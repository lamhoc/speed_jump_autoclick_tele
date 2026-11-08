-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (100% HEADLESS - FULL FIXED LOGIC)
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.HG_Kaitun) == "table" and type(genv.HG_Kaitun.Stop) == "function" then
    pcall(genv.HG_Kaitun.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Chu trình mở trứng & Secret Room
    SecretFarmDuration = 480,            -- 8 phút (480s) cày xu ngoài bãi khi hết tiền mở Secret Egg
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (Max trứng theo Rank/lần)
    HatchDelay = 0.45,

    -- 2. Nâng cấp sự kiện (Treat Upgrades)
    AutoTreatUpgrades = true,
    UpgradeCooldown = 600,               -- 10 phút (600 giây) kiểm tra nâng cấp 1 lần

    -- 3. Ghép Huge Bat Hoodie Bunny
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 60,

    -- 4. Auto Mail
    Mail = {
        Enabled = true,
        Recipient = "DienTenAccNhanVaoDay", -- ⚠️ ĐIỀN USERNAME ACC NHẬN
        CheckInterval = 120,
        MinDiamondsToKeep = 50000,
        SendAllHuges = true,
        MinConsumableStack = 4,
        ConsumableTiers = { 1, 2, 3 },
        Consumables = {
            "Halloween Games Lucky Charm",
            "Halloween Games Treat Magnet",
            "Halloween Games Broomstick",
            "Halloween Games Lantern",
        },
    },

    -- 5. Auto Buffs (Chống Spam: Đúng thời gian hết hạn mới dùng lại)
    AutoBuffs = {
        Daycare = true,
        Toys = true,                        -- 900s (15 phút)
        Fruits = true,                      -- 300s (5 phút)
        Potions = true,                     -- 900s (15 phút)
        Flags = true,                       -- 300s (5 phút)
        PreferredFlags = { "Coins Flag", "Fortune Flag", "Hasty Flag", "Magnet Flag" },
    },
}
local CFG = genv.KaitunConfig

-- ================= HẠ QUYỀN THREAD IDENTITY =================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

repeat task.wait(0.2) until LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

local IDENTITY_GAME = 2
local IDENTITY_EXEC = 7
local canSetIdentity = type(setthreadidentity) == "function"
if type(getthreadidentity) == "function" then
    local ok, id = pcall(getthreadidentity)
    if ok and type(id) == "number" then IDENTITY_EXEC = id end
end

local function gcall(fn, ...)
    if type(fn) ~= "function" then return false, "not a function" end
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_GAME) end
    local r = table.pack(pcall(fn, ...))
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_EXEC) end
    return table.unpack(r, 1, r.n)
end

local function gval(fn, ...)
    local ok, a, b, c = gcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function isfn(t, k)
    return type(t) == "table" and type(t[k]) == "function"
end

-- ================= LOAD MODULES TỪ GAME =================
local function req(path)
    local ok, mod = gcall(function()
        local node = RS
        for seg in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(seg)
            if not node then error("missing " .. path) end
        end
        return require(node)
    end)
    return ok and mod or nil
end

local G = {
    Network           = req("Library.Client.Network"),
    Save              = req("Library.Client.Save"),
    Instancing        = req("Library.Client.InstancingCmds"),
    InstanceZone      = req("Library.Client.InstanceZoneCmds"),
    CustomEggs        = req("Library.Client.CustomEggsCmds"),
    EggCmds           = req("Library.Client.EggCmds"),
    Eggs              = req("Library.Directory.Eggs"),
    CurrencyCmds      = req("Library.Client.CurrencyCmds"),
    PlayerPet         = req("Library.Client.PlayerPet"),
    PetCmds           = req("Library.Client.PetCmds"),
    BreakableFrontend = req("Library.Client.BreakableFrontend"),
    EventUpgrades     = req("Library.Directory.EventUpgrades"),
    EventUpgradeCmds  = req("Library.Client.EventUpgradeCmds"),
    DaycareCmds       = req("Library.Client.DaycareCmds"),
    Directory         = req("Library.Directory"),
    FFlags            = req("Library.Client.FFlags"),
}

-- ================= DỮ LIỆU TỌA ĐỘ VỊ TRÍ =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    UPGRADE_MACHINE = "HalloweenGamesUpgradeMachine",
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    SECRET_EGG_ID   = "Secret Room Egg",
    SECRET_STAND    = Vector3.new(-6675.58, 2117.07, -3683.72),
    ZONES = {
        [1] = { Number = 1, Name = "#1 Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60, 16.20, -3939.52), EggPos = Vector3.new(-5315.25, 20.87, -3914.00) },
        [2] = { Number = 2, Name = "#2 Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83, 16.24, -3940.37), EggPos = Vector3.new(-5496.82, 20.31, -3913.00) },
        [3] = { Number = 3, Name = "#3 Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.55, 16.39, -3941.15), EggPos = Vector3.new(-5657.75, 20.70, -3913.00) },
        [4] = { Number = 4, Name = "#4 Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52, 16.42, -3939.43), EggPos = Vector3.new(-5810.95, 20.30, -3915.00) },
        [5] = { Number = 5, Name = "#5 Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.74, 16.24, -3939.23), EggPos = Vector3.new(-5984.55, 20.30, -3917.00) },
        [6] = { Number = 6, Name = "#6 Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.53, 16.92, -3910.60), EggPos = Vector3.new(-6340.73, 20.56, -3884.65) },
        [7] = { Number = 7, Name = "#7 Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.39, 16.96, -3911.23), EggPos = Vector3.new(-6520.73, 20.78, -3885.90) },
        [8] = { Number = 8, Name = "#8 Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50, 16.92, -3910.71), EggPos = Vector3.new(-6680.73, 20.58, -3886.40) },
    },
    UPGRADES = {
        { Key = "CoinFinder",     Id = "HalloweenGamesCoinFinder" },
        { Key = "EggLuck",        Id = "HalloweenGamesEggLuck" },
        { Key = "HugeLuck",       Id = "HalloweenGamesHugeLuck" },
        { Key = "Golden",         Id = "HalloweenGamesGolden" },
        { Key = "Rainbow",        Id = "HalloweenGamesRainbow" },
        { Key = "Shiny",          Id = "HalloweenGamesShiny" },
        { Key = "PetSavings",     Id = "HalloweenGamesPetSavings" },
        { Key = "BetterVariants", Id = "HalloweenGamesBetterVariants" },
    }
}

local state = {
    alive = true,
    excursion = nil,
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 },
    totalEggsHatched = 0,
    secretCooldownUntil = 0,
    -- Cooldown Buffs & Nâng cấp
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextFlagAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextDaycareAt = 0,
}

local connections = {}
local restoreFns = {}

-- ================= TIỆN ÍCH MẠNG & DI CHUYỂN =================
local function netInvoke(name, ...)
    if isfn(G.Network, "Invoke") then return gcall(G.Network.Invoke, name, ...) end
    return false
end

local function netFire(name, ...)
    if isfn(G.Network, "Fire") then return gcall(G.Network.Fire, name, ...) end
    return false
end

local function netUnreliable(name, ...)
    if isfn(G.Network, "UnreliableFire") then return gcall(G.Network.UnreliableFire, name, ...) end
    return false
end

local function getSave()
    if isfn(G.Save, "Get") then return gval(G.Save.Get) end
    return nil
end

local function currency(id)
    if isfn(G.CurrencyCmds, "Get") then
        local v = gval(G.CurrencyCmds.Get, id)
        if type(v) == "number" then return v end
    end
    local s = getSave()
    if s and type(s.Currency) == "table" and type(s.Currency[id]) == "number" then return s.Currency[id] end
    return 0
end

local function hrp()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function playerPos()
    local r = hrp()
    return r and r.Position or nil
end

local function dist(a, b)
    if not (a and b) then return math.huge end
    return (a - b).Magnitude
end

local function teleportTo(pos)
    local c = LocalPlayer.Character
    local r = hrp()
    if not (c and r and pos) then return false end
    local cf = CFrame.new(pos) * (r.CFrame - r.CFrame.Position)
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end

-- ================= HOOKS CHỐNG LAG =================
pcall(function()
    if type(hookfunction) == "function" and isfn(G.PlayerPet, "CalculateSpeedMultiplier") then
        local orig
        orig = hookfunction(G.PlayerPet.CalculateSpeedMultiplier, function(...)
            if state.alive then return math.huge end
            return orig(...)
        end)
    end
end)

task.spawn(function()
    pcall(function()
        if type(getsenv) ~= "function" then return end
        local ps = LocalPlayer:WaitForChild("PlayerScripts", 10)
        local eggScript = ps and ps:WaitForChild("Scripts", 10):WaitForChild("Game", 10):WaitForChild("Egg Opening Frontend", 10)
        if not eggScript then return end
        local env = getsenv(eggScript)
        if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
            local orig = env.PlayEggAnimation
            env.PlayEggAnimation = function(...)
                if state.alive then return end
                return orig(...)
            end
            table.insert(restoreFns, function() env.PlayEggAnimation = orig end)
        end
    end)
end)

pcall(function()
    if type(getconnections) == "function" then
        for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
            if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
        end
    end
    table.insert(connections, LocalPlayer.Idled:Connect(function()
        if not state.alive then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end)

-- ================= INSTANCE, ZONE & SECRET ROOM DETECTION =================
local function currentInstanceId()
    if isfn(G.Instancing, "GetInstanceID") then
        local id = gval(G.Instancing.GetInstanceID)
        if type(id) == "string" and id ~= "" then return id end
    end
    return nil
end

local function inEvent()
    return currentInstanceId() == K.INSTANCE_ID
end

local function ensureInHalloweenEvent()
    if inEvent() then return true end
    if isfn(G.Instancing, "Enter") then
        gcall(G.Instancing.Enter, K.INSTANCE_ID)
    end
    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 20 do
        if inEvent() then
            task.wait(1)
            return true
        end
        task.wait(0.5)
    end
    return inEvent()
end

local function zoneUnlocked(n)
    if n <= 1 then return true end
    if isfn(G.InstanceZone, "IsUnlocked") then
        local v = gval(G.InstanceZone.IsUnlocked, n)
        if v ~= nil then return v == true end
    end
    local s = getSave()
    local iv = s and s.InstanceVars and s.InstanceVars[K.INSTANCE_ID]
    local iz = iv and iv.InstanceZones
    return type(iz) == "table" and iz["__Zone_" .. n] == true
end

local function bestUnlockedZone()
    if isfn(G.InstanceZone, "GetMaximumOwnedZoneNumber") then
        local n = gval(G.InstanceZone.GetMaximumOwnedZoneNumber)
        if type(n) == "number" and n >= 1 then return math.clamp(n, 1, 8) end
    end
    local best = 1
    for i = 2, 8 do
        if zoneUnlocked(i) then best = i end
    end
    return best
end

local function tryUnlockNextZone()
    local best = bestUnlockedZone()
    if best >= 8 then return false end
    local nextZ = best + 1

    local obj = isfn(G.Instancing, "Get") and gval(G.Instancing.Get)
    local zInfo = obj and obj.instanceZones and obj.instanceZones[nextZ]
    if zInfo then
        local cost = tonumber(zInfo.CurrencyCost)
        local curId = zInfo.CurrencyId or K.CURRENCY
        if cost and currency(curId) < cost then
            return false
        end
    end

    local ok, res = netInvoke("InstanceZones_RequestPurchase", K.INSTANCE_ID, nextZ)
    if ok and res == true then
        return true
    end
    return false
end

-- Kiểm tra Secret Room có đang mở cửa hay không
local function isSecretRoomOpen()
    local things = workspace:FindFirstChild("__THINGS")
    local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local active = container and container:FindFirstChild("Active")
    if active and active:FindFirstChild("HalloweenGamesSecretRoom") then
        return true
    end
    return false
end

-- ================= HATCH TRỨNG (THEO RANK & ĐIỂM ĐỨNG VIỀN) =================
local function findCustomEggById(eggId)
    if not isfn(G.CustomEggs, "All") then return nil end
    local all = gval(G.CustomEggs.All)
    if type(all) ~= "table" then return nil end
    for uid, e in pairs(all) do
        if type(e) == "table" and e._id == eggId then
            local pos = e._position
            if typeof(pos) ~= "Vector3" and e._model and e._model.Parent then
                pcall(function() pos = e._model:GetPivot().Position end)
            end
            return {
                uid = e._uid or uid,
                id = e._id,
                dir = e._dir or (G.Eggs and G.Eggs[e._id]) or nil,
                pos = pos,
                maxCount = e._maxEggCount,
            }
        end
    end
    return nil
end

local function getAccountMaxHatch(egg)
    local bestMax = 1
    if isfn(G.EggCmds, "GetMaxHatch") then
        local n = gval(G.EggCmds.GetMaxHatch, egg and egg.dir or nil)
        if type(n) == "number" and n > bestMax then bestMax = math.floor(n) end
    end
    if egg and type(egg.maxCount) == "number" and egg.maxCount > bestMax then
        bestMax = math.floor(egg.maxCount)
    end
    return math.max(1, bestMax)
end

-- Trả về: (thành công, số lượng mở được, hết tiền)
local function executeHatch(egg)
    if not egg or not egg.uid then return false, 0, false end
    local amount = getAccountMaxHatch(egg)

    local ok, res, msg = netInvoke("CustomEggs_Hatch", egg.uid, amount)
    if ok and res == true then
        state.totalEggsHatched += amount
        return true, amount, false
    end

    local errText = string.lower(tostring(msg or res or ""))
    local isOutOfCoins = errText:find("afford") or errText:find("enough") or errText:find("coin")

    if isOutOfCoins then
        local tryAmt = amount
        while state.alive and tryAmt > 1 do
            tryAmt = math.max(1, math.floor(tryAmt / 2))
            local ok2, res2 = netInvoke("CustomEggs_Hatch", egg.uid, tryAmt)
            if ok2 and res2 == true then
                state.totalEggsHatched += tryAmt
                return true, tryAmt, false
            end
        end
        return false, 0, true
    end

    return false, 0, false
end

-- Điểm đứng viền: Nằm ở vị trí trung hòa giữa bệ trứng và tâm bãi farm
local function getOptimalZoneStandPos(zoneNumber, isActivelyHatching)
    local z = K.ZONES[zoneNumber]
    if not z then return nil end
    if isActivelyHatching then
        -- Khi đang mở trứng: Đứng ở trung điểm (cách trứng ~12 studs và lọt vào rìa bãi quái)
        return Vector3.new((z.Pos.X + z.EggPos.X) / 2, z.Pos.Y, (z.Pos.Z + z.EggPos.Z) / 2)
    else
        -- Khi đã xong 5 lần mở trứng: Đứng thẳng vào tâm bãi farm để tối ưu đập quái
        return z.Pos
    end
end

-- ================= HỆ THỐNG FARM BREAKABLES & HÚT ORBS =================
local function petEuids()
    if not isfn(G.PlayerPet, "GetAll") then return {} end
    local ok, out = gcall(function()
        local res = {}
        local all = G.PlayerPet.GetAll()
        if type(all) == "table" then
            for _, p in pairs(all) do
                if type(p) == "table" and p.euid ~= nil then table.insert(res, p.euid) end
            end
        end
        return res
    end)
    return (ok and type(out) == "table") and out or {}
end

local function zoneBreakables(zoneNumber)
    local list = {}
    local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if not folder then return list end
    local area = "Main_" .. tostring(zoneNumber)
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("ParentID") == K.INSTANCE_ID and m:GetAttribute("AreaID") == area then
            local buid = m:GetAttribute("BreakableUID")
            if buid ~= nil then table.insert(list, buid) end
        end
    end
    return list
end

local lastFastMap = {}
local lastFastSend = 0
local function farmZoneBreakables(zoneNumber)
    local targetUids = zoneBreakables(zoneNumber)
    if #targetUids == 0 then return end
    local pets = petEuids()
    if #pets == 0 then return end

    local infos, chests = {}, {}
    for _, uid in ipairs(targetUids) do
        local b = isfn(G.BreakableFrontend, "Get") and gval(G.BreakableFrontend.Get, uid) or nil
        if type(b) == "table" then
            local hp = type(b.health) == "number" and b.health or 1
            if hp > 0 then
                local item = { uid = uid, health = hp, class = tostring(b.class or "Normal") }
                if item.class ~= "Normal" then table.insert(chests, item) end
                table.insert(infos, item)
            end
        else
            table.insert(infos, { uid = uid, health = 1e9, class = "Normal" })
        end
    end
    if #infos == 0 then return end

    local ordered = (#chests > 0) and chests or infos
    table.sort(ordered, function(a, b)
        if a.health ~= b.health then return a.health < b.health end
        return tostring(a.uid) < tostring(b.uid)
    end)

    netUnreliable("Breakables_PlayerDealDamage", ordered[1].uid)

    local map, changed = {}, false
    for i, euid in ipairs(pets) do
        local tUid = ordered[((i - 1) % #ordered) + 1].uid
        map[euid] = tUid
        if lastFastMap[euid] ~= tUid then changed = true end
    end
    lastFastMap = map

    if changed or (os.clock() - lastFastSend > 0.8) then
        lastFastSend = os.clock()
        netFire("Breakables_JoinPetBulk", map)
    end
end

local orbMapCache = nil
local function findOrbMap()
    if type(orbMapCache) == "table" then return orbMapCache end
    local ok, map = gcall(function()
        local mod = RS.Library.Client:FindFirstChild("OrbCmds")
        if not mod or type(getsenv) ~= "function" then return nil end
        local env = getsenv(mod)
        local fn = type(env) == "table" and env.ProcessCreate or nil
        if type(fn) ~= "function" and type(getgc) == "function" then
            for _, f in ipairs(getgc(false)) do
                if type(f) == "function" and debug.info(f, "n") == "ProcessCreate" then fn = f break end
            end
        end
        if type(fn) ~= "function" then return nil end
        for _, up in pairs(debug.getupvalues(fn)) do
            if type(up) == "table" then
                local strKeys = false
                for k in pairs(up) do if type(k) == "string" then strKeys = true break end end
                if not strKeys then return up end
            end
        end
        return nil
    end)
    if ok and type(map) == "table" then orbMapCache = map end
    return orbMapCache
end

local function collectOrbsTick()
    local map = findOrbMap()
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

-- ================= AUTO TREAT UPGRADES (10 PHÚT / LẦN) =================
local function getMachineStand(machineName)
    local things = workspace:FindFirstChild("__THINGS")
    local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local act = cont and cont:FindFirstChild("Active")
    local m = act and act:FindFirstChild(K.INSTANCE_ID)
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    local mach = machines and machines:FindFirstChild(machineName)
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0) end
    return mach:GetPivot().Position + Vector3.new(0, 3, 6)
end

local function getAffordableUpgrade(treats)
    for _, u in ipairs(K.UPGRADES) do
        local dir = G.EventUpgrades and G.EventUpgrades[u.Id]
        if type(dir) == "table" and not dir.Disabled then
            local tier = isfn(G.EventUpgradeCmds, "GetTier") and gval(G.EventUpgradeCmds.GetTier, u.Id) or 0
            local maxTier = type(dir.TierPowers) == "table" and #dir.TierPowers or 5
            if tier < maxTier and type(dir.TierCosts) == "table" and dir.TierCosts[tier + 1] then
                local cost = nil
                pcall(function()
                    cost = dir.TierCosts[tier + 1]._data and dir.TierCosts[tier + 1]._data._am or dir.TierCosts[tier + 1]:GetAmount()
                end)
                if type(cost) == "number" and cost <= treats then
                    return u.Id
                end
            end
        end
    end
    return nil
end

local function checkAndRunTreatUpgrades()
    if not CFG.AutoTreatUpgrades or not inEvent() or state.excursion ~= nil then return end
    local now = os.clock()
    if now < state.nextTreatUpgradeAt then return end

    local treats = currency(K.TREATS)
    if treats <= 0 then
        state.nextTreatUpgradeAt = now + 120
        return
    end

    local firstCheck = getAffordableUpgrade(treats)
    if not firstCheck then
        state.nextTreatUpgradeAt = now + 180
        return
    end

    state.excursion = "upgrades"
    local savedPos = playerPos()
    local stand = getMachineStand(K.UPGRADE_MACHINE)

    pcall(function()
        if stand then
            teleportTo(stand)
            task.wait(0.6)
        end
        local boughtCount = 0
        while state.alive and boughtCount < 15 do
            local curTreats = currency(K.TREATS)
            local upgId = getAffordableUpgrade(curTreats)
            if not upgId then break end

            local ok, res = netInvoke("EventUpgrades: Purchase", upgId)
            if not (ok and res == true) then break end

            boughtCount = boughtCount + 1
            task.wait(0.4)
        end
    end)

    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil

    -- Đặt đúng 10 phút (600 giây) mới quay lại kiểm tra máy nâng cấp
    state.nextTreatUpgradeAt = os.clock() + (CFG.UpgradeCooldown or 600)
end

-- ================= AUTO COMBINE "HUGE BAT HOODIE BUNNY" & CLAIM =================
local function flagValue(name)
    if not (name and type(G.FFlags) == "table" and type(G.FFlags.Keys) == "table" and type(G.FFlags.Get) == "function") then return nil end
    local key = G.FFlags.Keys[name]
    return key and gval(G.FFlags.Get, key) or nil
end

local function combineDir()
    local all = type(G.Directory) == "table" and rawget(G.Directory, "HalloweenCraftingMachines") or nil
    if all == nil and type(G.Directory) == "table" then
        local ok, v = pcall(function() return G.Directory.HalloweenCraftingMachines end)
        all = ok and v or nil
    end
    return type(all) == "table" and all[K.COMBINE_ID] or nil
end

local function ingredientNeed(dir, ing)
    local amount = tonumber(flagValue(ing.AmountFFlag)) or tonumber(ing.Amount) or 1
    local need = math.max(1, math.ceil(amount))
    if not ing.NoDiscount and type(dir.IngredientAmount) == "function" then
        local ok, v = pcall(dir.IngredientAmount, nil, need)
        if ok and type(v) == "number" and v == v then need = math.max(1, math.ceil(v)) end
    end
    return need
end

local function ingredientHave(dir, ing)
    local okC, have = gcall(function()
        local item = ing.Item:Clone()
        local n = item:CountAny()
        if dir.AnyVariantInputs and item:IsA("Pet") then
            for _, v in ipairs({ "Golden", "Rainbow" }) do
                local c = item:Clone()
                if c["CanBe" .. v](c) then c["Set" .. v](c) n += c:CountAny() end
            end
            if item:CanBeShiny() then
                for _, v in ipairs({ "Normal", "Golden", "Rainbow" }) do
                    local c = item:Clone()
                    if v == "Normal" or (v == "Golden" and c:CanBeGolden()) or (v == "Rainbow" and c:CanBeRainbow()) then
                        if v ~= "Normal" then c["Set" .. v](c) end
                        c:SetShiny(true)
                        n += c:CountAny()
                    end
                end
            end
        end
        return n
    end)
    return okC and tonumber(have) or 0
end

local function checkAndRunCombine()
    if not CFG.AutoCombine or not inEvent() or state.excursion ~= nil then return end
    local now = os.clock()
    if now < state.nextCombineAt then return end

    local dir = combineDir()
    if not dir or type(dir.Recipes) ~= "table" then return end

    local okQ, queue = netInvoke("HalloweenCraftingMachine_GetQueue")
    if not okQ or type(queue) ~= "table" then
        state.nextCombineAt = now + 30
        return
    end

    local queuedByIndex, readyClaims = {}, {}
    for _, e in ipairs(queue) do
        if type(e) == "table" and (e.MachineId == nil or e.MachineId == dir._id) and e.RecipeIndex then
            queuedByIndex[e.RecipeIndex] = e
            if (tonumber(e.Remaining) or 0) <= 0 and e.UID then table.insert(readyClaims, e) end
        end
    end

    local targetRecipeIndex = nil
    local targetReady = false
    for idx, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result and type(r.Ingredients) == "table" then
            local resName = tostring(gval(function() return r.Result:GetId() end) or "")
            if string.lower(resName) == string.lower(CFG.TargetCombineRecipe) then
                targetRecipeIndex = idx
                if not queuedByIndex[idx] then
                    local allEnough = true
                    for _, ing in ipairs(r.Ingredients) do
                        if ingredientHave(dir, ing) < ingredientNeed(dir, ing) then
                            allEnough = false
                            break
                        end
                    end
                    targetReady = allEnough
                end
                break
            end
        end
    end

    if #readyClaims == 0 and not targetReady then
        state.nextCombineAt = now + (CFG.CombineCooldown or 60)
        return
    end

    state.excursion = "combine"
    local savedPos = playerPos()
    pcall(function()
        local stand = getMachineStand(K.COMBINE_MACHINE)
        if stand then
            teleportTo(stand)
            task.wait(0.8)
        end
        for _, claim in ipairs(readyClaims) do
            netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            task.wait(0.5)
        end
        if targetReady and targetRecipeIndex then
            netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, targetRecipeIndex)
            task.wait(0.5)
        end
    end)
    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (CFG.CombineCooldown or 60)
end

-- ================= AUTO BUFFS (COOLDOWN CHỐNG SPAM) =================
local function runDelayedBuffs(activeZoneNumber)
    local bCfg = CFG.AutoBuffs
    if not bCfg then return end
    local now = os.clock()
    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    -- Daycare (120s)
    if bCfg.Daycare and now > state.nextDaycareAt then
        pcall(function() netInvoke("Daycare: Claim") end)
        local freeSlots = 30
        pcall(function() freeSlots = math.max(0, (gval(G.DaycareCmds.GetMaxSlots) or 30) - (gval(G.DaycareCmds.GetUsedSlots) or 0)) end)
        if freeSlots > 0 and type(inv.Pet) == "table" then
            for uid, data in pairs(inv.Pet) do
                if type(data) == "table" and type(data.id) == "string" and not data.lk then
                    local idLower = string.lower(data.id)
                    if not idLower:find("huge") and not idLower:find("titanic") and (tonumber(data._am) or 1) > 50 then
                        netInvoke("Daycare: Enroll", { [uid] = math.min(freeSlots, 10) })
                        break
                    end
                end
            end
        end
        state.nextDaycareAt = now + 120
    end

    -- Toys (900s = 15 phút)
    if bCfg.Toys and now > state.nextToyAt then
        pcall(function() netInvoke("ToyBall_Consume") end)
        pcall(function() netInvoke("ToyBone_Consume") end)
        pcall(function() netInvoke("SqueakyToy_Consume") end)
        state.nextToyAt = now + 900
    end

    -- Fruits (300s = 5 phút)
    if bCfg.Fruits and now > state.nextFruitAt and type(inv.Fruit) == "table" then
        for uid, data in pairs(inv.Fruit) do
            if type(data) == "table" and (tonumber(data._am) or 1) > 0 then
                netFire("Fruits: Consume", uid, 20)
            end
        end
        state.nextFruitAt = now + 300
    end

    -- Potions (900s = 15 phút)
    if bCfg.Potions and now > state.nextPotionAt and type(inv.Potion) == "table" then
        for uid, data in pairs(inv.Potion) do
            if type(data) == "table" and type(data.id) == "string" and (tonumber(data._am) or 1) > 0 then
                local pName = string.lower(data.id)
                if pName:find("coin") or pName:find("luck") or pName:find("damage") or pName:find("speed") or pName:find("treasure") then
                    netFire("Potions: Consume", uid)
                end
            end
        end
        state.nextPotionAt = now + 900
    end

    -- Cắm Cờ (300s = 5 phút)
    if bCfg.Flags and activeZoneNumber and now > state.nextFlagAt and type(inv.Misc) == "table" then
        for _, prefName in ipairs(bCfg.PreferredFlags or {}) do
            local foundFlagUid = nil
            for uid, data in pairs(inv.Misc) do
                if type(data) == "table" and data.id == prefName and (tonumber(data._am) or 1) > 0 then
                    foundFlagUid = uid
                    break
                end
            end
            if foundFlagUid then
                local zoneId = "Main_" .. tostring(activeZoneNumber)
                pcall(function() netInvoke("Flags: Consume", prefName, foundFlagUid, 1) end)
                pcall(function() netInvoke("FlexibleFlags_Consume", prefName, foundFlagUid, zoneId) end)
                state.nextFlagAt = now + 300
                break
            end
        end
    end
end

-- ================= AUTO MAIL ALL HUGE + 4 CONSUMABLES (TIER 1-3) =================
local function checkAndRunAutoMail()
    local mCfg = CFG.Mail
    if not (mCfg and mCfg.Enabled) then return end
    if type(mCfg.Recipient) ~= "string" or mCfg.Recipient == "" or mCfg.Recipient == "DienTenAccNhanVaoDay" then return end
    if string.lower(mCfg.Recipient) == string.lower(LocalPlayer.Name) then return end
    if currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then return end

    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    local wantedCons = {}
    for _, name in ipairs(mCfg.Consumables or {}) do wantedCons[string.lower(name)] = true end
    local wantedTiers = {}
    for _, t in ipairs(mCfg.ConsumableTiers or {1, 2, 3}) do wantedTiers[tonumber(t)] = true end

    local equippedSet = {}
    if isfn(G.PetCmds, "GetEquippedItems") then
        local okE, eq = gcall(G.PetCmds.GetEquippedItems)
        if okE and type(eq) == "table" then
            for _, it in pairs(eq) do
                local okU, uid = pcall(function() return it:GetUID() end)
                if okU and uid then equippedSet[uid] = true end
            end
        end
    end

    local toSend = {}

    -- Huge
    if mCfg.SendAllHuges and type(inv.Pet) == "table" then
        for uid, data in pairs(inv.Pet) do
            if type(data) == "table" and type(data.id) == "string" then
                if string.find(string.lower(data.id), "huge", 1, true) and not data.lk then
                    local amt = tonumber(data._am) or 1
                    if equippedSet[uid] then netFire("Pets_UnequipByUID", uid) task.wait(0.2) end
                    table.insert(toSend, { Category = "Pet", UID = uid, Amount = amt })
                end
            end
        end
    end

    -- Consumables Tier 1..3
    if type(inv.Consumable) == "table" then
        for uid, data in pairs(inv.Consumable) do
            if type(data) == "table" and type(data.id) == "string" and not data.lk then
                local idLower = string.lower(data.id)
                local tier = tonumber(data.tn) or 1
                local amt = tonumber(data._am) or 1
                if wantedCons[idLower] and wantedTiers[tier] and amt >= (mCfg.MinConsumableStack or 4) then
                    table.insert(toSend, { Category = "Consumable", UID = uid, Amount = amt })
                end
            end
        end
    end

    for _, item in ipairs(toSend) do
        if not state.alive or currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then break end
        netInvoke("Mailbox: Send", mCfg.Recipient, "Kaitun Halloween", item.Category, item.UID, item.Amount)
        task.wait(1.5)
    end
end

-- ================= VÒNG LẶP CHÍNH (ĐIỀU PHỐI CHU TRÌNH TOÀN NĂNG) =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if not CFG.Enabled then return end
            if not ensureInHalloweenEvent() then return end
            if state.excursion ~= nil then return end

            -- 1. ƯU TIÊN SỐ 1: SECRET ROOM EGG
            local srOpen = isSecretRoomOpen()
            local now = os.clock()
            local inSecretCooldown = now < state.secretCooldownUntil

            if srOpen and not inSecretCooldown then
                local p = playerPos()
                -- Bay thẳng vào vị trí đứng mở trứng bên trong Secret Room
                if not p or dist(p, K.SECRET_STAND) > 15 then
                    teleportTo(K.SECRET_STAND)
                    task.wait(0.4)
                end

                local srEgg = findCustomEggById(K.SECRET_EGG_ID)
                if srEgg then
                    local okH, amt, outOfCoins = executeHatch(srEgg)
                    if outOfCoins then
                        -- Hết xu mở Secret Egg -> Ra bãi cao nhất farm đúng 8 phút (480s)
                        state.secretCooldownUntil = os.clock() + (CFG.SecretFarmDuration or 480)
                    end
                end
                return
            end

            -- 2. TIẾN TRÌNH 8 ZONE (KHI SECRET ĐÓNG HOẶC ĐANG TRONG 8 PHÚT FARM BÙ TIỀN)
            tryUnlockNextZone()
            local currentZone = bestUnlockedZone()
            local zoneData = K.ZONES[currentZone]

            -- Xác định xem Zone hiện tại có cần mở trứng không
            local needHatch = false
            if currentZone <= 7 then
                if (state.zoneHatchCounts[currentZone] or 0) < (CFG.First7ZonesHatchTimes or 5) then
                    needHatch = true
                end
            else
                -- Khu 8 mở liên tục
                needHatch = true
            end

            -- Nếu đang trong 8 phút cày xu cho Secret Egg thì dồn 100% xu (không mở trứng Zone thường)
            if srOpen and inSecretCooldown then
                needHatch = false
            end

            -- Đưa nhân vật tới điểm đứng viền (nếu đang mở trứng) hoặc tâm bãi farm (nếu chỉ cày xu)
            local standTarget = getOptimalZoneStandPos(currentZone, needHatch)
            if standTarget then
                local p = playerPos()
                if not p or dist(p, standTarget) > 12 then
                    teleportTo(standTarget)
                    task.wait(0.3)
                end
            end

            -- Điều Pet đánh quái trong khu vực
            farmZoneBreakables(currentZone)

            -- Thực thi mở trứng nếu khu vực cần mở
            if needHatch then
                local eggInfo = findCustomEggById(zoneData.Egg)
                if eggInfo then
                    local okH, amt = executeHatch(eggInfo)
                    if okH and currentZone <= 7 then
                        state.zoneHatchCounts[currentZone] = (state.zoneHatchCounts[currentZone] or 0) + 1
                    end
                end
            end
        end)
        task.wait(math.max(0.2, CFG.HatchDelay or 0.45))
    end
end)

-- Vòng lặp nhặt Orbs (0.15s)
task.spawn(function()
    while state.alive do
        if CFG.Enabled and inEvent() then
            pcall(collectOrbsTick)
        end
        task.wait(0.15)
    end
end)

-- Vòng lặp Treat Upgrades, Ghép Huge & Buffs (4s)
task.spawn(function()
    while state.alive do
        pcall(function()
            if CFG.Enabled and inEvent() then
                checkAndRunTreatUpgrades()
                checkAndRunCombine()
                runDelayedBuffs(bestUnlockedZone())
            end
        end)
        task.wait(4)
    end
end)

-- Vòng lặp Auto Mail (120s)
task.spawn(function()
    while state.alive do
        if CFG.Enabled then pcall(checkAndRunAutoMail) end
        task.wait(CFG.Mail and CFG.Mail.CheckInterval or 120)
    end
end)

genv.HG_Kaitun = {
    Stop = function()
        state.alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
    end
}