assert(game.GameId == 3317771874, "This script is for Pet Simulator 99")

local ResumeAfterTeleport = getgenv().PS99RankResume == true
getgenv().PS99RankResume = nil

local Config = {
    -- AutoRank & Kaitun A-Z
    AutoRankEnabled = true,
    TargetRank = 11,
    StayInWorld1 = true,
    AutoWorldTeleport = false, -- Không qua World 2, cày đủ Rank 11 tại World 1
    AutoClaimRewards = true,
    AutoFarm = true,
    AutoHatch = true,
    AutoTapEggs = true,
    AlwaysHatch = false,
    AutoCraftGoldRainbow = true,
    AutoUsePotions = true,
    AutoUpgradePotions = true,
    AutoUpgradeEnchants = true,
    AutoUseFruits = true,
    AutoUseFlags = true,
    AutoSpawnEvents = true,
    AutoBuyZones = true,
    AutoEquipBestPets = true,
    AutoPickStarterPets = true,
    AutoOpenSlots = true,
    AutoClaimFreeGifts = true,

    -- Discord Webhook Notifications
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
        NotifyEveryRank = true,
        TargetRank = 11,
    },

    -- KizHub Blackout GUI & Performance
    BlackoutGui = false,
    Disable3DRendering = true,
    GuiToggleKey = Enum.KeyCode.RightControl,

    FarmTick = 0.25,
    HatchDelay = 0.75,
    HatchMaxDistance = 85,
    ControllerTick = 1.0,
    CraftTick = 4.0,
    EventTick = 3.0,
    ZonePositionTolerance = 25,
    MaxInventoryPotionTier = 10,
    PotionUsePriority = { "Lucky", "Coins", "Diamonds", "Treasure Hunter", "Damage" },
    PotionUpgradePriority = { "Coins", "Diamonds", "Lucky", "Treasure Hunter", "Damage" },
    EnchantUpgradePriority = {
        "Coins",
        "Diamonds",
        "Tap Power",
        "Criticals",
        "Lucky Eggs",
        "Strong Pets",
        "Treasure Hunter",
    },
    FruitUsePriority = { "Apple", "Orange", "Pineapple", "Banana", "Watermelon", "Rainbow" },
    AllowShinyFruit = false,
    FlagPriority = {
        "Coins Flag",
        "Diamonds Flag",
        "Hasty Flag",
        "Strength Flag",
        "Magnet Flag",
        "Fortune Flag",
        "Shiny Flag",
    },
    CoinJarPriority = { "Basic Coin Jar", "Giant Coin Jar", "Magic Coin Jar" },
    ProtectedPetIds = {},
    UseShinyPetsAsFodder = false,
    WorkspaceFile = "PS99-AutoRank.luau",
    ShowGui = true,
    ReduceMotion = false,
    ShowOverviewStats = true,
}

local SavedOptions = {
    { "ReduceMotion", "Reduce motion", "Appearance" },
    { "ShowOverviewStats", "Show activity totals", "Appearance" },
    { "AutoFarm", "Farm breakables", "Progression" },
    { "AutoEquipBestPets", "Equip best pets", "Progression" },
    { "AutoPickStarterPets", "Pick starter pets", "Progression" },
    { "AutoOpenSlots", "Buy pet & egg slots", "Progression" },
    { "AutoClaimFreeGifts", "Claim free gifts", "Progression" },
    { "AutoClaimRewards", "Auto claim rank rewards", "Progression" },
    { "AutoBuyZones", "Buy zones", "Progression" },
    { "AutoWorldTeleport", "Switch worlds", "Progression" },
    { "AutoSpawnEvents", "Use event items", "Items" },
    { "AutoUsePotions", "Use potions", "Items" },
    { "AutoUpgradePotions", "Upgrade potions", "Items" },
    { "AutoUpgradeEnchants", "Upgrade enchants", "Items" },
    { "AutoUseFruits", "Use fruit", "Items" },
    { "AutoUseFlags", "Use flags", "Items" },
    { "AutoHatch", "Hatch eggs", "Hatching" },
    { "AutoTapEggs", "Tap eggs to open", "Hatching" },
    { "AlwaysHatch", "Hatch without a quest", "Hatching" },
    { "AutoCraftGoldRainbow", "Craft gold and rainbow", "Crafting" },
}

local VERSION = "1.0.0"
local TAG = "[99 Ranker] "
local STATE_FILE = "Riftware_AutoRank_State.json"
local STATE_FILE_MAX_AGE = 900
local MAX_CRAFT_PER_CALL = 50
local MAX_UPGRADE_PER_CALL = 25
local MAX_CLAIM_ATTEMPTS = 6
local CLAIM_SLOW_RETRY = 60
local GUI_WIDTH = 300

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local WORLD_PLACE_IDS = {
    [8737899170] = 1,
    [16498369169] = 2,
    [17503543197] = 3,
    [140403681187145] = 4,
}

local GOAL_TYPE_NAMES = {
    [1] = "BREAKABLE",
    [2] = "PET",
    [3] = "EGG",
    [4] = "GOLD_PET",
    [5] = "RAINBOW_PET",
    [6] = "ZONE",
    [7] = "CURRENCY",
    [8] = "MINI_CHEST",
    [9] = "DIAMOND_BREAKABLE",
    [10] = "BUY_POTION",
    [11] = "BUY_ENCHANT",
    [12] = "UPGRADE_POTION",
    [13] = "UPGRADE_ENCHANT",
    [14] = "COLLECT_POTION",
    [15] = "COLLECT_ENCHANT",
    [18] = "FREE_GIFT",
    [19] = "FUSE_PETS",
    [20] = "BEST_EGG",
    [21] = "CURRENT_BREAKABLE",
    [22] = "SPAWN_OBBY",
    [23] = "MINEFIELD",
    [24] = "ATLANTIS",
    [25] = "DIGSITE",
    [26] = "FISHING",
    [27] = "ICE_OBBY",
    [28] = "PYRAMID_OBBY",
    [29] = "JUNGLE_OBBY",
    [30] = "CHEST_RUSH",
    [31] = "COIN_JAR",
    [32] = "COMET",
    [33] = "USE_FLAG",
    [34] = "USE_POTION",
    [35] = "USE_FRUIT",
    [36] = "SLED_RACE",
    [37] = "BEST_COIN_JAR",
    [38] = "BEST_COMET",
    [39] = "BEST_MINI_CHEST",
    [40] = "BEST_GOLD_PET",
    [41] = "BEST_RAINBOW_PET",
    [42] = "HATCH_RARE_PET",
    [43] = "BEST_PINATA",
    [44] = "BEST_LUCKYBLOCK",
    [45] = "ADVANCED_DIGSITE",
    [46] = "ADVANCED_FISHING",
    [47] = "INDEX_PET",
    [66] = "PINATA",
    [67] = "LUCKYBLOCK",
    [68] = "RANDOM_COIN_JAR",
    [69] = "RANDOM_COMET",
    [70] = "RANDOM_PINATA",
    [71] = "RANDOM_LUCKYBLOCK",
    [72] = "RANDOM_MINI_CHEST",
    [75] = "SUPERIOR_MINI_CHEST",
    [76] = "BEST_SUPERIOR_MINI_CHEST",
    [77] = "RANDOM_SUPERIOR_MINI_CHEST",
    [80] = "EQUIP_PET",
    [81] = "SPECIFIC_ZONE",
}

local function MakeSet(list)
    local s = {}
    for _, v in ipairs(list) do
        s[v] = true
    end
    return s
end

local FARM_GOALS = MakeSet({ 1, 21, 9, 7, 14, 15, 8, 39, 75, 76 })
local CHEST_GOALS = MakeSet({ 8, 39, 75, 76 })
local HATCH_GOALS = MakeSet({ 20, 42, 3, 2 })
local EGG_COUNT_GOALS = MakeSet({ 20, 3 })
local GOLD_GOALS = MakeSet({ 40, 4 })
local RAINBOW_GOALS = MakeSet({ 41, 5 })
local BEST_EGG_ONLY_CRAFT = MakeSet({ 40, 41 })

local T_ZONE, T_DIAMOND, T_UPGRADE_POTION, T_UPGRADE_ENCHANT = 6, 9, 12, 13
local T_USE_FLAG, T_USE_POTION, T_USE_FRUIT = 33, 34, 35

local EVENT_GOAL_KIND = {
    [38] = "Comet",
    [32] = "Comet",
    [43] = "Pinata",
    [66] = "Pinata",
    [44] = "LuckyBlock",
    [67] = "LuckyBlock",
    [37] = "CoinJar",
    [31] = "CoinJar",
}
local EVENT_DEFS = {
    Comet = { items = { "Comet" }, remote = "Comet_Spawn", label = "comet", match = { "comet" } },
    Pinata = { items = { "Mini Pinata" }, remote = "MiniPinata_Consume", label = "pinata", match = { "pinata" } },
    LuckyBlock = {
        items = { "Mini Lucky Block" },
        remote = "MiniLuckyBlock_Consume",
        label = "lucky block",
        match = { "luckyblock" },
    },
    CoinJar = { items = Config.CoinJarPriority, remote = "CoinJar_Spawn", label = "coin jar", match = { "coinjar" } },
}
local EVENT_BREAKABLE_WORDS = { "comet", "pinata", "jar", "lucky", "chest" }

local POTION_TIER_REQ_FALLBACK = { 3, 3, 4, 5, 5, 5, 5, 5, 7, 7, 7 }
local ENCHANT_TIER_REQ_FALLBACK = { 3, 3, 3, 5, 5, 5, 5, 5, 8, 8 }

local function Int(x)
    x = tonumber(x) or 0
    return tostring(math.floor(x + 0.5))
end

local function Fmt(f, ...)
    if select("#", ...) == 0 then
        return tostring(f)
    end
    local ok, s = pcall(string.format, tostring(f), ...)
    if ok then
        return s
    end
    local parts = { tostring(f) }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

local function Log(f, ...)
    print(TAG .. Fmt(f, ...))
end

local WarnAt = {}
local function WarnLog(key, f, ...)
    local now = os.clock()
    local last = WarnAt[tostring(key)]
    if last and now - last < 30 then
        return
    end
    WarnAt[tostring(key)] = now
    warn(TAG .. Fmt(f, ...))
end

local LogAt = {}
local function LogEvery(key, seconds, f, ...)
    local now = os.clock()
    local last = LogAt[tostring(key)]
    if last and now - last < seconds then
        return
    end
    LogAt[tostring(key)] = now
    Log(f, ...)
end

local OnceDone = {}
local function LogOnce(key, f, ...)
    key = tostring(key)
    if OnceDone[key] then
        return
    end
    OnceDone[key] = true
    Log(f, ...)
end

local function WarnOnce(key, f, ...)
    key = tostring(key)
    if OnceDone[key] then
        return
    end
    OnceDone[key] = true
    warn(TAG .. Fmt(f, ...))
end

local function ResetOnce(prefix)
    for k in pairs(OnceDone) do
        if string.sub(k, 1, #prefix) == prefix then
            OnceDone[k] = nil
        end
    end
end

local Genv = (type(getgenv) == "function" and getgenv()) or _G
if type(Genv.RiftwareAutoRank) == "table" and type(Genv.RiftwareAutoRank.Stop) == "function" then
    pcall(Genv.RiftwareAutoRank.Stop)
    task.wait(0.25)
end

local IDENTITY_GAME = 2
local CanSetIdentity = type(setthreadidentity) == "function"

local function GameCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "gcall: not a function"
    end
    local identity = CanSetIdentity and getthreadidentity()
    if identity then
        pcall(setthreadidentity, IDENTITY_GAME)
    end
    local r = table.pack(pcall(fn, ...))
    if identity then
        pcall(setthreadidentity, identity)
    end
    return table.unpack(r, 1, r.n)
end

local function GameValue(fn, ...)
    local ok, a, b, c, d = GameCall(fn, ...)
    if ok then
        return a, b, c, d
    end
    return nil
end

local function HasFunction(mod, name)
    return type(mod) == "table" and type(mod[name]) == "function"
end

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
    Persist = { LastWorldSwitch = 0 },
    WorldSwitching = false,
    WorldSwitchAt = 0,
    WorldMismatch = false,
    World = nil,
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

local Connections = {}
local function Track(conn)
    if conn then
        Connections[#Connections + 1] = conn
    end
    return conn
end

local Threads = {}
local AssignedPets = setmetatable({}, { __mode = "k" })
local function Defer(Callback)
    local Thread
    Thread = task.defer(function()
        Callback()
        Threads[Thread] = nil
    end)
    Threads[Thread] = true
end
local PersistHook = nil
local Gui = nil
local Stopped = false
local Handle

local function Stop()
    if Stopped then
        return
    end
    Stopped = true
    State.Alive = false
    State.Enabled = false
    State.Persist.ResumeCancelled = true
    State.Action = "stopped"
    local Current = coroutine.running()
    for Thread in pairs(Threads) do
        if Thread ~= Current and coroutine.status(Thread) ~= "dead" then
            pcall(task.cancel, Thread)
        end
    end
    table.clear(Threads)
    for _, c in ipairs(Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    Connections = {}
    for Pet, Assignment in pairs(AssignedPets) do
        if Pet.target == Assignment.Target and Pet.owner == LocalPlayer then
            local Original = Assignment.Original
            if typeof(Original) == "Instance" and not Original.Parent then
                Original = LocalPlayer.Character
            end
            GameCall(Pet.SetTarget, Pet, Original)
        end
    end
    table.clear(AssignedPets)
    if Gui then
        pcall(function()
            Gui:Destroy()
        end)
        Gui = nil
    end
    if KizHubGui then
        pcall(function()
            KizHubGui:Destroy()
        end)
        KizHubGui = nil
    end
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    if PersistHook then
        pcall(PersistHook)
    end
    if Genv.RiftwareAutoRank == Handle then
        Genv.RiftwareAutoRank = nil
    end
    print(TAG .. "stopped")
end

Handle = { Stop = Stop, Config = Config, State = State, Version = VERSION }
Genv.RiftwareAutoRank = Handle

local G = {}

local MODULE_PATHS = {
    Save = { "Library", "Client", "Save" },
    Network = { "Library", "Client", "Network" },
    Directory = { "Library", "Directory" },
    RanksUtil = { "Library", "Util", "RanksUtil" },
    RankCmds = { "Library", "Client", "RankCmds" },
    ZoneCmds = { "Library", "Client", "ZoneCmds" },
    ZonesUtil = { "Library", "Util", "ZonesUtil" },
    EggsUtil = { "Library", "Util", "EggsUtil" },
    EggCmds = { "Library", "Client", "EggCmds" },
    Balancing = { "Library", "Balancing" },
    CalcEggPricePlayer = { "Library", "Balancing", "CalcEggPricePlayer" },
    MapCmds = { "Library", "Client", "MapCmds" },
    QuestCmds = { "Library", "Client", "QuestCmds" },
    PotionCmds = { "Library", "Client", "PotionCmds" },
    FruitCmds = { "Library", "Client", "FruitCmds" },
    FlexibleFlagCmds = { "Library", "Client", "FlexibleFlagCmds" },
    RandomEventCmds = { "Library", "Client", "RandomEventCmds" },
    InstancingCmds = { "Library", "Client", "InstancingCmds" },
    PlayerPet = { "Library", "Client", "PlayerPet" },
    PetCmds = { "Library", "Client", "PetCmds" },
    CurrencyCmds = { "Library", "Client", "CurrencyCmds" },
    PlaceFile = { "Library", "Modules", "PlaceFile" },
    CalcPotionsPerTierRequired = { "Library", "Balancing", "CalcPotionsPerTierRequired" },
    CalcEnchantsPerTierRequired = { "Library", "Balancing", "CalcEnchantsPerTierRequired" },
}
local OPTIONAL_MODULE_PATHS = {
    WorldsUtil = { "Library", "Util", "WorldsUtil" },
    EnchantCmds = { "Library", "Client", "EnchantCmds" },
    UpgradeCmds = { "Library", "Client", "UpgradeCmds" },
}

local function FindPath(root, path, timeout)
    local inst = root
    for _, name in ipairs(path) do
        if not inst then
            return nil
        end
        local child = inst:FindFirstChild(name)
        if not child then
            local ok, res = pcall(function()
                return inst:WaitForChild(name, timeout or 5)
            end)
            child = ok and res or nil
        end
        inst = child
    end
    return inst
end

local function LoadModule(key, path, optional)
    if G[key] ~= nil then
        return G[key]
    end
    local inst = FindPath(RS, path, optional and 1 or 5)
    if not inst then
        if not optional then
            WarnLog(
                "mod-" .. key,
                "module %s not found (ReplicatedStorage.%s) - features needing it are disabled",
                key,
                table.concat(path, ".")
            )
        end
        return nil
    end
    local ok, mod = GameCall(require, inst)
    if not ok then
        WarnLog("mod-" .. key, "require(%s) failed: %s", key, tostring(mod))
        return nil
    end
    G[key] = mod
    return mod
end

local function DirectoryTable(name)
    if type(G.Directory) == "table" then
        local ok, t = GameCall(function()
            return G.Directory[name]
        end)
        if ok and type(t) == "table" then
            return t
        end
    end
    return LoadModule(name, { "Library", "Directory", name }, true)
end

local function LoadModules()
    for key, path in pairs(MODULE_PATHS) do
        if not State.Alive then
            return
        end
        LoadModule(key, path, false)
    end
    for key, path in pairs(OPTIONAL_MODULE_PATHS) do
        if not State.Alive then
            return
        end
        LoadModule(key, path, true)
    end
    G.Ranks = DirectoryTable("Ranks")
    G.Zones = DirectoryTable("Zones")
    G.Eggs = DirectoryTable("Eggs")
    G.Potions = DirectoryTable("Potions")
    G.Enchants = DirectoryTable("Enchants")
    G.RandomEvents = DirectoryTable("RandomEvents")
    local missing = {}
    for key in pairs(MODULE_PATHS) do
        if G[key] == nil then
            missing[#missing + 1] = key
        end
    end
    if #missing > 0 then
        table.sort(missing)
        WarnLog("mod-missing", "missing modules: %s", table.concat(missing, ", "))
    end
end

local function NetFire(name, ...)
    if not State.Alive or not State.Enabled then
        return false, "Automation paused"
    end
    if not HasFunction(G.Network, "Fire") then
        return false, "Network.Fire unavailable"
    end
    return GameCall(G.Network.Fire, name, ...)
end

local function NetInvoke(name, ...)
    if not State.Alive or not State.Enabled then
        return false, "Automation paused"
    end
    if not HasFunction(G.Network, "Invoke") then
        return false, "Network.Invoke unavailable"
    end
    return GameCall(G.Network.Invoke, name, ...)
end

local function GetSave()
    if not HasFunction(G.Save, "Get") then
        return nil
    end
    local ok, s = GameCall(G.Save.Get)
    if ok and type(s) == "table" then
        return s
    end
    return nil
end

local function ReadStateFile()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end
    local ok, data = pcall(function()
        if not isfile(STATE_FILE) then
            return nil
        end
        local raw = readfile(STATE_FILE)
        if type(raw) ~= "string" or raw == "" then
            return nil
        end
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function WriteStateFile()
    if type(writefile) ~= "function" then
        return
    end
    pcall(function()
        local options = {}
        for _, entry in ipairs(SavedOptions) do
            options[entry[1]] = Config[entry[1]]
        end
        local LegacyCounters = {}
        for Key, Value in pairs(State.Counters) do
            LegacyCounters[Key:sub(1, 1):lower() .. Key:sub(2)] = Value
        end
        local payload = {
            options = options,
            panelPosition = State.Persist.PanelPosition,
            buttonPosition = State.Persist.ButtonPosition,
            resumeCancelled = State.Persist.ResumeCancelled,
            accentIndex = State.Persist.AccentIndex,
            version = VERSION,
            savedAt = os.time(),
            lastWorldSwitch = State.Persist.LastWorldSwitch or 0,
            counters = LegacyCounters,
        }
        writefile(STATE_FILE, HttpService:JSONEncode(payload))
    end)
end
PersistHook = WriteStateFile

local function RestoreStateFile()
    local data = ReadStateFile()
    if not data then
        return
    end
    if type(data.options) == "table" then
        for _, entry in ipairs(SavedOptions) do
            local key = entry[1]
            if type(data.options[key]) == "boolean" then
                Config[key] = data.options[key]
            end
        end
    end
    if type(data.accentIndex) == "number" then
        State.Persist.AccentIndex = math.clamp(math.floor(data.accentIndex), 1, 4)
    end
    State.Persist.ResumeCancelled = data.resumeCancelled == true
    for _, Key in ipairs({ "panelPosition", "buttonPosition" }) do
        local Position = data[Key]
        if type(Position) == "table" and type(Position.x) == "number" and type(Position.y) == "number" then
            State.Persist[Key:sub(1, 1):upper() .. Key:sub(2)] = { x = Position.x, y = Position.y }
        end
    end
    State.Persist.LastWorldSwitch = tonumber(data.lastWorldSwitch) or 0
    local savedAt = tonumber(data.savedAt) or 0
    if type(data.counters) == "table" and os.time() - savedAt < STATE_FILE_MAX_AGE then
        for k, v in pairs(data.counters) do
            local Key = type(k) == "string" and k:sub(1, 1):upper() .. k:sub(2)
            if Key and type(v) == "number" and State.Counters[Key] ~= nil then
                State.Counters[Key] = v
            end
        end
        Log("Restored counters from %s", STATE_FILE)
    end
end

local function installAntiAfk()
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)
    local VirtualUser = game:GetService("VirtualUser")
    Track(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

local function sendWebhook(title, description, color, customUrl)
    local wb = Config.Webhook
    if not (wb and wb.Enabled) then return end

    local targetUrl = customUrl or wb.Url
    if type(targetUrl) ~= "string" or not targetUrl:find("^https://") then return end

    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then return end

    local payload = {
        username = "kizhub • Pet Simulator 99",
        avatar_url = "https://i.imgur.com/8Y1jE6u.png",
        embeds = { {
            title = title,
            description = description,
            color = color or 0x00E5BE,
            footer = { text = "kizhub • AutoRank Kaitun (World 1 ➔ Rank 11)" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        } }
    }

    task.spawn(function()
        local bodyJson = HttpService:JSONEncode(payload)
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
                        if data and data.retry_after then waitSec = tonumber(data.retry_after) or 5 end
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
end

local function QueueSelf(verbose)
    if State.Queued then
        return true
    end
    local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(qot) ~= "function" then
        if verbose then
            WarnLog(
                "queue-missing",
                "queue_on_teleport is not available - the script will not survive a world teleport"
            )
        end
        return false
    end
    local src = nil
    local candidateFiles = { "Autorank.lua", Config.WorkspaceFile, "PS99-AutoRank.luau" }
    for _, fn in ipairs(candidateFiles) do
        if type(fn) == "string" and type(isfile) == "function" and isfile(fn) then
            src = string.format(
                'local ok, err = pcall(function() local f, e = loadstring(readfile(%q)); assert(f, e); getgenv().PS99RankResume = true; f() end) if not ok then warn("[KizHub reexec] " .. tostring(err)) end',
                fn
            )
            break
        end
    end
    if not src then
        if verbose then
            WarnLog(
                "queue-nofile",
                "cannot re-queue: file not found in executor workspace"
            )
        end
        return false
    end
    local ok, err = pcall(qot, src)
    if ok then
        State.Queued = true
        State.Persist.ResumeCancelled = false
        WriteStateFile()
        Log("Re-execution queued for the next place teleport")
    else
        WarnLog("queue-fail", "queue_on_teleport failed: %s", tostring(err))
    end
    return ok
end

local Cache = {
    ZoneId = nil,
    ZoneAt = 0,
    Zone = nil,
    Egg = nil,
    EggAt = 0,
    MaxHatch = nil,
    MaxHatchAt = 0,
    BreakPart = nil,
    BreakPartZone = nil,
}

local function InvalidateCaches()
    Cache.ZoneAt = 0
    Cache.EggAt = 0
    Cache.MaxHatchAt = 0
    Cache.BreakPart = nil
end

local function GetHRP()
    local ch = LocalPlayer and LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

local InstanceCache = { At = -1e9, Value = false }
local function InInstance()
    local now = os.clock()
    if now - InstanceCache.At < 1 then
        return InstanceCache.Value
    end
    local v = false
    if HasFunction(G.InstancingCmds, "IsInInstance") then
        v = GameValue(G.InstancingCmds.IsInInstance) == true
    end
    InstanceCache.At = now
    InstanceCache.Value = v
    return v
end

local function CurrentWorld()
    local pf = G.PlaceFile
    if type(pf) == "table" then
        for n = 1, 4 do
            local v = pf["IsWorld" .. n]
            if type(v) == "function" then
                local ok, r = GameCall(v)
                v = ok and r or nil
            end
            if v == true then
                return n
            end
        end
    end
    if HasFunction(G.WorldsUtil, "GetWorldNumber") then
        local n = GameValue(G.WorldsUtil.GetWorldNumber)
        if type(n) == "number" then
            return n
        end
    end
    return WORLD_PLACE_IDS[game.PlaceId]
end

local function BestZoneId()
    local now = os.clock()
    if Cache.ZoneId and now - Cache.ZoneAt < 10 then
        return Cache.ZoneId
    end
    if HasFunction(G.ZoneCmds, "GetMaxOwnedZone") then
        local id = GameValue(G.ZoneCmds.GetMaxOwnedZone)
        if type(id) == "table" then
            id = id._id
        end
        if type(id) == "string" then
            Cache.ZoneId = id
            Cache.ZoneAt = now
            Cache.Zone = type(G.Zones) == "table" and G.Zones[id] or nil
        end
    end
    return Cache.ZoneId
end

local function BestZone()
    BestZoneId()
    return Cache.Zone
end

local function BestZoneName()
    local z = BestZone()
    return (z and (z.ZoneName or z._id)) or BestZoneId() or "?"
end

local function BestEgg()
    local now = os.clock()
    if Cache.Egg and now - Cache.EggAt < 10 then
        if Cache.Egg.part and Cache.Egg.part.Parent == nil then
            Cache.EggAt = 0
        else
            return Cache.Egg
        end
    end
    if not (HasFunction(G.EggCmds, "GetHighestEggNumberAvailable") and HasFunction(G.EggsUtil, "GetIdByNumber")) then
        return Cache.Egg
    end
    local n = GameValue(G.EggCmds.GetHighestEggNumberAvailable)
    if type(n) ~= "number" then
        return Cache.Egg
    end
    local id = GameValue(G.EggsUtil.GetIdByNumber, n)
    if type(id) == "table" then
        id = id._id
    end
    if type(id) ~= "string" then
        return Cache.Egg
    end
    local dir = type(G.Eggs) == "table" and G.Eggs[id] or nil
    local petIds = {}
    if dir and type(dir.pets) == "table" then
        for _, e in pairs(dir.pets) do
            if type(e) == "table" and type(e[1]) == "string" then
                petIds[e[1]] = true
            elseif type(e) == "string" then
                petIds[e] = true
            end
        end
    end
    local part = nil
    if HasFunction(G.EggsUtil, "GetEggPart") then
        local p = GameValue(G.EggsUtil.GetEggPart, n)
        if typeof(p) == "Instance" then
            if p:IsA("BasePart") then
                part = p
            elseif p:IsA("Model") then
                part = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
            end
        end
    end
    Cache.Egg = { number = n, id = id, dir = dir, petIds = petIds, part = part, name = (dir and dir.name) or id }
    Cache.EggAt = now
    return Cache.Egg
end

local function MaxHatch()
    local now = os.clock()
    if Cache.MaxHatch and now - Cache.MaxHatchAt < 30 then
        return Cache.MaxHatch
    end
    local n = nil
    if HasFunction(G.EggCmds, "GetMaxHatch") then
        n = GameValue(G.EggCmds.GetMaxHatch)
    end
    if type(n) ~= "number" or n < 1 then
        n = Cache.MaxHatch or 1
    end
    Cache.MaxHatch = math.max(1, math.floor(n))
    Cache.MaxHatchAt = now
    return Cache.MaxHatch
end

local function Inventory(category)
    local save = GetSave()
    local inv = save and save.Inventory
    local cat = type(inv) == "table" and inv[category] or nil
    if type(cat) ~= "table" then
        return {}
    end
    return cat
end

local function Stacks(category, predicate)
    local out = {}
    for uid, item in pairs(Inventory(category)) do
        if type(item) == "table" then
            local amount = tonumber(item._am) or 1
            if amount >= 1 and (predicate == nil or predicate(item, amount)) then
                out[#out + 1] = { uid = uid, item = item, amount = amount }
            end
        end
    end
    table.sort(out, function(a, b)
        return a.amount > b.amount
    end)
    return out
end

local function PickByPriority(list, priority)
    for _, id in ipairs(priority or {}) do
        for _, s in ipairs(list) do
            if s.item.id == id then
                return s
            end
        end
    end
    return nil
end

local function OrderByPriority(list, priority)
    local rank = {}
    for i, id in ipairs(priority or {}) do
        rank[id] = i
    end
    local out = {}
    for _, s in ipairs(list) do
        out[#out + 1] = s
    end
    table.sort(out, function(a, b)
        local ra, rb = rank[a.item.id] or 1e9, rank[b.item.id] or 1e9
        if ra ~= rb then
            return ra < rb
        end
        return a.amount > b.amount
    end)
    return out
end

local function RankInfo()
    local save = GetSave()
    if not save then
        return nil
    end
    local info = {}
    info.rankNumber = tonumber(save.Rank) or 1
    info.stars = tonumber(save.RankStars) or 0
    info.rebirths = tonumber(save.Rebirths) or 0
    info.rankId = HasFunction(G.RanksUtil, "RankIDFromNumber")
            and GameValue(G.RanksUtil.RankIDFromNumber, info.rankNumber)
        or nil
    info.rankDir = (info.rankId ~= nil and type(G.Ranks) == "table") and G.Ranks[info.rankId] or nil
    info.title = (info.rankDir and info.rankDir.Title) or tostring(info.rankId or ("Rank " .. info.rankNumber))
    info.rewards = (info.rankDir and type(info.rankDir.Rewards) == "table") and info.rankDir.Rewards or {}
    local total = nil
    if info.rankId ~= nil and HasFunction(G.RanksUtil, "GetTotalStarsRequired") then
        total = GameValue(G.RanksUtil.GetTotalStarsRequired, info.rankId)
    end
    if type(total) ~= "number" then
        total = 0
        for _, rw in ipairs(info.rewards) do
            total += tonumber(type(rw) == "table" and rw.StarsRequired) or 0
        end
    end
    info.totalStars = total
    info.redeemed = type(save.RedeemedRankRewards) == "table" and save.RedeemedRankRewards or {}
    local cnt = 0
    for _, v in pairs(info.redeemed) do
        if v then
            cnt += 1
        end
    end
    info.redeemedCount = cnt
    info.allRedeemed = #info.rewards > 0 and cnt >= #info.rewards
    info.isMax = HasFunction(G.RankCmds, "IsMaxRank") and GameValue(G.RankCmds.IsMaxRank) == true
    info.blockedByZone, info.blockedByRebirth = false, false
    if HasFunction(G.RankCmds, "IsRankBlockedByZone") then
        local ok, bz, br, zn, rn = GameCall(G.RankCmds.IsRankBlockedByZone)
        if ok then
            info.blockedByZone = bz == true
            info.blockedByRebirth = br == true
            info.zoneNumberNeeded = zn
            info.rebirthsNeeded = rn
        end
    end
    return info
end

local function EarnedUnclaimedRewards(info)
    local out = {}
    if not info then
        return out
    end
    local cum = 0
    for i, rw in ipairs(info.rewards) do
        cum += tonumber(type(rw) == "table" and rw.StarsRequired) or 0
        if cum <= info.stars and info.redeemed[tostring(i)] == nil then
            out[#out + 1] = i
        end
    end
    return out
end

local function NextRewardIn(info)
    if not info then
        return nil
    end
    local cum = 0
    for _, rw in ipairs(info.rewards) do
        cum += tonumber(type(rw) == "table" and rw.StarsRequired) or 0
        if cum > info.stars then
            return cum - info.stars
        end
    end
    return nil
end

local function IsSupported(t)
    if FARM_GOALS[t] then
        return Config.AutoFarm
    end
    if HATCH_GOALS[t] then
        return Config.AutoHatch
    end
    if GOLD_GOALS[t] or RAINBOW_GOALS[t] then
        return Config.AutoCraftGoldRainbow
    end
    if EVENT_GOAL_KIND[t] then
        return Config.AutoSpawnEvents
    end
    if t == T_USE_POTION then
        return Config.AutoUsePotions
    end
    if t == T_UPGRADE_POTION then
        return Config.AutoUpgradePotions
    end
    if t == T_UPGRADE_ENCHANT then
        return Config.AutoUpgradeEnchants
    end
    if t == T_USE_FRUIT then
        return Config.AutoUseFruits
    end
    if t == T_USE_FLAG then
        return Config.AutoUseFlags
    end
    if t == T_ZONE then
        return Config.AutoBuyZones
    end
    return false
end

local TitleCache, titleCacheCount = {}, 0
function Handle.AuditRanks()
    local result = { ranks = 0, goalTypes = {}, unsupported = {} }
    for _, rank in pairs(G.Ranks or {}) do
        result.ranks += 1
        for _, pool in pairs(rank.Goals or {}) do
            for _, goal in pairs(pool) do
                if type(goal) == "table" and goal.Type then
                    local id = goal.Type
                    result.goalTypes[id] = (result.goalTypes[id] or 0) + 1
                    if not IsSupported(id) then
                        result.unsupported[id] = GOAL_TYPE_NAMES[id] or tostring(id)
                    end
                end
            end
        end
    end
    return result
end

local function GoalTitle(raw, copy)
    local key = tostring(copy.UID) .. ":" .. tostring(copy.Progress)
    local cached = TitleCache[key]
    if cached then
        return cached
    end
    local title = nil
    if HasFunction(G.QuestCmds, "MakeTitle") then
        local ok, t = GameCall(G.QuestCmds.MakeTitle, raw)
        if ok and type(t) == "string" and #t > 0 then
            title = t
        end
    end
    if not title then
        title = (GOAL_TYPE_NAMES[copy.Type] or ("Type " .. tostring(copy.Type))) .. " x" .. Int(copy.Amount)
    end
    title = (string.gsub(title, "<[^>]->", ""))
    if titleCacheCount > 200 then
        TitleCache, titleCacheCount = {}, 0
    end
    TitleCache[key] = title
    titleCacheCount += 1
    return title
end

local function ActiveGoals()
    local save = GetSave()
    local list, byType = {}, {}
    if not save or type(save.Goals) ~= "table" then
        return list, byType
    end
    for tier, g in pairs(save.Goals) do
        if type(g) == "table" and g.Type ~= nil then
            local amount = tonumber(g.Amount) or 0
            local progress = tonumber(g.Progress) or 0
            local copy = {
                tier = tier,
                Stars = tonumber(g.Stars) or 0,
                Type = g.Type,
                Amount = amount,
                Progress = progress,
                UID = g.UID,
                remaining = math.max(0, amount - progress),
                PotionTier = g.PotionTier,
                EnchantTier = g.EnchantTier,
                BreakableType = g.BreakableType,
                CurrencyID = g.CurrencyID,
                raw = g,
            }
            copy.title = GoalTitle(g, copy)
            copy.supported = IsSupported(copy.Type)
            list[#list + 1] = copy
            byType[copy.Type] = byType[copy.Type] or {}
            table.insert(byType[copy.Type], copy)
        end
    end
    table.sort(list, function(a, b)
        if a.Stars ~= b.Stars then
            return a.Stars > b.Stars
        end
        return tostring(a.tier) < tostring(b.tier)
    end)
    return list, byType
end

local function GoalParam(goal, field)
    local v = goal[field]
    if v == nil and type(goal.raw) == "table" then
        v = goal.raw[field]
    end
    if v ~= nil then
        return v
    end
    local info = State.Rank
    local pools = info and info.rankDir and info.rankDir.Goals
    if type(pools) ~= "table" then
        return nil
    end
    local pool = pools[goal.tier]
    if type(pool) ~= "table" then
        pool = pools[tonumber(goal.tier)]
    end
    if type(pool) ~= "table" then
        pool = pools[tostring(goal.tier)]
    end
    if type(pool) ~= "table" then
        return nil
    end
    local fallback = nil
    for _, entry in pairs(pool) do
        if type(entry) == "table" and entry.Type == goal.Type and entry[field] ~= nil then
            if entry.Amount == goal.Amount then
                return entry[field]
            end
            if fallback == nil then
                fallback = entry[field]
            end
        end
    end
    return fallback
end

local function FindSaveGoal(goal)
    local save = GetSave()
    if not (save and type(save.Goals) == "table") then
        return nil, false
    end
    for _, g in pairs(save.Goals) do
        if type(g) == "table" and g.UID == goal.UID then
            return g, true
        end
    end
    return nil, true
end

local function CurrentRemaining(goal)
    local g, saveOk = FindSaveGoal(goal)
    if not saveOk then
        return goal.remaining
    end
    if not g then
        return 0
    end
    return math.max(0, (tonumber(g.Amount) or 0) - (tonumber(g.Progress) or 0))
end

local function ZoneArrivalPosition(ZoneId)
    if not HasFunction(G.ZonesUtil, "GetTeleportPartLocation") then
        return nil
    end
    local Arrival = GameValue(G.ZonesUtil.GetTeleportPartLocation, ZoneId)
    if typeof(Arrival) == "CFrame" then
        return Arrival.Position
    end
    if typeof(Arrival) == "Vector3" then
        return Arrival
    end
    return nil
end

local function BreakZonePart(zoneId)
    if Cache.BreakPart and Cache.BreakPartZone == zoneId and Cache.BreakPart.Parent then
        return Cache.BreakPart
    end
    local found = nil
    if HasFunction(G.ZonesUtil, "GetInteractFolder") then
        local folder = GameValue(G.ZonesUtil.GetInteractFolder, zoneId)
        if typeof(folder) == "Instance" then
            local bz = folder:FindFirstChild("BREAK_ZONES")
            if bz then
                local Arrival = ZoneArrivalPosition(zoneId)
                local NearestDistance = math.huge
                local Count = 0
                for _, Part in ipairs(bz:GetDescendants()) do
                    if Part:IsA("BasePart") then
                        Count += 1
                        local Distance = Arrival and (Part.Position - Arrival).Magnitude or 0
                        if Distance < NearestDistance then
                            found = Part
                            NearestDistance = Distance
                        end
                    end
                end
                if not Arrival and Count > 1 then
                    return nil
                end
            end
        end
    end
    if not found and HasFunction(G.MapCmds, "GetCurrentBreakZonePart") and HasFunction(G.MapCmds, "GetCurrentZone") then
        if GameValue(G.MapCmds.GetCurrentZone) == zoneId then
            local p = GameValue(G.MapCmds.GetCurrentBreakZonePart)
            if typeof(p) == "Instance" and p:IsA("BasePart") then
                found = p
            end
        end
    end
    Cache.BreakPart = found
    Cache.BreakPartZone = zoneId
    return found
end

local function StandPosition(zoneId)
    local part = BreakZonePart(zoneId)
    if part then
        return part.Position + Vector3.new(0, 4, 0)
    end
    local Arrival = ZoneArrivalPosition(zoneId)
    return Arrival and Arrival + Vector3.new(0, 3, 0) or nil
end

local function CurrentZoneInfo()
    local cz = HasFunction(G.MapCmds, "GetCurrentZone") and GameValue(G.MapCmds.GetCurrentZone) or nil
    local inBox = HasFunction(G.MapCmds, "IsInDottedBox") and GameValue(G.MapCmds.IsInDottedBox) or nil
    return cz, inBox
end

local LastEnsureAt = 0
local function EnsureInBestZone()
    if State.HatchSession or State.Hopping or State.WorldSwitching or State.WorldMismatch then
        return false
    end
    local now = os.clock()
    local force = State.ReturnAfterHatch ~= nil and now >= State.ReturnAfterHatch
    if not force and now - LastEnsureAt < 3 then
        return false
    end
    LastEnsureAt = now
    if InInstance() then
        LogEvery("ensure-instance", 30, "In an instance - not teleporting to the break zone")
        return false
    end
    local zoneId = BestZoneId()
    if not zoneId then
        return false
    end
    local pos = StandPosition(zoneId)
    if not pos then
        LogEvery("ensure-nopos", 60, "Cannot resolve the break zone position of %s yet", tostring(zoneId))
        return false
    end
    local hrp = GetHRP()
    if not hrp then
        return false
    end
    local cz = HasFunction(G.MapCmds, "GetCurrentZone") and GameValue(G.MapCmds.GetCurrentZone) or nil
    local dist = (hrp.Position - pos).Magnitude
    if dist > Config.ZonePositionTolerance or (cz ~= nil and cz ~= zoneId) then
        pcall(function()
            hrp.CFrame = CFrame.new(pos)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        State.ReturnAfterHatch = nil
        LogEvery(
            "ensure-tp",
            10,
            "Teleported into the break zone of %s (was %s studs away)",
            tostring(zoneId),
            Int(dist)
        )
        return true
    end
    State.ReturnAfterHatch = nil
    return false
end

local BreakAssign = {}
local FarmLastTier = 3
local BreakablesFolderCache = nil
local LastEquipBestAt = 0

local function BreakablesFolder()
    if BreakablesFolderCache and BreakablesFolderCache.Parent then
        return BreakablesFolderCache
    end
    local things = workspace:FindFirstChild("__THINGS")
    local f = things and things:FindFirstChild("Breakables") or nil
    BreakablesFolderCache = f
    return f
end

local function ClassifyBreakable(m)
    local id = string.lower(tostring(m:GetAttribute("BreakableID") or ""))
    local class = m:GetAttribute("BreakableClass")
    if class ~= nil and class ~= "Normal" then
        return 1
    end
    for _, w in ipairs(EVENT_BREAKABLE_WORDS) do
        if string.find(id, w, 1, true) then
            return 1
        end
    end
    if string.find(id, "diamond", 1, true) then
        return 2
    end
    return 3
end

local function IsPublicBreakable(Model)
    local Area = Model:GetAttribute("AreaID")
    return (type(Area) ~= "string" or Area:lower() ~= "vip") and Model:GetAttribute("VIPBreakable") ~= true
end

local function CollectBreakables(zoneId)
    local p1, p2, p3 = {}, {}, {}
    local folder = BreakablesFolder()
    if not folder or not zoneId then
        return p1, p2, p3
    end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("ParentID") == zoneId and IsPublicBreakable(m) then
            local uid = m:GetAttribute("BreakableUID")
            if uid ~= nil then
                local pr = ClassifyBreakable(m)
                if pr == 1 then
                    p1[#p1 + 1] = uid
                elseif pr == 2 then
                    p2[#p2 + 1] = uid
                else
                    p3[#p3 + 1] = uid
                end
            end
        end
    end
    return p1, p2, p3
end

local function PetEuids()
    if not HasFunction(G.PlayerPet, "GetByPlayer") then
        return {}
    end
    local pets = {}
    for _, pet in pairs(GameValue(G.PlayerPet.GetByPlayer, LocalPlayer) or {}) do
        if pet.owner == LocalPlayer and pet.euid ~= nil then
            table.insert(pets, pet.euid)
        end
    end
    return pets
end

local function TargetPets(assignments)
    if not State.Alive or not State.Enabled or not HasFunction(G.PlayerPet, "GetByPlayer") then
        return false
    end
    local folder = BreakablesFolder()
    if not folder then
        return false
    end
    local targets = {}
    for _, model in ipairs(folder:GetChildren()) do
        local uid = model:GetAttribute("BreakableUID")
        if uid ~= nil and IsPublicBreakable(model) then
            targets[uid] = model
        end
    end
    local updated = false
    for _, pet in pairs(GameValue(G.PlayerPet.GetByPlayer, LocalPlayer) or {}) do
        local model = targets[assignments[pet.euid]]
        if State.Enabled and model and pet.owner == LocalPlayer and pet.target ~= model then
            local Assignment = AssignedPets[pet]
            local Original = pet.target
            if Assignment and Assignment.Target == Original then
                Original = Assignment.Original
            end
            local ok = GameCall(pet.SetTarget, pet, model)
            if ok then
                AssignedPets[pet] = { Original = Original, Target = model }
            end
            updated = updated or ok
        end
    end
    return updated
end

local function MaybeEquipBest()
    if not Config.AutoEquipBestPets then
        return
    end
    local now = os.clock()
    if now - LastEquipBestAt < 30 or now - lastEquipCheckAt < 5 then
        return
    end
    lastEquipCheckAt = now
    if not (HasFunction(G.PetCmds, "GetEquipped") and HasFunction(G.PetCmds, "EquipBest")) then
        return
    end
    local okEq, eq = GameCall(G.PetCmds.GetEquipped)
    if not okEq then
        WarnLog("getequipped", "PetCmds.GetEquipped failed (%s) - EquipBest skipped", tostring(eq))
        return
    end
    if type(eq) == "table" then
        if next(eq) ~= nil then
            return
        end
    elseif type(eq) == "number" then
        if eq > 0 then
            return
        end
    else
        WarnLog("getequipped", "PetCmds.GetEquipped returned %s - EquipBest skipped", typeof(eq))
        return
    end
    LastEquipBestAt = now
    local ok, err = GameCall(G.PetCmds.EquipBest)
    if ok then
        Log("No pets equipped - PetCmds.EquipBest() called")
    else
        WarnLog("equipbest", "EquipBest failed: %s", tostring(err))
    end
end

local function WantsDiamonds()
    for _, g in ipairs(State.GoalsByType[T_DIAMOND] or {}) do
        if g.remaining > 0 then
            return true
        end
    end
    return false
end

local function FarmTick()
    if not State.Enabled then
        return
    end
    if not Config.AutoFarm then
        return
    end
    if State.WorldSwitching or State.WorldMismatch or State.Hopping or State.HatchSession then
        return
    end
    if InInstance() then
        return
    end
    EnsureInBestZone()
    local zoneId = BestZoneId()
    if not zoneId then
        return
    end
    local pets = PetEuids()
    State.FarmPets = #pets
    if #pets == 0 then
        MaybeEquipBest()
        return
    end
    local p1, p2, p3 = CollectBreakables(zoneId)
    local targets, tier
    if #p1 > 0 then
        targets, tier = p1, 1
    elseif #p2 > 0 and WantsDiamonds() then
        targets, tier = p2, 2
    else
        targets = {}
        for _, u in ipairs(p2) do
            targets[#targets + 1] = u
        end
        for _, u in ipairs(p3) do
            targets[#targets + 1] = u
        end
        tier = 3
    end
    State.FarmTargets = #targets
    if #targets == 0 then
        return
    end
    if tier < FarmLastTier then
        BreakAssign = {}
    end
    FarmLastTier = tier

    local live, used, petSet = {}, {}, {}
    for _, u in ipairs(targets) do
        live[u] = true
    end
    for _, e in ipairs(pets) do
        petSet[e] = true
    end
    for e, u in pairs(BreakAssign) do
        if live[u] and petSet[e] then
            used[u] = true
        else
            BreakAssign[e] = nil
        end
    end
    local free = {}
    for _, u in ipairs(targets) do
        if not used[u] then
            free[#free + 1] = u
        end
    end
    local rr = 0
    local map = {}
    for _, e in ipairs(pets) do
        if BreakAssign[e] == nil then
            if #free > 0 then
                BreakAssign[e] = table.remove(free, 1)
            else
                rr += 1
                BreakAssign[e] = targets[(rr - 1) % #targets + 1]
            end
        end
        map[e] = BreakAssign[e]
    end
    if next(map) == nil then
        return
    end
    if TargetPets(map) then
        State.Counters.FarmTicks += 1
    end
end

local function OnBreakableAdded(m)
    if not (State.Alive and State.Enabled and Config.AutoFarm) or State.WorldSwitching or State.WorldMismatch then
        return
    end
    if typeof(m) ~= "Instance" or not m:IsA("Model") then
        return
    end
    local zoneId = Cache.ZoneId or BestZoneId()
    if not zoneId then
        return
    end
    local function Handle()
        local ok, err = pcall(function()
            if not State.Alive or not State.Enabled or m.Parent == nil then
                return
            end
            if m:GetAttribute("ParentID") ~= zoneId or not IsPublicBreakable(m) then
                return
            end
            if ClassifyBreakable(m) ~= 1 then
                return
            end
            local uid = m:GetAttribute("BreakableUID")
            if uid == nil then
                return
            end
            if InInstance() then
                return
            end
            local pets = PetEuids()
            if #pets == 0 then
                return
            end
            local map = {}
            for _, e in ipairs(pets) do
                map[e] = uid
                BreakAssign[e] = uid
            end
            FarmLastTier = 1
            if not TargetPets(map) then
                return
            end
            State.Counters.EventTargets += 1
            Log(
                "Event breakable '%s' appeared - all pets sent to it (%s caught so far)",
                tostring(m:GetAttribute("BreakableID") or m.Name),
                Int(State.Counters.EventTargets)
            )
        end)
        if not ok then
            WarnLog("fastpath", "breakable fast-path error: %s", tostring(err))
        end
    end
    if m:GetAttribute("ParentID") == nil then
        Defer(Handle)
    else
        Handle()
    end
end

local function InstallBreakableListener()
    Defer(function()
        local folder = nil
        local t0 = os.clock()
        while State.Alive and not folder and os.clock() - t0 < 180 do
            folder = BreakablesFolder()
            if not folder then
                task.wait(1)
            end
        end
        if not folder or not State.Alive then
            if State.Alive then
                WarnLog("nobreakables", "workspace.__THINGS.Breakables not found - fast path disabled")
            end
            return
        end
        Track(folder.ChildAdded:Connect(OnBreakableAdded))
        Log("Breakable fast-path listener installed")
    end)
end

local HatchFailures = 0
local HatchBackoffUntil = 0
local HatchNeedsHop = false

local function HatchAmount()
    local amount = MaxHatch()
    local Plan = State.Plan
    if Plan.HatchEggOnly and type(Plan.HatchRemaining) == "number" and Plan.HatchRemaining > 0 then
        amount = math.min(amount, Plan.HatchRemaining)
    end
    return math.max(1, math.floor(amount))
end

local function HatchPlanned()
    return State.Enabled and Config.AutoHatch and (Config.AlwaysHatch or State.Plan.Hatch == true)
end

local function EggRevealPrompt()
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Animation = PlayerGui and PlayerGui:FindFirstChild("EggOpenAnimation")
    local Prompt = Animation and Animation.Enabled and Animation:FindFirstChild("TapToOpen")
    local Text = Prompt and Prompt:FindFirstChild("TextLabel")
    return Text
        and Text:IsA("TextLabel")
        and Text.Visible
        and Prompt.Visible
        and (
            Text.Text == "Click to open!"
            or Text.Text == "Tap to open!"
            or Text.Text:match("^Tap .+ to open!$") ~= nil
        )
end

local function AutoTapEgg()
    if
        not State.Alive
        or not State.Enabled
        or not Config.AutoHatch
        or not Config.AutoTapEggs
        or not EggRevealPrompt()
    then
        return false
    end
    if type(getconnections) ~= "function" then
        return false
    end
    local Scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local Frontend = Scripts and Scripts:FindFirstChild("Egg Opening Frontend", true)
    if not Frontend then
        return false
    end
    local Source = Frontend:GetFullName()
    for _, Connection in ipairs(getconnections(LocalPlayer:GetMouse().Button1Down)) do
        local Callback = Connection.Function
        if Connection.Enabled ~= false and type(Callback) == "function" and debug.info(Callback, "s") == Source then
            return GameCall(Callback)
        end
    end
    return false
end

local function CanHatchEgg(Egg)
    return Egg ~= nil
        and type(Egg.id) == "string"
        and HasFunction(G.EggCmds, "IsUnlocked")
        and GameValue(G.EggCmds.IsUnlocked, Egg.id) == true
        and GameValue(G.EggCmds.IsEggAvailable, Egg.id) == true
end

local function EggUnitPrice(Egg)
    if not Egg or not Egg.dir then
        return nil
    end
    return GameValue(G.CalcEggPricePlayer, Egg.dir)
end

local function AffordableHatchAmount(Egg, Limit)
    local Price = EggUnitPrice(Egg)
    local Currency = Egg.dir and Egg.dir.currency
    if type(Price) ~= "number" or not Currency then
        return 0
    end
    local Balance = GameValue(G.CurrencyCmds.Get, Currency)
    if type(Balance) == "number" then
        return math.clamp(math.floor(Balance / math.max(Price, 1)), 0, Limit)
    end
    for Amount = Limit, 1, -1 do
        if GameValue(G.CurrencyCmds.CanAfford, Currency, Amount * Price) == true then
            return Amount
        end
    end
    return 0
end

local function HatchTick()
    if not HatchPlanned() then
        State.HatchSession = false
        return
    end
    if EggRevealPrompt() then
        return
    end
    if State.WorldSwitching or State.WorldMismatch then
        return
    end
    if os.clock() < HatchBackoffUntil then
        return
    end
    if InInstance() then
        return
    end
    local egg = BestEgg()
    if not (egg and egg.id) then
        State.HatchSession = false
        WarnLog("no-egg", "cannot resolve the best egg")
        return
    end
    if GameValue(G.EggCmds.IsEggAvailable, egg.id) ~= true then
        State.HatchSession = false
        HatchBackoffUntil = os.clock() + 5
        return
    end
    local Unlocked = CanHatchEgg(egg)
    local Amount = Unlocked and AffordableHatchAmount(egg, HatchAmount()) or 0
    if Unlocked and Amount < 1 then
        State.HatchSession = false
        HatchBackoffUntil = os.clock() + 2
        LogEvery("hatch-budget", 30, "Farming for egg currency")
        return
    end
    local Root = GetHRP()
    local Part = egg.part
    local EggPosition = Part and Part.Parent and Part.Position or GameValue(G.EggsUtil.GetEggPosition, egg.number)
    local Far = Root
        and typeof(EggPosition) == "Vector3"
        and (Root.Position - EggPosition).Magnitude > Config.HatchMaxDistance
    local Hopped = Root and typeof(EggPosition) == "Vector3" and (Far or HatchNeedsHop)
    State.HatchSession = true
    if Hopped then
        State.Hopping = true
        Root.CFrame = CFrame.new(EggPosition + Vector3.new(0, 3, 6))
        Root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.25)
    end
    local Ok, Result, Message
    if Unlocked then
        Ok, Result, Message = NetInvoke("Eggs_RequestPurchase", egg.id, Amount)
    else
        Ok, Result, Message = NetInvoke("Eggs_RequestUnlock", egg.id)
    end
    if Hopped then
        State.Hopping = false
    end
    if not Unlocked then
        HatchBackoffUntil = os.clock() + (Ok and Result == true and 1 or 8)
        if Ok and Result == true then
            Log("Unlocked %s", egg.name or egg.id)
        else
            State.HatchSession = false
            WarnLog("egg-unlock", "Could not unlock %s: %s", egg.name or egg.id, tostring(Message or Result))
        end
        return
    end
    local ok, res, msg = Ok, Result, Message
    local amount, far, hopped = Amount, Far, Hopped
    if ok and res == true then
        HatchFailures = 0
        HatchNeedsHop = false
        State.Counters.Hatched += amount
        local Plan = State.Plan
        if Plan.HatchEggOnly and type(Plan.HatchRemaining) == "number" then
            Plan.HatchRemaining -= amount
            if Plan.HatchRemaining <= 0 then
                Plan.Hatch = false
                State.HatchSession = false
            end
        end
        LogEvery(
            "hatch-ok",
            30,
            "Hatching %s x%d (total %d)",
            tostring(egg.name or egg.id),
            amount,
            State.Counters.Hatched
        )
    else
        HatchFailures += 1
        local delays = { 1, 2, 5 }
        local d = delays[math.min(HatchFailures, 3)]
        HatchBackoffUntil = os.clock() + d
        local reason = ok and tostring(msg or res) or tostring(res)
        HatchNeedsHop = not hopped
            and typeof(EggPosition) == "Vector3"
            and (far or reason:lower():find("too far", 1, true) ~= nil)
        if not HatchNeedsHop then
            State.HatchSession = false
        end
        WarnLog(
            "hatch-fail",
            "hatch %s x%d failed (%s) - backing off %d s%s",
            tostring(egg.id),
            amount,
            reason,
            d,
            HatchNeedsHop and ", retrying next to the egg" or ""
        )
    end
end

local function ProtectedSet()
    local s = {}
    for _, id in ipairs(Config.ProtectedPetIds or {}) do
        s[id] = true
    end
    return s
end

local function FodderStacks(ptWanted, allowedIds)
    local prot = ProtectedSet()
    return Stacks("Pet", function(item, _)
        if type(item.id) ~= "string" then
            return false
        end
        local pt = tonumber(item.pt) or 0
        if pt ~= ptWanted then
            return false
        end
        if allowedIds and not allowedIds[item.id] then
            return false
        end
        if item.sh == true and not Config.UseShinyPetsAsFodder then
            return false
        end
        if prot[item.id] then
            return false
        end
        return true
    end)
end

local function CraftAllowedIds(goal)
    if BEST_EGG_ONLY_CRAFT[goal.Type] then
        local egg = BestEgg()
        if not (egg and egg.petIds and next(egg.petIds) ~= nil) then
            WarnLog("craft-noegg", "cannot resolve best-egg pets for goal %s", tostring(goal.title))
            return false, nil, nil
        end
        return true, egg.petIds, tostring(egg.name or egg.id)
    end
    return true, nil, "best-egg"
end

local function GoldGoalCap()
    local cap = nil
    for t in pairs(GOLD_GOALS) do
        for _, g in ipairs(State.GoalsByType[t] or {}) do
            local live = FindSaveGoal(g)
            if live then
                local r = math.max(0, (tonumber(live.Amount) or 0) - (tonumber(live.Progress) or 0))
                cap = cap and math.min(cap, r) or r
            end
        end
    end
    return cap
end

local function CraftGoldenFrom(normalStacks, rem, logSuffix, capFn)
    local crafted = 0
    for _, s in ipairs(normalStacks) do
        if rem <= 0 then
            break
        end
        while rem > 0 and s.amount >= 10 and State.Alive do
            local k = math.min(math.floor(s.amount / 10), rem, MAX_CRAFT_PER_CALL)
            local ok, res, msg = NetInvoke("GoldMachine_Activate", s.uid, k)
            if ok and res == true then
                crafted += k
                rem -= k
                s.amount -= k * 10
                State.Counters.Crafted += k
                Log("Crafted %d golden %s%s", k, tostring(s.item.id), logSuffix or "")
                task.wait(0.5)
                if capFn then
                    local c = capFn()
                    if type(c) == "number" then
                        rem = math.min(rem, c)
                    end
                end
            else
                WarnLog("gold-fail", "GoldMachine_Activate failed: %s", tostring(ok and (msg or res) or res))
                return crafted, rem, nil
            end
        end
    end
    local best = 0
    for _, s in ipairs(normalStacks) do
        best = math.max(best, s.amount)
    end
    return crafted, rem, best
end

local function FodderReason(left, leftover, label, goal)
    if left > 0 and leftover ~= nil then
        local need = math.max(1, left * 10 - leftover)
        return string.format(
            "need %d more normal %s pets for %s",
            need,
            tostring(label),
            GOAL_TYPE_NAMES[goal.Type] or "crafting"
        )
    end
    return nil
end

local function HandleGoldCraft(goal)
    local ok, allowed, label = CraftAllowedIds(goal)
    if not ok then
        return nil
    end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return nil
    end
    local normal = FodderStacks(0, allowed)
    local _, left, leftover = CraftGoldenFrom(normal, rem, "", function()
        return CurrentRemaining(goal)
    end)
    return FodderReason(left, leftover, label, goal)
end

local function CraftRainbowFrom(goldenStacks, rem, goal)
    for _, s in ipairs(goldenStacks) do
        if rem <= 0 then
            break
        end
        while rem > 0 and s.amount >= 10 and State.Alive do
            local k = math.min(math.floor(s.amount / 10), rem, MAX_CRAFT_PER_CALL)
            local ok, res, msg = NetInvoke("RainbowMachine_Activate", s.uid, k)
            if ok and res == true then
                rem -= k
                s.amount -= k * 10
                State.Counters.Crafted += k
                Log("Crafted %d rainbow %s", k, tostring(s.item.id))
                task.wait(0.5)
                rem = math.min(rem, CurrentRemaining(goal))
            else
                WarnLog("rainbow-fail", "RainbowMachine_Activate failed: %s", tostring(ok and (msg or res) or res))
                return rem, false
            end
        end
    end
    return rem, true
end

local function HandleRainbowCraft(goal)
    local okIds, allowed, label = CraftAllowedIds(goal)
    if not okIds then
        return nil
    end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return nil
    end
    local golden = FodderStacks(1, allowed)
    local okStep
    rem, okStep = CraftRainbowFrom(golden, rem, goal)
    if rem <= 0 or not okStep then
        return nil
    end
    local goldenById = {}
    for _, s in ipairs(golden) do
        goldenById[s.item.id] = (goldenById[s.item.id] or 0) + s.amount
    end
    local normal = FodderStacks(0, allowed)
    table.sort(normal, function(a, b)
        local ga, gb = goldenById[a.item.id] or 0, goldenById[b.item.id] or 0
        if ga ~= gb then
            return ga > gb
        end
        return a.amount > b.amount
    end)
    local src = normal[1]
    if not src then
        return FodderReason(rem * 10, 0, label, goal)
    end
    local goldenNeeded = rem * 10 - (goldenById[src.item.id] or 0)
    if goldenNeeded <= 0 then
        return nil
    end
    local goldCap = GoldGoalCap()
    if goldCap ~= nil then
        if goldCap <= 0 then
            LogEvery(
                "rainbow-goldcap",
                30,
                "Waiting for the gold goal to refresh before crafting golden pets for %s",
                tostring(goal.title)
            )
            return nil
        end
        goldenNeeded = math.min(goldenNeeded, goldCap)
    end
    local made, left, leftover =
        CraftGoldenFrom({ src }, goldenNeeded, " (for rainbow goal)", goldCap ~= nil and GoldGoalCap or nil)
    if made > 0 then
        task.wait(0.75)
        rem = CurrentRemaining(goal)
        if rem > 0 then
            CraftRainbowFrom(FodderStacks(1, allowed), rem, goal)
        end
    end
    return FodderReason(left, leftover, label, goal)
end

local function TierRequirement(kind, srcTier)
    local fn, fb
    if kind == "potion" then
        fn = G.CalcPotionsPerTierRequired
        fb = POTION_TIER_REQ_FALLBACK
    else
        fn = G.CalcEnchantsPerTierRequired
        fb = ENCHANT_TIER_REQ_FALLBACK
    end
    if type(fn) == "function" then
        local n = GameValue(fn, srcTier)
        if type(n) == "number" and n >= 1 then
            return math.floor(n)
        end
    end
    return fb[srcTier] or fb[#fb] or 3
end

local function HandleUsePotions(goal)
    local T = tonumber(GoalParam(goal, "PotionTier"))
    if not T then
        WarnOnce(
            "notier:" .. tostring(goal.UID),
            "USE_POTION goal '%s' has no PotionTier - skipping",
            tostring(goal.title)
        )
        return
    end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return
    end
    local n = math.min(rem, 10)
    local used = 0
    while used < n and State.Alive do
        local list = Stacks("Potion", function(item, _)
            return tonumber(item.tn) == T
        end)
        local s = PickByPriority(list, Config.PotionUsePriority) or list[1]
        if not s then
            WarnOnce(
                "noitem:" .. tostring(goal.UID),
                "No tier %d potions left in inventory (%s)",
                T,
                tostring(goal.title)
            )
            break
        end
        local ok, err = NetFire("Potions: Consume", s.uid, 1)
        if not ok then
            WarnLog("potion-fail", "Potions: Consume failed: %s", tostring(err))
            break
        end
        used += 1
        State.Counters.ItemsUsed += 1
        task.wait(0.4)
    end
    if used > 0 then
        Log("Used %d tier %d potion(s) (%s)", used, T, tostring(goal.title))
    end
end

local function UpgradeStacks(category, srcTier, priority, dirTable, targetTier)
    local list = Stacks(category, function(item, _)
        if tonumber(item.tn) ~= srcTier then
            return false
        end
        local dirEntry = type(dirTable) == "table" and item.id ~= nil and dirTable[item.id] or nil
        local maxTier = dirEntry and tonumber(dirEntry.MaxTier) or nil
        if maxTier and maxTier < targetTier then
            return false
        end
        return true
    end)
    return OrderByPriority(list, priority)
end

local function HandleUpgrade(goal, kind)
    local isPotion = kind == "potion"
    local field = isPotion and "PotionTier" or "EnchantTier"
    local T = tonumber(GoalParam(goal, field))
    if not T or T < 2 then
        WarnOnce(
            "notier:" .. tostring(goal.UID),
            "%s goal '%s' has no usable %s - skipping",
            GOAL_TYPE_NAMES[goal.Type] or "upgrade",
            tostring(goal.title),
            field
        )
        return
    end
    if isPotion and T > Config.MaxInventoryPotionTier then
        WarnOnce(
            "notier:" .. tostring(goal.UID),
            "UPGRADE_POTION goal '%s' targets tier %d above MaxInventoryPotionTier (%d) - skipping",
            tostring(goal.title),
            T,
            Config.MaxInventoryPotionTier
        )
        return
    end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return
    end
    local need = TierRequirement(kind, T - 1)
    local dirTable
    if isPotion then
        dirTable = G.Potions
    else
        dirTable = G.Enchants
    end
    local list = UpgradeStacks(
        isPotion and "Potion" or "Enchant",
        T - 1,
        isPotion and Config.PotionUpgradePriority or Config.EnchantUpgradePriority,
        dirTable,
        T
    )
    local remote = isPotion and "UpgradePotionsMachine_Activate" or "UpgradeEnchantsMachine_Activate"
    local usable = 0
    for _, s in ipairs(list) do
        if rem <= 0 or not State.Alive then
            break
        end
        if s.amount >= need then
            usable += 1
            local k = math.min(math.floor(s.amount / need), rem, MAX_UPGRADE_PER_CALL)
            local ok, res, msg = NetInvoke(remote, s.uid, k)
            if ok and res == true then
                rem -= k
                State.Counters.Crafted += k
                Log("Upgraded %d x %s %s T%d -> T%d", k, tostring(s.item.id), kind, T - 1, T)
                task.wait(0.5)
                rem = math.min(rem, CurrentRemaining(goal))
            else
                WarnLog("upg-fail-" .. kind, "%s failed: %s", remote, tostring(ok and (msg or res) or res))
                break
            end
        end
    end
    if usable == 0 and rem > 0 then
        WarnOnce(
            "noitem:" .. tostring(goal.UID),
            "No tier %d %s stacks with >= %d items to upgrade (%s)",
            T - 1,
            kind,
            need,
            tostring(goal.title)
        )
    end
end

local function HandleUseFruits(goal)
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return
    end
    local n = math.min(rem, 10)
    local used = 0
    while used < n and State.Alive do
        local list = Stacks("Fruit", function(item, _)
            if item.sh == true and not Config.AllowShinyFruit then
                return false
            end
            return true
        end)
        local s = PickByPriority(list, Config.FruitUsePriority) or list[1]
        if not s then
            WarnOnce("noitem:" .. tostring(goal.UID), "No fruits left in inventory (%s)", tostring(goal.title))
            break
        end
        local ok, err = NetFire("Fruits: Consume", s.uid, 1)
        if not ok then
            WarnLog("fruit-fail", "Fruits: Consume failed: %s", tostring(err))
            break
        end
        used += 1
        State.Counters.ItemsUsed += 1
        task.wait(0.4)
    end
    if used > 0 then
        Log("Used %d fruit(s) (%s)", used, tostring(goal.title))
    end
end

local function HandleUseFlags(goal)
    if os.clock() < State.FlagRetryAt then
        return
    end
    if State.WorldMismatch then
        return
    end
    if not HasFunction(G.FlexibleFlagCmds, "Consume") then
        LogOnce("noflagcmds", "FlexibleFlagCmds.Consume unavailable - flag goals are manual")
        return
    end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then
        return
    end
    if InInstance() then
        return
    end
    local zoneId = BestZoneId()
    local cz, inBox = CurrentZoneInfo()
    if cz ~= zoneId or inBox ~= true then
        EnsureInBestZone()
        return
    end
    local list = Stacks("Misc", function(item, _)
        return type(item.id) == "string" and string.sub(item.id, -5) == " Flag"
    end)
    local s = PickByPriority(list, Config.FlagPriority) or list[1]
    if not s then
        WarnOnce("noitem:" .. tostring(goal.UID), "No flags left in inventory (%s)", tostring(goal.title))
        State.FlagRetryAt = os.clock() + 60
        return
    end
    local ok, res, msg = GameCall(G.FlexibleFlagCmds.Consume, s.item.id, s.uid, 1)
    if ok and res == true then
        State.Counters.ItemsUsed += 1
        State.FlagRetryAt = os.clock() + 5
        Log("Placed %s (%s left) for %s", tostring(s.item.id), Int(s.amount - 1), tostring(goal.title))
    elseif ok and res == false then
        local m = tostring(msg or "")
        local ml = string.lower(m)
        if string.find(ml, "different flag", 1, true) or string.find(ml, "already", 1, true) then
            State.FlagRetryAt = os.clock() + 60
            LogEvery("flag-exists", 60, "A flag is already placed in this area (%s) - retrying in 60 s", m)
        else
            State.FlagRetryAt = os.clock() + 20
            WarnLog("flag-fail", "Flag placement refused: %s", m)
        end
    else
        State.FlagRetryAt = os.clock() + 20
        WarnLog("flag-err", "FlexibleFlagCmds.Consume error: %s", tostring(res))
    end
end

local function CraftOrder(t)
    if GOLD_GOALS[t] then
        return 1
    end
    if RAINBOW_GOALS[t] then
        return 2
    end
    return 3
end

local function CraftTick()
    if not State.Enabled then
        return
    end
    if State.WorldSwitching then
        return
    end
    local goals = {}
    for _, g in ipairs(State.Goals) do
        if g.remaining > 0 then
            goals[#goals + 1] = g
        end
    end
    if #goals == 0 then
        State.CraftHatchReason = nil
        return
    end
    table.sort(goals, function(a, b)
        local oa, ob = CraftOrder(a.Type), CraftOrder(b.Type)
        if oa ~= ob then
            return oa < ob
        end
        if a.Stars ~= b.Stars then
            return a.Stars > b.Stars
        end
        return tostring(a.tier) < tostring(b.tier)
    end)
    local needHatch = nil
    for _, goal in ipairs(goals) do
        if not State.Alive or not State.Enabled then
            return
        end
        local t = goal.Type
        local handler, arg = nil, nil
        if GOLD_GOALS[t] and Config.AutoCraftGoldRainbow then
            handler = HandleGoldCraft
        elseif RAINBOW_GOALS[t] and Config.AutoCraftGoldRainbow then
            handler = HandleRainbowCraft
        elseif t == T_USE_POTION and Config.AutoUsePotions then
            handler = HandleUsePotions
        elseif t == T_UPGRADE_POTION and Config.AutoUpgradePotions then
            handler, arg = HandleUpgrade, "potion"
        elseif t == T_UPGRADE_ENCHANT and Config.AutoUpgradeEnchants then
            handler, arg = HandleUpgrade, "enchant"
        elseif t == T_USE_FRUIT and Config.AutoUseFruits then
            handler = HandleUseFruits
        elseif t == T_USE_FLAG and Config.AutoUseFlags then
            handler = HandleUseFlags
        end
        if handler then
            local ok, result = pcall(handler, goal, arg)
            if not ok then
                WarnLog("handler-" .. tostring(t), "handler for goal type %s failed: %s", tostring(t), tostring(result))
            elseif (GOLD_GOALS[t] or RAINBOW_GOALS[t]) and type(result) == "string" and needHatch == nil then
                needHatch = result
            end
        end
    end
    if needHatch ~= nil then
        LogEvery("craft-fodder", 30, "Crafting needs more fodder: %s - hatching the best egg", needHatch)
    end
    State.CraftHatchReason = needHatch
end

local function EventKindOf(ev)
    if type(ev) ~= "table" then
        return nil
    end
    local names = {}
    if type(ev.dir) == "table" then
        names[#names + 1] = ev.dir._id
        names[#names + 1] = ev.dir.Name
        names[#names + 1] = ev.dir.name
    end
    names[#names + 1] = ev.id
    names[#names + 1] = ev.name
    for _, n in ipairs(names) do
        if type(n) == "string" then
            local norm = string.lower((string.gsub(n, "%s", "")))
            for kind, def in pairs(EVENT_DEFS) do
                for _, m in ipairs(def.match) do
                    if string.find(norm, m, 1, true) then
                        return kind
                    end
                end
            end
        end
    end
    return nil
end

local function ActiveEventKinds(zoneId)
    local kinds = {}
    if not HasFunction(G.RandomEventCmds, "GetActive") then
        return kinds
    end
    local ok, active = GameCall(G.RandomEventCmds.GetActive)
    if not ok or type(active) ~= "table" then
        return kinds
    end
    for _, ev in pairs(active) do
        local kind = EventKindOf(ev)
        if kind and (ev.parentID == nil or ev.parentID == zoneId) then
            kinds[kind] = true
        end
    end
    return kinds
end

local function PickMiscStack(ids)
    local set = MakeSet(ids or {})
    local list = Stacks("Misc", function(item, _)
        return set[item.id] == true
    end)
    return PickByPriority(list, ids) or list[1]
end

local function EventTick()
    if not State.Enabled then
        return
    end
    if not Config.AutoSpawnEvents then
        return
    end
    if State.WorldSwitching or State.WorldMismatch or State.Hopping or State.HatchSession then
        return
    end
    local wanted = {}
    for _, goal in ipairs(State.Goals) do
        local kind = EVENT_GOAL_KIND[goal.Type]
        if kind and goal.remaining > 0 and wanted[kind] == nil then
            wanted[kind] = goal
        end
    end
    if next(wanted) == nil then
        return
    end
    if InInstance() then
        return
    end
    local zoneId = BestZoneId()
    if not zoneId then
        return
    end
    local cz, inBox = CurrentZoneInfo()
    if cz ~= zoneId or inBox ~= true then
        LogEvery(
            "event-notinbox",
            30,
            "Not inside the dotted box of %s - moving before spawning event items",
            tostring(zoneId)
        )
        EnsureInBestZone()
        return
    end
    local active = ActiveEventKinds(zoneId)
    local now = os.clock()
    for kind, goal in pairs(wanted) do
        if not State.Alive then
            return
        end
        local def = EVENT_DEFS[kind]
        if
            def
            and not active[kind]
            and now - (State.LastEventSpawn[kind] or -1e9) >= 12
            and now >= (State.EventBackoffUntil[kind] or 0)
        then
            local rem = CurrentRemaining(goal)
            if rem > 0 then
                local s = PickMiscStack(def.items)
                if not s then
                    WarnOnce(
                        "noitem:" .. tostring(goal.UID),
                        "No %s left in inventory (%s)",
                        table.concat(def.items, "/"),
                        tostring(goal.title)
                    )
                else
                    local ok, res, msg = NetInvoke(def.remote, s.uid)
                    if ok and res == true then
                        State.LastEventSpawn[kind] = now
                        State.Counters.ItemsUsed += 1
                        Log(
                            "Spawned %s (%s left) - %s %s/%s",
                            tostring(s.item.id),
                            Int(s.amount - 1),
                            def.label,
                            Int(goal.Amount - rem + 1),
                            Int(goal.Amount)
                        )
                    else
                        State.EventBackoffUntil[kind] = now + 10
                        WarnLog(
                            "event-fail-" .. kind,
                            "%s failed: %s",
                            def.remote,
                            tostring(ok and (msg or res) or res)
                        )
                    end
                    task.wait(0.3)
                end
            end
        end
    end
end

local LastWorldAttempt = -1e9

local function WorldTeleport(n, zoneId)
    if State.WorldSwitching then
        return
    end
    if os.clock() - LastWorldAttempt < 30 then
        return
    end
    LastWorldAttempt = os.clock()
    n = math.floor(tonumber(n) or 0)
    local now = os.time()
    local last = tonumber(State.Persist.LastWorldSwitch) or 0
    if now - last < 90 then
        WarnLog(
            "world-loop",
            "Best zone is in World %d but the last world switch was %d s ago - waiting (anti-loop guard)",
            n,
            now - last
        )
        return
    end
    if not QueueSelf(true) then
        WarnLog(
            "world-noqueue",
            "Not teleporting to World %d: re-execution could not be queued (put this file in the Potassium workspace as %s, or teleport manually)",
            n,
            tostring(Config.WorkspaceFile)
        )
        return
    end
    State.Persist.LastWorldSwitch = now
    WriteStateFile()
    State.WorldSwitching = true
    State.WorldSwitchAt = os.clock()
    State.Action = string.format("Teleporting to World %d", n)
    Log("Teleporting to World %d (best zone %s)", n, tostring(zoneId))
    local ok, res, msg = NetInvoke(string.format("World%dTeleport", n))
    if not ok or res == false then
        State.WorldSwitching = false
        State.Persist.LastWorldSwitch = last
        WriteStateFile()
        if not ok then
            WarnLog("world-fail", "World%dTeleport failed: %s", n, tostring(res))
        else
            WarnLog("world-refused", "World%dTeleport refused: %s", n, tostring(msg))
        end
    end
end

local function CheckWorld()
    if Config.StayInWorld1 then
        State.World = 1
        State.WorldMismatch = false
        return
    end
    if State.WorldSwitching then
        if os.clock() - State.WorldSwitchAt > 45 then
            State.WorldSwitching = false
            WarnLog("world-timeout", "World teleport did not happen within 45 s - resuming")
        end
        return
    end
    local zone = BestZone()
    local cw = CurrentWorld()
    State.World = cw or State.World
    if not (zone and type(zone.WorldNumber) == "number" and cw) then
        State.WorldMismatch = false
        return
    end
    State.WorldMismatch = cw ~= zone.WorldNumber
    if not State.WorldMismatch then
        return
    end
    if Config.AutoWorldTeleport then
        WorldTeleport(zone.WorldNumber, BestZoneId())
    else
        LogOnce(
            "world:wrong",
            "Best zone %s is in World %s but we are in World %s - enable AutoWorldTeleport or teleport manually (farming/hatching/events idle; crafting and item use continue)",
            tostring(BestZoneId()),
            tostring(zone.WorldNumber),
            tostring(cw)
        )
    end
end

local function OnRankUp(info)
    Log("RANK UP! now rank %d - %s", info.rankNumber, tostring(info.title))
    for i in pairs(State.PendingClaims) do
        State.Counters.Claimed += 1
        State.PendingClaims[i] = nil
    end
    State.ClaimedAt = {}
    State.ClaimAttempts = {}
    State.TrackCompleteLoggedRank = nil
    State.TrackCompleteAt = nil
    State.RankUpFiredRank = nil
    State.LastZoneBuyAt = 0
    ResetOnce("rank:")
    HatchFailures = 0
    HatchBackoffUntil = 0
    HatchNeedsHop = false
    InvalidateCaches()
    WriteStateFile()

    -- WEBHOOK THÔNG BÁO RANK (ĐẠT RANK 11 VÀ MỖI LẦN LÊN RANK)
    local elapsed = math.floor(os.clock() - State.StartedAt)
    local elapsedStr = string.format("%02dh %02dm %02ds", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
    local bestZName = BestZoneName() or ("Zone #" .. tostring(BestZoneId() or "?"))

    if info.rankNumber >= (Config.TargetRank or 11) then
        if not State.Rank11WebhookSent then
            State.Rank11WebhookSent = true
            sendWebhook(
                "👑 [KIZHUB • HOÀN THÀNH MỤC TIÊU RANK 11!] 👑",
                string.format(
                    "👤 **Tài khoản:** `%s`\n" ..
                    "🏆 **Rank đạt được:** **Rank %d - %s**\n" ..
                    "🗺️ **Khu vực:** World 1 (`%s`)\n" ..
                    "⏱️ **Thời gian cày:** `%s`\n" ..
                    "⭐ **Tổng sao tích lũy:** `%s Stars`\n" ..
                    "🎁 **Phần thưởng đã nhận:** `%d`\n" ..
                    "🥚 **Trứng đã mở:** `%s`\n" ..
                    "⚡ Kaitun World 1 hoàn tất xuất sắc!",
                    LocalPlayer.Name,
                    info.rankNumber,
                    tostring(info.title),
                    bestZName,
                    elapsedStr,
                    Int(info.stars),
                    info.redeemedCount or 0,
                    Int(State.Counters.Hatched)
                ),
                0xFFD700
            )
        end
    elseif Config.Webhook and Config.Webhook.NotifyEveryRank then
        sendWebhook(
            "🎉 [KIZHUB • LÊN RANK THÀNH CÔNG!] 🎉",
            string.format(
                "👤 **Tài khoản:** `%s`\n" ..
                "📈 **Rank mới:** **Rank %d - %s**\n" ..
                "🎯 **Mục tiêu:** Rank %d (Còn %d rank)\n" ..
                "🗺️ **Khu vực:** World 1 (`%s`)\n" ..
                "⏱️ **Thời gian:** `%s`\n" ..
                "⭐ **Stars hiện tại:** `%s / %s`",
                LocalPlayer.Name,
                info.rankNumber,
                tostring(info.title),
                Config.TargetRank or 11,
                math.max(0, (Config.TargetRank or 11) - info.rankNumber),
                bestZName,
                elapsedStr,
                Int(info.stars),
                Int(info.totalStars)
            ),
            0x00E5BE
        )
    end
end

local function ClaimRewards(info)
    if not Config.AutoClaimRewards or not info then
        return
    end
    for i in pairs(State.PendingClaims) do
        if info.redeemed[tostring(i)] ~= nil then
            State.Counters.Claimed += 1
            State.PendingClaims[i] = nil
        end
    end
    local now = os.clock()
    for _, i in ipairs(EarnedUnclaimedRewards(info)) do
        if not State.Alive then
            return
        end
        local attempts = State.ClaimAttempts[i] or 0
        local stuck = attempts >= MAX_CLAIM_ATTEMPTS
        if stuck then
            WarnOnce(
                "rank:claimstuck-" .. tostring(i),
                "Reward #%d was requested %d times but never redeemed - retrying every %d s (RankRewards disabled server-side?)",
                i,
                attempts,
                CLAIM_SLOW_RETRY
            )
        end
        local last = State.ClaimedAt[i]
        if last == nil or now - last > (stuck and CLAIM_SLOW_RETRY or 5) then
            local ok, err = NetFire("Ranks_ClaimReward", i)
            if ok then
                State.ClaimedAt[i] = now
                State.ClaimAttempts[i] = attempts + 1
                State.PendingClaims[i] = now
                if stuck then
                    LogEvery(
                        "claim-retry-" .. tostring(i),
                        300,
                        "Retrying reward #%d claim (%s/%s stars)",
                        i,
                        Int(info.stars),
                        Int(info.totalStars)
                    )
                else
                    Log("Claimed reward #%d (%s/%s stars)", i, Int(info.stars), Int(info.totalStars))
                end
                task.wait(0.3)
            else
                WarnLog("claim-fail", "Ranks_ClaimReward %d failed: %s", i, tostring(err))
            end
        end
    end
end

local function CheckTrackComplete(info)
    if not info or info.isMax then
        return
    end
    if not (info.allRedeemed and info.stars >= info.totalStars) then
        return
    end
    if info.blockedByZone or info.blockedByRebirth then
        return
    end
    if State.TrackCompleteLoggedRank ~= info.rankNumber then
        State.TrackCompleteLoggedRank = info.rankNumber
        State.TrackCompleteAt = os.clock()
        Log("Rank %d track complete - waiting for the server rank-up", info.rankNumber)
    end
end

local function HandleBlockedAndZones(info)
    if info and info.isMax then
        LogOnce("rank:max", "Max rank reached - nothing more to rank up")
    end
    if info and info.blockedByZone then
        LogOnce(
            "rank:blockedzone",
            "Rank %d is blocked by zone: zone #%s required%s",
            info.rankNumber,
            tostring(info.zoneNumberNeeded),
            Config.AutoBuyZones and " - trying to buy zones" or ""
        )
    end
    if info and info.blockedByRebirth then
        LogOnce(
            "rank:blockedrebirth",
            "Rank %d is blocked by rebirth: %s rebirth(s) required (have %s) - rebirths are not automated",
            info.rankNumber,
            tostring(info.rebirthsNeeded),
            Int(info.rebirths)
        )
    end
    if not Config.AutoBuyZones then
        return
    end
    if
        State.WorldSwitching
        or State.Hopping
        or State.HatchSession
        or InInstance()
        or os.clock() - State.LastZoneBuyAt < 2
    then
        return
    end
    if not HasFunction(G.ZoneCmds, "GetNextZone") then
        return
    end
    local ZoneId, Zone = GameValue(G.ZoneCmds.GetNextZone)
    if type(ZoneId) == "table" then
        Zone, ZoneId = ZoneId, ZoneId._id
    end
    Zone = Zone or (type(ZoneId) == "string" and G.Zones and G.Zones[ZoneId])
    if type(Zone) ~= "table" or type(ZoneId) ~= "string" or Zone.WorldNumber ~= CurrentWorld() then
        return
    end
    if GameValue(G.ZoneCmds.HasCompletedNextZoneQuests) ~= true then
        return
    end
    local Price = GameValue(G.Balancing and G.Balancing.CalcGatePrice, Zone)
    if
        type(Price) ~= "number"
        or not Zone.Currency
        or GameValue(G.CurrencyCmds.CanAfford, Zone.Currency, Price) ~= true
    then
        return
    end
    State.LastZoneBuyAt = os.clock()
    local ok, res, msg = NetInvoke("Zones_RequestPurchase", ZoneId)
    if not ok then
        WarnLog("zonebuy-err", "Zones_RequestPurchase error: %s", tostring(res))
    elseif res == false then
        LogEvery("zonebuy-refused", 30, "Zone purchase of %s refused: %s", ZoneId, tostring(msg))
    else
        InvalidateCaches()
        Log("Purchased zone %s", ZoneId)
        InvalidateCaches()
    end
end

local function BuildPlan()
    local info = State.Rank
    local Plan = {
        Hatch = false,
        HatchReasons = {},
        HatchEggOnly = true,
        HatchRemaining = nil,
        Crafting = false,
        WaitingChest = false,
    }
    local parts = {}
    local zone = BestZone()
    if State.WorldSwitching then
        State.Plan = Plan
        State.Action = string.format("teleporting to World %s", tostring(zone and zone.WorldNumber or "?"))
        return
    end
    if State.WorldMismatch then
        parts[#parts + 1] =
            string.format("wrong world (best zone is in World %s)", tostring(zone and zone.WorldNumber or "?"))
    elseif info and info.isMax then
        parts[#parts + 1] = "max rank reached"
    elseif Config.AutoFarm then
        local s = string.format(
            "Farming %s (%s pets / %s targets)",
            tostring(BestZoneName()),
            Int(State.FarmPets),
            Int(State.FarmTargets)
        )
        if State.Counters.EventTargets > 0 then
            s = s .. string.format(", %s events caught", Int(State.Counters.EventTargets))
        end
        parts[#parts + 1] = s
    end
    for _, goal in ipairs(State.Goals) do
        local t = goal.Type
        if goal.remaining > 0 then
            if HATCH_GOALS[t] and Config.AutoHatch then
                Plan.Hatch = true
                table.insert(Plan.HatchReasons, GOAL_TYPE_NAMES[t] or tostring(t))
                if EGG_COUNT_GOALS[t] then
                    Plan.HatchRemaining = math.max(Plan.HatchRemaining or 0, goal.remaining)
                else
                    Plan.HatchEggOnly = false
                end
            elseif (GOLD_GOALS[t] or RAINBOW_GOALS[t]) and Config.AutoCraftGoldRainbow then
                Plan.Crafting = true
                parts[#parts + 1] = string.format(
                    "%s %s/%s",
                    GOLD_GOALS[t] and "gold crafting" or "rainbow crafting",
                    Int(goal.Progress),
                    Int(goal.Amount)
                )
            elseif EVENT_GOAL_KIND[t] and Config.AutoSpawnEvents then
                local def = EVENT_DEFS[EVENT_GOAL_KIND[t]]
                parts[#parts + 1] = string.format("%s %s/%s", def.label, Int(goal.Progress), Int(goal.Amount))
            elseif CHEST_GOALS[t] then
                Plan.WaitingChest = true
            elseif t == T_USE_POTION and Config.AutoUsePotions then
                parts[#parts + 1] = string.format(
                    "potions T%s %s/%s",
                    tostring(GoalParam(goal, "PotionTier") or "?"),
                    Int(goal.Progress),
                    Int(goal.Amount)
                )
            elseif t == T_UPGRADE_POTION and Config.AutoUpgradePotions then
                parts[#parts + 1] = string.format("potion upgrades %s/%s", Int(goal.Progress), Int(goal.Amount))
            elseif t == T_UPGRADE_ENCHANT and Config.AutoUpgradeEnchants then
                parts[#parts + 1] = string.format("enchant upgrades %s/%s", Int(goal.Progress), Int(goal.Amount))
            elseif t == T_USE_FRUIT and Config.AutoUseFruits then
                parts[#parts + 1] = string.format("fruits %s/%s", Int(goal.Progress), Int(goal.Amount))
            elseif t == T_USE_FLAG and Config.AutoUseFlags then
                parts[#parts + 1] = string.format("flags %s/%s", Int(goal.Progress), Int(goal.Amount))
            elseif t == T_ZONE and Config.AutoBuyZones then
                parts[#parts + 1] = "buying zones"
            end
        end
    end
    local fodderOnly = false
    if State.CraftHatchReason ~= nil and Config.AutoHatch then
        fodderOnly = not Plan.Hatch
        Plan.Hatch = true
        Plan.HatchEggOnly = false
        table.insert(Plan.HatchReasons, State.CraftHatchReason)
    end
    if Config.AlwaysHatch and Config.AutoHatch then
        Plan.Hatch = true
        Plan.HatchEggOnly = false
        fodderOnly = false
    end
    if not Plan.Hatch then
        Plan.HatchEggOnly = false
    end
    State.Plan = Plan
    if Plan.Hatch and not State.WorldMismatch then
        local egg = Cache.Egg or BestEgg()
        parts[#parts + 1] = string.format(
            "hatching %s x%s%s",
            tostring(egg and (egg.name or egg.id) or "best egg"),
            Int(HatchAmount()),
            fodderOnly and " (fodder)" or ""
        )
    end
    if Plan.WaitingChest then
        parts[#parts + 1] = "waiting for mini chest spawns"
    end
    if info and info.blockedByZone then
        parts[#parts + 1] = string.format("rank needs zone %s", tostring(info.zoneNumberNeeded or "?"))
    elseif info and info.blockedByRebirth then
        parts[#parts + 1] =
            string.format("rank needs %s rebirths (have %s)", tostring(info.rebirthsNeeded or "?"), Int(info.rebirths))
    end
    if State.Hopping then
        parts[#parts + 1] = "hopping to egg"
    end
    State.Action = #parts > 0 and table.concat(parts, " | ") or "idle"
end

-- ============================================================================
-- AUTO PICK STARTER PETS, AUTO OPEN SLOTS & AUTO CLAIM FREE GIFTS
-- ============================================================================

local function autoPickStarterPets()
    if not Config.AutoPickStarterPets then
        return
    end
    if State.StarterPetsPicked then
        return
    end
    local now = os.clock()
    if now - (State.LastStarterPetCheckAt or 0) < 5 then
        return
    end
    State.LastStarterPetCheckAt = now

    -- 1. Kiểm tra inventory hiện tại xem đã có pet starter chưa
    local save = GetSave()
    if save and save.Inventory and type(save.Inventory.Pet) == "table" then
        local petCount = 0
        for _ in pairs(save.Inventory.Pet) do
            petCount = petCount + 1
            if petCount >= 2 then
                State.StarterPetsPicked = true
                return
            end
        end
    end

    -- 2. Thử remote chọn 2 pet starter qua Network
    local candidatePairs = {
        { "Cat", "Dog" },
        { "Dog", "Cat" },
        { "Dragon", "Bunny" },
        { 1, 2 },
    }
    for _, pair in ipairs(candidatePairs) do
        pcall(function()
            NetInvoke("Pick Starter Pets", pair[1], pair[2])
        end)
        pcall(function()
            NetInvoke("Pick Starter Pets", pair)
        end)
        pcall(function()
            NetFire("Pick Starter Pets", pair[1], pair[2])
        end)
        pcall(function()
            NetFire("Pick Starter Pets", pair)
        end)
    end

    -- 3. Quét PlayerGui nếu có bảng chọn starter pet của game
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pgui then
            return
        end
        for _, gui in ipairs(pgui:GetChildren()) do
            local gname = gui.Name:lower()
            if gname:find("starter") or gname:find("intro") or gname:find("tutorial") or gname:find("pick") or gname:find("choose") then
                local petBtns = {}
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("GuiButton") and desc.Visible then
                        local n = desc.Name:lower()
                        local t = desc:IsA("TextButton") and desc.Text:lower() or ""
                        if n:find("cat") or n:find("dog") or n:find("bunny") or n:find("dragon") or
                           t:find("cat") or t:find("dog") or t:find("bunny") or t:find("dragon") then
                            petBtns[#petBtns + 1] = desc
                        end
                    end
                end
                for i = 1, math.min(2, #petBtns) do
                    local btn = petBtns[i]
                    pcall(function()
                        if type(getconnections) == "function" then
                            for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                            end
                            for _, c in ipairs(getconnections(btn.Activated) or {}) do
                                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                            end
                        end
                    end)
                end
                task.wait(0.2)
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("GuiButton") and desc.Visible then
                        local n = desc.Name:lower()
                        local t = desc:IsA("TextButton") and desc.Text:lower() or ""
                        if n:find("confirm") or n:find("select") or n:find("ready") or n:find("claim") or n:find("pick") or
                           t:find("confirm") or t:find("select") or t:find("ready") or t:find("claim") or t:find("ok") then
                            pcall(function()
                                if type(getconnections) == "function" then
                                    for _, c in ipairs(getconnections(desc.MouseButton1Click) or {}) do
                                        if c.Fire then c:Fire() elseif c.Function then c.Function() end
                                    end
                                    for _, c in ipairs(getconnections(desc.Activated) or {}) do
                                        if c.Fire then c:Fire() elseif c.Function then c.Function() end
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)

    -- 4. Xác nhận lại inventory sau khi pick
    task.wait(0.5)
    local saveAfter = GetSave()
    if saveAfter and saveAfter.Inventory and type(saveAfter.Inventory.Pet) == "table" then
        local count = 0
        for _ in pairs(saveAfter.Inventory.Pet) do
            count = count + 1
        end
        if count >= 2 then
            State.StarterPetsPicked = true
            Log("Starter pets selected successfully (%d pets in inventory)", count)
            if HasFunction(G.PetCmds, "EquipBest") then
                pcall(G.PetCmds.EquipBest)
            end
        end
    end
end

local function autoOpenSlots()
    if not Config.AutoOpenSlots or not State.Enabled then
        return
    end
    if State.WorldSwitching or State.WorldMismatch or State.Hopping then
        return
    end
    local now = os.clock()
    if now - (State.LastSlotPurchaseAt or 0) < 15 then
        return
    end
    State.LastSlotPurchaseAt = now

    -- Kích hoạt Proximity của cả 2 máy nâng cấp slot
    pcall(function()
        NetFire("Machines: Mark Approached", "EquipSlotsMachine")
        NetFire("Machines: Mark Approached", "EggHatchSlotsMachine")
    end)
    task.wait(0.1)

    -- 1. Nâng cấp Slot Pet (Pet Equip Slots)
    for _ = 1, 5 do
        local ok, res = NetInvoke("EquipSlotsMachine_RequestPurchase")
        if not ok or res == false then
            local okFb, resFb = NetInvoke("Upgrades_Purchase", "PetSlots")
            if not okFb or resFb == false then
                break
            end
        end
        task.wait(0.15)
    end

    -- 2. Nâng cấp Slot Mở Trứng (Egg Hatch Slots)
    for _ = 1, 5 do
        local ok, res = NetInvoke("EggHatchSlotsMachine_RequestPurchase")
        if not ok or res == false then
            local okFb, resFb = NetInvoke("Upgrades_Purchase", "EggSlots")
            if not okFb or resFb == false then
                break
            end
        end
        task.wait(0.15)
    end
end

local function checkAndClaimFreeGifts()
    if not Config.AutoClaimFreeGifts or not State.Enabled then
        return
    end
    local now = os.clock()
    if now < (State.NextClaimGiftsAt or 0) then
        return
    end
    State.NextClaimGiftsAt = now + 60

    -- 12 mốc Free Gifts trong PS99
    for giftId = 1, 12 do
        pcall(function()
            NetInvoke("Redeem Free Gift", giftId)
        end)
        pcall(function()
            NetFire("Redeem Free Gift", giftId)
        end)
        task.wait(0.1)
    end
end

local function ControllerTick()
    local info = RankInfo()
    if info then
        State.Rank = info
        if State.LastRank ~= nil and info.rankNumber ~= State.LastRank then
            OnRankUp(info)
        end
        State.LastRank = info.rankNumber
    end
    local goals, byType = ActiveGoals()
    State.Goals = goals
    State.GoalsByType = byType
    for _, goal in ipairs(goals) do
        if not goal.supported then
            LogOnce(
                "unsupported-" .. tostring(goal.UID),
                "Goal '%s' (type %s %s) is not automatable; farming continues",
                tostring(goal.title),
                tostring(goal.Type),
                GOAL_TYPE_NAMES[goal.Type] or ""
            )
        end
    end
    if not State.Enabled then
        State.Plan = { Hatch = false, HatchReasons = {}, HatchEggOnly = false, HatchRemaining = nil }
        State.HatchSession = false
        State.Action = "automation paused - rank tracking only"
        return
    end
    if State.WorldSwitching then
        BuildPlan()
        CheckWorld()
        return
    end
    pcall(ClaimRewards, info)
    pcall(CheckTrackComplete, info)
    pcall(HandleBlockedAndZones, info)
    pcall(CheckWorld)
    BuildPlan()
end

local function SetEnabled(on)
    on = on ~= false
    if State.Enabled == on then
        return on
    end
    State.Enabled = on
    if on then
        InvalidateCaches()
        State.Action = "resuming"
        Log("Automation enabled")
    else
        State.HatchSession = false
        State.Action = "automation paused - rank tracking only"
        Log("Automation paused")
    end
    return on
end

Handle.SetEnabled = SetEnabled
Handle.Toggle = function()
    return SetEnabled(not State.Enabled)
end
Handle.IsEnabled = function()
    return State.Enabled == true
end

local BuildGui, RefreshGui
local function ConfigureGui()
    local Width, Height = GUI_WIDTH, 422
    local Background = Color3.fromRGB(22, 23, 27)
    local Surface = Color3.fromRGB(33, 35, 40)
    local Text = Color3.fromRGB(244, 245, 249)
    local Muted = Color3.fromRGB(164, 171, 187)
    local Accents = {
        { "Blue", Color3.fromRGB(157, 196, 255) },
        { "Mint", Color3.fromRGB(132, 220, 182) },
        { "Lavender", Color3.fromRGB(202, 170, 255) },
        { "Amber", Color3.fromRGB(255, 207, 138) },
    }
    local Accent = Accents[1][2]
    local Switches = {}
    local HomeElapsed, HomeActivity, HomeStats, HomeStart
    local Motion = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local Window, Body, Start, Rank, Stars, Fill, Status
    local Rows = {}
    local Pages, Tabs = {}, {}
    local ActivePage
    local TabSpecs = {
        { "Home", "rbxassetid://15048277985" },
        { "Rank", "rbxassetid://15055562843" },
        { "Eggs", "rbxassetid://15209657961" },
        { "Settings", "rbxassetid://15048277045" },
    }
    local LastEnabled, LastProgress

    local function Animate(Object, Properties)
        if Config.ReduceMotion then
            for Key, Value in pairs(Properties) do
                Object[Key] = Value
            end
        else
            TweenService:Create(Object, Motion, Properties):Play()
        end
    end

    local function Make(Class, Parent, Props)
        local Object = Instance.new(Class)
        for Key, Value in pairs(Props) do
            Object[Key] = Value
        end
        Object.Parent = Parent
        return Object
    end

    local function Round(Object, Radius)
        Make("UICorner", Object, { CornerRadius = UDim.new(0, Radius or 8) })
        Make("UIStroke", Object, {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Color3.fromRGB(88, 98, 119),
            Transparency = Object == Window and 0.3 or 0.63,
        })
    end

    local function Label(Parent, Value, X, Y, W, H, Size, Color)
        return Make("TextLabel", Parent, {
            Position = UDim2.fromOffset(X, Y),
            Size = UDim2.fromOffset(W, H),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = Value,
            TextSize = Size or 13,
            TextColor3 = Color or Text,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local function Button(Parent, Value, X, Y, W, H, Callback)
        local Object = Make("TextButton", Parent, {
            Position = UDim2.fromOffset(X, Y),
            Size = UDim2.fromOffset(W, H),
            BackgroundColor3 = Surface,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            Text = Value,
            TextSize = 13,
            TextColor3 = Text,
        })
        Round(Object)
        local Scale = Make("UIScale", Object, {})
        Object.InputBegan:Connect(function(Input)
            if
                Input.UserInputType == Enum.UserInputType.Touch
                or Input.UserInputType == Enum.UserInputType.MouseButton1
            then
                Animate(Scale, { Scale = Config.ReduceMotion and 1 or 0.96 })
            end
        end)
        Object.InputEnded:Connect(function()
            Animate(Scale, { Scale = 1 })
        end)
        Object.MouseLeave:Connect(function()
            Animate(Scale, { Scale = 1 })
        end)
        Object.Activated:Connect(Callback)
        return Object
    end

    local function Fit(X, Y, Object)
        local Size = Gui.AbsoluteSize
        local Panel = (Object or Window).AbsoluteSize
        return math.clamp(X, 0, math.max(0, Size.X - Panel.X)), math.clamp(Y, 0, math.max(0, Size.Y - Panel.Y))
    end

    local function SwitchPage(Name)
        if ActivePage == Name then
            return
        end
        ActivePage = Name
        for Key, Page in pairs(Pages) do
            Page.Visible = Key == Name
            Animate(Tabs[Key], { BackgroundColor3 = Key == Name and Surface:Lerp(Accent, 0.22) or Surface })
        end
        local Page = Pages[Name]
        Page.GroupTransparency = 0.3
        Animate(Page, { GroupTransparency = 0 })
    end

    function BuildGui()
        if not Config.ShowGui then
            return
        end
        Gui = Make("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"), {
            Name = "99Ranker",
            ResetOnSpawn = false,
            DisplayOrder = 100,
        })
        Accent = Accents[State.Persist.AccentIndex or 1][2]
        Window = Make("CanvasGroup", Gui, {
            Name = "Window",
            Size = UDim2.fromOffset(Width, Height),
            BackgroundColor3 = Background,
            GroupTransparency = 1,
        })
        Round(Window, 13)
        local WindowScale = Make("UIScale", Window, {})
        local function FitWindow()
            local Size = Gui.AbsoluteSize
            WindowScale.Scale = math.clamp(math.min((Size.X - 8) / Width, (Size.Y - 8) / Height), 0.25, 1)
            local Position = State.Persist.PanelPosition or { x = Size.X * 0.028, y = Size.Y * 0.11 }
            local X, Y = Fit(Position.x, Position.y)
            Window.Position = UDim2.fromOffset(X, Y)
        end
        Track(Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitWindow))
        FitWindow()
        Defer(function()
            if State.Alive then
                FitWindow()
            end
        end)
        Animate(Window, { GroupTransparency = 0 })

        local Header = Make("Frame", Window, {
            Active = true,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(Width, 40),
        })
        Label(Header, "99 Ranker", 14, 0, 192, 40, 19)
        local Minimized
        local MiniDragged = false
        local function SetMinimized(Value)
            Window.Visible = not Value
            Minimized.Visible = Value
            if Value then
                local Position = State.Persist.ButtonPosition
                    or { x = Window.Position.X.Offset, y = Window.Position.Y.Offset }
                local X, Y = Fit(Position.x, Position.y, Minimized)
                Minimized.Position = UDim2.fromOffset(X, Y)
            else
                Window.GroupTransparency = 0.25
                Animate(Window, { GroupTransparency = 0 })
            end
        end
        Button(Header, "-", 214, 6, 32, 29, function()
            SetMinimized(true)
        end).Name = "Minimize"
        Button(Header, "X", 252, 6, 34, 29, Stop).Name = "Unload"
        Minimized = Button(Gui, "99 Ranker", 0, 0, 106, 42, function()
            if not MiniDragged then
                SetMinimized(false)
            end
        end)
        Minimized.Name = "MinimizedButton"
        Minimized.Visible = false
        for Index, Spec in ipairs(TabSpecs) do
            local Name, Icon = table.unpack(Spec)
            local Tab = Button(Window, "", 12 + (Index - 1) * 70, 43, 66, 31, function()
                SwitchPage(Name)
            end)
            Tab.Name = Name .. "Tab"
            Make("ImageLabel", Tab, {
                Name = "Icon",
                Position = UDim2.fromOffset(5, 7),
                Size = UDim2.fromOffset(17, 17),
                BackgroundTransparency = 1,
                Image = Icon,
                ScaleType = Enum.ScaleType.Fit,
            })
            Label(Tab, Name, 25, 0, 41, 31, 10)
            Tabs[Name] = Tab
        end

        local Pointer, Origin, Base, DraggedObject
        local function BeginDrag(Input, Object)
            local Kind = Input.UserInputType
            if Pointer or (Kind ~= Enum.UserInputType.Touch and Kind ~= Enum.UserInputType.MouseButton1) then
                return
            end
            Pointer, Origin, Base, DraggedObject = Input, Input.Position, Object.Position, Object
            if Object == Minimized then
                MiniDragged = false
            end
        end
        Header.InputBegan:Connect(function(Input)
            if Input.Position.X - Window.AbsolutePosition.X <= 207 * WindowScale.Scale then
                BeginDrag(Input, Window)
            end
        end)
        Minimized.InputBegan:Connect(function(Input)
            BeginDrag(Input, Minimized)
        end)
        Track(UserInputService.InputChanged:Connect(function(Input)
            if not Pointer then
                return
            end
            local Matches = Pointer.UserInputType == Enum.UserInputType.Touch and Input == Pointer
                or Pointer.UserInputType == Enum.UserInputType.MouseButton1
                    and Input.UserInputType == Enum.UserInputType.MouseMovement
            if Matches then
                local Delta = Input.Position - Origin
                if DraggedObject == Minimized then
                    MiniDragged = MiniDragged or Delta.Magnitude >= 6
                    if not MiniDragged then
                        return
                    end
                end
                local X, Y = Fit(Base.X.Offset + Delta.X, Base.Y.Offset + Delta.Y, DraggedObject)
                DraggedObject.Position = UDim2.fromOffset(X, Y)
            end
        end))
        Track(UserInputService.InputEnded:Connect(function(Input)
            if Input == Pointer then
                local Key = DraggedObject == Minimized and "ButtonPosition" or "PanelPosition"
                State.Persist[Key] = { x = DraggedObject.Position.X.Offset, y = DraggedObject.Position.Y.Offset }
                Pointer, DraggedObject = nil, nil
                WriteStateFile()
            end
        end))
        Track(Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if Minimized.Visible then
                local X, Y = Fit(Minimized.Position.X.Offset, Minimized.Position.Y.Offset, Minimized)
                Minimized.Position = UDim2.fromOffset(X, Y)
            end
        end))
        Track(UserInputService.InputBegan:Connect(function(Input, Processed)
            if not Processed and Input.KeyCode == Config.GuiToggleKey then
                Gui.Enabled = not Gui.Enabled
            end
        end))

        Body = Make("CanvasGroup", Window, {
            Position = UDim2.fromOffset(0, 82),
            Size = UDim2.fromOffset(Width, Height - 82),
            BackgroundTransparency = 1,
        })
        local Card = Make("Frame", Body, {
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.fromOffset(276, 60),
            BackgroundColor3 = Surface,
        })
        Round(Card)
        Rank = Label(Card, "Loading rank", 12, 4, 252, 23, 16)
        Stars = Label(Card, "", 12, 28, 252, 16, 12, Muted)
        local Bar = Make("Frame", Card, {
            Position = UDim2.fromOffset(12, 48),
            Size = UDim2.fromOffset(252, 5),
            BackgroundColor3 = Background,
        })
        Round(Bar)
        Fill = Make("Frame", Bar, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Accent })
        Round(Fill)
        Label(Body, "Rank quests", 14, 63, 272, 19, 12, Muted)
        for Index = 1, 4 do
            local Row = Make("Frame", Body, {
                Position = UDim2.fromOffset(12, 85 + (Index - 1) * 39),
                Size = UDim2.fromOffset(276, 35),
                BackgroundColor3 = Surface,
            })
            Round(Row)
            local Name = Label(Row, "", 10, 2, 256, 19, 12)
            Name.TextTruncate = Enum.TextTruncate.AtEnd
            Rows[Index] = { Frame = Row, Name = Name, Progress = Label(Row, "", 10, 20, 256, 15, 11, Muted) }
        end
        Status = Label(Body, "", 14, 242, 272, 39, 11, Muted)
        Status.TextWrapped = true
        Start = Button(Body, "Start", 12, 289, 276, 36, function()
            SetEnabled(not State.Enabled)
            RefreshGui()
        end)

        Body.Name = "RankPage"
        local Home = Make("CanvasGroup", Window, {
            Name = "HomePage",
            Position = UDim2.fromOffset(0, 82),
            Size = UDim2.fromOffset(Width, Height - 82),
            BackgroundTransparency = 1,
        })
        Pages.Home = Home
        local Summary = Make("Frame", Home, {
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.fromOffset(276, 113),
            BackgroundColor3 = Surface,
        })
        Round(Summary)
        local Executor = "Unknown"
        if type(identifyexecutor) == "function" then
            local Success, Name, Version = pcall(identifyexecutor)
            if Success and type(Name) == "string" and Name ~= "" then
                Executor = Name .. (type(Version) == "string" and Version ~= "" and " " .. Version or "")
            end
        end
        local Avatar = Make("ImageLabel", Summary, {
            Name = "Avatar",
            Position = UDim2.fromOffset(12, 13),
            Size = UDim2.fromOffset(56, 56),
            BackgroundColor3 = Background,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150",
            ScaleType = Enum.ScaleType.Crop,
        })
        Round(Avatar, 14)
        local PlayerName = Label(Summary, "@" .. LocalPlayer.Name, 80, 9, 184, 23, 14)
        PlayerName.Name = "LocalPlayer"
        PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
        Label(Summary, "ID " .. tostring(LocalPlayer.UserId), 80, 34, 184, 19, 12, Muted).Name = "UserId"
        local ExecutorLabel = Label(Summary, Executor, 80, 54, 184, 19, 12, Muted)
        ExecutorLabel.Name = "Executor"
        ExecutorLabel.TextTruncate = Enum.TextTruncate.AtEnd
        HomeElapsed = Label(Summary, "Elapsed 00:00:00", 12, 80, 252, 22, 12, Muted)
        HomeElapsed.Name = "Elapsed"
        HomeActivity = Label(Home, "", 14, 118, 272, 46, 12, Text)
        HomeActivity.TextWrapped = true
        HomeStats = Make("Frame", Home, {
            Position = UDim2.fromOffset(12, 170),
            Size = UDim2.fromOffset(276, 107),
            BackgroundColor3 = Surface,
        })
        Round(HomeStats)
        Label(HomeStats, "Activity totals", 12, 3, 252, 24, 12, Muted)
        Label(HomeStats, "", 12, 25, 252, 25, 13).Name = "Hatched"
        Label(HomeStats, "", 12, 50, 252, 25, 13).Name = "Crafted"
        Label(HomeStats, "", 12, 75, 252, 25, 13).Name = "Claimed"
        HomeStart = Button(Home, "Start", 12, 289, 276, 36, function()
            SetEnabled(not State.Enabled)
            RefreshGui()
        end)

        Pages.Rank = Body
        for _, Name in ipairs({ "Eggs", "Settings" }) do
            local Page = Make("CanvasGroup", Window, {
                Position = UDim2.fromOffset(0, 82),
                Size = UDim2.fromOffset(Width, Height - 82),
                BackgroundTransparency = 1,
                Visible = false,
            })
            Page.Name = Name .. "Page"
            Pages[Name] = Page
            local Caption = type(writefile) == "function" and "Settings save automatically."
                or "Settings apply for this session."
            Label(Page, Caption, 14, 0, 272, 26, 12, Muted)
            local Scroll = Make("ScrollingFrame", Page, {
                Position = UDim2.fromOffset(12, 32),
                Size = UDim2.fromOffset(276, 293),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 4,
            })
            Make("UIListLayout", Scroll, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
            if Name == "Settings" then
                local Cycle
                Cycle = Button(Scroll, "", 0, 0, 268, 37, function()
                    local Index = (State.Persist.AccentIndex or 1) % #Accents + 1
                    State.Persist.AccentIndex = Index
                    Accent = Accents[Index][2]
                    Cycle.Text = "Accent: " .. Accents[Index][1]
                    for _, Paint in pairs(Switches) do
                        Paint()
                    end
                    Animate(Tabs[ActivePage], { BackgroundColor3 = Surface:Lerp(Accent, 0.22) })
                    Animate(Fill, { BackgroundColor3 = Accent })
                    LastEnabled = nil
                    RefreshGui()
                    WriteStateFile()
                end)
                Cycle.LayoutOrder = 0
                Cycle.Text = "Accent: " .. Accents[State.Persist.AccentIndex or 1][1]
            end
            local PreviousSection
            for Index, Entry in ipairs(SavedOptions) do
                local Key, Option, Section = table.unpack(Entry)
                local IsEggSection = Section == "Hatching" or Section == "Crafting"
                if IsEggSection == (Name == "Eggs") then
                    if PreviousSection ~= Section then
                        PreviousSection = Section
                        Label(Scroll, Section, 0, 0, 260, 23, 11, Muted).LayoutOrder = Index * 2 - 1
                    end
                    local Control = Button(Scroll, "", 0, 0, 268, 37, function()
                        Config[Key] = not Config[Key]
                        Switches[Key]()
                        RefreshGui()
                        WriteStateFile()
                    end)
                    Control.LayoutOrder = Index * 2
                    Control.Name = Key .. "Toggle"
                    Label(Control, Option, 11, 0, 201, 37, 13)
                    local Track = Make("Frame", Control, {
                        Name = "SwitchTrack",
                        Position = UDim2.fromOffset(222, 9),
                        Size = UDim2.fromOffset(35, 19),
                    })
                    Round(Track, 10)
                    local Knob = Make("Frame", Track, {
                        Name = "Knob",
                        Size = UDim2.fromOffset(13, 13),
                        BackgroundColor3 = Text,
                    })
                    Round(Knob, 7)
                    Switches[Key] = function()
                        local On = Config[Key]
                        Control:SetAttribute("On", On)
                        Animate(Track, { BackgroundColor3 = On and Accent or Color3.fromRGB(69, 73, 85) })
                        Animate(Knob, {
                            Position = UDim2.fromOffset(On and 19 or 3, 3),
                            BackgroundColor3 = On and Background or Text,
                        })
                    end
                    Switches[Key]()
                end
            end
        end
        SwitchPage("Home")
        RefreshGui()
    end

    function RefreshGui()
        if not Window or not Window.Parent then
            return
        end
        local Info = State.Rank
        if Info then
            Rank.Text = string.format("Rank %s  |  %s", Int(Info.rankNumber), tostring(Info.title))
            Stars.Text = string.format("%s / %s stars", Int(Info.stars), Int(Info.totalStars))
            local Progress = math.clamp(Info.stars / math.max(1, Info.totalStars), 0, 1)
            if LastProgress ~= Progress then
                LastProgress = Progress
                Animate(Fill, { Size = UDim2.fromScale(Progress, 1) })
            end
        end
        for Index, Row in ipairs(Rows) do
            local Goal = State.Goals[Index]
            Row.Frame.Visible = Goal ~= nil
            if Goal then
                Row.Name.Text = tostring(Goal.title)
                Row.Progress.Text = string.format(
                    "+%s stars  |  %s / %s%s",
                    Int(Goal.Stars),
                    Int(Goal.Progress),
                    Int(Goal.Amount),
                    Goal.supported and "" or "  |  Manual"
                )
            end
        end
        local Activity = "Paused"
        if State.Enabled then
            if State.WorldSwitching then
                Activity = "Switching worlds"
            elseif State.WorldMismatch then
                Activity = "Waiting for the right world"
            elseif Info and Info.isMax then
                Activity = "Max rank reached"
            elseif Info and Info.blockedByRebirth then
                Activity = "Rebirth required"
            elseif State.Hopping then
                Activity = "Moving to egg"
            elseif State.Plan.Hatch and CanHatchEgg(Cache.Egg) then
                Activity = State.HatchSession and "Hatching eggs" or "Preparing next hatch"
            elseif State.Plan.Hatch then
                Activity = Config.AutoFarm and "Farming | Unlocking best egg" or "Unlocking best egg"
            elseif State.Plan.Crafting then
                Activity = "Crafting pets"
            elseif State.Plan.WaitingChest then
                Activity = "Waiting for chests"
            elseif Config.AutoFarm then
                Activity = "Farming " .. tostring(BestZoneName() or "best area")
            else
                Activity = "Waiting for a quest"
            end
        end
        Status.Text = Activity
        HomeActivity.Text = Activity
        local Elapsed = math.floor(os.clock() - State.StartedAt)
        HomeElapsed.Text = string.format(
            "Elapsed %02d:%02d:%02d",
            math.floor(Elapsed / 3600),
            math.floor(Elapsed / 60) % 60,
            Elapsed % 60
        )
        HomeStats.Visible = Config.ShowOverviewStats
        HomeStats.Hatched.Text = "Eggs hatched: " .. Int(State.Counters.Hatched)
        HomeStats.Crafted.Text = "Pets crafted: " .. Int(State.Counters.Crafted)
        HomeStats.Claimed.Text = "Rewards claimed: " .. Int(State.Counters.Claimed)
        if LastEnabled ~= State.Enabled then
            LastEnabled = State.Enabled
            for _, Control in ipairs({ Start, HomeStart }) do
                Control.Text = State.Enabled and "Pause" or "Start"
                Control.TextColor3 = State.Enabled and Background or Text
                Animate(Control, { BackgroundColor3 = State.Enabled and Accent or Surface })
            end
        end
        if RefreshKizHubDashboard then
            RefreshKizHubDashboard()
        end
    end
end
ConfigureGui()

local KizHubGui = nil
local KizHubUI = {}

local function setBlackout(visible)
    State.BlackoutVisible = visible
    if KizHubUI.Blackout then
        KizHubUI.Blackout.Visible = visible
    end
    if Config.Disable3DRendering then
        pcall(function()
            RunService:Set3dRenderingEnabled(not visible)
        end)
    end
end

local function BuildKizHubBlackoutGui()
    if KizHubGui then
        pcall(function() KizHubGui:Destroy() end)
        KizHubGui = nil
    end

    local parentGui = nil
    pcall(function()
        if type(gethui) == "function" then
            parentGui = gethui()
        elseif CoreGui then
            parentGui = CoreGui
        end
    end)
    if not parentGui then
        parentGui = LocalPlayer:WaitForChild("PlayerGui")
    end

    KizHubGui = Instance.new("ScreenGui")
    KizHubGui.Name = "KizHub_Blackout_Dashboard"
    KizHubGui.ResetOnSpawn = false
    KizHubGui.DisplayOrder = 999999
    KizHubGui.IgnoreGuiInset = true
    KizHubGui.Parent = parentGui

    -- 1. Fullscreen Blackout Frame (AMOLED Dark)
    local Blackout = Instance.new("Frame")
    Blackout.Name = "BlackoutFrame"
    Blackout.Size = UDim2.new(1, 0, 1, 0)
    Blackout.Position = UDim2.new(0, 0, 0, 0)
    Blackout.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
    Blackout.BorderSizePixel = 0
    Blackout.Active = true
    Blackout.Visible = Config.BlackoutGui ~= false
    Blackout.Parent = KizHubGui
    KizHubUI.Blackout = Blackout

    -- 2. Center Dashboard Panel
    local Panel = Instance.new("Frame")
    Panel.Name = "DashboardPanel"
    Panel.AnchorPoint = Vector2.new(0.5, 0.5)
    Panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    Panel.Size = UDim2.fromOffset(560, 680)
    Panel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Panel.BorderSizePixel = 0
    Panel.Parent = Blackout

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 14)
    pCorner.Parent = Panel

    local pStroke = Instance.new("UIStroke")
    pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pStroke.Color = Color3.fromRGB(0, 229, 190)
    pStroke.Transparency = 0.2
    pStroke.Thickness = 1.5
    pStroke.Parent = Panel

    local pScale = Instance.new("UIScale")
    pScale.Parent = Panel
    local function FitPanel()
        local vp = Blackout.AbsoluteSize
        local scale = math.clamp(math.min((vp.X - 24) / 560, (vp.Y - 24) / 680), 0.35, 1.1)
        pScale.Scale = scale
    end
    Track(Blackout:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitPanel))
    task.defer(FitPanel)

    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, -32, 0, 50)
    Header.Position = UDim2.new(0, 16, 0, 14)
    Header.BackgroundTransparency = 1
    Header.Parent = Panel

    local Title = Instance.new("TextLabel")
    Title.Text = "KIZHUB"
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 22
    Title.TextColor3 = Color3.fromRGB(0, 229, 190)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.Size = UDim2.new(0, 110, 0, 26)
    Title.BackgroundTransparency = 1
    Title.Parent = Header

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Text = "PET SIMULATOR 99 • AUTORANK KAITUN (WORLD 1 ➔ RANK 11)"
    SubTitle.Font = Enum.Font.GothamMedium
    SubTitle.TextSize = 10
    SubTitle.TextColor3 = Color3.fromRGB(140, 150, 175)
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Position = UDim2.new(0, 0, 0, 26)
    SubTitle.Size = UDim2.new(0, 360, 0, 16)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Parent = Header

    local StatusBadge = Instance.new("Frame")
    StatusBadge.Name = "StatusBadge"
    StatusBadge.AnchorPoint = Vector2.new(1, 0)
    StatusBadge.Position = UDim2.new(1, 0, 0, 8)
    StatusBadge.Size = UDim2.fromOffset(125, 28)
    StatusBadge.BackgroundColor3 = Color3.fromRGB(10, 40, 30)
    StatusBadge.BorderSizePixel = 0
    StatusBadge.Parent = Header

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 6)
    sbCorner.Parent = StatusBadge

    local sbStroke = Instance.new("UIStroke")
    sbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    sbStroke.Color = Color3.fromRGB(0, 229, 190)
    sbStroke.Thickness = 1
    sbStroke.Parent = StatusBadge

    local StatusText = Instance.new("TextLabel")
    StatusText.Text = "● RUNNING"
    StatusText.Font = Enum.Font.GothamBold
    StatusText.TextSize = 11
    StatusText.TextColor3 = Color3.fromRGB(0, 255, 170)
    StatusText.Size = UDim2.new(1, 0, 1, 0)
    StatusText.BackgroundTransparency = 1
    StatusText.Parent = StatusBadge
    KizHubUI.StatusText = StatusText

    -- Quick Toggle 3D Button (Top right mini)
    local Toggle3D = Instance.new("TextButton")
    Toggle3D.Name = "Toggle3D"
    Toggle3D.AnchorPoint = Vector2.new(1, 0)
    Toggle3D.Position = UDim2.new(1, -135, 0, 8)
    Toggle3D.Size = UDim2.fromOffset(80, 28)
    Toggle3D.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
    Toggle3D.Font = Enum.Font.GothamMedium
    Toggle3D.Text = "👁️ 3D Game"
    Toggle3D.TextSize = 11
    Toggle3D.TextColor3 = Color3.fromRGB(220, 225, 240)
    Toggle3D.Parent = Header
    local t3dCorner = Instance.new("UICorner")
    t3dCorner.CornerRadius = UDim.new(0, 6)
    t3dCorner.Parent = Toggle3D
    Toggle3D.Activated:Connect(function()
        setBlackout(not Blackout.Visible)
    end)

    -- Account Row
    local AccountBar = Instance.new("Frame")
    AccountBar.Size = UDim2.new(1, -32, 0, 32)
    AccountBar.Position = UDim2.new(0, 16, 0, 72)
    AccountBar.BackgroundColor3 = Color3.fromRGB(22, 23, 30)
    AccountBar.BorderSizePixel = 0
    AccountBar.Parent = Panel
    local abCorner = Instance.new("UICorner")
    abCorner.CornerRadius = UDim.new(0, 6)
    abCorner.Parent = AccountBar

    local AccountLabel = Instance.new("TextLabel")
    AccountLabel.Text = "👤 " .. tostring(LocalPlayer.Name)
    AccountLabel.Font = Enum.Font.GothamSemibold
    AccountLabel.TextSize = 12
    AccountLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    AccountLabel.Position = UDim2.new(0, 12, 0, 0)
    AccountLabel.Size = UDim2.new(0.5, -12, 1, 0)
    AccountLabel.TextXAlignment = Enum.TextXAlignment.Left
    AccountLabel.BackgroundTransparency = 1
    AccountLabel.Parent = AccountBar

    local ElapsedLabel = Instance.new("TextLabel")
    ElapsedLabel.Text = "⏱️ 00:00:00"
    ElapsedLabel.Font = Enum.Font.GothamMedium
    ElapsedLabel.TextSize = 12
    ElapsedLabel.TextColor3 = Color3.fromRGB(160, 175, 205)
    ElapsedLabel.AnchorPoint = Vector2.new(1, 0)
    ElapsedLabel.Position = UDim2.new(1, -12, 0, 0)
    ElapsedLabel.Size = UDim2.new(0.5, -12, 1, 0)
    ElapsedLabel.TextXAlignment = Enum.TextXAlignment.Right
    ElapsedLabel.BackgroundTransparency = 1
    ElapsedLabel.Parent = AccountBar
    KizHubUI.ElapsedLabel = ElapsedLabel

    -- CARD 1: RANK & STATS (rank bao nhiêu rồi, stat của rank bao nhiêu)
    local RankCard = Instance.new("Frame")
    RankCard.Name = "RankCard"
    RankCard.Size = UDim2.new(1, -32, 0, 128)
    RankCard.Position = UDim2.new(0, 16, 0, 114)
    RankCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    RankCard.BorderSizePixel = 0
    RankCard.Parent = Panel
    local rcCorner = Instance.new("UICorner")
    rcCorner.CornerRadius = UDim.new(0, 10)
    rcCorner.Parent = RankCard

    local rcTitle = Instance.new("TextLabel")
    rcTitle.Text = "🏆 TIẾN TRÌNH RANK (WORLD 1 ➔ RANK 11)"
    rcTitle.Font = Enum.Font.GothamBold
    rcTitle.TextSize = 11
    rcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    rcTitle.TextXAlignment = Enum.TextXAlignment.Left
    rcTitle.Position = UDim2.new(0, 14, 0, 10)
    rcTitle.Size = UDim2.new(1, -28, 0, 16)
    rcTitle.BackgroundTransparency = 1
    rcTitle.Parent = RankCard

    local RankValue = Instance.new("TextLabel")
    RankValue.Text = "RANK 1 • ..."
    RankValue.Font = Enum.Font.GothamBold
    RankValue.TextSize = 17
    RankValue.TextColor3 = Color3.fromRGB(255, 215, 0)
    RankValue.TextXAlignment = Enum.TextXAlignment.Left
    RankValue.Position = UDim2.new(0, 14, 0, 30)
    RankValue.Size = UDim2.new(0.65, 0, 0, 24)
    RankValue.BackgroundTransparency = 1
    RankValue.Parent = RankCard
    KizHubUI.RankValue = RankValue

    local TargetRankLabel = Instance.new("TextLabel")
    TargetRankLabel.Text = "Mục tiêu: Rank 11"
    TargetRankLabel.Font = Enum.Font.GothamMedium
    TargetRankLabel.TextSize = 12
    TargetRankLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
    TargetRankLabel.TextXAlignment = Enum.TextXAlignment.Right
    TargetRankLabel.AnchorPoint = Vector2.new(1, 0)
    TargetRankLabel.Position = UDim2.new(1, -14, 0, 30)
    TargetRankLabel.Size = UDim2.new(0.35, 0, 0, 24)
    TargetRankLabel.BackgroundTransparency = 1
    TargetRankLabel.Parent = RankCard
    KizHubUI.TargetRankLabel = TargetRankLabel

    local StarsLabel = Instance.new("TextLabel")
    StarsLabel.Text = "Stars: 0 / 0 (0%)"
    StarsLabel.Font = Enum.Font.GothamSemibold
    StarsLabel.TextSize = 12
    StarsLabel.TextColor3 = Color3.fromRGB(230, 235, 250)
    StarsLabel.TextXAlignment = Enum.TextXAlignment.Left
    StarsLabel.Position = UDim2.new(0, 14, 0, 58)
    StarsLabel.Size = UDim2.new(1, -28, 0, 18)
    StarsLabel.BackgroundTransparency = 1
    StarsLabel.Parent = RankCard
    KizHubUI.StarsLabel = StarsLabel

    -- Star Progress Bar
    local StarBarBg = Instance.new("Frame")
    StarBarBg.Size = UDim2.new(1, -28, 0, 10)
    StarBarBg.Position = UDim2.new(0, 14, 0, 78)
    StarBarBg.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
    StarBarBg.BorderSizePixel = 0
    StarBarBg.Parent = RankCard
    local sbCorner2 = Instance.new("UICorner")
    sbCorner2.CornerRadius = UDim.new(0, 5)
    sbCorner2.Parent = StarBarBg

    local StarBarFill = Instance.new("Frame")
    StarBarFill.Size = UDim2.new(0, 0, 1, 0)
    StarBarFill.BackgroundColor3 = Color3.fromRGB(0, 229, 190)
    StarBarFill.BorderSizePixel = 0
    StarBarFill.Parent = StarBarBg
    local sbfCorner = Instance.new("UICorner")
    sbfCorner.CornerRadius = UDim.new(0, 5)
    sbfCorner.Parent = StarBarFill
    KizHubUI.StarBarFill = StarBarFill

    local RankSubStats = Instance.new("TextLabel")
    RankSubStats.Text = "🎁 Quà: 0/0  |  🔄 Rebirth: 0  |  ⚡ Trạng thái: Cày sao"
    RankSubStats.Font = Enum.Font.GothamMedium
    RankSubStats.TextSize = 11
    RankSubStats.TextColor3 = Color3.fromRGB(150, 160, 185)
    RankSubStats.TextXAlignment = Enum.TextXAlignment.Left
    RankSubStats.Position = UDim2.new(0, 14, 0, 96)
    RankSubStats.Size = UDim2.new(1, -28, 0, 20)
    RankSubStats.BackgroundTransparency = 1
    RankSubStats.Parent = RankCard
    KizHubUI.RankSubStats = RankSubStats

    -- CARD 2: ZONE INFO (zone mấy)
    local ZoneCard = Instance.new("Frame")
    ZoneCard.Name = "ZoneCard"
    ZoneCard.Size = UDim2.new(1, -32, 0, 68)
    ZoneCard.Position = UDim2.new(0, 16, 0, 252)
    ZoneCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    ZoneCard.BorderSizePixel = 0
    ZoneCard.Parent = Panel
    local zcCorner = Instance.new("UICorner")
    zcCorner.CornerRadius = UDim.new(0, 10)
    zcCorner.Parent = ZoneCard

    local zcTitle = Instance.new("TextLabel")
    zcTitle.Text = "🗺️ KHU VỰC HIỆN TẠI (WORLD 1)"
    zcTitle.Font = Enum.Font.GothamBold
    zcTitle.TextSize = 11
    zcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    zcTitle.TextXAlignment = Enum.TextXAlignment.Left
    zcTitle.Position = UDim2.new(0, 14, 0, 10)
    zcTitle.Size = UDim2.new(1, -28, 0, 16)
    zcTitle.BackgroundTransparency = 1
    zcTitle.Parent = ZoneCard

    local ZoneLabel = Instance.new("TextLabel")
    ZoneLabel.Text = "Zone #1: Spawn"
    ZoneLabel.Font = Enum.Font.GothamSemibold
    ZoneLabel.TextSize = 14
    ZoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ZoneLabel.TextXAlignment = Enum.TextXAlignment.Left
    ZoneLabel.Position = UDim2.new(0, 14, 0, 28)
    ZoneLabel.Size = UDim2.new(0.65, 0, 0, 20)
    ZoneLabel.BackgroundTransparency = 1
    ZoneLabel.Parent = ZoneCard
    KizHubUI.ZoneLabel = ZoneLabel

    local ActionLabel = Instance.new("TextLabel")
    ActionLabel.Text = "Farming..."
    ActionLabel.Font = Enum.Font.GothamMedium
    ActionLabel.TextSize = 11
    ActionLabel.TextColor3 = Color3.fromRGB(150, 160, 185)
    ActionLabel.TextXAlignment = Enum.TextXAlignment.Left
    ActionLabel.Position = UDim2.new(0, 14, 0, 48)
    ActionLabel.Size = UDim2.new(1, -28, 0, 16)
    ActionLabel.BackgroundTransparency = 1
    ActionLabel.Parent = ZoneCard
    KizHubUI.ActionLabel = ActionLabel

    -- CARD 3: ACTIVE QUESTS (quest đang làm)
    local QuestCard = Instance.new("Frame")
    QuestCard.Name = "QuestCard"
    QuestCard.Size = UDim2.new(1, -32, 0, 220)
    QuestCard.Position = UDim2.new(0, 16, 0, 330)
    QuestCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    QuestCard.BorderSizePixel = 0
    QuestCard.Parent = Panel
    local qcCorner = Instance.new("UICorner")
    qcCorner.CornerRadius = UDim.new(0, 10)
    qcCorner.Parent = QuestCard

    local qcTitle = Instance.new("TextLabel")
    qcTitle.Text = "📜 NHIỆM VỤ RANK ĐANG LÀM (ACTIVE QUESTS)"
    qcTitle.Font = Enum.Font.GothamBold
    qcTitle.TextSize = 11
    qcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    qcTitle.TextXAlignment = Enum.TextXAlignment.Left
    qcTitle.Position = UDim2.new(0, 14, 0, 10)
    qcTitle.Size = UDim2.new(1, -28, 0, 16)
    qcTitle.BackgroundTransparency = 1
    qcTitle.Parent = QuestCard

    local QuestRows = {}
    for i = 1, 4 do
        local qRow = Instance.new("Frame")
        qRow.Name = "QuestRow_" .. i
        qRow.Size = UDim2.new(1, -28, 0, 42)
        qRow.Position = UDim2.new(0, 14, 0, 30 + (i - 1) * 46)
        qRow.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
        qRow.BorderSizePixel = 0
        qRow.Visible = false
        qRow.Parent = QuestCard

        local qrCorner = Instance.new("UICorner")
        qrCorner.CornerRadius = UDim.new(0, 6)
        qrCorner.Parent = qRow

        local qStars = Instance.new("TextLabel")
        qStars.Text = "[⭐ 1]"
        qStars.Font = Enum.Font.GothamBold
        qStars.TextSize = 11
        qStars.TextColor3 = Color3.fromRGB(255, 200, 50)
        qStars.Position = UDim2.new(0, 8, 0, 4)
        qStars.Size = UDim2.new(0, 42, 0, 16)
        qStars.TextXAlignment = Enum.TextXAlignment.Left
        qStars.BackgroundTransparency = 1
        qStars.Parent = qRow

        local qName = Instance.new("TextLabel")
        qName.Text = "Quest Name..."
        qName.Font = Enum.Font.GothamSemibold
        qName.TextSize = 12
        qName.TextColor3 = Color3.fromRGB(240, 245, 255)
        qName.Position = UDim2.new(0, 52, 0, 4)
        qName.Size = UDim2.new(1, -165, 0, 16)
        qName.TextXAlignment = Enum.TextXAlignment.Left
        qName.TextTruncate = Enum.TextTruncate.AtEnd
        qName.BackgroundTransparency = 1
        qName.Parent = qRow

        local qProgText = Instance.new("TextLabel")
        qProgText.Text = "0 / 0"
        qProgText.Font = Enum.Font.GothamMedium
        qProgText.TextSize = 11
        qProgText.TextColor3 = Color3.fromRGB(0, 229, 190)
        qProgText.AnchorPoint = Vector2.new(1, 0)
        qProgText.Position = UDim2.new(1, -8, 0, 4)
        qProgText.Size = UDim2.new(0, 110, 0, 16)
        qProgText.TextXAlignment = Enum.TextXAlignment.Right
        qProgText.BackgroundTransparency = 1
        qProgText.Parent = qRow

        local qBarBg = Instance.new("Frame")
        qBarBg.Size = UDim2.new(1, -16, 0, 6)
        qBarBg.Position = UDim2.new(0, 8, 0, 26)
        qBarBg.BackgroundColor3 = Color3.fromRGB(40, 43, 55)
        qBarBg.BorderSizePixel = 0
        qBarBg.Parent = qRow
        local qbCorner = Instance.new("UICorner")
        qbCorner.CornerRadius = UDim.new(0, 3)
        qbCorner.Parent = qBarBg

        local qBarFill = Instance.new("Frame")
        qBarFill.Size = UDim2.new(0, 0, 1, 0)
        qBarFill.BackgroundColor3 = Color3.fromRGB(0, 229, 190)
        qBarFill.BorderSizePixel = 0
        qBarFill.Parent = qBarBg
        local qbfCorner = Instance.new("UICorner")
        qbfCorner.CornerRadius = UDim.new(0, 3)
        qbfCorner.Parent = qBarFill

        table.insert(QuestRows, {
            Frame = qRow,
            Stars = qStars,
            Name = qName,
            ProgressText = qProgText,
            BarFill = qBarFill
        })
    end
    KizHubUI.QuestRows = QuestRows

    -- CARD 4: ACTIVITY TOTALS & FOOTER
    local FooterBar = Instance.new("Frame")
    FooterBar.Size = UDim2.new(1, -32, 0, 64)
    FooterBar.Position = UDim2.new(0, 16, 0, 560)
    FooterBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    FooterBar.BorderSizePixel = 0
    FooterBar.Parent = Panel
    local fbCorner = Instance.new("UICorner")
    fbCorner.CornerRadius = UDim.new(0, 10)
    fbCorner.Parent = FooterBar

    local TotalsLabel = Instance.new("TextLabel")
    TotalsLabel.Text = "🥚 Trứng: 0  |  🐾 Craft: 0  |  🎁 Nhận quà: 0"
    TotalsLabel.Font = Enum.Font.GothamSemibold
    TotalsLabel.TextSize = 12
    TotalsLabel.TextColor3 = Color3.fromRGB(220, 230, 250)
    TotalsLabel.Position = UDim2.new(0, 14, 0, 10)
    TotalsLabel.Size = UDim2.new(1, -28, 0, 20)
    TotalsLabel.TextXAlignment = Enum.TextXAlignment.Center
    TotalsLabel.BackgroundTransparency = 1
    TotalsLabel.Parent = FooterBar
    KizHubUI.TotalsLabel = TotalsLabel

    local HintLabel = Instance.new("TextLabel")
    HintLabel.Text = "💡 Phím tắt: [Right Control] để Bật/Tắt màn hình đen & 3D Render"
    HintLabel.Font = Enum.Font.GothamMedium
    HintLabel.TextSize = 10
    HintLabel.TextColor3 = Color3.fromRGB(120, 130, 150)
    HintLabel.Position = UDim2.new(0, 14, 0, 34)
    HintLabel.Size = UDim2.new(1, -28, 0, 18)
    HintLabel.TextXAlignment = Enum.TextXAlignment.Center
    HintLabel.BackgroundTransparency = 1
    HintLabel.Parent = FooterBar

    -- Keybind toggle handler
    Track(UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == (Config.GuiToggleKey or Enum.KeyCode.RightControl) then
            setBlackout(not Blackout.Visible)
        end
    end))

    -- Set initial 3D rendering state
    if Config.Disable3DRendering and Blackout.Visible then
        pcall(function() RunService:Set3dRenderingEnabled(false) end)
    end
end

local function RefreshKizHubDashboard()
    if not (KizHubGui and KizHubUI.Blackout) then return end

    -- 1. Elapsed Time
    local elapsed = math.floor(os.clock() - State.StartedAt)
    if KizHubUI.ElapsedLabel then
        KizHubUI.ElapsedLabel.Text = string.format("⏱️ %02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
    end

    -- 2. Rank & Stats
    local info = State.Rank
    if info then
        local rNum = info.rankNumber or 1
        local rTitle = tostring(info.title or ("Rank " .. rNum))
        local stars = tonumber(info.stars) or 0
        local totalStars = math.max(1, tonumber(info.totalStars) or 1)
        local starPct = math.clamp((stars / totalStars) * 100, 0, 100)

        if KizHubUI.RankValue then
            KizHubUI.RankValue.Text = string.format("RANK %d • %s", rNum, rTitle:upper())
        end

        local targetRank = Config.TargetRank or 11
        if KizHubUI.TargetRankLabel then
            if rNum >= targetRank then
                KizHubUI.TargetRankLabel.Text = "👑 ĐÃ ĐẠT RANK 11!"
                KizHubUI.TargetRankLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
                if KizHubUI.StatusText then
                    KizHubUI.StatusText.Text = "👑 COMPLETED"
                    KizHubUI.StatusText.TextColor3 = Color3.fromRGB(255, 215, 0)
                end
            else
                KizHubUI.TargetRankLabel.Text = string.format("Mục tiêu: Rank %d (%d/%d)", targetRank, rNum, targetRank)
                KizHubUI.TargetRankLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
            end
        end

        if KizHubUI.StarsLabel then
            KizHubUI.StarsLabel.Text = string.format("⭐ Sao: %s / %s (%.1f%%)", Int(stars), Int(totalStars), starPct)
        end

        if KizHubUI.StarBarFill then
            KizHubUI.StarBarFill.Size = UDim2.fromScale(math.clamp(stars / totalStars, 0, 1), 1)
        end

        if KizHubUI.RankSubStats then
            local redeemed = info.redeemedCount or 0
            local totalRewards = (info.rewards and #info.rewards) or 0
            local rebirths = info.rebirths or 0
            local statusDesc = (rNum >= targetRank and "Hoàn thành mục tiêu Rank 11!") or (info.isMax and "Max Rank") or (info.blockedByRebirth and "Cần Rebirth") or "Đang cày sao..."
            KizHubUI.RankSubStats.Text = string.format("🎁 Quà: %d/%d  |  🔄 Rebirth: %d  |  ⚡ %s", redeemed, totalRewards, rebirths, statusDesc)
        end
    end

    -- 3. Zone Info
    local bestZName = BestZoneName() or "?"
    if KizHubUI.ZoneLabel then
        KizHubUI.ZoneLabel.Text = string.format("Zone: %s (World 1)", tostring(bestZName))
    end
    if KizHubUI.ActionLabel then
        KizHubUI.ActionLabel.Text = string.format("Hành động: %s", tostring(State.Action or "Farming"))
    end

    -- 4. Active Quests
    local goals = State.Goals or {}
    for i = 1, 4 do
        local r = KizHubUI.QuestRows and KizHubUI.QuestRows[i]
        if r then
            local g = goals[i]
            if g then
                r.Frame.Visible = true
                r.Stars.Text = string.format("[⭐ %s]", Int(g.Stars or 1))
                r.Name.Text = tostring(g.title or "Quest")
                local prog = tonumber(g.Progress) or 0
                local amt = math.max(1, tonumber(g.Amount) or 1)
                local pct = math.clamp((prog / amt) * 100, 0, 100)
                r.ProgressText.Text = string.format("%s / %s (%.0f%%)", Int(prog), Int(amt), pct)
                r.BarFill.Size = UDim2.fromScale(math.clamp(prog / amt, 0, 1), 1)
            else
                r.Frame.Visible = false
            end
        end
    end

    -- 5. Totals
    if KizHubUI.TotalsLabel then
        KizHubUI.TotalsLabel.Text = string.format(
            "🥚 Trứng: %s  |  🐾 Ghép thú: %s  |  🎁 Nhận quà: %s",
            Int(State.Counters.Hatched or 0),
            Int(State.Counters.Crafted or 0),
            Int(State.Counters.Claimed or 0)
        )
    end
end

local function SpawnLoop(name, tickFn, intervalFn)
    Defer(function()
        while State.Alive do
            local ok, err = pcall(tickFn)
            if not ok then
                WarnLog("loop-" .. name, "%s loop error: %s", name, tostring(err))
                task.wait(1)
            end
            if not State.Alive then
                break
            end
            local okI, iv = pcall(intervalFn)
            iv = okI and tonumber(iv) or 1
            task.wait(math.max(0.05, iv))
        end
    end)
end

local function FarmInterval()
    if not Config.AutoFarm or not State.Enabled or State.WorldSwitching or State.WorldMismatch then
        return 1
    end
    return Config.FarmTick
end

local function HatchInterval()
    local now = os.clock()
    if HatchBackoffUntil > now then
        return math.min(5, HatchBackoffUntil - now)
    end
    if not HatchPlanned() or State.WorldSwitching or State.WorldMismatch then
        return 1
    end
    return Config.HatchDelay
end

local function StartThreads()
    SpawnLoop("controller", ControllerTick, function()
        return Config.ControllerTick
    end)
    SpawnLoop("farm", FarmTick, FarmInterval)
    SpawnLoop("hatch", HatchTick, HatchInterval)
    SpawnLoop("egg reveal", AutoTapEgg, function()
        return 0.12
    end)
    SpawnLoop("craft", CraftTick, function()
        return Config.CraftTick
    end)
    SpawnLoop("events", EventTick, function()
        return Config.EventTick
    end)
    SpawnLoop("starter pets", autoPickStarterPets, function()
        return State.StarterPetsPicked and 9999 or 5
    end)
    SpawnLoop("open slots", autoOpenSlots, function()
        return 15
    end)
    SpawnLoop("free gifts", checkAndClaimFreeGifts, function()
        return 60
    end)
    SpawnLoop("gui", RefreshGui, function()
        return 0.5
    end)
    SpawnLoop("persist", WriteStateFile, function()
        return 60
    end)
    InstallBreakableListener()
end

local function Bootstrap()
    repeat
        task.wait()
    until game:IsLoaded() or not State.Alive
    if not State.Alive then
        return false
    end
    local t0 = os.clock()
    while State.Alive and not Players.LocalPlayer do
        if os.clock() - t0 > 60 then
            warn(TAG .. "LocalPlayer not available after 60 s - aborting")
            return false
        end
        task.wait(0.5)
    end
    if not State.Alive then
        return false
    end
    LocalPlayer = Players.LocalPlayer
    t0 = os.clock()
    while State.Alive do
        local lib = RS:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            break
        end
        if os.clock() - t0 > 60 then
            warn(TAG .. "ReplicatedStorage.Library.Client not found after 60 s - aborting")
            return false
        end
        LogEvery("boot-lib", 5, "Waiting for ReplicatedStorage.Library.Client...")
        task.wait(0.5)
    end
    if not State.Alive then
        return false
    end
    LoadModules()
    if not (G.Save and G.Network) then
        warn(TAG .. "Save/Network module unavailable - cannot continue")
        return false
    end
    t0 = os.clock()
    while State.Alive and GetSave() == nil do
        if os.clock() - t0 > 60 then
            warn(TAG .. "Save.Get() stayed nil for 60 s - aborting")
            return false
        end
        LogEvery("boot-save", 5, "Waiting for save data...")
        task.wait(0.5)
    end
    t0 = os.clock()
    while State.Alive and os.clock() - t0 < 5 do
        local ok, loaded = pcall(function()
            return LocalPlayer:GetAttribute("__LOADED")
        end)
        if ok and loaded then
            break
        end
        task.wait(0.25)
    end
    return State.Alive
end

local function StartupSummary()
    local info = State.Rank
    if info then
        Log(
            "Rank %s - %s | %s/%s stars | rewards %s/%s | rebirths %s",
            Int(info.rankNumber),
            tostring(info.title),
            Int(info.stars),
            Int(info.totalStars),
            Int(info.redeemedCount),
            Int(#info.rewards),
            Int(info.rebirths)
        )
    end
    for _, g in ipairs(State.Goals) do
        Log(
            "  goal [%s*] %s  %s/%s (type %s)%s",
            Int(g.Stars),
            tostring(g.title),
            Int(g.Progress),
            Int(g.Amount),
            tostring(g.Type),
            g.supported and "" or " (manual)"
        )
    end
    local zone = BestZone()
    local egg = BestEgg()
    Log(
        "Best zone: %s (world %s) | best egg: %s (#%s, max hatch %s) | current world: %s",
        tostring(BestZoneName()),
        tostring(zone and zone.WorldNumber or "?"),
        tostring(egg and (egg.name or egg.id) or "?"),
        tostring(egg and egg.number or "?"),
        Int(MaxHatch()),
        tostring(CurrentWorld() or "?")
    )
    if State.Action ~= "" then
        Log("Action: %s", State.Action)
    end
end

local function Main()
    Log(
        "99 Ranker v%s starting (identity %s)",
        VERSION,
        tostring(type(getthreadidentity) == "function" and getthreadidentity() or "?")
    )
    if not Bootstrap() then
        Stop()
        return
    end
    local prior = Genv.PS99AutoRank
    if prior and type(prior.Unload) == "function" then
        prior.Unload()
    end
    RestoreStateFile()
    if ResumeAfterTeleport and State.Persist.ResumeCancelled then
        Stop()
        return
    end
    BuildGui()
    if BuildKizHubBlackoutGui then
        BuildKizHubBlackoutGui()
    end
    installAntiAfk()
    pcall(autoPickStarterPets)
    local ok, err = pcall(ControllerTick)
    if not ok then
        WarnLog("first-tick", "first controller tick failed: %s", tostring(err))
    end
    StartThreads()
    pcall(StartupSummary)
    Log(
        "All threads running. Toggle automation with the panel switch or getgenv().RiftwareAutoRank.SetEnabled(true/false); stop with .Stop()"
    )
end

Defer(function()
    local ok, err = pcall(Main)
    if not ok then
        warn(TAG .. "fatal error during startup: " .. tostring(err))
        Stop()
    end
end)
