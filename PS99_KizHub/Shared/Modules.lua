-- =========================================================================
-- PS99_KizHub/Shared/Modules.lua
-- Nạp và đóng gói toàn bộ Game Client Modules cho Pet Simulator 99
-- Tương thích 100% với cả Halloween Kaitun và AutoRank Kaitun
-- =========================================================================

local RS = game:GetService("ReplicatedStorage")

local IDENTITY_GAME = 2
local IDENTITY_EXEC = 7
local canSetIdentity = type(setthreadidentity) == "function"
if type(getthreadidentity) == "function" then
    local ok, id = pcall(getthreadidentity)
    if ok and type(id) == "number" then
        IDENTITY_EXEC = id
    end
end

local function gcall(fn, ...)
    if type(fn) ~= "function" then return false, "not a function" end
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_GAME) end
    local r = table.pack(pcall(fn, ...))
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_EXEC) end
    return table.unpack(r, 1, r.n)
end

-- Wrapper require an toàn qua ReplicatedStorage
local function req(path, optional)
    local ok, mod = gcall(function()
        local node = RS
        for seg in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(seg)
            if not node then
                if optional then return nil end
                error("Missing ReplicatedStorage node: " .. path)
            end
        end
        return require(node)
    end)
    if ok and mod ~= nil then
        return mod
    end
    return nil
end

-- Hàm tìm kiếm node lồng nhau có timeout
local function FindPath(root, path, timeout)
    local inst = root
    for _, name in ipairs(path) do
        if not inst then return nil end
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

-- Bảng chứa toàn bộ Client Modules đã require
local G = {
    -- Core & Network
    Network                     = req("Library.Client.Network"),
    Save                        = req("Library.Client.Save"),
    Directory                   = req("Library.Directory"),
    Items                       = req("Library.Items", true),
    FFlags                      = req("Library.Client.FFlags", true),
    TabController               = req("Library.Client.TabController", true),
    PlaceFile                   = req("Library.Modules.PlaceFile", true),

    -- Pets & Farming
    PlayerPet                   = req("Library.Client.PlayerPet"),
    PetCmds                     = req("Library.Client.PetCmds"),
    BreakableFrontend           = req("Library.Client.BreakableFrontend"),

    -- Currency & Economy
    CurrencyCmds                = req("Library.Client.CurrencyCmds"),
    Balancing                   = req("Library.Balancing"),

    -- Eggs & Hatching
    EggCmds                     = req("Library.Client.EggCmds"),
    Eggs                        = req("Library.Directory.Eggs", true),
    CustomEggs                  = req("Library.Client.CustomEggsCmds", true),
    EggsUtil                    = req("Library.Util.EggsUtil", true),
    CalcEggPricePlayer          = req("Library.Balancing.CalcEggPricePlayer", true),

    -- Zones & Maps
    ZoneCmds                    = req("Library.Client.ZoneCmds"),
    ZonesUtil                   = req("Library.Util.ZonesUtil", true),
    Zones                       = req("Library.Directory.Zones", true),
    MapCmds                     = req("Library.Client.MapCmds", true),
    Instancing                  = req("Library.Client.InstancingCmds", true),
    InstancingCmds              = req("Library.Client.InstancingCmds", true),
    InstanceZone                = req("Library.Client.InstanceZoneCmds", true),
    WorldsUtil                  = req("Library.Util.WorldsUtil", true),

    -- Ranks & Quests
    RankCmds                    = req("Library.Client.RankCmds"),
    RanksUtil                   = req("Library.Util.RanksUtil", true),
    QuestCmds                   = req("Library.Client.QuestCmds", true),

    -- Machines, Upgrades & Daycare
    MachineCmds                 = req("Library.Client.MachineCmds", true),
    UpgradeCmds                 = req("Library.Client.UpgradeCmds", true),
    Upgrades                    = req("Library.Directory.Upgrades", true),
    DaycareCmds                 = req("Library.Client.DaycareCmds", true),

    -- Halloween Special Modules
    EventUpgrades               = req("Library.Directory.EventUpgrades", true),
    EventUpgradeCmds            = req("Library.Client.EventUpgradeCmds", true),
    HGUpgrades                  = req("Library.Client.HalloweenGamesCmds.Upgrades", true),
    HGForge                     = req("Library.Client.HalloweenGamesCmds.Forge", true),

    -- Items, Potions, Enchants & Fruits
    PotionCmds                  = req("Library.Client.PotionCmds", true),
    Potions                     = req("Library.Directory.Potions", true),
    EnchantCmds                 = req("Library.Client.EnchantCmds", true),
    Enchants                    = req("Library.Directory.Enchants", true),
    FruitCmds                   = req("Library.Client.FruitCmds", true),
    Fruits                      = req("Library.Directory.Fruits", true),
    FlexibleFlagCmds            = req("Library.Client.FlexibleFlagCmds", true),
    Flags                       = req("Library.Directory.Flags", true),
    RandomEventCmds             = req("Library.Client.RandomEventCmds", true),

    -- Balancing calculations
    CalcPotionsPerTierRequired  = req("Library.Balancing.CalcPotionsPerTierRequired", true),
    CalcEnchantsPerTierRequired = req("Library.Balancing.CalcEnchantsPerTierRequired", true),
}

-- Fallback bổ sung module nếu require dạng chuỗi chưa nạp được
local function ensureModule(key, pathArray, optional)
    if G[key] ~= nil then return G[key] end
    local inst = FindPath(RS, pathArray, 3)
    if inst and inst:IsA("ModuleScript") then
        local ok, mod = pcall(require, inst)
        if ok and mod ~= nil then
            G[key] = mod
            return mod
        end
    end
    return nil
end

ensureModule("Network", { "Library", "Client", "Network" })
ensureModule("Save", { "Library", "Client", "Save" })
ensureModule("EggCmds", { "Library", "Client", "EggCmds" })
ensureModule("PetCmds", { "Library", "Client", "PetCmds" })
ensureModule("ZoneCmds", { "Library", "Client", "ZoneCmds" })
ensureModule("CurrencyCmds", { "Library", "Client", "CurrencyCmds" })
ensureModule("RankCmds", { "Library", "Client", "RankCmds" })

return {
    G = G,
    req = req,
    gcall = gcall,
    FindPath = FindPath,
    ensureModule = ensureModule,
}
