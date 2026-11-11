-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/TreatUpgrades.lua
-- Module tự động nâng cấp kỹ năng sự kiện bằng kẹo Treat (VyHub Logic)
-- Tích hợp: Nhận diện cấu trúc Save.Get(), Ưu tiên Combine First, Safe Teleport
-- =========================================================================

local TreatUpgrades = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local K = nil
local inEventFn = nil
local instanceModelFn = nil

function TreatUpgrades.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
end

function TreatUpgrades.upgradeDir(id)
    local ok, d = pcall(function()
        return type(G.EventUpgrades) == "table" and G.EventUpgrades[id] or nil
    end)
    return ok and type(d) == "table" and d or nil
end

-- Đọc cấp độ hiện tại của nâng cấp
function TreatUpgrades.upgradeTier(idOrUpgrade)
    local testIds = {}
    if type(idOrUpgrade) == "table" then
        if idOrUpgrade.Id then table.insert(testIds, idOrUpgrade.Id) end
        if type(idOrUpgrade.Aliases) == "table" then
            for _, a in ipairs(idOrUpgrade.Aliases) do
                table.insert(testIds, a)
            end
        end
    elseif type(idOrUpgrade) == "string" then
        table.insert(testIds, idOrUpgrade)
        if idOrUpgrade == "HalloweenGamesPetSavings" then
            table.insert(testIds, "HalloweenGamesForgeSaver")
        elseif idOrUpgrade == "HalloweenGamesForgeSaver" then
            table.insert(testIds, "HalloweenGamesPetSavings")
        end
    end

    local s = Net.getSave()
    for _, id in ipairs(testIds) do
        -- 1. Gọi EventUpgradeCmds.GetTier với Identity Game
        if Net.isfn(G.EventUpgradeCmds, "GetTier") then
            local t = Net.gval(G.EventUpgradeCmds.GetTier, id)
            if type(t) == "number" and t > 0 then return t end
        end
        -- 2. Đọc từ s.EventUpgrades trong Save.Get()
        if type(s) == "table" and type(s.EventUpgrades) == "table" then
            local val = s.EventUpgrades[id]
            if type(val) == "number" and val > 0 then return val end
            if type(val) == "table" then
                local num = val.Tier or val.tier or val._tier or val._am or val[1]
                if type(num) == "number" and num > 0 then return num end
            end
        end
    end

    local firstId = testIds[1]
    if firstId then
        if Net.isfn(G.EventUpgradeCmds, "GetTier") then
            local t = Net.gval(G.EventUpgradeCmds.GetTier, firstId)
            if type(t) == "number" then return t end
        end
        if type(s) == "table" and type(s.EventUpgrades) == "table" and type(s.EventUpgrades[firstId]) == "number" then
            return s.EventUpgrades[firstId]
        end
    end
    return 0
end

-- Lấy thông tin chi tiết nâng cấp (tier, max, cost, power, status)
function TreatUpgrades.upgradeInfo(u)
    local d = TreatUpgrades.upgradeDir(u.Id)
    local tier = tonumber(TreatUpgrades.upgradeTier(u)) or 0
    local maxTier = d and type(d.TierPowers) == "table" and #d.TierPowers or 5
    local cost = nil
    if d and tier < maxTier then
        if Net.isfn(G.HGUpgrades, "Cost") then
            local okC, item = Net.gcall(G.HGUpgrades.Cost, d, tier + 1)
            if okC and item then
                local okA, amt = pcall(function() return item:GetAmount() end)
                if okA and type(amt) == "number" then cost = amt end
            end
        end
        if not cost and type(d.TierCosts) == "table" and d.TierCosts[tier + 1] then
            local targetCost = d.TierCosts[tier + 1]
            if type(targetCost) == "number" then
                cost = targetCost
            elseif type(targetCost) == "table" and type(targetCost.GetAmount) == "function" then
                local okA, amt = pcall(targetCost.GetAmount, targetCost)
                if okA and type(amt) == "number" then cost = amt end
            end
        end
    end
    local onSale = true
    if Net.isfn(G.HGUpgrades, "OnSale") then
        onSale = Net.gval(G.HGUpgrades.OnSale, u.Id) ~= false
    end
    local power = d and type(d.TierPowers) == "table" and d.TierPowers[tier] or nil
    return {
        tier = tier,
        max = maxTier,
        cost = cost,
        power = power,
        disabled = (d == nil) or d.Disabled == true or not onSale,
        dir = d,
    }
end

-- Lấy Model máy nâng cấp
function TreatUpgrades.upgradeMachineModel()
    if Net.isfn(G.MachineCmds, "GetModels") then
        local ok, models = Net.gcall(G.MachineCmds.GetModels, K.UPGRADE_MACHINE)
        if ok and type(models) == "table" then
            local m = instanceModelFn and instanceModelFn() or nil
            for _, mod in pairs(models) do
                if typeof(mod) == "Instance" and (not m or mod:IsDescendantOf(m)) then
                    return mod
                end
            end
        end
    end
    local m = instanceModelFn and instanceModelFn() or nil
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    return machines and machines:FindFirstChild(K.UPGRADE_MACHINE) or nil
end

function TreatUpgrades.machineStandPos()
    local mach = TreatUpgrades.upgradeMachineModel()
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then
        return pad.Position + Vector3.new(0, 3, 0), mach:GetPivot().Position
    end
    local pivot = mach:GetPivot().Position
    return pivot + Vector3.new(0, 3, 6), pivot
end

function TreatUpgrades.nearMachine()
    if Net.isfn(G.MachineCmds, "CanUse") then
        local v = Net.gval(G.MachineCmds.CanUse, K.UPGRADE_MACHINE)
        if v == true then return true end
    end
    local stand, pivot = TreatUpgrades.machineStandPos()
    local p = Net.playerPos()
    return pivot ~= nil and p ~= nil and Net.dist(p, pivot) <= (K.MACHINE_REACH or 8) + 4
end

-- Lựa chọn nâng cấp tối ưu theo thứ tự mục tiêu (Combine First)
function TreatUpgrades.pickUpgrade()
    local treats = Net.currency(K.TREATS)
    local candidates = {}
    for _, u in ipairs(K.UPGRADES) do
        local info = TreatUpgrades.upgradeInfo(u)
        if info.dir and not info.disabled and info.tier < info.max and info.cost and info.cost <= treats then
            candidates[#candidates + 1] = { u = u, info = info }
        end
    end
    if #candidates == 0 then return nil end

    local order = K.OBJECTIVE_ORDER and K.OBJECTIVE_ORDER["Combine First"]
    if order then
        local rank = {}
        for i, key in ipairs(order) do rank[key] = i end
        table.sort(candidates, function(a, b)
            local ra, rb = rank[a.u.Key] or 99, rank[b.u.Key] or 99
            if ra ~= rb then return ra < rb end
            return a.info.cost < b.info.cost
        end)
    else
        table.sort(candidates, function(a, b) return a.info.cost < b.info.cost end)
    end
    return candidates[1]
end

-- Thực hiện kiểm tra và tự động nâng cấp
function TreatUpgrades.checkAndRunTreatUpgrades(state)
    if not Config.AutoTreatUpgrades or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextTreatUpgradeAt or 0) then return end

    local cand = TreatUpgrades.pickUpgrade()
    if not cand then
        state.nextTreatUpgradeAt = now + 45
        return
    end

    state.excursion = "upgrades"
    local before = Net.playerPos()

    pcall(function()
        local stand = TreatUpgrades.machineStandPos()
        if not stand then return end
        if not TreatUpgrades.nearMachine() then
            Net.teleportTo(stand)
            local t0 = os.clock()
            repeat task.wait(0.2) until TreatUpgrades.nearMachine() or os.clock() - t0 > 3 or not state.alive
        end

        local bought = 0
        while state.alive and cand and bought < 12 do
            local ok, res = Net.netInvoke("EventUpgrades: Purchase", cand.u.Id)
            if not (ok and res == true) then break end
            bought = bought + 1
            state.lastSuccessfulHatch = os.clock()
            task.wait(0.6)
            cand = TreatUpgrades.pickUpgrade()
        end

        pcall(function()
            if G.TabController and type(G.TabController.Close) == "function" then
                G.TabController.Close("HalloweenGamesUpgradeMachine")
                G.TabController.Close("HalloweenUpgrades")
            end
        end)
    end)

    if before and state.alive then
        Net.teleportTo(before)
    end
    state.excursion = nil
    state.nextTreatUpgradeAt = os.clock() + (Config.UpgradeCooldown or 180)
end

return TreatUpgrades
