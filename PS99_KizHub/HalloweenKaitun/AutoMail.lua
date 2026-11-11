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
    StartupWaitSec   = 30,
    MailCooldownSec  = 61,
    RetryIntervalSec = 1800, -- ĐÚNG 30 PHÚT: Nếu gửi không được thì đúng 30 phút sau mới thử lại
    IdleCheckSec     = 20,
}

function AutoMail.getDiamonds()
    local s = Net.getSave()
    local cur = s and s.Inventory and s.Inventory.Currency
    if type(cur) == "table" then
        for _, v in pairs(cur) do
            if type(v) == "table" and v.id == "Diamonds" then
                return tonumber(v._am) or 0
            end
        end
    end
    return 0
end

-- Quét tìm Huge pet có thể gửi (bỏ qua Titanic, Gargantuan, Untradable, Soulbound, Bat Hoodie Bunny)
function AutoMail.findSendableHuge()
    local s = Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return nil end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            -- 1. Tuyệt đối KHÔNG gửi Titanic hay Gargantuan (giữ lại trên tài khoản)
            if p.id:find("Titanic ") or p.id:find("Gargantuan ") then
                continue
            end

            -- 2. Bỏ qua Huge Bat Hoodie Bunny & Combine event pets
            if p.id:find("Bat Hoodie Bunny") or p.id:find("Combine") then
                continue
            end

            -- 3. Bỏ qua nếu nằm trong blacklist tạm thời (lỗi trước đó)
            if FailedUIDBlacklist[uid] then continue end

            -- 4. Bỏ qua Soulbound / Untradable (Game cấm gửi thư)
            if p.sb == true or p._sb == true or p.Soulbound == true or p.Untradable == true or p.tradable == false then
                FailedUIDBlacklist[uid] = true
                continue
            end

            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
            if isHuge then
                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                return {
                    UID = uid,
                    Id = p.id,
                    Name = pName,
                    IsLocked = (p.lk == true or p._lk == true)
                }
            end
        end
    end
    return nil
end

-- Vòng lặp kiểm tra và gửi thư
function AutoMail.stepMailTick(state)
    if not Config.AutoMailHuge or (inEventFn and not inEventFn()) or state.excursion ~= nil then
        return
    end

    local now = os.clock()

    -- 1. Nếu đang trong thời gian giãn cách 30 phút (do lỗi/hòm đầy/cước thư)
    if now < nextMailAttemptAt then
        local remSec = math.max(0, math.ceil(nextMailAttemptAt - now))
        local remMins = math.floor(remSec / 60)
        local remSecs = remSec % 60
        state.mailStatus = string.format("Chờ gửi lại sau 30p (%02d:%02d)", remMins, remSecs)
        return
    end

    -- 2. Tìm Huge cần gửi
    local huge = AutoMail.findSendableHuge()
    if not huge then
        state.mailStatus = "Hết Huge hợp lệ"
        return
    end

    -- 3. Bắt đầu phiên gửi Huge
    state.excursion = "mail"
    state.mailStatus = "Đang gửi " .. huge.Name

    -- Kiểm tra số Gems tối thiểu trong ví để tránh request vô nghĩa khi không đủ tiền
    local currentDiamonds = AutoMail.getDiamonds()
    if currentDiamonds < 10000 then
        state.excursion = nil
        nextMailAttemptAt = os.clock() + (Config.MailRetryInterval or MailSettings.RetryIntervalSec)
        state.mailStatus = "Chờ gửi lại sau 30p (Thiếu Gems)"
        return
    end

    pcall(function()
        Net.netFire("Machines: Mark Approached", "Mailbox")
    end)
    task.wait(0.3)

    -- Mở khóa pet nếu đang bị khóa
    if huge.IsLocked then
        pcall(function()
            Net.netInvoke("Locking_SetLocked", huge.UID, false)
            Net.netFire("Pets_Unlock", huge.UID)
        end)
        task.wait(0.4)
    end

    local diaBefore = AutoMail.getDiamonds()
    local okSend, resSend = Net.netInvokeTimeout(6, "Mailbox: Send", MailSettings.Recipient, "Gift #" .. tostring(math.random(100, 999)), "Pet", huge.UID, 1)
    local diaAfter = AutoMail.getDiamonds()
    local actualCost = math.max(0, diaBefore - diaAfter)

    state.excursion = nil -- Giải phóng ngay lập tức

    if okSend and resSend == true then
        state.mailStatus = string.format("Đã gửi %s (Cước: %s)", huge.Name, Net.shorten(actualCost))
        local eventsUrl = Config.Webhook and Config.Webhook.EventsUrl
        Webhook.sendWebhook(
            "📦 [AUTO-MAIL HUGE THÀNH CÔNG] 📦",
            string.format(
                "Người gửi: **%s**\nNgười nhận: **%s**\nPet gửi: **%s**\nPhí cước: **%d Gems**",
                LocalPlayer.Name,
                MailSettings.Recipient,
                huge.Name,
                actualCost
            ),
            0x00E676,
            eventsUrl
        )
        task.wait(MailSettings.MailCooldownSec)
    else
        local errStr = string.lower(tostring(resSend))
        if errStr:find("soulbound") or errStr:find("untradable") or errStr:find("cannot be traded") or errStr:find("not tradable") then
            FailedUIDBlacklist[huge.UID] = true
            state.mailStatus = "Pet không thể trade (Bỏ qua)"
            task.wait(3)
        else
            -- BẤT KỲ LỖI NÀO (CƯỚC CAO > 1M GEMS, THIẾU GEMS, HÒM ĐẦY, TIMEOUT, TỪ CHỐI):
            -- LẬP TỨC KHÓA ĐÚNG 30 PHÚT, ĐẾM LÙI THỜI GIAN THỰC, 0 REQUEST SPAM!
            nextMailAttemptAt = os.clock() + (Config.MailRetryInterval or MailSettings.RetryIntervalSec)
            state.mailStatus = "Chờ gửi lại sau 30p (30:00)"
        end
    end
end

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
