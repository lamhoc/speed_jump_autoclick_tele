-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/AutoMail.lua
-- Module tự động gửi Huge Pet qua hòm thư Mailbox về tài khoản chính
-- Tích hợp: Bỏ qua Titanic, Gargantuan, Untradable, Soulbound, Bat Hoodie Bunny
--           Khóa cước Gems, Chống spam 30p khi lỗi
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AutoMail = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local Webhook = nil
local inEventFn = nil

function AutoMail.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
end

local FailedUIDBlacklist = {}
local nextMailAttemptAt = 0

local MailSettings = {
    Recipient        = "Kizmoii_VNG",
    StartupWaitSec   = 10,
    MailCooldownSec  = 10,
    RetryIntervalSec = 1800, -- 30 phút nếu hòm thư đầy hoặc thiếu gems
    IdleCheckSec     = 10,
}

function AutoMail.getDiamonds()
    if Net and type(Net.currency) == "function" then
        local d = Net.currency("Diamonds")
        if type(d) == "number" and d > 0 then
            return d
        end
    end
    local s = Net and Net.getSave and Net.getSave()
    local cur = (s and s.Inventory and s.Inventory.Currency) or (s and s.Currencies) or (s and s.Currency)
    if type(cur) == "table" then
        for _, v in pairs(cur) do
            if type(v) == "table" and (v.id == "Diamonds" or v._id == "Diamonds") then
                return tonumber(v._am or v.Amount) or 0
            end
        end
    end
    return 0
end

local TARGET_TIER2_BOOSTS = {
    ["Island Luck Boost"] = true,
    ["Patch Coin Boost"] = true,
    ["Pumpkin Damage Boost"] = true,
}

-- Quét tìm Tier 2 Event Boost cần gửi qua mail về tài khoản chính (dù chỉ có 1 cái cũng gửi)
function AutoMail.findSendableTier2Boost()
    if not Config.AutoMailTier2Boosts then return nil end
    local s = Net and Net.getSave and Net.getSave()
    local inv = s and s.Inventory
    if not inv or type(inv.Consumable) ~= "table" then return nil end

    for uid, item in pairs(inv.Consumable) do
        if type(item) == "table" and type(item.id) == "string" then
            if TARGET_TIER2_BOOSTS[item.id] and not FailedUIDBlacklist[uid] then
                local tier = tonumber(item.tn) or tonumber(item.tier) or 1
                if tier == 2 then
                    local amt = tonumber(item._am) or 1
                    if amt > 0 then
                        return {
                            UID = uid,
                            Id = item.id,
                            Name = item.id .. " (Tier 2)",
                            Amount = amt,
                            Category = "Consumable",
                            IsLocked = (item.lk == true or item._lk == true),
                        }
                    end
                end
            end
        end
    end
    return nil
end

-- Quét tìm Huge pet có thể gửi (gửi TOÀN BỘ Huge đang có, không bỏ sót con nào)
function AutoMail.findSendableHuge()
    if Config.AutoMailHuge == false then return nil end
    local s = Net and Net.getSave and Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return nil end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            -- 1. Giữ lại Titanic và Gargantuan (nếu có)
            if p.id:find("Titanic ") or p.id:find("Gargantuan ") then
                continue
            end

            -- 2. Bỏ qua nếu đã bị server từ chối vì lý do Soulbound thực sự
            if FailedUIDBlacklist[uid] then continue end

            -- 3. Bỏ qua Soulbound thực tế (nếu mang cờ sb)
            if p.sb == true or p._sb == true or p.Soulbound == true then
                FailedUIDBlacklist[uid] = true
                continue
            end

            -- 4. Nhận diện mọi Huge pet (Huge Bat Hoodie Bunny, Huge Orchard Hedgehog, v.v.)
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
            if isHuge then
                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                return {
                    UID = uid,
                    Id = p.id,
                    Name = pName,
                    Amount = 1,
                    Category = "Pet",
                    IsLocked = (p.lk == true or p._lk == true)
                }
            end
        end
    end
    return nil
end

-- Vòng lặp kiểm tra và gửi thư (Ưu tiên gửi Tier 2 Boost trước, sau đó tới Huge)
function AutoMail.stepMailTick(state)
    local canMail = (Config.AutoMailHuge or Config.AutoMailTier2Boosts)
    if not canMail or (inEventFn and not inEventFn()) then
        return
    end
    if state and state.excursion == "mail" then
        return
    end

    local now = os.clock()

    -- 1. Nếu đang trong thời gian giãn cách do lỗi server/hòm đầy
    if now < nextMailAttemptAt then
        local remSec = math.max(0, math.ceil(nextMailAttemptAt - now))
        local remMins = math.floor(remSec / 60)
        local remSecs = remSec % 60
        state.mailStatus = string.format("Chờ gửi lại sau 30p (%02d:%02d)", remMins, remSecs)
        return
    end

    -- 2. Ưu tiên tìm Tier 2 Boost cần gift về trước
    local targetItem = AutoMail.findSendableTier2Boost()
    local isBoost = (targetItem ~= nil)

    -- Nếu không có Tier 2 Boost thì tìm Huge pet
    if not targetItem and Config.AutoMailHuge then
        targetItem = AutoMail.findSendableHuge()
    end

    if not targetItem then
        state.mailStatus = "Hết đồ cần gửi mail"
        return
    end

    -- 3. Bắt đầu phiên gửi qua Mailbox
    local prevExcursion = state.excursion
    state.excursion = "mail"
    state.mailStatus = "Đang gửi " .. targetItem.Name

    -- Kiểm tra số Gems tối thiểu trong ví để trả cước gửi thư
    local currentDiamonds = AutoMail.getDiamonds()
    if currentDiamonds < 10000 then
        state.excursion = prevExcursion
        nextMailAttemptAt = os.clock() + (Config.MailRetryInterval or MailSettings.RetryIntervalSec)
        state.mailStatus = "Chờ gửi lại sau 30p (Thiếu Gems)"
        return
    end

    pcall(function()
        Net.netFire("Machines: Mark Approached", "Mailbox")
    end)
    task.wait(0.2)

    -- Mở khóa vật phẩm nếu đang bị khóa
    if targetItem.IsLocked then
        pcall(function()
            Net.netInvoke("Locking_SetLocked", targetItem.UID, false)
            if targetItem.Category == "Pet" then
                Net.netFire("Pets_Unlock", targetItem.UID)
            end
        end)
        task.wait(0.3)
    end

    local recipient = Config.MailRecipient or (type(getgenv) == "function" and getgenv().MailRecipient) or MailSettings.Recipient or "Kizmoii_VNG"
    local diaBefore = AutoMail.getDiamonds()
    local mailMsg = isBoost and ("Gift Boost #" .. tostring(math.random(100, 999))) or ("Gift #" .. tostring(math.random(100, 999)))
    local okSend, resSend = Net.netInvokeTimeout(8, "Mailbox: Send", recipient, mailMsg, targetItem.Category or "Consumable", targetItem.UID, targetItem.Amount or 1)
    local diaAfter = AutoMail.getDiamonds()
    local actualCost = math.max(0, diaBefore - diaAfter)

    state.excursion = prevExcursion -- Phục hồi excursion trước đó

    if okSend and resSend == true then
        state.mailStatus = string.format("Đã gửi %s (Cước: %s)", targetItem.Name, Net.shorten(actualCost))
        print(string.format("[KizHub Mail] 📦 Đã gửi thành công %s tới %s (SL: %d, Cước: %s Gems)", targetItem.Name, recipient, targetItem.Amount or 1, Net.shorten(actualCost)))
        local eventsUrl = Config.Webhook and Config.Webhook.EventsUrl
        if Webhook and type(Webhook.sendWebhook) == "function" then
            local webhookTitle = isBoost and "📦 [AUTO-MAIL TIER 2 BOOST THÀNH CÔNG] 📦" or "📦 [AUTO-MAIL HUGE THÀNH CÔNG] 📦"
            local webhookDesc = string.format(
                "Người gửi: **%s**\nNgười nhận: **%s**\nVật phẩm: **%s**\nSố lượng: **%d**\nPhí cước: **%d Gems**",
                LocalPlayer.Name,
                recipient,
                targetItem.Name,
                targetItem.Amount or 1,
                actualCost
            )
            Webhook.sendWebhook(
                webhookTitle,
                webhookDesc,
                0x00E676,
                eventsUrl
            )
        end
        task.wait(Config.MailCooldownSec or MailSettings.MailCooldownSec or 10)
    else
        local errStr = string.lower(tostring(resSend))
        if errStr:find("soulbound") or errStr:find("untradable") or errStr:find("cannot be traded") or errStr:find("not tradable") then
            FailedUIDBlacklist[targetItem.UID] = true
            state.mailStatus = "Vật phẩm không thể trade (Bỏ qua)"
            task.wait(2)
        else
            nextMailAttemptAt = os.clock() + (Config.MailRetryInterval or MailSettings.RetryIntervalSec)
            state.mailStatus = "Chờ gửi lại sau 30p (Lỗi gửi thư)"
            print(string.format("[KizHub Mail] ⚠️ Lỗi gửi thư (%s) -> Chờ thử lại sau 30p", tostring(resSend)))
        end
    end
end

-- Alias tương thích cho các script gọi hàm
AutoMail.checkAndSendHuge = AutoMail.stepMailTick

-- Vòng lặp chạy nền độc lập cho AutoMail
function AutoMail.startMailLoop(state)
    task.spawn(function()
        local gTime = workspace.DistributedGameTime
        if gTime < MailSettings.StartupWaitSec then
            task.wait(math.ceil(MailSettings.StartupWaitSec - gTime))
        end

        while state and state.alive do
            local ok, err = pcall(function()
                AutoMail.stepMailTick(state)
            end)
            if not ok then
                state.excursion = nil
                nextMailAttemptAt = os.clock() + (Config.MailRetryInterval or MailSettings.RetryIntervalSec)
                state.mailStatus = "Chờ gửi lại sau 30p (30:00)"
            end
            task.wait(1)
        end
    end)
end

return AutoMail
