-- =========================================================================
-- PS99 HALLOWEEN GAMES KAITUN (100% HEADLESS / LOGIC VERIFICATION BUILD)
-- Chu trình:
-- 1. Ưu tiên số 1: Secret Room Egg (Mở max theo Rank -> Hết xu ra farm 8 phút -> Quay lại mở tiếp đến khi đóng)
-- 2. Mở khóa Zone 1 -> 8: Đủ tiền mở ngay Zone mới & tele sang farm.
-- 3. 7 Khu đầu (Zone 1..7): Mỗi khu mở đúng 5 lần (Max trứng theo Rank/lần). Khu 8 mở liên tục.
-- 4. Auto Combine duy nhất "Huge Bat Hoodie Bunny" khi đủ nguyên liệu + Auto Claim.
-- 5. Auto Mail All Huge + 4 Consumables Halloween (Tier 1..3).
-- 6. Auto Daycare, Toys, Potions, Fruits, Flags.
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.HG_Kaitun) == "table" and type(genv.HG_Kaitun.Stop) == "function" then
    pcall(genv.HG_Kaitun.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN TỰ ĐỘNG (CHỈNH TẠI ĐÂY) =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,
    ShowDebugMonitor = true,             -- Hiện bảng đen nhỏ góc trái để kiểm tra logic chạy (đổi false khi muốn ẩn hẳn)

    -- 1. Cấu hình Secret Room Egg & Chu trình 8 khu
    SecretFarmDuration = 480,            -- 8 phút (480 giây) ra khu farm cày xu khi hết tiền mở Secret Egg
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (mỗi lần mở Max trứng theo Rank của acc)
    HatchDelay = 0.45,                   -- Thời gian nghỉ giữa 2 lần gọi lệnh mở trứng

    -- 2. Cấu hình Combine-o-Matic
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny", -- Chỉ ghép duy nhất Huge Bat Hoodie Bunny

    -- 3. Cấu hình Auto Mail (All Huge + 4 Consumables Tier 1-3)
    Mail = {
        Enabled = true,
        Recipient = "TenAccNhanDoCuaBan", -- ⚠️ ĐIỀN USERNAME ACC NHẬN ĐỒ VÀO ĐÂY!
        CheckInterval = 60,               -- Kiểm tra hòm đồ mỗi 60 giây
        MinDiamondsToKeep = 50000,        -- Giữ lại tối thiểu 50k Diamonds làm phí gửi thư
        SendAllHuges = true,              -- Tự động gửi tất cả Huge (trừ Huge đang bị khóa nếu muốn)
        MinConsumableStack = 10,          -- Gom đủ từ 10 cái trở lên mới gửi 1 lần cho đỡ tốn phí Mail
        ConsumableTiers = { 1, 2, 3 },    -- Gửi từ Tier 1 đến Tier 3
        Consumables = {
            "Halloween Games Lucky Charm",
            "Halloween Games Treat Magnet",
            "Halloween Games Broomstick",
            "Halloween Games Lantern",
        },
    },

    -- 4. Cấu hình Buffs & Tiện ích
    AutoBuffs = {
        Daycare = true,
        Toys = true,                      -- Toy Ball, Toy Bone, Squeaky Toy
        Fruits = true,                    -- Ăn hoa quả trong kho
        Potions = true,                   -- Cắn thuốc Coins, Lucky, Damage, Speed, Treasure Hunter
        Flags = true,                     -- Cắm cờ vào khu đang farm (Ưu tiên Coins Flag / Fortune Flag / Hasty Flag)
        PreferredFlags = { "Coins Flag", "Fortune Flag", "Hasty Flag", "Magnet Flag", "Strength Flag" },
    },
}
local CFG = genv.KaitunConfig

-- ================= KHỞI TẠO DỊCH VỤ & THREAD IDENTITY =================
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

-- ================= LOAD MODULES NỘI BỘ CỦA GAME =================
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
    UltimateCmds      = req("Library.Client.UltimateCmds"),
    Directory         = req("Library.Directory"),
    Items             = req("Library.Items"),
    FFlags            = req("Library.Client.FFlags"),
    DaycareCmds       = req("Library.Client.DaycareCmds"),
    PotionCmds        = req("Library.Client.PotionCmds"),
    FruitCmds         = req("Library.Client.FruitCmds"),
    ZoneFlagCmds      = req("Library.Client.ZoneFlagCmds"),
    HGForge           = req("Library.Client.HalloweenGamesCmds.Forge"),
}

-- ================= DỮ LIỆU HALLOWEEN GAMES & SECRET ROOM EGG =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    SECRET_EGG_ID   = "Secret Room Egg",
    SECRET_STAND    = Vector3.new(-6675.58, 2117.07, -3683.72), -- Lấy từ Halloween_Kaitun_Dump.json
    SECRET_EGG_POS  = Vector3.new(-6679.00, 2123.18, -3707.00),
    ZONES = {
        [1] = { Number = 1, Name = "#1 Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60, 16.20, -3939.52), EggPos = Vector3.new(-5315.25, 20.87, -3914.00) },
        [2] = { Number = 2, Name = "#2 Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83, 16.24, -3940.37), EggPos = Vector3.new(-5496.82, 20.31, -3913.00) },
        [3] = { Number = 3, Name = "#3 Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.55, 16.39, -3941.15), EggPos = Vector3.new(-5657.75, 20.70, -3913.00) },
        [4] = { Number = 4, Name = "#4 Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52, 16.42, -3939.43), EggPos = Vector3.new(-5810.95, 20.30, -3915.00) },
        [5] = { Number = 5, Name = "#5 Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.74, 16.24, -3939.23), EggPos = Vector3.new(-5984.55, 20.30, -3917.00) },
        [6] = { Number = 6, Name = "#6 Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.53, 16.92, -3910.60), EggPos = Vector3.new(-6340.73, 20.56, -3884.65) },
        [7] = { Number = 7, Name = "#7 Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.39, 16.96, -3911.23), EggPos = Vector3.new(-6520.73, 20.78, -3885.90) },
        [8] = { Number = 8, Name = "#8 Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50, 16.92, -3910.71), EggPos = Vector3.new(-6680.73, 20.58, -3886.40) },
    }
}

local state = {
    alive = true,
    status = "Khởi tạo...",
    excursion = nil,              -- "combine", "mail", "daycare"
    secretCooldownUntil = 0,      -- Thời điểm kết thúc 8 phút farm ngoài bãi
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 }, -- Đếm số lần mở trứng (max 5 lần/khu cho 7 khu đầu)
    totalHatches = 0,
    totalEggsOpened = 0,
    combinesStarted = 0,
    combinesClaimed = 0,
    mailsSent = 0,
    lastFlagAt = 0,
}

local connections = {}
local restoreFns = {}
local function track(c)
    if c then table.insert(connections, c) end
    return c
end

-- ================= HÀM GIAO TIẾP MẠNG & TIỆN ÍCH =================
local function netInvoke(name, ...)
    if isfn(G.Network, "Invoke") then return gcall(G.Network.Invoke, name, ...) end
    local r = RS:FindFirstChild("Network") and RS.Network:FindFirstChild(name)
    if r and r:IsA("RemoteFunction") then return pcall(r.InvokeServer, r, ...) end
    return false
end

local function netFire(name, ...)
    if isfn(G.Network, "Fire") then return gcall(G.Network.Fire, name, ...) end
    local r = RS:FindFirstChild("Network") and RS.Network:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return pcall(r.FireServer, r, ...) end
    return false
end

local function netUnreliable(name, ...)
    if isfn(G.Network, "UnreliableFire") then return gcall(G.Network.UnreliableFire, name, ...) end
    local r = RS:FindFirstChild("Network") and RS.Network:FindFirstChild(name)
    if r and r:IsA("UnreliableRemoteEvent") then return pcall(r.FireServer, r, ...) end
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

local function teleportTo(pos, lookAt)
    local c = LocalPlayer.Character
    local r = hrp()
    if not (c and r and pos) then return false end
    local cf = lookAt and CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
        or (CFrame.new(pos) * (r.CFrame - r.CFrame.Position))
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end

-- ================= HOOKS: CHẶN ANIMATION MỞ TRỨNG, PET SPEED, ANTI-AFK =================
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
end)

pcall(function()
    if type(getconnections) == "function" then
        for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
            if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
        end
    end
    track(LocalPlayer.Idled:Connect(function()
        if not state.alive then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end)

-- ================= QUẢN LÝ INSTANCE & ZONES (1 -> 8) =================
local function currentInstanceId()
    if isfn(G.Instancing, "GetInstanceID") then
        local id = gval(G.Instancing.GetInstanceID)
        if type(id) == "string" and id ~= "" then return id end
    end
    return nil
end

local function instanceModel()
    if isfn(G.Instancing, "GetModel") then
        local m = gval(G.Instancing.GetModel)
        if typeof(m) == "Instance" then return m end
    end
    local things = workspace:FindFirstChild("__THINGS")
    local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local act = cont and cont:FindFirstChild("Active")
    return act and act:FindFirstChild(K.INSTANCE_ID) or nil
end

local function inEvent()
    return currentInstanceId() == K.INSTANCE_ID and instanceModel() ~= nil
end

local function ensureInHalloweenEvent()
    if inEvent() then return true end
    state.status = "Đang vào cổng Halloween Games..."
    if isfn(G.Instancing, "Enter") then
        gcall(G.Instancing.Enter, K.INSTANCE_ID)
    end
    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 20 do
        if inEvent() then
            task.wait(0.6)
            return true
        end
        task.wait(0.4)
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

-- Tự động kiểm tra và mua ngay Zone tiếp theo khi đủ tiền
local function tryUnlockNextZoneImmediately()
    local best = bestUnlockedZone()
    if best >= 8 then return false end
    local nextZone = best + 1

    local obj = isfn(G.Instancing, "Get") and gval(G.Instancing.Get) or nil
    local zData = obj and type(obj.instanceZones) == "table" and obj.instanceZones[nextZone] or nil
    if type(zData) == "table" then
        local cost = tonumber(zData.CurrencyCost)
        local curId = zData.CurrencyId or K.CURRENCY
        if cost and currency(curId) < cost then
            return false
        end
    end

    local ok, res = netInvoke("InstanceZones_RequestPurchase", K.INSTANCE_ID, nextZone)
    if ok and res == true then
        log("Đã mở khóa Zone %d (%s)! Lập tức chuyển sang Zone mới.", nextZone, K.ZONES[nextZone].Name)
        return true, nextZone
    end
    return false
end

-- ================= LOGIC HATCH TRỨNG CHUẨN THEO RANK & SECRET ROOM =================
-- Tìm thông tin trứng từ CustomEggsCmds.All() theo tên _id (ví dụ "Straw Egg", "Secret Room Egg")
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

-- Kiểm tra phòng Secret Room có đang mở không
local function isSecretRoomAvailable()
    local things = workspace:FindFirstChild("__THINGS")
    local active = things and things:FindFirstChild("__INSTANCE_CONTAINER") and things.__INSTANCE_CONTAINER:FindFirstChild("Active")
    local srModel = active and active:FindFirstChild("HalloweenGamesSecretRoom")
    local srEgg = findCustomEggById(K.SECRET_EGG_ID)
    -- Nếu tồn tại Secret Room Egg trong CustomEggs và có model thực tế trong Workspace.__THINGS.CustomEggs
    if srEgg and srEgg.model and srEgg.model.Parent then
        return true, srEgg
    end
    if srModel and srEgg then
        return true, srEgg
    end
    return false, nil
end

-- Lấy số lượng mở trứng tối đa theo đúng Rank/Mastery/Slot của từng tài khoản (vd: 58, 15, 8, 99...)
local function getAccountMaxHatchForEgg(egg)
    local bestMax = 1
    -- 1. Ưu tiên đọc từ EggCmds.GetMaxHatch(dir) của game (tính chuẩn Rank + Mastery + Gamepass của acc đó)
    if isfn(G.EggCmds, "GetMaxHatch") then
        local n = gval(G.EggCmds.GetMaxHatch, egg and egg.dir or nil)
        if type(n) == "number" and n > bestMax then
            bestMax = math.floor(n)
        end
    end
    -- 2. Kiểm tra thêm thuộc tính _maxEggCount trên object CustomEgg (nếu cao hơn)
    if egg and type(egg.maxCount) == "number" and egg.maxCount > bestMax then
        bestMax = math.floor(egg.maxCount)
    end
    return math.max(1, bestMax)
end

-- Lấy giá 1 quả trứng (lưu ý: overrideCost trong Directory là giá gốc, thực tế trong game có thể rẻ hơn nhờ Upgrade/Discount)
local function getSingleEggCost(egg)
    local d = egg and egg.dir
    if type(d) == "table" and type(d.overrideCost) == "number" then
        return d.overrideCost, d.currency or K.CURRENCY
    end
    return 0, K.CURRENCY
end

-- Thực thi 1 lần mở trứng với số lượng Max của Acc
-- Trả về: (success: boolean, reason: string, actualAmountHatched: number)
local function executeMaxHatch(egg, requireFullBatch)
    if not egg or not egg.uid then return false, "no_egg", 0 end
    local maxCount = getAccountMaxHatchForEgg(egg)

    -- Thử gọi trực tiếp với maxCount trước (vì giá thực tế trong game như ảnh của bạn là 21.5m/quả thay vì 86m trong Directory)
    local ok, res, msg = netInvoke("CustomEggs_Hatch", egg.uid, maxCount)
    if ok and res == true then
        state.totalHatches += 1
        state.totalEggsOpened += maxCount
        return true, "ok", maxCount
    end

    local errText = string.lower(tostring(msg or res or ""))
    local isOutOfCoins = errText:find("afford", 1, true) or errText:find("enough", 1, true) or errText:find("coin", 1, true)

    -- Nếu không yêu cầu bắt buộc full batch thì thử chia đôi số lượng xuống mức mua được
    if isOutOfCoins and not requireFullBatch then
        local tryAmt = maxCount
        while state.alive and tryAmt > 1 do
            tryAmt = math.max(1, math.floor(tryAmt / 2))
            local ok2, res2 = netInvoke("CustomEggs_Hatch", egg.uid, tryAmt)
            if ok2 and res2 == true then
                state.totalHatches += 1
                state.totalEggsOpened += tryAmt
                return true, "ok_partial", tryAmt
            end
        end
    end

    if isOutOfCoins then
        return false, "no_coins", 0
    elseif errText:find("locked", 1, true) or errText:find("secret", 1, true) or errText:find("far", 1, true) or errText:find("exist", 1, true) then
        return false, "room_locked_or_far", 0
    elseif errText:find("quickly", 1, true) then
        return false, "rate_limit", 0
    end

    return false, tostring(msg or res or "failed"), 0
end

-- Tính vị trí đứng ở viền ranh giới giữa Bãi Farm và Quả Trứng của Zone (để vừa mở trứng vừa đánh bãi)
local function getZoneEdgeStandPos(zoneNumber)
    local z = K.ZONES[zoneNumber]
    if not z then return nil end
    -- Đứng lệch từ quả trứng về phía tâm bãi farm 18 studs (nằm gọn trong bán kính mở trứng ~25 studs của Server)
    local dirToFarm = (z.Pos - z.EggPos)
    if dirToFarm.Magnitude > 1 then
        return z.EggPos + dirToFarm.Unit * 16 + Vector3.new(0, 2.5, 0)
    end
    return z.Pos
end

-- ================= HỆ THỐNG FARM BREAKABLES & HÚT ORBS =================
local function petEuids()
    if not isfn(G.PlayerPet, "GetAll") then return {} end
    local ok, out = gcall(function()
        local res, unfiltered = {}, {}
        local all = G.PlayerPet.GetAll()
        if type(all) ~= "table" then return res end
        local belongs = type(G.PlayerPet.BelongsToLocalPlayer) == "function" and G.PlayerPet.BelongsToLocalPlayer or nil
        for _, p in pairs(all) do
            if type(p) == "table" and p.euid ~= nil then
                table.insert(unfiltered, p.euid)
                local keep = true
                if belongs then
                    local okB, r = pcall(belongs, p)
                    if okB and r == false then keep = false end
                end
                if keep then table.insert(res, p.euid) end
            end
        end
        return (#res > 0) and res or unfiltered
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

    -- Auto Tap mục tiêu đầu tiên
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

-- Hook Upvalue của OrbCmds để nhặt toàn bộ Orbs ngay khi rớt
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

-- ================= LOGIC 3: AUTO COMBINE "HUGE BAT HOODIE BUNNY" & AUTO CLAIM =================
local function flagValue(name)
    if not (name and type(G.FFlags) == "table" and type(G.FFlags.Keys) == "table" and type(G.FFlags.Get) == "function") then return nil end
    local key = G.FFlags.Keys[name]
    if key == nil then return nil end
    return gval(G.FFlags.Get, key)
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
                if c["CanBe" .. v](c) then
                    c["Set" .. v](c)
                    n += c:CountAny()
                end
            end
            if item:CanBeShiny() then
                for _, v in ipairs({ "Normal", "Golden", "Rainbow" }) do
                    local c = item:Clone()
                    local ok = v == "Normal" or (v == "Golden" and c:CanBeGolden()) or (v == "Rainbow" and c:CanBeRainbow())
                    if ok then
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

local function combineMachineStand()
    local m = instanceModel()
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    local mach = machines and machines:FindFirstChild(K.COMBINE_MACHINE)
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0) end
    return mach:GetPivot().Position + Vector3.new(0, 3, 6)
end

local function checkAndRunCombine()
    if not CFG.AutoCombine or not inEvent() or state.excursion ~= nil then return end
    local dir = combineDir()
    if not dir or type(dir.Recipes) ~= "table" then return end

    -- 1. Kiểm tra hàng đợi để Claim các món đã hoàn thành
    local okQ, queue = netInvoke("HalloweenCraftingMachine_GetQueue")
    if not okQ or type(queue) ~= "table" then return end

    local queuedByIndex = {}
    local readyClaims = {}
    for _, e in ipairs(queue) do
        if type(e) == "table" and (e.MachineId == nil or e.MachineId == dir._id) and e.RecipeIndex then
            queuedByIndex[e.RecipeIndex] = e
            if (tonumber(e.Remaining) or 0) <= 0 and e.UID then
                table.insert(readyClaims, e)
            end
        end
    end

    -- 2. Tìm đúng công thức "Huge Bat Hoodie Bunny" và kiểm tra đủ nguyên liệu chưa
    local targetRecipeIndex = nil
    local targetReady = false
    for idx, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result and type(r.Ingredients) == "table" then
            local resultName = tostring(gval(function() return r.Result:GetId() end) or "")
            if string.lower(resultName) == string.lower(CFG.TargetCombineRecipe) then
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

    if #readyClaims == 0 and not targetReady then return end

    state.excursion = "combine"
    local savedPos = playerPos()
    pcall(function()
        local stand = combineMachineStand()
        if stand then
            teleportTo(stand)
            task.wait(0.8)
        end

        -- Auto Claim khi combine xong
        for _, claimEntry in ipairs(readyClaims) do
            local ok, res = netInvoke("HalloweenCraftingMachine_Claim", claimEntry.UID)
            if ok and res then
                state.combinesClaimed += 1
                log("Combine-o-Matic: Đã Claim thành công (UID: %s)!", tostring(claimEntry.UID))
            end
            task.wait(0.5)
        end

        -- Auto Start Combine nếu đủ nguyên liệu cho Huge Bat Hoodie Bunny
        if targetReady and targetRecipeIndex then
            local ok, res = netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, targetRecipeIndex)
            if ok and res then
                state.combinesStarted += 1
                log("Combine-o-Matic: Đã bắt đầu ghép %s!", CFG.TargetCombineRecipe)
            end
            task.wait(0.5)
        end
    end)
    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil
end

-- ================= LOGIC 4: AUTO MAIL ALL HUGE + 4 CONSUMABLES (TIER 1 -> 3) =================
local function checkAndRunAutoMail()
    local mCfg = CFG.Mail
    if not (mCfg and mCfg.Enabled) then return end
    if type(mCfg.Recipient) ~= "string" or mCfg.Recipient == "" or mCfg.Recipient == "TenAccNhanDoCuaBan" then return end
    if string.lower(mCfg.Recipient) == string.lower(LocalPlayer.Name) then return end
    if currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then return end

    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    -- Tạo bảng tra cứu nhanh 4 Consumable và Tier 1..3
    local wantedCons = {}
    for _, name in ipairs(mCfg.Consumables or {}) do
        wantedCons[string.lower(name)] = true
    end
    local wantedTiers = {}
    for _, t in ipairs(mCfg.ConsumableTiers or {1, 2, 3}) do
        wantedTiers[tonumber(t)] = true
    end

    -- Lấy danh sách Pet đang Equipped để tránh gửi nhầm Huge đang đeo (nếu bị lỗi)
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

    -- A. Quét toàn bộ Huge trong kho Pet
    if mCfg.SendAllHuges and type(inv.Pet) == "table" then
        for uid, data in pairs(inv.Pet) do
            if type(data) == "table" and type(data.id) == "string" then
                if string.find(string.lower(data.id), "huge", 1, true) and not data.lk then
                    local amt = tonumber(data._am) or 1
                    -- Nếu Huge đang đeo thì tháo ra trước khi gửi
                    if equippedSet[uid] then
                        netFire("Pets_UnequipByUID", uid)
                        task.wait(0.2)
                    end
                    table.insert(toSend, { Category = "Pet", UID = uid, Amount = amt, Label = data.id })
                end
            end
        end
    end

    -- B. Quét 4 Consumable sự kiện từ Tier 1 -> Tier 3
    if type(inv.Consumable) == "table" then
        for uid, data in pairs(inv.Consumable) do
            if type(data) == "table" and type(data.id) == "string" and not data.lk then
                local idLower = string.lower(data.id)
                local tier = tonumber(data.tn) or 1
                local amt = tonumber(data._am) or 1
                if wantedCons[idLower] and wantedTiers[tier] and amt >= (mCfg.MinConsumableStack or 1) then
                    table.insert(toSend, {
                        Category = "Consumable",
                        UID = uid,
                        Amount = amt,
                        Label = string.format("%s (Tier %d x%d)", data.id, tier, amt)
                    })
                end
            end
        end
    end

    if #toSend == 0 then return end

    for _, item in ipairs(toSend) do
        if not state.alive then break end
        if currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then break end
        local ok, res, msg = netInvoke("Mailbox: Send", mCfg.Recipient, "Kaitun Auto Mail", item.Category, item.UID, item.Amount)
        if ok and res == true then
            state.mailsSent += 1
            log("Auto Mail: Đã gửi %s cho %s!", item.Label, mCfg.Recipient)
        else
            log("Auto Mail lỗi khi gửi %s: %s", item.Label, tostring(msg or res))
        end
        task.wait(1.5)
    end
end

-- ================= LOGIC 5: AUTO DAYCARE, TOYS, POTIONS, FRUITS, FLAGS =================
local function checkAndRunBuffsAndDaycare(activeZoneNumber)
    local bCfg = CFG.AutoBuffs
    if not bCfg then return end
    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    -- 1. Cắn Toys (Toy Ball, Toy Bone, Squeaky Toy)
    if bCfg.Toys then
        pcall(function() netInvoke("ToyBall_Consume") end)
        pcall(function() netInvoke("ToyBone_Consume") end)
        pcall(function() netInvoke("SqueakyToy_Consume") end)
    end

    -- 2. Ăn Hoa Quả (Fruits: Consume)
    if bCfg.Fruits and type(inv.Fruit) == "table" then
        for uid, data in pairs(inv.Fruit) do
            if type(data) == "table" and (tonumber(data._am) or 1) > 0 then
                netFire("Fruits: Consume", uid, 1)
                task.wait(0.1)
            end
        end
    end

    -- 3. Cắn Thuốc (Potions: Consume) - Ưu tiên Coins, Lucky, Damage, Speed, Treasure Hunter
    if bCfg.Potions and type(inv.Potion) == "table" then
        for uid, data in pairs(inv.Potion) do
            if type(data) == "table" and type(data.id) == "string" and (tonumber(data._am) or 1) > 0 then
                local pName = string.lower(data.id)
                if pName:find("coin") or pName:find("luck") or pName:find("damage") or pName:find("speed") or pName:find("treasure") then
                    netFire("Potions: Consume", uid)
                    task.wait(0.1)
                end
            end
        end
    end

    -- 4. Cắm Cờ vào khu vực đang đứng Farm (Flags: Consume / FlexibleFlags_Consume)
    if bCfg.Flags and activeZoneNumber and (os.clock() - state.lastFlagAt > 120) and type(inv.Misc) == "table" then
        for _, prefFlagName in ipairs(bCfg.PreferredFlags or {}) do
            local foundFlagUid = nil
            for uid, data in pairs(inv.Misc) do
                if type(data) == "table" and data.id == prefFlagName and (tonumber(data._am) or 1) > 0 then
                    foundFlagUid = uid
                    break
                end
            end
            if foundFlagUid then
                local zoneId = "Main_" .. tostring(activeZoneNumber)
                pcall(function() netInvoke("Flags: Consume", prefFlagName, foundFlagUid, 1) end)
                pcall(function() netInvoke("FlexibleFlags_Consume", prefFlagName, foundFlagUid, zoneId) end)
                state.lastFlagAt = os.clock()
                break
            end
        end
    end

    -- 5. Auto Daycare (Nhận thưởng & Nhét Pet dư vào Daycare)
    if bCfg.Daycare then
        pcall(function()
            if isfn(G.DaycareCmds, "Claim") then gcall(G.DaycareCmds.Claim) end
            netInvoke("Daycare: Claim")
        end)
        pcall(function()
            local maxSlots = isfn(G.DaycareCmds, "GetMaxSlots") and gval(G.DaycareCmds.GetMaxSlots) or 30
            local usedSlots = isfn(G.DaycareCmds, "GetUsedSlots") and gval(G.DaycareCmds.GetUsedSlots) or 0
            local freeSlots = math.max(0, maxSlots - usedSlots)
            if freeSlots > 0 and type(inv.Pet) == "table" then
                for uid, data in pairs(inv.Pet) do
                    if type(data) == "table" and type(data.id) == "string" and not data.lk then
                        local idLower = string.lower(data.id)
                        -- Chỉ nhét Pet thường có số lượng nhiều (> 50 con) và không phải Huge/Titanic
                        if not idLower:find("huge") and not idLower:find("titanic") and (tonumber(data._am) or 1) > 50 then
                            local enrollList = { [uid] = math.min(freeSlots, 10) }
                            netInvoke("Daycare: Enroll", enrollList)
                            break
                        end
                    end
                end
            end
        end)
    end
end

-- ================= BẢNG MONITOR DEBUG NHỎ GỌN (ĐỂ BẠN KIỂM TRA LOGIC) =================
local debugLbl = nil
if CFG.ShowDebugMonitor then
    pcall(function()
        local parentGui = (type(gethui) == "function" and gethui()) or CoreGui
        local old = parentGui:FindFirstChild("HG_Kaitun_Monitor")
        if old then old:Destroy() end

        local sg = Instance.new("ScreenGui")
        sg.Name = "HG_Kaitun_Monitor"
        sg.ResetOnSpawn = false
        sg.Parent = parentGui

        local frame = Instance.new("Frame", sg)
        frame.Size = UDim2.new(0, 320, 0, 145)
        frame.Position = UDim2.new(0, 12, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local st = Instance.new("UIStroke", frame)
        st.Color = Color3.fromRGB(255, 130, 0)
        st.Thickness = 1.2

        debugLbl = Instance.new("TextLabel", frame)
        debugLbl.Size = UDim2.new(1, -16, 1, -12)
        debugLbl.Position = UDim2.new(0, 8, 0, 6)
        debugLbl.BackgroundTransparency = 1
        debugLbl.Font = Enum.Font.Code
        debugLbl.TextSize = 12
        debugLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        debugLbl.TextXAlignment = Enum.TextXAlignment.Left
        debugLbl.TextYAlignment = Enum.TextYAlignment.Top
        debugLbl.TextWrapped = true
        debugLbl.Text = "Đang khởi động Kaitun Halloween..."
    end)
end

-- ================= VÒNG LẶP CHÍNH: ĐIỀU PHỐI TOÀN BỘ CHU TRÌNH KAITUN =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if not CFG.Enabled then return end
            if not ensureInHalloweenEvent() then return end
            if state.excursion ~= nil then return end

            -- BƯỚC 1: Luôn kiểm tra nếu đủ tiền mở Zone mới (từ 1 -> 8) thì mở khóa ngay lập tức!
            tryUnlockNextZoneImmediately()
            local bestZone = bestUnlockedZone()

            -- BƯỚC 2: Kiểm tra Secret Room Egg có đang mở hay không & đã hết 8 phút farm ngoài bãi chưa
            local secretOpen, secretEgg = isSecretRoomAvailable()
            local now = os.clock()
            local inSecretCooldown = now < state.secretCooldownUntil

            if secretOpen and not inSecretCooldown then
                -- >>> CHẾ ĐỘ ƯU TIÊN 1: VÀO PHÒNG SECRET MỞ SECRET ROOM EGG <<<
                local p = playerPos()
                if not p or dist(p, K.SECRET_STAND) > 12 then
                    state.status = "Đang bay vào Secret Room Egg..."
                    teleportTo(K.SECRET_STAND, K.SECRET_EGG_POS)
                    task.wait(0.4)
                    secretOpen, secretEgg = isSecretRoomAvailable()
                end

                if secretEgg then
                    local maxBatch = getAccountMaxHatchForEgg(secretEgg)
                    state.status = string.format("Secret Room: Đang mở Secret Egg (Max x%d)", maxBatch)
                    local okHatch, reason, hatchedCount = executeMaxHatch(secretEgg, false)

                    if not okHatch and reason == "no_coins" then
                        -- Hết xu! Bật bộ đếm ra khu farm đúng 8 phút (480 giây) rồi mới quay lại
                        state.secretCooldownUntil = os.clock() + (CFG.SecretFarmDuration or 480)
                        log("Hết xu mở Secret Room Egg! Ra Zone %d farm trong %d phút rồi quay lại.", bestZone, math.floor((CFG.SecretFarmDuration or 480) / 60))
                    elseif not okHatch and reason == "room_locked_or_far" then
                        -- Phòng đã bị khóa
                        log("Secret Room đã đóng/khóa! Quay trở lại Zone %d.", bestZone)
                        task.wait(1)
                    end
                end
                return
            end

            -- BƯỚC 3: NẾU ĐANG TRONG 8 PHÚT FARM BÙ XU CHO SECRET EGG HOẶC SECRET ĐÓNG
            -- Xác định xem có khu nào trong 7 khu đầu (từ 1 đến min(bestZone, 7)) chưa mở đủ 5 lần không:
            -- Lưu ý: Theo yêu cầu 1 của bạn, ưu tiên đứng ở bestZone hiện tại.
            -- Nếu bestZone <= 7 và chưa mở đủ 5 lần ở bestZone -> mở cho đủ 5 lần rồi chỉ đứng farm chờ đủ tiền lên Zone mới!
            local activeZone = bestZone
            local targetPos = getZoneEdgeStandPos(activeZone)
            local p = playerPos()

            if p and targetPos and dist(p, targetPos) > 14 then
                teleportTo(targetPos, K.ZONES[activeZone].EggPos)
                task.wait(0.25)
            end

            -- Luôn điều Pet đánh Breakables tại Zone hiện tại
            farmZoneBreakables(activeZone)

            -- Nếu đang trong thời gian 8 phút farm xu để quay lại Secret Room Egg -> KHÔNG mở trứng thường để tích 100% xu cho Secret Egg!
            if secretOpen and inSecretCooldown then
                local leftSec = math.max(0, math.ceil(state.secretCooldownUntil - os.clock()))
                state.status = string.format("Farm xu cho Secret Egg tại Zone %d (Còn %dm %02ds)", activeZone, math.floor(leftSec / 60), leftSec % 60)
                return
            end

            -- BƯỚC 4: LOGIC MỞ TRỨNG Ở 8 KHU KHI KHÔNG BẬN SECRET ROOM
            local zoneEggInfo = findCustomEggById(K.ZONES[activeZone].Egg)
            if activeZone <= 7 then
                local doneCount = state.zoneHatchCounts[activeZone] or 0
                local maxAllowed = CFG.First7ZonesHatchTimes or 5
                if doneCount < maxAllowed then
                    if zoneEggInfo then
                        local okH, reason, amt = executeMaxHatch(zoneEggInfo, false)
                        if okH then
                            state.zoneHatchCounts[activeZone] = doneCount + 1
                            log("Zone %d (%s): Đã mở lần %d/%d (x%d quả)", activeZone, K.ZONES[activeZone].Egg, state.zoneHatchCounts[activeZone], maxAllowed, amt)
                        end
                    end
                    state.status = string.format("Zone %d: Mở trứng (%d/%d lần) + Farm lên Zone %d", activeZone, state.zoneHatchCounts[activeZone] or 0, maxAllowed, activeZone + 1)
                else
                    -- Đã mở đủ 5 lần ở khu này -> Ngừng mở trứng để tích xu mở khóa ngay Zone tiếp theo!
                    state.status = string.format("Zone %d: Đã mở đủ %d/%d lần! Đang tích xu mở Zone %d...", activeZone, maxAllowed, maxAllowed, activeZone + 1)
                end
            else
                -- Khu 8 (Khu cuối - Thorn Egg): Mở liên tục không giới hạn!
                if zoneEggInfo then
                    local okH, _, amt = executeMaxHatch(zoneEggInfo, false)
                    state.status = string.format("Zone 8 (Khu cuối): Mở liên tục %s (x%d) + Farm", K.ZONES[8].Egg, amt > 0 and amt or getAccountMaxHatchForEgg(zoneEggInfo))
                else
                    state.status = "Zone 8 (Khu cuối): Đang farm..."
                end
            end
        end)
        task.wait(math.max(0.2, CFG.HatchDelay or 0.45))
    end
end)

-- Vòng lặp hút Orbs liên tục (0.15s/lần)
task.spawn(function()
    while state.alive do
        if CFG.Enabled and inEvent() then
            pcall(collectOrbsTick)
        end
        task.wait(0.15)
    end
end)

-- Vòng lặp Auto Combine "Huge Bat Hoodie Bunny" & Auto Claim (10s/lần)
task.spawn(function()
    while state.alive do
        if CFG.Enabled and inEvent() then
            pcall(checkAndRunCombine)
        end
        task.wait(10)
    end
end)

-- Vòng lặp Auto Buffs (Toys, Fruits, Potions, Flags, Daycare) (25s/lần)
task.spawn(function()
    while state.alive do
        if CFG.Enabled and inEvent() then
            pcall(function() checkAndRunBuffsAndDaycare(bestUnlockedZone()) end)
        end
        task.wait(25)
    end
end)

-- Vòng lặp Auto Mail All Huge + 4 Consumables Tier 1-3 (60s/lần)
task.spawn(function()
    while state.alive do
        if CFG.Enabled then
            pcall(checkAndRunAutoMail)
        end
        task.wait(CFG.Mail and CFG.Mail.CheckInterval or 60)
    end
end)

-- Vòng lặp cập nhật bảng Monitor kiểm tra Logic (1s/lần)
task.spawn(function()
    while state.alive do
        pcall(function()
            if debugLbl then
                local zCounts = {}
                for i = 1, 7 do table.insert(zCounts, string.format("Z%d:%d/5", i, state.zoneHatchCounts[i] or 0)) end
                local srOpen = isSecretRoomAvailable()
                debugLbl.Text = string.format(
                    "[KAITUN HALLOWEEN LOGIC MONITOR]\nTrạng thái: %s\nCoins: %s | Zone: %d/8 | Secret Mở: %s\nLần Hatch Z1-7: %s\nTổng trứng nở: %d | Combine: %d/%d | Mail: %d",
                    state.status,
                    shorten(currency(K.CURRENCY)),
                    bestUnlockedZone(),
                    srOpen and "CÓ" or "KHÔNG",
                    table.concat(zCounts, " "),
                    state.totalEggsOpened,
                    state.combinesStarted,
                    state.combinesClaimed,
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
    State = state,
}