-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/main.lua
-- Loader tổng cho Kịch bản AutoRank Kaitun World 1 (Rank 1 -> 11)
-- Nạp: Shared Modules, Network, EngineOptim, AntiAFK, Webhook, DashboardGui
-- Quản lý: Rank Controller, Quest Farm, Quest Hatch, Quest Craft, Progression
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G

-- Trình nạp module an toàn (Hỗ trợ cả Local Workspace & GitHub Raw Fallback)
local GITHUB_REPO_BASE = "https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/refs/heads/main/PS99_KizHub/"

local function ensureParentDirs(filePath)
    if type(makefolder) ~= "function" then return end
    local parts = filePath:gsub("\\", "/"):split("/")
    local current = ""
    for i = 1, #parts - 1 do
        current = current .. (current == "" and "" or "/") .. parts[i]
        local exists = false
        if type(isfolder) == "function" then
            local ok, res = pcall(isfolder, current)
            if ok and res == true then exists = true end
        end
        if not exists then
            pcall(makefolder, current)
        end
    end
end

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
        local exists = false
        if type(isfile) == "function" then
            local ok, res = pcall(isfile, p)
            if ok and res == true then exists = true end
        else
            exists = true
        end
        if exists and type(readfile) == "function" then
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

        -- Tự động lưu cache cục bộ vào Delta workspace
        if content and type(writefile) == "function" then
            pcall(function()
                local localPath = "PS99_KizHub/" .. cleanPath
                ensureParentDirs(localPath)
                writefile(localPath, content)
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
EngineOptim.hideOtherPlayers()
AntiAFK.installGodModeAntiAfk(Network.netFire, 35)

local ui = nil
if Config.ShowGui ~= false then
    ui = DashboardGui.createKizHub({
        Title = "👑 KIZHUB",
        Subtitle = "PET SIMULATOR 99 • AUTORANK KAITUN (WORLD 1 ➔ RANK 11)",
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

-- Cập nhật GUI Dashboard (Chuẩn 100% phong cách KizHub với 👑 & 4 Quests Progress Bars)
local function updateRankGui()
    if not ui then return end
    pcall(function()
        local elapsed = math.floor(os.clock() - State.StartedAt)
        if ui.ElapsedLabel then
            ui.ElapsedLabel.Text = string.format("⏱️ %02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
        end

        local info = State.Rank
        local rNum = info and info.rankNumber or 1
        local rTitle = info and tostring(info.title or "") or "Rank " .. rNum
        local stars = info and info.stars or 0
        local totalStars = info and math.max(1, info.totalStars) or 1
        local starPct = (stars / totalStars) * 100

        if ui.RankValue then
            ui.RankValue.Text = string.format("RANK %d • %s", rNum, rTitle:upper())
        end

        local targetRank = Config.TargetRank or 11
        if ui.TargetRankLabel then
            if rNum >= targetRank then
                ui.TargetRankLabel.Text = "👑 ĐÃ ĐẠT RANK 11!"
                ui.TargetRankLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
                if ui.StatusText then
                    ui.StatusText.Text = "👑 COMPLETED"
                    ui.StatusText.TextColor3 = Color3.fromRGB(255, 215, 0)
                end
            else
                ui.TargetRankLabel.Text = string.format("Mục tiêu: Rank %d (Còn %d)", targetRank, math.max(0, targetRank - rNum))
                ui.TargetRankLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
            end
        end

        if ui.StarsLabel then
            ui.StarsLabel.Text = string.format("⭐ Sao: %s / %s (%.1f%%)", Net.int(stars), Net.int(totalStars), starPct)
        end

        if ui.StarBarFill then
            ui.StarBarFill.Size = UDim2.fromScale(math.clamp(stars / totalStars, 0, 1), 1)
        end

        if ui.RankSubStats then
            local redeemed = info and info.redeemedCount or 0
            local totalRewards = info and (type(info.rewards) == "table" and #info.rewards or 0) or 0
            local rebirths = info and info.rebirths or 0
            local statusDesc = (rNum >= targetRank) and "Hoàn thành" or "Cày sao"
            ui.RankSubStats.Text = string.format("🎁 Quà: %d/%d  |  🔄 Rebirth: %d  |  ⚡ %s", redeemed, totalRewards, rebirths, statusDesc)
        end

        if ui.ZoneLabel then
            ui.ZoneLabel.Text = string.format("Zone: %s (World 1)", tostring(QuestFarm.BestZoneName() or "?"))
        end

        if ui.ActionLabel then
            ui.ActionLabel.Text = string.format("Hành động: %s", tostring(State.Action or "Farming"))
        end

        -- 4 Hàng Nhiệm vụ Rank trực tiếp kèm thanh phần trăm nạp
        local goals = State.Goals or {}
        if ui.QuestRows then
            for i = 1, 4 do
                local r = ui.QuestRows[i]
                if r then
                    local g = goals[i]
                    if g then
                        r.Frame.Visible = true
                        r.Stars.Text = string.format("[⭐ %s]", Net.int(g.Stars or 1))
                        r.Name.Text = tostring(g.title or "Quest")
                        local prog = tonumber(g.Progress) or 0
                        local amt = math.max(1, tonumber(g.Amount) or 1)
                        local pct = math.clamp((prog / amt) * 100, 0, 100)
                        r.ProgressText.Text = string.format("%s / %s (%.0f%%)", Net.int(prog), Net.int(amt), pct)
                        r.BarFill.Size = UDim2.fromScale(math.clamp(prog / amt, 0, 1), 1)
                    else
                        r.Frame.Visible = false
                    end
                end
            end
        end

        -- Thống kê hoạt động
        if ui.TotalsLabel then
            local coins = Net.currency("Coins")
            local diamonds = Net.currency("Diamonds")
            ui.TotalsLabel.Text = string.format(
                "💰 Xu: %s  |  💎 Gems: %s  |  🥚 Trứng: %s",
                Net.shorten(coins),
                Net.shorten(diamonds),
                Net.shorten(State.Counters.Hatched or 0)
            )
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

    -- Thực thi Quests Potion, Enchant, Fruit, Flag (3.5s)
    SpawnLoop("quest items", function()
        QuestItems.ItemTick(State)
    end, 3.5)

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

    -- [TẮT THEO YÊU CẦU]: Không mua slot pet hay egg
    if Config.AutoOpenSlots == true then
        SpawnLoop("open slots", function()
            Progression.autoOpenSlots(State)
        end, 15)
    end

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
