-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/QuestFarm.lua
-- Module tự động farm bãi vỡ theo nhiệm vụ Rank (Quest-Aware Farm)
-- Tối ưu hóa: Ưu tiên rương, Diamond breakables, Auto-Equip Best, Đứng chuẩn bãi
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local QuestFarm = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local RankData = nil

local Cache = {
    ZoneId = nil,
    ZoneAt = 0,
    Zone = nil,
    BreakPart = nil,
    BreakPartZone = nil,
}

local BreakAssign = {}
local FarmLastTier = 3
local BreakablesFolderCache = nil
local LastEquipBestAt = 0
local LastEnsureAt = 0
local lastEquipCheckAt = 0

function QuestFarm.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    RankData = deps.RankData

    pcall(QuestFarm.installOrbHook)
end

function QuestFarm.CurrentWorld()
    local pf = G.PlaceFile
    if type(pf) == "table" then
        for n = 1, 4 do
            local v = pf["IsWorld" .. n]
            if type(v) == "function" then
                local ok, r = Net.gcall(v)
                v = ok and r or nil
            end
            if v == true then return n end
        end
    end
    if Net.isfn(G.WorldsUtil, "GetWorldNumber") then
        local n = Net.gval(G.WorldsUtil.GetWorldNumber)
        if type(n) == "number" then return n end
    end
    return RankData.WORLD_PLACE_IDS[game.PlaceId] or 1
end

function QuestFarm.BestZoneId()
    local now = os.clock()
    if Cache.ZoneId and now - Cache.ZoneAt < 10 then
        return Cache.ZoneId
    end
    if Net.isfn(G.ZoneCmds, "GetMaxOwnedZone") then
        local id = Net.gval(G.ZoneCmds.GetMaxOwnedZone)
        if type(id) == "table" then id = id._id end
        if type(id) == "string" then
            Cache.ZoneId = id
            Cache.ZoneAt = now
            Cache.Zone = type(G.Zones) == "table" and G.Zones[id] or nil
        end
    end
    return Cache.ZoneId
end

function QuestFarm.BestZone()
    QuestFarm.BestZoneId()
    return Cache.Zone
end

function QuestFarm.BestZoneName()
    local z = QuestFarm.BestZone()
    return (z and (z.ZoneName or z._id)) or QuestFarm.BestZoneId() or "?"
end

function QuestFarm.ZoneArrivalPosition(ZoneId)
    if not Net.isfn(G.ZonesUtil, "GetTeleportPartLocation") then
        return nil
    end
    local Arrival = Net.gval(G.ZonesUtil.GetTeleportPartLocation, ZoneId)
    if typeof(Arrival) == "CFrame" then return Arrival.Position end
    if typeof(Arrival) == "Vector3" then return Arrival end
    return nil
end

function QuestFarm.BreakZonePart(zoneId)
    if Cache.BreakPart and Cache.BreakPartZone == zoneId and Cache.BreakPart.Parent then
        return Cache.BreakPart
    end
    local found = nil
    if Net.isfn(G.ZonesUtil, "GetInteractFolder") then
        local folder = Net.gval(G.ZonesUtil.GetInteractFolder, zoneId)
        if typeof(folder) == "Instance" then
            local bz = folder:FindFirstChild("BREAK_ZONES")
            if bz then
                local Arrival = QuestFarm.ZoneArrivalPosition(zoneId)
                local NearestDistance = math.huge
                local Count = 0
                for _, Part in ipairs(bz:GetDescendants()) do
                    if Part:IsA("BasePart") then
                        Count = Count + 1
                        local Distance = Arrival and (Part.Position - Arrival).Magnitude or 0
                        if Distance < NearestDistance then
                            found = Part
                            NearestDistance = Distance
                        end
                    end
                end
                if not Arrival and Count > 1 then return nil end
            end
        end
    end
    if not found and Net.isfn(G.MapCmds, "GetCurrentBreakZonePart") and Net.isfn(G.MapCmds, "GetCurrentZone") then
        if Net.gval(G.MapCmds.GetCurrentZone) == zoneId then
            local p = Net.gval(G.MapCmds.GetCurrentBreakZonePart)
            if typeof(p) == "Instance" and p:IsA("BasePart") then
                found = p
            end
        end
    end
    Cache.BreakPart = found
    Cache.BreakPartZone = zoneId
    return found
end

function QuestFarm.StandPosition(zoneId)
    local part = QuestFarm.BreakZonePart(zoneId)
    if part then
        return part.Position + Vector3.new(0, 4, 0)
    end
    local Arrival = QuestFarm.ZoneArrivalPosition(zoneId)
    return Arrival and Arrival + Vector3.new(0, 3, 0) or nil
end

function QuestFarm.EnsureInBestZone(state)
    if state.HatchSession or state.Hopping or state.WorldSwitching or state.WorldMismatch then
        return false
    end
    local now = os.clock()
    local force = state.ReturnAfterHatch ~= nil and now >= state.ReturnAfterHatch
    if not force and now - LastEnsureAt < 3 then
        return false
    end
    LastEnsureAt = now

    local zoneId = QuestFarm.BestZoneId()
    if not zoneId then return false end

    local pos = QuestFarm.StandPosition(zoneId)
    if not pos then return false end

    local hrp = Net.hrp()
    if not hrp then return false end

    local cz = Net.isfn(G.MapCmds, "GetCurrentZone") and Net.gval(G.MapCmds.GetCurrentZone) or nil
    local dist = (hrp.Position - pos).Magnitude
    if dist > (Config.ZonePositionTolerance or 25) or (cz ~= nil and cz ~= zoneId) then
        pcall(function()
            hrp.CFrame = CFrame.new(pos)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        state.ReturnAfterHatch = nil
        return true
    end
    state.ReturnAfterHatch = nil
    return false
end

function QuestFarm.BreakablesFolder()
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
    if class ~= nil and class ~= "Normal" then return 1 end
    for _, w in ipairs(RankData.EVENT_BREAKABLE_WORDS) do
        if string.find(id, w, 1, true) then return 1 end
    end
    if string.find(id, "diamond", 1, true) then return 2 end
    return 3
end

local function IsPublicBreakable(Model)
    local Area = Model:GetAttribute("AreaID")
    return (type(Area) ~= "string" or Area:lower() ~= "vip") and Model:GetAttribute("VIPBreakable") ~= true
end

function QuestFarm.CollectBreakables(zoneId)
    local p1, p2, p3 = {}, {}, {}
    local folder = QuestFarm.BreakablesFolder()
    if not folder or not zoneId then return p1, p2, p3 end

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

function QuestFarm.PetEuids()
    if not Net.isfn(G.PlayerPet, "GetByPlayer") then return {} end
    local pets = {}
    for _, pet in pairs(Net.gval(G.PlayerPet.GetByPlayer, LocalPlayer) or {}) do
        if pet.owner == LocalPlayer and pet.euid ~= nil then
            table.insert(pets, pet.euid)
        end
    end
    return pets
end

function QuestFarm.TargetPets(assignments, state)
    if not state.Alive or not state.Enabled or not Net.isfn(G.PlayerPet, "GetByPlayer") then
        return false
    end
    local folder = QuestFarm.BreakablesFolder()
    if not folder then return false end

    local targets = {}
    for _, model in ipairs(folder:GetChildren()) do
        local uid = model:GetAttribute("BreakableUID")
        if uid ~= nil and IsPublicBreakable(model) then
            targets[uid] = model
        end
    end

    local updated = false
    for _, pet in pairs(Net.gval(G.PlayerPet.GetByPlayer, LocalPlayer) or {}) do
        if Config.MaxPetSpeed ~= false and pet.owner == LocalPlayer then
            pcall(function()
                if type(pet.SetSpeed) == "function" then pet:SetSpeed(math.huge) end
                if pet.speedMultiplier ~= nil then pet.speedMultiplier = math.huge end
                if pet.speed ~= nil then pet.speed = math.huge end
            end)
        end
        local model = targets[assignments[pet.euid]]
        if state.Enabled and model and pet.owner == LocalPlayer and pet.target ~= model then
            local ok = Net.gcall(pet.SetTarget, pet, model)
            updated = updated or ok
        end
    end
    return updated
end

function QuestFarm.MaybeEquipBest()
    if not Config.AutoEquipBestPets then return end
    local now = os.clock()
    if now - LastEquipBestAt < 30 or now - lastEquipCheckAt < 5 then return end
    lastEquipCheckAt = now

    if not (Net.isfn(G.PetCmds, "GetEquipped") and Net.isfn(G.PetCmds, "EquipBest")) then return end

    local okEq, eq = Net.gcall(G.PetCmds.GetEquipped)
    if not okEq then return end

    if type(eq) == "table" and next(eq) ~= nil then return end
    if type(eq) == "number" and eq > 0 then return end

    LastEquipBestAt = now
    Net.gcall(G.PetCmds.EquipBest)
end

function QuestFarm.WantsDiamonds(state)
    for _, g in ipairs(state.GoalsByType and state.GoalsByType[RankData.T_DIAMOND] or {}) do
        if g.remaining > 0 then return true end
    end
    return false
end

function QuestFarm.FarmTick(state)
    if not state.Enabled or not Config.AutoFarm then return end
    if state.WorldSwitching or state.WorldMismatch or state.Hopping or state.HatchSession then return end

    QuestFarm.EnsureInBestZone(state)
    local zoneId = QuestFarm.BestZoneId()
    if not zoneId then return end

    local pets = QuestFarm.PetEuids()
    state.FarmPets = #pets
    if #pets == 0 then
        QuestFarm.MaybeEquipBest()
        return
    end

    local p1, p2, p3 = QuestFarm.CollectBreakables(zoneId)
    local targets, tier
    if #p1 > 0 then
        targets, tier = p1, 1
    elseif #p2 > 0 and QuestFarm.WantsDiamonds(state) then
        targets, tier = p2, 2
    else
        targets = {}
        for _, u in ipairs(p2) do targets[#targets + 1] = u end
        for _, u in ipairs(p3) do targets[#targets + 1] = u end
        tier = 3
    end

    state.FarmTargets = #targets
    if #targets == 0 then return end

    if tier < FarmLastTier then
        BreakAssign = {}
    end
    FarmLastTier = tier

    local live = {}
    for _, u in ipairs(targets) do live[u] = true end

    local map = {}
    for i, euid in ipairs(pets) do
        local targetUid = targets[((i - 1) % #targets) + 1]
        map[euid] = targetUid
    end
    QuestFarm.TargetPets(map, state)
end

function QuestFarm.OnBreakableAdded(model, state)
    if not state.Enabled or not Config.AutoFarm then return end
    if not (model and model:IsA("Model") and IsPublicBreakable(model)) then return end

    local zoneId = QuestFarm.BestZoneId()
    if model:GetAttribute("ParentID") ~= zoneId then return end

    local pr = ClassifyBreakable(model)
    if pr == 1 then
        local uid = model:GetAttribute("BreakableUID")
        if uid then
            local pets = QuestFarm.PetEuids()
            local assign = {}
            for _, euid in ipairs(pets) do
                assign[euid] = uid
            end
            QuestFarm.TargetPets(assign, state)
        end
    end
end

-- ================= 1. AUTO TAP / AUTO CLICK BREAKABLES =================
function QuestFarm.enableAutoTapper()
    pcall(function() Net.netInvoke("AutoTapper_Toggle", true) end)
    pcall(function() Net.netFire("AutoTapper_Toggle", true) end)
end

function QuestFarm.AutoTapTick(state)
    if not state or not state.Alive or not state.Enabled then return end
    local folder = QuestFarm.BreakablesFolder()
    if not folder then return end

    local hrp = Net.hrp()
    local myPos = hrp and hrp.Position or nil
    local zoneId = QuestFarm.BestZoneId()

    local candidates = {}
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and IsPublicBreakable(m) then
            local uid = m:GetAttribute("BreakableUID")
            if uid ~= nil then
                local inRange = false
                if myPos then
                    local ok, pos = pcall(function() return m:GetPivot().Position end)
                    if ok and (pos - myPos).Magnitude <= 95 then
                        inRange = true
                    end
                end
                if not inRange and zoneId then
                    local pid = m:GetAttribute("ParentID")
                    local aid = m:GetAttribute("AreaID")
                    if pid == zoneId or aid == zoneId then
                        inRange = true
                    end
                end
                if inRange then
                    candidates[#candidates + 1] = uid
                end
            end
        end
    end

    if #candidates > 0 then
        -- Chọn ngẫu nhiên 1 quặng bất kỳ trong bãi farm để nã sát thương
        local targetUid = candidates[math.random(1, #candidates)]
        Net.netUnreliable("Breakables_PlayerDealDamage", targetUid)
        pcall(function() Net.netFire("Breakables_PlayerDealDamage", targetUid) end)
    end
end

-- ================= 2. INFINITE / MAX PET SPEED =================
local isPetSpeedHooked = false
function QuestFarm.installMaxPetSpeed(state)
    if isPetSpeedHooked then return end
    task.spawn(function()
        for attempt = 1, 30 do
            local hooked = false
            pcall(function()
                local PlayerPet = G.PlayerPet or (G.require and G.require("Library.Client.PlayerPet"))
                if type(PlayerPet) == "table" and type(PlayerPet.CalculateSpeedMultiplier) == "function" then
                    if type(hookfunction) == "function" then
                        local orig
                        orig = hookfunction(PlayerPet.CalculateSpeedMultiplier, function(...)
                            if state and state.Alive and state.Enabled then
                                return math.huge -- Tốc độ cực đại math.huge giúp pet di chuyển tức thì
                            end
                            if type(orig) == "function" then return orig(...) end
                            return 1
                        end)
                        hooked = true
                        isPetSpeedHooked = true
                    else
                        local orig = PlayerPet.CalculateSpeedMultiplier
                        PlayerPet.CalculateSpeedMultiplier = function(...)
                            if state and state.Alive and state.Enabled then
                                return math.huge
                            end
                            return orig(...)
                        end
                        hooked = true
                        isPetSpeedHooked = true
                    end
                end
            end)
            if hooked then break end
            task.wait(1.0)
        end
    end)
end

-- ================= 3. ORB COLLECTOR (TỰ ĐỘNG HÚT NGỌC/ORBS/LOOTBAGS) =================
local isOrbHooked = false
function QuestFarm.installOrbHook()
    if isOrbHooked then return end
    task.spawn(function()
        for attempt = 1, 30 do
            local hooked = false
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local orbModule = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client") and RS.Library.Client:FindFirstChild("OrbCmds") and RS.Library.Client.OrbCmds:FindFirstChild("Orb")
                if orbModule then
                    local Orb = require(orbModule)
                    if type(Orb) == "table" and type(Orb.new) == "function" then
                        local origNew = Orb.new
                        Orb.new = function(...)
                            local orb = origNew(...)
                            if type(orb) == "table" then
                                task.defer(function()
                                    task.wait(tonumber(orb._pickupDelay) or 0.1)
                                    pcall(orb.Collect, orb, nil, nil, true)
                                end)
                            end
                            return orb
                        end
                        hooked = true
                        isOrbHooked = true
                    end
                end
            end)
            if hooked then break end
            task.wait(1.0)
        end
    end)
end

local orbMapCache = nil
function QuestFarm.findOrbMap()
    if type(orbMapCache) == "table" then return orbMapCache end
    local ok, map = Net.gcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local mod = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client") and RS.Library.Client:FindFirstChild("OrbCmds")
        if not mod then return nil end

        local fn = nil
        if type(getsenv) == "function" then
            local env = getsenv(mod)
            if type(env) == "table" and type(env.ProcessCreate) == "function" then
                fn = env.ProcessCreate
            end
        end

        if type(fn) ~= "function" and type(getgc) == "function" then
            for _, f in ipairs(getgc(false)) do
                if type(f) == "function" and debug.info(f, "n") == "ProcessCreate" then
                    fn = f
                    break
                end
            end
        end

        if type(fn) ~= "function" then return nil end
        if type(debug.getupvalues) ~= "function" then return nil end

        for _, up in pairs(debug.getupvalues(fn)) do
            if type(up) == "table" then
                local strKeys = false
                for k in pairs(up) do
                    if type(k) == "string" then
                        strKeys = true
                        break
                    end
                end
                if not strKeys then
                    return up
                end
            end
        end
        return nil
    end)
    if ok and type(map) == "table" then
        orbMapCache = map
    end
    return orbMapCache
end

function QuestFarm.CollectOrbsTick(state)
    if not state or not state.Alive or not state.Enabled then return end

    -- 1. Hút Orbs & Lootbags vật lý trực tiếp trong workspace.__THINGS về nhân vật
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hrpCf = hrp.CFrame
        local things = workspace:FindFirstChild("__THINGS")
        if not things then return end

        local orbsFolder = things:FindFirstChild("Orbs")
        if orbsFolder then
            for _, orb in ipairs(orbsFolder:GetChildren()) do
                pcall(function()
                    if orb:IsA("BasePart") then
                        orb.CFrame = hrpCf
                        if type(firetouchinterest) == "function" then
                            firetouchinterest(hrp, orb, 0)
                            firetouchinterest(hrp, orb, 1)
                        end
                    elseif orb:IsA("Model") then
                        orb:PivotTo(hrpCf)
                        local pp = orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart")
                        if pp and type(firetouchinterest) == "function" then
                            firetouchinterest(hrp, pp, 0)
                            firetouchinterest(hrp, pp, 1)
                        end
                    end
                end)
            end
        end

        local lootbagsFolder = things:FindFirstChild("Lootbags")
        if lootbagsFolder then
            for _, bag in ipairs(lootbagsFolder:GetChildren()) do
                pcall(function()
                    if bag:IsA("BasePart") then
                        bag.CFrame = hrpCf
                        if type(firetouchinterest) == "function" then
                            firetouchinterest(hrp, bag, 0)
                            firetouchinterest(hrp, bag, 1)
                        end
                    elseif bag:IsA("Model") then
                        bag:PivotTo(hrpCf)
                        local pp = bag.PrimaryPart or bag:FindFirstChildWhichIsA("BasePart")
                        if pp and type(firetouchinterest) == "function" then
                            firetouchinterest(hrp, pp, 0)
                            firetouchinterest(hrp, pp, 1)
                        end
                    end
                end)
            end
        end
    end)

    -- 2. Kích hoạt logic thu thập client-side của OrbCmds nếu có
    pcall(function()
        local map = QuestFarm.findOrbMap()
        if type(map) == "table" then
            local now = workspace:GetServerTimeNow()
            for _, orb in pairs(map) do
                if type(orb) == "table" and not orb._collected and not orb._destroyed and type(orb.Collect) == "function" then
                    local age = now - (tonumber(orb._timestamp) or now)
                    if age >= (tonumber(orb._pickupDelay) or 0) then
                        pcall(orb.Collect, orb, nil, nil, true)
                    end
                end
            end
        end
    end)
end

return QuestFarm
