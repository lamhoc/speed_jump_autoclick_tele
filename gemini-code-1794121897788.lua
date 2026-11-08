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
    TargetFPS = 5,                      -- Khóa 10 FPS (giảm mạnh CPU, giữ ping mạng ổn định chống timeout)
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
        Recipient = "Kizmoii_VNG", -- ⚠️ ĐIỀN USERNAME ACC NHẬN
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
        Enabled = true,                    -- Đổi thành true để bật Webhook
        
        -- Kênh 1: Báo Huge & Mail thành công
        Url = "https://discord.com/api/webhooks/1444485821909569558/ONQp3ZOyvQevUptUSVbLQpkm5SZZDUOEUr0LTZGoYNPeh_NlMwTxeIS8kEre_u7qEvfC",                           -- ⚠️ DÁN LINK WEBHOOK BÁO HUGE VÀO ĐÂY
        NotifyOnHuge = true,
        NotifyOnMail = true,

        -- Kênh 2: Báo cáo trạng thái Heartbeat định kỳ kiểm tra sống/chết
        StatusUrl = "https://discord.com/api/webhooks/1372817821293219860/0RlqBFpPwUX-TjWsrcpLhDDEY8EKsz_6gbywjKK2J361TIg2YfwvbVE-ZxDcymNjxB44",                     -- ⚠️ DÁN LINK WEBHOOK BÁO TRẠNG THÁI VÀO ĐÂY
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

    local CrownLogo = Instance.new("ImageLabel", HeaderFrame)
    CrownLogo.Name = "CrownLogo"
    CrownLogo.Size = UDim2.new(0, 56, 0, 56)
    CrownLogo.Position = UDim2.new(0, 18, 0, 10)
    CrownLogo.BackgroundTransparency = 1
    CrownLogo.Image = CFG.LogoAssetId
    CrownLogo.ScaleType = Enum.ScaleType.Fit

    local BrandText = Instance.new("TextLabel", HeaderFrame)
    BrandText.Name = "BrandText"
    BrandText.Text = "kizhub"
    BrandText.Font = Enum.Font.GothamBold
    BrandText.TextSize = 16
    BrandText.TextColor3 = Color3.fromRGB(255, 140, 0)
    BrandText.TextXAlignment = Enum.TextXAlignment.Center
    BrandText.BackgroundTransparency = 1
    BrandText.Position = UDim2.new(0, 18, 0, 68)
    BrandText.Size = UDim2.new(0, 56, 0, 20)

    local TitleInfo = Instance.new("TextLabel", HeaderFrame)
    TitleInfo.Text = "PS99 HALLOWEEN KAITUN"
    TitleInfo.Font = Enum.Font.GothamBold
    TitleInfo.TextSize = 15
    TitleInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleInfo.TextXAlignment = Enum.TextXAlignment.Left
    TitleInfo.BackgroundTransparency = 1
    TitleInfo.Position = UDim2.new(0, 90, 0, 20)
    TitleInfo.Size = UDim2.new(1, -90, 0, 20)

    local SubInfo = Instance.new("TextLabel", HeaderFrame)
    SubInfo.Text = "Autonomous Farming • Auto Mail • Auto Upgrade"
    SubInfo.Font = Enum.Font.Gotham
    SubInfo.TextSize = 11
    SubInfo.TextColor3 = Color3.fromRGB(160, 160, 175)
    SubInfo.TextXAlignment = Enum.TextXAlignment.Left
    SubInfo.BackgroundTransparency = 1
    SubInfo.Position = UDim2.new(0, 90, 0, 42)
    SubInfo.Size = UDim2.new(1, -90, 0, 16)

    local SepLine = Instance.new("Frame", KizCard)
    SepLine.Size = UDim2.new(1, -36, 0, 1)
    SepLine.Position = UDim2.new(0, 18, 0, 96)
    SepLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SepLine.BorderSizePixel = 0

    local InfoContainer = Instance.new("Frame", KizCard)
    InfoContainer.Size = UDim2.new(1, -36, 1, -110)
    InfoContainer.Position = UDim2.new(0, 18, 0, 105)
    InfoContainer.BackgroundTransparency = 1

    local function createRow(labelText, defaultVal, yPos)
        local lbl = Instance.new("TextLabel", InfoContainer)
        lbl.Text = labelText
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(200, 200, 215)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 0, 0, yPos)
        lbl.Size = UDim2.new(0, 130, 0, 18)

        local val = Instance.new("TextLabel", InfoContainer)
        val.Text = defaultVal
        val.Font = Enum.Font.GothamMedium
        val.TextSize = 12
        val.TextColor3 = Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(0, 130, 0, yPos)
        val.Size = UDim2.new(1, -130, 0, 18)
        return val
    end

    uiRefs.ZoneLabel    = createRow("Zone Hiện Tại:", "Đang tải...", 0)
    uiRefs.CombineLabel = createRow("Trạng Thái Combine:", "Rảnh", 22)
    uiRefs.CoinsLabel   = createRow("Candy Coins:", "0", 44)
    uiRefs.TreatsLabel  = createRow("Treats / Trứng Nở:", "0 / 0", 66)
    uiRefs.MailLabel    = createRow("Hệ Thống Mailbox:", "Gửi: 0 | Nhận: 0", 88)

    local UpgTitle = Instance.new("TextLabel", InfoContainer)
    UpgTitle.Text = "Tiến Trình Treat Upgrades:"
    UpgTitle.Font = Enum.Font.GothamBold
    UpgTitle.TextSize = 12
    UpgTitle.TextColor3 = Color3.fromRGB(255, 140, 0)
    UpgTitle.TextXAlignment = Enum.TextXAlignment.Left
    UpgTitle.BackgroundTransparency = 1
    UpgTitle.Position = UDim2.new(0, 0, 0, 114)
    UpgTitle.Size = UDim2.new(1, 0, 0, 18)

    uiRefs.UpgradesLabel = Instance.new("TextLabel", InfoContainer)
    uiRefs.UpgradesLabel.Text = "Đang đọc dữ liệu nâng cấp..."
    uiRefs.UpgradesLabel.Font = Enum.Font.Code
    uiRefs.UpgradesLabel.TextSize = 10.5
    uiRefs.UpgradesLabel.TextColor3 = Color3.fromRGB(180, 235, 200)
    uiRefs.UpgradesLabel.TextXAlignment = Enum.TextXAlignment.Left
    uiRefs.UpgradesLabel.TextYAlignment = Enum.TextYAlignment.Top
    uiRefs.UpgradesLabel.TextWrapped = true
    uiRefs.UpgradesLabel.BackgroundTransparency = 1
    uiRefs.UpgradesLabel.Position = UDim2.new(0, 0, 0, 134)
    uiRefs.UpgradesLabel.Size = UDim2.new(1, 0, 0, 100)
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

-- ================= HATCH TRỨNG (ĐỒNG BỘ CẢ UID LẪN TÊN TRỨNG VÀ HẠ SỐ LƯỢNG) =================
local function findCustomEggById(eggId)
    if not isfn(G.CustomEggs, "All") then return nil end
    local all = gval(G.CustomEggs.All)
    if type(all) ~= "table" then return nil end
    for uid, e in pairs(all) do
        if type(e) == "table" and (e._id == eggId or uid == eggId) then
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
    if not egg then return false end
    local maxAmount = getAccountMaxHatch(egg)
    local targetUid = egg.uid
    local targetName = egg.id

    local amountsToTry = { maxAmount, 25, 10, 5, 1 }
    for _, amt in ipairs(amountsToTry) do
        if amt <= maxAmount and amt > 0 then
            -- Cách 1: Mở bằng UID
            if targetUid then
                local ok, res = netInvoke("CustomEggs_Hatch", targetUid, amt)
                if ok and res == true then
                    state.totalEggsHatched = state.totalEggsHatched + amt
                    return true, amt
                end
            end
            -- Cách 2: Mở bằng Tên Trứng
            if targetName then
                local ok2, res2 = netInvoke("CustomEggs_Hatch", targetName, amt)
                if ok2 and res2 == true then
                    state.totalEggsHatched = state.totalEggsHatched + amt
                    return true, amt
                end
            end
        end
    end
    return false, 0
end

-- ================= FARM BREAKABLES & HÚT ORBS =================
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
local lastHitSend = 0
local function farmZoneBreakables(zoneNumber)
    local targetUids = zoneBreakables(zoneNumber)
    if #targetUids == 0 then return end
    
    local pets = petEuids()
    if #pets == 0 and isfn(G.PetCmds, "EquipBest") then
        gcall(G.PetCmds.EquipBest)
        task.wait(0.5)
        pets = petEuids()
    end
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

    local now = os.clock()
    if now - lastHitSend > 0.6 then
        lastHitSend = now
        netUnreliable("Breakables_PlayerDealDamage", ordered[1].uid)
    end

    local map, changed = {}, false
    for i, euid in ipairs(pets) do
        local tUid = ordered[((i - 1) % #ordered) + 1].uid
        map[euid] = tUid
        if lastFastMap[euid] ~= tUid then changed = true end
    end

    if changed or (now - lastFastSend > 1.2) then
        lastFastSend = now
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

-- ================= AUTO TREAT UPGRADES (CHUẨN 8 MÓN & TẮT GIAO DIỆN) =================
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

local function forceCloseUpgradeUI()
    pcall(function()
        if G.TabController and type(G.TabController.Close) == "function" then
            G.TabController.Close("HalloweenGamesUpgradeMachine")
            G.TabController.Close("HalloweenUpgrades")
        end
    end)
    pcall(function()
        if G.HGUpgrades then
            if type(G.HGUpgrades.OnLeave) == "function" then G.HGUpgrades.OnLeave() end
            if type(G.HGUpgrades.Close) == "function" then G.HGUpgrades.Close() end
        end
    end)
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pGui then
            for _, g in ipairs(pGui:GetChildren()) do
                if g:IsA("ScreenGui") and (g.Name:find("Upgrade") or g.Name:find("HalloweenGamesUpgradeMachine")) then
                    g.Enabled = false
                    local closeBtn = g:FindFirstChild("Close", true) or g:FindFirstChild("CloseButton", true) or g:FindFirstChild("Exit", true)
                    if closeBtn and closeBtn:IsA("GuiButton") then
                        pcall(function() firesignal(closeBtn.MouseButton1Click) end)
                    end
                end
            end
        end
    end)
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

    forceCloseUpgradeUI()
    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil
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
        state.combineStatus = queuedByIndex[targetRecipeIndex] and "Đang ghép Huge" or "Chờ nguyên liệu"
        state.nextCombineAt = now + (CFG.CombineCooldown or 40)
        return
    end

    state.excursion = "combine"
    state.combineStatus = targetReady and "Đang bắt đầu ghép" or "Đang Claim Huge"
    local savedPos = playerPos()
    pcall(function()
        local stand = getMachineStand(K.COMBINE_MACHINE)
        if stand then
            teleportTo(stand)
            task.wait(0.8)
        end
        for _, claim in ipairs(readyClaims) do
            netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            sendWebhook("🎉 GHÉP THÀNH CÔNG HUGE!", "Đã nhận thành công **" .. CFG.TargetCombineRecipe .. "**!", 0xFFD700)
            task.wait(0.5)
        end
        if targetReady and targetRecipeIndex then
            netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, targetRecipeIndex)
            task.wait(0.5)
        end
    end)
    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil
    state.combineStatus = "Đang ghép Huge"
    state.nextCombineAt = os.clock() + (CFG.CombineCooldown or 40)
end

-- ================= AUTO CLAIM FREE GIFTS =================
local function checkAndClaimFreeGifts()
    if not CFG.AutoClaimFreeGifts then return end
    local now = os.clock()
    if now < state.nextClaimGiftsAt then return end
    state.nextClaimGiftsAt = now + 60

    pcall(function()
        for i = 1, 12 do
            netInvoke("Redeem Free Gift", i)
        end
    end)
end

-- ================= AUTO BUFFS =================
local function runDelayedBuffs(activeZoneNumber)
    local bCfg = CFG.AutoBuffs
    if not bCfg then return end
    local now = os.clock()
    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

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

    if bCfg.Toys and now > state.nextToyAt then
        pcall(function() netInvoke("ToyBall_Consume") end)
        pcall(function() netInvoke("ToyBone_Consume") end)
        pcall(function() netInvoke("SqueakyToy_Consume") end)
        state.nextToyAt = now + 900
    end

    if bCfg.Fruits and now > state.nextFruitAt and type(inv.Fruit) == "table" then
        for uid, data in pairs(inv.Fruit) do
            if type(data) == "table" and (tonumber(data._am) or 1) > 0 then
                netFire("Fruits: Consume", uid, 20)
            end
        end
        state.nextFruitAt = now + 300
    end

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

-- ================= AUTO MAIL LIÊN TỤC & AUTO CLAIM MAIL =================
local isMailing = false
local function checkAndRunContinuousMail()
    local mCfg = CFG.Mail
    if not (mCfg and mCfg.Enabled) or isMailing then return end
    if type(mCfg.Recipient) ~= "string" or mCfg.Recipient == "" or mCfg.Recipient == "DienTenAccNhanVaoDay" then return end
    if string.lower(mCfg.Recipient) == string.lower(LocalPlayer.Name) then return end
    if currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then return end

    if mCfg.AutoClaimMail and os.clock() > state.nextClaimMailAt then
        state.nextClaimMailAt = os.clock() + 15
        pcall(function()
            local ok, res = netInvoke("Mailbox: ClaimAll")
            if ok and res then
                state.mailsClaimed = state.mailsClaimed + 1
            end
        end)
    end

    local s = getSave()
    local inv = s and s.Inventory
    if type(inv) ~= "table" then return end

    local toSend = {}

    if mCfg.SendAllHuges and type(inv.Pet) == "table" then
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

        for uid, data in pairs(inv.Pet) do
            if type(data) == "table" and type(data.id) == "string" then
                if string.find(string.lower(data.id), "huge", 1, true) and not data.lk then
                    local amt = tonumber(data._am) or 1
                    if equippedSet[uid] then netFire("Pets_UnequipByUID", uid) task.wait(0.2) end
                    table.insert(toSend, { Category = "Pet", UID = uid, Amount = amt, Name = data.id })
                end
            end
        end
    end

    if type(inv.Consumable) == "table" and type(mCfg.Consumables) == "table" then
        for uid, data in pairs(inv.Consumable) do
            if type(data) == "table" and type(data.id) == "string" and not data.lk then
                local itemAmt = tonumber(data._am) or 1
                local itemTier = tonumber(data.tn) or 1
                local itemIdLower = string.lower(data.id)

                for _, rule in ipairs(mCfg.Consumables) do
                    local ruleIdLower = string.lower(tostring(rule.Id or ""))
                    local ruleTier = tonumber(rule.Tier) or 1
                    local ruleMin = tonumber(rule.MinAmount) or 1

                    if itemIdLower == ruleIdLower and itemTier == ruleTier then
                        if itemAmt >= ruleMin then
                            table.insert(toSend, {
                                Category = "Consumable",
                                UID = uid,
                                Amount = itemAmt,
                                Name = string.format("%s (Tier %d)", data.id, itemTier)
                            })
                        end
                        break
                    end
                end
            end
        end
    end

    if #toSend == 0 then return end

    isMailing = true
    for _, item in ipairs(toSend) do
        if not state.alive or currency("Diamonds") < (mCfg.MinDiamondsToKeep or 50000) then break end
        local ok, res = netInvoke("Mailbox: Send", mCfg.Recipient, "kizhub auto mail", item.Category, item.UID, item.Amount)
        if ok and res == true then
            state.mailsSent = state.mailsSent + 1
            sendWebhook("📦 GỬI MAIL THÀNH CÔNG!", string.format("Đã gửi **%s** (x%d) đến **%s**", item.Name, item.Amount, mCfg.Recipient), 0x00FF88)
        end
        task.wait(1.2)
    end
    isMailing = false
end

-- ================= CẬP NHẬT GIAO DIỆN KIZHUB & TIÊU ĐỀ WINDOWS =================
local function updateKizhubGui()
    if not uiRefs.ZoneLabel then return end

    local zData = K.ZONES[state.currentZoneNumber]
    uiRefs.ZoneLabel.Text = string.format("Zone %d/8 (%s)", state.currentZoneNumber, zData and zData.Name or "")
    uiRefs.CombineLabel.Text = state.combineStatus
    uiRefs.MailLabel.Text = string.format("Đã gửi: %d | Đã nhận: %d", state.mailsSent, state.mailsClaimed)
    uiRefs.CoinsLabel.Text = shorten(currency(K.CURRENCY))
    uiRefs.TreatsLabel.Text = string.format("%s Treats | %s quả", shorten(currency(K.TREATS)), shorten(state.totalEggsHatched))

    -- Render 8 nâng cấp Treats chuẩn gốc
    local upgLines = {}
    for _, u in ipairs(K.UPGRADES) do
        local tier = 0
        pcall(function()
            tier = isfn(G.EventUpgradeCmds, "GetTier") and gval(G.EventUpgradeCmds.GetTier, u.Id) or 0
        end)
        local dir = G.EventUpgrades and G.EventUpgrades[u.Id]
        local maxTier = (dir and type(dir.TierPowers) == "table") and #dir.TierPowers or 5
        local tierStr = (tier >= maxTier) and "MAX" or string.format("%d/%d", tier, maxTier)
        table.insert(upgLines, string.format("%s: %s", u.Name, tierStr))
    end

    local formatted = ""
    for i = 1, #upgLines, 2 do
        local col1 = upgLines[i] or ""
        local col2 = upgLines[i+1] or ""
        formatted = formatted .. string.format("%s | %s\n", col1, col2)
    end
    uiRefs.UpgradesLabel.Text = formatted

    pcall(function()
        local titleFn = setwindowtitle or set_window_title
        if titleFn then
            titleFn(string.format("[%s] Z%d | %s Xu | %s Trứng",
                LocalPlayer.Name,
                state.currentZoneNumber or 1,
                shorten(currency(K.CURRENCY) or 0),
                shorten(state.totalEggsHatched or 0)
            ))
        end
    end)
end

-- ================= VÒNG LẶP CHÍNH (CHU TRÌNH 8 ZONE) =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if not CFG.Enabled then return end
            if not ensureInHalloweenEvent() then return end
            if state.excursion ~= nil then return end

            tryUnlockNextZone()
            local currentZone = bestUnlockedZone()
            state.currentZoneNumber = currentZone

            local zoneData = K.ZONES[currentZone]
            if zoneData and zoneData.Pos then
                local p = playerPos()
                if not p or dist(p, zoneData.Pos) > 12 then
                    teleportTo(zoneData.Pos)
                    task.wait(0.3)
                end
            end

            farmZoneBreakables(currentZone)

            local eggInfo = findCustomEggById(zoneData.Egg)
            if currentZone <= 7 then
                local hatchedSoFar = state.zoneHatchCounts[currentZone] or 0
                local maxRequired = CFG.First7ZonesHatchTimes or 5
                if hatchedSoFar < maxRequired then
                    if eggInfo then
                        local okH, _ = hatchZoneEgg(eggInfo)
                        if okH then
                            state.zoneHatchCounts[currentZone] = hatchedSoFar + 1
                        end
                    end
                end
            else
                if eggInfo then
                    hatchZoneEgg(eggInfo)
                end
            end
        end)
        task.wait(math.max(0.2, CFG.HatchDelay or 0.5))
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

-- Vòng lặp Treat Upgrades, Ghép Huge, Free Gifts & Buffs
task.spawn(function()
    while state.alive do
        pcall(function()
            if CFG.Enabled and inEvent() then
                checkAndRunTreatUpgrades()
                checkAndRunCombine()
                checkAndClaimFreeGifts()
                runDelayedBuffs(bestUnlockedZone())
            end
        end)
        task.wait(4)
    end
end)

-- Vòng lặp Auto Mail liên tục (Mỗi 3s quét kiểm tra mốc MinAmount)
task.spawn(function()
    while state.alive do
        pcall(function()
            if CFG.Enabled then checkAndRunContinuousMail() end
        end)
        task.wait(3)
    end
end)

-- Vòng lặp cập nhật giao diện kizhub & Windows Title (4s/lần)
task.spawn(function()
    while state.alive do
        pcall(updateKizhubGui)
        task.wait(4)
    end
end)

-- Vòng lặp báo cáo Heartbeat (Gửi sang Kênh 2: StatusUrl)
task.spawn(function()
    while state.alive do
        local interval = (CFG.Webhook and CFG.Webhook.StatusInterval) or 600
        task.wait(interval)
        
        pcall(function()
            local wb = CFG.Webhook
            if wb and wb.Enabled and wb.StatusUrl and wb.StatusUrl ~= "" then
                local currentCoins = shorten(currency(K.CURRENCY) or 0)
                local currentTreats = shorten(currency(K.TREATS) or 0)
                local totalHatched = shorten(state.totalEggsHatched or 0)
                local currentZ = state.currentZoneNumber or 1
                local zoneInfo = K.ZONES[currentZ]
                local zoneTitle = string.format("Zone %d/8 (%s)", currentZ, zoneInfo and zoneInfo.Name or "Unknown")

                local statusDesc = string.format(
                    "📍 **Khu vực:** `%s`\n" ..
                    "🍬 **Candy Coins:** `%s`\n" ..
                    "🎃 **Treats:** `%s`\n" ..
                    "🥚 **Trứng đã nở:** `%s` quả\n" ..
                    "📦 **Mail:** Đã gửi `%d` | Đã nhận `%d`\n" ..
                    "🛠️ **Ghép Huge:** `%s`",
                    zoneTitle,
                    currentCoins,
                    currentTreats,
                    totalHatched,
                    state.mailsSent or 0,
                    state.mailsClaimed or 0,
                    state.combineStatus or "Rảnh"
                )

                sendWebhook(
                    "🟢 [STATUS] " .. LocalPlayer.Name,
                    statusDesc,
                    0x00E676,
                    nil,
                    wb.StatusUrl
                )
            end
        end)
    end
end)

-- Vòng lặp thu gom rác bộ nhớ (Garbage Collector) mỗi 60 giây
task.spawn(function()
    while state.alive do
        task.wait(60)
        pcall(function() collectgarbage("collect") end)
    end
end)

genv.Kizhub_HG = {
    Stop = function()
        state.alive = false
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
        local parentGui = (type(gethui) == "function" and gethui()) or CoreGui
        local g = parentGui:FindFirstChild("Kizhub_WhiteScreen")
        if g then g:Destroy() end
    end
}
