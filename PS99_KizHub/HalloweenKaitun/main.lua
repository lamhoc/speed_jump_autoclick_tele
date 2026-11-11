-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/main.lua
-- Loader tổng cho Kịch bản Halloween Kaitun (Modular Architecture)
-- Nạp: Shared Modules, Network, EngineOptim, AntiAFK, Webhook, DashboardGui
-- Quản lý: Zone Progression, Auto Farm, Hatching, Upgrades, Combine, Mail, Daycare
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G

-- Trình nạp module an toàn (Hỗ trợ cả Local Workspace & GitHub Raw Fallback)
local GITHUB_REPO_BASE = "https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/refs/heads/main/PS99_KizHub/"

local function import(path)
    local cleanPath = path:gsub("\\", "/")
    local cacheKey = "__KizHub_Cache_" .. cleanPath
    if genv[cacheKey] then
        return genv[cacheKey]
    end

    local candidates = {
        cleanPath,
        "PS99_KizHub/" .. cleanPath,
        "c:/Users/lamho/Desktop/ps99/PS99_KizHub/" .. cleanPath,
    }
    local content = nil
    for _, p in ipairs(candidates) do
        if type(isfile) == "function" and isfile(p) then
            local ok, data = pcall(readfile, p)
            if ok and type(data) == "string" and #data > 0 then
                content = data
                break
            end
        end
    end

    -- Fallback: Tự động tải từ GitHub Raw nếu máy/VPS không có sẵn file local
    if not content and type(game.HttpGet) == "function" then
        local remoteUrl = GITHUB_REPO_BASE .. cleanPath
        local ok, data = pcall(game.HttpGet, game, remoteUrl)
        if ok and type(data) == "string" and #data > 0 then
            content = data
        end
    end

    if not content then
        error(string.format("[KizHub Import] File not found locally and GitHub fallback failed: %s", path))
    end

    local fn, compileErr = loadstring(content, "=" .. cleanPath)
    if not fn then
        error(string.format("[KizHub Import] Syntax error in %s: %s", path, tostring(compileErr)))
    end
    local res = fn()
    genv[cacheKey] = res
    return res
end

-- 1. Nạp các module dùng chung (Shared)
local Modules       = import("Shared/Modules.lua")
local Network       = import("Shared/Network.lua")
local EngineOptim   = import("Shared/EngineOptim.lua")
local AntiAFK       = import("Shared/AntiAFK.lua")
local Webhook       = import("Shared/Webhook.lua")
local DashboardGui  = import("Shared/DashboardGui.lua")

-- Gán Modules vào Network
Network.bindModules(Modules.G)

-- 2. Nạp cấu hình & các module Halloween
local ConfigData    = import("HalloweenKaitun/Config.lua")
local Config        = ConfigData.Config
local K             = ConfigData.K

local ZoneFarm      = import("HalloweenKaitun/ZoneFarm.lua")
local EggHatch      = import("HalloweenKaitun/EggHatch.lua")
local TreatUpgrades = import("HalloweenKaitun/TreatUpgrades.lua")
local CombineHuge   = import("HalloweenKaitun/CombineHuge.lua")
local Daycare       = import("HalloweenKaitun/Daycare.lua")
local AutoMail      = import("HalloweenKaitun/AutoMail.lua")
local BuffsAndGifts = import("HalloweenKaitun/BuffsAndGifts.lua")

-- Đặt Webhook URL mặc định
Webhook.setDefaultUrl(Config.Webhook and Config.Webhook.EventsUrl)

-- Trạng thái toàn cục của phiên chạy
local state = {
    alive = true,
    excursion = nil,
    isRejoining = false,
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 },
    totalEggsHatched = 0,
    combineStatus = "Rảnh",
    mailStatus = "Rảnh",
    daycareStatus = Config.AutoDaycare and "Rảnh" or "Đã tắt (Config)",
    lastSuccessfulHatch = os.clock(),
    nextHatchAttemptAt = 0,
    nextUnlockTryAt = 0,
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextDaycareCheckAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextClaimGiftsAt = 0,
    currentZoneNumber = 1,
    sessionStartCoins = nil,
    lastStatusCoins = nil,
    lastStatusTreats = nil,
    lastStatusHatched = nil,
}

local SCRIPT_START_TIME = os.clock()
local function formatUptime()
    local elapsed = math.max(0, math.floor(os.clock() - SCRIPT_START_TIME))
    local hrs = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = elapsed % 60
    local totalMins = elapsed / 60
    return string.format("%02d:%02d:%02d (%.1f phút)", hrs, mins, secs, totalMins)
end

-- Quản lý Instance sự kiện
local function currentInstanceId()
    if Network.isfn(Modules.G.Instancing, "GetInstanceID") then
        local id = Network.gval(Modules.G.Instancing.GetInstanceID)
        if type(id) == "string" and id ~= "" then return id end
    end
    return nil
end

local function instanceModel()
    if Network.isfn(Modules.G.Instancing, "GetModel") then
        local m = Network.gval(Modules.G.Instancing.GetModel)
        if typeof(m) == "Instance" then return m end
    end
    local id = currentInstanceId()
    local things = workspace:FindFirstChild("__THINGS")
    local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local act = cont and cont:FindFirstChild("Active")
    return act and id and act:FindFirstChild(id) or nil
end

local function isPhysicallyInHalloweenMap()
    local p = Network.playerPos()
    if not p then return false end
    for i = 1, 8 do
        if Network.dist(p, K.ZONES[i].Pos) < 450 then return true end
    end
    return false
end

local function inEvent()
    return currentInstanceId() == K.INSTANCE_ID or isPhysicallyInHalloweenMap()
end

local lastEnterAttempt = 0
local function ensureInHalloweenEvent()
    if inEvent() then return true end
    local now = os.clock()
    if now - lastEnterAttempt < 30 then return false end
    lastEnterAttempt = now

    if Network.isfn(Modules.G.Instancing, "Enter") then
        Network.gcall(Modules.G.Instancing.Enter, K.INSTANCE_ID)
    end
    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 15 do
        if inEvent() then
            task.wait(1.5)
            return true
        end
        task.wait(0.5)
    end
    return inEvent()
end

-- Kiểm tra mở khóa zone
local function zoneUnlocked(n)
    if n <= 1 then return true end
    if Network.isfn(Modules.G.InstanceZone, "IsUnlocked") then
        local v = Network.gval(Modules.G.InstanceZone.IsUnlocked, n)
        if v ~= nil then return v == true end
    end
    local s = Network.getSave()
    local iv = s and s.InstanceVars and s.InstanceVars[K.INSTANCE_ID]
    local iz = iv and iv.InstanceZones
    return type(iz) == "table" and iz["__Zone_" .. n] == true
end

local function bestUnlockedZone()
    if Network.isfn(Modules.G.InstanceZone, "GetMaximumOwnedZoneNumber") then
        local n = Network.gval(Modules.G.InstanceZone.GetMaximumOwnedZoneNumber)
        if type(n) == "number" and n >= 1 then
            return math.clamp(n, 1, 8)
        end
    end
    local best = 1
    for i = 2, 8 do
        if zoneUnlocked(i) then best = i end
    end
    return best
end

local function tryUnlockNextZone()
    local now = os.clock()
    if now < (state.nextUnlockTryAt or 0) then return false end
    state.nextUnlockTryAt = now + 8

    local best = bestUnlockedZone()
    if best >= 8 then return false end
    local nextZ = best + 1

    local obj = Network.isfn(Modules.G.Instancing, "Get") and Network.gval(Modules.G.Instancing.Get) or nil
    local zInfo = obj and obj.instanceZones and obj.instanceZones[nextZ]
    if zInfo then
        local cost = tonumber(zInfo.CurrencyCost)
        local curId = zInfo.CurrencyId or K.CURRENCY
        if cost and Network.currency(curId) < cost then
            return false
        end
    end

    local ok, res = Network.netInvoke("InstanceZones_RequestPurchase", K.INSTANCE_ID, nextZ)
    return ok and res == true
end

-- 3. Khởi tạo liên kết các module con
local sharedDeps = {
    Modules       = Modules,
    Network       = Network,
    Config        = Config,
    K             = K,
    Webhook       = Webhook,
    inEvent       = inEvent,
    instanceModel = instanceModel,
    petEuids      = ZoneFarm.petEuids,
}

ZoneFarm.init(sharedDeps)
EggHatch.init(sharedDeps)
TreatUpgrades.init(sharedDeps)
CombineHuge.init(sharedDeps)
Daycare.init(sharedDeps)
AutoMail.init(sharedDeps)
BuffsAndGifts.init(sharedDeps)

-- 4. Kích hoạt tối ưu đồ họa, Anti-AFK & Bỏ animation nở trứng
EngineOptim.applyAll(Config.TargetFPS or 5, true)
AntiAFK.installGodModeAntiAfk(Network.netFire, Config.AfkPulseInterval or 35)
EggHatch.installNoHatchAnimation()
AutoMail.startMailLoop(state)

-- 5. Khởi tạo Giao diện AMOLED KizCard
local ui = DashboardGui.create({
    Title = "PS99 HALLOWEEN KAITUN",
    Subtitle = "Auto Farm • Auto Combine Huge • Daycare • Upgrades",
    LogoAssetId = Config.LogoAssetId,
})

local function updateKizhubGui()
    if not ui then return end
    pcall(function()
        if ui.UptimeLabel then
            ui.UptimeLabel.Text = formatUptime()
        end
        if ui.ZoneLabel then
            local z = state.currentZoneNumber or 1
            local zInfo = K.ZONES[z]
            ui.ZoneLabel.Text = string.format("Zone %d/8 (%s)", z, zInfo and zInfo.Name or "...")
        end
        if ui.CombineLabel then
            ui.CombineLabel.Text = state.combineStatus or "Rảnh"
        end
        if ui.MailLabel then
            ui.MailLabel.Text = state.mailStatus or "Rảnh"
        end
        if ui.DaycareLabel then
            ui.DaycareLabel.Text = state.daycareStatus or "Rảnh"
        end
        if ui.CoinsLabel then
            local c = Network.currency(K.CURRENCY) or 0
            ui.CoinsLabel.Text = Network.shorten(c)
        end
        if ui.TreatsLabel then
            local t = Network.currency(K.TREATS) or 0
            ui.TreatsLabel.Text = string.format("%s treats | %d trứng", Network.shorten(t), state.totalEggsHatched or 0)
        end
        if ui.DetailBox then
            local lines = {}
            for _, u in ipairs(K.UPGRADES) do
                local info = TreatUpgrades.upgradeInfo(u)
                local t = info.tier or 0
                local m = info.max or 5
                local status = (t >= m) and "MAX" or (info.cost and (Network.shorten(info.cost) .. " treats") or "...")
                table.insert(lines, string.format("[%s: Lv%d/%d - %s]", u.Name, t, m, status))
            end
            ui.DetailBox.Text = table.concat(lines, "\n")
        end
    end)
end

-- 6. Khởi động Vòng lặp chính (Main Kaitun Loop)
task.spawn(function()
    while state.alive do
        pcall(function()
            if not Config.Enabled then return end
            if not ensureInHalloweenEvent() then return end
            if state.excursion ~= nil then return end

            tryUnlockNextZone()
            local currentZone = bestUnlockedZone()
            state.currentZoneNumber = currentZone

            local zoneData = K.ZONES[currentZone]
            if zoneData and zoneData.Pos then
                local p = Network.playerPos()
                if not p or Network.dist(p, zoneData.Pos) > 15 then
                    Network.teleportTo(zoneData.Pos)
                    task.wait(0.4)
                end
            end

            ZoneFarm.farmZoneBreakables(currentZone)

            local eggInfo = EggHatch.findCustomEggById(zoneData.Egg)
            if currentZone <= 7 then
                local hatchedSoFar = state.zoneHatchCounts[currentZone] or 0
                local maxRequired = Config.First7ZonesHatchTimes or 5

                if hatchedSoFar < maxRequired then
                    if eggInfo then
                        local okH, _ = EggHatch.hatchZoneEgg(eggInfo, state)
                        if okH then
                            state.zoneHatchCounts[currentZone] = hatchedSoFar + 1
                            state.lastSuccessfulHatch = os.clock()
                        else
                            if #ZoneFarm.zoneBreakables(currentZone) > 0 then
                                state.lastSuccessfulHatch = os.clock()
                            end
                        end
                    else
                        if #ZoneFarm.zoneBreakables(currentZone) > 0 then
                            state.lastSuccessfulHatch = os.clock()
                        end
                    end
                else
                    if #ZoneFarm.zoneBreakables(currentZone) > 0 or (Network.currency(K.CURRENCY) or 0) > 0 then
                        state.lastSuccessfulHatch = os.clock()
                    end
                end
            else
                -- Ở Zone 8: Mở trứng liên tục
                if eggInfo then
                    local okH, _ = EggHatch.hatchZoneEgg(eggInfo, state)
                    if okH then
                        state.lastSuccessfulHatch = os.clock()
                    else
                        if #ZoneFarm.zoneBreakables(8) > 0 or (Network.currency(K.CURRENCY) or 0) > 0 then
                            state.lastSuccessfulHatch = os.clock()
                        end
                    end
                else
                    if #ZoneFarm.zoneBreakables(8) > 0 or (Network.currency(K.CURRENCY) or 0) > 0 then
                        state.lastSuccessfulHatch = os.clock()
                    end
                end
            end
        end)
        task.wait(math.max(0.8, Config.HatchDelay or 1.0))
    end
end)

-- Vòng lặp nhặt Orbs (0.8s)
task.spawn(function()
    while state.alive do
        if Config.Enabled and inEvent() then
            pcall(ZoneFarm.collectOrbsTick)
        end
        task.wait(0.8)
    end
end)

-- Vòng lặp Auto-Tap (10Hz)
task.spawn(function()
    pcall(function() Network.netInvoke("AutoTapper_Toggle", true) end)
    local delayTime = (Config.AutoTap and Config.AutoTap.TapDelay) or 0.1
    while state.alive do
        if Config.AutoTap and Config.AutoTap.Enabled and inEvent() and state.excursion == nil then
            pcall(ZoneFarm.runAutoTapTick, state.currentZoneNumber)
        end
        task.wait(delayTime)
    end
end)

-- Vòng lặp kiểm tra nổ Huge / Titanic toàn cục (5s)
task.spawn(function()
    while state.alive do
        pcall(function()
            Webhook.checkNewHugeHatched(Network.getSave, Config.Webhook and Config.Webhook.EventsUrl)
        end)
        task.wait(5)
    end
end)

-- Vòng lặp phụ: Upgrades, Ghép Huge, Daycare, Quà Free & Buffs (6s)
task.spawn(function()
    while state.alive do
        pcall(function()
            if Config.Enabled and inEvent() then
                TreatUpgrades.checkAndRunTreatUpgrades(state)
                CombineHuge.checkAndRunCombine(state)
                Daycare.checkAndRunDaycare(state)
                BuffsAndGifts.checkAndClaimFreeGifts(state)
                BuffsAndGifts.runDelayedBuffs(state)
            end
        end)
        task.wait(6)
    end
end)

-- Vòng lặp cập nhật GUI KizCard (4s)
task.spawn(function()
    while state.alive do
        pcall(updateKizhubGui)
        task.wait(4)
    end
end)

-- Vòng lặp gửi Status Webhook 30 phút (định dạng 1M (+1M), chống spam đồng thời 80 acc)
task.spawn(function()
    local interval = (Config.Webhook and Config.Webhook.StatusInterval) or 1800
    local pName = game:GetService("Players").LocalPlayer.Name or "Player"
    local myHash = 0
    for i = 1, #pName do
        myHash = (myHash * 31 + string.byte(pName, i)) % interval
    end

    local nextStatusSendAt = os.clock() + 60 + (myHash % 90)

    while state.alive do
        task.wait(10)
        local now = os.clock()
        if now >= nextStatusSendAt then
            nextStatusSendAt = now + interval

            pcall(function()
                local wb = Config.Webhook
                if wb and wb.Enabled and wb.StatusUrl and wb.StatusUrl ~= "" then
                    local upStr = formatUptime()
                    local rawCoins = Network.currency(K.CURRENCY) or 0
                    local rawTreats = Network.currency(K.TREATS) or 0
                    local rawHatched = state.totalEggsHatched or 0

                    local lastCoins = state.lastStatusCoins or rawCoins
                    local lastTreats = state.lastStatusTreats or rawTreats
                    local lastHatched = state.lastStatusHatched or rawHatched

                    local deltaCoins = math.max(0, rawCoins - lastCoins)
                    local deltaTreats = math.max(0, rawTreats - lastTreats)
                    local deltaHatched = math.max(0, rawHatched - lastHatched)

                    state.lastStatusCoins = rawCoins
                    state.lastStatusTreats = rawTreats
                    state.lastStatusHatched = rawHatched

                    local coinsDisplay = string.format("%s (+%s)", Network.shorten(rawCoins), Network.shorten(deltaCoins))
                    local treatsDisplay = string.format("%s (+%s)", Network.shorten(rawTreats), Network.shorten(deltaTreats))
                    local hatchedDisplay = string.format("%s (+%s)", Network.shorten(rawHatched), Network.shorten(deltaHatched))

                    local currentZ = state.currentZoneNumber or 1
                    local zoneInfo = K.ZONES[currentZ]
                    local zoneTitle = string.format("Zone %d/8 (%s)", currentZ, zoneInfo and zoneInfo.Name or "Unknown")

                    local statusDesc = string.format(
                        "⏱️ **Thời gian chạy:** `%s`\n" ..
                        "📍 **Khu vực:** `%s`\n" ..
                        "🍬 **Candy Coins:** `%s`\n" ..
                        "🎃 **Treats:** `%s`\n" ..
                        "🥚 **Trứng đã nở:** `%s` quả\n" ..
                        "🛠️ **Ghép Huge:** `%s`\n" ..
                        "📬 **Hòm thư:** `%s`\n" ..
                        "🏡 **Daycare:** `%s`",
                        upStr, zoneTitle, coinsDisplay, treatsDisplay, hatchedDisplay,
                        state.combineStatus or "Rảnh", state.mailStatus or "Rảnh", state.daycareStatus or "Rảnh"
                    )

                    Webhook.sendWebhook("🟢 [STATUS 30' REPORT] " .. pName, statusDesc, 0x00E676, wb.StatusUrl)
                end
            end)
        end
    end
end)

print("[KizHub] Halloween Kaitun Modular System Initialized Successfully!")

return {
    State = state,
    Stop = function()
        state.alive = false
        DashboardGui.destroy()
    end,
}
