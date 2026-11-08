-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (KIZHUB FULL - GUI RESTORED + GOD ANTI-AFK)
-- Tích hợp: Khôi phục Full GUI thẻ trắng + Bộ đếm Uptime, Anti-AFK God Mode,
-- Auto Mail Exodus (IsHuge, Direct Send, Random Title), 5 FPS Tối ưu CPU
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.Kizhub_HG) == "table" and type(genv.Kizhub_HG.Stop) == "function" then
    pcall(genv.Kizhub_HG.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN KIZHUB =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Khóa FPS tối ưu CPU
    TargetFPS = 5,
    LogoAssetId = "rbxassetid://10709791437",

    -- 2. Quà tặng miễn phí (Free Gifts)
    AutoClaimFreeGifts = true,

    -- 3. Mở trứng 8 Zone
    First7ZonesHatchTimes = 5,
    HatchDelay = 1.0,

    -- 4. Nâng cấp sự kiện (8 món chuẩn)
    AutoTreatUpgrades = true,
    UpgradeCooldown = 600,

    -- 5. Ghép Huge Bat Hoodie Bunny
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 60,

    -- 6. Chu kỳ Anti-AFK God Mode (3 phút = 180 giây)
    AfkPulseInterval = 180,

    -- 7. Auto Mail (Exodus Automail Logic)
    Mail = {
        Enabled = true,
        Recipient = "Kizmoii_VNG",
        StartupDelay = 40,
        MailCooldown = 60,
        MinDiamondsToKeep = 10000,
        AutoClaimMail = true,
        SendAllHuges = true,
        
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

    -- 8. Discord Webhook Tách 2 Kênh Độc Lập
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1444485821909569558/ONQp3ZOyvQevUptUSVbLQpkm5SZZDUOEUr0LTZGoYNPeh_NlMwTxeIS8kEre_u7qEvfC",
        NotifyOnHuge = true,
        NotifyOnMail = true,

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

-- ================= KHỞI TẠO SERVICES & THREAD IDENTITY =================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
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

-- ================= TỐI ƯU HÓA ENGINE (5 FPS / 0% GPU) =================
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
end)

-- ================= NẠP TOÀN DIỆN THƯ VIỆN CLIENT (CHUẨN AUTOMAIL) =================
local ExodusLibrary = {}
pcall(function()
    local clientFolder = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client")
    if clientFolder then
        for _, v in ipairs(clientFolder:GetChildren()) do
            if v:IsA("ModuleScript") and not v:GetAttribute("NOLOAD") then
                local ok, mod = pcall(require, v)
                if ok and type(mod) == "table" then
                    ExodusLibrary[v.Name] = mod
                end
            end
        end
    end
    local libFolder = RS:FindFirstChild("Library")
    if libFolder then
        for _, v in ipairs(libFolder:GetChildren()) do
            if v:IsA("ModuleScript") and not v:GetAttribute("NOLOAD") then
                local ok, mod = pcall(require, v)
                if ok and type(mod) == "table" then
                    ExodusLibrary[v.Name] = mod
                end
            end
        end
    end
end)

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
    Network           = ExodusLibrary.Network or req("Library.Client.Network"),
    Save              = ExodusLibrary.Save or req("Library.Client.Save"),
    Instancing        = ExodusLibrary.InstancingCmds or req("Library.Client.InstancingCmds"),
    InstanceZone      = ExodusLibrary.InstanceZoneCmds or req("Library.Client.InstanceZoneCmds"),
    CustomEggs        = ExodusLibrary.CustomEggsCmds or req("Library.Client.CustomEggsCmds"),
    EggCmds           = ExodusLibrary.EggCmds or req("Library.Client.EggCmds"),
    Eggs              = req("Library.Directory.Eggs"),
    CurrencyCmds      = ExodusLibrary.CurrencyCmds or req("Library.Client.CurrencyCmds"),
    PlayerPet         = ExodusLibrary.PlayerPet or req("Library.Client.PlayerPet"),
    PetCmds           = ExodusLibrary.PetCmds or req("Library.Client.PetCmds"),
    BreakableFrontend = ExodusLibrary.BreakableFrontend or req("Library.Client.BreakableFrontend"),
    EventUpgrades     = req("Library.Directory.EventUpgrades"),
    EventUpgradeCmds  = ExodusLibrary.EventUpgradeCmds or req("Library.Client.EventUpgradeCmds"),
    HGUpgrades        = req("Library.Client.HalloweenGamesCmds.Upgrades", true),
    TabController     = req("Library.Client.TabController", true),
    Directory         = req("Library.Directory"),
    FFlags            = ExodusLibrary.FFlags or req("Library.Client.FFlags"),
}

-- ================= DỮ LIỆU TỌA ĐỘ 8 ZONE & 8 UPGRADES =================
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
    nextUnlockTryAt = 0,
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextFlagAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextClaimMailAt = 0,
    nextClaimGiftsAt = 0,
    currentZoneNumber = 1,
}

local connections = {}
local restoreFns = {}

-- ================= TIỆN ÍCH MẠNG & THÔNG SỐ =================
local function netInvoke(name, ...)
    if isfn(G.Network, "Invoke") then return gcall(G.Network.Invoke, name, ...) end
    return false, "Network.Invoke unavailable"
end

local function netFire(name, ...)
    if isfn(G.Network, "Fire") then return gcall(G.Network.Fire, name, ...) end
    return false, "Network.Fire unavailable"
end

local function netUnreliable(name, ...)
    if isfn(G.Network, "UnreliableFire") then return gcall(G.Network.UnreliableFire, name, ...) end
    return false
end

local function getSave()
    if isfn(G.Save, "Get") then return gval(G.Save.Get) end
    return nil
end

local function GetDiamonds(ReturnUID)
    local s = getSave()
    local cur = s and s.Inventory and s.Inventory.Currency
    if type(cur) == "table" then
        for i, v in pairs(cur) do
            if type(v) == "table" and v.id == "Diamonds" then
                return ReturnUID and i or (tonumber(v._am) or 0)
            end
        end
    end
    return 0
end

local function currency(id)
    if id == "Diamonds" then return GetDiamonds(false) end
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

-- ================= DISCORD WEBHOOK SENDER =================
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

-- ================= HỆ THỐNG ANTI-AFK GOD MODE ĐA TẦNG =================
local function installGodModeAntiAfk()
    -- 1. Xóa các listener Idled mặc định
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)

    -- 2. Đón đầu Idled bằng Click chuột ảo VirtualUser
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

    -- 3. Xung nhịp định kỳ 3 phút (Jump + VIM + Micro Pan Camera + Remote Bypass)
    task.spawn(function()
        local interval = CFG.AfkPulseInterval or 180
        while state.alive do
            task.wait(interval)
            if not state.alive then break end

            print("🛡️ [ANTI-AFK]: Kích hoạt xung nhịp chống kick God Mode...")

            -- Nhảy vật lý
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    hum.Jump = true
                end
            end)

            -- Bấm phím ảo qua VirtualInputManager
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)

            -- Nhích nhẹ góc nhìn Camera để ép Roblox gửi Replication Packet lên Server
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.05), 0)
                    task.wait(0.08)
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-0.05), 0)
                end
            end)

            -- Quét tắt liên tục Idle Tracking & Server Closing trong Core Scripts
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

            -- Bắn Remote báo server PS99 hủy bộ đếm idle
            pcall(function()
                netFire("Idle Tracking: Stop Timer")
            end)
        end
    end)
    print("🛡️ [KIZHUB]: Đã cài đặt Anti-AFK God Mode 24/24")
end
pcall(installGodModeAntiAfk)

-- Hook tốc độ thú cưng & bỏ diễn hoạt nở trứng
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

-- ================= FULLSCREEN GUI MÀN TRẮNG (KHÔI PHỤC HOÀN CHỈNH) =================
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

    local WhiteCover = Instance.new("Frame")
    WhiteCover.Name = "WhiteCover"
    WhiteCover.Size = UDim2.new(1, 0, 1, 0)
    WhiteCover.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    WhiteCover.BorderSizePixel = 0
    WhiteCover.Parent = ScreenGui

    local KizCard = Instance.new("Frame")
    KizCard.Name = "KizCard"
    KizCard.Size = UDim2.new(0, 380, 0, 365)
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
    SubInfo.Text = "God Mode Anti-AFK • Exodus Mail • Low Request"
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
        lbl.Size = UDim2.new(0, 130, 0, 18)

        local val = Instance.new("TextLabel", InfoContainer)
        val.Text = defaultVal
        val.Font = Enum.Font.GothamBold
        val.TextSize = 12
        val.TextColor3 = highlightColor or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(0, 130, 0, yPos)
        val.Size = UDim2.new(1, -130, 0, 18)
        return val
    end

    uiRefs.UptimeLabel  = createRow("Thời Gian Chạy:", "00:00:00 (0.0 phút)", 0, Color3.fromRGB(0, 255, 140))
    uiRefs.ZoneLabel    = createRow("Zone Hiện Tại:", "Đang tải...", 22)
    uiRefs.CombineLabel = createRow("Trạng Thái Combine:", "Rảnh", 44)
    uiRefs.CoinsLabel   = createRow("Candy Coins:", "0", 66)
    uiRefs.TreatsLabel  = createRow("Treats / Trứng Nở:", "0 / 0", 88)
    uiRefs.MailLabel    = createRow("Hệ Thống Mailbox:", "Gửi: 0 |