-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/main.lua
-- Loader tổng cho Kịch bản AutoRank Kaitun World 1 (Rank 1 -> 11)
-- Nạp: Shared Modules, Network, EngineOptim, AntiAFK, Webhook, DashboardGui
-- Quản lý: Rank Controller, Quest Farm, Quest Hatch, Quest Craft, Progression
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
        if type(readfile) == "function" then
            local ok, data = pcall(readfile, p)
            if ok and type(data) == "string" and #data > 0 then
                content = data
                break
            end
        end
    end

    -- Fallback: Tự động tải từ GitHub Raw nếu máy/VPS/Mobile (Delta) chưa có sẵn file local
    if not content then
        local remoteUrl = GITHUB_REPO_BASE .. cleanPath
        if type(game.HttpGet) == "function" then
            local ok, data = pcall(game.HttpGet, game, remoteUrl)
            if ok and type(data) == "string" and #data > 0 then
                content = data
            end
        end
        if not content then
            local reqFn = (type(request) == "function" and request)
                or (type(http_request) == "function" and http_request)
                or (type(http) == "table" and type(http.request) == "function" and http.request)
                or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
            if reqFn then
                local ok, resp = pcall(reqFn, { Url = remoteUrl, Method = "GET" })
                if ok and type(resp) == "table" and type(resp.Body) == "string" and #resp.Body > 0 then
                    content = resp.Body
                end
            end
        end

        -- Tự động lưu cache cục bộ trên Mobile (Delta) nếu executor hỗ trợ
        if content and type(writefile) == "function" then
            pcall(function()
                if type(makefolder) == "function" then
                    pcall(makefolder, "PS99_KizHub")
                    local parts = cleanPath:split("/")
                    if #parts > 1 then
                        pcall(makefolder, "PS99_KizHub/" .. parts[1])
                    end
                end
                pcall(writefile, "PS99_KizHub/" .. cleanPath, content)
            end)
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

-- 1. Nạp Shared Modules
local Modules       = import("Shared/Modules.lua")
local Network       = import("Shared/Network.lua")
local EngineOptim   = import("Shared/EngineOptim.lua")
local AntiAFK       = import("Shared/AntiAFK.lua")
local Webhook       = import("Shared/Webhook.lua")
local DashboardGui  = import("Shared/DashboardGui.lua")

Network.bindModules(Modules.G)

-- 2. Nạp AutoRank Modules
local ConfigData     = import("AutoRankKaitun/Config.lua")
local Config         = ConfigData.Config
local RankData       = import("AutoRankKaitun/RankData.lua")
local QuestFarm      = import("AutoRankKaitun/QuestFarm.lua")
local QuestHatch     = import("AutoRankKaitun/QuestHatch.lua")
local QuestCraft     = import("AutoRankKaitun/QuestCraft.lua")
local QuestItems     = import("AutoRankKaitun/QuestItems.lua")
local Progression    = import("AutoRankKaitun/Progression.lua")
local RankController = import("AutoRankKaitun/RankController.lua")

-- Đặt Webhook mặc định
Webhook.setDefaultUrl(Config.Webhook and Config.Webhook.Url)

-- 3. Trạng thái toàn cục của AutoRank
local State = {
    Alive = true,
    Enabled = Config.AutoRankEnabled ~= false,
    StartedAt = os.clock(),
    Rank = nil,
    Goals = {},
    GoalsByType = {},
    Plan = { Hatch = false, HatchReasons = {}, HatchEggOnly = false, HatchRemaining = nil },
    Action = "starting",
    Counters = { Hatched = 0, Claimed = 0, Crafted = 0, ItemsUsed = 0, FarmTicks = 0, EventTargets = 0 },
    WorldSwitching = false,
    WorldSwitchAt = 0,
    WorldMismatch = false,
    World = 1,
    Hopping = false,
    HatchSession = false,
    ReturnAfterHatch = nil,
    LastRank = nil,
    ClaimedAt = {},
    ClaimAttempts = {},
    PendingClaims = {},
    TrackCompleteLoggedRank = nil,
    TrackCompleteAt = nil,
    RankUpFiredRank = nil,
    LastZoneBuyAt = 0,
    CraftHatchReason = nil,
    LastEventSpawn = {},
    EventBackoffUntil = {},
    FlagRetryAt = 0,
    FarmPets = 0,
    FarmTargets = 0,
    Queued = false,
    Rank11WebhookSent = false,
    StarterPetsPicked = false,
    LastStarterPetCheckAt = 0,
    LastSlotPurchaseAt = 0,
    NextClaimGiftsAt = 0,
    BlackoutVisible = Config.BlackoutGui ~= false,
}

-- 4. Khởi tạo liên kết các module con
local autoRankDeps = {
    Modules          = Modules,
    Network          = Network,
    Config           = Config,
    RankData         = RankData,
    Webhook          = Webhook,
    BestZone         = QuestFarm.BestZone,
    BestZoneId       = QuestFarm.BestZoneId,
    BestZoneName     = QuestFarm.BestZoneName,
    CurrentWorld     = QuestFarm.CurrentWorld,
    EnsureInBestZone = QuestFarm.EnsureInBestZone,
    BestEgg          = QuestHatch.BestEgg,
    MaxHatch         = QuestHatch.MaxHatch,
    HatchAmount      = QuestHatch.HatchAmount,
    CanHatchEgg      = QuestHatch.CanHatchEgg,
}

QuestFarm.init(autoRankDeps)
QuestHatch.init(autoRankDeps)
QuestCraft.init(autoRankDeps)
QuestItems.init(autoRankDeps)
Progression.init(autoRankDeps)
RankController.init(autoRankDeps)

-- 5. Kích hoạt tối ưu đồ họa, Anti-AFK & Giao diện Dashboard
if Config.Disable3DRendering == false then
    EngineOptim.restoreNormal(Config.TargetFPS or 60)
else
    EngineOptim.applyAll(Config.TargetFPS or 5, true)
end
AntiAFK.installGodModeAntiAfk(Network.netFire, 35)

local ui = nil
if Config.ShowGui ~= false then
    ui = DashboardGui.create({
        Title = "PS99 AUTORANK WORLD 1 (1 -> 11)",
        Subtitle = "Auto Quest Farm • Auto Hatch • Auto Craft • Auto Slots",
        LogoAssetId = "rbxassetid://10709791437",
        ToggleKey = Config.GuiToggleKey,
        Blackout = Config.BlackoutGui ~= false,
    })
else
    DashboardGui.destroy()
    pcall(function()
        local rs = game:GetService("RunService")
        if rs:IsClient() and type(rs.Set3dRenderingEnabled) == "function" then
            rs:Set3dRenderingEnabled(true)
        end
    end)
end

-- Hàm SpawnLoop bảo vệ luồng nền
local function SpawnLoop(name, tickFn, intervalFn)
    task.spawn(function()
        while State.Alive do
            local ok, err = pcall(tickFn)
            if not ok then
                task.wait(1)
            end
            if not State.Alive then break end

            local iv = 1
            if type(intervalFn) == "function" then
                local okI, resI = pcall(intervalFn)
                iv = okI and tonumber(resI) or 1
            elseif type(intervalFn) == "number" then
                iv = intervalFn
            end
            task.wait(math.max(0.05, iv))
        end
    end)
end

-- Cập nhật GUI Dashboard
local function updateRankGui()
    if not ui then return end
    pcall(function()
        local elapsed = math.floor(os.clock() - State.StartedAt)
        if ui.UptimeLabel then
            ui.UptimeLabel.Text = string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
        end

        local info = State.Rank
        if ui.ZoneLabel then
            ui.ZoneLabel.Text = QuestFarm.BestZoneName()
        end
        if ui.CombineLabel then
            local rNum = info and info.rankNumber or 1
            local rTitle = info and tostring(info.title or "") or "Rank " .. rNum
            ui.CombineLabel.Text = string.format("Rank %d - %s", rNum, rTitle)
        end
        if ui.MailLabel then
            local stars = info and info.stars or 0
            local totalStars = info and math.max(1, info.totalStars) or 1
            ui.MailLabel.Text = string.format("%s / %s Sao (%.1f%%)", Net.int(stars), Net.int(totalStars), (stars / totalStars) * 100)
        end
        if ui.DaycareLabel then
            local targetRank = Config.TargetRank or 11
            local rNum = info and info.rankNumber or 1
            ui.DaycareLabel.Text = (rNum >= targetRank) and "👑 ĐẠT RANK 11!" or string.format("Mục tiêu: Rank %d (Còn %d)", targetRank, math.max(0, targetRank - rNum))
        end
        if ui.CoinsLabel then
            local coins = Net.currency("Coins")
            local diamonds = Net.currency("Diamonds")
            ui.CoinsLabel.Text = string.format("%s Coins | %s Gems", Net.shorten(coins), Net.shorten(diamonds))
        end
        if ui.TreatsLabel then
            ui.TreatsLabel.Text = string.format("Trứng: %s | Quà: %s | Craft: %s", Net.shorten(State.Counters.Hatched or 0), Net.shorten(State.Counters.Claimed or 0), Net.shorten(State.Counters.Crafted or 0))
        end
        if ui.DetailBox then
            local lines = {}
            lines[#lines + 1] = "HÀNH ĐỘNG: " .. tostring(State.Action or "Đang farm...")
            lines[#lines + 1] = "----------------------------------------"
            local goals = State.Goals or {}
            if #goals == 0 then
                lines[#lines + 1] = "• Đang quét dữ liệu nhiệm vụ Rank..."
            else
                for i, goal in ipairs(goals) do
                    if i <= 5 then
                        local prog = Net.int(goal.Progress or 0)
                        local target = Net.int(goal.Amount or 0)
                        lines[#lines + 1] = string.format("• [%d★] %s (%s/%s)", goal.Stars or 0, tostring(goal.title or ("Goal " .. tostring(goal.Type))), prog, target)
                    end
                end
            end
            ui.DetailBox.Text = table.concat(lines, "\n")
        end
    end)
end

-- 6. Khởi động toàn bộ luồng xử lý
local function StartThreads()
    -- Bộ điều phối Rank (1s)
    SpawnLoop("controller", function()
        RankController.ControllerTick(State)
        Progression.HandleBlockedAndZones(State.Rank, State)
    end, function() return Config.ControllerTick or 1.0 end)

    -- Farm bãi vỡ (0.25s)
    SpawnLoop("farm", function()
        QuestFarm.FarmTick(State)
    end, function() return Config.FarmTick or 0.25 end)

    -- Mở trứng theo Quest (0.75s)
    SpawnLoop("hatch", function()
        QuestHatch.HatchTick(State)
    end, function() return Config.HatchDelay or 0.75 end)

    -- Fast-tap mở trứng (0.12s)
    SpawnLoop("egg reveal", function()
        QuestHatch.AutoTapEgg(State)
    end, 0.12)

    -- Ghép Pet Gold / Rainbow (4.0s)
    SpawnLoop("craft", function()
        QuestCraft.CraftTick(State)
    end, function() return Config.CraftTick or 4.0 end)

    -- Sử dụng Items sự kiện (3.0s)
    SpawnLoop("events", function()
        QuestItems.EventTick(State)
    end, function() return Config.EventTick or 3.0 end)

    -- Tự chọn starter pets cho acc mới: Chạy luồng độc lập, khi xong hoặc acc đã có pet là HỦY LUỒNG VĨNH VIỄN
    task.spawn(function()
        for attempt = 1, 10 do
            if not State.Alive or State.StarterPetsPicked then break end
            local done = false
            pcall(function()
                done = Progression.autoPickStarterPets(State)
            end)
            if done or State.StarterPetsPicked then
                State.StarterPetsPicked = true
                break
            end
            task.wait(2.5)
        end
        State.StarterPetsPicked = true
    end)

    -- Tự mở Slot Pet và Slot Trứng bằng Diamonds (15.0s)
    SpawnLoop("open slots", function()
        Progression.autoOpenSlots(State)
    end, 15)

    -- Tự nhận Free Gifts 12 mốc (60.0s)
    SpawnLoop("free gifts", function()
        Progression.checkAndClaimFreeGifts(State)
    end, 60)

    -- Kiểm tra nổ Huge / Titanic (5.0s)
    SpawnLoop("check huge", function()
        Webhook.checkNewHugeHatched(Network.getSave, Config.Webhook and Config.Webhook.Url)
    end, 5)

    -- [1. Auto Tap / Click Breakables]: 10Hz song song cùng pet
    if Config.AutoTapBreakables ~= false then
        pcall(QuestFarm.enableAutoTapper)
        SpawnLoop("auto tap", function()
            QuestFarm.AutoTapTick(State)
        end, function() return Config.AutoTapDelay or 0.1 end)
    end

    -- [2. Infinite / Max Pet Speed]: Hook CalculateSpeedMultiplier math.huge
    if Config.MaxPetSpeed ~= false then
        pcall(function() QuestFarm.installMaxPetSpeed(State) end)
    end

    -- [3. Orb Collector]: Tự động quét và hút sạch ngọc & lootbags rơi (0.35s)
    if Config.AutoCollectOrbs ~= false then
        SpawnLoop("collect orbs", function()
            QuestFarm.CollectOrbsTick(State)
        end, function() return Config.OrbCollectInterval or 0.35 end)
    end

    -- [4. Disable Egg Animation]: Bỏ qua cutscene ấp trứng
    if Config.DisableEggAnimation ~= false then
        pcall(QuestHatch.installNoEggAnimation)
    end

    -- [5. Auto Buffs]: Tự cắn Trái cây, Potion, Đồ chơi định kỳ
    local bCfg = Config.AutoBuffs
    if bCfg and bCfg.Enabled ~= false then
        if bCfg.Fruits ~= false then
            SpawnLoop("buff fruits", function()
                QuestItems.AutoBuffFruits(State)
            end, function() return bCfg.FruitInterval or 60 end)
        end
        if bCfg.Potions ~= false then
            SpawnLoop("buff potions", function()
                QuestItems.AutoBuffPotions(State)
            end, function() return bCfg.PotionInterval or 90 end)
        end
        if bCfg.Toys ~= false then
            SpawnLoop("buff toys", function()
                QuestItems.AutoBuffToys(State)
            end, function() return bCfg.ToyInterval or 180 end)
        end
    end

    -- Cập nhật Dashboard GUI (1.0s)
    SpawnLoop("gui", function()
        updateRankGui()
    end, 1.0)
end

-- Listener bắt Breakable mới xuất hiện để tối ưu thời gian phản hồi
local function installBreakableFastPath()
    task.spawn(function()
        local folder = nil
        local t0 = os.clock()
        while State.Alive and not folder and os.clock() - t0 < 60 do
            folder = QuestFarm.BreakablesFolder()
            if not folder then task.wait(1) end
        end
        if folder and State.Alive then
            folder.ChildAdded:Connect(function(child)
                QuestFarm.OnBreakableAdded(child, State)
            end)
        end
    end)
end

installBreakableFastPath()
StartThreads()

print("[KizHub] AutoRank World 1 Modular System Initialized Successfully!")

return {
    State = State,
    Config = Config,
    Stop = function()
        State.Alive = false
        DashboardGui.destroy()
    end,
}
