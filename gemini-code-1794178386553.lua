-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (WATCHDOG REJOIN • VYHUB TREAT UPGRADES)
-- Tính năng: Watchdog kẹt mở trứng (Rejoin sau 7p), Treat Upgrades bê nguyên từ
-- halloween.lua (ưu tiên Trang 2), 100% Auto Combine Huge Bunny, GUI góc phải trên
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.Kizhub_HG) == "table" and type(genv.Kizhub_HG.Stop) == "function" then
    pcall(genv.Kizhub_HG.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN KIZHUB =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Giới hạn FPS tối ưu tài nguyên máy
    TargetFPS = 5,
    LogoAssetId = "rbxassetid://10709791437",

    -- 2. Quà tặng miễn phí (Free Gifts)
    AutoClaimFreeGifts = true,

    -- 3. Mở trứng 8 Zone
    First7ZonesHatchTimes = 5,
    HatchDelay = 1.0,

    -- 4. WATCHDOG: Tự động Rejoin nếu kẹt mở trứng quá lâu (Mặc định 7 phút)
    Watchdog = {
        Enabled = true,
        MaxIdleHatchMinutes = 7, -- 7 phút không mở được quả trứng nào -> Tự Rejoin
    },

    -- 5. Treat Upgrades (Bê nguyên logic chuẩn từ halloween.lua)
    AutoTreatUpgrades = true,
    UpgradeCooldown = 180,

    -- 6. Auto Combine (BẢO TOÀN 100%: Ghép Huge Bat Hoodie Bunny)
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 60,

    -- 7. Chu kỳ Anti-AFK God Mode (180s = 3 phút)
    AfkPulseInterval = 180,

    -- 8. Discord Webhook
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1444485821909569558/ONQp3ZOyvQevUptUSVbLQpkm5SZZDUOEUr0LTZGoYNPeh_NlMwTxeIS8kEre_u7qEvfC", -- ⚠️ Thay link mới nếu link cũ bị phá
        NotifyOnHuge = true,
        StatusUrl = "https://discord.com/api/webhooks/1372817821293219860/0RlqBFpPwUX-TjWsrcpLhDDEY8EKsz_6gbywjKK2J361TIg2YfwvbVE-ZxDcymNjxB44",
        StatusInterval = 600,
    },

    -- 9. Auto Buffs
    AutoBuffs = {
        Toys = true,
        Fruits = true,
        Potions = true,
        Flags = true,
        PreferredFlags = { "Coins Flag", "Fortune Flag", "Hasty Flag", "Magnet Flag" },
    },
}
local CFG = genv.KaitunConfig

-- ================= KHỞI TẠO SERVICES & IDENTITY =================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

repeat task.wait(0.2) until LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

local SCRIPT_START_TIME = os.clock()

local function formatUptime()
    local elapsed = math.max(0, math.floor(os.clock() - SCRIPT_START_TIME))
    local hrs = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = elapsed % 60
    local totalMins = elapsed / 60
    return string.format("%02d:%02d:%02d (%.1f phút)", hrs, mins, secs, totalMins), totalMins
end

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

-- ================= TỐI ƯU HÓA ENGINE & ĐỒ HỌA =================
pcall(function()
    if type(setfpscap) == "function" then
        setfpscap(CFG.TargetFPS or 5)
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
end)

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.Technology = Enum.Technology.Compatibility

    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
            v.Enabled = false
        end
    end

    local function stripHeavyVisuals(obj)
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        stripHeavyVisuals(obj)
    end
    workspace.DescendantAdded:Connect(stripHeavyVisuals)
end)

-- ================= NẠP CLIENT MODULES (ĐẦY ĐỦ TỪ HALLOWEEN.LUA) =================
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
    MachineCmds       = req("Library.Client.MachineCmds"),
    TabController     = req("Library.Client.TabController", true),
    Directory         = req("Library.Directory"),
    Items             = req("Library.Items"),
    FFlags            = req("Library.Client.FFlags", true),
}

-- ================= BẢNG NÂNG CẤP BÊ NGUYÊN TỪ HALLOWEEN.LUA =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    UPGRADE_MACHINE = "HalloweenGamesUpgradeMachine",
    MACHINE_REACH   = 8,
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    ZONES = {
        [1] = { Number = 1, Name = "Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60, 16.20, -3939.52) },
        [2] = { Number = 2, Name = "Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83, 16.24, -3940.37) },
        [3] = { Number = 3, Name = "Poltergeist Barn", Egg = "Poltergeist Egg", Pos = Vector3.new(-5658.55, 16.39, -3941.15) },
        [4] = { Number = 4, Name = "Carousel Fair",    Egg = "Carousel Egg",    Pos = Vector3.new(-5811.52, 16.42, -3939.43) },
        [5] = { Number = 5, Name = "Masquerade Manor", Egg = "Masquerade Egg",  Pos = Vector3.new(-5984.74, 16.24, -3939.23) },
        [6] = { Number = 6, Name = "Witch Village",    Egg = "Witch Hat Egg",   Pos = Vector3.new(-6338.53, 16.92, -3910.60) },
        [7] = { Number = 7, Name = "Masquerade Ball",  Egg = "Ballroom Egg",    Pos = Vector3.new(-6519.39, 16.96, -3911.23) },
        [8] = { Number = 8, Name = "Thorn Spire",      Egg = "Thorn Egg",       Pos = Vector3.new(-6680.50, 16.92, -3910.71) },
    },
    UPGRADES = {
        { Key = "PetSavings",     Id = "HalloweenGamesPetSavings",     Name = "Pet Savings (Forge Saver)" },
        { Key = "BetterVariants", Id = "HalloweenGamesBetterVariants", Name = "Better Variants" },
        { Key = "HugeLuck",       Id = "HalloweenGamesHugeLuck",       Name = "Huge Luck" },
        { Key = "EggLuck",        Id = "HalloweenGamesEggLuck",        Name = "More Egg Luck" },
        { Key = "CoinFinder",     Id = "HalloweenGamesCoinFinder",     Name = "Coin Finder" },
        { Key = "Golden",         Id = "HalloweenGamesGolden",         Name = "More Gold" },
        { Key = "Rainbow",        Id = "HalloweenGamesRainbow",        Name = "More Rainbow" },
        { Key = "Shiny",          Id = "HalloweenGamesShiny",          Name = "Ooo Shiny" },
    },
    OBJECTIVE_ORDER = {
        -- Ưu tiên Trang 2: PetSavings & BetterVariants đứng đầu!
        ["Combine First"] = { "PetSavings", "BetterVariants", "HugeLuck", "EggLuck", "CoinFinder", "Golden", "Rainbow", "Shiny" },
    }
}

local state = {
    alive = true,
    excursion = nil,
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 },
    totalEggsHatched = 0,
    combineStatus = "Rảnh",
    lastSuccessfulHatch = os.clock(), -- Bộ đếm Watchdog chống kẹt
    nextUnlockTryAt = 0,
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextFlagAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
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

-- ================= DISCORD WEBHOOK =================
local function sendWebhook(title, description, color, customUrl)
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

-- ================= HÀM TỰ ĐỘNG REJOIN KHI WATCHDOG BÁO KẸT =================
local function forceRejoin(reason)
    print(string.format("🔄 [WATCHDOG]: %s -> Đang Rejoin để tự sửa lỗi...", reason))
    sendWebhook("⚠️ [WATCHDOG REJOIN]", string.format("**%s** bị kẹt: %s. Đang tiến hành Rejoin lại server!", LocalPlayer.Name, reason), 0xFF3333)

    task.wait(1)
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\n[WATCHDOG]: Kẹt mở trứng quá lâu. Đang Rejoin lại...")
            task.wait(0.5)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
end

-- ================= HỆ THỐNG ANTI-AFK GOD MODE =================
local function installGodModeAntiAfk()
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)

    table.insert(connections, LocalPlayer.Idled:Connect(function()
        if not state.alive then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
            task.wait(0.05)
            VirtualUser:Button2Up(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
        end)
    end))

    task.spawn(function()
        local interval = CFG.AfkPulseInterval or 180
        while state.alive do
            task.wait(interval)
            if not state.alive then break end

            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    hum.Jump = true
                end
            end)

            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)

            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.05), 0)
                    task.wait(0.08)
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-0.05), 0)
                end
            end)

            pcall(function()
                local pScripts = LocalPlayer:FindFirstChild("PlayerScripts")
                local coreFolder = pScripts and pScripts:FindFirstChild("Scripts") and pScripts.Scripts:FindFirstChild("Core")
                if coreFolder then
                    local idl = coreFolder:FindFirstChild("Idle Tracking")
                    if idl then idl.Enabled = false end
                    local sc = coreFolder:FindFirstChild("Server Closing")
                    if sc then sc.Enabled = false end
                end
            end)

            pcall(function()
                netFire("Idle Tracking: Stop Timer")
            end)
        end
    end)
end
pcall(installGodModeAntiAfk)

-- ================= SKIP EGG ANIMATION (GETSENV) =================
local function installNoHatchAnimation()
    task.spawn(function()
        local attempts = 0
        while state.alive and attempts < 30 do
            attempts = attempts + 1
            local ok, hooked = pcall(function()
                if type(getsenv) ~= "function" then return false end
                local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
                local scripts = ps and ps:FindFirstChild("Scripts")
                local gameFolder = scripts and scripts:FindFirstChild("Game")
                local eggScript = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
                if not eggScript then return false end

                local env = getsenv(eggScript)
                if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                    if not env._kizhubHooked then
                        local orig = env.PlayEggAnimation
                        env.PlayEggAnimation = function(...)
                            if state.alive then return end
                            return orig(...)
                        end
                        env._kizhubHooked = true
                        table.insert(restoreFns, function() env.PlayEggAnimation = orig end)
                    end
                    return true
                end
                return false
            end)

            if ok and hooked == true then
                break
            end
            task.wait(1.0)
        end
    end)
end
pcall(installNoHatchAnimation)

-- Hook tốc độ thú cưng
pcall(function()
    if type(hookfunction) == "function" and isfn(G.PlayerPet, "CalculateSpeedMultiplier") then
        local orig
        orig = hookfunction(G.PlayerPet.CalculateSpeedMultiplier, function(...)
            if state.alive then return math.huge end
            return orig(...)
        end)
    end
end)

-- ================= GUI KIZCARD (CỐ ĐỊNH GÓC PHẢI TRÊN • TẮT MÀN TRẮNG) =================
local uiRefs = {}
pcall(function()
    local parentGui = (type(gethui) == "function" and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui
    local oldGui = parentGui:FindFirstChild("Kizhub_WhiteScreen")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kizhub_WhiteScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parentGui

    -- Cố định góc trên bên phải màn hình
    local KizCard = Instance.new("Frame")
    KizCard.Name = "KizCard"
    KizCard.AnchorPoint = Vector2.new(1, 0)
    KizCard.Position = UDim2.new(1, -20, 0, 20)
    KizCard.Size = UDim2.new(0, 395, 0, 345)
    KizCard.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    KizCard.BackgroundTransparency = 0.15
    KizCard.BorderSizePixel = 0
    KizCard.Active = true
    KizCard.Draggable = true
    KizCard.Parent = ScreenGui

    Instance.new("UICorner", KizCard).CornerRadius = UDim.new(0, 14)
    local CardStroke = Instance.new("UIStroke", KizCard)
    CardStroke.Color = Color3.fromRGB(255, 140, 0)
    CardStroke.Thickness = 1.8

    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Size = UDim2.new(1, 0, 0, 95)
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
    SubInfo.Text = "Auto Farm • Auto Combine Huge • VyHub Upgrades"
    SubInfo.Font = Enum.Font.Gotham
    SubInfo.TextSize = 11
    SubInfo.TextColor3 = Color3.fromRGB(160, 160, 175)
    SubInfo.TextXAlignment = Enum.TextXAlignment.Left
    SubInfo.BackgroundTransparency = 1
    SubInfo.Position = UDim2.new(0, 90, 0, 42)
    SubInfo.Size = UDim2.new(1, -90, 0, 16)

    local SepLine = Instance.new("Frame", KizCard)
    SepLine.Size = UDim2.new(1, -36, 0, 1)
    SepLine.Position = UDim2.new(0, 18, 0, 92)
    SepLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SepLine.BorderSizePixel = 0

    local InfoContainer = Instance.new("Frame", KizCard)
    InfoContainer.Size = UDim2.new(1, -36, 1, -102)
    InfoContainer.Position = UDim2.new(0, 18, 0, 100)
    InfoContainer.BackgroundTransparency = 1

    local function createRow(labelText, defaultVal, yPos, highlightColor)
        local lbl = Instance.new("TextLabel", InfoContainer)
        lbl.Text = labelText
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(200, 200, 215)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 0, 0, yPos)
        lbl.Size = UDim2.new(0, 135, 0, 18)

        local val = Instance.new("TextLabel", InfoContainer)
        val.Text = defaultVal
        val.Font = Enum.Font.GothamBold
        val.TextSize = 12
        val.TextColor3 = highlightColor or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(0, 135, 0, yPos)
        val.Size = UDim2.new(1, -135, 0, 18)
        return val
    end

    uiRefs.UptimeLabel  = createRow("Thời Gian Chạy:", "00:00:00 (0.0 phút)", 0, Color3.fromRGB(0, 255, 140))
    uiRefs.ZoneLabel    = createRow("Zone Hiện Tại:", "Đang tải...", 22)
    uiRefs.CombineLabel = createRow("Ghép Huge Bunny:", "Rảnh", 44, Color3.fromRGB(255, 215, 0))
    uiRefs.CoinsLabel   = createRow("Candy Coins:", "0", 66)
    uiRefs.TreatsLabel  = createRow("Treats / Trứng Nở:", "0 / 0", 88)

    local UpgTitle = Instance.new("TextLabel", InfoContainer)
    UpgTitle.Text = "Tiến Trình Treat Upgrades (VyHub Logic):"
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
    uiRefs.UpgradesLabel.TextSize = 10
    uiRefs.UpgradesLabel.TextColor3 = Color3.fromRGB(180, 235, 200)
    uiRefs.UpgradesLabel.TextXAlignment = Enum.TextXAlignment.Left
    uiRefs.UpgradesLabel.TextYAlignment = Enum.TextYAlignment.Top
    uiRefs.UpgradesLabel.TextWrapped = true
    uiRefs.UpgradesLabel.BackgroundTransparency = 1
    uiRefs.UpgradesLabel.Position = UDim2.new(0, 0, 0, 134)
    uiRefs.UpgradesLabel.Size = UDim2.new(1, 0, 0, 105)
end)

-- ================= QUẢN LÝ INSTANCE HALLOWEEN =================
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
    local id = currentInstanceId()
    local things = workspace:FindFirstChild("__THINGS")
    local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local act = cont and cont:FindFirstChild("Active")
    return act and id and act:FindFirstChild(id) or nil
end

local function isPhysicallyInHalloweenMap()
    local p = playerPos()
    if not p then return false end
    for i = 1, 8 do
        if dist(p, K.ZONES[i].Pos) < 450 then return true end
    end
    return false
end

local function inEvent()
    return currentInstanceId() == K.INSTANCE_ID or isPhysicallyInHalloweenMap()
end

local lastEnterAttempt = 0
local function ensureInHalloweenEvent()
    if inEvent() then return true end
    local now = os.clock()
    if now - lastEnterAttempt < 30 then return false end
    lastEnterAttempt = now

    if isfn(G.Instancing, "Enter") then
        gcall(G.Instancing.Enter, K.INSTANCE_ID)
    end
    local t0 = os.clock()
    while state.alive and os.clock() - t0 < 15 do
        if inEvent() then
            task.wait(1.5)
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
    local now = os.clock()
    if now < state.nextUnlockTryAt then return false end
    state.nextUnlockTryAt = now + 8

    local best = bestUnlockedZone()
    if best >= 8 then return false end
    local nextZ = best + 1

    local obj = isfn(G.Instancing, "Get") and gval(G.Instancing.Get) or nil
    local zInfo = obj and obj.instanceZones and obj.instanceZones[nextZ]
    if zInfo then
        local cost = tonumber(zInfo.CurrencyCost)
        local curId = zInfo.CurrencyId or K.CURRENCY
        if cost and currency(curId) < cost then
            return false
        end
    end

    local ok, res = netInvoke("InstanceZones_RequestPurchase", K.INSTANCE_ID, nextZ)
    return ok and res == true
end

-- ================= HATCH TRỨNG TỰ ĐỘNG & WATCHDOG TRIGGER =================
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
    if not egg then return false, 0 end
    local maxAmount = getAccountMaxHatch(egg)
    local target = egg.uid or egg.id
    if not target then return false, 0 end

    local ok, res = netInvoke("CustomEggs_Hatch", target, maxAmount)
    if ok and res == true then
        state.totalEggsHatched = state.totalEggsHatched + maxAmount
        state.lastSuccessfulHatch = os.clock() -- RESET BỘ ĐẾM WATCHDOG
        return true, maxAmount
    end
    return false, 0
end

-- ================= FARM BREAKABLES & HÚT ORBS =================
local function petEuids()
    if not isfn(G.PlayerPet, "GetAll") then return {} end
    local ok, all = gcall(G.PlayerPet.GetAll)
    local res = {}
    if ok and type(all) == "table" then
        for _, p in pairs(all) do
            if type(p) == "table" and p.euid ~= nil then table.insert(res, p.euid) end
        end
    end
    return res
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
        task.wait(0.8)
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
    if now - lastHitSend > 1.2 then
        lastHitSend = now
        netUnreliable("Breakables_PlayerDealDamage", ordered[1].uid)
    end

    local map, changed = {}, false
    for i, euid in ipairs(pets) do
        local tUid = ordered[((i - 1) % #ordered) + 1].uid
        map[euid] = tUid
        if lastFastMap[euid] ~= tUid then changed = true end
    end

    if changed or (now - lastFastSend > 2.0) then
        lastFastSend = now
        lastFastMap = map
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

-- ================= TREAT UPGRADES: BÊ NGUYÊN BẢN TỪ HALLOWEEN_2.LUA =================
local function upgradeDir(id)
    local ok, d = pcall(function() return type(G.EventUpgrades) == "table" and G.EventUpgrades[id] or nil end)
    return ok and type(d) == "table" and d or nil
end

local function upgradeTier(id)
    if isfn(G.EventUpgradeCmds, "GetTier") then
        local t = gval(G.EventUpgradeCmds.GetTier, id)
        if type(t) == "number" then return t end
    end
    local s = getSave()
    return s and type(s.EventUpgrades) == "table" and (s.EventUpgrades[id] or 0) or 0
end

local function upgradeInfo(u)
    local d = upgradeDir(u.Id)
    local tier = upgradeTier(u.Id)
    local maxTier = d and type(d.TierPowers) == "table" and #d.TierPowers or 5
    local cost
    if d and tier < maxTier then
        if isfn(G.HGUpgrades, "Cost") then
            local okC, item = gcall(G.HGUpgrades.Cost, d, tier + 1)
            if okC and item then
                local okA, amt = pcall(function() return item:GetAmount() end)
                if okA and type(amt) == "number" then cost = amt end
            end
        end
        if not cost and type(d.TierCosts) == "table" and d.TierCosts[tier + 1] then
            local okC, amt = gcall(function() return d.TierCosts[tier + 1]:GetAmount() end)
            if okC and type(amt) == "number" then cost = amt end
        end
    end
    local onSale = true
    if isfn(G.HGUpgrades, "OnSale") then onSale = gval(G.HGUpgrades.OnSale, u.Id) ~= false end
    local power = d and type(d.TierPowers) == "table" and d.TierPowers[tier] or nil
    return { tier = tier, max = maxTier, cost = cost, power = power, disabled = (d == nil) or d.Disabled == true or not onSale, dir = d }
end

local function upgradeMachineModel()
    if not isfn(G.MachineCmds, "GetModels") then return nil end
    local ok, models = gcall(G.MachineCmds.GetModels, K.UPGRADE_MACHINE)
    if ok and type(models) == "table" then
        local m = instanceModel()
        for _, mod in pairs(models) do
            if typeof(mod) == "Instance" and (not m or mod:IsDescendantOf(m)) then return mod end
        end
    end
    local m = instanceModel()
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    return machines and machines:FindFirstChild(K.UPGRADE_MACHINE) or nil
end

local function machineStandPos()
    local mach = upgradeMachineModel()
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0), mach:GetPivot().Position end
    local pivot = mach:GetPivot().Position
    return pivot + Vector3.new(0, 3, 6), pivot
end

local function nearMachine()
    if isfn(G.MachineCmds, "CanUse") then
        local v = gval(G.MachineCmds.CanUse, K.UPGRADE_MACHINE)
        if v == true then return true end
    end
    local stand, pivot = machineStandPos()
    local p = playerPos()
    return pivot ~= nil and p ~= nil and dist(p, pivot) <= (K.MACHINE_REACH or 8) + 4
end

local function pickUpgrade()
    local treats = currency(K.TREATS)
    local candidates = {}
    for _, u in ipairs(K.UPGRADES) do
        local info = upgradeInfo(u)
        if info.dir and not info.disabled and info.tier < info.max and info.cost and info.cost <= treats then
            candidates[#candidates + 1] = { u = u, info = info }
        end
    end
    if #candidates == 0 then return nil end

    -- Ưu tiên theo thứ tự Combine First (PetSavings & BetterVariants trước)
    local order = K.OBJECTIVE_ORDER["Combine First"]
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

local function buyUpgrade(cand)
    local ok, res, msg = netInvoke("EventUpgrades: Purchase", cand.u.Id)
    if ok and res == true then
        print(string.format("🎃 [VYHUB UPGRADE]: Đã mua thành công %s (Tier %d)!", cand.u.Name, cand.info.tier + 1))
        return true
    end
    return false, msg or res
end

local function checkAndRunTreatUpgrades()
    if not CFG.AutoTreatUpgrades or not inEvent() or state.excursion ~= nil then return end
    local now = os.clock()
    if now < state.nextTreatUpgradeAt then return end

    local cand = pickUpgrade()
    if not cand then
        state.nextTreatUpgradeAt = now + 45
        return
    end

    state.excursion = "upgrades"
    local before = playerPos()

    pcall(function()
        local stand = machineStandPos()
        if not stand then return end
        if not nearMachine() then
            teleportTo(stand)
            local t0 = os.clock()
            repeat task.wait(0.2) until nearMachine() or os.clock() - t0 > 3 or not state.alive
        end

        local bought = 0
        while state.alive and cand and bought < 12 do
            local ok = buyUpgrade(cand)
            if not ok then break end
            bought = bought + 1
            task.wait(0.6)
            cand = pickUpgrade()
        end

        pcall(function()
            if G.TabController and type(G.TabController.Close) == "function" then
                G.TabController.Close("HalloweenGamesUpgradeMachine")
                G.TabController.Close("HalloweenUpgrades")
            end
        end)
    end)

    if before and state.alive then teleportTo(before) end
    state.excursion = nil
    state.nextTreatUpgradeAt = os.clock() + (CFG.UpgradeCooldown or 180)
end

-- ================= AUTO COMBINE HUGE BAT HOODIE BUNNY (GIỮ 100%) =================
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
                    n = n + c:CountAny()
                end
            end
            if item:CanBeShiny() then
                for _, v in ipairs({ "Normal", "Golden", "Rainbow" }) do
                    local c = item:Clone()
                    local ok = v == "Normal" or (v == "Golden" and c:CanBeGolden()) or (v == "Rainbow" and c:CanBeRainbow())
                    if ok then
                        if v ~= "Normal" then c["Set" .. v](c) end
                        c:SetShiny(true)
                        n = n + c:CountAny()
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
    local now = os.clock()
    if now < state.nextCombineAt then return end

    local dir = combineDir()
    if not dir or type(dir.Recipes) ~= "table" then return end

    local okQ, queue = netInvoke("HalloweenCraftingMachine_GetQueue")
    if not okQ or type(queue) ~= "table" then
        state.nextCombineAt = now + 45
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
        state.nextCombineAt = now + (CFG.CombineCooldown or 60)
        return
    end

    state.excursion = "combine"
    state.combineStatus = targetReady and "Đang bắt đầu ghép" or "Đang Claim Huge"
    local savedPos = playerPos()
    pcall(function()
        local stand = combineMachineStand()
        if stand then
            teleportTo(stand)
            task.wait(0.8)
        end
        for _, claim in ipairs(readyClaims) do
            netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            sendWebhook("🎉 GHÉP THÀNH CÔNG HUGE!", "Đã nhận thành công **" .. CFG.TargetCombineRecipe .. "**!", 0xFFD700)
            task.wait(0.6)
        end
        if targetReady and targetRecipeIndex then
            netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, targetRecipeIndex)
            task.wait(0.6)
        end
    end)
    if savedPos and state.alive then teleportTo(savedPos) end
    state.excursion = nil
    state.combineStatus = "Đang ghép Huge"
    state.nextCombineAt = os.clock() + (CFG.CombineCooldown or 60)
end

-- ================= AUTO CLAIM FREE GIFTS =================
local function checkAndClaimFreeGifts()
    if not CFG.AutoClaimFreeGifts then return end
    local now = os.clock()
    if now < state.nextClaimGiftsAt then return end
    state.nextClaimGiftsAt = now + 180

    pcall(function()
        local s = getSave()
        local redeemed = (s and type(s.RedeemedFreeGifts) == "table") and s.RedeemedFreeGifts or {}
        local alreadySet = {}
        for _, id in pairs(redeemed) do
            alreadySet[tonumber(id) or id] = true
        end

        for i = 1, 12 do
            if not alreadySet[i] then
                netInvoke("Redeem Free Gift", i)
                task.wait(0.8)
            end
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

    if bCfg.Toys and now > state.nextToyAt then
        pcall(function() netInvoke("ToyBall_Consume") end)
        task.wait(0.5)
        pcall(function() netInvoke("ToyBone_Consume") end)
        task.wait(0.5)
        pcall(function() netInvoke("SqueakyToy_Consume") end)
        state.nextToyAt = now + 900
    end

    if bCfg.Fruits and now > state.nextFruitAt and type(inv.Fruit) == "table" then
        for uid, data in pairs(inv.Fruit) do
            if type(data) == "table" and (tonumber(data._am) or 1) > 0 then
                netFire("Fruits: Consume", uid, 20)
                task.wait(0.3)
            end
        end
        state.nextFruitAt = now + 360
    end

    if bCfg.Potions and now > state.nextPotionAt and type(inv.Potion) == "table" then
        for uid, data in pairs(inv.Potion) do
            if type(data) == "table" and type(data.id) == "string" and (tonumber(data._am) or 1) > 0 then
                local pName = string.lower(data.id)
                if pName:find("coin") or pName:find("luck") or pName:find("damage") or pName:find("speed") or pName:find("treasure") then
                    netFire("Potions: Consume", uid)
                    task.wait(0.3)
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
                pcall(function() netInvoke("FlexibleFlags_Consume", prefName, foundFlagUid, zoneId) end)
                state.nextFlagAt = now + 360
                break
            end
        end
    end
end

-- ================= UPTIME TRACKER =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if uiRefs.UptimeLabel then
                local upStr = formatUptime()
                uiRefs.UptimeLabel.Text = upStr
            end
        end)
        task.wait(1)
    end
end)

-- ================= CẬP NHẬT GIAO DIỆN KIZCARD =================
local function updateKizhubGui()
    if not uiRefs.ZoneLabel then return end

    local upStr = formatUptime()
    local zData = K.ZONES[state.currentZoneNumber]
    uiRefs.ZoneLabel.Text = string.format("Zone %d/8 (%s)", state.currentZoneNumber, zData and zData.Name or "")
    uiRefs.CombineLabel.Text = state.combineStatus
    uiRefs.CoinsLabel.Text = shorten(currency(K.CURRENCY))
    uiRefs.TreatsLabel.Text = string.format("%s Treats | %s quả", shorten(currency(K.TREATS)), shorten(state.totalEggsHatched))

    -- Cập nhật danh sách 8 Upgrades từ halloween_2.lua
    local upgLines = {}
    for _, u in ipairs(K.UPGRADES) do
        local tier = upgradeTier(u.Id)
        local tag = (u.Key == "PetSavings" or u.Key == "BetterVariants") and "[P2]" or "[P1]"
        local tierStr = (tier >= 5) and "MAX" or string.format("%d/5", tier)
        table.insert(upgLines, string.format("%s %s: %s", tag, u.Name:gsub(" %(.*%)", ""), tierStr))
    end

    local formatted = ""
    for i = 1, #upgLines, 2 do
        local col1 = upgLines[i] or ""
        local col2 = upgLines[i+1] or ""
        formatted = formatted .. string.format("%-18s | %s\n", col1, col2)
    end
    uiRefs.UpgradesLabel.Text = formatted

    pcall(function()
        local titleFn = setwindowtitle or set_window_title
        if titleFn then
            titleFn(string.format("[%s] %s | Z%d | %s Xu",
                LocalPlayer.Name,
                upStr,
                state.currentZoneNumber or 1,
                shorten(currency(K.CURRENCY) or 0)
            ))
        end
    end)
end

-- ================= VÒNG LẶP WATCHDOG: THEO DÕI & REJOIN KHI KẸT =================
task.spawn(function()
    while state.alive do
        task.wait(15)
        pcall(function()
            local wCfg = CFG.Watchdog
            if not (wCfg and wCfg.Enabled) then return end
            if not inEvent() then return end
            if state.excursion ~= nil then return end

            local maxIdleSeconds = (wCfg.MaxIdleHatchMinutes or 7) * 60
            local timeSinceLastHatch = os.clock() - state.lastSuccessfulHatch

            if timeSinceLastHatch >= maxIdleSeconds then
                forceRejoin(string.format("Không nở được trứng trong %.1f phút", timeSinceLastHatch / 60))
            end
        end)
    end
end)

-- ================= VÒNG LẶP CHÍNH =================
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
                if not p or dist(p, zoneData.Pos) > 15 then
                    teleportTo(zoneData.Pos)
                    task.wait(0.4)
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
        task.wait(math.max(0.8, CFG.HatchDelay or 1.0))
    end
end)

-- Vòng lặp nhặt Orbs (0.4s)
task.spawn(function()
    while state.alive do
        if CFG.Enabled and inEvent() then
            pcall(collectOrbsTick)
        end
        task.wait(0.4)
    end
end)

-- Vòng lặp Treat Upgrades (VyHub), Ghép Huge, Free Gifts & Buffs (6s)
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
        task.wait(6)
    end
end)

-- Vòng lặp cập nhật GUI (4s/lần)
task.spawn(function()
    while state.alive do
        pcall(updateKizhubGui)
        task.wait(4)
    end
end)

-- Vòng lặp gửi Status Webhook (10 phút/lần)
task.spawn(function()
    while state.alive do
        local interval = (CFG.Webhook and CFG.Webhook.StatusInterval) or 600
        task.wait(interval)
        
        pcall(function()
            local wb = CFG.Webhook
            if wb and wb.Enabled and wb.StatusUrl and wb.StatusUrl ~= "" then
                local upStr = formatUptime()
                local currentCoins = shorten(currency(K.CURRENCY) or 0)
                local currentTreats = shorten(currency(K.TREATS) or 0)
                local totalHatched = shorten(state.totalEggsHatched or 0)
                local currentZ = state.currentZoneNumber or 1
                local zoneInfo = K.ZONES[currentZ]
                local zoneTitle = string.format("Zone %d/8 (%s)", currentZ, zoneInfo and zoneInfo.Name or "Unknown")

                local statusDesc = string.format(
                    "⏱️ **Thời gian chạy:** `%s`\n" ..
                    "📍 **Khu vực:** `%s`\n" ..
                    "🍬 **Candy Coins:** `%s`\n" ..
                    "🎃 **Treats:** `%s`\n" ..
                    "🥚 **Trứng đã nở:** `%s` quả\n" ..
                    "🛠️ **Ghép Huge:** `%s`",
                    upStr,
                    zoneTitle,
                    currentCoins,
                    currentTreats,
                    totalHatched,
                    state.combineStatus or "Rảnh"
                )

                sendWebhook(
                    "🟢 [STATUS] " .. LocalPlayer.Name,
                    statusDesc,
                    0x00E676,
                    wb.StatusUrl
                )
            end
        end)
    end
end)

-- Dọn RAM định kỳ
task.spawn(function()
    while state.alive do
        task.wait(60)
        pcall(function() collectgarbage("collect") end)
    end
end)

genv.Kizhub_HG = {
    Stop = function()
        state.alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
        local parentGui = (type(gethui) == "function" and gethui()) or CoreGui
        local g = parentGui:FindFirstChild("Kizhub_WhiteScreen")
        if g then g:Destroy() end
    end
}