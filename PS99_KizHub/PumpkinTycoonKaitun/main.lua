-- =========================================================================
-- PS99_KizHub/PumpkinTycoonKaitun/main.lua
-- Trình điều phối chính (Orchestrator) cho Suite tự động hóa Pumpkin Patch Tycoon
-- Tác giả: VANTA [JHON369] | KizHub Automation Engine
-- =========================================================================

repeat task.wait(0.2) until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local GITHUB_REPO_BASE = (type(getgenv) == "function" and getgenv().KizHubRepoBase) or "https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/refs/heads/main/PS99_KizHub/"
local GITHUB_FALLBACK_BASE = "https://raw.githubusercontent.com/accphu0803-tech/nobodyhere/refs/heads/main/PS99_KizHub/"

local function readFileSafe(path)
    if type(readfile) == "function" then
        local ok, content = pcall(readfile, path)
        if ok and content and #content > 0 then
            return content
        end
    end
    return nil
end

local function import(relativePath)
    local localCandidates = {
        relativePath,
        "PS99_KizHub/" .. relativePath,
        "scripts/PS99_KizHub/" .. relativePath,
    }
    for _, path in ipairs(localCandidates) do
        local content = readFileSafe(path)
        if content then
            local fn, err = loadstring(content, "=" .. relativePath)
            if fn then return fn() else error("[KizHub Import] Lỗi nạp local " .. relativePath .. ": " .. tostring(err)) end
        end
    end

    local primaryUrl = GITHUB_REPO_BASE .. relativePath
    local cacheBustUrl = primaryUrl .. "?t=" .. tostring(os.time())
    local okG, webContent = pcall(function() return game:HttpGet(cacheBustUrl) end)
    if not okG or not webContent or #webContent == 0 then
        okG, webContent = pcall(function() return game:HttpGet(primaryUrl) end)
    end
    if not okG or not webContent or #webContent == 0 then
        local fallbackUrl = GITHUB_FALLBACK_BASE .. relativePath
        okG, webContent = pcall(function() return game:HttpGet(fallbackUrl) end)
    end
    if okG and webContent and #webContent > 0 then
        local fn, err = loadstring(webContent, "=" .. relativePath)
        if fn then return fn() else error("[KizHub Import] Lỗi nạp online " .. primaryUrl .. ": " .. tostring(err)) end
    end

    error("[KizHub Import] Không tìm thấy file: " .. relativePath)
end

-- =========================================================================
-- 1. NẠP MODULES & CẤU HÌNH HỆ THỐNG
-- =========================================================================

local Modules        = import("Shared/Modules.lua")
local Network        = import("Shared/Network.lua")
local EngineOptim    = import("Shared/EngineOptim.lua")
local AntiAFK        = import("Shared/AntiAFK.lua")
local Webhook        = import("Shared/Webhook.lua")
local DashboardGui   = import("Shared/DashboardGui.lua")

local Daycare        = import("HalloweenKaitun/Daycare.lua")
local AutoMail       = import("HalloweenKaitun/AutoMail.lua")
local BuffsAndGifts  = import("HalloweenKaitun/BuffsAndGifts.lua")

local ConfigModule   = import("PumpkinTycoonKaitun/Config.lua")
local Config         = ConfigModule.Config
local K              = ConfigModule.K

local TycoonFarm     = import("PumpkinTycoonKaitun/TycoonFarm.lua")
local EggHatch       = import("PumpkinTycoonKaitun/EggHatch.lua")
local TycoonMachines = import("PumpkinTycoonKaitun/TycoonMachines.lua")

-- Ràng buộc Network với môi trường game
Network.bindModules(Modules.G)

-- Trạng thái điều phối phiên chạy
local state = {
    alive = true,
    startTime = os.clock(),
    sessionStartCoins = 0,
    totalEggsHatched = 0,
    currentEggName = "Cocoa Cabin Egg",
    excursion = nil,
    daycareStatus = "Chờ",
    mailStatus = "Rảnh",
    autoFarmActive = false,
}

-- =========================================================================
-- 2. HÀM KIỂM TRA TRẠNG THÁI SỰ KIỆN (IN-EVENT DETECTION)
-- =========================================================================

local function inEvent()
    -- 1. Kiểm tra container active instance trong Workspace
    local things = workspace:FindFirstChild("__THINGS")
    local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local act = cont and cont:FindFirstChild("Active")
    if act and act:FindFirstChild("PumpkinTycoon") ~= nil then
        return true
    end

    -- 2. Kiểm tra ClientPlot của người chơi từ Island module
    local okPlot, plotObj = pcall(function()
        local islandCmds = require(ReplicatedStorage.Library.Client.PumpkinTycoonCmds.Island)
        return islandCmds and islandCmds.Plot and islandCmds.Plot()
    end)
    if okPlot and plotObj ~= nil then
        return true
    end

    -- 3. Kiểm tra tọa độ không gian (Y > 1750 và trong bán kính 4500 studs quanh Vector3.new(8000, 2000, 8000))
    local p = Network.playerPos and Network.playerPos()
    if p and p.Y > 1750 then
        local dist = (p - Vector3.new(8000, 2000, 8000)).Magnitude
        if dist < 4500 then
            return true
        end
    end

    -- 4. Kiểm tra InstanceId từ Save hoặc Instancing module
    local s = Network.getSave and Network.getSave()
    local inst = s and s.Instancing and s.Instancing.InstanceId
    if inst == "PumpkinTycoon" then
        return true
    end
    if Modules and Modules.G and Modules.G.Instancing and Network.isfn(Modules.G.Instancing, "GetId") then
        local okId, curId = pcall(function() return Network.gval(Modules.G.Instancing.GetId) end)
        if okId and curId == "PumpkinTycoon" then
            return true
        end
    end

    return false
end

-- Khởi tạo Dependencies dùng chung
local sharedDeps = {
    Modules = Modules,
    Network = Network,
    Config = Config,
    K = K,
    Webhook = Webhook,
    inEvent = inEvent,
    instanceModel = function()
        if Modules and Modules.G and Modules.G.Instancing and Network.isfn(Modules.G.Instancing, "GetModel") then
            local m = Network.gval(Modules.G.Instancing.GetModel)
            if typeof(m) == "Instance" then return m end
        end
        local things = workspace:FindFirstChild("__THINGS")
        local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = cont and cont:FindFirstChild("Active")
        return act and act:FindFirstChild(K.INSTANCE_ID or "PumpkinTycoon")
    end,
    petEuids = TycoonFarm.petEuids,
    DashboardGui = DashboardGui,
    TycoonFarm = TycoonFarm,
    EggHatch = EggHatch,
}

Modules.TycoonFarm = TycoonFarm
Modules.EggHatch = EggHatch

TycoonFarm.init(sharedDeps)
EggHatch.init(sharedDeps)
TycoonMachines.init(sharedDeps)
Daycare.init(sharedDeps)
AutoMail.init(sharedDeps)
BuffsAndGifts.init(sharedDeps)

-- =========================================================================
-- 2. TỐI ƯU HIỆU NĂNG (CPU SAVER) & CHỐNG AFK KICK
-- =========================================================================

if Config.CPUSaver ~= false then
    EngineOptim.applyAll(Config.TargetFPS or 5, true)
    EngineOptim.set3dRendering(false)
    EngineOptim.muteAllSounds()
    EngineOptim.disableHeavyLighting()
    EngineOptim.purgeHeavyVisuals()
    EngineOptim.stopAnimations()
    EngineOptim.hideOtherPlayers()
    EngineOptim.startMemoryCleanupLoop()
    print("[KizHub Tycoon] ❄️ ĐÃ KÍCH HOẠT CHẾ ĐỘ CPU SAVER (3D Rendering Off, Cap FPS, Mute)!")
else
    EngineOptim.restoreNormal(Config.TargetFPS or 60)
    print("[KizHub Tycoon] 🎮 ĐÃ KÍCH HOẠT BẢN TEST TRỰC QUAN (3D Rendering ON, 60 FPS, Đồ họa chuẩn)!")
end

if Config.InfinitePetSpeed ~= false and TycoonFarm and type(TycoonFarm.installInfinitePetSpeed) == "function" then
    TycoonFarm.installInfinitePetSpeed()
end

AntiAFK.installGodModeAntiAfk(Network.netFire, Config.AfkPulseInterval or 35)

-- Chống bung và tự động ẩn cửa sổ túi đồ / popup rương quà để triệt tiêu 100% giật lag
task.spawn(function()
    while state.alive do
        pcall(function()
            local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pgui then
                for _, name in ipairs({ "Inventory", "Lootbox", "GiftOpening", "CardOpening", "Rewards" }) do
                    local g = pgui:FindFirstChild(name)
                    if g and g:IsA("ScreenGui") and g.Enabled then
                        g.Enabled = false
                    end
                end
            end
        end)
        task.wait(1.5)
    end
end)

-- =========================================================================
-- 3. ĐẢM BẢO NGƯỜI CHƠI ĐÃ VÀO INSTANCE PUMPKIN TYCOON
-- =========================================================================

local lastEnterAttempt = 0

local function ensureInPumpkinTycoon()
    if inEvent() then
        return true
    end

    local now = os.clock()
    if now - lastEnterAttempt < 25 then
        return false
    end
    lastEnterAttempt = now

    print("[KizHub Tycoon] Đang tiến vào thế giới Pumpkin Tycoon...")
    pcall(function()
        if Modules and Modules.G and Modules.G.Instancing and Network.isfn(Modules.G.Instancing, "Enter") then
            Network.gcall(Modules.G.Instancing.Enter, K.INSTANCE_ID or "PumpkinTycoon")
        else
            Network.netInvoke("Instancing_PlayerEnterInstance", K.INSTANCE_ID or "PumpkinTycoon")
        end
    end)

    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 15 do
        if inEvent() then
            task.wait(1.5)
            pcall(function()
                local islandCmds = require(ReplicatedStorage.Library.Client.PumpkinTycoonCmds.Island)
                if islandCmds and type(islandCmds.GetTeleport) == "function" then
                    local teleCF = islandCmds.GetTeleport()
                    if teleCF and Network.teleportTo then
                        Network.teleportTo(teleCF)
                    end
                end
            end)
            -- Đặt cấu hình AutoBreak về 0 ngay khi vào đảo
            if TycoonFarm and type(TycoonFarm.ensureAutoBreakZero) == "function" then
                TycoonFarm.ensureAutoBreakZero()
            end
            return true
        end
        task.wait(0.5)
    end

    if inEvent() then
        pcall(function()
            local islandCmds = require(ReplicatedStorage.Library.Client.PumpkinTycoonCmds.Island)
            if islandCmds and type(islandCmds.GetTeleport) == "function" then
                local teleCF = islandCmds.GetTeleport()
                if teleCF and Network.teleportTo then
                    Network.teleportTo(teleCF)
                end
            end
        end)
        return true
    end

    return false
end

-- =========================================================================
-- 4. KHỞI TẠO DASHBOARD GUI THEO DÕI THỜI GIAN THỰC
-- =========================================================================

local ui = DashboardGui.create({
    Mode = "Tycoon",
    BadgeTitle = "🎃 Kiz Hub | Pumpkin Patch Tycoon",
    OnClose = function()
        state.alive = false
    end,
})

task.spawn(function()
    while state.alive do
        pcall(function()
            local now = os.clock()
            local uptime = now - state.startTime
            local hrs = math.floor(uptime / 3600)
            local mins = math.floor((uptime % 3600) / 60)
            local secs = math.floor(uptime % 60)

            local prog = TycoonFarm.getTycoonProgress()
            local mach = TycoonMachines.getMachineSummary()
            local coins = Network.currency(K.CURRENCY) or 0
            local tokens = Network.currency(K.TOKENS) or 0

            if state.sessionStartCoins == 0 and coins > 0 then
                state.sessionStartCoins = coins
            end
            local deltaCoins = math.max(0, coins - state.sessionStartCoins)

            -- Cập nhật Header
            if ui.UptimeLabel then
                ui.UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", hrs, mins, secs)
            end
            if ui.ZoneLabel then
                local areaIdx = (TycoonFarm and type(TycoonFarm.getActiveAreaIndex) == "function" and TycoonFarm.getActiveAreaIndex()) or 1
                local ZONE_NAMES = {
                    [1] = "Bãi 1 (Cocoa Cabin)",
                    [2] = "Bãi 2 (Apple Orchard)",
                    [3] = "Bãi 3 (Hayride Hill)",
                    [4] = "Bãi 4 (Cider Mill)",
                    [5] = "Bãi 5 (Golden Grove - Max)",
                }
                local areaName = ZONE_NAMES[areaIdx] or ("Bãi " .. tostring(areaIdx))
                ui.ZoneLabel.Text = string.format("Pumpkin Tycoon • %s • Xây: %d/%d (%.0f%%) • %d hatched", areaName, prog.ownedButtons, prog.totalButtons, prog.percent * 100, state.totalEggsHatched or 0)
            end
            if ui.CombineLabel then
                ui.CombineLabel.Text = string.format("🎃 AutoFarm: %s • Move: %s • Máy Upg: %s (%d/%d Cấp)", state.autoFarmActive and "BẬT" or "TẮT", Config.MovementMode or "Rage", mach.hasMachine and "ĐÃ MỞ" or "CHƯA", mach.totalTiers or 0, mach.maxTiers or 74)
            end
            if ui.CoinsLabel then
                ui.CoinsLabel.Text = string.format("Patch Coins: %s (+%s) • Pumpkin Tokens: %s", Network.shorten(coins), Network.shorten(deltaCoins), Network.shorten(tokens))
            end
            if ui.MailLabel then
                ui.MailLabel.Text = string.format("Hatched: %d • Flannel Gifts: %d • Merchant: %s • Mail: %s", state.totalEggsHatched or 0, mach.flannelGiftCount or 0, mach.merchantStatus or "Rảnh", state.mailStatus or "Rảnh")
            end
            if ui.DetailBox then
                if state.excursion and state.excursion:find("Bí Ngô") then
                    state.excursion = nil
                end
                local currentTask = state.excursion or state.hatchStatus or string.format("Đứng bãi farm %s & mở trứng...", areaName)
                ui.DetailBox.Text = "Doing: " .. tostring(currentTask)
            end

            -- Cập nhật 4 Hàng Tiến Độ (QuestRows)
            if ui.QuestRows then
                -- Hàng 1: [🏝️ Đảo] Tiến độ xây đảo (ownedButtons / totalButtons + trạng thái nhận thưởng 100%)
                local r1 = ui.QuestRows[1]
                if r1 then
                    r1.Row.Visible = true
                    r1.Stars.Text = "[🏝️ Đảo]"
                    r1.Stars.TextColor3 = Color3.fromRGB(56, 189, 248)
                    r1.Name.Text = "Tiến Độ Xây Đảo"
                    local isDone = prog.completed or (prog.percent >= 1)
                    r1.ProgText.Text = string.format("%d / %d (%.0f%%) • %s", prog.ownedButtons, prog.totalButtons, prog.percent * 100, isDone and "HOÀN THÀNH" or "ĐANG XÂY")
                    r1.ProgText.TextColor3 = isDone and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(248, 113, 113)
                    r1.BarFill.Size = UDim2.new(math.clamp(prog.percent, 0, 1), 0, 1, 0)
                    r1.BarFill.BackgroundColor3 = isDone and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(56, 189, 248)
                end

                -- Hàng 2: [🎃 Bí Ngô] Bệ trồng & Bí Khổng Lồ (unlockedPedestals/8 bệ • Túi: stockCount/maxSlots)
                local r2 = ui.QuestRows[2]
                if r2 then
                    r2.Row.Visible = true
                    r2.Stars.Text = "[🎃 Bí Ngô]"
                    r2.Stars.TextColor3 = Color3.fromRGB(251, 146, 60)
                    r2.Name.Text = "Bệ Trồng & Bí Khổng Lồ"
                    r2.ProgText.Text = string.format("%d/8 bệ • Túi: %d/%d • Bí: %s", prog.unlockedPedestals or 0, mach.stockCount or 0, mach.stockMax or 15, prog.activeBigPumpkins > 0 and ("Bậc " .. (prog.activeBigPumpkinRung or 1)) or "Không")
                    r2.ProgText.TextColor3 = (prog.activeBigPumpkins > 0) and Color3.fromRGB(251, 146, 60) or Color3.fromRGB(52, 211, 153)
                    local pedFrac = math.clamp((prog.unlockedPedestals or 0) / 8, 0, 1)
                    r2.BarFill.Size = UDim2.new(pedFrac, 0, 1, 0)
                    r2.BarFill.BackgroundColor3 = Color3.fromRGB(251, 146, 60)
                end

                -- Hàng 3: [⚡ Nâng Cấp] Upgrade Machine
                local r3 = ui.QuestRows[3]
                if r3 then
                    r3.Row.Visible = true
                    r3.Stars.Text = "[⚡ Nâng Cấp]"
                    r3.Stars.TextColor3 = Color3.fromRGB(168, 85, 247)
                    r3.Name.Text = "Upgrade Machine"
                    
                    if not mach.hasMachine then
                        r3.ProgText.Text = "Chưa mở máy • Chờ mua nút UpgradeMachine"
                        r3.ProgText.TextColor3 = Color3.fromRGB(148, 163, 184)
                        r3.BarFill.Size = UDim2.new(0, 0, 1, 0)
                    elseif mach.totalTiers >= (mach.maxTiers or 74) then
                        r3.ProgText.Text = string.format("MAX TOÀN BỘ (%d/%d Cấp) • Đã Tối Đa!", mach.totalTiers, mach.maxTiers or 74)
                        r3.ProgText.TextColor3 = Color3.fromRGB(52, 211, 153)
                        r3.BarFill.Size = UDim2.new(1, 0, 1, 0)
                        r3.BarFill.BackgroundColor3 = Color3.fromRGB(52, 211, 153)
                    else
                        local nxt = mach.nextUpgrade
                        local nextText = ""
                        if nxt then
                            if tokens >= nxt.cost then
                                nextText = string.format(" • Tiếp: %s Lv%d (%s 🎟️ - ĐỦ)", nxt.name, nxt.nextTier, Network.shorten(nxt.cost))
                            else
                                nextText = string.format(" • Tiếp: %s Lv%d (%s/%s 🎟️)", nxt.name, nxt.nextTier, Network.shorten(tokens), Network.shorten(nxt.cost))
                            end
                        end
                        r3.ProgText.Text = string.format("%d/%d Cấp (%.0f%%)%s", mach.totalTiers, mach.maxTiers or 74, (mach.percent or 0) * 100, nextText)
                        r3.ProgText.TextColor3 = Color3.fromRGB(168, 85, 247)
                        r3.BarFill.Size = UDim2.new(math.clamp(mach.percent or 0, 0, 1), 0, 1, 0)
                        r3.BarFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
                    end
                end

                -- Hàng 4: [☕ Cocoa] Hot Cocoa Boosts & Ép Pet Gold/Rainbow
                local r4 = ui.QuestRows[4]
                if r4 then
                    r4.Row.Visible = true
                    r4.Stars.Text = "[☕ Cocoa]"
                    r4.Stars.TextColor3 = Color3.fromRGB(250, 204, 21)
                    r4.Name.Text = "Hot Cocoa & Ép Pet"
                    local cocoaMin = mach.activeCocoaMin or 0
                    r4.ProgText.Text = string.format("Cocoa: %dp • Ép Pet: Sẵn sàng", cocoaMin)
                    r4.ProgText.TextColor3 = (cocoaMin > 0) and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(248, 113, 113)
                    r4.BarFill.Size = UDim2.new(math.clamp(cocoaMin / 60, 0, 1), 0, 1, 0)
                    r4.BarFill.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
                end
            end
        end)
        task.wait(3.0)
    end
end)

-- =========================================================================
-- 5. CÁC TIẾN TRÌNH VẬN HÀNH ĐỒNG THỜI (CONCURRENT WORKERS)
-- =========================================================================

-- LUỒNG 1: Farm bãi patch cao nhất + Mở trứng Custom (giãn cách 0.35s tối ưu CPU)
task.spawn(function()
    while state.alive do
        pcall(function()
            if not Config.Enabled or not ensureInPumpkinTycoon() then
                task.wait(1.0)
                return
            end

            -- 1. Luôn duy trì farm bãi Patch tốt nhất (sweet spot)
            TycoonFarm.farmBestPatchTick(state)

            -- 2. Mở trứng Custom cao nhất từ xa (tại sweet spot)
            EggHatch.hatchBestEggTick(state)
        end)
        task.wait(0.35)
    end
end)

-- LUỒNG 2: Mua nút Tycoon (Cheapest First) & Hút Orbs / Lootbags
task.spawn(function()
    while state.alive do
        pcall(function()
            if not Config.Enabled or not ensureInPumpkinTycoon() then
                task.wait(1.0)
                return
            end

            -- Tự động mua nút rẻ nhất khi đủ Patch Coins
            TycoonFarm.checkAndBuyButtons(state)
            TycoonFarm.collectOrbsTick()
        end)
        task.wait(Config.ButtonBuyInterval or 2.0)
    end
end)

-- LUỒNG 3: Auto-Tap gõ quặng xung quanh (giãn cách 1.5s siêu nhẹ CPU)
task.spawn(function()
    while state.alive do
        pcall(function()
            if Config.Enabled and ensureInPumpkinTycoon() then
                TycoonFarm.runAutoTapTick()
            end
        end)
        task.wait(Config.AutoTap and Config.AutoTap.TapDelay or 1.5)
    end
end)

-- LUỒNG 4: Quản lý toàn bộ máy trạm (Upgrades, Merchant, Cocoa, Roster Pets, Gifts)
task.spawn(function()
    while state.alive do
        pcall(function()
            if Config.Enabled and ensureInPumpkinTycoon() then
                TycoonMachines.runAllMachinesTick(state)
                TycoonFarm.ensureAutoBreakZero()
            end
        end)
        task.wait(6.0)
    end
end)

-- LUỒNG 5: Quản lý Daycare, AutoMail Huge & Buffs phụ trợ
task.spawn(function()
    while state.alive do
        pcall(function()
            if Config.Enabled then
                if Config.AutoDaycare and Daycare and type(Daycare.checkAndEnroll) == "function" then
                    Daycare.checkAndEnroll(state)
                end
                if (Config.AutoMailHuge or Config.AutoMailTier2Boosts) and AutoMail and type(AutoMail.checkAndSendHuge) == "function" then
                    AutoMail.checkAndSendHuge(state)
                end
                if BuffsAndGifts and type(BuffsAndGifts.runBuffsAndGiftsTick) == "function" then
                    BuffsAndGifts.runBuffsAndGiftsTick(state)
                end
            end
        end)
        task.wait(30.0)
    end
end)

-- LUỒNG 6: Bắt Huge / Titanic mới nở từ Trứng, Quà Gift & Gửi Báo Cáo Discord Webhook Định Kỳ
task.spawn(function()
    local lastStatusReport = os.clock()
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    while state.alive do
        pcall(function()
            -- 1. Quét tìm Huge / Titanic vừa nở hoặc vừa nhận từ Gift
            local eventsUrl = (Config.Webhook and Config.Webhook.EventsUrl)
            if (not eventsUrl or eventsUrl == "") and genv then
                eventsUrl = genv.EventsUrl or genv.WebhookUrl
            end
            if eventsUrl and eventsUrl ~= "" and Webhook and type(Webhook.checkNewHugeHatched) == "function" then
                Webhook.checkNewHugeHatched(Network.getSave, eventsUrl)
            end

            -- 2. Gửi báo cáo trạng thái định kỳ 30 phút
            local statusUrl = (Config.Webhook and Config.Webhook.StatusUrl)
            if (not statusUrl or statusUrl == "") and genv then
                statusUrl = genv.StatusUrl or genv.WebhookUrl
            end
            local interval = (Config.Webhook and Config.Webhook.StatusInterval) or 1800
            if statusUrl and statusUrl ~= "" and os.clock() - lastStatusReport >= interval then
                lastStatusReport = os.clock()
                local prog = TycoonFarm.getTycoonProgress()
                local coins = Network.currency(K.CURRENCY) or 0
                local tokens = Network.currency(K.TOKENS) or 0
                local uptimeHours = (os.clock() - state.startTime) / 3600

                local title = "📊 [BÁO CÁO PUMPKIN TYCOON] THỐNG KÊ ĐỊNH KỲ"
                local desc = string.format(
                    "Tài khoản: **%s**\nThời gian chạy: **%.1f giờ**\nTiến độ Đảo: **%d/%d (%.1f%%)**\nPatch Coins: **%s**\nPumpkin Tokens: **%s**\nTrứng đã mở: **%d**\nBệ Pedestal: **%d/8**\nAutoFarm: **%s**",
                    LocalPlayer.Name,
                    uptimeHours,
                    prog.ownedButtons,
                    prog.totalButtons,
                    prog.percent * 100,
                    Network.shorten(coins),
                    Network.shorten(tokens),
                    state.totalEggsHatched or 0,
                    prog.unlockedPedestals or 0,
                    state.autoFarmActive and "BẬT" or "TẮT"
                )
                Webhook.sendWebhook(title, desc, 0xf59e0b, statusUrl)
            end
        end)
        task.wait(2.0)
    end
end)

print("[KizHub Tycoon] 🚀 Khởi chạy hoàn tất Suite tự động hóa Pumpkin Patch Tycoon!")
