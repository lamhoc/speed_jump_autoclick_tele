-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/ZoneFarm.lua
-- Module tự động farm bãi vỡ (Breakables), Hút Orbs & Auto-Tap sự kiện Halloween
-- Tối ưu hóa CPU: Cache UID bãi vỡ, Bulk Join Pets, Quét Orbs không leak RAM
-- =========================================================================

local RS = game:GetService("ReplicatedStorage")
local ZoneFarm = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local K = nil

function ZoneFarm.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
end

local breakablesCache = {}
local lastBreakableScan = 0
local lastFastMap = {}
local lastFastSend = 0
local lastHitSend = 0
local orbMapCache = nil

-- Quét danh sách BreakableUID thuộc về khu vực chỉ định (Zone 1 - 8)
function ZoneFarm.zoneBreakables(zoneNumber)
    local now = os.clock()
    if breakablesCache[zoneNumber] and (now - lastBreakableScan < 1.2) then
        return breakablesCache[zoneNumber]
    end

    local list = {}
    local things = workspace:FindFirstChild("__THINGS")
    local folder = things and things:FindFirstChild("Breakables")
    if folder then
        local area = "Main_" .. tostring(zoneNumber)
        local altArea = "__Zone_" .. tostring(zoneNumber)
        local zoneCfg = K and K.ZONES and K.ZONES[zoneNumber]
        local zPos = zoneCfg and zoneCfg.Pos

        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local pid = m:GetAttribute("ParentID")
                local aid = m:GetAttribute("AreaID")
                local matchArea = (aid == area or aid == altArea or aid == tostring(zoneNumber))
                if (pid == (K and K.INSTANCE_ID or "HalloweenGames") and matchArea) or (zPos and Net.dist(m:GetPivot().Position, zPos) <= 60) then
                    local buid = m:GetAttribute("BreakableUID")
                    if buid ~= nil then
                        table.insert(list, buid)
                    end
                end
            end
        end
    end
    breakablesCache[zoneNumber] = list
    lastBreakableScan = now
    return list
end

-- Lấy danh sách UID pet đang trang bị
function ZoneFarm.petEuids()
    if not Net.isfn(G.PlayerPet, "GetAll") then return {} end
    local ok, all = Net.gcall(G.PlayerPet.GetAll)
    local res = {}
    if ok and type(all) == "table" then
        for _, p in pairs(all) do
            if type(p) == "table" and p.euid ~= nil then
                table.insert(res, p.euid)
            end
        end
    end
    return res
end

-- Phân phối pet tấn công bãi vỡ trong zone hiện tại
function ZoneFarm.farmZoneBreakables(zoneNumber)
    local targetUids = ZoneFarm.zoneBreakables(zoneNumber)
    if #targetUids == 0 then return end

    local pets = ZoneFarm.petEuids()
    if #pets == 0 and Net.isfn(G.PetCmds, "EquipBest") then
        Net.gcall(G.PetCmds.EquipBest)
        task.wait(0.8)
        pets = ZoneFarm.petEuids()
    end
    if #pets == 0 then return end

    local infos, chests = {}, {}
    for _, uid in ipairs(targetUids) do
        local b = Net.isfn(G.BreakableFrontend, "Get") and Net.gval(G.BreakableFrontend.Get, uid) or nil
        if type(b) == "table" then
            local hp = type(b.health) == "number" and b.health or 1
            if hp > 0 then
                local item = { uid = uid, health = hp, class = tostring(b.class or "Normal") }
                if item.class ~= "Normal" then
                    table.insert(chests, item)
                end
                table.insert(infos, item)
            end
        else
            table.insert(infos, { uid = uid, health = 1e9, class = "Normal" })
        end
    end
    if #infos == 0 then return end

    -- Ưu tiên rương trước, sau đó sắp xếp theo lượng máu thấp nhất
    local ordered = (#chests > 0) and chests or infos
    table.sort(ordered, function(a, b)
        if a.health ~= b.health then return a.health < b.health end
        return tostring(a.uid) < tostring(b.uid)
    end)

    local now = os.clock()
    if now - lastHitSend > 1.2 then
        lastHitSend = now
        Net.netUnreliable("Breakables_PlayerDealDamage", ordered[1].uid)
    end

    local map, changed = {}, false
    for i, euid in ipairs(pets) do
        local tUid = ordered[((i - 1) % #ordered) + 1].uid
        map[euid] = tUid
        if lastFastMap[euid] ~= tUid then
            changed = true
        end
    end

    if changed or (now - lastFastSend > 2.2) then
        lastFastSend = now
        lastFastMap = map
        Net.netFire("Breakables_JoinPetBulk", map)
    end
end

-- Tìm bảng Orbs trong bộ nhớ Client của Big Games
function ZoneFarm.findOrbMap()
    if type(orbMapCache) == "table" then return orbMapCache end
    local ok, map = Net.gcall(function()
        local mod = RS.Library.Client:FindFirstChild("OrbCmds")
        if not mod or type(getsenv) ~= "function" then return nil end
        local env = getsenv(mod)
        local fn = type(env) == "table" and env.ProcessCreate or nil
        if type(fn) ~= "function" and type(getgc) == "function" then
            for _, f in ipairs(getgc(false)) do
                if type(f) == "function" and debug.info(f, "n") == "ProcessCreate" then
                    fn = f
                    break
                end
            end
        end
        if type(fn) ~= "function" then return nil end
        for _, up in pairs(debug.getupvalues(fn)) do
            if type(up) == "table" then
                local strKeys = false
                for k in pairs(up) do
                    if type(k) == "string" then
                        strKeys = true
                        break
                    end
                end
                if not strKeys then return up end
            end
        end
        return nil
    end)
    if ok and type(map) == "table" then
        orbMapCache = map
    end
    return orbMapCache
end

-- Tự động hút toàn bộ Orbs rơi ra trong map
function ZoneFarm.collectOrbsTick()
    local map = ZoneFarm.findOrbMap()
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
end

-- Nhịp Auto-Tap 10Hz ngẫu nhiên vào bãi vỡ trong zone hiện tại
function ZoneFarm.runAutoTapTick(currentZoneNumber)
    local targetUids = ZoneFarm.zoneBreakables(currentZoneNumber or 1)
    if #targetUids > 0 then
        local randomTarget = targetUids[math.random(1, #targetUids)]
        Net.netUnreliable("Breakables_PlayerDealDamage", randomTarget)
    end
end

return ZoneFarm
