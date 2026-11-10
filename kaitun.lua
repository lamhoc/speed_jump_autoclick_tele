-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (FINAL 100% PRODUCTION • BLACK SCREEN)
-- Cập nhật: Bỏ qua Mail Huge Bat Hoodie Bunny & Tích hợp Auto Daycare lên GUI
-- Tác giả: kizhub • Auto Combine Huge • VyHub Logic • Tối ưu CPU 80 Acc
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.Kizhub_HG) == "table" and type(genv.Kizhub_HG.Stop) == "function" then
    pcall(genv.Kizhub_HG.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN KIZHUB =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,
    TargetFPS = 5,
    LogoAssetId = "rbxassetid://10709791437",

    AutoClaimFreeGifts = true,

    First7ZonesHatchTimes = 5,
    HatchDelay = 1.0,

    Watchdog = {
        Enabled = false,
        MaxIdleHatchMinutes = 30,
    },
    
    AutoTap = {
        Enabled = true,
        TapDelay = 0.25,
    },

    AutoTreatUpgrades = true,
    UpgradeCooldown = 180,

    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 60,

    AutoDaycare = true,
    AutoMailHuge = true,
    MailRetryInterval = 1800, -- Nếu gửi không được: đúng 30 phút sau mới thử lại, chống spam 100%

    AfkPulseInterval = 180,

    Webhook = {
        Enabled = true,
        EventsUrl = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
        StatusUrl = "https://discord.com/api/webhooks/1372817821293219860/0RlqBFpPwUX-TjWsrcpLhDDEY8EKsz_6gbywjKK2J361TIg2YfwvbVE-ZxDcymNjxB44",
        StatusInterval = 1800,
    },

    AutoBuffs = {
        Toys = true,
        Fruits = true,
        Potions = true,
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

-- ================= TỐI ƯU HÓA ENGINE & CPU (CHO 80 ACC) =================
pcall(function()
    if type(setfpscap) == "function" then setfpscap(CFG.TargetFPS or 5) end
    if settings and settings().Rendering then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
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
end)

-- Hàm quét và dọn sạch rác đồ họa/mô hình thừa (KHÔNG DÙNG DescendantAdded để chống Crash Tab 24/24)
local function purgeHeavyVisuals()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    end)
    pcall(function()
        local things = workspace:FindFirstChild("__THINGS")
        if things then
            local pets = things:FindFirstChild("Pets")
            if pets then
                for _, p in ipairs(pets:GetChildren()) do pcall(function() p:Destroy() end) end
            end
            local dmg = things:FindFirstChild("DamageNumbers")
            if dmg then
                for _, d in ipairs(dmg:GetChildren()) do pcall(function() d:Destroy() end) end
            end
            local orbs = things:FindFirstChild("Orbs")
            if orbs then
                for _, o in ipairs(orbs:GetChildren()) do pcall(function() o:Destroy() end) end
            end
        end
        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, deb in ipairs(debris:GetChildren()) do pcall(function() deb:Destroy() end) end
        end
    end)
end
pcall(purgeHeavyVisuals)

pcall(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local anim = hum and hum:FindFirstChildOfClass("Animator")
    if anim then
        for _, t in ipairs(anim:GetPlayingAnimationTracks()) do t:Stop(0) end
    end
end)

pcall(function()
    if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
        RunService:Set3dRenderingEnabled(false)
    end
end)

-- Thu gom rác bộ nhớ (Full Garbage Collection) định kỳ mỗi 60s - Chống rò rỉ RAM cho 80 acc treo 24/24
task.spawn(function()
    while true do
        task.wait(60)
        pcall(purgeHeavyVisuals)
        pcall(function()
            collectgarbage("collect")
        end)
    end
end)

-- ================= NẠP CLIENT MODULES =================
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
    HGForge           = req("Library.Client.HalloweenGamesCmds.Forge", true),
    MachineCmds       = req("Library.Client.MachineCmds"),
    TabController     = req("Library.Client.TabController", true),
    Directory         = req("Library.Directory"),
    Items             = req("Library.Items"),
    FFlags            = req("Library.Client.FFlags", true),
    DaycareCmds       = req("Library.Client.DaycareCmds", true),
}

-- ================= BẢNG HẰNG SỐ & KHU VỰC =================
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
        { Key = "CoinFinder",     Id = "HalloweenGamesCoinFinder",     Aliases = { "HalloweenGamesCoinFinder" }, Name = "Coin Finder" },
        { Key = "EggLuck",        Id = "HalloweenGamesEggLuck",        Aliases = { "HalloweenGamesEggLuck" }, Name = "More Egg Luck" },
        { Key = "HugeLuck",       Id = "HalloweenGamesHugeLuck",       Aliases = { "HalloweenGamesHugeLuck" }, Name = "Huge Luck" },
        { Key = "Golden",         Id = "HalloweenGamesGolden",         Aliases = { "HalloweenGamesGolden" }, Name = "More Gold" },
        { Key = "Rainbow",        Id = "HalloweenGamesRainbow",        Aliases = { "HalloweenGamesRainbow" }, Name = "More Rainbow" },
        { Key = "Shiny",          Id = "HalloweenGamesShiny",          Aliases = { "HalloweenGamesShiny" }, Name = "Ooo Shiny" },
        { Key = "ForgeSaver",     Id = "HalloweenGamesForgeSaver",     Aliases = { "HalloweenGamesForgeSaver", "HalloweenGamesPetSavings" }, Name = "Forge Saver" },
        { Key = "TreatFinder",    Id = "HalloweenGamesTreatFinder",    Aliases = { "HalloweenGamesTreatFinder", "HalloweenGamesTrickFinder", "HalloweenGamesBetterVariants" }, Name = "Treat Finder" },
    },
    OBJECTIVE_ORDER = {
        ["Combine First"] = { "ForgeSaver", "TreatFinder", "HugeLuck", "EggLuck", "CoinFinder", "Golden", "Rainbow", "Shiny" },
    }
}

local state = {
    alive = true,
    excursion = nil,
    isRejoining = false,
    zoneHatchCounts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 },
    totalEggsHatched = 0,
    combineStatus = "Rảnh",
    mailStatus = "Rảnh",
    daycareStatus = "Rảnh",
    lastSuccessfulHatch = os.clock(),
    nextHatchAttemptAt = 0,
    nextUnlockTryAt = 0,
    nextTreatUpgradeAt = 0,
    nextCombineAt = 0,
    nextDaycareCheckAt = 0,
    nextToyAt = 0,
    nextFruitAt = 0,
    nextPotionAt = 0,
    nextClaimGiftsAt = 0,
    currentZoneNumber = 1,
    sessionStartCoins = nil,
    lastStatusCoins = nil,
    lastStatusTreats = nil,
    lastStatusHatched = nil,
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

-- Chuẩn hóa đọc tiền: Quét CurrencyCmds -> s.Currency -> s.Inventory.Currency
local function currency(id)
    if isfn(G.CurrencyCmds, "Get") then
        local v = gval(G.CurrencyCmds.Get, id)
        if type(v) == "number" then return v end
    end
    local s = getSave()
    if type(s) == "table" then
        if type(s.Currency) == "table" and type(s.Currency[id]) == "number" then
            return s.Currency[id]
        end
        local cur = s.Inventory and s.Inventory.Currency
        if type(cur) == "table" then
            for _, v in pairs(cur) do
                if type(v) == "table" and v.id == id then
                    return tonumber(v._am) or 0
                end
            end
        end
    end
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
    
    local targetUrl = customUrl or wb.EventsUrl
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

-- ================= BỘ THEO DÕI NỔ HUGE (HUGE WATCHER) =================
local knownHugeUids = {}
local isHugeCacheInitialized = false

local function checkNewHugeHatched()
    local s = getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    if not isHugeCacheInitialized then
        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                if isHuge then knownHugeUids[uid] = true end
            end
        end
        isHugeCacheInitialized = true
        return
    end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
            if isHuge and not knownHugeUids[uid] then
                knownHugeUids[uid] = true
                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                sendWebhook(
                    "💥 [NỔ HUGE PET THÀNH CÔNG] 💥",
                    string.format("Người chơi: **%s**\nPet nhận được: **%s**\nUID: `%s`", LocalPlayer.Name, pName, tostring(uid)),
                    0xFFD700,
                    CFG.Webhook.EventsUrl
                )
            end
        end
    end
end

-- ================= HÀM TỰ ĐỘNG REJOIN =================
local function forceRejoin(reason)
    if state.isRejoining then return end
    state.isRejoining = true

    sendWebhook("⚠️ [WATCHDOG REJOIN]", string.format("**%s** bị kẹt: %s. Đang tiến hành Rejoin lại server!", LocalPlayer.Name, reason), 0xFF3333, CFG.Webhook.EventsUrl)

    task.wait(2)
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\n[WATCHDOG]: Tự động Rejoin...")
            task.wait(0.5)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    task.wait(999)
end

-- ================= HỆ THỐNG ANTI-AFK GOD MODE & CHỐNG KICK 15' =================
local function installGodModeAntiAfk()
    -- 1. Chặn triệt để BigGames gọi TeleportService từ Client để Server Hop sau 15 phút (__namecall & hookfunction)
    pcall(function()
        if type(hookmetamethod) == "function" then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if (method == "Teleport" or method == "TeleportToPlaceInstance" or method == "teleport" or method == "TeleportToSpawnByName") and typeof(self) == "Instance" and self:IsA("TeleportService") then
                    if not (state and state.isRejoining) then
                        warn("[Anti-AFK Block]: Đã chặn BigGames tự động Hop Server (__namecall)!")
                        return
                    end
                end
                return oldNamecall(self, ...)
            end)
        end
        if type(hookfunction) == "function" then
            local oldTeleport
            oldTeleport = hookfunction(TeleportService.Teleport, function(self, ...)
                if not (state and state.isRejoining) then
                    warn("[Anti-AFK Block]: Đã chặn BigGames tự động Hop Server!")
                    return
                end
                return oldTeleport(self, ...)
            end)

            local oldTeleportToPlaceInstance
            oldTeleportToPlaceInstance = hookfunction(TeleportService.TeleportToPlaceInstance, function(self, ...)
                if not (state and state.isRejoining) then
                    warn("[Anti-AFK Block]: Đã chặn BigGames tự động Hop Server (Instance)!")
                    return
                end
                return oldTeleportToPlaceInstance(self, ...)
            end)
        end
    end)

    -- 2. Vô hiệu hóa Idled Connection của Roblox (Chống kick 20')
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)

    table.insert(connections, LocalPlayer.Idled:Connect(function()
        if not (state and state.alive) then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
            task.wait(0.05)
            VirtualUser:Button2Up(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
        end)
    end))

    -- 3. Chu kỳ nhịp Anti-AFK God Mode chuẩn (180s = 3 phút theo đúng code gốc của dj)
    task.spawn(function()
        local interval = CFG.AfkPulseInterval or 180
        while (state and state.alive) do
            task.wait(interval)
            if not (state and state.alive) then break end

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
                netFire("Idle Tracking: Stop Timer")
            end)
        end
    end)
end
pcall(installGodModeAntiAfk)


-- ================= BỎ QUA ANIMATION MỞ TRỨNG & BUFF SPEED =================
local function installNoHatchAnimation()
    task.spawn(function()
        while (state and state.alive) do
            local ok, hooked = pcall(function()
                local eggCmds = RS.Library.Client:FindFirstChild("EggCmds")
                if not eggCmds or type(getsenv) ~= "function" then return false end
                local env = getsenv(eggCmds)
                if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                    env.PlayEggAnimation = function() return end
                    return true
                end
                return false
            end)

            if ok and hooked == true then break end
            task.wait(1.0)
        end
    end)
end
pcall(installNoHatchAnimation)

pcall(function()
    if type(hookfunction) == "function" and isfn(G.PlayerPet, "CalculateSpeedMultiplier") then
        local orig
        orig = hookfunction(G.PlayerPet.CalculateSpeedMultiplier, function(...)
            if (state and state.alive) then return math.huge end
            return orig(...)
        end)
    end
end)

-- ================= GUI KIZCARD & BLACK SCREEN MODE =================
local uiRefs = {}
pcall(function()
    local parentGui = (type(gethui) == "function" and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui
    local oldGui = parentGui:FindFirstChild("Kizhub_BlackScreen") or parentGui:FindFirstChild("Kizhub_WhiteScreen")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kizhub_BlackScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parentGui

    -- Background Đen hoàn toàn thay thế White Screen
    local BlackBackground = Instance.new("Frame", ScreenGui)
    BlackBackground.Name = "BlackBackground"
    BlackBackground.Size = UDim2.new(1, 0, 1, 0)
    BlackBackground.Position = UDim2.new(0, 0, 0, 0)
    BlackBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BlackBackground.BorderSizePixel = 0
    BlackBackground.ZIndex = 0

    local KizCard = Instance.new("Frame")
    KizCard.Name = "KizCard"
    KizCard.AnchorPoint = Vector2.new(1, 0)
    KizCard.Position = UDim2.new(1, -20, 0, 20)
    KizCard.Size = UDim2.new(0, 420, 0, 365)
    KizCard.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    KizCard.BackgroundTransparency = 0.05
    KizCard.BorderSizePixel = 0
    KizCard.ClipsDescendants = true
    KizCard.Active = true
    KizCard.Draggable = true
    KizCard.ZIndex = 2
    KizCard.Parent = ScreenGui

    Instance.new("UICorner", KizCard).CornerRadius = UDim.new(0, 14)
    local CardStroke = Instance.new("UIStroke", KizCard)
    CardStroke.Color = Color3.fromRGB(255, 140, 0)
    CardStroke.Thickness = 1.8

    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Size = UDim2.new(1, 0, 0, 95)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.ZIndex = 2

    local CrownLogo = Instance.new("ImageLabel", HeaderFrame)
    CrownLogo.Name = "CrownLogo"
    CrownLogo.Size = UDim2.new(0, 56, 0, 56)
    CrownLogo.Position = UDim2.new(0, 18, 0, 10)
    CrownLogo.BackgroundTransparency = 1
    CrownLogo.Image = CFG.LogoAssetId
    CrownLogo.ScaleType = Enum.ScaleType.Fit
    CrownLogo.ZIndex = 2

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
    BrandText.ZIndex = 2

    local TitleInfo = Instance.new("TextLabel", HeaderFrame)
    TitleInfo.Text = "PS99 HALLOWEEN KAITUN"
    TitleInfo.Font = Enum.Font.GothamBold
    TitleInfo.TextSize = 15
    TitleInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleInfo.TextXAlignment = Enum.TextXAlignment.Left
    TitleInfo.BackgroundTransparency = 1
    TitleInfo.Position = UDim2.new(0, 90, 0, 20)
    TitleInfo.Size = UDim2.new(1, -90, 0, 20)
    TitleInfo.ZIndex = 2

    local SubInfo = Instance.new("TextLabel", HeaderFrame)
    SubInfo.Text = "Auto Farm • Auto Combine Huge • Daycare • Upgrades"
    SubInfo.Font = Enum.Font.Gotham
    SubInfo.TextSize = 11
    SubInfo.TextColor3 = Color3.fromRGB(160, 160, 175)
    SubInfo.TextXAlignment = Enum.TextXAlignment.Left
    SubInfo.BackgroundTransparency = 1
    SubInfo.Position = UDim2.new(0, 90, 0, 42)
    SubInfo.Size = UDim2.new(1, -90, 0, 16)
    SubInfo.ZIndex = 2

    local SepLine = Instance.new("Frame", KizCard)
    SepLine.Size = UDim2.new(1, -36, 0, 1)
    SepLine.Position = UDim2.new(0, 18, 0, 92)
    SepLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SepLine.BorderSizePixel = 0
    SepLine.ZIndex = 2

    local InfoContainer = Instance.new("Frame", KizCard)
    InfoContainer.Size = UDim2.new(1, -36, 1, -102)
    InfoContainer.Position = UDim2.new(0, 18, 0, 100)
    InfoContainer.BackgroundTransparency = 1
    InfoContainer.ZIndex = 2

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
        lbl.ZIndex = 2

        local val = Instance.new("TextLabel", InfoContainer)
        val.Text = defaultVal
        val.Font = Enum.Font.GothamBold
        val.TextSize = 12
        val.TextColor3 = highlightColor or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(0, 135, 0, yPos)
        val.Size = UDim2.new(1, -135, 0, 18)
        val.ZIndex = 2
        return val
    end

    uiRefs.UptimeLabel  = createRow("Thời Gian Chạy:", "00:00:00 (0.0 phút)", 0, Color3.fromRGB(0, 255, 140))
    uiRefs.ZoneLabel    = createRow("Zone Hiện Tại:", "Đang tải...", 20)
    uiRefs.CombineLabel = createRow("Ghép Huge Bunny:", "Rảnh", 40, Color3.fromRGB(255, 215, 0))
    uiRefs.MailLabel    = createRow("Auto Mailbox:", "Rảnh", 60, Color3.fromRGB(0, 200, 255))
    uiRefs.DaycareLabel = createRow("Auto Daycare:", "Đang tải...", 80, Color3.fromRGB(180, 130, 255))
    uiRefs.CoinsLabel   = createRow("Candy Coins:", "0", 100)
    uiRefs.TreatsLabel  = createRow("Treats / Trứng Nở:", "0 / 0", 120)

    local UpgTitle = Instance.new("TextLabel", InfoContainer)
    UpgTitle.Text = "Tiến Trình Treat Upgrades (VyHub Logic):"
    UpgTitle.Font = Enum.Font.GothamBold
    UpgTitle.TextSize = 12
    UpgTitle.TextColor3 = Color3.fromRGB(255, 140, 0)
    UpgTitle.TextXAlignment = Enum.TextXAlignment.Left
    UpgTitle.BackgroundTransparency = 1
    UpgTitle.Position = UDim2.new(0, 0, 0, 142)
    UpgTitle.Size = UDim2.new(1, 0, 0, 18)
    UpgTitle.ZIndex = 2

    uiRefs.UpgradesLabel = Instance.new("TextLabel", InfoContainer)
    uiRefs.UpgradesLabel.Text = "Đang nạp dữ liệu nâng cấp..."
    uiRefs.UpgradesLabel.Font = Enum.Font.Code
    uiRefs.UpgradesLabel.TextSize = 10
    uiRefs.UpgradesLabel.TextColor3 = Color3.fromRGB(180, 235, 200)
    uiRefs.UpgradesLabel.TextXAlignment = Enum.TextXAlignment.Left
    uiRefs.UpgradesLabel.TextYAlignment = Enum.TextYAlignment.Top
    uiRefs.UpgradesLabel.TextWrapped = true
    uiRefs.UpgradesLabel.BackgroundTransparency = 1
    uiRefs.UpgradesLabel.Position = UDim2.new(0, 0, 0, 162)
    uiRefs.UpgradesLabel.Size = UDim2.new(1, 0, 0, 85)
    uiRefs.UpgradesLabel.ZIndex = 2
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
    while (state and state.alive) and os.clock() - t0 < 15 do
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

-- ================= HATCH TRỨNG TỰ ĐỘNG =================
local function findCustomEggById(eggId)
    if isfn(G.CustomEggs, "All") then
        local all = gval(G.CustomEggs.All)
        if type(all) == "table" then
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
        end
    end

    local things = workspace:FindFirstChild("__THINGS")
    local customEggsFolder = things and things:FindFirstChild("CustomEggs")
    if customEggsFolder then
        for _, eggModel in ipairs(customEggsFolder:GetChildren()) do
            if eggModel:IsA("Model") and (eggModel.Name:find(eggId) or eggModel:GetAttribute("EggId") == eggId) then
                local realUid = eggModel:GetAttribute("UID") or eggModel.Name
                return {
                    uid = realUid,
                    id = eggId,
                    dir = G.Eggs and G.Eggs[eggId] or nil,
                    pos = eggModel:GetPivot().Position,
                    maxCount = 99
                }
            end
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
    local now = os.clock()
    if now < (state.nextHatchAttemptAt or 0) then return false, 0 end

    -- Kiểm tra số dư coin trước khi gửi Remote! Tránh spam 75 request/phút khi hết tiền gây văng server
    local curBal = currency(K.CURRENCY) or 0
    if curBal <= 0 then
        state.nextHatchAttemptAt = now + 3.0 -- Nghỉ 3s chờ cày thêm quặng
        return false, 0
    end

    local maxAmount = getAccountMaxHatch(egg)
    local target = egg.uid or egg.id
    if not target then return false, 0 end

    local ok, res = netInvoke("CustomEggs_Hatch", target, maxAmount)
    if ok and res == true then
        state.totalEggsHatched = state.totalEggsHatched + maxAmount
        state.lastSuccessfulHatch = os.clock()
        return true, maxAmount
    else
        -- Nếu mở bulk thất bại: thử hatch 1 quả
        if maxAmount > 1 then
            local ok1, res1 = netInvoke("CustomEggs_Hatch", target, 1)
            if ok1 and res1 == true then
                state.totalEggsHatched = state.totalEggsHatched + 1
                state.lastSuccessfulHatch = os.clock()
                return true, 1
            end
        end
        -- Thất bại do hết coin hoặc server cooldown -> giãn nhịp 3.5 giây, TUYỆT ĐỐI KHÔNG spam invoke
        state.nextHatchAttemptAt = now + 3.5
        return false, 0
    end
end

-- ================= FARM BREAKABLES & HÚT ORBS (CPU OPTIMIZED) =================
local breakablesCache = {}
local lastBreakableScan = 0

local function zoneBreakables(zoneNumber)
    local now = os.clock()
    if breakablesCache[zoneNumber] and (now - lastBreakableScan < 1.2) then
        return breakablesCache[zoneNumber]
    end

    local list = {}
    local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if folder then
        local area = "Main_" .. tostring(zoneNumber)
        local altArea = "__Zone_" .. tostring(zoneNumber)
        local zoneCfg = K.ZONES[zoneNumber]
        local zPos = zoneCfg and zoneCfg.Pos
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local pid = m:GetAttribute("ParentID")
                local aid = m:GetAttribute("AreaID")
                local matchArea = (aid == area or aid == altArea or aid == tostring(zoneNumber))
                if (pid == K.INSTANCE_ID and matchArea) or (zPos and dist(m:GetPivot().Position, zPos) <= 60) then
                    local buid = m:GetAttribute("BreakableUID")
                    if buid ~= nil then table.insert(list, buid) end
                end
            end
        end
    end
    breakablesCache[zoneNumber] = list
    lastBreakableScan = now
    return list
end

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

    if changed or (now - lastFastSend > 2.2) then
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

-- ================= TREAT UPGRADES (CHUẨN HÓA CẤU TRÚC SAVE.GET) =================
local function upgradeDir(id)
    local ok, d = pcall(function() return type(G.EventUpgrades) == "table" and G.EventUpgrades[id] or nil end)
    return ok and type(d) == "table" and d or nil
end

local function upgradeTier(idOrUpgrade)
    local testIds = {}
    if type(idOrUpgrade) == "table" then
        if idOrUpgrade.Id then table.insert(testIds, idOrUpgrade.Id) end
        if type(idOrUpgrade.Aliases) == "table" then
            for _, a in ipairs(idOrUpgrade.Aliases) do table.insert(testIds, a) end
        end
    elseif type(idOrUpgrade) == "string" then
        table.insert(testIds, idOrUpgrade)
        if idOrUpgrade == "HalloweenGamesPetSavings" then
            table.insert(testIds, "HalloweenGamesForgeSaver")
        elseif idOrUpgrade == "HalloweenGamesForgeSaver" then
            table.insert(testIds, "HalloweenGamesPetSavings")
        end
    end

    local s = getSave()
    for _, id in ipairs(testIds) do
        -- 1. Gọi EventUpgradeCmds.GetTier với Identity Game (2)
        if isfn(G.EventUpgradeCmds, "GetTier") then
            local t = gval(G.EventUpgradeCmds.GetTier, id)
            if type(t) == "number" and t > 0 then return t end
        end
        -- 2. Đọc từ s.EventUpgrades trong Save.Get()
        if type(s) == "table" and type(s.EventUpgrades) == "table" then
            local val = s.EventUpgrades[id]
            if type(val) == "number" and val > 0 then return val end
            if type(val) == "table" then
                local num = val.Tier or val.tier or val._tier or val._am or val[1]
                if type(num) == "number" and num > 0 then return num end
            end
        end
    end

    local firstId = testIds[1]
    if firstId then
        if isfn(G.EventUpgradeCmds, "GetTier") then
            local t = gval(G.EventUpgradeCmds.GetTier, firstId)
            if type(t) == "number" then return t end
        end
        if type(s) == "table" and type(s.EventUpgrades) == "table" and type(s.EventUpgrades[firstId]) == "number" then
            return s.EventUpgrades[firstId]
        end
    end
    return 0
end

local function upgradeInfo(u)
    local d = upgradeDir(u.Id)
    local tier = tonumber(upgradeTier(u)) or 0
    local maxTier = d and type(d.TierPowers) == "table" and #d.TierPowers or 5
    local cost = nil
    if d and tier < maxTier then
        if isfn(G.HGUpgrades, "Cost") then
            local okC, item = gcall(G.HGUpgrades.Cost, d, tier + 1)
            if okC and item then
                local okA, amt = pcall(function() return item:GetAmount() end)
                if okA and type(amt) == "number" then cost = amt end
            end
        end
        if not cost and type(d.TierCosts) == "table" and d.TierCosts[tier + 1] then
            local targetCost = d.TierCosts[tier + 1]
            if type(targetCost) == "number" then
                cost = targetCost
            elseif type(targetCost) == "table" and type(targetCost.GetAmount) == "function" then
                local okA, amt = pcall(targetCost.GetAmount, targetCost)
                if okA and type(amt) == "number" then cost = amt end
            end
        end
    end
    local onSale = true
    if isfn(G.HGUpgrades, "OnSale") then onSale = gval(G.HGUpgrades.OnSale, u.Id) ~= false end
    local power = d and type(d.TierPowers) == "table" and d.TierPowers[tier] or nil
    return { tier = tier, max = maxTier, cost = cost, power = power, disabled = (d == nil) or d.Disabled == true or not onSale, dir = d }
end

local function upgradeMachineModel()
    if isfn(G.MachineCmds, "GetModels") then
        local ok, models = gcall(G.MachineCmds.GetModels, K.UPGRADE_MACHINE)
        if ok and type(models) == "table" then
            local m = instanceModel()
            for _, mod in pairs(models) do
                if typeof(mod) == "Instance" and (not m or mod:IsDescendantOf(m)) then return mod end
            end
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
            repeat task.wait(0.2) until nearMachine() or os.clock() - t0 > 3 or not (state and state.alive)
        end

        local bought = 0
        while (state and state.alive) and cand and bought < 12 do
            local ok, res = netInvoke("EventUpgrades: Purchase", cand.u.Id)
            if not (ok and res == true) then break end
            bought = bought + 1
            state.lastSuccessfulHatch = os.clock()
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

    if before and (state and state.alive) then teleportTo(before) end
    state.excursion = nil
    state.nextTreatUpgradeAt = os.clock() + (CFG.UpgradeCooldown or 180)
end

-- ================= AUTO COMBINE HUGE BAT HOODIE BUNNY (100% HOÀN CHỈNH) =================
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

local function combineRecipes()
    local dir = combineDir()
    local out = {}
    if not dir or type(dir.Recipes) ~= "table" then return out, dir end
    for i, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result and type(r.Ingredients) == "table" and r.Hidden ~= true then
            local name = tostring(gval(function() return r.Result:GetId() end) or ("Recipe " .. i))
            local open = r.EnabledFFlag == nil or flagValue(r.EnabledFFlag) ~= false
            local ready, missing = true, {}
            for _, ing in ipairs(r.Ingredients) do
                local need, have = ingredientNeed(dir, ing), ingredientHave(dir, ing)
                if have < need then
                    ready = false
                    local ingName = tostring(gval(function() return ing.Item:GetId() end) or "?"):gsub("Halloween ", ""):gsub("Masquerade ", "")
                    missing[#missing + 1] = string.format("%s %d/%d", ingName, have, need)
                end
            end
            out[#out + 1] = {
                index = i,
                name = name,
                open = open,
                ready = ready,
                missing = table.concat(missing, ", "),
                duration = tonumber(flagValue(r.DurationFFlag)) or tonumber(r.Duration)
            }
        end
    end
    return out, dir
end

local function combineMachineStand()
    local m = instanceModel()
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    local mach = machines and machines:FindFirstChild(K.COMBINE_MACHINE)
    if not mach then
        local things = workspace:FindFirstChild("__THINGS")
        local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = cont and cont:FindFirstChild("Active")
        local inst = act and act:FindFirstChild(K.INSTANCE_ID)
        local iinter = inst and inst:FindFirstChild("INTERACT")
        local imachines = iinter and iinter:FindFirstChild("Machines")
        mach = imachines and imachines:FindFirstChild(K.COMBINE_MACHINE)
    end
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0) end
    return mach:GetPivot().Position + Vector3.new(0, 3, 6)
end

local function activeQueues()
    -- 1. Ưu tiên gọi Remote mạng HalloweenCraftingMachine_GetQueue
    local okQ, queue = netInvoke("HalloweenCraftingMachine_GetQueue")
    if okQ and type(queue) == "table" then
        return queue
    end

    -- 2. Đọc từ s.HalloweenCraftingQueue trong Save.Get()
    local s = getSave()
    if type(s) == "table" then
        if type(s.HalloweenCraftingQueue) == "table" then
            return s.HalloweenCraftingQueue
        end
        local iv = s.InstanceVars and s.InstanceVars[K.INSTANCE_ID]
        local cm = iv and iv.HalloweenCraftingMachines
        local m = cm and cm[K.COMBINE_ID]
        if type(m) == "table" and type(m.Queue) == "table" then
            return m.Queue
        end
    end
    return {}
end

local function checkAndRunCombine()
    if not CFG.AutoCombine or not inEvent() or state.excursion ~= nil then return end
    local now = os.clock()
    if now < state.nextCombineAt then return end

    local recipes, dir = combineRecipes()
    if not dir or #recipes == 0 then return end

    local q = activeQueues()
    local readyClaims, queued = {}, {}
    for k, item in pairs(q) do
        if type(item) == "table" then
            local uid = item.UID or (type(k) == "string" and k) or nil
            local recIdx = item.RecipeIndex or (item.Recipe and item.Recipe.Index)
            local rem = tonumber(item.Remaining) or tonumber(item.TimeLeft) or 0
            if recIdx then
                if rem <= 0 and uid then
                    table.insert(readyClaims, { UID = uid, RecipeIndex = recIdx })
                else
                    queued[recIdx] = item
                end
            end
        end
    end

    local targetRecipeName = CFG.TargetCombineRecipe or "Huge Bat Hoodie Bunny"
    local starts = {}
    local waiting = {}

    for i = #recipes, 1, -1 do
        local r = recipes[i]
        local isTarget = (r.name == targetRecipeName) or (targetRecipeName == "" or targetRecipeName == nil)
        if isTarget and r.open and not queued[r.index] then
            if r.ready then
                table.insert(starts, r)
            else
                table.insert(waiting, r.missing)
            end
        elseif isTarget and queued[r.index] and (tonumber(queued[r.index].Remaining) or 0) > 0 then
            local rem = tonumber(queued[r.index].Remaining) or 0
            state.combineStatus = string.format("Đang ghép (%ds)", math.floor(rem))
        end
    end

    if #readyClaims == 0 and #starts == 0 then
        if #waiting > 0 then
            state.combineStatus = "Thiếu: " .. waiting[1]
        elseif state.combineStatus == "Rảnh" or state.combineStatus == "Đang Claim Huge" then
            state.combineStatus = "Chờ nguyên liệu"
        end
        state.nextCombineAt = now + (CFG.CombineCooldown or 60)
        return
    end

    state.excursion = "combine"
    local savedPos = playerPos()

    pcall(function()
        local stand = combineMachineStand()
        if stand then
            teleportTo(stand)
            task.wait(0.8)
        end

        -- 1. Claim các mẻ đã ghép xong
        for _, claim in ipairs(readyClaims) do
            local okC, resC = netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            if okC and resC then
                local recName = targetRecipeName
                for _, r in ipairs(recipes) do if r.index == claim.RecipeIndex then recName = r.name end end
                state.combineStatus = "Đã nhận " .. recName
                -- Webhook chỉ báo khi nhận Huge và tên acc nhận Huge (không kèm time)
                sendWebhook(
                    "🎉 [NHẬN HUGE GHÉP THÀNH CÔNG] 🎉",
                    string.format("👑 **Tài khoản:** `%s`\n🎉 **Pet nhận được:** **%s**", LocalPlayer.Name, recName),
                    0xFFD700,
                    CFG.Webhook.EventsUrl
                )
            end
            task.wait(0.6)
        end

        -- 2. Tự động bắt đầu mẻ ghép mới khi đủ nguyên liệu (KHÔNG GỬI WEBHOOK BẮT ĐẦU)
        for _, r in ipairs(starts) do
            local again = combineRecipes()
            local fresh
            for _, x in ipairs(again) do if x.index == r.index then fresh = x end end
            if fresh and fresh.ready then
                local okS, resS = netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index)
                if okS and resS then
                    local durMin = r.duration and math.floor(r.duration / 60) or 0
                    state.combineStatus = string.format("Đang ghép %s (%dp)", r.name:gsub("Halloween ", ""):gsub("Huge ", ""), durMin)
                else
                    state.combineStatus = "Ghép lỗi: " .. tostring(resS)
                end
            end
            task.wait(0.6)
        end
    end)

    if savedPos and (state and state.alive) then teleportTo(savedPos) end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (CFG.CombineCooldown or 60)
end

-- ================= AUTO DAYCARE MODULE (CLAIM & SMART ENROLL) =================
local function daycareStandPos()
    if isfn(G.MachineCmds, "GetModels") then
        local ok, models = gcall(G.MachineCmds.GetModels, "Daycare")
        if ok and type(models) == "table" then
            for _, m in pairs(models) do
                if typeof(m) == "Instance" then
                    local pad = m:FindFirstChild("Pad", true)
                    if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0) end
                    return m:GetPivot().Position + Vector3.new(0, 3, 6)
                end
            end
        end
    end
    local map = workspace:FindFirstChild("Map")
    local beach = map and map:FindFirstChild("20 | Beach")
    local inter = beach and beach:FindFirstChild("INTERACT")
    local machs = inter and inter:FindFirstChild("Machines")
    local dc = machs and (machs:FindFirstChild("DaycareMachine") or machs:FindFirstChild("Daycare"))
    if dc then
        local pad = dc:FindFirstChild("Pad", true)
        if pad and pad:IsA("BasePart") then return pad.Position + Vector3.new(0, 3, 0) end
        return dc:GetPivot().Position + Vector3.new(0, 3, 6)
    end
    return Vector3.new(130.26, 16.56, 509.21)
end

local function getDaycareInfo()
    local s = getSave()
    local active = s and s.DaycareActive
    local maxSlots = 10
    if isfn(G.DaycareCmds, "GetMaxSlots") then
        local okM, m = gcall(G.DaycareCmds.GetMaxSlots)
        if okM and type(m) == "number" then maxSlots = m end
    end

    local enrolled = 0
    if isfn(G.DaycareCmds, "GetUsedSlots") then
        local okU, u = gcall(G.DaycareCmds.GetUsedSlots)
        if okU and type(u) == "number" then enrolled = u end
    end
    if enrolled == 0 and type(active) == "table" then
        for _ in pairs(active) do enrolled = enrolled + 1 end
    end

    local readyToClaim = false
    local minRemaining = math.huge
    local now = os.time()

    if type(active) == "table" then
        for uid, v in pairs(active) do
            if type(v) == "table" then
                local remain = nil
                if isfn(G.DaycareCmds, "ComputeRemainingTime") then
                    local okR, r = gcall(G.DaycareCmds.ComputeRemainingTime, v)
                    if okR and type(r) == "number" then remain = r end
                end

                if not remain then
                    local readyAt = tonumber(v.ReadyTime or v.ReadyAt or v.ClaimTime or v.EndTime)
                    if readyAt then
                        remain = readyAt - now
                    elseif tonumber(v.CreationTime) and tonumber(v.CreationAge) then
                        remain = math.max(0, 21600 - (now - v.CreationTime))
                    end
                end

                if remain then
                    if remain <= 0 then
                        readyToClaim = true
                        minRemaining = 0
                    else
                        if remain < minRemaining then minRemaining = remain end
                    end
                end
            end
        end
    end

    if minRemaining == math.huge then minRemaining = 0 end
    return {
        enrolled = enrolled,
        maxSlots = math.max(10, maxSlots),
        readyToClaim = readyToClaim,
        minRemaining = minRemaining
    }
end

local function getPetPower(p)
    if type(p) ~= "table" or type(p.id) ~= "string" then return 0 end
    if isfn(G.PetCmds, "GetPower") then
        local ok, pow = gcall(G.PetCmds.GetPower, p)
        if ok and type(pow) == "number" then return pow end
    end
    if isfn(G.PetCmds, "GetStrength") then
        local ok, str = gcall(G.PetCmds.GetStrength, p)
        if ok and type(str) == "number" then return str end
    end
    local basePower = 1
    local dir = (G.Directory and G.Directory.Pets and G.Directory.Pets[p.id]) or (G.Pets and G.Pets[p.id])
    if type(dir) == "table" then
        basePower = tonumber(dir.strength or dir.power or dir.damage or dir.BaseDamage) or 1
    end
    local mult = 1
    if p.pt == 1 then mult = mult * 1.5 -- Golden
    elseif p.pt == 2 then mult = mult * 2.5 -- Rainbow
    end
    if p.sh == true then mult = mult * 2.0 -- Shiny
    end
    return basePower * mult
end

local function checkAndRunDaycare()
    if not CFG.AutoDaycare or state.excursion ~= nil then return end

    local now = os.clock()
    if now < state.nextDaycareCheckAt then return end
    state.nextDaycareCheckAt = now + 40 -- Kiểm tra mỗi 40s

    local dcInfo = getDaycareInfo()
    local slotsOpen = dcInfo.maxSlots - dcInfo.enrolled

    local needClaim = dcInfo.readyToClaim or (dcInfo.enrolled > 0 and dcInfo.minRemaining <= 0)
    local needEnroll = slotsOpen > 0

    if not (needClaim or needEnroll) then
        if dcInfo.enrolled > 0 then
            local remMins = math.ceil(dcInfo.minRemaining / 60)
            local hrs = math.floor(remMins / 60)
            local mins = remMins % 60
            if hrs > 0 then
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dh %dp)", dcInfo.enrolled, dcInfo.maxSlots, hrs, mins)
            else
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dp)", dcInfo.enrolled, dcInfo.maxSlots, mins)
            end
        end
        return
    end

    -- Quét danh sách pet thường: Chọn Stat pet MẠNH NHẤT chưa khóa và chưa trang bị
    local s = getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    local candidates = {}
    if needEnroll and type(pets) == "table" then
        -- Thu thập tập hợp UID các pet đang được trang bị để không bao giờ gửi nhầm
        local equippedSet = {}
        if isfn(G.PetCmds, "GetEquipped") then
            local okEq, eqList = gcall(G.PetCmds.GetEquipped)
            if okEq and type(eqList) == "table" then
                for _, eqUid in pairs(eqList) do
                    if type(eqUid) == "string" then equippedSet[eqUid] = true end
                end
            end
        end
        if type(s and s.EquippedPets) == "table" then
            for _, eqUid in pairs(s.EquippedPets) do
                if type(eqUid) == "string" then equippedSet[eqUid] = true end
            end
        end
        for _, activePet in ipairs(petEuids()) do
            if activePet ~= nil then equippedSet[tostring(activePet)] = true end
        end

        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") ~= nil)
                local isTitanic = (p.id:find("Titanic ") ~= nil)
                local isExclusive = (p.id:find("Exclusive") ~= nil)
                local isLocked = (p.lk == true or p._lk == true or p.Locked == true)
                local isEquipped = (p._eq == true or p.eq == true or equippedSet[uid] == true)

                if not (isHuge or isTitanic or isExclusive or isLocked or isEquipped) then
                    table.insert(candidates, {
                        uid = uid,
                        id = p.id,
                        power = getPetPower(p)
                    })
                end
            end
        end

        -- Sắp xếp giảm dần theo sức mạnh (Stat pet mạnh nhất luôn được chọn đầu tiên)
        if #candidates > 1 then
            table.sort(candidates, function(a, b)
                return (a.power or 0) > (b.power or 0)
            end)
        end
    end

    if not needClaim and #candidates == 0 then
        if dcInfo.enrolled == 0 then
            state.daycareStatus = "Hết pet thường để gửi"
        end
        return
    end

    -- THỰC HIỆN EXCURSION TỚI BỤC DAYCARE (BEACH AREA 20)
    local savedPos = playerPos()
    local stand = daycareStandPos()
    if not stand then return end

    state.excursion = "Daycare"
    state.daycareStatus = "Đang tới bục Daycare..."
    teleportTo(stand)
    task.wait(0.5)

    pcall(function()
        netFire("Machines: Mark Approached", "Daycare")
    end)
    task.wait(0.2)

    -- 1. Claim quà Daycare nếu đã ủ xong
    if needClaim then
        state.daycareStatus = "Đang nhận quà Daycare..."

        -- Snapshot túi đồ TRƯỚC KHI CLAIM để đối chiếu chính xác
        local sBefore = getSave()
        local diaBefore = 0
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Currency) == "table" then
            for _, v in pairs(sBefore.Inventory.Currency) do
                if type(v) == "table" and v.id == "Diamonds" then diaBefore = tonumber(v._am) or 0 end
            end
        end

        local petsBefore = {}
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Pet) == "table" then
            for uid, p in pairs(sBefore.Inventory.Pet) do
                if type(p) == "table" then petsBefore[uid] = true end
            end
        end

        local eggsBefore = {}
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Egg) == "table" then
            for uid, e in pairs(sBefore.Inventory.Egg) do
                if type(e) == "table" and e.id then
                    eggsBefore[e.id] = (eggsBefore[e.id] or 0) + (tonumber(e._am) or 1)
                end
            end
        end

        local okC = false
        local claimData = nil
        if isfn(G.DaycareCmds, "Claim") then
            local ok, res = gcall(G.DaycareCmds.Claim)
            if ok and res then
                okC = true
                claimData = res
            end
        end
        if not okC then
            local ok, res = netInvoke("Daycare: Claim")
            if ok and res then
                okC = true
                claimData = res
            end
        end

        if okC then
            task.wait(0.6)
            dcInfo = getDaycareInfo()
            slotsOpen = dcInfo.maxSlots - dcInfo.enrolled

            -- Đối chiếu túi đồ SAU KHI CLAIM
            local sAfter = getSave()
            local diaAfter = 0
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Currency) == "table" then
                for _, v in pairs(sAfter.Inventory.Currency) do
                    if type(v) == "table" and v.id == "Diamonds" then diaAfter = tonumber(v._am) or 0 end
                end
            end
            local diaGained = math.max(0, diaAfter - diaBefore)

            local hugeFound = {}
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Pet) == "table" then
                for uid, p in pairs(sAfter.Inventory.Pet) do
                    if type(p) == "table" and not petsBefore[uid] then
                        local isHuge = (p.IsHuge and p:IsHuge()) or (type(p.id) == "string" and p.id:find("Huge "))
                        if isHuge then
                            local hName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. tostring(p.id)
                            table.insert(hugeFound, hName)
                        end
                    end
                end
            end

            local eggsFound = {}
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Egg) == "table" then
                for uid, e in pairs(sAfter.Inventory.Egg) do
                    if type(e) == "table" and e.id then
                        local oldAmt = eggsBefore[e.id] or 0
                        local newAmt = tonumber(e._am) or 1
                        if newAmt > oldAmt then
                            table.insert(eggsFound, string.format("%dx %s", newAmt - oldAmt, tostring(e.id)))
                        end
                    end
                end
            end

            -- Quét thêm trong claimData bảng trả về trực tiếp từ game (nếu có)
            if type(claimData) == "table" then
                for _, item in pairs(claimData) do
                    if type(item) == "table" then
                        local id = tostring(item.id or item.Id or "")
                        if id:find("Huge ") and #hugeFound == 0 then
                            table.insert(hugeFound, id)
                        elseif (id:find("Egg") or item.Class == "Egg") and #eggsFound == 0 then
                            table.insert(eggsFound, string.format("%dx %s", tonumber(item._am or item.Amount) or 1, id))
                        end
                    end
                end
            end

            -- GỬI WEBHOOK KHI NỔ MEEBO IN A SPACESHIP HOẶC TRÚNG GARGANTUAN MACHINE HIPPOMELON EGG (THEO YÊU CẦU CỦA DJ)
            pcall(function()
                local targetHugeFound = {}
                for _, h in ipairs(hugeFound) do
                    local strH = tostring(h)
                    if strH:find("Meebo in a Spaceship") or strH:find("Meebo") or strH:find("Huge ") then
                        table.insert(targetHugeFound, strH)
                    end
                end

                local targetEggFound = {}
                for _, e in ipairs(eggsFound) do
                    local strE = tostring(e)
                    if strE:find("Gargantuan Machine Hippomelon Egg") or strE:find("Hippomelon") or strE:find("Gargantuan") then
                        table.insert(targetEggFound, strE)
                    end
                end

                if #targetHugeFound > 0 then
                    -- NỔ HUGE DAYCARE: EMBED VÀNG HOÀNG KIM (SIÊU GIÁ TRỊ)
                    sendWebhook(
                        "🚨🚨 [NỔ HUGE DAYCARE: MEEBO IN A SPACESHIP] 🚨🚨",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "🎉 **PET NỔ:** **%s**\n" ..
                            "💎 **Gems thu hoạch:** `+%s Gems`",
                            LocalPlayer.Name,
                            table.concat(targetHugeFound, ", "),
                            shorten(diaGained)
                        ),
                        0xFFD700,
                        CFG.Webhook.EventsUrl
                    )
                elseif #targetEggFound > 0 then
                    -- TRÚNG TRỨNG GARGANTUAN MACHINE HIPPOMELON EGG: EMBED XANH LỤC BẢO
                    sendWebhook(
                        "🥚🔥 [TRÚNG TRỨNG GARGANTUAN HIPPOMELON TỪ DAYCARE] 🔥🥚",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "📦 **TRỨNG ĐỈNH:** **%s**\n" ..
                            "💎 **Gems thu hoạch:** `+%s Gems`",
                            LocalPlayer.Name,
                            table.concat(targetEggFound, ", "),
                            shorten(diaGained)
                        ),
                        0x00E676,
                        CFG.Webhook.EventsUrl
                    )
                end
                -- CÁC PHẦN THƯỞNG THƯỜNG / TRỨNG THƯỜNG: HOÀN TOÀN KHÔNG BẮN WEBHOOK
            end)
        end
    end

    -- 2. Gửi pet vào slot trống
    if slotsOpen > 0 and #candidates > 0 then
        local toEnrollDict = {}
        local count = math.min(slotsOpen, #candidates)
        for i = 1, count do
            toEnrollDict[candidates[i].uid] = 1
        end

        state.daycareStatus = string.format("Đang gửi %d pet...", count)
        local okE = false
        local errReason = nil

        local ok, res = netInvoke("Daycare: Enroll", toEnrollDict)
        if ok and res == true then
            okE = true
        else
            errReason = tostring(res)
            if isfn(G.DaycareCmds, "Enroll") then
                local ok2, res2 = gcall(G.DaycareCmds.Enroll, toEnrollDict)
                if ok2 and res2 then okE = true else errReason = tostring(res2) end
            end
        end

        if okE then
            state.daycareStatus = string.format("Đã gửi %d pet vào Daycare", count)
            task.wait(0.5)
            dcInfo = getDaycareInfo()
        else
            state.daycareStatus = "Gửi thất bại (" .. tostring(errReason or "Từ chối") .. ")"
        end
    end

    -- 3. Teleport trở lại vị trí farm cũ ngay lập tức
    if savedPos and (state and state.alive) then
        teleportTo(savedPos)
    end
    state.excursion = nil

    -- 4. Cập nhật nhãn trạng thái hiển thị trên KizCard
    if dcInfo.enrolled > 0 then
        if dcInfo.minRemaining > 0 then
            local remMins = math.ceil(dcInfo.minRemaining / 60)
            local hrs = math.floor(remMins / 60)
            local mins = remMins % 60
            if hrs > 0 then
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dh %dp)", dcInfo.enrolled, dcInfo.maxSlots, hrs, mins)
            else
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dp)", dcInfo.enrolled, dcInfo.maxSlots, mins)
            end
        else
            state.daycareStatus = string.format("Đang gửi %d/%d (Đã xong, chờ nhận)", dcInfo.enrolled, dcInfo.maxSlots)
        end
    elseif slotsOpen > 0 and (state.daycareStatus == "Rảnh" or state.daycareStatus == "Đang tải...") then
        state.daycareStatus = string.format("Trống %d/%d slot", slotsOpen, dcInfo.maxSlots)
    end
end

-- ================= AUTO CLAIM FREE GIFTS (12 MỐC - TIẾT KIỆM REQUEST) =================
local function checkAndClaimFreeGifts()
    if not CFG.AutoClaimFreeGifts then return end
    local now = os.clock()
    if now < state.nextClaimGiftsAt then return end
    state.nextClaimGiftsAt = now + 180 -- Nhận quà mỗi 3 phút, chống spam remote

    pcall(function()
        for i = 1, 12 do
            netInvoke("Redeem Free Gift", i)
            task.wait(0.2)
        end
    end)
end

-- ================= AUTO BUFFS (FRUITS • POTIONS • TOYS) =================
local function runDelayedBuffs()
    local bCfg = CFG.AutoBuffs
    if not bCfg then return end
    local now = os.clock()

    -- 1. Fruits: Tối đa 20 quả/lần theo tên quả
    if bCfg.Fruits and now >= state.nextFruitAt then
        state.nextFruitAt = now + 60
        pcall(function()
            local s = getSave()
            local fruits = s and s.Inventory and s.Inventory.Fruit
            if type(fruits) == "table" then
                for _, item in pairs(fruits) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local amt = tonumber(item._am) or 0
                        if amt > 0 then
                            local eatAmt = math.clamp(amt, 1, 20)
                            netFire("Fruits: Consume", item.id, eatAmt)
                            task.wait(0.08)
                        end
                    end
                end
            end
        end)
    end

    -- 2. Potions: Tự cắn Potions (damage, coins, luck, speed, treasure)
    if bCfg.Potions and now >= state.nextPotionAt then
        state.nextPotionAt = now + 90
        pcall(function()
            local s = getSave()
            local potions = s and s.Inventory and s.Inventory.Potion
            if type(potions) == "table" then
                local targetTypes = { "damage", "coins", "luck", "lucky", "speed", "treasure" }
                for _, item in pairs(potions) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local lowerId = string.lower(item.id)
                        local matched = false
                        for _, kw in ipairs(targetTypes) do
                            if lowerId:find(kw) then matched = true; break end
                        end
                        if matched and (tonumber(item._am) or 0) > 0 then
                            netFire("Potions: Consume", item.id)
                            task.wait(0.08)
                        end
                    end
                end
            end
        end)
    end

    -- 3. Toys: Dùng Toys truyền đúng UID từ Inventory.Misc
    if bCfg.Toys and now >= state.nextToyAt then
        state.nextToyAt = now + 180
        pcall(function()
            local s = getSave()
            local misc = s and s.Inventory and s.Inventory.Misc
            if type(misc) == "table" then
                for uid, item in pairs(misc) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local toyUid = item._uid or uid
                        if item.id == "Toy Ball" then
                            netInvoke("ToyBall_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id == "Toy Bone" then
                            netInvoke("ToyBone_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id == "Squeaky Toy" then
                            netInvoke("SqueakyToy_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id:lower():find("toy") then
                            netInvoke("Consumables_Consume", toyUid)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end)
    end
end

-- ================= UPTIME TRACKER =================
task.spawn(function()
    while (state and state.alive) do
        pcall(function()
            if uiRefs.UptimeLabel then
                uiRefs.UptimeLabel.Text = formatUptime()
            end
        end)
        task.wait(1)
    end
end)

-- ================= CẬP NHẬT GIAO DIỆN KIZCARD (BỌC AN TOÀN TỪNG DÒNG) =================
local function updateKizhubGui()
    if not uiRefs.ZoneLabel then return end

    local upStr = formatUptime()
    local zData = K.ZONES[state.currentZoneNumber]
    
    local rawCoins = currency(K.CURRENCY) or 0
    if state.sessionStartCoins == nil then state.sessionStartCoins = rawCoins end
    local deltaCoinsSession = math.max(0, rawCoins - state.sessionStartCoins)
    local coinsDisplay = (deltaCoinsSession > 0) and string.format("%s (+%s)", shorten(rawCoins), shorten(deltaCoinsSession)) or shorten(rawCoins)

    -- Cập nhật thông số cơ bản (Bọc riêng từng dòng để tránh gãy luồng)
    pcall(function() uiRefs.ZoneLabel.Text = string.format("Zone %d/8 (%s)", state.currentZoneNumber or 1, zData and zData.Name or "") end)
    pcall(function() uiRefs.CombineLabel.Text = state.combineStatus end)
    pcall(function() uiRefs.MailLabel.Text = state.mailStatus end)
    pcall(function() uiRefs.DaycareLabel.Text = state.daycareStatus end)
    pcall(function() uiRefs.CoinsLabel.Text = coinsDisplay end)
    pcall(function() uiRefs.TreatsLabel.Text = string.format("%s Treats | %s quả", shorten(currency(K.TREATS)), shorten(state.totalEggsHatched)) end)

    -- Cập nhật danh sách 8 Upgrades (Khớp hoàn toàn với Save.Get().EventUpgrades)
    pcall(function()
        local upgLines = {}
        for _, u in ipairs(K.UPGRADES) do
            local tier = 0
            pcall(function() tier = tonumber(upgradeTier(u)) or 0 end)
            local tag = (u.Key == "ForgeSaver" or u.Key == "TreatFinder") and "[P2]" or "[P1]"
            local tierStr = (tier >= 5) and "MAX" or string.format("%d/5", tier)
            table.insert(upgLines, string.format("%s %s: %s", tag, u.Name, tierStr))
        end

        local formatted = ""
        for i = 1, #upgLines, 2 do
            local col1 = upgLines[i] or ""
            local col2 = upgLines[i+1] or ""
            formatted = formatted .. string.format("%-18s | %s\n", col1, col2)
        end
        if uiRefs.UpgradesLabel then
            uiRefs.UpgradesLabel.Text = formatted
        end
    end)

    pcall(function()
        local titleFn = setwindowtitle or set_window_title
        if titleFn then
            titleFn(string.format("[%s] %s | Z%d | %s Xu | Daycare: %s", LocalPlayer.Name, upStr, state.currentZoneNumber or 1, shorten(currency(K.CURRENCY) or 0), state.daycareStatus))
        end
    end)
end

-- Cập nhật GUI ngay lập tức khi load xong
task.spawn(function()
    task.wait(0.5)
    pcall(updateKizhubGui)
end)

-- ================= VÒNG LẶP WATCHDOG (CHỐNG REJOIN OAN 7 ZONE ĐẦU) =================
task.spawn(function()
    while (state and state.alive) do
        task.wait(15)
        pcall(function()
            local wCfg = CFG.Watchdog
            if not (wCfg and wCfg.Enabled) then return end
            if not inEvent() or state.excursion ~= nil then return end
            if state.isRejoining then return end

            -- Nếu nhân vật còn sống và đang farm breakables hoặc còn coin -> Tuyệt đối không kick oan!
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local currentZone = state.currentZoneNumber or 1
                if #zoneBreakables(currentZone) > 0 or (currency(K.CURRENCY) or 0) > 0 then
                    state.lastSuccessfulHatch = os.clock()
                    return
                end
            end

            local maxIdleSec = (wCfg.MaxIdleHatchMinutes or 30) * 60
            if (os.clock() - state.lastSuccessfulHatch) >= maxIdleSec then
                forceRejoin(string.format("Kẹt cứng không hatch/farm được quá %d phút.", math.floor(maxIdleSec / 60)))
            end
        end)
    end
end)

-- ================= VÒNG LẶP AUTO TAP RANDOM (10Hz • CPU CACHED) =================
local function runAutoTapTick()
    local tCfg = CFG.AutoTap
    if not (tCfg and tCfg.Enabled) or not inEvent() or state.excursion ~= nil then return end

    local currentZone = state.currentZoneNumber or 1
    local targetUids = zoneBreakables(currentZone)
    if #targetUids > 0 then
        local randomTarget = targetUids[math.random(1, #targetUids)]
        netUnreliable("Breakables_PlayerDealDamage", randomTarget)
    end
end

task.spawn(function()
    pcall(function() netInvoke("AutoTapper_Toggle", true) end)
    local delayTime = (CFG.AutoTap and CFG.AutoTap.TapDelay) or 0.1
    while (state and state.alive) do
        pcall(runAutoTapTick)
        task.wait(delayTime)
    end
end)

-- ================= VÒNG LẶP CHÍNH =================
task.spawn(function()
    while (state and state.alive) do
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
                            state.lastSuccessfulHatch = os.clock()
                        else
                            -- Thiếu coin hoặc hatch lỗi nhưng bãi còn breakables để farm -> không kick oan
                            if #zoneBreakables(currentZone) > 0 then
                                state.lastSuccessfulHatch = os.clock()
                            end
                        end
                    else
                        if #zoneBreakables(currentZone) > 0 then
                            state.lastSuccessfulHatch = os.clock()
                        end
                    end
                else
                    -- Ở 7 Zone đầu: Nếu đã đập đủ 5 trứng thì đứng cày tiền qua map -> cập nhật Watchdog
                    if #zoneBreakables(currentZone) > 0 or currency(K.CURRENCY) > 0 then
                        state.lastSuccessfulHatch = os.clock()
                    end
                end
            else
                -- Ở Zone 8: Mở trứng liên tục
                if eggInfo then
                    local okH, _ = hatchZoneEgg(eggInfo)
                    if okH then
                        state.lastSuccessfulHatch = os.clock()
                    else
                        if #zoneBreakables(8) > 0 or (currency(K.CURRENCY) or 0) > 0 then
                            state.lastSuccessfulHatch = os.clock()
                        end
                    end
                else
                    if #zoneBreakables(8) > 0 or (currency(K.CURRENCY) or 0) > 0 then
                        state.lastSuccessfulHatch = os.clock()
                    end
                end
            end
        end)
        task.wait(math.max(0.8, CFG.HatchDelay or 1.0))
    end
end)

-- Vòng lặp nhặt Orbs (0.8s - CPU Optimized)
task.spawn(function()
    while (state and state.alive) do
        if CFG.Enabled and inEvent() then pcall(collectOrbsTick) end
        task.wait(0.8)
    end
end)

-- Vòng lặp phụ: Upgrades, Ghép Huge, Daycare, Quà & Buffs (6s)
task.spawn(function()
    while (state and state.alive) do
        pcall(function()
            if CFG.Enabled and inEvent() then
                checkNewHugeHatched()
                checkAndRunTreatUpgrades()
                checkAndRunCombine()
                checkAndRunDaycare()
                checkAndClaimFreeGifts()
                runDelayedBuffs()
            end
        end)
        task.wait(6)
    end
end)

-- Vòng lặp cập nhật GUI (4s/lần)
task.spawn(function()
    while (state and state.alive) do
        pcall(updateKizhubGui)
        task.wait(4)
    end
end)

-- ================= VÒNG LẶP GỬI STATUS WEBHOOK (ANTI-SPAM 80 ACC) =================
task.spawn(function()
    while (state and state.alive) do
        local interval = (CFG.Webhook and CFG.Webhook.StatusInterval) or 1800
        task.wait(interval)
        
        pcall(function()
            local wb = CFG.Webhook
            if wb and wb.Enabled and wb.StatusUrl and wb.StatusUrl ~= "" then
                task.wait(math.random(1, 120))
                
                local upStr = formatUptime()
                local rawCoins = currency(K.CURRENCY) or 0
                local rawTreats = currency(K.TREATS) or 0
                local rawHatched = state.totalEggsHatched or 0

                -- Tính mức tăng sau mỗi 30 phút (ví dụ: 1M (+1M)) theo đúng yêu cầu của dj
                local lastCoins = state.lastStatusCoins or rawCoins
                local lastTreats = state.lastStatusTreats or rawTreats
                local lastHatched = state.lastStatusHatched or rawHatched

                local deltaCoins = math.max(0, rawCoins - lastCoins)
                local deltaTreats = math.max(0, rawTreats - lastTreats)
                local deltaHatched = math.max(0, rawHatched - lastHatched)

                state.lastStatusCoins = rawCoins
                state.lastStatusTreats = rawTreats
                state.lastStatusHatched = rawHatched

                local coinsDisplay = string.format("%s (+%s)", shorten(rawCoins), shorten(deltaCoins))
                local treatsDisplay = string.format("%s (+%s)", shorten(rawTreats), shorten(deltaTreats))
                local hatchedDisplay = string.format("%s (+%s)", shorten(rawHatched), shorten(deltaHatched))

                local currentZ = state.currentZoneNumber or 1
                local zoneInfo = K.ZONES[currentZ]
                local zoneTitle = string.format("Zone %d/8 (%s)", currentZ, zoneInfo and zoneInfo.Name or "Unknown")

                local statusDesc = string.format(
                    "⏱️ **Thời gian chạy:** `%s`\n📍 **Khu vực:** `%s`\n🍬 **Candy Coins:** `%s`\n🎃 **Treats:** `%s`\n🥚 **Trứng đã nở:** `%s` quả\n🛠️ **Ghép Huge:** `%s`\n📬 **Hòm thư:** `%s`\n🏡 **Daycare:** `%s`",
                    upStr, zoneTitle, coinsDisplay, treatsDisplay, hatchedDisplay, state.combineStatus or "Rảnh", state.mailStatus or "Rảnh", state.daycareStatus or "Rảnh"
                )

                sendWebhook("🟢 [STATUS 30' REPORT] " .. LocalPlayer.Name, statusDesc, 0x00E676, wb.StatusUrl)
            end
        end)
    end
end)

-- ================= AUTO-MAIL HUGE MODULE (BỎ QUA BAT HOODIE BUNNY) =================
task.spawn(function()
    local MailConfig = {
        Recipient       = "Kizmoii_VNG",
        EventsWebhook   = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
        StartupWaitSec  = 30,
        MailCooldownSec = 61,
        RetryIntervalSec = (CFG.MailRetryInterval or 1800), -- ĐÚNG 30 PHÚT: Nếu gửi không được thì 30 phút sau thử lại
        IdleCheckSec    = 20,
    }

    local FailedUIDBlacklist = {}
    local nextMailAttemptAt = 0

    local function getDiamonds()
        local s = getSave()
        local cur = s and s.Inventory and s.Inventory.Currency
        if type(cur) == "table" then
            for _, v in pairs(cur) do
                if type(v) == "table" and v.id == "Diamonds" then return tonumber(v._am) or 0 end
            end
        end
        return 0
    end

    local function findSendableHuge()
        local s = getSave()
        local pets = s and s.Inventory and s.Inventory.Pet
        if type(pets) ~= "table" then return nil end

        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                if isHuge then
                    -- Bỏ qua Huge Bat Hoodie Bunny (chưa hỗ trợ gửi thư tại event này)
                    if p.id:find("Bat Hoodie Bunny") then
                        continue
                    end

                    if FailedUIDBlacklist[uid] then continue end
                    if p.sb == true or p._sb == true or p.Soulbound == true or p.Untradable == true then
                        FailedUIDBlacklist[uid] = true
                        continue
                    end

                    local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                    return { UID = uid, Id = p.id, Name = pName, IsLocked = (p.lk == true or p._lk == true) }
                end
            end
        end
        return nil
    end

    local gTime = workspace.DistributedGameTime
    if gTime < MailConfig.StartupWaitSec then task.wait(math.ceil(MailConfig.StartupWaitSec - gTime)) end

    while (state and state.alive) do
        local sendSuccess = false
        pcall(function()
            if not inEvent() or state.excursion ~= nil then task.wait(2) return end

            local now = os.clock()

            -- 1. Nếu đang trong thời gian chờ thử lại (30 phút giữa các lần gửi không được, 0 request spam)
            if now < nextMailAttemptAt then
                local remSec = math.max(0, math.ceil(nextMailAttemptAt - now))
                local remMins = math.floor(remSec / 60)
                local remSecs = remSec % 60
                state.mailStatus = string.format("Chờ gửi lại sau 30p (%02d:%02d)", remMins, remSecs)
                task.wait(1)
                return
            end

            -- 2. Tìm Huge cần gửi (Đã tự động loại trừ Bat Hoodie Bunny)
            local huge = findSendableHuge()
            if not huge then
                state.mailStatus = "Hết Huge (Bỏ qua Bunny)"
                task.wait(MailConfig.IdleCheckSec)
                return
            end

            -- 3. Bắt đầu gửi Huge
            state.excursion = "mail"
            state.mailStatus = "Đang gửi " .. huge.Name

            netFire("Machines: Mark Approached", "Mailbox")
            task.wait(0.3)

            if huge.IsLocked then
                netInvoke("Locking_SetLocked", huge.UID, false)
                netFire("Pets_Unlock", huge.UID)
                task.wait(0.4)
            end

            local diaBefore = getDiamonds()
            local okSend, resSend = netInvoke("Mailbox: Send", MailConfig.Recipient, "Gift #" .. tostring(math.random(100, 999)), "Pet", huge.UID, 1)
            local diaAfter = getDiamonds()
            local actualCost = math.max(0, diaBefore - diaAfter)

            state.excursion = nil -- Luôn trả quyền điều khiển về luồng chính ngay lập tức

            if okSend and resSend == true then
                sendSuccess = true
                state.mailStatus = string.format("Đã gửi %s (Cước: %s)", huge.Name, shorten(actualCost))
                sendWebhook("📦 [AUTO-MAIL HUGE THÀNH CÔNG] 📦", string.format("Người gửi: **%s**\nNgười nhận: **%s**\nPet gửi: **%s**\nPhí cước: **%d Gems**", LocalPlayer.Name, MailConfig.Recipient, huge.Name, actualCost), 0x00E676, MailConfig.EventsWebhook)
            else
                local errStr = string.lower(tostring(resSend))
                if errStr:find("soulbound") or errStr:find("untradable") or errStr:find("cannot be traded") or errStr:find("not tradable") then
                    FailedUIDBlacklist[huge.UID] = true
                    state.mailStatus = "Pet không thể trade (Bỏ qua)"
                    task.wait(3)
                else
                    -- BẤT KỲ LỖI NÀO (CƯỚC CAO, THIẾU GEMS, HÒM ĐẦY, SERVER TỪ CHỐI):
                    -- NGHỈ ĐÚNG 30 PHÚT RỒI MỚI THỬ LẠI! HOÀN TOÀN KHÔNG SPAM REQUEST!
                    nextMailAttemptAt = os.clock() + MailConfig.RetryIntervalSec
                    state.mailStatus = string.format("Gửi chưa được | Thử lại sau 30p")
                    task.wait(1)
                end
            end
        end)
        if sendSuccess then task.wait(MailConfig.MailCooldownSec) end
        task.wait(1)
    end
end)

-- ================= CLEANUP INTERFACE =================
genv.Kizhub_HG = {
    Stop = function()
        state.alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
        local parentGui = (type(gethui) == "function" and gethui()) or CoreGui
        local g = parentGui:FindFirstChild("Kizhub_BlackScreen") or parentGui:FindFirstChild("Kizhub_WhiteScreen")
        if g then g:Destroy() end
    end
}
