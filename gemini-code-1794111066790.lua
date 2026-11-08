-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (100% HEADLESS - GITHUB READY)
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.HG_Kaitun) == "table" and type(genv.HG_Kaitun.Stop) == "function" then
    pcall(genv.HG_Kaitun.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN (TỰ THIẾT LẬP TẠI ĐÂY) =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Chu trình mở trứng 8 Zone
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (Max trứng/lần)
    HatchDelay = 0.5,                    -- Tốc độ mở trứng

    -- 2. Nâng cấp sự kiện (Treat Upgrades)
    AutoTreatUpgrades = true,

    -- 3. Ghép Huge Bat Hoodie Bunny
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",

    -- 4. Auto Mail
    Mail = {
        Enabled = true,
        Recipient = "DienTenAccNhanVaoDay", -- ⚠️ ĐIỀN USERNAME ACC NHẬN
        CheckInterval = 120,                -- Quét mỗi 120s
        MinDiamondsToKeep = 50000,          -- Giữ lại tối thiểu 50k Diamonds làm phí
        SendAllHuges = true,                -- Tự động gửi tất cả Huge có trong kho
        MinConsumableStack = 4,             -- Gom đủ từ 4 cái trở lên mới gửi 1 lần
        ConsumableTiers = { 1, 2, 3 },      -- Gửi từ Tier 1 đến Tier 3
        Consumables = {
            "Halloween Games Lucky Charm",
            "Halloween Games Treat Magnet",
            "Halloween Games Broomstick",
            "Halloween Games Lantern",
        },
    },

    -- 5. Auto Buffs (Chống Spam, chỉ dùng lại khi hết thời gian)
    AutoBuffs = {
        Daycare = true,
        Toys = true,                        -- Cooldown 900s (15 phút)
        Fruits = true,                      -- Cooldown 300s (5 phút)
        Potions = true,                     -- Cooldown 900s (15 phút)
        Flags = true,                       -- Cooldown 300s (5 phút)
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

local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HG-KAITUN] " .. (ok and msg or tostring(fmt)))
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
    MachineCmds       = req("Library.Client.MachineCmds"),
}

-- ================= DỮ LIỆU TỌA ĐỘ CHUẨN XÁC TỪ HALLOWEEN.LUA =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    UPGRADE_MACHINE = "HalloweenGamesUpgradeMachine",
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    -- Toàn bộ Pos lấy nguyên mẫu 100% từ mảng K.ZONES trong file halloween.lua
    ZONES = {
        [1] = { Number = 1, Name = "#1 Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60400390625, 16.19723892211914, -3939.5205078125) },
        [2] = { Number = 2, Name = "#2 Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83203125, 16.239492416381836, -3940.37158203125) },
        [3] = { Number = 3, Name = "#3 Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.5517578125, 16.394588470458984, -3941.1513671875) },
        [4] = { Number = 4, Name = "#4 Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52197265625, 16.417028427124023, -3939.434814453125) },
        [5] = { Number = 5, Name = "#5 Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.740234375, 16.23948860168457, -3939.2265625) },
        [6] = { Number = 6, Name = "#6 Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.5283203125, 16.917938232421875, -3910.60400390625) },
        [7] = { Number = 7, Name = "#7 Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.3916015625, 16.960006713867188, -3911.231689453125) },
        [8] = { Number = 8, Name = "#8 Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50146484375, 16.917938232421875, -3910.71044921875) },
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
    -- Cooldown Buffs
    nextFlagAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextDaycareAt = 0,
    lastZoneTeleport = 0,
}

local connections = {}
local restoreFns = {}

-- ================= TIỆN ÍCH MẠNG & NHÂN VẬT =================
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

local function shorten(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
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

-- ================= HOOKS TỐC ĐỘ, CHẶN ANIMATION, ANTI-AFK =================
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

-- ================= QUẢN LÝ INSTANCE & ZONE UNLOCK =================
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
    log("Đang vào cổng Halloween Games...")
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
        log("MỞ KHÓA THÀNH CÔNG Zone %d! Lập tức chuyển sang cày Zone mới.", nextZ)
        return true
    end
    return false
end

-- ================= HATCH TRỨNG (LẤY MAX COUNT CHUẨN THEO RANK) =================
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

local function hatchZoneEgg(egg)
    if not egg or not egg.uid then return false end
    local amount = getAccountMaxHatch(egg)

    local ok, res, msg = netInvoke("CustomEggs_Hatch", egg.uid, amount)
    if ok and res == true then
        state.totalEggsHatched += amount
        return true, amount
    end

    local errText = string.lower(tostring(msg or res or ""))
    -- Nếu thiếu xu cho 1 full batch, tự chia đôi để mở tối đa số lượng có thể
    if errText:find("afford") or errText:find("enough") or errText:find("coin") then
        local tryAmt = amount
        while state.alive and tryAmt > 1 do
            tryAmt = math.max(1, math.floor(tryAmt / 2))
            local ok2, res2 = netInvoke("CustomEggs_Hatch", egg.uid, tryAmt)
            if ok2 and res2 == true then
                state.totalEggsHatched += tryAmt
                return true, tryAmt
            end
        end
    end
    return false, 0
end

-- ================= HỆ THỐNG FARM BREAKABLES & HÚT ORB =================
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

-- Hook Upvalue nhặt Orbs tức thì
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

-- ================= AUTO TREAT UPGRADES (NÂNG CẤP SỰ KIỆN) =================
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

local function checkAndRunTreatUpgrades()
    if not CFG.AutoTreatUpgrades or not inEvent() or state.excursion ~= nil then return end
    local treats = currency(K.TREATS)
    if treats <= 0 then return end

    local affordableUpgrade = nil
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
                    affordableUpgrade = u.Id
                    break
                end
            end
        end
    end

    if not affordableUpgrade then return end

    state.excursion = "upgrades"
    local savedPos = playerPos()