--[[
    Pet Simulator 99 - Pumpkin Patch Tycoon! Kaitun Core
    Target: Fast full automation (Buttons Rush, Smart Farm, Keep/Lock/Stock, Merchant, Upgrades, Boosts/Cocoa, Gifts, Zone 5 Egg Hatch, Anti-AFK, Pet Speed, Map & Render Optimizer)
]]

-- ============================================================================
-- 0. RE-EXECUTION TEARDOWN GUARD
-- ============================================================================
local GEN_KEY = "_PumpkinTycoonKaitun"
local prevEnv = getgenv()[GEN_KEY]
if type(prevEnv) == "table" and type(prevEnv.Teardown) == "function" then
    pcall(prevEnv.Teardown)
    task.wait(0.15)
end

-- ============================================================================
-- 1. CONFIGURATION
-- ============================================================================
local DEFAULT_CONFIG = {
    Enabled = true,
    Debug = true,

    -- Instance & Onboarding
    AutoJoin = true,
    AutoTutorial = true,

    -- Anti-AFK (Roblox 20m + PS99 Idle Tracking)
    AntiAFK = true,
    AntiAFKRoblox = true,           -- Periodic VirtualUser pulse (< 120s) + LocalPlayer.Idled fallback against 20m kick
    AntiAFKRobloxPulseInterval = 45,-- Seconds between proactive VirtualUser pulses
    AntiAFKP99 = true,              -- Resets PS99 Scripts.Core["Idle Tracking"] before 10s + guards Move Server
    AntiAFKP99PulseInterval = 6.5,  -- Seconds between engine-counted inputs (< 10s AntiAFKStartServerTimerAt)
    BlockNativeMoveServer = true,   -- Suppress "Move Server", "Idle Tracking: Engine Idle", "Idle Tracking: Update Timer"
    SpoofIdleFocusTrue = true,      -- Force "Idle Tracking: Focus Changed" arg1 = true when unfocused

    -- Phase Progression (A1)
    RushButtonsFirst = true,        -- Hold Coins purely for Buttons + Completion before spending on Eggs/Merchant/Cocoa
    AutoBuyButtons = true,
    AutoCompleteTycoon = true,      -- Invokes BT_Settle on 100% Part 1 completion for 20x Flannel Gift

    -- Farm & Combat Speed
    AutoFarm = true,
    AutoTap = true,
    AutoPetFocus = true,
    AutoSpreadZoneBreakables = true, -- Spread each pet onto its own highest-zone breakable; focus all pets on BonusChest/Pedestal
    AutoTeleportToTarget = true,
    AutoBuffPetSpeed = true,        -- Overrides LocalPlayer CalculateSpeedMultiplier() -> PetSpeedMultiplier
    PetSpeedMultiplier = 999,       -- Target speedMult (PetRendering multiplies petSpeed * petSpeedMult)
    FarmOrchardAndHay = true,
    AutoCollectOrbs = true,         -- Collects both Orbs and Lootbags from __THINGS.Orbs via "Orbs: Collect"
    TapInterval = 0.04,             -- Fast tap cadence when breakable is inside reach
    FarmLoopInterval = 0.10,        -- Pet & movement target refresh interval
    OrbSweepInterval = 0.10,

    -- Keep / Lock / Stock / Merchant (A2: Mua TẤT CẢ Pumpkin & ĐẬP HẾT)
    BreakAllPumpkins = true,         -- Mua tất cả các loại bí ngô và ĐẬP SẠCH (không khóa giữ bí)
    KeepRung = 0,                   -- 0 = Không giữ quả nào, cho phép đập sạch
    LockMinRung = 99,               -- Không khóa bất kỳ quả bí nào
    MinFarmPedestals = 8,           -- Toàn bộ 8 bệ thờ đều ưu tiên đập bí
    AutoLockUpgradeSwap = false,
    AutoPlaceStock = true,          -- Đặt bí ngô mua từ merchant lên bệ thờ ngay lập tức để đập
    AutoBuyMerchant = true,
    MerchantRequireButtonsComplete = false,
    MerchantActivateCoins = 100000, -- Có 100k Coins là mua ngay
    MerchantMinSpareCoins = 50000,  -- Giữ 50k Coins dự phòng
    KeepServerAutoMerchantOff = true,
    MerchantBandOrder = { "ExoticPlus", "MythicalPlus", "LegendaryPlus", "EpicPlus", "RarePlus" },
    AllowedMerchantBands = {
        ExoticPlus = true,
        MythicalPlus = true,
        LegendaryPlus = true,
        EpicPlus = true,
        RarePlus = true,
    },

    -- Free Gifts (12 Mốc Quà Miễn Phí Tích Lũy Gems)
    AutoClaimFreeGifts = true,

    -- Auto Buffs Phụ Trợ (Trái Cây, Potions, Đồ Chơi - TUYỆT ĐỐI KHÔNG CẮM CỜ)
    AutoBuffs = {
        Enabled = true,
        Fruits = true,
        Potions = true,
        Toys = true,
        NoFlags = true,
    },

    -- Bảng GUI Mini (Siêu nhẹ cho 80 acc)
    ShowGui = true,

    -- Upgrades with PumpkinTokens (A3)
    AutoUpgrades = true,
    UpgradeTier1CheapFirst = true,  -- Buy all Tier 1 upgrades <= UpgradeCheapTier1MaxBaseCost before Priority Tier 2+
    UpgradeCheapTier1MaxBaseCost = 50,
    UpgradePriority = {
        "SpawnLuck",
        "PumpkinCoins",
        "PumpkinDamage",
        "RespawnSpeed",
        "ChaseOdds",
        "EggLuck",
        "StockSlots",
        "MerchantLuck",
    },
    UpgradeCheapCatchupRatio = 0.40, -- Buy lower-priority track if cost <= 40% of blocked top priority (0 = strict linear)

    -- Boosts, Hot Cocoa Stand & Flannel Gifts (A4)
    AutoConsumeBoosts = true,
    BoostRefreshSeconds = 15,
    AllowedConsumableBoosts = {
        ["Patch Coin Boost"] = true,
        ["Pumpkin Damage Boost"] = true,
        ["Island Luck Boost"] = true,
    },

    AutoCocoaStand = true,
    CocoaRequireButtonsComplete = true,
    CocoaActivateCoins = 300000000,  -- Activate Hot Cocoa Stand at >= 300M Patch Coins
    CocoaMaintainMinutes = 2,
    CocoaBuyStepMinutes = 2,         -- Buy 1-2 minutes per refresh cycle while maintaining >= CocoaMinSpareCoins
    CocoaMinSpareCoins = 150000000,  -- Keep at least 150M Patch Coins spare after Cocoa purchase
    CocoaAxes = { "Coins", "Damage", "IslandLuck" },

    AutoOpenGifts = true,
    GiftBatchAmount = 8,            -- Server clamp [1, 8]

    -- Egg Hatching (Smart Early Bootstrap + Post-Buttons Zone 5)
    AutoHatch = true,
    AutoEarlyHatchForDamage = true, -- Hatch unlocked eggs during rush when slots < MaxPetsEquipped or power < egg common pet
    EarlyHatchMaxPerEgg = 8,        -- Cap early bootstrap hatches per unlocked egg tier
    EarlyHatchReserveCoins = true,  -- Temporarily reserve 1x egg cost during early bootstrap before buying buttons
    AutoEquipBestPets = true,       -- Ensure AutoEquipPets / EquipBest equips newly hatched stronger pets immediately
    TargetEggName = "Golden Grove Egg",
    FallbackHighestUnlockedEgg = true,
    HatchDisableAnimation = true,
    HatchMinBatchMultiplier = 1,    -- Start hatching when Coins >= cost * maxBatch * mult (or >= cost * 1)
    HatchMoveMaxDist = 14,
    HatchCooldown = 0.05,

    -- Pet Crafting (Gold & Rainbow Machine)
    AutoMakeGold = true,                -- Automatically craft Normal pets -> Golden at plot GoldMachine
    AutoMakeRainbow = true,             -- Automatically craft Golden pets -> Rainbow at plot RainbowMachine
    CraftEventPetsOnly = true,          -- Restrict crafting to PumpkinTycoon event pets
    CraftProtectShiny = true,           -- Skip Shiny pets (sh == true)
    CraftProtectLocked = true,          -- Skip locked pets (_lk == true / IsLocked())
    CraftProtectEquipped = true,        -- Subtract currently equipped stack counts via PetCmds.GetEquipped()
    CraftReserveMinTeamSlots = true,    -- Preserve at least PetCmds.GetMaxEquipped() total pets across inventory
    CraftRequireButtonComplete = true,  -- Require plot GoldMachine / RainbowMachine button to be owned before crafting
    CraftMinBatch = 1,                  -- Minimum crafted output pets per stack before triggering a machine trip
    CraftMaxBatchPerInvoke = 25,        -- Max crafted pets per single Network.Invoke call (chunks larger stacks)
    CraftCheckIntervalSec = 1.0,        -- Seconds between craft eligibility scans
    CraftHatchYieldIntervalSec = 4.0,   -- Max seconds continuous AutoHatch runs before yielding to pending crafts
    CraftFailCooldownSec = 10,          -- Cooldown backoff after a failed machine invoke

    -- Optional Event Pass (disabled by default; enable when desired)
    AutoEventPass = false,

    -- Map & Render Optimization
    OptimizeMap = false,                 -- Master toggle for world cleanup + visual hiding + lighting/FX reduction
    StripWorldClutter = false,           -- Destroy unused world maps/props (PSX Portal, Border, Ornaments, unused Instances, __DEBRIS)
    HideIslandVisuals = false,           -- Make PumpkinTycoonIslands, __THINGS.Plots, Pads, Pumpkins invisible + strip decals/FX
    HideEntityVisuals = false,           -- Make Breakables, CustomEggs, Pets, Orbs & other players invisible (keeps hitboxes/data)
    OptimizeLightingAndEffects = false,  -- Disable Shadows/Sky/Bloom/Atmosphere/PostEffects/Particles and Terrain decoration
    SafeFloorEnabled = true,            -- Maintain invisible backup Baseplate under own plot to prevent void falls
    OptimizeScanInterval = 2.0,         -- Seconds between low-cost sweeps for newly streamed islands/players

    -- Webhook & AutoMail (KizHub)
    AutoMailHuge = true,
    MailRecipient = "Kizmoii_VNG",
    MailRetryInterval = 1800,
    MailCooldownSec = 10,
    WebhookUrl = "",
    NotifyHuge = true,
    NotifyTitanic = true,

    -- Cấu hình hiệu năng & FPS (Non-Opti 60FPS vs Opti 5FPS)
    CPUSaver = false,
    TargetFPS = 60,
}

local function ApplyConfigDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                local clone = {}
                ApplyConfigDefaults(clone, v)
                dst[k] = clone
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            ApplyConfigDefaults(dst[k], v)
        end
    end
end

local genv = (type(getgenv) == "function" and getgenv()) or _G
local Config = type(genv.PumpkinTycoonConfig) == "table" and genv.PumpkinTycoonConfig or (type(genv.KaitunConfig) == "table" and genv.KaitunConfig or {})
ApplyConfigDefaults(Config, DEFAULT_CONFIG)
if genv.MailRecipient and type(genv.MailRecipient) == "string" then
    Config.MailRecipient = genv.MailRecipient
end
if genv.WebhookUrl and type(genv.WebhookUrl) == "string" then
    Config.WebhookUrl = genv.WebhookUrl
elseif genv.EventsUrl and type(genv.EventsUrl) == "string" then
    Config.WebhookUrl = genv.EventsUrl
end
genv.PumpkinTycoonConfig = Config
genv.KaitunConfig = Config

-- ============================================================================
-- 2. SERVICES & RUNTIME STATE
-- ============================================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local okVim, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not okVim then
    VirtualInputManager = nil
end
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local SessionToken = HttpService:GenerateGUID(false)
local Connections = {}

local Runtime = {
    Token = SessionToken,
    Running = true,
    Stats = {
        StartTime = os.time(),
        Phase = "Initializing",
        Coins = 0,
        Tokens = 0,
        ButtonsDone = 0,
        ButtonsTotal = 0,
        Part1Complete = false,
        CompletedClaimed = false,
        IslandLuck = 0,
        ActiveTargetUid = nil,
        ActiveTargetDesc = "None",
        IsHatching = false,
        EggsHatched = 0,
        EarlyEggsHatched = 0,
        GoldCrafted = 0,
        RainbowCrafted = 0,
        ShinyCrafted = 0,
        TeamPowerWeakest = 0,
        TeamPowerBest = 0,
        GiftsOpened = 0,
        PetSpeedMult = 1,
        AfkPulsesRoblox = 0,
        AfkPulsesP99 = 0,
        BlockedMoveServer = 0,
        BlockedIdleTelemetry = 0,
        MapDestroyedCount = 0,
        VisualsHiddenCount = 0,
    },
    Cache = {
        IslandBox = nil,
        IslandBoxAt = 0,
        Buttons = nil,
        ButtonsAt = 0,
        CriticalButtons = nil,
        EggCostCache = {},
        EggBasePowerCache = {},
        EarlyHatchedByEgg = {},
        ReserveEarlyEggCost = 0,
        LastEquipBestAt = 0,
        TeamPowerSnapshot = nil,
        TeamPowerSnapshotAt = 0,
        BoostConsumeCooldown = {},
        LastKeepInvoked = nil,
        LastServerAutoMerchant = nil,
        LastAutoPlace = nil,
        PetSpeedHookActive = false,
        PetSpeedHookWrapper = nil,
        AntiAfkHookActive = false,
        NetFireHookTarget = nil,
        NetFireOrig = nil,
        LastRobloxAfkPulseAt = 0,
        LastP99AfkPulseAt = 0,
        LastMoveServerBlockLogAt = 0,
        SavedLightingState = nil,
        SafeFloorPart = nil,
        MapOptimizerInitialized = false,
        LastOptimizeScanAt = 0,
        LastButtonsDoneForDecor = -1,
        MoveLockUntil = 0,
        MachineSessionDepth = 0,
        HatchYieldUntil = 0,
        HatchInFlight = false,
        LastTeleportAt = 0,
        LastCocoaFailAt = 0,
        LastMerchantFailAt = 0,
        LastCraftCheckAt = 0,
        LastCraftTripAt = 0,
        PendingCraftReadySince = 0,
        CraftFailUntil = { Gold = 0, Rainbow = 0 },
        CraftEventPetSet = nil,
    },
}

local function IsRunning()
    return Runtime.Running and Config.Enabled and Runtime.Token == SessionToken
end

local function Log(level, fmt, ...)
    if level == "DEBUG" and not Config.Debug then
        return
    end
    local ok, text = pcall(string.format, fmt, ...)
    print(string.format("[PumpkinKaitun][%s] %s", level, ok and text or tostring(fmt)))
end

local function BindConn(signal, fn)
    if not signal then
        return nil
    end
    local conn = signal:Connect(fn)
    table.insert(Connections, conn)
    return conn
end

-- ============================================================================
-- 3. MODULE RESOLUTION
-- ============================================================================
local Library = ReplicatedStorage:WaitForChild("Library", 20)

local function SafeRequire(parent, ...)
    local cur = parent
    for _, childName in ipairs({ ... }) do
        if not cur then
            return nil
        end
        cur = cur:FindFirstChild(childName) or cur:WaitForChild(childName, 3)
    end
    if not cur then
        return nil
    end
    local ok, mod = pcall(require, cur)
    return ok and mod or nil
end

local Modules = {
    -- Core Client & Util
    Network = SafeRequire(Library, "Client", "Network"),
    Signal = SafeRequire(Library, "Signal"),
    Save = SafeRequire(Library, "Client", "Save"),
    FFlags = SafeRequire(Library, "Client", "FFlags") or SafeRequire(Library, "Universal", "FFlags"),
    Variables = SafeRequire(Library, "Variables") or SafeRequire(Library, "Client", "Variables"),
    CurrencyCmds = SafeRequire(Library, "Client", "CurrencyCmds"),
    BoostCmds = SafeRequire(Library, "Client", "BoostCmds"),
    InstancingCmds = SafeRequire(Library, "Client", "InstancingCmds"),
    ClientPlot = SafeRequire(Library, "Client", "PlotCmds", "ClientPlot"),
    BreakableFrontend = SafeRequire(Library, "Client", "BreakableFrontend"),
    AutoFarmCmds = SafeRequire(Library, "Client", "AutoFarmCmds"),
    PlayerPet = SafeRequire(Library, "Client", "PlayerPet"),
    PetCmds = SafeRequire(Library, "Client", "PetCmds"),
    MasteryCmds = SafeRequire(Library, "Client", "MasteryCmds"),
    MachineCmds = SafeRequire(Library, "Client", "MachineCmds"),
    DaycareCmds = SafeRequire(Library, "Client", "DaycareCmds"),
    ExclusiveDaycareCmds = SafeRequire(Library, "Client", "ExclusiveDaycareCmds"),
    TabController = SafeRequire(Library, "Client", "TabController"),
    CustomEggsCmds = SafeRequire(Library, "Client", "CustomEggsCmds"),
    EggCmds = SafeRequire(Library, "Client", "EggCmds"),
    EventUpgradeCmds = SafeRequire(Library, "Client", "EventUpgradeCmds"),
    LootboxLocation = SafeRequire(Library, "Client", "LootboxCmds", "LocationFinder"),
    Directory = SafeRequire(Library, "Directory"),
    Items = SafeRequire(Library, "Items"),
    PetItem = SafeRequire(Library, "Items", "PetItem"),
    LootboxItem = SafeRequire(Library, "Items", "LootboxItem"),

    -- PumpkinTycoon Types & Utils
    PumpkinTycoon = SafeRequire(Library, "Types", "PumpkinTycoon"),
    ButtonsTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Buttons"),
    LadderTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Ladder"),
    MerchantTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Merchant"),
    UpgradesTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Upgrades"),
    LootboxTypes = SafeRequire(Library, "Types", "Lootboxes"),

    PumpkinButtonsUtil = SafeRequire(Library, "Util", "PumpkinTycoonButtons"),
    PumpkinUpgradesUtil = SafeRequire(Library, "Util", "PumpkinTycoonUpgrades"),
    PumpkinBoostsUtil = SafeRequire(Library, "Util", "PumpkinTycoonBoosts"),
    PumpkinCocoaUtil = SafeRequire(Library, "Util", "PumpkinTycoonCocoa"),
    PumpkinEarnUtil = SafeRequire(Library, "Util", "PumpkinTycoonEarn"),
    PumpkinGiftUtil = SafeRequire(Library, "Util", "PumpkinTycoonGift"),

    -- Optional Event Pass
    EventPassTypes = SafeRequire(Library, "Types", "EventPass"),
    EventPassUtil = SafeRequire(Library, "Util", "EventPassUtil"),
}

-- EventCmds submodules (loaded via PumpkinTycoonCmds if available)
local PT_Cmds = SafeRequire(Library, "Client", "PumpkinTycoonCmds")
local PT_Buttons = PT_Cmds and SafeRequire(Library, "Client", "PumpkinTycoonCmds", "Buttons")
local PT_AutoBreak = PT_Cmds and SafeRequire(Library, "Client", "PumpkinTycoonCmds", "AutoBreak")

local NET_FIRE_HOOK_KEY = "_PumpkinTycoonKaitun_NetFireHookTarget"

local function PulseRobloxAntiAfk()
    if not VirtualUser then
        return false
    end
    local ok = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
    if ok then
        Runtime.Cache.LastRobloxAfkPulseAt = os.clock()
        Runtime.Stats.AfkPulsesRoblox = (Runtime.Stats.AfkPulsesRoblox or 0) + 1
    end
    return ok
end

local function PulseP99AntiAfk()
    if not VirtualInputManager or not VirtualInputManager.SendKeyEvent then
        return false
    end
    if UserInputService and UserInputService.GetFocusedTextBox then
        local okTb, focusedBox = pcall(UserInputService.GetFocusedTextBox, UserInputService)
        if okTb and focusedBox ~= nil then
            return false
        end
    end
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
    end)
    if ok then
        Runtime.Cache.LastP99AfkPulseAt = os.clock()
        Runtime.Stats.AfkPulsesP99 = (Runtime.Stats.AfkPulsesP99 or 0) + 1
    end
    return ok
end

local function RestoreAntiAfkNetworkHook()
    local hookedTarget = Runtime.Cache.NetFireHookTarget or getgenv()[NET_FIRE_HOOK_KEY]
    if hookedTarget and type(isfunctionhooked) == "function" and type(restorefunction) == "function" then
        local okH, hooked = pcall(isfunctionhooked, hookedTarget)
        if okH and hooked then
            pcall(restorefunction, hookedTarget)
        end
    end
    Runtime.Cache.AntiAfkHookActive = false
    Runtime.Cache.NetFireHookTarget = nil
    Runtime.Cache.NetFireOrig = nil
    getgenv()[NET_FIRE_HOOK_KEY] = nil
end

local function EnsureAntiAfkNetworkHook()
    if not Config.AntiAFK or not Config.AntiAFKP99 then
        if Runtime.Cache.AntiAfkHookActive then
            RestoreAntiAfkNetworkHook()
        end
        return
    end
    local net = Modules.Network
    if not net or type(net.Fire) ~= "function" or type(hookfunction) ~= "function" then
        return
    end
    if Runtime.Cache.AntiAfkHookActive and Runtime.Cache.NetFireHookTarget == net.Fire then
        return
    end

    if type(isfunctionhooked) == "function" and type(restorefunction) == "function" then
        local okH, hooked = pcall(isfunctionhooked, net.Fire)
        if okH and hooked then
            pcall(restorefunction, net.Fire)
        end
    end

    local origFire
    local wrapper = function(eventName, ...)
        if IsRunning() and Config.AntiAFK and Config.AntiAFKP99 then
            if Config.BlockNativeMoveServer and eventName == "Move Server" then
                Runtime.Stats.BlockedMoveServer = (Runtime.Stats.BlockedMoveServer or 0) + 1
                local now = os.clock()
                if now - (Runtime.Cache.LastMoveServerBlockLogAt or 0) >= 15 then
                    Runtime.Cache.LastMoveServerBlockLogAt = now
                    Log("INFO", "Blocked PS99 AFK Move Server (#%d).", Runtime.Stats.BlockedMoveServer)
                end
                return
            elseif Config.BlockNativeMoveServer and (eventName == "Idle Tracking: Engine Idle" or eventName == "Idle Tracking: Update Timer") then
                Runtime.Stats.BlockedIdleTelemetry = (Runtime.Stats.BlockedIdleTelemetry or 0) + 1
                return
            elseif Config.SpoofIdleFocusTrue and eventName == "Idle Tracking: Focus Changed" then
                origFire(eventName, true)
                return
            end
        end
        origFire(eventName, ...)
    end

    local hookedClosure = type(newcclosure) == "function" and newcclosure(wrapper) or wrapper
    local ok, prev = pcall(hookfunction, net.Fire, hookedClosure)
    if ok and type(prev) == "function" then
        origFire = prev
        Runtime.Cache.NetFireHookTarget = net.Fire
        Runtime.Cache.NetFireOrig = prev
        Runtime.Cache.AntiAfkHookActive = true
        getgenv()[NET_FIRE_HOOK_KEY] = net.Fire
        Log("INFO", "PS99 Idle Tracking & Move Server hook enabled.")
    else
        Log("DEBUG", "Failed to hook Network.Fire for PS99 Anti-AFK: %s", tostring(prev))
    end
end

local function SetupAntiAfk()
    if not Config.AntiAFK then
        RestoreAntiAfkNetworkHook()
        return
    end

    EnsureAntiAfkNetworkHook()

    BindConn(LocalPlayer.Idled, function()
        if not IsRunning() or not Config.AntiAFK or not Config.AntiAFKRoblox then
            return
        end
        PulseRobloxAntiAfk()
    end)

    task.spawn(function()
        if Config.AntiAFKRoblox then
            PulseRobloxAntiAfk()
        end
        if Config.AntiAFKP99 then
            PulseP99AntiAfk()
            if Config.SpoofIdleFocusTrue and Modules.Network and type(Modules.Network.Fire) == "function" then
                pcall(Modules.Network.Fire, "Idle Tracking: Focus Changed", true)
            end
        end

        while IsRunning() do
            task.wait(1)
            if not IsRunning() then
                break
            end
            EnsureAntiAfkNetworkHook()
            local now = os.clock()
            if Config.AntiAFK and Config.AntiAFKP99 then
                local p99Interval = math.max(1, tonumber(Config.AntiAFKP99PulseInterval) or 6.5)
                if now - (Runtime.Cache.LastP99AfkPulseAt or 0) >= p99Interval then
                    PulseP99AntiAfk()
                end
            end
            if Config.AntiAFK and Config.AntiAFKRoblox then
                local rbxInterval = math.max(10, tonumber(Config.AntiAFKRobloxPulseInterval) or 45)
                if now - (Runtime.Cache.LastRobloxAfkPulseAt or 0) >= rbxInterval then
                    PulseRobloxAntiAfk()
                end
            end
        end
    end)
end

local function DisableNativeAutoFarmOnce()
    local af = Modules.AutoFarmCmds
    if af and af.IsEnabled and af.Disable then
        local okE, enabled = pcall(af.IsEnabled)
        if okE and enabled == true then
            pcall(af.Disable)
        end
    end
end

local function ReleaseHeldPets()
    if not Modules.PlayerPet or not Modules.PlayerPet.GetByPlayer then
        return
    end
    local releasedAny = false
    pcall(function()
        for _, pet in pairs(Modules.PlayerPet.GetByPlayer(LocalPlayer)) do
            if pet and pet.AIHold == "PumpkinKaitun" then
                pet.AIHold = nil
                releasedAny = true
            end
        end
    end)
    if releasedAny and Modules.Signal and Modules.Signal.Fire then
        pcall(Modules.Signal.Fire, "PetAI_Reset")
    end
end

local ORIG_PET_SPEED_KEY = "_PumpkinTycoonKaitun_OrigCalcPetSpeed"
local HOOK_PET_SPEED_KEY = "_PumpkinTycoonKaitun_HookCalcPetSpeed"

local function RefreshLocalPetSpeeds()
    local pp = Modules.PlayerPet
    if not pp or not pp.GetByPlayer then
        return 0
    end
    local updated = 0
    local sampleMult = nil
    pcall(function()
        for _, pet in pairs(pp.GetByPlayer(LocalPlayer)) do
            if pet and not pet.destroyed and type(pet.CalculateSpeedMultiplier) == "function" then
                local okM, mult = pcall(pet.CalculateSpeedMultiplier, pet)
                if okM and type(mult) == "number" and mult > 0 then
                    sampleMult = mult
                    if pet.speedMult ~= mult then
                        pet.speedMult = mult
                        updated = updated + 1
                    end
                    if pet.cpet and type(pet.cpet.Broadcast) == "function" then
                        local curIn = type(pet.cpet.parallelIn) == "table" and pet.cpet.parallelIn.petSpeedMult or nil
                        if curIn ~= mult then
                            pet.cpet:Broadcast("petSpeedMult", mult)
                        end
                    end
                end
            end
        end
    end)
    if sampleMult ~= nil then
        Runtime.Stats.PetSpeedMult = sampleMult
    end
    return updated
end

local function RestorePetSpeedBuff()
    local pp = Modules.PlayerPet
    local env = getgenv()
    local orig = env[ORIG_PET_SPEED_KEY]
    local myWrapper = Runtime.Cache.PetSpeedHookWrapper
    if pp and type(orig) == "function" and (pp.CalculateSpeedMultiplier == myWrapper or pp.CalculateSpeedMultiplier == env[HOOK_PET_SPEED_KEY]) then
        pp.CalculateSpeedMultiplier = orig
    end
    if myWrapper ~= nil and env[HOOK_PET_SPEED_KEY] == myWrapper then
        env[HOOK_PET_SPEED_KEY] = nil
    end
    Runtime.Cache.PetSpeedHookActive = false
    Runtime.Cache.PetSpeedHookWrapper = nil
    RefreshLocalPetSpeeds()
end

local function StepPetSpeedBuff()
    local pp = Modules.PlayerPet
    if not pp or type(pp.CalculateSpeedMultiplier) ~= "function" then
        return
    end
    local env = getgenv()
    local orig = env[ORIG_PET_SPEED_KEY]
    if type(orig) ~= "function" and pp.CalculateSpeedMultiplier ~= env[HOOK_PET_SPEED_KEY] then
        orig = pp.CalculateSpeedMultiplier
        env[ORIG_PET_SPEED_KEY] = orig
    end
    if type(orig) ~= "function" then
        return
    end

    if not Config.AutoBuffPetSpeed then
        if Runtime.Cache.PetSpeedHookActive or pp.CalculateSpeedMultiplier == env[HOOK_PET_SPEED_KEY] then
            RestorePetSpeedBuff()
        end
        return
    end

    local targetMult = math.max(1, tonumber(Config.PetSpeedMultiplier) or 999)
    local myWrapper = Runtime.Cache.PetSpeedHookWrapper
    if type(myWrapper) ~= "function" or pp.CalculateSpeedMultiplier ~= myWrapper or not Runtime.Cache.PetSpeedHookActive then
        myWrapper = function(petSelf, ...)
            if IsRunning() and Config.AutoBuffPetSpeed and petSelf and petSelf.owner == LocalPlayer then
                local cfgMult = tonumber(Config.PetSpeedMultiplier)
                if cfgMult and cfgMult > 0 then
                    return cfgMult
                end
            end
            return orig(petSelf, ...)
        end
        env[HOOK_PET_SPEED_KEY] = myWrapper
        pp.CalculateSpeedMultiplier = myWrapper
        Runtime.Cache.PetSpeedHookWrapper = myWrapper
        Runtime.Cache.PetSpeedHookActive = true
        Log("INFO", "Pet speed buff hook enabled (mult=%s).", tostring(targetMult))
    end
    RefreshLocalPetSpeeds()
end

-- ============================================================================
-- 3C. MAP & RENDER OPTIMIZER (SAFE CLUTTER REMOVAL + ZERO-RENDER ISLAND/FX)
-- ============================================================================
local SAFE_FLOOR_NAME = "_PumpkinKaitun_SafeFloor"
local OPTIMIZER_EVENT_ID = "PumpkinTycoon"
local WORLD_CLUTTER_NAMES = {
    ["PSX Portal"] = true,
    ["Border"] = true,
    ["PSX Hall"] = true,
    ["FlyBorder"] = true,
    ["GREYBOX_WIP"] = true,
    ["Tiles"] = true,
    ["__INSTANCE_SCENERY"] = true,
}
-- Keep main world/zone hierarchy intact (e.g. Traveling Merchant UI references in Zone 1) and hide visuals only
local WORLD_HIDE_NAMES = {
    ["Zone 1"] = true,
    ["Map"] = true,
    ["Map2"] = true,
    ["Map3"] = true,
    ["Map4"] = true,
    ["Tycoons"] = true,
    ["BlockWorlds"] = true,
    ["TradingPlaza"] = true,
}
local THINGS_CLEAR_FOLDERS = {
    "Ornaments",
    "Ski Chairs",
    "BalloonGifts",
    "Hoverboards",
    "InfinityEggs",
    "Flags",
    "VictoryScene",
    "__FAKE_INSTANCE_BREAK_ZONES",
}

local TrackedContainers = {}
local HookedContainers = {}

local function TrackContainer(container)
    if TrackedContainers[container] then
        return
    end
    TrackedContainers[container] = true
    BindConn(container.Destroying, function()
        TrackedContainers[container] = nil
        HookedContainers[container] = nil
    end)
end

local function DestroyClutterInstance(inst, defer)
    if not inst or not inst.Parent or inst.Name == SAFE_FLOOR_NAME or inst == Workspace then
        return
    end
    Runtime.Stats.MapDestroyedCount = (Runtime.Stats.MapDestroyedCount or 0) + 1
    if defer then
        task.defer(function()
            if inst and inst.Parent then
                pcall(inst.Destroy, inst)
            end
        end)
    else
        pcall(inst.Destroy, inst)
    end
end

local function StripVisualObject(obj, stripCollision, defer)
    if not obj or not obj.Parent or obj.Name == SAFE_FLOOR_NAME then
        return
    end
    if obj:IsA("BasePart") then
        local changed = false
        if obj.Transparency < 1 then
            obj.Transparency = 1
            changed = true
        end
        if obj.CastShadow then
            obj.CastShadow = false
        end
        if obj.Material ~= Enum.Material.SmoothPlastic then
            obj.Material = Enum.Material.SmoothPlastic
        end
        if stripCollision then
            if obj.CanCollide then
                obj.CanCollide = false
            end
            if obj.CanTouch then
                obj.CanTouch = false
            end
            if obj.CanQuery then
                obj.CanQuery = false
            end
        end
        if changed then
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
        return
    end

    if obj:IsA("SurfaceAppearance") then
        Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        DestroyClutterInstance(obj, defer)
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if obj.Transparency < 1 then
            obj.Transparency = 1
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("ParticleEmitter") then
        if obj.Enabled or obj.Rate > 0 then
            obj.Enabled = false
            obj.Rate = 0
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        if obj.Enabled then
            obj.Enabled = false
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Light") then
        if obj.Enabled or obj.Brightness > 0 then
            obj.Enabled = false
            obj.Brightness = 0
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        if obj.Enabled then
            obj.Enabled = false
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    end
end

local function StripLocalCharacterFx(charModel)
    if not charModel then
        return
    end
    for _, d in ipairs(charModel:GetDescendants()) do
        if d:IsA("BasePart") then
            if d.CastShadow then
                d.CastShadow = false
            end
        elseif d:IsA("ParticleEmitter") then
            d.Enabled = false
            d.Rate = 0
        elseif d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            d.Enabled = false
        elseif d:IsA("Light") then
            d.Enabled = false
            d.Brightness = 0
        end
    end
end

local function HookDescendantStripper(container, stripCollision)
    if not container or HookedContainers[container] then
        return
    end
    HookedContainers[container] = true
    BindConn(container.DescendantAdded, function(desc)
        if not IsRunning() or not Config.OptimizeMap then
            return
        end
        task.defer(function()
            if IsRunning() and Config.OptimizeMap and desc and desc.Parent then
                StripVisualObject(desc, stripCollision, true)
            end
        end)
    end)
end

local function StripContainerTree(container, stripCollision, watchDescendants, forceResweep, yieldBatch)
    if not container or not container.Parent then
        return
    end
    local alreadyTracked = (TrackedContainers[container] == true)
    if alreadyTracked and not forceResweep then
        if watchDescendants then
            HookDescendantStripper(container, stripCollision)
        end
        return
    end

    TrackContainer(container)
    if watchDescendants then
        HookDescendantStripper(container, stripCollision)
    end

    StripVisualObject(container, stripCollision, yieldBatch == true)
    local descendants = container:GetDescendants()
    for i, desc in ipairs(descendants) do
        StripVisualObject(desc, stripCollision, yieldBatch == true)
        if yieldBatch and i % 1200 == 0 then
            task.wait()
            if not IsRunning() or not Config.OptimizeMap then
                return
            end
        end
    end
end

local function ClearFolderWithWatcher(folder, keepChildName)
    if not folder or TrackedContainers[folder] then
        return
    end
    TrackContainer(folder)
    for _, child in ipairs(folder:GetChildren()) do
        if not keepChildName or child.Name ~= keepChildName then
            DestroyClutterInstance(child, false)
        end
    end
    if not HookedContainers[folder] then
        HookedContainers[folder] = true
        BindConn(folder.ChildAdded, function(child)
            if not IsRunning() or not Config.OptimizeMap or not Config.StripWorldClutter then
                return
            end
            if not keepChildName or child.Name ~= keepChildName then
                DestroyClutterInstance(child, true)
            end
        end)
    end
end

local function ApplyLightingAndEffectsOptimization()
    if not Config.OptimizeLightingAndEffects then
        return
    end
    if not Runtime.Cache.SavedLightingState then
        local savedChildren = {}
        for _, child in ipairs(Lighting:GetChildren()) do
            local entry = {}
            if child:IsA("PostEffect") then
                entry.Enabled = child.Enabled
            elseif child:IsA("Atmosphere") then
                entry.Density = child.Density
                entry.Offset = child.Offset
                entry.Glare = child.Glare
                entry.Haze = child.Haze
            elseif child:IsA("Sky") then
                entry.SkyboxBk = child.SkyboxBk
                entry.SkyboxDn = child.SkyboxDn
                entry.SkyboxFt = child.SkyboxFt
                entry.SkyboxLf = child.SkyboxLf
                entry.SkyboxRt = child.SkyboxRt
                entry.SkyboxUp = child.SkyboxUp
                entry.StarCount = child.StarCount
                entry.CelestialBodiesShown = child.CelestialBodiesShown
            elseif child:IsA("Clouds") then
                entry.Enabled = child.Enabled
                entry.Cover = child.Cover
            end
            if next(entry) ~= nil then
                savedChildren[child] = entry
            end
        end
        local prevQualityLevel = nil
        local prevSavedQuality = nil
        pcall(function()
            local r = settings and settings().Rendering
            if r then
                prevQualityLevel = r.QualityLevel
                r.QualityLevel = Enum.QualityLevel.Level01
            end
        end)
        pcall(function()
            local userSettings = UserSettings()
            local ugs = userSettings and userSettings:GetService("UserGameSettings")
            if ugs then
                prevSavedQuality = ugs.SavedQualityLevel
                if ugs.SavedQualityLevel ~= Enum.SavedQualitySetting.QualityLevel1 then
                    ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
                end
            end
        end)

        Runtime.Cache.SavedLightingState = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            RenderQualityLevel = prevQualityLevel,
            SavedQualityLevel = prevSavedQuality,
            Children = savedChildren,
        }

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.Decoration = false
            end)
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
            pcall(function()
                terrain:Clear()
            end)
        end
    end

    if Lighting.GlobalShadows then
        Lighting.GlobalShadows = false
    end
    if Lighting.Brightness ~= 0 then
        Lighting.Brightness = 0
    end
    if Lighting.FogEnd < 9e8 then
        Lighting.FogEnd = 9e9
    end
    if Lighting.EnvironmentDiffuseScale ~= 0 then
        Lighting.EnvironmentDiffuseScale = 0
    end
    if Lighting.EnvironmentSpecularScale ~= 0 then
        Lighting.EnvironmentSpecularScale = 0
    end

    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            if child.Enabled then
                child.Enabled = false
            end
        elseif child:IsA("Atmosphere") then
            child.Density = 0
            child.Offset = 0
            child.Glare = 0
            child.Haze = 0
        elseif child:IsA("Sky") then
            child.SkyboxBk = ""
            child.SkyboxDn = ""
            child.SkyboxFt = ""
            child.SkyboxLf = ""
            child.SkyboxRt = ""
            child.SkyboxUp = ""
            child.StarCount = 0
            child.CelestialBodiesShown = false
        elseif child:IsA("Clouds") then
            child.Enabled = false
            child.Cover = 0
        end
    end
end

local function CleanOtherPlayerCharacter(model, yieldBatch)
    if not model or model == LocalPlayer.Character or not model:IsA("Model") then
        return
    end
    local plr = Players:GetPlayerFromCharacter(model)
    local isOtherChar = (plr ~= nil and plr ~= LocalPlayer)
        or (model.Name ~= LocalPlayer.Name and model:FindFirstChildOfClass("Humanoid") ~= nil)
    if isOtherChar then
        StripContainerTree(model, true, true, false, yieldBatch)
    end
end

local function StripIslandsFolder(islands, yieldBatch)
    if not islands then
        return
    end
    local myUidStr = tostring(LocalPlayer.UserId)
    for _, islandModel in ipairs(islands:GetChildren()) do
        if not TrackedContainers[islandModel] then
            local isMine = (islandModel.Name == myUidStr)
            StripContainerTree(islandModel, not isMine, true, false, yieldBatch)
        end
    end
    if not HookedContainers[islands] then
        HookedContainers[islands] = true
        BindConn(islands.ChildAdded, function(child)
            if not IsRunning() or not Config.OptimizeMap or not Config.HideIslandVisuals then
                return
            end
            task.defer(function()
                if IsRunning() and Config.OptimizeMap and Config.HideIslandVisuals and child and child.Parent then
                    local isMine = (child.Name == myUidStr)
                    StripContainerTree(child, not isMine, true, false, true)
                end
            end)
        end)
    end
end

local function EnsureSafeFloor(plot)
    if not Config.OptimizeMap or not Config.SafeFloorEnabled then
        local existing = Runtime.Cache.SafeFloorPart or Workspace:FindFirstChild(SAFE_FLOOR_NAME)
        if existing and existing.Parent then
            pcall(existing.Destroy, existing)
        end
        Runtime.Cache.SafeFloorPart = nil
        return
    end
    if not plot then
        return
    end
    local okCf, cf = pcall(plot.GetCFrame, plot)
    if not okCf or typeof(cf) ~= "CFrame" then
        return
    end

    local floor = Runtime.Cache.SafeFloorPart
    if not floor or not floor.Parent then
        floor = Workspace:FindFirstChild(SAFE_FLOOR_NAME)
    end
    if not floor or not floor:IsA("Part") then
        local newFloor = Instance.new("Part")
        newFloor.Name = SAFE_FLOOR_NAME
        newFloor.Anchored = true
        newFloor.CanCollide = true
        newFloor.CanQuery = true
        newFloor.CanTouch = false
        newFloor.Transparency = 1
        newFloor.CastShadow = false
        newFloor.Material = Enum.Material.SmoothPlastic
        newFloor.Size = Vector3.new(2048, 4, 2048)
        newFloor.Parent = Workspace
        floor = newFloor
    end
    Runtime.Cache.SafeFloorPart = floor

    local targetPos = Vector3.new(cf.Position.X, cf.Position.Y - 12, cf.Position.Z)
    if (floor.Position - targetPos).Magnitude > 1 then
        floor.CFrame = CFrame.new(targetPos)
    end
end

local function StripSiblingInstancesFolder(instancesFolder, yieldBatch)
    if not instancesFolder or not instancesFolder.Parent then
        return
    end
    -- Keep unused minigame container folders alive so PS99 does not loop-print "<Name> Instances" on missing lookups
    for _, instChild in ipairs(instancesFolder:GetChildren()) do
        if instChild.Name ~= OPTIMIZER_EVENT_ID and not TrackedContainers[instChild] then
            StripContainerTree(instChild, true, true, false, yieldBatch)
        end
    end
    if not HookedContainers[instancesFolder] then
        HookedContainers[instancesFolder] = true
        BindConn(instancesFolder.ChildAdded, function(instChild)
            if IsRunning() and Config.OptimizeMap and Config.StripWorldClutter and instChild.Name ~= OPTIMIZER_EVENT_ID then
                task.defer(function()
                    if IsRunning() and Config.OptimizeMap and instChild and instChild.Parent then
                        StripContainerTree(instChild, true, true, false, true)
                    end
                end)
            end
        end)
    end
end

local function RunMapOptimizerPass(plot, yieldBatch)
    if not Config.OptimizeMap then
        return
    end

    local things = Workspace:FindFirstChild("__THINGS")
    if Config.StripWorldClutter then
        for _, child in ipairs(Workspace:GetChildren()) do
            if WORLD_CLUTTER_NAMES[child.Name] then
                DestroyClutterInstance(child, false)
            elseif WORLD_HIDE_NAMES[child.Name] and not TrackedContainers[child] then
                StripContainerTree(child, true, true, false, yieldBatch)
            end
        end

        ClearFolderWithWatcher(Workspace:FindFirstChild("__DEBRIS"), nil)

        if things then
            for _, folderName in ipairs(THINGS_CLEAR_FOLDERS) do
                ClearFolderWithWatcher(things:FindFirstChild(folderName), nil)
            end
            StripSiblingInstancesFolder(things:FindFirstChild("Instances"), yieldBatch)

            local ic = things:FindFirstChild("__INSTANCE_CONTAINER")
            local activeFolder = ic and ic:FindFirstChild("Active")
            local ptActive = activeFolder and activeFolder:FindFirstChild(OPTIMIZER_EVENT_ID)
            if ptActive then
                local water = ptActive:FindFirstChild("Water")
                if water then
                    DestroyClutterInstance(water, false)
                end
                if not HookedContainers[ptActive] then
                    HookedContainers[ptActive] = true
                    BindConn(ptActive.ChildAdded, function(child)
                        if IsRunning() and Config.OptimizeMap and Config.StripWorldClutter and child.Name == "Water" then
                            DestroyClutterInstance(child, true)
                        end
                    end)
                end
            end
        end
    end

    if Config.HideIslandVisuals then
        StripIslandsFolder(Workspace:FindFirstChild("PumpkinTycoonIslands"), yieldBatch)
        if things then
            StripContainerTree(things:FindFirstChild("Plots"), false, true, false, yieldBatch)
        end
        StripContainerTree(Workspace:FindFirstChild("PumpkinTycoonPads"), false, true, false, yieldBatch)
        StripContainerTree(Workspace:FindFirstChild("PumpkinTycoonPumpkins"), false, true, false, yieldBatch)
    end

    if Config.HideEntityVisuals then
        if things then
            for _, entityFolderName in ipairs({ "Breakables", "CustomEggs", "Pets", "PetsHidden", "Orbs" }) do
                StripContainerTree(things:FindFirstChild(entityFolderName), false, true, false, yieldBatch)
            end
        end
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") and not TrackedContainers[child] then
                CleanOtherPlayerCharacter(child, yieldBatch)
            end
        end
    end

    EnsureSafeFloor(plot)
end

local function HookOtherPlayerEvents(plr)
    if not plr or plr == LocalPlayer then
        return
    end
    if plr.Character then
        task.spawn(CleanOtherPlayerCharacter, plr.Character, true)
    end
    BindConn(plr.CharacterAdded, function(char)
        if IsRunning() and Config.OptimizeMap and Config.HideEntityVisuals then
            task.defer(function()
                CleanOtherPlayerCharacter(char, true)
            end)
        end
    end)
end

local function SetupMapOptimizer()
    if Config.CPUSaver then
        pcall(function()
            if type(setfpscap) == "function" then
                setfpscap(Config.TargetFPS or 5)
            end
            local r = game:GetService("RunService")
            if type(r.Set3dRenderingEnabled) == "function" then
                r:Set3dRenderingEnabled(false)
            end
        end)
    else
        pcall(function()
            if type(setfpscap) == "function" then
                setfpscap(Config.TargetFPS or 60)
            end
            local r = game:GetService("RunService")
            if type(r.Set3dRenderingEnabled) == "function" then
                r:Set3dRenderingEnabled(true)
            end
        end)
    end

    if not Config.OptimizeMap then
        return
    end
    if not Runtime.Cache.MapOptimizerInitialized then
        Runtime.Cache.MapOptimizerInitialized = true
        ApplyLightingAndEffectsOptimization()
        local myChar = LocalPlayer.Character
        if myChar and Config.OptimizeLightingAndEffects then
            StripLocalCharacterFx(myChar)
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            HookOtherPlayerEvents(plr)
        end
        BindConn(Players.PlayerAdded, HookOtherPlayerEvents)

        BindConn(Workspace.ChildAdded, function(child)
            if not IsRunning() or not Config.OptimizeMap then
                return
            end
            task.defer(function()
                if not IsRunning() or not Config.OptimizeMap or not child or not child.Parent then
                    return
                end
                if Config.StripWorldClutter and WORLD_CLUTTER_NAMES[child.Name] then
                    DestroyClutterInstance(child, true)
                    return
                end
                if Config.StripWorldClutter and WORLD_HIDE_NAMES[child.Name] then
                    StripContainerTree(child, true, true, false, true)
                    return
                end
                if Config.StripWorldClutter and child.Name == "__DEBRIS" then
                    ClearFolderWithWatcher(child, nil)
                elseif Config.HideIslandVisuals and child.Name == "PumpkinTycoonIslands" then
                    StripIslandsFolder(child, true)
                elseif Config.HideIslandVisuals and (child.Name == "PumpkinTycoonPads" or child.Name == "PumpkinTycoonPumpkins") then
                    StripContainerTree(child, false, true, false, true)
                elseif Config.HideEntityVisuals and child:IsA("Model") then
                    CleanOtherPlayerCharacter(child, true)
                end
            end)
        end)

        BindConn(Lighting.ChildAdded, function()
            if IsRunning() and Config.OptimizeMap and Config.OptimizeLightingAndEffects then
                task.defer(ApplyLightingAndEffectsOptimization)
            end
        end)

        BindConn(LocalPlayer.CharacterAdded, function(char)
            if IsRunning() and Config.OptimizeMap and Config.OptimizeLightingAndEffects then
                task.defer(function()
                    StripLocalCharacterFx(char)
                end)
            end
        end)
    end

    task.spawn(function()
        RunMapOptimizerPass(nil, true)
        Runtime.Cache.LastOptimizeScanAt = os.clock()
        Log("INFO", "Map optimizer active (destroyed=%d, visualsHidden=%d).",
            tonumber(Runtime.Stats.MapDestroyedCount) or 0,
            tonumber(Runtime.Stats.VisualsHiddenCount) or 0)
    end)
end

local function ScheduleMyIslandResweep()
    for _, delaySec in ipairs({ 0.55, 1.25 }) do
        task.delay(delaySec, function()
            if IsRunning() and Config.OptimizeMap and Config.HideIslandVisuals then
                local islands = Workspace:FindFirstChild("PumpkinTycoonIslands")
                local myDecor = islands and islands:FindFirstChild(tostring(LocalPlayer.UserId))
                if myDecor then
                    StripContainerTree(myDecor, false, true, true, true)
                end
            end
        end)
    end
end

local function StepMapOptimizer(plot)
    if not Config.OptimizeMap then
        return
    end
    EnsureSafeFloor(plot)

    local buttonsDone = tonumber(Runtime.Stats.ButtonsDone) or 0
    local prevButtonsDone = tonumber(Runtime.Cache.LastButtonsDoneForDecor) or -1
    if buttonsDone ~= prevButtonsDone then
        Runtime.Cache.LastButtonsDoneForDecor = buttonsDone
        if prevButtonsDone >= 0 then
            ScheduleMyIslandResweep()
        end
    end

    local now = os.clock()
    local interval = math.max(0.5, tonumber(Config.OptimizeScanInterval) or 2.0)
    if now - (Runtime.Cache.LastOptimizeScanAt or 0) >= interval then
        Runtime.Cache.LastOptimizeScanAt = now
        -- Fast O(1)-per-container check for any un-tracked streamed folder/island; avoids re-scanning tracked trees
        RunMapOptimizerPass(plot, true)
    end
end

local function RestoreMapOptimizer()
    local safeFloor = Runtime.Cache.SafeFloorPart or Workspace:FindFirstChild(SAFE_FLOOR_NAME)
    if safeFloor and safeFloor.Parent then
        pcall(safeFloor.Destroy, safeFloor)
    end
    Runtime.Cache.SafeFloorPart = nil

    local saved = Runtime.Cache.SavedLightingState
    if type(saved) == "table" then
        pcall(function()
            Lighting.GlobalShadows = saved.GlobalShadows
            Lighting.FogEnd = saved.FogEnd
            Lighting.Brightness = saved.Brightness
            Lighting.EnvironmentDiffuseScale = saved.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = saved.EnvironmentSpecularScale
        end)
        if saved.RenderQualityLevel ~= nil then
            pcall(function()
                local r = settings and settings().Rendering
                if r then
                    r.QualityLevel = saved.RenderQualityLevel
                end
            end)
        end
        if saved.SavedQualityLevel ~= nil then
            pcall(function()
                local userSettings = UserSettings()
                local ugs = userSettings and userSettings:GetService("UserGameSettings")
                if ugs then
                    ugs.SavedQualityLevel = saved.SavedQualityLevel
                end
            end)
        end
        if type(saved.Children) == "table" then
            for inst, props in pairs(saved.Children) do
                if inst and inst.Parent then
                    pcall(function()
                        for k, v in pairs(props) do
                            (inst :: any)[k] = v
                        end
                    end)
                end
            end
        end
        Runtime.Cache.SavedLightingState = nil
    end
    table.clear(TrackedContainers)
    table.clear(HookedContainers)
    Runtime.Cache.MapOptimizerInitialized = false
end

Runtime.Teardown = function()
    Runtime.Running = false
    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Connections)
    RestorePetSpeedBuff()
    RestoreAntiAfkNetworkHook()
    RestoreMapOptimizer()
    ReleaseHeldPets()
    Runtime.Cache.MachineSessionDepth = 0
    Runtime.Cache.HatchYieldUntil = 0
    Runtime.Cache.HatchInFlight = false
    Runtime.Cache.MoveLockUntil = 0
    Log("INFO", "Previous session cleaned up.")
end
getgenv()[GEN_KEY] = Runtime

-- ============================================================================
-- 4. CORE HELPER UTILITIES
-- ============================================================================
local PT = Modules.PumpkinTycoon
local INSTANCE_ID = (PT and PT.INSTANCE_ID) or "PumpkinTycoon"
local NET = (PT and PT.NET) or {
    Buy = "NZ_Commit",
    BuyBand = "FZ_Reserve",
    CocoaBuyTime = "VB_Extend",
    SetAutoBreak = "QW_Policy",
    SetLock = "KT_Shelter",
    PlaceStock = "XC_Allocate",
    SetAutoPlace = "JD_Prefer",
    SetAutoMerchant = "HM_Sustain",
    UpgradeBuy = "OQ_Advance",
    GiftOpen = "YR_Hydrate",
    Complete = "BT_Settle",
    TutorialDone = "WL_Recall",
}
local VAR = (PT and PT.VAR) or {
    Buttons = "Buttons",
    Pedestals = "Pedestals",
    Stock = "Stock",
    Merchant = "Merchant",
    AutoBreak = "AutoBreak",
    Tutorial = "Tutorial",
}

local function GetCharacter()
    local char = LocalPlayer.Character
    local hrp = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    return char, hrp
end

local function WaitReady()
    while IsRunning() do
        local _, hrp = GetCharacter()
        local saveOk, saveData = pcall(function()
            return Modules.Save and Modules.Save.Get and Modules.Save.Get()
        end)
        if hrp and saveOk and type(saveData) == "table" then
            return true
        end
        task.wait(0.2)
    end
    return false
end

local function HorizontalDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function MoveNear(targetPos, minThreshold)
    local _, hrp = GetCharacter()
    if not hrp or not targetPos then
        return false
    end
    local dist = HorizontalDist(hrp.Position, targetPos)
    if dist <= (minThreshold or 14) then
        return true
    end
    -- Offset cleanly on the same Y+2 plane to avoid lodging inside models
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 4))
    Runtime.Cache.LastTeleportAt = os.clock()
    return true
end

local function IsMoveLocked()
    return (Runtime.Cache.MoveLockUntil or 0) > os.clock()
end

local function AcquireMoveLock(durationSec)
    local untilTs = os.clock() + (tonumber(durationSec) or 3.0)
    if untilTs > (Runtime.Cache.MoveLockUntil or 0) then
        Runtime.Cache.MoveLockUntil = untilTs
    end
end

local function ReleaseMoveLock()
    Runtime.Cache.MoveLockUntil = 0
end

--- Close a machine UI modal only when TabController confirms that specific machine tab is open.
local function CloseMachineTab(machineName)
    local tc = Modules.TabController
    if not tc or type(machineName) ~= "string" then
        return
    end
    if type(tc.IsOpen) ~= "function" or type(tc.CloseTab) ~= "function" then
        return
    end
    local okOpen, isOpen = pcall(tc.IsOpen, machineName)
    if okOpen and isOpen == true then
        pcall(tc.CloseTab)
    end
end

--- Acquire a nested machine session lock and pause active AutoHatch cleanly before moving.
local function BeginMachineSession(waitTimeoutSec)
    Runtime.Cache.MachineSessionDepth = (Runtime.Cache.MachineSessionDepth or 0) + 1
    local lockSec = 4.0
    Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + lockSec)
    AcquireMoveLock(lockSec)

    if Runtime.Cache.MachineSessionDepth == 1 then
        local deadline = os.clock() + (tonumber(waitTimeoutSec) or 1.5)
        while IsRunning() and Runtime.Cache.HatchInFlight and os.clock() < deadline do
            Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + lockSec)
            AcquireMoveLock(lockSec)
            task.wait(0.03)
        end
    end
end

--- Extend both MoveLock and HatchYieldUntil during multi-invoke machine batches.
local function ExtendMachineSession(lockSec)
    local dur = tonumber(lockSec) or 4.0
    if (Runtime.Cache.MachineSessionDepth or 0) > 0 then
        Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + dur)
    end
    AcquireMoveLock(dur)
end

local function EndMachineSession()
    local depth = math.max(0, (Runtime.Cache.MachineSessionDepth or 1) - 1)
    Runtime.Cache.MachineSessionDepth = depth
    if depth == 0 then
        Runtime.Cache.HatchYieldUntil = 0
        ReleaseMoveLock()
    end
end

--- Run a callback across one or more machine visits while holding MoveLock and pausing AutoHatch.
local function WithMachineSession(callback)
    BeginMachineSession(1.5)
    local ok, err = pcall(callback)
    EndMachineSession()
    if not ok then
        Log("DEBUG", "Machine session error: %s", tostring(err))
        return false
    end
    return true
end

local function EnsureNearMachinePad(plot, machineName, rangeFn, standOnPad)
    if not plot or not machineName or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.MachinePad then
        return false
    end
    local okPlot, plotModel = pcall(plot.GetModel, plot)
    if not okPlot or not plotModel then
        return false
    end
    local pad = Modules.PumpkinButtonsUtil.MachinePad(plotModel, machineName)
    if not pad or not pad:IsA("BasePart") then
        return false
    end
    local range = 20
    if type(rangeFn) == "number" and rangeFn >= 6 then
        range = rangeFn
    elseif type(rangeFn) == "function" then
        local okR, r = pcall(rangeFn)
        if okR and type(r) == "number" and r >= 6 then
            range = r
        end
    end
    local moveDist = standOnPad and 2.5 or math.clamp(range - 8, 4, 12)
    local _, hrp = GetCharacter()
    if not hrp then
        return false
    end
    ExtendMachineSession(4.0)
    local needMove = HorizontalDist(hrp.Position, pad.Position) > moveDist
        or math.abs(hrp.Position.Y - pad.Position.Y) > 6
    if standOnPad and Modules.MachineCmds and Modules.MachineCmds.IsStandingOn then
        local okOn, standing = pcall(Modules.MachineCmds.IsStandingOn, machineName)
        if okOn and standing == false then
            needMove = true
        end
    end
    if needMove then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        local targetOffset = standOnPad
            and Vector3.new(0, (pad.Size.Y * 0.5) + 2.8, 0)
            or Vector3.new(0, 2.5, 1.5)
        hrp.CFrame = CFrame.new(pad.Position + targetOffset)
        Runtime.Cache.LastTeleportAt = os.clock()
    end
    local waitLeft = 0.38 - (os.clock() - (Runtime.Cache.LastTeleportAt or 0))
    if waitLeft > 0 then
        task.wait(waitLeft)
    end
    _, hrp = GetCharacter()
    if not hrp or (hrp.Position - pad.Position).Magnitude > (range - 1) then
        return false
    end
    return true
end

local function WithMachinePad(plot, machineName, rangeFn, callback, opts)
    BeginMachineSession(1.5)
    local standOnPad = type(opts) == "table" and opts.standOnPad == true
    local closeModal = type(opts) == "table" and opts.closeModal == true
    if not EnsureNearMachinePad(plot, machineName, rangeFn, standOnPad) then
        EndMachineSession()
        return false
    end
    if closeModal then
        CloseMachineTab(machineName)
    end
    local ok, err = pcall(callback)
    if closeModal then
        CloseMachineTab(machineName)
        task.delay(0.2, function()
            if IsRunning() then
                CloseMachineTab(machineName)
            end
        end)
    end
    EndMachineSession()
    if not ok then
        Log("DEBUG", "Machine action error [%s]: %s", tostring(machineName), tostring(err))
        return false
    end
    return true
end

local function GetCurrency(currencyId)
    if Modules.CurrencyCmds and Modules.CurrencyCmds.Get then
        local ok, val = pcall(Modules.CurrencyCmds.Get, currencyId)
        if ok and type(val) == "number" then
            return val
        end
    end
    return 0
end

local function GetFlag(keyName, fallback)
    local FFlags = Modules.FFlags
    if FFlags and FFlags.Keys and FFlags.Get then
        local k = FFlags.Keys[keyName]
        if k ~= nil then
            local ok, v = pcall(FFlags.Get, k)
            if ok and v ~= nil then
                return v
            end
        end
    end
    return fallback
end

local function IsInEventInstance()
    if Modules.InstancingCmds and Modules.InstancingCmds.IsInInstance then
        local ok, inside = pcall(Modules.InstancingCmds.IsInInstance, INSTANCE_ID)
        if ok and inside == true then
            return true
        end
    end
    if Modules.InstancingCmds and Modules.InstancingCmds.Get then
        local ok, info = pcall(Modules.InstancingCmds.Get)
        if ok and type(info) == "table" and info.instanceID == INSTANCE_ID then
            return true
        end
    end
    return LocalPlayer:GetAttribute("InstanceId") == INSTANCE_ID
end

local function GetMyPlot()
    if not Modules.ClientPlot or not Modules.ClientPlot.GetByPlayer then
        return nil
    end
    local ok, plot = pcall(Modules.ClientPlot.GetByPlayer, LocalPlayer)
    if ok and plot and not plot:IsDestroyed() then
        local dir = plot:GetDirectory()
        local dirId = type(dir) == "table" and (dir._id or dir.SaveId) or dir
        local targetDir = (PT and PT.PLOT_DIR) or INSTANCE_ID
        if dirId == targetDir or dirId == INSTANCE_ID then
            return plot
        end
    end
    return nil
end

local function GetIslandBox(plot)
    if not plot then
        return nil
    end
    local now = os.clock()
    if Runtime.Cache.IslandBox and (now - Runtime.Cache.IslandBoxAt < 2.0) then
        return Runtime.Cache.IslandBox
    end
    local model = plot:GetModel()
    if not model then
        return nil
    end
    local cf, size = model:GetBoundingBox()
    Runtime.Cache.IslandBox = { cf = cf, size = size, model = model }
    Runtime.Cache.IslandBoxAt = now
    return Runtime.Cache.IslandBox
end

local function IsOnMyIsland(model, islandBox)
    if not model or not model.Parent then
        return false
    end
    if model:GetAttribute("OwnerUsername") == LocalPlayer.Name then
        return true
    end
    if islandBox and PT and PT.OnIsland then
        return PT.OnIsland(islandBox.cf, islandBox.size, model:GetPivot().Position)
    end
    return false
end

local function GetZoneCount()
    if GetFlag("PumpkinTycoon_Part2", false) == true then
        return #(PT and PT.ZONES or {})
    end
    return (PT and PT.PART1_ZONES) or 5
end

local function GetProgressState(plot)
    local buttons = plot and plot:Save(VAR.Buttons) or nil
    local done, total = 0, 0
    if Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Progress then
        done, total = Modules.PumpkinButtonsUtil.Progress(buttons, 1)
    end
    local part1Complete = (total > 0 and done >= total)
    local claimedComplete = (Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Completed and Modules.PumpkinButtonsUtil.Completed(buttons)) == true

    Runtime.Cache.Buttons = buttons
    Runtime.Cache.ButtonsAt = os.clock()
    Runtime.Stats.ButtonsDone = done
    Runtime.Stats.ButtonsTotal = total
    Runtime.Stats.Part1Complete = part1Complete
    Runtime.Stats.CompletedClaimed = claimedComplete
    Runtime.Stats.Coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    Runtime.Stats.Tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
    Runtime.Stats.IslandLuck = tonumber(LocalPlayer:GetAttribute("PumpkinTycoonIslandLuck")) or 0

    return buttons, part1Complete, claimedComplete
end

-- ============================================================================
-- 5. JOIN & TUTORIAL
-- ============================================================================
local lastJoinAttempt = 0
local function EnsureInPumpkinTycoon()
    if IsInEventInstance() then
        local plot = GetMyPlot()
        if plot then
            return plot
        end
        Runtime.Stats.Phase = "Waiting Plot"
        local waitDeadline = os.clock() + 5
        while IsRunning() and IsInEventInstance() and os.clock() < waitDeadline do
            plot = GetMyPlot()
            if plot then
                Log("INFO", "Bound %s plot ID: %s", INSTANCE_ID, tostring(plot:GetId()))
                return plot
            end
            task.wait(0.15)
        end
        return nil
    end
    if not Config.AutoJoin then
        return nil
    end
    if os.clock() - lastJoinAttempt < 3.0 then
        return nil
    end
    lastJoinAttempt = os.clock()

    Runtime.Stats.Phase = "Entering PumpkinTycoon"
    Log("INFO", "Joining %s instance...", INSTANCE_ID)

    if Modules.InstancingCmds and Modules.InstancingCmds.Enter then
        pcall(Modules.InstancingCmds.Enter, INSTANCE_ID)
    end
    if not IsInEventInstance() and Modules.Network and Modules.Network.Invoke then
        pcall(Modules.Network.Invoke, "Instancing_PlayerEnterInstance", INSTANCE_ID)
    end

    local deadline = os.clock() + 8
    while IsRunning() and os.clock() < deadline do
        local plot = GetMyPlot()
        if IsInEventInstance() and plot then
            Log("INFO", "Entered %s plot ID: %s", INSTANCE_ID, tostring(plot:GetId()))
            return plot
        end
        task.wait(0.2)
    end
    return nil
end

local lastTutorialInvoke = 0
local function StepTutorial(plot)
    if not Config.AutoTutorial or not plot then
        return
    end
    if plot:Save(VAR.Tutorial) == true then
        return
    end
    if os.clock() - lastTutorialInvoke < 5 then
        return
    end
    lastTutorialInvoke = os.clock()
    local ok = pcall(function()
        return plot:Invoke(NET.TutorialDone)
    end)
    if ok then
        Log("DEBUG", "Completed island tutorial check.")
    end
end

-- ============================================================================
-- 6. PEDESTAL POLICY, LOCK, STOCK & MERCHANT
-- ============================================================================
local function AnalyzePedestals(plot)
    local raw = plot:Save(VAR.Pedestals)
    local maxPed = (PT and PT.MAX_PEDESTALS) or 8
    local unlockedIndices = {}
    local emptyIndices = {}
    local occupied = {}
    local lockedList = {}

    if type(raw) == "table" then
        for i = 1, maxPed do
            local entry = raw[i]
            if type(entry) == "table" and entry.Unlocked == true then
                table.insert(unlockedIndices, i)
                if type(entry.Standing) ~= "table" then
                    table.insert(emptyIndices, i)
                else
                    local rung = tonumber(entry.Standing.R) or 1
                    local isLocked = entry.Locked == true
                    local item = { index = i, rung = rung, locked = isLocked }
                    table.insert(occupied, item)
                    if isLocked then
                        table.insert(lockedList, item)
                    end
                end
            end
        end
    end

    table.sort(lockedList, function(a, b)
        return a.rung < b.rung
    end)

    return {
        raw = raw,
        unlockedCount = #unlockedIndices,
        emptyIndices = emptyIndices,
        occupied = occupied,
        lockedList = lockedList,
    }
end

local function ComputeMinFarmPedestals(unlockedCount)
    if unlockedCount <= 1 then
        return unlockedCount
    end
    if type(Config.MinFarmPedestals) == "number" then
        return math.clamp(math.floor(Config.MinFarmPedestals), 1, math.max(1, unlockedCount - 1))
    end
    return (unlockedCount >= 5) and 2 or 1
end

local function GetServerMaxBelow()
    if PT_AutoBreak and PT_AutoBreak.MaxBelow then
        local ok, m = pcall(PT_AutoBreak.MaxBelow)
        if ok and type(m) == "number" then
            return m
        end
    end
    local f = tonumber(GetFlag("PumpkinTycoon_AutoBreakFreeBelow", 8))
    return f or 8
end

local function IsProtectedForLockQueue(pedInfo, maxKeepSlots, rung)
    local lockMin = tonumber(Config.LockMinRung) or 5
    if rung < lockMin then
        return false
    end
    -- Skip temporarily only if Loop A can lock it outright or swap out a weaker locked pedestal
    if #pedInfo.lockedList < maxKeepSlots then
        return true
    end
    if Config.AutoLockUpgradeSwap and #pedInfo.lockedList > 0 and rung > pedInfo.lockedList[1].rung then
        return true
    end
    return false
end

local lastPolicyInvoke = 0
local function StepKeepLockAndStock(plot, buttons, part1Complete)
    if not plot or not Modules.MerchantTypes then
        return
    end
    local pedInfo = AnalyzePedestals(plot)
    if pedInfo.unlockedCount == 0 then
        return
    end

    local minFarm = ComputeMinFarmPedestals(pedInfo.unlockedCount)
    local maxKeepSlots = math.max(0, pedInfo.unlockedCount - minFarm)
    local lockedList = pedInfo.lockedList

    -- Nếu BreakAllPumpkins bật: Mở khóa TOÀN BỘ bệ thờ để dàn Pet và Player đập sạch
    if Config.BreakAllPumpkins then
        for _, l in ipairs(pedInfo.lockedList) do
            pcall(function()
                plot:Invoke(NET.SetLock, l.index, false)
            end)
            task.wait(0.02)
        end
        pedInfo.lockedList = {}
        lockedList = {}
    end

    -- 1. Enforce MinFarmPedestals invariant (never lock more pedestals than maxKeepSlots)
    while #lockedList > maxKeepSlots do
        local weakest = table.remove(lockedList, 1)
        pcall(function()
            plot:Invoke(NET.SetLock, weakest.index, false)
        end)
        task.wait(0.04)
    end

    -- 2. Lock high-value pedestals (>= LockMinRung), swapping weaker locked ones if higher spawns
    local candidates = {}
    for _, occ in ipairs(pedInfo.occupied) do
        if not occ.locked and occ.rung >= (Config.LockMinRung or 5) then
            table.insert(candidates, occ)
        end
    end
    table.sort(candidates, function(a, b)
        return a.rung > b.rung
    end)

    for _, cand in ipairs(candidates) do
        if Config.BreakAllPumpkins then break end
        if #lockedList < maxKeepSlots then
            local ok, res = pcall(function()
                return plot:Invoke(NET.SetLock, cand.index, true)
            end)
            if ok and res ~= false then
                cand.locked = true
                table.insert(lockedList, cand)
                table.sort(lockedList, function(a, b)
                    return a.rung < b.rung
                end)
            end
            task.wait(0.04)
        elseif Config.AutoLockUpgradeSwap and #lockedList > 0 and cand.rung > lockedList[1].rung then
            local weakest = table.remove(lockedList, 1)
            local uOk = pcall(function()
                return plot:Invoke(NET.SetLock, weakest.index, false)
            end)
            if uOk then
                task.wait(0.04)
                local lOk, lRes = pcall(function()
                    return plot:Invoke(NET.SetLock, cand.index, true)
                end)
                if lOk and lRes ~= false then
                    cand.locked = true
                    table.insert(lockedList, cand)
                    table.sort(lockedList, function(a, b)
                        return a.rung < b.rung
                    end)
                end
            end
            task.wait(0.04)
        end
    end

    -- 3. AutoPlace Stock setting + proactive allocation onto empty pedestals (highest band first)
    local merchantOwned = Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, Modules.MerchantTypes.BUTTON)
    if merchantOwned and Config.AutoPlaceStock then
        local currentAutoPlace = plot:Save("StockAutoPlace")
        if currentAutoPlace == false and Runtime.Cache.LastAutoPlace ~= true then
            Runtime.Cache.LastAutoPlace = true
            pcall(function()
                plot:Invoke(NET.SetAutoPlace, true)
            end)
        end

        local stockList = Modules.MerchantTypes.CleanStock(plot:Save(VAR.Stock))
        if #stockList > 0 and #pedInfo.emptyIndices > 0 then
            local counts = {}
            for _, bandKey in ipairs(stockList) do
                counts[bandKey] = (counts[bandKey] or 0) + 1
            end
            local bands = Modules.MerchantTypes.BANDS or {}
            local emptyCursor = 1
            for idx = #bands, 1, -1 do
                local bandKey = bands[idx]
                while (counts[bandKey] or 0) > 0 and emptyCursor <= #pedInfo.emptyIndices do
                    local emptyPedIdx = pedInfo.emptyIndices[emptyCursor]
                    local ok, res = pcall(function()
                        return plot:Invoke(NET.PlaceStock, emptyPedIdx, bandKey)
                    end)
                    emptyCursor = emptyCursor + 1
                    counts[bandKey] = counts[bandKey] - 1
                    if not ok or res == false then
                        break
                    end
                    task.wait(0.04)
                end
            end
        end
    end

    -- 4. Adaptive Keep Rule (QW_Policy): protect target KeepRung until Keep slots saturate, then Secret-guard
    if os.clock() - lastPolicyInvoke >= 0.6 then
        local maxAllowed = GetServerMaxBelow()
        local keepDesired = math.clamp(math.floor(Config.KeepRung or 5), 0, maxAllowed)
        if keepDesired == 1 then
            keepDesired = 0
        end

        local targetPolicy = keepDesired
        if pedInfo.unlockedCount <= minFarm then
            targetPolicy = 0
        elseif #lockedList >= maxKeepSlots then
            -- Lock slots full; only pause Secret spawns briefly until Lock loop swaps them in
            targetPolicy = (maxAllowed >= 8) and 8 or 0
        end

        local rawAuto = plot:Save(VAR.AutoBreak)
        local currentPolicy = (type(rawAuto) == "table" and tonumber(rawAuto.Below))
            or tonumber(rawAuto)
            or 0
        if currentPolicy ~= targetPolicy then
            lastPolicyInvoke = os.clock()
            local ok, res = pcall(function()
                return plot:Invoke(NET.SetAutoBreak, targetPolicy)
            end)
            if ok and res ~= false then
                Log("DEBUG", "Updated Keep policy (QW_Policy): %d -> %d (locked %d/%d)", currentPolicy, targetPolicy, #lockedList, maxKeepSlots)
            end
        end
    end

    -- 5. Merchant Buying & Server AutoMerchant control
    if not merchantOwned then
        return
    end

    -- Keep server HM_Sustain OFF if configured so it doesn't fill stock slots with low tiers
    local autoOn = plot:Save(Modules.MerchantTypes.AUTO_VAR) == true
    if (Config.KeepServerAutoMerchantOff or (Config.RushButtonsFirst and not part1Complete)) and autoOn then
        pcall(function()
            plot:Invoke(NET.SetAutoMerchant, false)
        end)
    end

    if not Config.AutoBuyMerchant or (Config.MerchantRequireButtonsComplete and not part1Complete) then
        return
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    Runtime.Stats.Coins = coins
    local activateCoins = tonumber(Config.MerchantActivateCoins) or 0
    local spareCoins = tonumber(Config.MerchantMinSpareCoins) or 0
    if coins < activateCoins then
        return
    end

    local merchantClean = Modules.MerchantTypes.Clean(plot:Save(VAR.Merchant))
    if not merchantClean or type(merchantClean.Items) ~= "table" then
        return
    end

    if os.clock() - (Runtime.Cache.LastMerchantFailAt or 0) < 15 then
        return
    end

    local stockCount = #Modules.MerchantTypes.CleanStock(plot:Save(VAR.Stock))
    local maxSlots = LocalPlayer:GetAttribute(Modules.MerchantTypes.ATTR_SLOTS) or Modules.MerchantTypes.BaseSlots()
    local bandConfigs = Modules.MerchantTypes.Config()

    local hasCandidate = false
    for _, bandKey in ipairs(Config.MerchantBandOrder or {}) do
        if Config.AllowedMerchantBands[bandKey] == true then
            local avail = merchantClean.Items[bandKey] or 0
            local bandCfg = bandConfigs and bandConfigs[bandKey]
            local price = bandCfg and bandCfg.Price
            if avail > 0 and stockCount < maxSlots and price and coins >= activateCoins and (coins - price) >= spareCoins then
                hasCandidate = true
                break
            end
        end
    end
    if not hasCandidate then
        return
    end

    WithMachinePad(plot, Modules.MerchantTypes.MACHINE, Modules.MerchantTypes.Range, function()
        for _, bandKey in ipairs(Config.MerchantBandOrder or {}) do
            if Config.AllowedMerchantBands[bandKey] == true then
                local avail = merchantClean.Items[bandKey] or 0
                local bandCfg = bandConfigs and bandConfigs[bandKey]
                local price = bandCfg and bandCfg.Price
                while IsRunning() and avail > 0 and stockCount < maxSlots and price and coins >= activateCoins and (coins - price) >= spareCoins do
                    local ok, res, reason = pcall(function()
                        return plot:Invoke(NET.BuyBand, bandKey)
                    end)
                    if not ok or res ~= true then
                        Runtime.Cache.LastMerchantFailAt = os.clock()
                        Log("DEBUG", "Merchant buy failed [%s]: %s", tostring(bandKey), tostring(reason or res))
                        return
                    end
                    Runtime.Cache.LastMerchantFailAt = 0
                    avail = avail - 1
                    stockCount = stockCount + 1
                    coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
                    Runtime.Stats.Coins = coins
                    Log("INFO", "Bought Merchant %s pumpkin for %s Coins", bandKey, tostring(price))
                    task.wait(0.05)
                end
            end
        end
    end)
end

-- ============================================================================
-- 7. BREAKABLES FARM ENGINE (ULTRA-FAST TAP + PET TARGETING + ORBS/LOOTBAGS)
-- ============================================================================
local activeFarmTarget = nil -- { uid = string, model = Model, pos = Vector3, isBonus = bool, rung = number }

local function BelongsToPlot(model, attrs, islandBox, plotId, plotSuffix)
    if type(attrs) == "table" and attrs.Plot ~= nil then
        return attrs.Plot == plotId
    end
    local owner = model:GetAttribute("OwnerUsername")
    if owner ~= nil then
        return owner == LocalPlayer.Name
    end
    local areaId = model:GetAttribute("AreaID")
    if type(areaId) == "string" and plotSuffix then
        if string.sub(areaId, -#plotSuffix) == plotSuffix then
            return true
        end
        if string.find(areaId, "_Zone_", 1, true) then
            return false
        end
    end
    return IsOnMyIsland(model, islandBox)
end

local function ResolveBreakableZoneIndex(data, model, attrs)
    local zn = tonumber(data and data.zoneNumber) or tonumber(attrs and attrs.ZoneNumber)
    if not zn and model then
        zn = tonumber(model:GetAttribute("ZoneNumber"))
    end
    if zn and zn >= 1 then
        return zn
    end
    local areaId = (data and data.areaID) or (attrs and attrs.AreaID) or (model and model:GetAttribute("AreaID"))
    if type(areaId) == "string" and PT and type(PT.ZONES) == "table" then
        for i, z in ipairs(PT.ZONES) do
            if z and z.Section and string.find(areaId, z.Section, 1, true) then
                return i
            end
        end
    end
    return 1
end

local function CollectMyBreakables(plot, pedInfo)
    if not plot or not Modules.BreakableFrontend or not Modules.BreakableFrontend.AllByInstanceAndClass then
        return {}
    end

    local allByClass = {}
    for _, cls in ipairs({ "Chest", "Normal" }) do
        local ok, res = pcall(Modules.BreakableFrontend.AllByInstanceAndClass, cls)
        if ok and type(res) == "table" then
            for uid, data in pairs(res) do
                allByClass[uid] = data
            end
        end
    end

    local islandBox = GetIslandBox(plot)
    local plotId = plot:GetId()
    local plotSuffix = plotId and ("_" .. tostring(plotId)) or nil
    local minFarm = ComputeMinFarmPedestals(pedInfo.unlockedCount)
    local maxKeepSlots = math.max(0, pedInfo.unlockedCount - minFarm)
    local lockedPedestals = {}
    for _, l in ipairs(pedInfo.lockedList) do
        lockedPedestals[l.index] = true
    end

    local _, hrp = GetCharacter()
    local playerPos = hrp and hrp.Position
    local targets = {}
    local emergencyFallback = {}

    for uid, data in pairs(allByClass) do
        local model = data and data.model
        local attrs = (data and data.clientAttributes) or {}
        if model and model.Parent and BelongsToPlot(model, attrs, islandBox, plotId, plotSuffix) then
            local isBonus = (attrs.OrchardChest ~= nil) or (attrs.HayPile == true)
            local pedIdx = attrs.PumpkinPedestal
            local rung = tonumber(attrs.PumpkinRung) or 1

            local valid = false
            local eligibleFallback = false
            if isBonus and Config.FarmOrchardAndHay then
                valid = true
            elseif type(pedIdx) == "number" then
                if Config.BreakAllPumpkins or not lockedPedestals[pedIdx] then
                    eligibleFallback = true
                    valid = true
                end
            else
                -- Normal zone breakables (coins, crates, presents, safes) on our island/zone
                valid = true
            end

            if valid or eligibleFallback then
                if valid and model:GetAttribute("ManualDamage") ~= nil then
                    pcall(function()
                        model:SetAttribute("ManualDamage", nil)
                    end)
                end
                local pos = model:GetPivot().Position
                local dist = playerPos and HorizontalDist(playerPos, pos) or 0
                local zoneNum = (not isBonus and type(pedIdx) ~= "number") and ResolveBreakableZoneIndex(data, model, attrs) or 0
                local score
                if isBonus then
                    score = 1000000 - (dist * 0.25)
                elseif type(pedIdx) == "number" then
                    score = (Config.BreakAllPumpkins and 200000 or 50000) + (rung * 1000) - (dist * 0.25)
                else
                    -- Highest unlocked Zone dominates distance penalty across the whole island
                    score = 5000 + (zoneNum * 2000) - (dist * 0.25)
                end
                local entry = {
                    uid = tostring(uid),
                    model = model,
                    pos = pos,
                    isBonus = isBonus,
                    isPedestal = (type(pedIdx) == "number"),
                    zone = zoneNum,
                    rung = rung,
                    dist = dist,
                    score = score,
                }
                if valid then
                    table.insert(targets, entry)
                else
                    table.insert(emergencyFallback, entry)
                end
            end
        end
    end

    if #targets == 0 and #emergencyFallback > 0 then
        -- Deadlock safety: break lowest-rung unlocked pedestal if every unlocked slot paused simultaneously
        table.sort(emergencyFallback, function(a, b)
            if a.rung ~= b.rung then
                return a.rung < b.rung
            end
            return a.dist < b.dist
        end)
        return { emergencyFallback[1] }
    end

    table.sort(targets, function(a, b)
        return a.score > b.score
    end)

    return targets
end

local function HoldPetOnModel(pet, targetModel)
    if not pet or not targetModel or not targetModel.Parent then
        return
    end
    local okT, tgtType = pcall(pet.GetTargetType, pet)
    local okG, curTgt = pcall(pet.GetTarget, pet)
    if not okT or not okG or tgtType ~= "Breakable" or curTgt ~= targetModel then
        pcall(pet.SetAnchored, pet, false)
        pcall(pet.SetTarget, pet, targetModel)
    end
    pet.AIHold = "PumpkinKaitun"
end

local function GetControllablePets()
    if not Config.AutoPetFocus or not Modules.PlayerPet or not Modules.PlayerPet.GetByPlayer then
        return nil
    end
    local ok, pets = pcall(Modules.PlayerPet.GetByPlayer, LocalPlayer)
    if not ok or type(pets) ~= "table" then
        return nil
    end
    local list = {}
    for _, pet in pairs(pets) do
        if pet and (pet.AIHold == nil or pet.AIHold == "PumpkinAutoBreak" or pet.AIHold == "PumpkinKaitun") then
            table.insert(list, pet)
        end
    end
    return list
end

local function AssignPetsToModel(targetModel)
    if not targetModel or not targetModel.Parent then
        return
    end
    local pets = GetControllablePets()
    if not pets then
        return
    end
    for _, pet in ipairs(pets) do
        HoldPetOnModel(pet, targetModel)
    end
end

local function AssignPetsSpread(zonePool)
    if type(zonePool) ~= "table" or #zonePool == 0 then
        return
    end
    local pets = GetControllablePets()
    if not pets or #pets == 0 then
        return
    end

    local poolByModel = {}
    local claimedCount = {}
    for _, entry in ipairs(zonePool) do
        if entry.model and entry.model.Parent then
            poolByModel[entry.model] = entry
            claimedCount[entry.model] = 0
        end
    end

    local needAssign = {}
    for _, pet in ipairs(pets) do
        local okT, tgtType = pcall(pet.GetTargetType, pet)
        local okG, curTgt = pcall(pet.GetTarget, pet)
        if okT and okG and tgtType == "Breakable" and curTgt and poolByModel[curTgt] and claimedCount[curTgt] < 1 then
            claimedCount[curTgt] = claimedCount[curTgt] + 1
            pet.AIHold = "PumpkinKaitun"
        else
            table.insert(needAssign, pet)
        end
    end

    for _, pet in ipairs(needAssign) do
        local bestEntry = nil
        local bestCount = math.huge
        for _, entry in ipairs(zonePool) do
            if entry.model and entry.model.Parent then
                local c = claimedCount[entry.model] or 0
                if c < bestCount then
                    bestCount = c
                    bestEntry = entry
                    if c == 0 then
                        break
                    end
                end
            end
        end
        if bestEntry then
            HoldPetOnModel(pet, bestEntry.model)
            claimedCount[bestEntry.model] = (claimedCount[bestEntry.model] or 0) + 1
        end
    end
end

local function GetTapReach()
    if PT_AutoBreak and PT_AutoBreak.TapReach then
        local ok, r = pcall(PT_AutoBreak.TapReach)
        if ok and type(r) == "number" then
            return r
        end
    end
    return 18
end

local function StepFarmTargeter(plot)
    if not Config.AutoFarm or not plot then
        activeFarmTarget = nil
        Runtime.Stats.ActiveTargetUid = nil
        Runtime.Stats.ActiveTargetDesc = "Idle"
        ReleaseHeldPets()
        return
    end

    local pedInfo = AnalyzePedestals(plot)
    local targets = CollectMyBreakables(plot, pedInfo)
    if #targets == 0 then
        activeFarmTarget = nil
        Runtime.Stats.ActiveTargetUid = nil
        Runtime.Stats.ActiveTargetDesc = "Waiting spawn"
        return
    end

    -- Sticky target hysteresis to avoid rapid flickering; break immediately for BonusChest, Pedestal, or a higher Zone
    local chosen = targets[1]
    if activeFarmTarget and activeFarmTarget.model and activeFarmTarget.model.Parent then
        for _, cand in ipairs(targets) do
            if cand.uid == activeFarmTarget.uid then
                local upgradeToPedestal = chosen.isPedestal and not cand.isPedestal
                local upgradeToHigherZone = (not cand.isPedestal) and (not chosen.isPedestal) and ((chosen.zone or 1) > (cand.zone or 1))
                if not chosen.isBonus and not upgradeToPedestal and not upgradeToHigherZone and chosen.rung < cand.rung + 2 then
                    chosen = cand
                end
                break
            end
        end
    end

    activeFarmTarget = chosen
    Runtime.Stats.ActiveTargetUid = chosen.uid
    Runtime.Stats.ActiveTargetDesc = chosen.isBonus and "BonusChest"
        or (chosen.isPedestal and ("Ped-Rung-" .. tostring(chosen.rung)) or ("Zone-" .. tostring(chosen.zone or 1)))

    -- Never steal character position while active Hatch loop or Machine Pad action holds position lock
    if Config.AutoTeleportToTarget and not Runtime.Stats.IsHatching and not IsMoveLocked() then
        local reach = GetTapReach()
        local moveRange = math.max(10, reach - 5)
        if chosen.dist > moveRange then
            MoveNear(chosen.pos, moveRange)
        end
    end

    if not chosen.isBonus and not chosen.isPedestal and Config.AutoSpreadZoneBreakables ~= false then
        local topZone = chosen.zone or 1
        local zonePool = {}
        for _, cand in ipairs(targets) do
            if not cand.isBonus and not cand.isPedestal and (cand.zone or 1) == topZone then
                table.insert(zonePool, cand)
            end
        end
        if #zonePool > 0 then
            AssignPetsSpread(zonePool)
            return
        end
    end

    AssignPetsToModel(chosen.model)
end

local function StepRapidTap()
    if not Config.AutoTap or not activeFarmTarget then
        return
    end
    local model = activeFarmTarget.model
    if not model or not model.Parent then
        return
    end
    local _, hrp = GetCharacter()
    if not hrp then
        return
    end

    local attrReach = tonumber(model:GetAttribute("AutoTapRadius"))
    local reach = attrReach and math.max(GetTapReach(), attrReach) or GetTapReach()
    if HorizontalDist(hrp.Position, model:GetPivot().Position) > reach then
        return
    end

    if Modules.Signal and Modules.Signal.Fire then
        pcall(Modules.Signal.Fire, "AutoClicker_Nearby", activeFarmTarget.uid)
    end
    if Modules.Network and Modules.Network.UnreliableFire then
        pcall(Modules.Network.UnreliableFire, "Breakables_PlayerDealDamage", activeFarmTarget.uid)
    end
end

local cachedOrbRemote = nil
local function FireOrbsCollect(batch)
    if not cachedOrbRemote or not cachedOrbRemote.Parent then
        local netFolder = ReplicatedStorage:FindFirstChild("Network")
        cachedOrbRemote = netFolder and netFolder:FindFirstChild("Orbs: Collect")
    end
    if cachedOrbRemote and cachedOrbRemote:IsA("RemoteEvent") then
        pcall(cachedOrbRemote.FireServer, cachedOrbRemote, batch)
    elseif Modules.Network and Modules.Network.Fire then
        pcall(Modules.Network.Fire, "Orbs: Collect", batch)
    end
end

local function SweepDrops()
    if not Config.AutoCollectOrbs then
        return
    end
    local things = Workspace:FindFirstChild("__THINGS")
    local orbsFolder = things and things:FindFirstChild("Orbs")
    if not orbsFolder then
        return
    end

    local _, hrp = GetCharacter()
    local orbIds = {}
    local seen = {}
    for _, orb in ipairs(orbsFolder:GetChildren()) do
        local rawId = orb:GetAttribute("OrbID") or orb:GetAttribute("id") or orb.Name
        local numId = tonumber(rawId)
        if numId and not seen[numId] then
            seen[numId] = true
            table.insert(orbIds, numId)
        end
        if hrp then
            pcall(function()
                if orb:IsA("BasePart") then
                    orb.CFrame = hrp.CFrame
                elseif orb:IsA("Model") then
                    orb:PivotTo(hrp.CFrame)
                end
            end)
        end
        if #orbIds >= 50 then
            local batch = orbIds
            orbIds = {}
            FireOrbsCollect(batch)
        end
    end
    if #orbIds > 0 then
        FireOrbsCollect(orbIds)
    end
end

-- ============================================================================
-- 8. TYCOON BUTTONS RUSH & COMPLETION CLAIM
-- ============================================================================
local function IsCriticalRootButton(btn)
    if btn.Opens or btn.PathIndex or btn.Egg or btn.Pedestal then
        return true
    end
    if btn.Id == "UpgradeMachine" or btn.Id == "CocoaStand" or btn.Id == "GoldMachine" or btn.Id == "RainbowMachine" or btn.Subclass == "IslandLuck" then
        return true
    end
    if string.sub(btn.Id, 1, 12) == "OrchardChest" or string.sub(btn.Id, -5) == "_Luck" or string.find(btn.Id, "Pedestal", 1, true) then
        return true
    end
    return false
end

local function GetCriticalButtonSet()
    if Runtime.Cache.CriticalButtons ~= nil then
        return Runtime.Cache.CriticalButtons
    end
    local set = {}
    local byId = Modules.ButtonsTypes and Modules.ButtonsTypes.BY_ID
    local list = Modules.ButtonsTypes and Modules.ButtonsTypes.BUTTONS
    if type(list) == "table" then
        local queue = {}
        for _, btn in ipairs(list) do
            if type(btn) == "table" and btn.Id and (btn.Part or 1) == 1 and IsCriticalRootButton(btn) then
                if not set[btn.Id] then
                    set[btn.Id] = true
                    table.insert(queue, btn)
                end
            end
        end
        local idx = 1
        while idx <= #queue do
            local curr = queue[idx]
            idx = idx + 1
            if type(curr.Required) == "table" and type(byId) == "table" then
                for _, reqId in ipairs(curr.Required) do
                    if not set[reqId] then
                        set[reqId] = true
                        local reqBtn = byId[reqId]
                        if type(reqBtn) == "table" then
                            table.insert(queue, reqBtn)
                        end
                    end
                end
            end
        end
    end
    Runtime.Cache.CriticalButtons = set
    return set
end

local function GetButtonPriorityRank(btn)
    if IsCriticalRootButton(btn) or GetCriticalButtonSet()[btn.Id] then
        return 1
    end
    if btn.Id == "Merchant" then
        return 2
    end
    return 3
end

local function GetButtonPriceMult()
    if PT_Buttons and PT_Buttons.PriceMult then
        local ok, mult = pcall(PT_Buttons.PriceMult)
        if ok and type(mult) == "number" then
            return mult
        end
    end
    return tonumber(GetFlag("PumpkinTycoon_ButtonPriceMult", 1)) or 1
end

local EvaluateEarlyBootstrap -- Forward-declared for StepButtonsAndComplete Coin reservation

local function StepButtonsAndComplete(plot)
    if not plot or not Modules.PumpkinButtonsUtil then
        return nil, false, false
    end

    local buttons, part1Complete, claimedComplete = GetProgressState(plot)

    if Config.AutoCompleteTycoon and part1Complete and not claimedComplete then
        local ok, res = pcall(function()
            return plot:Invoke(NET.Complete)
        end)
        if ok and res ~= false then
            Log("INFO", "Claimed Tycoon Part 1 completion reward!")
            buttons, part1Complete, claimedComplete = GetProgressState(plot)
        end
    end

    if not Config.AutoBuyButtons then
        return buttons, part1Complete, claimedComplete
    end

    local part2 = GetFlag("PumpkinTycoon_Part2", false) == true
    local zones = GetZoneCount()
    local priceMult = GetButtonPriceMult()
    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")

    if EvaluateEarlyBootstrap and not part1Complete then
        EvaluateEarlyBootstrap(plot, buttons)
    else
        Runtime.Cache.ReserveEarlyEggCost = 0
    end

    -- Burst buy all currently affordable unlocked buttons in progression priority order
    local boughtThisPass = 0
    while IsRunning() and boughtThisPass < 100 do
        if Config.RushButtonsFirst and not part1Complete and Runtime.Stats.IsHatching then
            break
        end
        local spendableCoins = math.max(0, coins - (Runtime.Cache.ReserveEarlyEggCost or 0))
        local avail = Modules.PumpkinButtonsUtil.Available(buttons, zones, part2, priceMult)
        local hasRank1 = false
        local minRank1Price = math.huge
        local candidates = {}
        local bestNextBtn = nil
        local bestNextPrice = math.huge
        local bestNextRank = math.huge

        for _, btn in ipairs(avail) do
            local rank = GetButtonPriorityRank(btn)
            local price = Modules.PumpkinButtonsUtil.Price(btn, priceMult)
            if rank == 1 then
                hasRank1 = true
                if price < minRank1Price then
                    minRank1Price = price
                end
            end
            if rank < bestNextRank or (rank == bestNextRank and price < bestNextPrice) then
                bestNextRank = rank
                bestNextPrice = price
                bestNextBtn = btn
            end
            if price <= spendableCoins then
                table.insert(candidates, { btn = btn, price = price, rank = rank })
            end
        end

        if bestNextBtn then
            Runtime.Stats.NextButtonName = tostring(bestNextBtn.Display or bestNextBtn.Id or "N/A")
            Runtime.Stats.NextButtonCost = bestNextPrice
            Runtime.Stats.MissingCoins = math.max(0, bestNextPrice - spendableCoins)
        elseif part1Complete then
            Runtime.Stats.NextButtonName = "Đã xong tất cả"
            Runtime.Stats.NextButtonCost = 0
            Runtime.Stats.MissingCoins = 0
        else
            Runtime.Stats.NextButtonName = "Chờ mở khóa"
            Runtime.Stats.NextButtonCost = 0
            Runtime.Stats.MissingCoins = 0
        end

        local affordable = {}
        for _, item in ipairs(candidates) do
            -- Save coins for the next critical-path button instead of draining budget on cosmetic leaves
            if item.rank == 1 or not hasRank1 or item.price <= (minRank1Price * 0.05) then
                table.insert(affordable, item)
            end
        end
        if #affordable == 0 then
            break
        end

        table.sort(affordable, function(a, b)
            if a.rank ~= b.rank then
                return a.rank < b.rank
            end
            if a.price ~= b.price then
                return a.price < b.price
            end
            return a.btn.Id < b.btn.Id
        end)

        local pick = affordable[1]
        local ok, res = pcall(function()
            return plot:Invoke(NET.Buy, pick.btn.Id)
        end)
        if not ok or res == false then
            break
        end
        boughtThisPass = boughtThisPass + 1
        Log("INFO", "Bought Button [%s] (%s) for %s Coins", pick.btn.Id, tostring(pick.btn.Display), tostring(pick.price))
        buttons, part1Complete, claimedComplete = GetProgressState(plot)
        coins = Runtime.Stats.Coins
        if EvaluateEarlyBootstrap and not part1Complete then
            EvaluateEarlyBootstrap(plot, buttons)
        else
            Runtime.Cache.ReserveEarlyEggCost = 0
        end
        task.wait(0.02)
    end

    if Config.AutoCompleteTycoon and part1Complete and not claimedComplete then
        local ok, res = pcall(function()
            return plot:Invoke(NET.Complete)
        end)
        if ok and res ~= false then
            Log("INFO", "Claimed Tycoon Part 1 completion reward!")
            buttons, part1Complete, claimedComplete = GetProgressState(plot)
        end
    end

    return buttons, part1Complete, claimedComplete
end

-- ============================================================================
-- 9. UPGRADES ENGINE (PUMPKIN TOKENS)
-- ============================================================================
local function GetUpgradeCostMult()
    if Modules.PumpkinUpgradesUtil and Modules.PumpkinUpgradesUtil.CostMult then
        local ok, mult = pcall(Modules.PumpkinUpgradesUtil.CostMult)
        if ok and type(mult) == "number" then
            return mult
        end
    end
    return 1
end

local function GetTrackNextInfo(trackKey)
    local row = Modules.UpgradesTypes and Modules.UpgradesTypes.ROWS and Modules.UpgradesTypes.ROWS[trackKey]
    if not row or not Modules.UpgradesTypes.Id then
        return nil
    end
    local tier = 0
    if Modules.EventUpgradeCmds and Modules.EventUpgradeCmds.GetTier then
        local ok, t = pcall(Modules.EventUpgradeCmds.GetTier, Modules.UpgradesTypes.Id(trackKey))
        if ok and type(t) == "number" then
            tier = t
        end
    end
    local maxTier = #row.Powers
    if tier >= maxTier then
        return nil
    end
    local baseCost = row.Costs[tier + 1]
    if not baseCost then
        return nil
    end
    local liveCost = math.max(1, math.ceil(baseCost * GetUpgradeCostMult()))
    return { track = trackKey, nextTier = tier + 1, baseCost = baseCost, cost = liveCost }
end

local function StepUpgrades(plot, buttons)
    if not Config.AutoUpgrades or not plot or not Modules.UpgradesTypes or not Modules.PumpkinButtonsUtil then
        return
    end
    local machineButton = Modules.UpgradesTypes.BUTTON or "UpgradeMachine"
    if not Modules.PumpkinButtonsUtil.Owned(buttons, machineButton) then
        return
    end

    local catchupRatio = tonumber(Config.UpgradeCheapCatchupRatio) or 0
    local maxCheapTier1 = tonumber(Config.UpgradeCheapTier1MaxBaseCost) or 50
    local maxBuys = 15
    for _ = 1, maxBuys do
        if not IsRunning() then
            break
        end
        local tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
        Runtime.Stats.Tokens = tokens

        local infos = {}
        local pendingCheapTier1 = nil
        local topCandidate = nil
        for _, trackKey in ipairs(Config.UpgradePriority or {}) do
            local info = GetTrackNextInfo(trackKey)
            if info then
                table.insert(infos, info)
                if not topCandidate then
                    topCandidate = info
                end
                if not pendingCheapTier1
                    and Config.UpgradeTier1CheapFirst
                    and info.nextTier == 1
                    and info.baseCost <= maxCheapTier1
                then
                    pendingCheapTier1 = info
                end
            end
        end

        local selected = nil
        if pendingCheapTier1 then
            if tokens >= pendingCheapTier1.cost then
                selected = pendingCheapTier1
            end
        elseif topCandidate then
            for _, info in ipairs(infos) do
                if tokens >= info.cost then
                    if info == topCandidate then
                        selected = info
                        break
                    elseif catchupRatio > 0 and info.cost <= (topCandidate.cost * catchupRatio) then
                        selected = info
                        break
                    end
                end
            end
        end

        if not selected then
            break
        end

        local ok, res = pcall(function()
            return plot:Invoke(NET.UpgradeBuy, selected.track)
        end)
        if not ok or res == false then
            break
        end
        Runtime.Stats.Tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
        Log("INFO", "Upgraded [%s] to Tier %d for %s Tokens", selected.track, selected.nextTier, tostring(selected.cost))
        task.wait(0.04)
    end
end

-- ============================================================================
-- 10. CONSUMABLE BOOSTS, HOT COCOA STAND & FLANNEL GIFTS
-- ============================================================================
local function GetBoostTimerSeconds(boostId)
    if not Modules.BoostCmds or not Modules.BoostCmds.GetTimer then
        return 0
    end
    local ok, sec = pcall(Modules.BoostCmds.GetTimer, boostId)
    return (ok and type(sec) == "number") and sec or 0
end

local function StepConsumableBoosts()
    if not Config.AutoConsumeBoosts or not Modules.PumpkinBoostsUtil or not Modules.Save or not Modules.Network then
        return
    end
    local okSave, saveData = pcall(Modules.Save.Get)
    local consumables = okSave and saveData and saveData.Inventory and saveData.Inventory.Consumable
    if type(consumables) ~= "table" then
        return
    end

    local itemToAxis = {}
    for axis, itemName in pairs(Modules.PumpkinBoostsUtil.ITEMS or {}) do
        itemToAxis[itemName] = axis
    end

    -- Collect matching event consumables and prioritize Tier 2 before Tier 1
    local threshold = tonumber(Config.BoostRefreshSeconds) or 15
    local now = os.clock()
    local candidates = {}

    for uid, data in pairs(consumables) do
        if type(data) == "table" then
            local itemName = tostring(data.id or data._id or "")
            local axis = itemToAxis[itemName]
            if axis and Config.AllowedConsumableBoosts[itemName] ~= false then
                local tier = math.clamp(math.floor(tonumber(data.tn or data.tier or 1) or 1), 1, 2)
                table.insert(candidates, {
                    uid = tostring(uid),
                    itemName = itemName,
                    axis = axis,
                    tier = tier,
                    boostId = Modules.PumpkinBoostsUtil.Id(axis, tier),
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.tier ~= b.tier then
            return a.tier > b.tier
        end
        return a.axis < b.axis
    end)

    for _, cand in ipairs(candidates) do
        local lastAt = Runtime.Cache.BoostConsumeCooldown[cand.boostId] or 0
        if (now - lastAt) >= 3.0 and GetBoostTimerSeconds(cand.boostId) <= threshold then
            local cOk, cRes = pcall(Modules.Network.Invoke, "Consumables_Consume", cand.uid, 1)
            if cOk and cRes ~= false then
                Runtime.Cache.BoostConsumeCooldown[cand.boostId] = now
                Log("INFO", "Consumed %s Tier %d (%s)", cand.itemName, cand.tier, cand.boostId)
                task.wait(0.05)
            end
        end
    end
end

local lastCocoaCheck = 0
local function StepHotCocoaStand(plot, buttons, part1Complete)
    if not Config.AutoCocoaStand or not plot or not Modules.PumpkinCocoaUtil or not Modules.PumpkinBoostsUtil then
        return
    end
    if not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned(buttons, Modules.PumpkinCocoaUtil.BUTTON) then
        return
    end
    if os.clock() - lastCocoaCheck < 1.5 then
        return
    end
    lastCocoaCheck = os.clock()

    if os.clock() - (Runtime.Cache.LastCocoaFailAt or 0) < 15 then
        return
    end

    if Config.CocoaRequireButtonsComplete and not part1Complete then
        return
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    Runtime.Stats.Coins = coins
    local activateCoins = tonumber(Config.CocoaActivateCoins) or 0
    local spareCoins = tonumber(Config.CocoaMinSpareCoins) or 0
    if coins < activateCoins then
        return
    end

    local tier = Modules.PumpkinCocoaUtil.TIER or 1
    local costPerMin = Modules.PumpkinCocoaUtil.CostPerMinute and Modules.PumpkinCocoaUtil.CostPerMinute(tier)
    if type(costPerMin) ~= "number" or costPerMin <= 0 then
        return
    end

    local maintainSec = (tonumber(Config.CocoaMaintainMinutes) or 2) * 60
    local stepMin = math.max(1, math.floor(tonumber(Config.CocoaBuyStepMinutes) or 2))
    local tankSec = (Modules.PumpkinCocoaUtil.TankSeconds and Modules.PumpkinCocoaUtil.TankSeconds()) or (720 * 60)

    local pending = {}
    local simCoins = coins
    for _, axis in ipairs(Config.CocoaAxes or {}) do
        if simCoins < activateCoins then
            break
        end
        local boostId = Modules.PumpkinBoostsUtil.Id(axis, tier)
        local validOffer = (not Modules.PumpkinCocoaUtil.Offer) or (Modules.PumpkinCocoaUtil.Offer(boostId) ~= nil)
        if validOffer then
            local remaining = GetBoostTimerSeconds(boostId)
            if remaining < maintainSec then
                local needMin = math.max(1, math.ceil((maintainSec - remaining) / 60))
                local maxTankMin = math.floor(math.max(0, tankSec - remaining) / 60)
                local affordableMin = math.floor(math.max(0, simCoins - spareCoins) / costPerMin)
                local buyMin = math.min(stepMin, needMin, maxTankMin, affordableMin)
                if buyMin >= 1 then
                    table.insert(pending, { boostId = boostId, buyMin = buyMin })
                    simCoins = simCoins - (buyMin * costPerMin)
                end
            end
        end
    end
    if #pending == 0 then
        return
    end

    WithMachinePad(plot, Modules.PumpkinCocoaUtil.MACHINE, Modules.PumpkinCocoaUtil.Range, function()
        for _, req in ipairs(pending) do
            if not IsRunning() then
                break
            end
            local ok, res, reason = pcall(function()
                return plot:Invoke(NET.CocoaBuyTime, req.boostId, req.buyMin)
            end)
            if ok and res == true then
                Runtime.Cache.LastCocoaFailAt = 0
                coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
                Runtime.Stats.Coins = coins
                Log("INFO", "Bought %dm Cocoa [%s] (%s Coins/min)", req.buyMin, tostring(req.boostId), tostring(costPerMin))
                task.wait(0.05)
            else
                Runtime.Cache.LastCocoaFailAt = os.clock()
                Log("DEBUG", "Cocoa buy failed [%s x%dm]: %s", tostring(req.boostId), req.buyMin, tostring(reason or res))
                break
            end
        end
    end)
end

local function BuildGiftPositions(amount)
    if Modules.LootboxLocation and Modules.LootboxLocation.ComputePositions and Modules.LootboxTypes then
        local ok, posList = pcall(
            Modules.LootboxLocation.ComputePositions,
            Modules.LootboxTypes.PlacementConfig,
            amount,
            {}
        )
        if ok and type(posList) == "table" and #posList == amount then
            return posList
        end
    end

    local char, hrp = GetCharacter()
    if not hrp then
        return nil
    end
    local center = hrp.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = char and { char } or {}

    local positions = {}
    local radius = 10
    for i = 1, amount do
        local angle = (math.pi * 2 * i) / amount
        local rx = center.X + math.cos(angle) * radius
        local rz = center.Z + math.sin(angle) * radius
        local hit = Workspace:Raycast(Vector3.new(rx, center.Y + 15, rz), Vector3.new(0, -80, 0), rayParams)
        local gy = hit and hit.Position.Y or (center.Y - 3)
        table.insert(positions, Vector3.new(rx, gy, rz))
    end
    return positions
end

local lastGiftAttempt = 0
local function StepOpenFlannelGifts()
    if not Config.AutoOpenGifts or not Modules.Network then
        return
    end
    -- PumpkinTycoonGiftOpener gate removed (client does not set attribute)
    if os.clock() - lastGiftAttempt < 0.25 then
        return
    end

    local giftName = (Modules.ButtonsTypes and Modules.ButtonsTypes.COMPLETION_GIFT) or "Flannel Gift"
    local giftUid, giftAmt = nil, 0

    if Modules.LootboxItem then
        pcall(function()
            local list = Modules.LootboxItem(giftName):FindAny()
            local first = list and list[1]
            if first then
                giftUid = first:GetUID()
                giftAmt = first:GetAmount()
            end
        end)
    end

    if not giftUid and Modules.Save and Modules.Save.Get then
        pcall(function()
            local inv = Modules.Save.Get().Inventory
            local boxes = inv and inv.Lootbox
            if type(boxes) == "table" then
                for uid, d in pairs(boxes) do
                    if type(d) == "table" and (d.id == giftName or d._id == giftName) then
                        giftUid = tostring(uid)
                        giftAmt = tonumber(d._am) or 1
                        break
                    end
                end
            end
        end)
    end

    if not giftUid or giftAmt < 1 then
        return
    end

    local count = math.clamp(math.floor(math.min(giftAmt, Config.GiftBatchAmount or 8)), 1, 8)
    local positions = BuildGiftPositions(count)
    if not positions then
        return
    end

    lastGiftAttempt = os.clock()
    local ok, res = pcall(Modules.Network.Invoke, NET.GiftOpen, giftUid, count, positions)
    if ok and res == true then
        Runtime.Stats.GiftsOpened = Runtime.Stats.GiftsOpened + count
        Log("INFO", "Opened %dx %s (Total: %d)", count, giftName, Runtime.Stats.GiftsOpened)
        pcall(CheckNewHugeWatcher)
    end
end

-- ============================================================================
-- 11. EGG HATCHER (SMART EARLY BOOTSTRAP + POST-COMPLETION ZONE 5 EGG)
-- ============================================================================
local function SuppressEggAnimation()
    if not Config.HatchDisableAnimation then
        return
    end
    pcall(function()
        Workspace:SetAttribute("GlobalInstantHatch", true)
        if Modules.Variables then
            Modules.Variables.OpeningEgg = 0
            Modules.Variables.MessageOpen = false
        end
    end)
end

local function GetEggPrice(eggName)
    if Runtime.Cache.EggCostCache[eggName] then
        return Runtime.Cache.EggCostCache[eggName]
    end
    local dirEggs = Modules.Directory and Modules.Directory.Eggs
    local info = dirEggs and rawget(dirEggs, eggName)
    local cost = info and (info.overrideCost or info.cost)
    if type(cost) == "number" and cost > 0 then
        Runtime.Cache.EggCostCache[eggName] = cost
        return cost
    end
    local fallbacks = {
        ["Cocoa Cabin Egg"] = 200,
        ["Apple Orchard Egg"] = 1000,
        ["Hayride Hill Egg"] = 4000,
        ["Cider Mill Egg"] = 8000,
        ["Golden Grove Egg"] = 16000,
    }
    return fallbacks[eggName] or 16000
end

local function GetEggCommonPower(eggName)
    if Runtime.Cache.EggBasePowerCache[eggName] ~= nil then
        return Runtime.Cache.EggBasePowerCache[eggName]
    end
    local dirEggs = Modules.Directory and Modules.Directory.Eggs
    local info = dirEggs and rawget(dirEggs, eggName)
    local bestPetId, bestWeight = nil, -1
    if info and type(info.pets) == "table" then
        for _, entry in ipairs(info.pets) do
            local pname = type(entry) == "table" and entry[1] or nil
            local weight = type(entry) == "table" and tonumber(entry[2]) or 0
            if type(pname) == "string" and weight and weight > bestWeight then
                bestWeight = weight
                bestPetId = pname
            end
        end
    end
    local power = 0
    if bestPetId then
        if Modules.PetItem then
            local okI, inst = pcall(Modules.PetItem, bestPetId, "preview", { id = bestPetId })
            if okI and inst and inst.CalculatePower then
                local okP, pw = pcall(inst.CalculatePower, inst)
                if okP and type(pw) == "number" and pw > 0 then
                    power = pw
                end
            end
        end
        if power <= 0 and Modules.Directory and Modules.Directory.Pets then
            local pd = rawget(Modules.Directory.Pets, bestPetId)
            if pd then
                power = (type(pd.cachedPower) == "table" and tonumber(pd.cachedPower[1]))
                    or tonumber(pd.power)
                    or 0
            end
        end
    end
    Runtime.Cache.EggBasePowerCache[eggName] = power
    return power
end

local function SafeDirLookup(dirTable, key)
    if type(dirTable) ~= "table" or key == nil then
        return nil
    end
    local ok, val = pcall(function()
        return dirTable[key]
    end)
    if ok then
        return val
    end
    return rawget(dirTable, key)
end

local function ShallowCopyTable(src)
    if type(src) ~= "table" then
        return nil
    end
    if type(table.clone) == "function" then
        return table.clone(src)
    end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = v
    end
    return copy
end

local function ResolvePetItem(uid, data)
    local petItemCls = Modules.PetItem
    if not petItemCls then
        return nil
    end
    if uid ~= nil and type(petItemCls.Get) == "function" then
        local okG, inst = pcall(petItemCls.Get, petItemCls, uid)
        if okG and inst then
            return inst
        end
    end
    if type(data) == "table" and type(petItemCls.From) == "function" then
        local okF, inst = pcall(petItemCls.From, petItemCls, ShallowCopyTable(data))
        if okF and inst then
            return inst
        end
    end
    return nil
end

local function GetTeamPowerSnapshot(forceRefresh)
    local now = os.clock()
    if not forceRefresh and Runtime.Cache.TeamPowerSnapshot and (now - Runtime.Cache.TeamPowerSnapshotAt) < 0.4 then
        return Runtime.Cache.TeamPowerSnapshot
    end
    local maxEquip = 4
    if Modules.PetCmds and Modules.PetCmds.GetMaxEquipped then
        local okM, m = pcall(Modules.PetCmds.GetMaxEquipped)
        if okM and type(m) == "number" and m >= 1 then
            maxEquip = math.floor(m)
        end
    end

    local okSave, saveData = false, nil
    if Modules.Save and Modules.Save.Get then
        okSave, saveData = pcall(Modules.Save.Get)
    end
    local invPets = okSave and type(saveData) == "table" and saveData.Inventory and saveData.Inventory.Pet
    local petsDir = Modules.Directory and Modules.Directory.Pets
    local entries = {}
    local bestNonHugePw = 0

    if type(invPets) == "table" then
        for uid, data in pairs(invPets) do
            if type(data) == "table" and type(data.id) == "string" then
                local pd = SafeDirLookup(petsDir, data.id)
                local scaleWithBest = (pd and (pd.huge == true or pd.titanic == true or pd.gargantuan == true))
                    or string.sub(data.id, 1, 5) == "Huge "
                    or string.sub(data.id, 1, 8) == "Titanic "
                local pw = 0
                local inst = ResolvePetItem(uid, data)
                if inst and inst.CalculatePower then
                    local okP, val = pcall(inst.CalculatePower, inst)
                    if okP and type(val) == "number" then
                        pw = val
                    end
                end
                if pw <= 0 and pd then
                    pw = (type(pd.cachedPower) == "table" and tonumber(pd.cachedPower[1])) or tonumber(pd.power) or 1
                end
                if not scaleWithBest and pw > bestNonHugePw then
                    bestNonHugePw = pw
                end
                local amt = math.min(maxEquip, math.max(1, math.floor(tonumber(data._am) or 1)))
                table.insert(entries, { pw = pw, scaleWithBest = scaleWithBest, amt = amt })
            end
        end
    end

    local slotPowers = {}
    for _, e in ipairs(entries) do
        -- Account for PetPlayer 0.1s cache delay immediately after hatching a new stat pet
        local effPw = e.scaleWithBest and math.max(e.pw, bestNonHugePw) or e.pw
        for _ = 1, e.amt do
            table.insert(slotPowers, effPw)
        end
    end
    table.sort(slotPowers, function(a, b)
        return a > b
    end)

    local best = slotPowers[1] or 0
    local weakest = (#slotPowers >= maxEquip) and slotPowers[maxEquip] or 0
    local snap = {
        maxEquip = maxEquip,
        ownedTotal = #slotPowers,
        best = best,
        weakest = weakest,
    }
    Runtime.Cache.TeamPowerSnapshot = snap
    Runtime.Cache.TeamPowerSnapshotAt = now
    Runtime.Stats.TeamPowerBest = best
    Runtime.Stats.TeamPowerWeakest = weakest
    return snap
end

local function EnsureBestPetsEquipped(force)
    if not Config.AutoEquipBestPets or not Modules.PetCmds then
        return
    end
    local now = os.clock()
    if not force and (now - (Runtime.Cache.LastEquipBestAt or 0)) < 0.6 then
        return
    end
    Runtime.Cache.LastEquipBestAt = now
    if Modules.PetCmds.IsAutoEquipEnabled and Modules.PetCmds.ToggleAutoEquip then
        local okA, enabled = pcall(Modules.PetCmds.IsAutoEquipEnabled)
        if okA and not enabled then
            pcall(Modules.PetCmds.ToggleAutoEquip)
        end
    end
    if Modules.PetCmds.EquipBest then
        pcall(Modules.PetCmds.EquipBest)
    end
end

local function IsEggOnMyIsland(egg, islandBox, pos)
    if not islandBox or not PT or not PT.OnIsland then
        return true
    end
    if pos and PT.OnIsland(islandBox.cf, islandBox.size, pos) then
        return true
    end
    if egg and egg._model and IsOnMyIsland(egg._model, islandBox) then
        return true
    end
    return false
end

local function ResolveTargetEgg(plot, buttons, preferHighestUnlocked)
    if not Modules.CustomEggsCmds or not Modules.CustomEggsCmds.All then
        return nil, nil, nil, nil
    end
    local ok, allEggs = pcall(Modules.CustomEggsCmds.All)
    if not ok or type(allEggs) ~= "table" then
        return nil, nil, nil, nil
    end

    local islandBox = GetIslandBox(plot)
    local candidateNames = {}
    local seenNames = {}
    local function pushName(name)
        if type(name) == "string" and not seenNames[name] then
            seenNames[name] = true
            table.insert(candidateNames, name)
        end
    end

    if not preferHighestUnlocked then
        pushName(Config.TargetEggName)
    end
    if (preferHighestUnlocked or Config.FallbackHighestUnlockedEgg) and PT and PT.ZONES then
        local maxZones = GetZoneCount()
        for i = math.min(#PT.ZONES, maxZones), 1, -1 do
            local z = PT.ZONES[i]
            if z.Egg then
                local eggBtnId = z.Section .. "_Egg"
                if Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, eggBtnId) then
                    pushName(z.Egg)
                end
            end
        end
    end
    if preferHighestUnlocked then
        pushName(Config.TargetEggName)
    end

    for _, wantedName in ipairs(candidateNames) do
        for uid, egg in pairs(allEggs) do
            if type(egg) == "table" and egg._id == wantedName then
                local canHatch = (egg._hatchable == true)
                if not canHatch and egg.IsHatchable then
                    local hOk, hRes = pcall(egg.IsHatchable, egg)
                    canHatch = hOk and hRes == true
                end
                if canHatch then
                    local pos = egg._position
                    if not pos and egg._model then
                        pcall(function()
                            pos = egg._model:GetPivot().Position
                        end)
                    end
                    if pos and IsEggOnMyIsland(egg, islandBox, pos) then
                        local maxPerEgg = tonumber(egg._maxEggCount)
                        if not maxPerEgg and egg.GetMaxEggCount then
                            local mOk, mRes = pcall(egg.GetMaxEggCount, egg)
                            maxPerEgg = mOk and tonumber(mRes) or nil
                        end
                        return tostring(egg._uid or uid), wantedName, pos, maxPerEgg
                    end
                end
            end
        end
    end
    return nil, nil, nil, nil
end

EvaluateEarlyBootstrap = function(plot, buttons)
    if not Config.AutoHatch or not Config.AutoEarlyHatchForDamage or not plot then
        Runtime.Cache.ReserveEarlyEggCost = 0
        return false
    end
    local eggUid, eggName, eggPos, eggMax = ResolveTargetEgg(plot, buttons, true)
    if not eggUid or not eggPos then
        Runtime.Cache.ReserveEarlyEggCost = 0
        return false
    end

    local maxEarly = math.max(1, math.floor(tonumber(Config.EarlyHatchMaxPerEgg) or 8))
    local hatchedHere = Runtime.Cache.EarlyHatchedByEgg[eggName] or 0
    if hatchedHere >= maxEarly then
        Runtime.Cache.ReserveEarlyEggCost = 0
        return false
    end

    local targetCommonPw = GetEggCommonPower(eggName)
    local snap = GetTeamPowerSnapshot(false)
    local needsSlots = snap.ownedTotal < snap.maxEquip
    local needsPower = (targetCommonPw > 0) and (snap.weakest < (targetCommonPw * 0.99))
    if not needsSlots and not needsPower then
        Runtime.Cache.ReserveEarlyEggCost = 0
        return false
    end

    local eggCost = GetEggPrice(eggName)
    Runtime.Cache.ReserveEarlyEggCost = (Config.EarlyHatchReserveCoins ~= false) and eggCost or 0
    local remainingCap = maxEarly - hatchedHere
    return true, eggUid, eggName, eggPos, eggMax, eggCost, remainingCap
end

local function StepHatch(plot, buttons, part1Complete)
    if not Config.AutoHatch or not plot then
        Runtime.Stats.IsHatching = false
        return
    end

    local isEarly = false
    local eggUid, eggName, eggPos, eggMax, eggCost, remainingCap

    if Config.RushButtonsFirst and not part1Complete then
        local needEarly
        needEarly, eggUid, eggName, eggPos, eggMax, eggCost, remainingCap = EvaluateEarlyBootstrap(plot, buttons)
        if not needEarly then
            Runtime.Stats.IsHatching = false
            return
        end
        isEarly = true
    else
        Runtime.Cache.ReserveEarlyEggCost = 0
        eggUid, eggName, eggPos, eggMax = ResolveTargetEgg(plot, buttons, false)
        if not eggUid or not eggPos then
            Runtime.Stats.IsHatching = false
            return
        end
        eggCost = GetEggPrice(eggName)
    end

    local maxHatch = 8
    if Modules.EggCmds and Modules.EggCmds.GetMaxHatch then
        local ok, m = pcall(Modules.EggCmds.GetMaxHatch)
        if ok and type(m) == "number" and m >= 1 then
            maxHatch = m
        end
    end
    if type(eggMax) == "number" and eggMax >= 1 then
        maxHatch = math.min(maxHatch, eggMax)
    end
    if isEarly and type(remainingCap) == "number" then
        maxHatch = math.min(maxHatch, math.max(1, remainingCap))
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local batchMult = isEarly and 1 or (tonumber(Config.HatchMinBatchMultiplier) or 1)
    local minReq = eggCost * batchMult
    if coins < minReq then
        Runtime.Stats.IsHatching = false
        return
    end

    local batch = math.clamp(math.floor(coins / eggCost), 1, maxHatch)
    if batch < 1 then
        Runtime.Stats.IsHatching = false
        return
    end

    if not Config.AutoHatch or IsMoveLocked() or (Runtime.Cache.HatchYieldUntil or 0) > os.clock() then
        Runtime.Stats.IsHatching = false
        return
    end

    Runtime.Stats.IsHatching = true
    Runtime.Stats.Phase = (isEarly and "Early Hatch " or "Hatching ") .. eggName
    SuppressEggAnimation()

    Runtime.Cache.HatchInFlight = true
    local _, hrp = GetCharacter()
    if hrp and HorizontalDist(hrp.Position, eggPos) > (Config.HatchMoveMaxDist or 14) then
        MoveNear(eggPos, Config.HatchMoveMaxDist or 14)
        task.wait(0.25) -- Allow physics position replication before CustomEggs_Hatch range check
        if not IsRunning() or not Config.AutoHatch or IsMoveLocked() or (Runtime.Cache.HatchYieldUntil or 0) > os.clock() then
            Runtime.Cache.HatchInFlight = false
            Runtime.Stats.IsHatching = false
            return
        end
        coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
        batch = math.clamp(math.floor(coins / eggCost), 1, maxHatch)
        if coins < eggCost or batch < 1 then
            Runtime.Cache.HatchInFlight = false
            Runtime.Stats.IsHatching = false
            return
        end
    end

    local ok, res, errMsg = pcall(Modules.Network.Invoke, "CustomEggs_Hatch", eggUid, batch)
    Runtime.Cache.HatchInFlight = false
    if ok and res == true then
        Runtime.Stats.EggsHatched = Runtime.Stats.EggsHatched + batch
        pcall(CheckNewHugeWatcher)
        if isEarly then
            Runtime.Stats.EarlyEggsHatched = Runtime.Stats.EarlyEggsHatched + batch
            Runtime.Cache.EarlyHatchedByEgg[eggName] = (Runtime.Cache.EarlyHatchedByEgg[eggName] or 0) + batch
            Runtime.Cache.TeamPowerSnapshotAt = 0
            GetTeamPowerSnapshot(true)
            Log("INFO", "Early-hatched %dx [%s] (%d/%d for tier) for damage boost",
                batch, eggName, Runtime.Cache.EarlyHatchedByEgg[eggName], Config.EarlyHatchMaxPerEgg or 8)
            EnsureBestPetsEquipped(true)
            task.delay(0.15, function()
                if IsRunning() then
                    GetTeamPowerSnapshot(true)
                    EnsureBestPetsEquipped(true)
                end
            end)
        end
    elseif ok and res == false and errMsg == "Failed to commit!" then
        Runtime.Stats.IsHatching = false
        task.wait(0.35)
    elseif not ok or res == false then
        Runtime.Stats.IsHatching = false
        Log("DEBUG", "Hatch failed [%s x%d]: %s", tostring(eggName), batch, tostring(errMsg or res))
    end
end

-- ============================================================================
-- 11B. PET CRAFTING (GOLD & RAINBOW MACHINE)
-- ============================================================================
local CRAFT_SPECS = {
    {
        kind = "Gold",
        configKey = "AutoMakeGold",
        machineName = "GoldMachine",
        invokeName = "GoldMachine_Activate",
        perkName = "GoldReduction",
        statKey = "GoldCrafted",
        requireNormal = true,
        requireGolden = false,
        canCraftFnName = "CanGoldMachine",
    },
    {
        kind = "Rainbow",
        configKey = "AutoMakeRainbow",
        machineName = "RainbowMachine",
        invokeName = "RainbowMachine_Activate",
        perkName = "RainbowReduction",
        statKey = "RainbowCrafted",
        requireNormal = false,
        requireGolden = true,
        canCraftFnName = "CanRainbowMachine",
    },
}

local function SafeMethodBool(obj, methodName)
    if not obj or type(obj[methodName]) ~= "function" then
        return nil
    end
    local ok, res = pcall(obj[methodName], obj)
    if ok then
        return res == true
    end
    return nil
end

local function HasAncestorNamed(inst, targetName)
    local cur = inst
    while cur do
        if cur.Name == targetName then
            return true
        end
        cur = cur.Parent
    end
    return false
end

local function AddEggPetsToSet(set, eggName)
    local eggsDir = Modules.Directory and Modules.Directory.Eggs
    if type(eggsDir) ~= "table" or type(eggName) ~= "string" or eggName == "" then
        return 0
    end
    local eggDir = SafeDirLookup(eggsDir, eggName)
    if type(eggDir) ~= "table" or type(eggDir.pets) ~= "table" then
        return 0
    end
    local added = 0
    for _, entry in ipairs(eggDir.pets) do
        local petId = type(entry) == "table" and entry[1] or entry
        if type(petId) == "string" and petId ~= "" and not set[petId] then
            set[petId] = true
            added = added + 1
        end
    end
    return added
end

--- Build and lazily cache the PumpkinTycoon event pet ID whitelist from Directory.Eggs, Buttons, and Zones.
local function GetEventCraftPetSet()
    if type(Runtime.Cache.CraftEventPetSet) == "table" and next(Runtime.Cache.CraftEventPetSet) ~= nil then
        return Runtime.Cache.CraftEventPetSet
    end

    local set = {}
    local eggsDir = Modules.Directory and Modules.Directory.Eggs
    if type(eggsDir) == "table" then
        pcall(function()
            for _, eggDir in pairs(eggsDir) do
                if type(eggDir) == "table" and type(eggDir.pets) == "table" then
                    local scriptRef = rawget(eggDir, "_script") or eggDir._script
                    if scriptRef and HasAncestorNamed(scriptRef, INSTANCE_ID) then
                        for _, entry in ipairs(eggDir.pets) do
                            local petId = type(entry) == "table" and entry[1] or entry
                            if type(petId) == "string" and petId ~= "" then
                                set[petId] = true
                            end
                        end
                    end
                end
            end
        end)
    end

    local buttonsList = Modules.ButtonsTypes and Modules.ButtonsTypes.BUTTONS
    if type(buttonsList) == "table" then
        for _, btn in ipairs(buttonsList) do
            if type(btn) == "table" and type(btn.Egg) == "string" then
                AddEggPetsToSet(set, btn.Egg)
            end
        end
    end

    local zones = (Modules.PumpkinTycoon and Modules.PumpkinTycoon.ZONES) or (PT and PT.ZONES)
    if type(zones) == "table" then
        for _, zone in ipairs(zones) do
            if type(zone) == "table" and type(zone.Egg) == "string" then
                AddEggPetsToSet(set, zone.Egg)
            end
        end
    end

    if next(set) ~= nil then
        Runtime.Cache.CraftEventPetSet = set
    end
    return set
end

--- Compute required pets per single craft after Mastery GoldReduction / RainbowReduction perks.
local function GetCraftCost(spec)
    local cost = 10
    local mastery = Modules.MasteryCmds
    if mastery and type(mastery.HasPerk) == "function" and type(mastery.GetPerkPower) == "function" then
        local okHas, hasPerk = pcall(mastery.HasPerk, "Pets", spec.perkName)
        if okHas and hasPerk then
            local okPow, power = pcall(mastery.GetPerkPower, "Pets", spec.perkName)
            if okPow and type(power) == "number" then
                cost = math.max(1, 10 - math.floor(power))
            end
        end
    end
    return cost
end

local function IsCraftMachineUnlocked(spec, plot, buttons)
    if Config.CraftRequireButtonComplete == false then
        return true
    end
    local btnState = buttons or (plot and plot:Save(VAR.Buttons))
    if not btnState or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned then
        return false
    end
    return Modules.PumpkinButtonsUtil.Owned(btnState, spec.machineName) == true
end

local function CollectDaycareUIDs(cmdModule, daycareUids)
    if not cmdModule or type(cmdModule.GetActive) ~= "function" then
        return
    end
    local ok, active = pcall(cmdModule.GetActive)
    if not ok or type(active) ~= "table" then
        return
    end
    for slotKey, entry in pairs(active) do
        if type(slotKey) == "string" and slotKey ~= "" then
            daycareUids[slotKey] = true
        end
        if type(entry) == "table" then
            if type(entry.uid) == "string" and entry.uid ~= "" then
                daycareUids[entry.uid] = true
            end
            if type(entry._uid) == "string" and entry._uid ~= "" then
                daycareUids[entry._uid] = true
            end
            if type(entry.Pet) == "table" then
                local petUid = entry.Pet.uid or entry.Pet._uid or entry.Pet._id or entry.Pet.UID
                if type(petUid) == "string" and petUid ~= "" then
                    daycareUids[petUid] = true
                end
            end
        end
    end
end

local function GetProtectedCraftingSets()
    local daycareUids = {}
    CollectDaycareUIDs(Modules.DaycareCmds, daycareUids)
    CollectDaycareUIDs(Modules.ExclusiveDaycareCmds, daycareUids)

    local equippedCounts = {}
    if Config.CraftProtectEquipped ~= false and Modules.PetCmds and type(Modules.PetCmds.GetEquipped) == "function" then
        local okEq, equipped = pcall(Modules.PetCmds.GetEquipped)
        if okEq and type(equipped) == "table" then
            for _, eq in pairs(equipped) do
                local stackUid = type(eq) == "table" and (eq.uid or eq._uid) or (type(eq) == "string" and eq or nil)
                if type(stackUid) == "string" and stackUid ~= "" then
                    equippedCounts[stackUid] = (equippedCounts[stackUid] or 0) + 1
                end
            end
        end
    end

    local maxEquip = 4
    if Modules.PetCmds and type(Modules.PetCmds.GetMaxEquipped) == "function" then
        local okMax, m = pcall(Modules.PetCmds.GetMaxEquipped)
        if okMax and type(m) == "number" and m >= 1 then
            maxEquip = math.floor(m)
        end
    end

    return {
        daycare = daycareUids,
        equippedCounts = equippedCounts,
        maxEquip = maxEquip,
    }
end

local function FetchPetInventory()
    if not Modules.Save or type(Modules.Save.Get) ~= "function" then
        return nil
    end
    local okSave, saveData = pcall(Modules.Save.Get)
    local invPets = okSave and type(saveData) == "table" and saveData.Inventory and saveData.Inventory.Pet
    return type(invPets) == "table" and invPets or nil
end

local function CollectInventoryCraftState(invPets)
    local totalOwnedPets = 0
    for _, data in pairs(invPets) do
        if type(data) == "table" and type(data.id) == "string" then
            totalOwnedPets = totalOwnedPets + math.max(1, math.floor(tonumber(data._am) or 1))
        end
    end
    return totalOwnedPets, GetProtectedCraftingSets()
end

local function IsPetStackEligibleForCraft(uid, data, spec, protected, eventPetSet, petsDir)
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return false
    end
    if Config.CraftEventPetsOnly ~= false and (not eventPetSet or not eventPetSet[data.id]) then
        return false
    end
    if protected.daycare[uid] then
        return false
    end

    local inst = ResolvePetItem(uid, data)
    local pd = SafeDirLookup(petsDir, data.id)

    -- Unconditionally validate raw save fields alongside PetItem methods so stale/nil wrappers cannot bypass guards.
    if spec.requireNormal then
        if data.pt ~= nil and data.pt ~= 0 then
            return false
        end
        if SafeMethodBool(inst, "IsNormal") == false then
            return false
        end
    elseif spec.requireGolden then
        if data.pt ~= 1 then
            return false
        end
        if SafeMethodBool(inst, "IsGolden") == false then
            return false
        end
    else
        return false
    end

    if Config.CraftProtectLocked ~= false then
        local rawLocked = (data._lk == true) or (data.l == true) or (data.lock == true)
        if rawLocked or SafeMethodBool(inst, "IsLocked") == true then
            return false
        end
    end

    if Config.CraftProtectShiny ~= false then
        if data.sh == true or SafeMethodBool(inst, "IsShiny") == true then
            return false
        end
    end

    if SafeMethodBool(inst, spec.canCraftFnName) == false then
        return false
    end
    if SafeMethodBool(inst, "IsHuge") == true
        or SafeMethodBool(inst, "IsTitanic") == true
        or SafeMethodBool(inst, "IsGargantuan") == true
    then
        return false
    end
    if inst and type(inst.GetExclusiveLevel) == "function" then
        local okEx, exLvl = pcall(inst.GetExclusiveLevel, inst)
        if okEx and type(exLvl) == "number" and exLvl > 0 then
            return false
        end
    end
    if pd and (pd.huge == true or pd.titanic == true or pd.gargantuan == true
        or (type(pd.exclusiveLevel) == "number" and pd.exclusiveLevel > 0))
    then
        return false
    end
    if not inst and not pd and (string.sub(data.id, 1, 5) == "Huge "
        or string.sub(data.id, 1, 8) == "Titanic "
        or string.sub(data.id, 1, 11) == "Gargantuan ")
    then
        return false
    end

    return true, inst, pd
end

local function EstimateCandidateCraftPower(inst, pd, spec)
    if inst and type(inst.CalculatePower) == "function" then
        local okP, val = pcall(inst.CalculatePower, inst)
        if okP and type(val) == "number" and val > 0 then
            return val
        end
    end
    if pd then
        local mult = spec.requireGolden and 3 or 1
        return ((type(pd.cachedPower) == "table" and tonumber(pd.cachedPower[1])) or tonumber(pd.power) or 0) * mult
    end
    return 0
end

--- Build deterministic craft batches for one machine spec (strongest pets first) while honoring team protections.
local function BuildCraftPlans(spec, cost, invPets, protected, eventPetSet, totalOwnedPets)
    local plans = {}
    if type(invPets) ~= "table" or cost < 1 then
        return plans
    end

    local petsDir = Modules.Directory and Modules.Directory.Pets
    local candidates = {}
    for uid, data in pairs(invPets) do
        local eligible, inst, pd = IsPetStackEligibleForCraft(uid, data, spec, protected, eventPetSet, petsDir)
        if eligible then
            local rawAmount = math.max(1, math.floor(tonumber(data._am) or 1))
            local eqCount = protected.equippedCounts[uid] or 0
            local available = rawAmount - eqCount
            if available >= cost then
                table.insert(candidates, {
                    uid = uid,
                    petId = data.id,
                    available = available,
                    power = EstimateCandidateCraftPower(inst, pd, spec),
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.power ~= b.power then
            return a.power > b.power
        end
        if a.available ~= b.available then
            return a.available > b.available
        end
        if a.petId ~= b.petId then
            return a.petId < b.petId
        end
        return tostring(a.uid) < tostring(b.uid)
    end)

    local minBatch = math.max(1, math.floor(tonumber(Config.CraftMinBatch) or 1))
    local reserveTeam = Config.CraftReserveMinTeamSlots ~= false
    local spareSlots = reserveTeam and math.max(0, totalOwnedPets - (protected.maxEquip or 4)) or math.huge

    for _, cand in ipairs(candidates) do
        local crafts = math.floor(cand.available / cost)
        if reserveTeam and cost > 1 then
            local maxBySlots = math.floor(spareSlots / (cost - 1))
            crafts = math.min(crafts, maxBySlots)
        end
        if crafts >= minBatch then
            if reserveTeam and cost > 1 then
                spareSlots = spareSlots - (crafts * (cost - 1))
            end
            table.insert(plans, {
                uid = cand.uid,
                petId = cand.petId,
                crafts = crafts,
                consume = crafts * cost,
            })
        end
    end

    return plans
end

local function ExecuteCraftPlans(plot, spec, plans, cost)
    local totalCrafted = 0
    local totalShiny = 0
    local padVisited = false
    local hadFailure = false
    local consumedByUid = {}

    local padOk = WithMachinePad(plot, spec.machineName, 80, function()
        padVisited = true
        Runtime.Stats.Phase = "Crafting " .. spec.kind
        CloseMachineTab(spec.machineName)

        local maxPerInvoke = math.max(1, math.floor(tonumber(Config.CraftMaxBatchPerInvoke) or 25))
        for _, plan in ipairs(plans) do
            local remaining = plan.crafts
            while IsRunning() and remaining > 0 do
                ExtendMachineSession(4.0)
                local batch = math.min(remaining, maxPerInvoke)
                local callOk, invokeOk, errOrMsg, shinyCount = pcall(Modules.Network.Invoke, spec.invokeName, plan.uid, batch)
                if callOk and invokeOk == true then
                    Runtime.Cache.CraftFailUntil[spec.kind] = 0
                    local shinyMade = type(shinyCount) == "number" and math.max(0, math.floor(shinyCount)) or 0
                    totalCrafted = totalCrafted + batch
                    totalShiny = totalShiny + shinyMade
                    consumedByUid[plan.uid] = (consumedByUid[plan.uid] or 0) + (batch * cost)
                    Runtime.Stats[spec.statKey] = (Runtime.Stats[spec.statKey] or 0) + batch
                    Runtime.Stats.ShinyCrafted = (Runtime.Stats.ShinyCrafted or 0) + shinyMade
                    remaining = remaining - batch
                    Log("INFO", "Crafted %dx %s [%s]%s",
                        batch,
                        spec.kind,
                        tostring(plan.petId),
                        shinyMade > 0 and string.format(" (%dx Shiny)", shinyMade) or ""
                    )
                    if remaining > 0 then
                        task.wait(0.08)
                    end
                else
                    hadFailure = true
                    Runtime.Cache.CraftFailUntil[spec.kind] = os.clock() + (tonumber(Config.CraftFailCooldownSec) or 10)
                    Log("DEBUG", "Craft %s failed [%s x%d]: %s",
                        spec.kind, tostring(plan.petId), batch, tostring(errOrMsg or invokeOk))
                    break
                end
            end
            if hadFailure or not IsRunning() then
                break
            end
        end

        CloseMachineTab(spec.machineName)
    end, { standOnPad = true, closeModal = true })

    if not padVisited or not padOk then
        hadFailure = true
        Runtime.Cache.CraftFailUntil[spec.kind] = os.clock() + (tonumber(Config.CraftFailCooldownSec) or 10)
        Log("DEBUG", "Craft %s machine pad unavailable [%s]", spec.kind, tostring(spec.machineName))
    end

    return totalCrafted, totalShiny, hadFailure, consumedByUid
end

--- Poll Save.Inventory.Pet briefly after Gold crafting until deductions/net pet change replicate cleanly.
local function WaitForCraftReplication(prevTotalOwned, beforeAmounts, consumedByUid, cost, crafted, timeoutSec)
    if crafted <= 0 then
        local curInv = FetchPetInventory()
        if not curInv then
            return nil
        end
        local curTotal, curProtected = CollectInventoryCraftState(curInv)
        return curInv, curTotal, curProtected
    end

    local expectLoss = (cost > 1) and (crafted * (cost - 1)) or 0
    local deadline = os.clock() + (tonumber(timeoutSec) or 0.80)
    local bestPartialInv, bestPartialTotal, bestPartialProtected

    while IsRunning() do
        ExtendMachineSession(4.0)
        local curInv = FetchPetInventory()
        if curInv then
            local allDeducted = true
            for uid, consumed in pairs(consumedByUid) do
                if consumed > 0 then
                    local prevAm = beforeAmounts[uid] or 0
                    local curEntry = curInv[uid]
                    local curAm = (type(curEntry) == "table") and math.max(1, math.floor(tonumber(curEntry._am) or 1)) or 0
                    if curAm > math.max(0, prevAm - consumed) then
                        allDeducted = false
                        break
                    end
                end
            end

            if allDeducted then
                local curTotal, curProtected = CollectInventoryCraftState(curInv)
                if expectLoss <= 0 or curTotal == (prevTotalOwned - expectLoss) then
                    return curInv, curTotal, curProtected
                end
                if curTotal <= (prevTotalOwned - expectLoss) then
                    bestPartialInv = curInv
                    bestPartialTotal = curTotal
                    bestPartialProtected = curProtected
                end
            end
        end

        if os.clock() >= deadline then
            break
        end
        task.wait(0.05)
    end

    if bestPartialInv then
        return bestPartialInv, bestPartialTotal, bestPartialProtected
    end
    return nil
end

local function RefreshCraftedTeamPower()
    Runtime.Cache.TeamPowerSnapshotAt = 0
    GetTeamPowerSnapshot(true)
    EnsureBestPetsEquipped(true)
    task.delay(0.15, function()
        if IsRunning() then
            Runtime.Cache.TeamPowerSnapshotAt = 0
            GetTeamPowerSnapshot(true)
            EnsureBestPetsEquipped(true)
        end
    end)
end

local function IsSpecReadyToCheck(spec, plot, buttons, now)
    if not Config[spec.configKey] then
        return false
    end
    if now < ((Runtime.Cache.CraftFailUntil and Runtime.Cache.CraftFailUntil[spec.kind]) or 0) then
        return false
    end
    return IsCraftMachineUnlocked(spec, plot, buttons)
end

--- Periodically scan inventory for Gold & Rainbow crafts, yielding politely to AutoHatch before chaining trips.
local function StepCraftPets(plot, buttons)
    if not plot or not Modules.Network then
        return
    end
    if not Config.AutoMakeGold and not Config.AutoMakeRainbow then
        return
    end

    local now = os.clock()
    local checkInterval = math.max(0.2, tonumber(Config.CraftCheckIntervalSec) or 1.0)
    if (now - (Runtime.Cache.LastCraftCheckAt or 0)) < checkInterval then
        return
    end
    Runtime.Cache.LastCraftCheckAt = now

    local anyEnabled = false
    for _, spec in ipairs(CRAFT_SPECS) do
        if IsSpecReadyToCheck(spec, plot, buttons, now) then
            anyEnabled = true
            break
        end
    end
    if not anyEnabled then
        Runtime.Cache.PendingCraftReadySince = 0
        return
    end

    local eventPetSet = nil
    if Config.CraftEventPetsOnly ~= false then
        eventPetSet = GetEventCraftPetSet()
        if not eventPetSet or next(eventPetSet) == nil then
            return
        end
    end

    local invPets = FetchPetInventory()
    if not invPets then
        return
    end
    local totalOwnedPets, protected = CollectInventoryCraftState(invPets)

    local hasPendingWork = false
    for _, spec in ipairs(CRAFT_SPECS) do
        if IsSpecReadyToCheck(spec, plot, buttons, now) then
            local plans = BuildCraftPlans(spec, GetCraftCost(spec), invPets, protected, eventPetSet, totalOwnedPets)
            if #plans > 0 then
                hasPendingWork = true
                break
            end
        end
    end
    if not hasPendingWork then
        Runtime.Cache.PendingCraftReadySince = 0
        return
    end

    if (Runtime.Cache.PendingCraftReadySince or 0) == 0 then
        Runtime.Cache.PendingCraftReadySince = now
    end

    local isHatchingNow = (Runtime.Stats.IsHatching == true) or (Runtime.Cache.HatchInFlight == true)
    if isHatchingNow then
        local yieldSec = math.max(0, tonumber(Config.CraftHatchYieldIntervalSec) or 4.0)
        local waitSinceReady = now - (Runtime.Cache.PendingCraftReadySince or now)
        local waitSinceTrip = now - (Runtime.Cache.LastCraftTripAt or 0)
        if waitSinceReady < yieldSec or waitSinceTrip < yieldSec then
            return
        end
    end

    Runtime.Cache.PendingCraftReadySince = 0
    Runtime.Cache.LastCraftTripAt = os.clock()

    local totalCraftedAny = 0
    WithMachineSession(function()
        -- Re-read inventory after BeginMachineSession yields so in-flight hatches/equips settle before planning.
        invPets = FetchPetInventory()
        if not invPets then
            return
        end
        totalOwnedPets, protected = CollectInventoryCraftState(invPets)

        local prevCrafted = 0
        local prevCost = 0
        local prevTotalOwned = totalOwnedPets
        local prevBeforeAmounts = nil
        local prevConsumedByUid = nil

        for idx, spec in ipairs(CRAFT_SPECS) do
            if not IsRunning() then
                break
            end

            local stepNow = os.clock()
            if IsSpecReadyToCheck(spec, plot, buttons, stepNow) then
                if idx > 1 and prevCrafted > 0 then
                    local updatedInv, newTotal, newProtected = WaitForCraftReplication(
                        prevTotalOwned,
                        prevBeforeAmounts,
                        prevConsumedByUid,
                        prevCost,
                        prevCrafted,
                        0.80
                    )
                    if not updatedInv then
                        Log("DEBUG", "Skipping %s pass: waiting for prior %s save replication timed out",
                            spec.kind, CRAFT_SPECS[idx - 1].kind)
                        break
                    end
                    invPets = updatedInv
                    totalOwnedPets = newTotal
                    protected = newProtected
                end

                local cost = GetCraftCost(spec)
                local plans = BuildCraftPlans(spec, cost, invPets, protected, eventPetSet, totalOwnedPets)
                if #plans > 0 then
                    local beforeAmounts = {}
                    for _, plan in ipairs(plans) do
                        local entry = invPets[plan.uid]
                        beforeAmounts[plan.uid] = (type(entry) == "table")
                            and math.max(1, math.floor(tonumber(entry._am) or 1))
                            or 0
                    end

                    local crafted, _, _, consumedByUid = ExecuteCraftPlans(plot, spec, plans, cost)
                    totalCraftedAny = totalCraftedAny + crafted
                    prevCrafted = crafted
                    prevCost = cost
                    prevTotalOwned = totalOwnedPets
                    prevBeforeAmounts = beforeAmounts
                    prevConsumedByUid = consumedByUid
                else
                    prevCrafted = 0
                end
            end
        end
    end)

    if totalCraftedAny > 0 then
        RefreshCraftedTeamPower()
    end
end

-- ============================================================================
-- 12. OPTIONAL EVENT PASS CLAIM LOOP
-- ============================================================================
local lastPassCheck = 0
local function StepEventPass()
    if not Config.AutoEventPass or not Modules.Network or not Modules.EventPassUtil or not Modules.EventPassTypes then
        return
    end
    if os.clock() - lastPassCheck < 15 then
        return
    end
    lastPassCheck = os.clock()

    local passId = Modules.EventPassUtil.Current and Modules.EventPassUtil.Current() or ""
    if passId == "" then
        return
    end
    local ok, state = pcall(Modules.Network.Invoke, Modules.EventPassTypes.NET.Get, passId)
    if not ok or type(state) ~= "table" then
        return
    end
    local passCfg = Modules.EventPassUtil.Get and Modules.EventPassUtil.Get(passId)
    if not passCfg or not Modules.EventPassUtil.WeekSet then
        return
    end
    local weekSet = Modules.EventPassUtil.WeekSet(passCfg, state.Week or 1)
    if not weekSet or type(weekSet.Tiers) ~= "table" then
        return
    end

    if state.Buying == false then
        return
    end
    local stars = tonumber(state.Stars) or 0
    local spent = tonumber(state.Spent) or 0
    local owned = type(state.Owned) == "table" and state.Owned or {}
    local tierUnlock = type(state.TierUnlock) == "table" and state.TierUnlock or {}

    for tierIdx, cards in ipairs(weekSet.Tiers) do
        local reqSpent = tierUnlock[tierIdx]
        if reqSpent ~= nil and spent >= reqSpent then
            for _, card in ipairs(cards) do
                local comingSoon = Modules.EventPassUtil.ComingSoon and Modules.EventPassUtil.ComingSoon(card)
                if not comingSoon and card.Key and not owned[card.Key] and type(card.Cost) == "number" and stars >= card.Cost then
                    local bOk, bRes = pcall(Modules.Network.Invoke, Modules.EventPassTypes.NET.Buy, passId, card.Key)
                    if bOk and bRes == true then
                        stars = stars - card.Cost
                        spent = spent + card.Cost
                        owned[card.Key] = true
                        Log("INFO", "Claimed Event Pass reward [%s]", tostring(card.Key))
                        task.wait(0.08)
                    end
                end
            end
        end
    end
end


-- ============================================================================
-- 12B. DISCORD WEBHOOK & AUTOMAIL ENGINE (KIZHUB INTEGRATION)
-- ============================================================================
local WebhookState = {
    KnownHugeUids = {},
    CacheInitialized = false,
    DefaultUrl = "",
}

local function SendDiscordWebhook(title, description, color, customUrl, options)
    local targetUrl = customUrl or Config.WebhookUrl or WebhookState.DefaultUrl
    if type(targetUrl) ~= "string" or not targetUrl:find("^https://") then
        return false, "Invalid Webhook URL"
    end

    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then
        return false, "Executor HTTP request function not available"
    end

    local opts = options or {}
    local username = opts.username or "KizHub Notifier"
    local avatarUrl = opts.avatar_url or "https://i.imgur.com/8Y1jE6u.png"
    local footerText = opts.footer or "KizHub • Pet Simulator 99"

    local payload = {
        username = username,
        avatar_url = avatarUrl,
        embeds = { {
            title = title,
            description = description,
            color = color or 0xFFA500,
            footer = { text = footerText },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        } }
    }

    task.spawn(function()
        task.wait(math.random(10, 30) / 10)
        local bodyJson = ""
        local okEncode, resEncode = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okEncode then return end
        bodyJson = resEncode

        for attempt = 1, 3 do
            local ok, res = pcall(reqFn, {
                Url = targetUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = bodyJson
            })

            if ok and type(res) == "table" then
                local code = tonumber(res.StatusCode) or 0
                if code == 200 or code == 204 then
                    break
                elseif code == 429 then
                    local waitSec = 5
                    pcall(function()
                        local data = HttpService:JSONDecode(res.Body)
                        if data and data.retry_after then
                            waitSec = tonumber(data.retry_after) or 5
                        end
                    end)
                    task.wait(waitSec + 1)
                else
                    task.wait(2)
                end
            else
                task.wait(2)
            end
        end
    end)
    return true
end

function CheckNewHugeWatcher()
    if not Modules.Save or not Modules.Save.Get then return end
    local s = Modules.Save.Get()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    local targetUrl = Config.WebhookUrl or (type(getgenv) == "function" and (getgenv().WebhookUrl or getgenv().EventsUrl)) or ""

    if not WebhookState.CacheInitialized then
        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local lowerId = p.id:lower()
                local isTitanic = (p.IsTitanic and p:IsTitanic()) or (lowerId:find("titanic") ~= nil)
                local isHuge = (p.IsHuge and p:IsHuge()) or (lowerId:find("huge") ~= nil and not lowerId:find("hunter"))
                if isHuge or isTitanic then
                    WebhookState.KnownHugeUids[uid] = true
                end
            end
        end
        WebhookState.CacheInitialized = true
        return
    end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            local lowerId = p.id:lower()
            local isTitanic = (p.IsTitanic and p:IsTitanic()) or (lowerId:find("titanic") ~= nil)
            local isHuge = (p.IsHuge and p:IsHuge()) or (lowerId:find("huge") ~= nil and not lowerId:find("hunter"))

            if (isHuge or isTitanic) and not WebhookState.KnownHugeUids[uid] then
                WebhookState.KnownHugeUids[uid] = true
                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                local playerName = LocalPlayer and LocalPlayer.Name or "Unknown"

                if isTitanic and Config.NotifyTitanic then
                    Log("WARN", "🎉 NỔ TITANIC PET SIÊU HIẾM: %s (UID: %s)", pName, tostring(uid))
                    SendDiscordWebhook(
                        "👑👑 [NỔ SIÊU PHẨM TITANIC THÀNH CÔNG] 👑👑",
                        string.format("Người chơi: **%s**\n🌟 Siêu Phẩm Titanic: **%s**\nUID: `%s`\nThời gian: <t:%d:R>", playerName, pName, tostring(uid), os.time()),
                        0x9B59B6,
                        targetUrl
                    )
                elseif isHuge and Config.NotifyHuge then
                    Log("WARN", "🎉 NỔ HUGE PET: %s (UID: %s)", pName, tostring(uid))
                    SendDiscordWebhook(
                        "💥 [NỔ HUGE PET THÀNH CÔNG] 💥",
                        string.format("Người chơi: **%s**\nPet nhận được: **%s**\nUID: `%s`\nThời gian: <t:%d:R>", playerName, pName, tostring(uid), os.time()),
                        0xFFD700,
                        targetUrl
                    )
                end
            end
        end
    end
end

-- ==================== AUTOMAIL ENGINE ====================
local MailState = {
    FailedUIDBlacklist = {},
    NextAttemptAt = 0,
    Status = "Rảnh",
}

local function GetDiamonds()
    if Modules.CurrencyCmds and type(Modules.CurrencyCmds.Get) == "function" then
        local ok, d = pcall(Modules.CurrencyCmds.Get, "Diamonds")
        if ok and type(d) == "number" and d > 0 then return d end
    end
    if Modules.Save and Modules.Save.Get then
        local s = Modules.Save.Get()
        local cur = (s and s.Inventory and s.Inventory.Currency) or (s and s.Currencies) or (s and s.Currency)
        if type(cur) == "table" then
            for _, v in pairs(cur) do
                if type(v) == "table" and (v.id == "Diamonds" or v._id == "Diamonds") then
                    return tonumber(v._am or v.Amount) or 0
                end
            end
        end
    end
    return 0
end

local function FindSendableHuge()
    if not Config.AutoMailHuge then return nil end
    if not Modules.Save or not Modules.Save.Get then return nil end
    local s = Modules.Save.Get()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return nil end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            if p.id:find("Titanic ") or p.id:find("Gargantuan ") then
                continue
            end
            if MailState.FailedUIDBlacklist[uid] then continue end
            if p.sb == true or p._sb == true or p.Soulbound == true then
                MailState.FailedUIDBlacklist[uid] = true
                continue
            end

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

local function StepAutoMail()
    if not Config.AutoMailHuge or not Modules.Network then return end
    if not IsInEventInstance() then return end

    local now = os.clock()
    if now < MailState.NextAttemptAt then
        return
    end

    local targetItem = FindSendableHuge()
    if not targetItem then
        MailState.Status = "Hết đồ cần gửi mail"
        return
    end

    local diamonds = GetDiamonds()
    if diamonds < 10000 then
        MailState.NextAttemptAt = os.clock() + (Config.MailRetryInterval or 1800)
        MailState.Status = "Thiếu Gems (Chờ 30p)"
        Log("WARN", "[AutoMail] Thiếu Gems gửi thư (Hiện có: %d, Cần: 10,000) -> Chờ thử lại sau 30 phút", diamonds)
        return
    end

    pcall(function()
        Modules.Network.Fire("Machines: Mark Approached", "Mailbox")
    end)
    task.wait(0.2)

    if targetItem.IsLocked then
        pcall(function()
            Modules.Network.Invoke("Locking_SetLocked", targetItem.UID, false)
            Modules.Network.Fire("Pets_Unlock", targetItem.UID)
        end)
        task.wait(0.3)
    end

    local recipient = Config.MailRecipient or (type(getgenv) == "function" and getgenv().MailRecipient) or "Kizmoii_VNG"
    local diaBefore = GetDiamonds()
    local mailMsg = "Gift #" .. tostring(math.random(100, 999))

    local okSend, resSend = pcall(Modules.Network.Invoke, "Mailbox: Send", recipient, mailMsg, targetItem.Category or "Pet", targetItem.UID, targetItem.Amount or 1)
    local diaAfter = GetDiamonds()
    local actualCost = math.max(0, diaBefore - diaAfter)

    if okSend and resSend == true then
        MailState.Status = string.format("Đã gửi %s", targetItem.Name)
        Log("INFO", "[AutoMail] 📦 Đã gửi thành công %s tới %s (Cước: %d Gems)", targetItem.Name, recipient, actualCost)

        local targetUrl = Config.WebhookUrl or (type(getgenv) == "function" and (getgenv().WebhookUrl or getgenv().EventsUrl)) or ""
        SendDiscordWebhook(
            "📦 [AUTO-MAIL HUGE THÀNH CÔNG] 📦",
            string.format("Người gửi: **%s**\nNgười nhận: **%s**\nVật phẩm: **%s**\nSố lượng: **%d**\nPhí cước: **%d Gems**",
                LocalPlayer and LocalPlayer.Name or "Unknown",
                recipient,
                targetItem.Name,
                targetItem.Amount or 1,
                actualCost
            ),
            0x00E676,
            targetUrl
        )
        task.wait(Config.MailCooldownSec or 10)
    else
        local errStr = string.lower(tostring(resSend))
        if errStr:find("soulbound") or errStr:find("untradable") or errStr:find("cannot be traded") or errStr:find("not tradable") then
            MailState.FailedUIDBlacklist[targetItem.UID] = true
            MailState.Status = "Không thể trade (Bỏ qua)"
            Log("WARN", "[AutoMail] Pet %s bị soulbound/untradable -> Bỏ qua", targetItem.Name)
            task.wait(2)
        else
            MailState.NextAttemptAt = os.clock() + (Config.MailRetryInterval or 1800)
            MailState.Status = "Lỗi gửi (Chờ 30p)"
            Log("WARN", "[AutoMail] Lỗi gửi thư: %s -> Chờ thử lại sau 30 phút", tostring(resSend))
        end
    end
end


-- ============================================================================
-- 12C. FREE GIFTS, AUTO BUFFS (FRUITS/POTIONS/TOYS) & MINI GUI (KIZHUB SUITE)
-- ============================================================================

-- 1. Tự động nhận 12 mốc quà Free Gifts định kỳ (tích lũy Gems trả cước AutoMail)
local lastFreeGiftCheck = 0
local function StepFreeGifts()
    if not Config.AutoClaimFreeGifts or not Modules.Network then return end
    local now = os.clock()
    if now - lastFreeGiftCheck < 90 then return end
    lastFreeGiftCheck = now

    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local FreeGiftsCmds = Modules.FreeGiftsCmds
        if not FreeGiftsCmds then
            pcall(function()
                FreeGiftsCmds = require(RS.Library.Client.FreeGiftsCmds)
                Modules.FreeGiftsCmds = FreeGiftsCmds
            end)
        end

        for i = 1, 12 do
            local claimed = false
            if FreeGiftsCmds and type(FreeGiftsCmds.Claim) == "function" then
                local ok, res = pcall(FreeGiftsCmds.Claim, i)
                if ok and res == true then claimed = true end
            end
            if not claimed then
                local okInv, resInv = pcall(Modules.Network.Invoke, "Redeem Free Gift", i)
                if okInv and resInv == true then claimed = true end
            end
            if not claimed then
                local r = RS:FindFirstChild("Network") and RS.Network:FindFirstChild("Redeem Free Gift")
                if r then
                    if r:IsA("RemoteFunction") then pcall(function() r:InvokeServer(i) end)
                    elseif r:IsA("RemoteEvent") then pcall(function() r:FireServer(i) end) end
                end
            end
            task.wait(0.08)
        end
    end)
end

-- 2. Tự động cắn Trái cây, Potions và kích hoạt Đồ chơi (TUYỆT ĐỐI KHÔNG CẮM CỜ)
local lastFruitCheck = 0
local lastPotionCheck = 0
local lastToyCheck = 0

local function StepAutoBuffs()
    if not Config.AutoBuffs or not Config.AutoBuffs.Enabled or not Modules.Network then return end
    local now = os.clock()

    -- A. Fruits: Ăn tối đa 20 quả/lần mỗi 120s
    if Config.AutoBuffs.Fruits and now - lastFruitCheck >= 120 then
        lastFruitCheck = now
        pcall(function()
            if not Modules.Save or not Modules.Save.Get then return end
            local s = Modules.Save.Get()
            local fruits = s and s.Inventory and s.Inventory.Fruit
            if type(fruits) == "table" then
                for _, item in pairs(fruits) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local amt = tonumber(item._am) or 0
                        if amt > 0 then
                            local eatAmt = math.clamp(amt, 1, 20)
                            pcall(Modules.Network.Fire, "Fruits: Consume", item.id, eatAmt)
                            task.wait(0.06)
                        end
                    end
                end
            end
        end)
    end

    -- B. Potions: Tự cắn Potions tăng Damage, Coins, Luck mỗi 180s
    if Config.AutoBuffs.Potions and now - lastPotionCheck >= 180 then
        lastPotionCheck = now
        pcall(function()
            if not Modules.Save or not Modules.Save.Get then return end
            local s = Modules.Save.Get()
            local potions = s and s.Inventory and s.Inventory.Potion
            if type(potions) == "table" then
                local targetTypes = { "damage", "coins", "luck", "lucky", "speed", "treasure", "pumpkin", "patch", "tycoon" }
                for _, item in pairs(potions) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local lowerId = string.lower(item.id)
                        local matched = false
                        for _, kw in ipairs(targetTypes) do
                            if lowerId:find(kw) then
                                matched = true
                                break
                            end
                        end
                        if matched and (tonumber(item._am) or 0) > 0 then
                            pcall(Modules.Network.Fire, "Potions: Consume", item.id)
                            task.wait(0.06)
                        end
                    end
                end
            end
        end)
    end

    -- C. Toys: Dùng Toys từ Inventory.Misc mỗi 300s
    if Config.AutoBuffs.Toys and now - lastToyCheck >= 300 then
        lastToyCheck = now
        pcall(function()
            if not Modules.Save or not Modules.Save.Get then return end
            local s = Modules.Save.Get()
            local misc = s and s.Inventory and s.Inventory.Misc
            if type(misc) == "table" then
                for uid, item in pairs(misc) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local toyUid = item._uid or uid
                        if item.id == "Toy Ball" then
                            pcall(Modules.Network.Invoke, "ToyBall_Consume", toyUid)
                            task.wait(0.12)
                        elseif item.id == "Toy Bone" then
                            pcall(Modules.Network.Invoke, "ToyBone_Consume", toyUid)
                            task.wait(0.12)
                        elseif item.id == "Squeaky Toy" then
                            pcall(Modules.Network.Invoke, "SqueakyToy_Consume", toyUid)
                            task.wait(0.12)
                        elseif item.id:lower():find("toy") then
                            pcall(Modules.Network.Invoke, "Consumables_Consume", toyUid)
                            task.wait(0.12)
                        end
                    end
                end
            end
        end)
    end
end

-- 3. BẢNG GUI MINI THEO DÕI TRỰC QUAN (SIÊU NHẸ CHO 80 ACC)
local MiniGuiState = {
    ScreenGui = nil,
    CoinsLabel = nil,
    ButtonLabel = nil,
    HatchLabel = nil,
    PhaseLabel = nil,
    MailLabel = nil,
}

local function SetupMiniGui()
    if Config.ShowGui == false then return end
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local parentTarget = (type(gethui) == "function" and gethui()) or CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not parentTarget then return end

        local existing = parentTarget:FindFirstChild("KizHub_MiniTycoonGui")
        if existing then existing:Destroy() end

        local sg = Instance.new("ScreenGui")
        sg.Name = "KizHub_MiniTycoonGui"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 9999

        local f = Instance.new("Frame")
        f.Name = "MiniContainer"
        f.Size = UDim2.new(0, 275, 0, 132)
        f.Position = UDim2.new(0, 15, 0, 50)
        f.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
        f.BackgroundTransparency = 0.2
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = true
        f.Parent = sg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = f

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(56, 189, 248)
        stroke.Thickness = 1.2
        stroke.Parent = f

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -16, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 4)
        title.BackgroundTransparency = 1
        title.Text = "👑 Kiz Hub • Tycoon Kaitun"
        title.TextColor3 = Color3.fromRGB(248, 250, 252)
        title.TextSize = 11
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = f

        local function makeLabel(yPos, color)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -16, 0, 16)
            l.Position = UDim2.new(0, 10, 0, yPos)
            l.BackgroundTransparency = 1
            l.TextColor3 = color
            l.TextSize = 10
            l.Font = Enum.Font.GothamMedium
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = f
            return l
        end

        MiniGuiState.CoinsLabel = makeLabel(24, Color3.fromRGB(251, 191, 36))
        MiniGuiState.ButtonLabel = makeLabel(42, Color3.fromRGB(244, 114, 182))
        MiniGuiState.HatchLabel = makeLabel(60, Color3.fromRGB(168, 85, 247))
        MiniGuiState.PhaseLabel = makeLabel(78, Color3.fromRGB(56, 189, 248))
        MiniGuiState.MailLabel = makeLabel(96, Color3.fromRGB(52, 211, 153))

        sg.Parent = parentTarget
        MiniGuiState.ScreenGui = sg
    end)
end

local lastGuiUpdate = 0
local function UpdateMiniGui()
    if not MiniGuiState.ScreenGui or not MiniGuiState.ScreenGui.Parent then return end
    local now = os.clock()
    if now - lastGuiUpdate < 1.0 then return end
    lastGuiUpdate = now

    pcall(function()
        local coins = Runtime.Stats.Coins or 0
        local tokens = GetCurrency((PT and PT.TOKEN) or "PumpkinTokens") or 0
        local hatched = Runtime.Stats.EggsHatched or 0
        local gifts = Runtime.Stats.GiftsOpened or 0
        local phase = Runtime.Stats.Phase or "Đang chạy..."
        local mailStat = (MailState and MailState.Status) or "Rảnh"
        local nextBtn = Runtime.Stats.NextButtonName or "..."
        local missing = Runtime.Stats.MissingCoins or 0
        local cost = Runtime.Stats.NextButtonCost or 0

        if MiniGuiState.CoinsLabel then
            MiniGuiState.CoinsLabel.Text = string.format("💰 Coins: %s • 🎟️ Tokens: %s", ShortenNumber(coins), ShortenNumber(tokens))
        end
        if MiniGuiState.ButtonLabel then
            if nextBtn == "Đã xong tất cả" then
                MiniGuiState.ButtonLabel.Text = "🔘 Nút: Hoàn thành 100% tất cả!"
            elseif missing > 0 then
                MiniGuiState.ButtonLabel.Text = string.format("🔘 Nút: %s (Thiếu %s)", tostring(nextBtn), ShortenNumber(missing))
            elseif cost > 0 then
                MiniGuiState.ButtonLabel.Text = string.format("🔘 Nút: %s (Đủ tiền mua!)", tostring(nextBtn))
            else
                MiniGuiState.ButtonLabel.Text = string.format("🔘 Nút: %s", tostring(nextBtn))
            end
        end
        if MiniGuiState.HatchLabel then
            MiniGuiState.HatchLabel.Text = string.format("🥚 Hatched: %s • 🎁 Gifts: %s", ShortenNumber(hatched), ShortenNumber(gifts))
        end
        if MiniGuiState.PhaseLabel then
            MiniGuiState.PhaseLabel.Text = string.format("📌 %s", tostring(phase))
        end
        if MiniGuiState.MailLabel then
            MiniGuiState.MailLabel.Text = string.format("📦 Mail: %s", tostring(mailStat))
        end
    end)
end

-- ============================================================================
-- 13. MAIN CONCURRENT LOOPS
-- ============================================================================
local function StartLoops()
    -- Loop A: Fast Progress (Join, Tutorial, Buttons Burst, Upgrades, Keep/Lock/Stock/Merchant, Boosts/Cocoa, Gifts)
    task.spawn(function()
        Log("INFO", "Progression and manager loop started.")
        while IsRunning() do
            local ok, err = pcall(function()
                local plot = EnsureInPumpkinTycoon()
                if not plot then
                    task.wait(0.5)
                    return
                end

                StepTutorial(plot)
                local buttons, part1Complete, claimedComplete = StepButtonsAndComplete(plot)

                Runtime.Stats.Phase = part1Complete
                    and (claimedComplete and "Post-Complete Farming & Hatch" or "Claiming Completion")
                    or string.format("Rushing Buttons (%d/%d)", Runtime.Stats.ButtonsDone, Runtime.Stats.ButtonsTotal)

                StepKeepLockAndStock(plot, buttons, part1Complete)
                StepUpgrades(plot, buttons)
                StepConsumableBoosts()
                StepHotCocoaStand(plot, buttons, part1Complete)
                StepPetSpeedBuff()
                StepMapOptimizer(plot)
                StepOpenFlannelGifts()
                StepCraftPets(plot, buttons)
                StepEventPass()
                StepFreeGifts()
                StepAutoBuffs()
                UpdateMiniGui()
            end)
            if not ok then
                Log("DEBUG", "Manager loop error: %s", tostring(err))
            end
            task.wait(0.20)
        end
    end)

    -- Loop B: Target Selector & Pet Assignment (fast 30ms retarget on break, full rescan on FarmLoopInterval)
    task.spawn(function()
        Log("INFO", "Farm targeting and pet focus loop started.")
        local lastTargetScan = 0
        while IsRunning() do
            local now = os.clock()
            local targetDead = (activeFarmTarget == nil)
                or (not activeFarmTarget.model)
                or (not activeFarmTarget.model.Parent)
            local waitingSpawn = (Runtime.Stats.ActiveTargetDesc == "Waiting spawn")
            local dueForScan = (now - lastTargetScan) >= (Config.FarmLoopInterval or 0.10)
            if (targetDead and not waitingSpawn) or dueForScan then
                lastTargetScan = now
                pcall(function()
                    if IsInEventInstance() then
                        local plot = GetMyPlot()
                        if plot then
                            StepFarmTargeter(plot)
                        end
                    end
                end)
            end
            task.wait(0.03)
        end
    end)

    -- Loop C: Ultra-Fast Tap Engine
    task.spawn(function()
        Log("INFO", "Rapid tap loop started.")
        while IsRunning() do
            pcall(StepRapidTap)
            task.wait(Config.TapInterval or 0.04)
        end
    end)

    -- Loop D: Orbs & Lootbags Sweeper
    task.spawn(function()
        Log("INFO", "Orb and lootbag sweep loop started.")
        while IsRunning() do
            pcall(SweepDrops)
            task.wait(Config.OrbSweepInterval or 0.12)
        end
    end)

    -- Loop E: Post-Complete Zone 5 Egg Hatcher
    task.spawn(function()
        Log("INFO", "Egg hatcher loop started.")
        while IsRunning() do
            local plot = IsInEventInstance() and GetMyPlot() or nil
            if plot then
                local buttons = Runtime.Cache.Buttons
                local part1Complete = Runtime.Stats.Part1Complete
                if buttons == nil or (os.clock() - (Runtime.Cache.ButtonsAt or 0) > 0.5) then
                    buttons, part1Complete = GetProgressState(plot)
                end
                pcall(StepHatch, plot, buttons, part1Complete)
                Runtime.Cache.HatchInFlight = false
            else
                Runtime.Stats.IsHatching = false
                Runtime.Cache.HatchInFlight = false
            end
            task.wait(Runtime.Stats.IsHatching and (Config.HatchCooldown or 0.05) or 0.25)
        end
    end)

    -- Loop F: AutoMail Huge Pets (KizHub)
    task.spawn(function()
        Log("INFO", "AutoMail loop started.")
        task.wait(15)
        while IsRunning() do
            pcall(StepAutoMail)
            task.wait(30)
        end
    end)
end

-- ============================================================================
-- 14. ENTRYPOINT
-- ============================================================================
if WaitReady() and IsRunning() then
    SetupAntiAfk()
    DisableNativeAutoFarmOnce()
    StepPetSpeedBuff()
    SetupMapOptimizer()
    pcall(CheckNewHugeWatcher)
    SetupMiniGui()
    Log("INFO", "Pumpkin Patch Tycoon Kaitun initialized (RushButtons=%s, KeepRung=%d, TargetEgg=%s, PetSpeed=%sx, OptimizeMap=%s).",
        tostring(Config.RushButtonsFirst),
        tonumber(Config.KeepRung) or 0,
        tostring(Config.TargetEggName),
        tostring(Config.AutoBuffPetSpeed and Config.PetSpeedMultiplier or 1),
        tostring(Config.OptimizeMap)
    )
    StartLoops()
end