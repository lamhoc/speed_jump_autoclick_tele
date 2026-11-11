-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/QuestItems.lua
-- Module tự động sử dụng & nâng cấp Items (Potions, Enchants, Fruits, Flags, Events)
-- =========================================================================

local QuestItems = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local RankData = nil
local BestZoneIdFn = nil
local EnsureInBestZoneFn = nil

local MAX_UPGRADE_PER_CALL = 25

function QuestItems.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    RankData = deps.RankData
    BestZoneIdFn = deps.BestZoneId
    EnsureInBestZoneFn = deps.EnsureInBestZone
end

local function Stacks(category, predicate)
    local save = Net.getSave()
    local inv = save and save.Inventory
    local cat = type(inv) == "table" and inv[category] or nil
    if type(cat) ~= "table" then return {} end

    local out = {}
    for uid, item in pairs(cat) do
        if type(item) == "table" then
            local amount = tonumber(item._am) or 1
            if amount >= 1 and (predicate == nil or predicate(item, amount)) then
                out[#out + 1] = { uid = uid, item = item, amount = amount }
            end
        end
    end
    table.sort(out, function(a, b) return a.amount > b.amount end)
    return out
end

local function PickByPriority(list, priority)
    if type(priority) ~= "table" or #priority == 0 then return list[1] end
    local rank = {}
    for i, name in ipairs(priority) do rank[name] = i end
    for _, s in ipairs(list) do
        if rank[s.item.id] then return s end
    end
    return list[1]
end

local function OrderByPriority(list, priority)
    local rank = {}
    for i, name in ipairs(priority or {}) do rank[name] = i end
    table.sort(list, function(a, b)
        local ra, rb = rank[a.item.id] or 999, rank[b.item.id] or 999
        if ra ~= rb then return ra < rb end
        return a.amount > b.amount
    end)
    return list
end

local function FindSaveGoal(goal)
    local save = Net.getSave()
    if not (save and type(save.Goals) == "table") then return nil, false end
    for _, g in pairs(save.Goals) do
        if type(g) == "table" and g.UID == goal.UID then
            return g, true
        end
    end
    return nil, true
end

local function CurrentRemaining(goal)
    local g, saveOk = FindSaveGoal(goal)
    if not saveOk then return goal.remaining end
    if not g then return 0 end
    return math.max(0, (tonumber(g.Amount) or 0) - (tonumber(g.Progress) or 0))
end

local function TierRequirement(kind, srcTier)
    local fn, fb
    if kind == "potion" then
        fn = G.CalcPotionsPerTierRequired
        fb = RankData.POTION_TIER_REQ_FALLBACK
    else
        fn = G.CalcEnchantsPerTierRequired
        fb = RankData.ENCHANT_TIER_REQ_FALLBACK
    end
    if type(fn) == "function" then
        local n = Net.gval(fn, srcTier)
        if type(n) == "number" and n >= 1 then return math.floor(n) end
    end
    return fb[srcTier] or fb[#fb] or 3
end

function QuestItems.HandleUsePotions(goal, state)
    local T = tonumber(goal.PotionTier or (goal.raw and goal.raw.PotionTier))
    if not T then return end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then return end

    local n = math.min(rem, 10)
    local used = 0
    while used < n and state.Alive do
        local list = Stacks("Potion", function(item, _)
            return tonumber(item.tn) == T
        end)
        local s = PickByPriority(list, Config.PotionUsePriority) or list[1]
        if not s then break end
        local ok, err = Net.netFire("Potions: Consume", s.uid, 1)
        if not ok then break end
        used = used + 1
        state.Counters = state.Counters or {}
        state.Counters.ItemsUsed = (state.Counters.ItemsUsed or 0) + 1
        task.wait(0.4)
    end
end

function QuestItems.HandleUpgrade(goal, kind, state)
    local isPotion = kind == "potion"
    local field = isPotion and "PotionTier" or "EnchantTier"
    local T = tonumber(goal[field] or (goal.raw and goal.raw[field]))
    if not T or T < 2 then return end

    if isPotion and T > (Config.MaxInventoryPotionTier or 10) then return end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then return end

    local need = TierRequirement(kind, T - 1)
    local dirTable = isPotion and G.Potions or G.Enchants
    local list = Stacks(isPotion and "Potion" or "Enchant", function(item, _)
        if tonumber(item.tn) ~= (T - 1) then return false end
        local dirEntry = type(dirTable) == "table" and item.id ~= nil and dirTable[item.id] or nil
        local maxTier = dirEntry and tonumber(dirEntry.MaxTier) or nil
        if maxTier and maxTier < T then return false end
        return true
    end)
    list = OrderByPriority(list, isPotion and Config.PotionUpgradePriority or Config.EnchantUpgradePriority)

    local remote = isPotion and "UpgradePotionsMachine_Activate" or "UpgradeEnchantsMachine_Activate"
    for _, s in ipairs(list) do
        if rem <= 0 or not state.Alive then break end
        if s.amount >= need then
            local k = math.min(math.floor(s.amount / need), rem, MAX_UPGRADE_PER_CALL)
            local ok, res, msg = Net.netInvoke(remote, s.uid, k)
            if ok and res == true then
                rem = rem - k
                state.Counters = state.Counters or {}
                state.Counters.Crafted = (state.Counters.Crafted or 0) + k
                task.wait(0.5)
                rem = math.min(rem, CurrentRemaining(goal))
            else
                break
            end
        end
    end
end

function QuestItems.HandleUseFruits(goal, state)
    local rem = CurrentRemaining(goal)
    if rem <= 0 then return end

    local n = math.min(rem, 10)
    local used = 0
    while used < n and state.Alive do
        local list = Stacks("Fruit", function(item, _)
            if item.sh == true and not Config.AllowShinyFruit then return false end
            return true
        end)
        local s = PickByPriority(list, Config.FruitUsePriority) or list[1]
        if not s then break end
        local ok, err = Net.netFire("Fruits: Consume", s.uid, 1)
        if not ok then break end
        used = used + 1
        state.Counters = state.Counters or {}
        state.Counters.ItemsUsed = (state.Counters.ItemsUsed or 0) + 1
        task.wait(0.4)
    end
end

function QuestItems.HandleUseFlags(goal, state)
    if os.clock() < (state.FlagRetryAt or 0) then return end
    if state.WorldMismatch then return end
    if not Net.isfn(G.FlexibleFlagCmds, "Consume") then return end

    local rem = CurrentRemaining(goal)
    if rem <= 0 then return end

    local list = Stacks("Misc", function(item, _)
        return type(item.id) == "string" and string.sub(item.id, -5) == " Flag"
    end)
    local s = PickByPriority(list, Config.FlagPriority) or list[1]
    if not s then
        state.FlagRetryAt = os.clock() + 60
        return
    end

    local ok, res, msg = Net.gcall(G.FlexibleFlagCmds.Consume, s.item.id, s.uid, 1)
    if ok and res == true then
        state.Counters = state.Counters or {}
        state.Counters.ItemsUsed = (state.Counters.ItemsUsed or 0) + 1
        state.FlagRetryAt = os.clock() + 5
    else
        state.FlagRetryAt = os.clock() + 30
    end
end

function QuestItems.EventTick(state)
    if not state.Enabled or not Config.AutoSpawnEvents then return end
    if state.WorldSwitching or state.WorldMismatch or state.Hopping or state.HatchSession then return end

    local wanted = {}
    for _, goal in ipairs(state.Goals or {}) do
        local kind = RankData.EVENT_GOAL_KIND[goal.Type]
        if kind and goal.remaining > 0 and wanted[kind] == nil then
            wanted[kind] = goal
        end
    end
    if next(wanted) == nil then return end

    local zoneId = BestZoneIdFn and BestZoneIdFn() or nil
    if not zoneId then return end

    local now = os.clock()
    state.LastEventSpawn = state.LastEventSpawn or {}
    state.EventBackoffUntil = state.EventBackoffUntil or {}

    for kind, goal in pairs(wanted) do
        if not state.Alive then return end
        local def = RankData.EVENT_DEFS[kind]
        if def and now - (state.LastEventSpawn[kind] or -1e9) >= 12 and now >= (state.EventBackoffUntil[kind] or 0) then
            local rem = CurrentRemaining(goal)
            if rem > 0 then
                local s = nil
                for _, itemId in ipairs(def.items) do
                    local list = Stacks("Misc", function(item, _) return item.id == itemId end)
                    if #list > 0 then s = list[1] break end
                end
                if s then
                    state.LastEventSpawn[kind] = now
                    local ok, res = Net.netInvoke(def.remote, s.uid)
                    if ok and res == true then
                        state.Counters = state.Counters or {}
                        state.Counters.ItemsUsed = (state.Counters.ItemsUsed or 0) + 1
                        state.EventBackoffUntil[kind] = now + 15
                    else
                        state.EventBackoffUntil[kind] = now + 8
                    end
                end
            end
        end
    end
end

return QuestItems
