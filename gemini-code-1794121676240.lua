-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (KIZHUB EDITION - STABLE 8 UPGRADES)
-- Khôi phục: Chuẩn 8 Treat Upgrades ổn định, Mở trứng linh hoạt 100%,
-- GPU 0%, 10 FPS, Chống Disconnect/Spam, Auto Equip Best, Free Gifts, 2 Webhook.
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.Kizhub_HG) == "table" and type(genv.Kizhub_HG.Stop) == "function" then
    pcall(genv.Kizhub_HG.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN KIZHUB =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Tối Ưu CPU / GPU Cực Hạn Cho Multi-Account
    TargetFPS = 10,                      -- Khóa 10 FPS (giảm mạnh CPU, giữ ping mạng ổn định chống timeout)
    LogoAssetId = "rbxassetid://10709791437", -- Asset ID icon Vương miện

    -- 2. Quà tặng miễn phí (Free Gifts)
    AutoClaimFreeGifts = true,           -- Tự động nhận 12 mốc quà Free Gifts theo thời gian

    -- 3. Chu trình mở trứng 8 Zone (Tọa độ Pos chuẩn 100% halloween.lua)
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (Max trứng/lần)
    HatchDelay = 0.5,                    -- Tốc độ mở trứng

    -- 4. Nâng cấp sự kiện (Treat Upgrades - Chuẩn 8 món gốc)
    AutoTreatUpgrades = true,
    UpgradeCooldown = 600,               -- Đúng 10 phút (600 giây) kiểm tra ghé máy 1 lần

    -- 5. Ghép Huge Bat Hoodie Bunny
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 40,

    -- 6. Auto Mail (Đủ đồ là gửi ngay lập tức) & Auto Claim Mail
    Mail = {
        Enabled = true,
        Recipient = "DienTenAccNhanVaoDay", -- ⚠️ ĐIỀN USERNAME ACC NHẬN
        AutoClaimMail = true,               -- Tự động nhận tất cả thư gửi đến (Claim All)
        MinDiamondsToKeep = 50000,          -- Giữ lại 50k Diamonds làm phí gửi thư
        SendAllHuges = true,                -- Tự động gửi tất cả Huge khi có trong kho
        
        -- Danh sách Consumable cấu hình riêng từng Tier và MinAmount chuẩn xác
        Consumables = {
            { Class = "Consumable", Id = "Halloween Games Lantern", Tier = 1, MinAmount = 500 },
            { Class = "Consumable", Id = "Halloween Games Lantern", Tier = 2, MinAmount = 50 },
            { Class = "Consumable", Id = "Halloween Games Lantern", Tier = 3, MinAmount = 10 },
            { Class = "Consumable", Id = "Halloween Games Lucky Charm", Tier = 1, MinAmount = 600 },
            { Class = "Consumable", Id = "Halloween Games Lucky Charm", Tier = 2, MinAmount = 50 },
            { Class = "Consumable", Id = "Halloween Games Lucky Charm", Tier = 3, MinAmount = 10 },
            { Class = "Consumable", Id = "Halloween Games Treat Magnet", Tier = 1, MinAmount = 600 },
            { Class = "Consumable", Id = "Halloween Games Treat Magnet", Tier = 2, MinAmount = 20 },
            { Class = "Consumable", Id = "Halloween Games Treat Magnet", Tier = 3, MinAmount = 10 },
            { Class = "Consumable", Id = "Halloween Games Broomstick", Tier = 1, MinAmount = 1000 },
            { Class = "Consumable", Id = "Halloween Games Broomstick", Tier = 2, MinAmount = 500 },
            { Class = "Consumable", Id = "Halloween Games Broomstick", Tier = 3, MinAmount = 20 },
        }
    },

    -- 7. Discord Webhook Thông Báo (Tách 2 kênh riêng biệt)
    Webhook = {
        Enabled = false,                    -- Đổi thành true để bật Webhook
        
        -- Kênh 1: Báo Huge & Mail thành công
        Url = "",                           -- ⚠️ DÁN LINK WEBHOOK BÁO HUGE VÀO ĐÂY
        NotifyOnHuge = true,
        NotifyOnMail = true,

        -- Kênh 2: Báo cáo trạng thái Heartbeat định kỳ kiểm tra sống/chết
        StatusUrl = "",                     -- ⚠️ DÁN LINK WEBHOOK BÁO TRẠNG THÁI VÀO ĐÂY
        StatusInterval = 600,               -- Báo cáo mỗi 600 giây (10 phút)
    },

    -- 8. Auto Buffs (Chống Spam: Đúng thời gian hết hạn mới dùng lại)
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
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
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

-- ================= ULTRA LOW-CPU ENGINE BOOSTER =================
pcall(function()
    if type(setfpscap) == "function" then
        setfpscap(CFG.TargetFPS or 10)
    end
end)

pcall(function()
    SoundService.RespectFilteringEnabled = true
    for _, s in ipairs(game:GetDescendants()) do
        if s:IsA("Sound") then
            s.Volume = 0
            s:Stop()
        end
    end
    game.DescendantAdded:Connect(function(v)
        if v:IsA("Sound") then
            v.Volume = 0
            v:Stop()
        end
    end)
end)

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.Technology = Enum.Technology.Compatibility

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostProcessEffect") or obj:IsA("Atmosphere") or obj:IsA("Sky") or obj:IsA("Clouds") then
            obj:Destroy()
        end
    end
end)

pcall(function()
    local function stripAsset(v)
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Texture = ""
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        elseif v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
        end
    end

    for _, v in ipairs(workspace:GetDescendants()) do
        stripAsset(v)
    end
    workspace.DescendantAdded:Connect(function(v)
        task.defer(stripAsset, v)
    end)
end)

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
    HGUpgrades        = req("Library.Client.HalloweenGamesCmds.Upgrades", true),
    TabController     = req("Library.Client.TabController", true),
    DaycareCmds       = req("Library.Client.DaycareCmds"),
    Directory         = req("Library.Directory"),
    FFlags            = req("Library.Client.FFlags"),
}

-- ================= DỮ LIỆU TỌA ĐỘ VỊ TRÍ 8 ZONE & ĐÚNG 8 NÂNG CẤP TREATS CHUẨN =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    UPGRADE_MACHINE = "HalloweenGamesUpgradeMachine",
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    ZONES = {
        [1] = { Number = 1, Name = "Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60400390625, 16.19723892211914, -3939.5205078125) },
        [2] = { Number = 2, Name = "Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83203125, 16.239492416381836, -3940.37158203125) },
        [3] = { Number = 3, Name = "Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.5517578125, 16.394588470458984, -3941.1513671875) },
        [4] = { Number = 4, Name = "Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52197265625, 16.417028427124023, -3939.434814453125) },
        [5] = { Number = 5, Name = "Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.740234375, 16.23948860168457, -3939.2265625) },
        [6] = { Number = 6, Name = "Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.5283203125, 16.917938232421875, -3910.60400390625) },
        [7] = { Number = 7, Name = "Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.3916015625, 16.960006713867188, -3911.231689453125) },
        [8] = { Number = 8, Name = "Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50146484375, 16.917938232421875, -3910.71044921875) },
    },
    UPGRADES = {
        { Key = "CoinFinder",     Id = "HalloweenGamesCoinFinder",     Name = "Coin Finder" },
        { Key = "EggLuck",        Id = "HalloweenGamesEggLuck",        Name = "Egg Luck" },
        { Key = "HugeLuck",       Id = "HalloweenGamesHugeLuck",       Name = "Huge Luck" },
        { Key = "Golden",         Id = "HalloweenGamesGolden",         Name = "More Gold" },
        { Key = "Rainbow",        Id = "HalloweenGamesRainbow",        Name = "More Rainbow" },
        { Key = "Shiny",          Id = "HalloweenGamesShiny",          Name = "Ooo Shiny" },
        { Key = "PetSavings",     Id = "HalloweenGamesPetSavings",     Name = "Pet Savings" },
        { Key = "BetterVariants", Id = "HalloweenGamesBetterVariants", Name = "Better Variants" },
    }
}

local state = {
    alive = true,
    excursion = nil,
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 },
    totalEggsHatched = 0,
    combineStatus = "Rảnh",
    mailsSent = 0,
    mailsClaimed = 0,
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextFlagAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextDaycareAt = 0,
    nextClaimMailAt = 0,
    nextClaimGiftsAt = 0,
    currentZoneNumber = 1,
}

local connections = {}
local restoreFns = {}

-- ================= TIỆN ÍCH MẠNG & THÔNG SỐ =================
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
    local safeTarget = pos + Vector3.new(0, 3.5, 0)
    local cf = CFrame.new(safeTarget) * (r.CFrame - r.CFrame.Position)
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end

-- ================= DISCORD WEBHOOK SENDER (HỖ TRỢ ĐA KÊNH RIÊNG BIỆT) =================
local function sendWebhook(title, description, color, fields, customUrl)
    local wb = CFG.Webhook
    if not (wb and wb.Enabled) then return end
    
    local targetUrl = customUrl or wb.Url
    if type(targetUrl) ~= "string" or not targetUrl:find("^https://") then return end

    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then return end

    local payload = {
        username = "kizhub Notifier",
        avatar_url = "https://i.imgur.com/8Y1jE6u.png",
        embeds = { {
            title = title,
            description = description,
            color = color or 0xFFA500,
            fields = fields or {},
            footer = { text = "kizhub • Pet Simulator 99" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        } }
    }

    task.spawn(function()
        pcall(reqFn, {
            Url = targetUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- ================= HOOKS CHỐNG LAG & ANTI-AFK XOAY CAMERA =================
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
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.1), 0)
            end
        end)
    end))
end)

-- ================= FULLSCREEN GUI MÀN TRẮNG (CỐ ĐỊNH) =================
local uiRefs = {}
pcall(function()
    pcall(function() RunService:Set3dRenderingEnabled(false) end)

    local parentGui = (type(gethui) == "function" and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui
    local oldGui = parentGui:FindFirstChild("Kizhub_WhiteScreen")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kizhub_WhiteScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parentGui

    local WhiteCover = Instance.new("Frame")
    WhiteCover.Name = "WhiteCover"
    WhiteCover.Size = UDim2.new(1, 0, 1, 0)
    WhiteCover.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    WhiteCover.BorderSizePixel = 0
    WhiteCover.Parent = ScreenGui

    local KizCard = Instance.new("Frame")
    KizCard.Name = "KizCard"
    KizCard.Size = UDim2.new(0, 380, 0, 360)
    KizCard.Position = UDim2.new(0, 20, 0, 20)
    KizCard.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    KizCard.BorderSizePixel = 0
    KizCard.Active = false
    KizCard.Draggable = false
    KizCard.Parent = ScreenGui

    Instance.new("UICorner", KizCard).CornerRadius = UDim.new(0, 14)
    local CardStroke = Instance.new("UIStroke", KizCard)
    CardStroke.Color = Color3.fromRGB(255, 140, 0)
    CardStroke.Thickness = 1.8

    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Size = UDim2.new(1, 0, 0, 100)
    HeaderFrame.BackgroundTransparency = 1