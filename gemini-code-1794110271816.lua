-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (100% HEADLESS)
-- Tối ưu hóa: Auto Mail (1-3), Delay Buffs (Toys/Potions/Flags), 
-- Secret Room (Vào cửa -> Tới Trứng), Farm Bãi, Combine, Treat Upgrades.
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.HG_Kaitun) == "table" and type(genv.HG_Kaitun.Stop) == "function" then
    pcall(genv.HG_Kaitun.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN TỰ ĐỘNG =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,
    ShowDebugMonitor = true,

    -- 1. Cấu hình Secret Room Egg & Chu trình 8 khu
    SecretFarmDuration = 480,            -- 8 phút (480 giây) ra khu farm cày xu khi hết tiền mở Secret Egg
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (Max trứng/lần)
    HatchDelay = 0.45,                   -- Tốc độ mở trứng

    -- 2. Cấu hình Combine-o-Matic
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny", 

    -- 3. Cấu hình Treat Upgrades (Nâng cấp sự kiện)
    AutoUpgrades = true,                 -- Tự động mua nâng cấp sự kiện
    -- Các nâng cấp ưu tiên (giống list trong halloween.lua)
    UpgradeOrder = { "HalloweenGamesEggLuck", "HalloweenGamesCoinFinder", "HalloweenGamesHugeLuck", "HalloweenGamesGolden", "HalloweenGamesRainbow", "HalloweenGamesShiny" },

    -- 4. Cấu hình Auto Mail (Huge & Consumables Tier 1-3)
    Mail = {
        Enabled = true,
        Recipient = "DienTenAccNhanVaoDay", -- ⚠️ ĐIỀN TÊN ACC NHẬN
        CheckInterval = 120,                -- Quét mỗi 120s
        MinDiamondsToKeep = 50000,
        SendAllHuges = true,
        MinConsumableStack = 4,             -- Gửi khi stack có >= 4 món
        ConsumableTiers = { 1, 2, 3 },      
        Consumables = {
            "Halloween Games Lucky Charm",
            "Halloween Games Treat Magnet",
            "Halloween Games Broomstick",
            "Halloween Games Lantern",
        },
    },

    -- 5. Cấu hình Buffs (Sử dụng Delay chống spam)
    AutoBuffs = {
        Daycare = true,
        Toys = true,                      
        Fruits = true,                    
        Potions = true,                   
        Flags = true,                     
        PreferredFlags = { "Coins Flag", "Fortune Flag", "Hasty Flag", "Magnet Flag" },
    },
}
local CFG = genv.KaitunConfig

-- ================= KHỞI TẠO & HẠ QUYỀN THREAD =================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
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

-- ================= LOAD MODULES =================
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
    PotionCmds        = req("Library.Client.PotionCmds"),
    FruitCmds         = req("Library.Client.FruitCmds"),
    ZoneFlagCmds      = req("Library.Client.ZoneFlagCmds"),
    BuffCmds          = req("Library.Client.BuffCmds"),
}

-- ================= DỮ LIỆU SỰ KIỆN =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    COMBINE_ID      = "HalloweenGamesCombine",
    SECRET_EGG_ID   = "Secret Room Egg",
    -- Tọa độ cổng vào Secret Room (bên ngoài)
    SECRET_DOOR     = Vector3.new(-6679, 2746.7, -3701.9), 
    -- Tọa độ bên trong phòng cạnh quả trứng
    SECRET_STAND    = Vector3.new(-6675.58, 2117.07, -3683.72),
    ZONES = {
        [1] = { Number = 1, Name = "Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60, 16.20, -3939.52), EggPos = Vector3.new(-5315.25, 20.87, -3914.00) },
        [2] = { Number = 2, Name = "Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83, 16.24, -3940.37), EggPos = Vector3.new(-5496.82, 20.31, -3913.00) },
        [3] = { Number = 3, Name = "Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.55, 16.39, -3941.15), EggPos = Vector3.new(-5657.75, 20.70, -3913.00) },
        [4] = { Number = 4, Name = "Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52, 16.42, -3939.43), EggPos = Vector3.new(-5810.95, 20.30, -3915.00) },
        [5] = { Number = 5, Name = "Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.74, 16.24, -3939.23), EggPos = Vector3.new(-5984.55, 20.30, -3917.00) },
        [6] = { Number = 6, Name = "Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.53, 16.92, -3910.60), EggPos = Vector3.new(-6340.73, 20.56, -3884.65) },
        [7] = { Number = 7, Name = "Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.39, 16.96, -3911.23), EggPos = Vector3.new(-6520.73, 20.78, -3885.90) },
        [8] = { Number = 8, Name = "Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50, 16.92, -3910.71), EggPos = Vector3.new(-6680.73, 20.58, -3886.40) },
    }
}

local state = {
    alive = true,
    status = "Đang tải...",
    secretCooldownUntil = 0,      
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 }, 
    totalEggsOpened = 0,
    combinesStarted = 0,
    mailsSent = 0,
    upgradesBought = 0,
    -- Quản lý cooldown Buffs
    nextFlagAt = 0,
    nextPotionAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
}
local connections = {}
local restoreFns = {}

-- ================= HÀM TIỆN ÍCH =================
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

local function currency(id)
    if isfn(G.CurrencyCmds, "Get") then
        local v = gval(G.CurrencyCmds.Get, id)
        if type(v) == "number" then return v end
    end
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
    if type(hookfunction) == "function" and isfn(G.PlayerPet, "CalculateSpeedMultiplier") then
        local orig
        orig = hookfunction(G.PlayerPet.CalculateSpeedMultiplier, function(...)
            if state.alive then return math.huge end
            return orig(...)
        end)
    end
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

-- ================= ZONE & SECRET ROOM =================
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
    state.status = "Đang vào cổng Halloween Games..."
    if isfn(G.Instancing, "Enter") then
        gcall(G.Instancing.Enter, K.INSTANCE_ID)
    end
    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 20 do
        if inEvent() then task.wait(1) return true end
        task.wait(0.5)
    end
    return inEvent()
end

local function bestUnlockedZone()
    if isfn(G.InstanceZone, "GetMaximumOwnedZoneNumber") then
        local n = gval(G.InstanceZone.GetMaximumOwnedZoneNumber)
        if type(n) == "number" and n >= 1 then return math.clamp(n, 1, 8) end
    end
    local best = 1
    for i = 2, 8 do
        local ok, v = pcall(function() return gval(G.InstanceZone.IsUnlocked, i) end)
        if ok and v == true then best = i end
    end
    return best
end

local function tryUnlockNextZoneImmediately()
    local best = bestUnlockedZone()
    if best >= 8 then return false end
    local nextZone = best + 1
    local ok, res = netInvoke("InstanceZones_RequestPurchase", K.INSTANCE_ID, nextZone)
    if ok and res == true then
        log("Đã mở khóa Zone %d!", nextZone)
        return true
    end
    return false
end

-- ================= HATCH LOGIC =================
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
                hatchable = e._hatchable,
                maxCount = e._maxEggCount,
                model = e._model,
            }
        end
    end
    return nil
end

local function isSecretRoomAvailable()
    local srEgg = findCustomEggById(K.SECRET_EGG_ID)
    if srEgg and srEgg.model and srEgg.model.Parent then
        return true, srEgg
    end
    local things = workspace:FindFirstChild("__THINGS")
    local active = things and things:FindFirstChild("__INSTANCE_CONTAINER") and things.__INSTANCE_CONTAINER:FindFirstChild("Active")
    local srModel = active and active:FindFirstChild("HalloweenGamesSecretRoom")
    if srModel then return true, srEgg end
    return false, nil
end

local function getAccountMaxHatchForEgg(egg)
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

local function executeMaxHatch(egg)
    if not egg or not egg.uid then return false, "no_egg", 0 end
    local maxCount = getAccountMaxHatchForEgg(egg)

    local ok, res, msg = netInvoke("CustomEggs_Hatch", egg.uid, maxCount)
    if ok and res == true then
        state.totalEggsOpened += maxCount
        return true, "ok", maxCount
    end

    local errText = string.lower(tostring(msg or res or ""))
    local isOutOfCoins = errText:find("afford") or errText:find("enough") or errText:find("coin")
    
    if isOutOfCoins then
        -- Chia đôi nếu thiếu xu
        local tryAmt = maxCount
        while state.alive and tryAmt > 1 do
            tryAmt = math.max(1, math.floor(tryAmt / 2))
            local ok2, res2 = netInvoke("CustomEggs_Hatch", egg.uid, tryAmt)
            if ok2 and res2 == true then
                state.totalEggsOpened += tryAmt
                return true, "ok_partial", tryAmt
            end
        end
        return false, "no_coins", 0
    elseif errText:find("locked") or errText:find("secret") or errText:find("far") or errText:find("exist") then
        return false, "room_locked_or_far", 0
    elseif errText:find("quickly") then
        return false, "rate_limit", 0
    end
    return false, tostring(msg or res), 0
end

local function getZoneEdgeStandPos(zoneNumber)
    local z = K.ZONES[zoneNumber]
    if not z then return nil end
    local dirToFarm = (z.Pos - z.EggPos)
    if dirToFarm.Magnitude > 1 then
        return z.EggPos + dirToFarm.Unit * 18 + Vector3.new(0, 2.5, 0)
    end
    return z.Pos
end

-- ================= FARM BÃI & HÚT ORB =================
local function getPetEuids()
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

local function farmZoneBreakables(zoneNumber)
    local targetUids = zoneBreakables(zoneNumber)
    if #targetUids == 0 then return end
    local pets = getPetEuids()
    if #pets == 0 then return end

    netUnreliable("Breakables_PlayerDealDamage", targetUids[1])
    local map = {}
    for i, euid in ipairs(pets) do
        map[euid] = targetUids[((i - 1) % #targetUids) + 1]
    end
    netFire("Breakables_JoinPetBulk", map)
end

-- ================= AUTO CÁC TÍNH NĂNG KHÁC =================
local function checkAndRunCombine()
    if not CFG.AutoCombine or not inEvent() then return end
    -- Đọc từ Dump Json Data của game: HalloweenCraftingMachines
    local all = type(G.Directory) == "table" and rawget(G.Directory, "HalloweenCraftingMachines")
    if type(all) ~= "table" then return end
    local dir = all[K.COMBINE_ID]
    if not dir or type(dir.Recipes) ~= "table" then return end

    -- Tự auto claim hàng đợi
    local okQ, queue = netInvoke("HalloweenCraftingMachine_GetQueue")
    if okQ and type(queue) == "table" then
        for _, e in ipairs(queue) do
            if type(e) == "table" and e.UID and (tonumber(e.Remaining) or 0) <= 0 then
                netInvoke("HalloweenCraftingMachine_Claim", e.UID)
            end
        end
    end
    -- Auto start (Bỏ qua khâu check vật phẩm vì khi gửi yêu cầu nếu thiếu game sẽ tự báo lỗi)
    -- Giả sử Recipe của Huge Bat Hoodie Bunny là 1 hoặc 2. Script sẽ duyệt qua và thử StartCraft cái có tên khớp.
    for idx, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result then
            local resName = tostring(gval(function() return r.Result:GetId() end) or "")
            if resName:lower() == CFG.TargetCombineRecipe:lower() then
                netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, idx)
            end
        end
    end
end

local function checkAndRunTreatUpgrades()
    if not CFG.AutoUpgrades or not inEvent() then return end
    local treats = currency(K.TREATS)
    for _, upgId in ipairs(CFG.UpgradeOrder) do
        local dir = G.EventUpgrades and G.EventUpgrades[upgId]
        if type(dir) == "table" and not dir.Disabled then
            local tier = isfn(G.EventUpgradeCmds, "GetTier") and gval(G.EventUpgradeCmds.GetTier, upgId) or 0
            local maxTier = type(dir.TierPowers) == "table" and #dir.TierPowers or 5
            if tier < maxTier then
                local cost = 0
                if type(dir.TierCosts) == "table" and dir.TierCosts[tier + 1] then
                    pcall(function()
                        cost = dir.TierCosts[tier + 1]._data and dir.TierCosts[tier + 1]._data._am or dir.TierCosts[tier + 1]:GetAmount()
                    end)
                end
                if type(cost) == "number" and cost <= treats then
                    local ok, res = netInvoke("EventUpgrades: Purchase", upgId)
                    if ok and res == true then
                        state.upgradesBought += 1
                        return -- Mua xong 1 cái thì thoát để lần lặp sau mua tiếp
                    end
                end
            end
        end
    end
end

local function runDelayedBuffs()
    if not CFG.AutoBuffs then return end
    local now = os.clock()
    local s = isfn(G.Save, "Get") and gval(G.Save.Get)
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    -- 1. Daycare (Claim & Enroll tự động)
    if CFG.AutoBuffs.Daycare then
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
    end

    -- 2. Toys (Chỉ cắn lại khi đã hết tác dụng ~ 15 phút, set an toàn 600s)
    if CFG.AutoBuffs.Toys and now > state.nextToyAt then
        pcall(function() netInvoke("ToyBall_Consume") end)
        pcall(function() netInvoke("ToyBone_Consume") end)
        pcall(function() netInvoke("SqueakyToy_Consume") end)
        state.nextToyAt = now + 600
    end

    -- 3. Fruits (Mỗi quả có tác dụng dài, set an toàn 300s)
    if CFG.AutoBuffs.Fruits and now > state.nextFruitAt and type(inv.Fruit) == "table" then
        for uid, data in pairs(inv.Fruit) do
            if type(data) == "table" and (tonumber(data._am) or 1) > 0 then
                netFire("Fruits: Consume", uid, 20)
            end
        end
        state.nextFruitAt = now + 300
    end

    -- 4. Potions (Set an toàn 1800s - 30p)
    if CFG.AutoBuffs.Potions and now > state.nextPotionAt and type(inv.Potion) == "table" then
        for uid, data in pairs(inv.Potion) do
            if type(data) == "table" and type(data.id) == "string" and (tonumber(data._am) or 1) > 0 then
                local pName = string.lower(data.id)
                if pName:find("coin") or pName:find("luck") or pName:find("damage") or pName:find("speed") or pName:find("treasure") then
                    netFire("Potions: Consume", uid)
                end
            end
        end
        state.nextPotionAt = now + 1800
    end

    -- 5. Cắm Cờ (Mỗi cờ tồn tại 5 phút, set 300s)
    local activeZone = bestUnlockedZone()
    if CFG.AutoBuffs.Flags and activeZone and now > state.nextFlagAt and type(inv.Misc) == "table" then
        for _, prefName in ipairs(CFG.AutoBuffs.PreferredFlags or {}) do
            local foundFlagUid = nil
            for uid, data in pairs(inv.Misc) do
                if type(data) == "table" and data.id == prefName and (tonumber(data._am) or 1) > 0 then
                    foundFlagUid = uid
                    break
                end
            end
            if foundFlagUid then
                local zoneId = "Main_" .. tostring(activeZone)
                pcall(function() netInvoke("Flags: Consume", prefName, foundFlagUid, 1) end)
                pcall(function() netInvoke("FlexibleFlags_Consume", prefName, foundFlagUid, zoneId) end)
                state.nextFlagAt = now + 300
                break
            end
        end
    end
end

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
                    table.insert(toSend, { Category = "Pet", UID = uid, Amount = amt, Label = data.id })
                end
            end
        end
    end

    -- Consumables
    if type(inv.Consumable) == "table" then
        for uid, data in pairs(inv.Consumable) do
            if type(data) == "table" and type(data.id) == "string" and not data.lk then
                local idLower = string.lower(data.id)
                local tier = tonumber(data.tn) or 1
                local amt = tonumber(data._am) or 1
                if wantedCons[idLower] and wantedTiers[tier] and amt >= (mCfg.MinConsumableStack or 4) then
                    table.insert(toSend, { Category = "Consumable", UID = uid, Amount = amt, Label = string.format("%s (T%d x%d)", data.id, tier, amt) })
                end
            end
        end
    end

    for _, item in ipairs(toSend) do
        if not state.alive or currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then break end
        local ok, res = netInvoke("Mailbox: Send", mCfg.Recipient, "Kaitun Halloween", item.Category, item.UID, item.Amount)
        if ok and res == true then
            state.mailsSent += 1
            log("Auto Mail: Đã gửi %s", item.Label)
        end
        task.wait(1.5)
    end
end

-- ================= BẢNG DEBUG =================
local debugLbl = nil
if CFG.ShowDebugMonitor then
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "HG_Kaitun_Monitor"
        sg.ResetOnSpawn = false
        sg.Parent = (type(gethui) == "function" and gethui()) or CoreGui

        local frame = Instance.new("Frame", sg)
        frame.Size = UDim2.new(0, 310, 0, 140)
        frame.Position = UDim2.new(0, 10, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        local st = Instance.new("UIStroke", frame) st.Color = Color3.fromRGB(255, 140, 0) st.Thickness = 1
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

        debugLbl = Instance.new("TextLabel", frame)
        debugLbl.Size = UDim2.new(1, -16, 1, -12)
        debugLbl.Position = UDim2.new(0, 8, 0, 6)
        debugLbl.BackgroundTransparency = 1
        debugLbl.Font = Enum.Font.Code
        debugLbl.TextSize = 11
        debugLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        debugLbl.TextXAlignment = Enum.TextXAlignment.Left
        debugLbl.TextYAlignment = Enum.TextYAlignment.Top
    end)
end

-- ================= VÒNG LẶP CHÍNH =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if not CFG.Enabled then return end
            if not ensureInHalloweenEvent() then return end

            tryUnlockNextZoneImmediately()
            local bestZone = bestUnlockedZone()

            -- 1. Ưu tiên Secret Room
            local secretOpen, secretEgg = isSecretRoomAvailable()
            local now = os.clock()
            local inSecretCooldown = now < state.secretCooldownUntil

            if secretOpen and not inSecretCooldown then
                local p = playerPos()
                -- Bước 1: Dịch chuyển đến trước cửa Secret Room (để load map phòng)
                if not p or dist(p, K.SECRET_STAND) > 15 then
                    state.status = "Secret Room: Di chuyển đến cửa phòng..."
                    teleportTo(K.SECRET_DOOR)
                    task.wait(0.5)
                    teleportTo(K.SECRET_STAND, K.SECRET_EGG_POS)
                    task.wait(0.5)
                    secretOpen, secretEgg = isSecretRoomAvailable()
                end

                if secretEgg then
                    local okHatch, reason, amt = executeMaxHatch(secretEgg, false)
                    if not okHatch and reason == "no_coins" then
                        state.secretCooldownUntil = os.clock() + (CFG.SecretFarmDuration or 480)
                        log("Hết xu mở Secret Room! Ra bãi farm 8 phút.")
                    elseif okHatch then
                        state.status = string.format("Secret Room: Mở thành công x%d quả!", amt)
                    else
                        state.status = "Secret Room: " .. tostring(reason)
                    end
                end
                return
            end

            -- 2. Đứng farm viền & Mở 7 khu đầu (5 lần/khu)
            local activeZone = bestZone
            local targetPos = getZoneEdgeStandPos(activeZone)
            local p = playerPos()

            if p and targetPos and dist(p, targetPos) > 14 then
                teleportTo(targetPos, K.ZONES[activeZone].EggPos)
                task.wait(0.25)
            end

            farmZoneBreakables(activeZone)

            if secretOpen and inSecretCooldown then
                local leftSec = math.max(0, math.ceil(state.secretCooldownUntil - os.clock()))
                state.status = string.format("Farm xu cho Secret Egg (Còn %dm %02ds)", math.floor(leftSec / 60), leftSec % 60)
                return
            end

            local zoneEggInfo = findCustomEggById(K.ZONES[activeZone].Egg)
            if activeZone <= 7 then
                local doneCount = state.zoneHatchCounts[activeZone] or 0
                local maxAllowed = CFG.First7ZonesHatchTimes or 5
                if doneCount < maxAllowed then
                    if zoneEggInfo then
                        local okH, _, amt = executeMaxHatch(zoneEggInfo)
                        if okH then state.zoneHatchCounts[activeZone] = doneCount + 1 end
                    end
                    state.status = string.format("Zone %d: Mở trứng (%d/%d lần)", activeZone, state.zoneHatchCounts[activeZone], maxAllowed)
                else
                    state.status = string.format("Zone %d: Đã xong 5 lần, farm tiền mở Zone %d", activeZone, activeZone + 1)
                end
            else
                if zoneEggInfo then
                    local _, _, amt = executeMaxHatch(zoneEggInfo)
                    state.status = string.format("Zone 8: Mở liên tục (x%d)", amt)
                else
                    state.status = "Zone 8: Đang farm..."
                end
            end
        end)
        task.wait(math.max(0.2, CFG.HatchDelay or 0.45))
    end
end)

-- Vòng lặp các tính năng phụ
task.spawn(function()
    while state.alive do
        pcall(function()
            if CFG.Enabled and inEvent() then
                checkAndRunTreatUpgrades()
                checkAndRunCombine()
                runDelayedBuffs()
            end
        end)
        task.wait(5)
    end
end)

task.spawn(function()
    while state.alive do
        if CFG.Enabled then pcall(checkAndRunAutoMail) end
        task.wait(CFG.Mail.CheckInterval or 120)
    end
end)

task.spawn(function()
    while state.alive do
        pcall(function()
            if debugLbl then
                local zCounts = {}
                for i = 1, 7 do table.insert(zCounts, string.format("Z%d:%d/5", i, state.zoneHatchCounts[i] or 0)) end
                local srOpen = isSecretRoomAvailable()
                debugLbl.Text = string.format(
                    "[KAITUN HALLOWEEN 100% HEADLESS]\nTrạng thái: %s\nCoins: %s | Zone: %d/8 | Secret Mở: %s\nHatch Z1-7: %s\nTổng trứng nở: %d | Mails Gửi: %d",
                    state.status,
                    shorten(currency(K.CURRENCY)),
                    bestUnlockedZone(),
                    srOpen and "CÓ" or "KHÔNG",
                    table.concat(zCounts, " "),
                    state.totalEggsOpened,
                    state.mailsSent
                )
            end
        end)
        task.wait(1)
    end
end)

genv.HG_Kaitun = {
    Stop = function()
        state.alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
        local parentGui = (type(gethui) == "function" and gethui()) or CoreGui
        local old = parentGui:FindFirstChild("HG_Kaitun_Monitor")
        if old then old:Destroy() end
        log("Đã dừng Kaitun Halloween.")
    end,
}