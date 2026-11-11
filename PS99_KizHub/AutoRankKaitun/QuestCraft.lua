-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/QuestCraft.lua
-- Module tự động ghép Pet Vàng (Gold) và Pet Cầu Vồng (Rainbow) theo Quest Rank
-- =========================================================================

local QuestCraft = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local RankData = nil
local BestEggFn = nil
local MAX_CRAFT_PER_CALL = 50

function QuestCraft.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    RankData = deps.RankData
    BestEggFn = deps.BestEgg
end

local function IsProtectedPet(id)
    for _, p in ipairs(Config.ProtectedPetIds or {}) do
        if p == id then return true end
    end
    return false
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

local function FodderStacks(targetKind, allowed)
    return Stacks("Pet", function(item, _)
        if type(item.id) ~= "string" or IsProtectedPet(item.id) then return false end
        if allowed ~= nil and not allowed[item.id] then return false end
        if item.sh == true and not Config.UseShinyPetsAsFodder then return false end
        local kind = item.pt or 0
        return kind == targetKind
    end)
end

local function CraftAllowedIds(goal)
    if RankData.BEST_EGG_ONLY_CRAFT[goal.Type] then
        local egg = BestEggFn and BestEggFn() or nil
        if not egg or not egg.petIds or next(egg.petIds) == nil then
            return false, nil, "best egg"
        end
        return true, egg.petIds, tostring(egg.name or egg.id or "best egg")
    end
    return true, nil, "any"
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

function QuestCraft.CraftGoldenFrom(normalStacks, rem, logSuffix, capFn, state)
    local crafted = 0
    for _, s in ipairs(normalStacks) do
        if rem <= 0 then break end
        while rem > 0 and s.amount >= 10 and state.Alive do
            local k = math.min(math.floor(s.amount / 10), rem, MAX_CRAFT_PER_CALL)
            local ok, res, msg = Net.netInvoke("GoldMachine_Activate", s.uid, k)
            if ok and res == true then
                crafted = crafted + k
                rem = rem - k
                s.amount = s.amount - k * 10
                state.Counters = state.Counters or {}
                state.Counters.Crafted = (state.Counters.Crafted or 0) + k
                task.wait(0.5)
                if capFn then
                    local c = capFn()
                    if type(c) == "number" then rem = math.min(rem, c) end
                end
            else
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

function QuestCraft.CraftRainbowFrom(goldenStacks, rem, goal, state)
    for _, s in ipairs(goldenStacks) do
        if rem <= 0 then break end
        while rem > 0 and s.amount >= 10 and state.Alive do
            local k = math.min(math.floor(s.amount / 10), rem, MAX_CRAFT_PER_CALL)
            local ok, res, msg = Net.netInvoke("RainbowMachine_Activate", s.uid, k)
            if ok and res == true then
                rem = rem - k
                s.amount = s.amount - k * 10
                state.Counters = state.Counters or {}
                state.Counters.Crafted = (state.Counters.Crafted or 0) + k
                task.wait(0.5)
                rem = math.min(rem, CurrentRemaining(goal))
            else
                return rem, false
            end
        end
    end
    return rem, true
end

function QuestCraft.HandleGoldCraft(goal, state)
    local ok, allowed, label = CraftAllowedIds(goal)
    if not ok then return nil end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then return nil end

    local normal = FodderStacks(0, allowed)
    local _, left, leftover = QuestCraft.CraftGoldenFrom(normal, rem, "", function()
        return CurrentRemaining(goal)
    end, state)
    if left > 0 and leftover ~= nil then
        return string.format("need %d more normal %s pets", math.max(1, left * 10 - leftover), tostring(label))
    end
    return nil
end

function QuestCraft.HandleRainbowCraft(goal, state)
    local okIds, allowed, label = CraftAllowedIds(goal)
    if not okIds then return nil end
    local rem = CurrentRemaining(goal)
    if rem <= 0 then return nil end

    local golden = FodderStacks(1, allowed)
    local okStep
    rem, okStep = QuestCraft.CraftRainbowFrom(golden, rem, goal, state)
    if rem <= 0 or not okStep then return nil end

    local goldenById = {}
    for _, s in ipairs(golden) do
        goldenById[s.item.id] = (goldenById[s.item.id] or 0) + s.amount
    end
    local normal = FodderStacks(0, allowed)
    table.sort(normal, function(a, b)
        local ga, gb = goldenById[a.item.id] or 0, goldenById[b.item.id] or 0
        if ga ~= gb then return ga > gb end
        return a.amount > b.amount
    end)
    local src = normal[1]
    if not src then
        return string.format("need %d more golden %s pets", rem * 10, tostring(label))
    end

    local goldenNeeded = rem * 10 - (goldenById[src.item.id] or 0)
    if goldenNeeded <= 0 then return nil end

    local made, left, leftover = QuestCraft.CraftGoldenFrom({ src }, goldenNeeded, " (for rainbow)", nil, state)
    if made > 0 then
        task.wait(0.75)
        rem = CurrentRemaining(goal)
        if rem > 0 then
            QuestCraft.CraftRainbowFrom(FodderStacks(1, allowed), rem, goal, state)
        end
    end
    return nil
end

function QuestCraft.CraftTick(state)
    if not state.Enabled or not Config.AutoCraftGoldRainbow then return end
    if state.WorldSwitching then return end

    local goals = {}
    for _, g in ipairs(state.Goals or {}) do
        if g.remaining > 0 and (RankData.GOLD_GOALS[g.Type] or RankData.RAINBOW_GOALS[g.Type]) then
            goals[#goals + 1] = g
        end
    end
    if #goals == 0 then
        state.CraftHatchReason = nil
        return
    end

    for _, goal in ipairs(goals) do
        if not state.Alive or not state.Enabled then return end
        if RankData.GOLD_GOALS[goal.Type] then
            QuestCraft.HandleGoldCraft(goal, state)
        elseif RankData.RAINBOW_GOALS[goal.Type] then
            QuestCraft.HandleRainbowCraft(goal, state)
        end
    end
end

return QuestCraft
