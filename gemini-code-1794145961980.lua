-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (KIZHUB STABLE - GOD MODE ANTI-AFK)
-- Tối ưu: Anti-AFK Đa tầng (VIM + VirtualUser + Camera + Remote Bypass),
-- Full Fix Send Huge trực tiếp, 5 FPS, Uptime Tracker
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
    AutoTreatUpgrades = true,
    UpgradeCooldown = 600,
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 60,
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
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1444485821909569558/ONQp3ZOyvQevUptUSVbLQpkm5SZZDUOEUr0LTZGoYNPeh_NlMwTxeIS8kEre_u7qEvfC",
        NotifyOnHuge = true,
        NotifyOnMail = true,
        StatusUrl = "https://discord.com/api/webhooks/1372817821293219860/0RlqBFpPwUX-TjWsrcpLhDDEY8EKsz_6gbywjKK2J361TIg2YfwvbVE-ZxDcymNjxB44",
        StatusInterval = 600,
    },
    AutoBuffs = {
        Toys = true,
        Fruits = true,
        Potions = true,
        Flags = true,
        PreferredFlags = { "Coins Flag", "Fortune Flag", "Hasty Flag", "Magnet Flag" },
    },
}
local CFG = genv.KaitunConfig

-- ================= KHỞI TẠO SERVICES =================
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

-- ================= TỐI ƯU ENGINE =================
pcall(function() if type(setfpscap) == "function" then setfpscap(CFG.TargetFPS or 5) end end)
pcall(function()
    SoundService.RespectFilteringEnabled = true
    for _, s in ipairs(game:GetDescendants()) do if s:IsA("Sound") then s.Volume = 0 s:Stop() end end
end)
pcall(function()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.Technology = Enum.Technology.Compatibility
end)

-- ================= NẠP MODULES TỪ REPLICATEDSTORAGE =================
local ExodusLibrary = {}
pcall(function()
    local clientFolder = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client")
    if clientFolder then
        for _, v in ipairs(clientFolder:GetChildren()) do
            if v:IsA("ModuleScript") and not v:GetAttribute("NOLOAD") then
                local ok, mod = pcall(require, v)
                if ok and type(mod) == "table" then ExodusLibrary[v.Name] = mod end
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
        { Key = "CoinFinder", Id = "HalloweenGamesCoinFinder", Name = "Coin Finder" },
        { Key = "EggLuck", Id = "HalloweenGamesEggLuck", Name = "Egg Luck" },
        { Key = "HugeLuck", Id = "HalloweenGamesHugeLuck", Name = "Huge Luck" },
        { Key = "Golden", Id = "HalloweenGamesGolden", Name = "More Gold" },
        { Key = "Rainbow", Id = "HalloweenGamesRainbow", Name = "More Rainbow" },
        { Key = "Shiny", Id = "HalloweenGamesShiny", Name = "Ooo Shiny" },
        { Key = "PetSavings", Id = "HalloweenGamesPetSavings", Name = "Pet Savings" },
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
    nextClaimMailAt = 0,
    currentZoneNumber = 1,
}

local connections = {}

-- ================= TIỆN ÍCH MẠNG =================
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

local function playerPos()
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return r and r.Position or nil
end

local function dist(a, b)
    if not (a and b) then return math.huge end
    return (a - b).Magnitude
end

local function teleportTo(pos)
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not (c and r and pos) then return false end
    local cf = CFrame.new(pos + Vector3.new(0, 3.5, 0)) * (r.CFrame - r.CFrame.Position)
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end

local function sendWebhook(title, desc, color)
    local wb = CFG.Webhook
    if not (wb and wb.Enabled and wb.Url and wb.Url:find("^https://")) then return end
    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then return end
    task.spawn(function()
        pcall(reqFn, {
            Url = wb.Url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "kizhub",
                embeds = {{ title = title, description = desc, color = color or 0x00FF88 }}
            })
        })
    end)
end

-- ================= ANTI-AFK GOD MODE ĐA TẦNG =================
local function installGodModeAntiAfk()
    -- 1. Triệt tiêu sự kiện Idled gốc
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)

    -- 2. Ghi đè phương thức Idled bằng Click Ảo
    table.insert(connections, LocalPlayer.Idled:Connect(function()
        if not state.alive then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))

    -- 3. Chuỗi xung nhịp (Pulse) mỗi 3 phút/lần
    task.spawn(function()
        while state.alive do
            task.wait(180) -- 3 phút
            if not state.alive then break end
            
            print("🛡️ [ANTI-AFK]: Bắn tín hiệu chống Kick đa tầng...")

            -- Nhảy vật lý
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then 
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    hum.Jump = true 
                end
            end)

            -- Bấm phím ảo
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)

            -- Xoay nhẹ góc nhìn Camera để ép Roblox gửi Replication Packet
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.05), 0)
                    task.wait(0.1)
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-0.05), 0)
                end
            end)

            -- Diệt Idle Tracking của PS99 (Quét liên tục phòng khi respawn)
            pcall(function()
                local core = LocalPlayer.PlayerScripts:FindFirstChild("Scripts")
                core = core and core:FindFirstChild("Core")
                if core then
                    local idleTrack = core:FindFirstChild("Idle Tracking")
                    if idleTrack then idleTrack.Enabled = false end
                    local serverClose = core:FindFirstChild("Server Closing")
                    if serverClose then serverClose.Enabled = false end
                end
            end)
            
            -- Gửi Remote trực tiếp ép Server PS99 reset bộ đếm thời gian
            pcall(function()
                if isfn(G.Network, "Fire") then
                    gcall(G.Network.Fire, "Idle Tracking: Stop Timer")
                end
            end)
        end
    end)
    print("🛡️ [KIZHUB]: Đã cài đặt Anti-AFK God Mode 24/24")
end
pcall(installGodModeAntiAfk)

-- Tắt diễn hoạt nở trứng
pcall(function()
    if type(getsenv) ~= "function" then return end
    task.spawn(function()
        local ps = LocalPlayer:WaitForChild("PlayerScripts", 10)
        local eggScript = ps and ps:WaitForChild("Scripts", 10):WaitForChild("Game", 10):WaitForChild("Egg Opening Frontend", 10)
        if eggScript then
            local env = getsenv(eggScript)
            if env and type(env.PlayEggAnimation) == "function" then
                env.PlayEggAnimation = function(...) if not state.alive then return end end
            end
        end
    end)
end)

-- ================= QUẢN LÝ INSTANCE HALLOWEEN =================
local function inEvent()
    local id = isfn(G.Instancing, "GetInstanceID") and gval(G.Instancing.GetInstanceID)
    if id == K.INSTANCE_ID then return true end
    local p = playerPos()
    for _, z in ipairs(K.ZONES) do
        if p and dist(p, z.Pos) < 450 then return true end
    end
    return false
end

local function bestUnlockedZone()
    if isfn(G.InstanceZone, "GetMaximumOwnedZoneNumber") then
        local n = gval(G.InstanceZone.GetMaximumOwnedZoneNumber)
        if type(n) == "number" and n >= 1 then return math.clamp(n, 1, 8) end
    end
    return 1
end

-- ================= FARM BREAKABLES & ORBS =================
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
    return ok and out or {}
end

local lastFastSend, lastFastMap = 0, {}
local function farmZoneBreakables(zoneNumber)
    local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if not folder then return end
    
    local targetUids = {}
    local area = "Main_" .. tostring(zoneNumber)
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("ParentID") == K.INSTANCE_ID and m:GetAttribute("AreaID") == area then
            table.insert(targetUids, m:GetAttribute("BreakableUID"))
        end
    end
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
        local b = isfn(G.BreakableFrontend, "Get") and gval(G.BreakableFrontend.Get, uid)
        if type(b) == "table" then
            local hp = type(b.health) == "number" and b.health or 1
            if hp > 0 then
                local item = { uid = uid, health = hp, class = tostring(b.class or "Normal") }
                if item.class ~= "Normal" then table.insert(chests, item) else table.insert(infos, item) end
            end
        end
    end
    
    local ordered = (#chests > 0) and chests or infos
    if #ordered == 0 then return end
    table.sort(ordered, function(a, b) return a.health < b.health end)

    local map, changed = {}, false
    for i, euid in ipairs(pets) do
        local tUid = ordered[((i - 1) % #ordered) + 1].uid
        map[euid] = tUid
        if lastFastMap[euid] ~= tUid then changed = true end
    end

    if changed or (os.clock() - lastFastSend > 2.0) then
        lastFastSend = os.clock()
        lastFastMap = map
        netFire("Breakables_JoinPetBulk", map)
        netUnreliable("Breakables_PlayerDealDamage", ordered[1].uid)
    end
end

-- ================= LOGIC AUTO MAIL TÍCH HỢP AUTOMAIL.LUA =================
local function GenerateMailTitle()
    local adjs = {"Bold", "Quick", "Happy", "Sad", "Tiny", "Big", "Brave", "Clever", "Swift", "Calm"}
    local nouns = {"Lion", "Castle", "Book", "Phone", "Cloud", "Tiger", "Forest", "Sword", "Star"}
    return adjs[math.random(#adjs)] .. " " .. nouns[math.random(#nouns)]
end

local function FindNextMailItem(mCfg)
    local s = getSave()
    local inv = s and s.Inventory
    if not (inv and type(inv) == "table") then return nil end

    -- Ưu tiên 1: Quét Huge (IsHuge)
    if mCfg.SendAllHuges and type(inv.Pet) == "table" then
        for uid, p in pairs(inv.Pet) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                if isHuge then
                    -- Mở khóa cờ Auto-Lock
                    if p.lk or p._lk then
                        print(string.format("🔓 [MAIL]: Mở khóa pet %s...", p.id))
                        pcall(function()
                            netInvoke("Lock: SetLocked", "Pet", uid, false)
                            netInvoke("Locking_SetLocked", uid, false)
                        end)
                        task.wait(0.3)
                    end
                    local petName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                    return { Class = "Pet", UID = uid, Amount = 1, Name = petName }
                end
            end
        end
    end

    -- Ưu tiên 2: Consumables
    if type(inv.Consumable) == "table" and type(mCfg.Consumables) == "table" then
        for uid, cData in pairs(inv.Consumable) do
            if type(cData) == "table" and type(cData.id) == "string" and not (cData.lk or cData._lk) then
                local itemAmt = tonumber(cData._am) or 1
                local itemTier = tonumber(cData.tn) or 1
                local idLower = string.lower(cData.id)

                for _, rule in ipairs(mCfg.Consumables) do
                    local rIdLower = string.lower(tostring(rule.Id or ""))
                    if idLower:find(rIdLower) and itemTier == (tonumber(rule.Tier) or 1) then
                        if itemAmt >= (tonumber(rule.MinAmount) or 1) then
                            return { Class = "Consumable", UID = uid, Amount = itemAmt, Name = string.format("%s (Tier %d)", cData.id, itemTier) }
                        end
                        break
                    end
                end
            end
        end
    end
    return nil
end

task.spawn(function()
    local mCfg = CFG.Mail
    if not (mCfg and mCfg.Enabled) then return end
    print(string.format("🔵 [MAIL]: Chờ %ds khởi động hệ thống...", mCfg.StartupDelay or 40))
    task.wait(mCfg.StartupDelay or 40)

    while state.alive do
        pcall(function()
            if not mCfg.Enabled or mCfg.Recipient == "" or string.lower(mCfg.Recipient) == string.lower(LocalPlayer.Name) then return end

            if mCfg.AutoClaimMail and os.clock() > state.nextClaimMailAt then
                state.nextClaimMailAt = os.clock() + 30
                pcall(function() netInvoke("Mailbox: ClaimAll") end)
            end

            local dia = GetDiamonds(false)
            local minKeep = mCfg.MinDiamondsToKeep or 10000

            if dia >= minKeep then
                local item = FindNextMailItem(mCfg)
                if item then
                    print(string.format("🔵 [MAIL]: Đang gửi %s (x%d) -> @%s...", item.Name, item.Amount, mCfg.Recipient))
                    
                    local title = GenerateMailTitle()
                    
                    -- Thử 3 hàm Remote Fallback
                    local ok, res = pcall(function()
                        if isfn(G.Network, "Invoke") then return gval(G.Network.Invoke, "Mailbox: Send", mCfg.Recipient, title, item.Class, item.UID, item.Amount) end
                        if ExodusLibrary.Network and type(ExodusLibrary.Network.Invoke) == "function" then return ExodusLibrary.Network.Invoke("Mailbox: Send", mCfg.Recipient, title, item.Class, item.UID, item.Amount) end
                        local rf = RS:FindFirstChild("Network") and RS.Network:FindFirstChild("Mailbox: Send")
                        if rf and rf:IsA("RemoteFunction") then return rf:InvokeServer(mCfg.Recipient, title, item.Class, item.UID, item.Amount) end
                        return false
                    end)

                    if ok and res == true then
                        state.mailsSent = state.mailsSent + 1
                        print(string.format("🟢 [MAIL SUCCESS]: %s (x%d) đã được gửi!", item.Name, item.Amount))
                        sendWebhook("📦 GỬI MAIL THÀNH CÔNG!", string.format("Đã gửi **%s** (x%d) đến **%s**", item.Name, item.Amount, mCfg.Recipient), 0x00FF88)
                        task.wait(mCfg.MailCooldown or 60)
                    else
                        warn(string.format("🔴 [MAIL FAILED]: Máy chủ chặn gửi %s (Có thể do quá tải). Thử lại sau 15s...", item.Name))
                        task.wait(15)
                    end
                else
                    task.wait(12) -- Kho nghỉ khi không có item
                end
            else
                task.wait(30) -- Chờ cày thêm kim cương
            end
        end)
        task.wait(1)
    end
end)

-- ================= VÒNG LẶP CHÍNH =================
task.spawn(function()
    while state.alive do
        pcall(function()
            if not CFG.Enabled then return end
            
            -- Tự động chui vào event
            if not inEvent() then
                if isfn(G.Instancing, "Enter") then gcall(G.Instancing.Enter, K.INSTANCE_ID) end
                task.wait(2)
                return
            end

            -- Best Zone & Teleport
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

            -- Hatch Trứng (Không diễn hoạt)
            local function maxHatch(eId)
                if isfn(G.EggCmds, "GetMaxHatch") then
                    local n = gval(G.EggCmds.GetMaxHatch, G.Eggs and G.Eggs[eId])
                    if type(n) == "number" and n >= 1 then return math.floor(n) end
                end
                return 1
            end

            local eggName = zoneData and zoneData.Egg
            if eggName then
                local targetUid
                if isfn(G.CustomEggs, "All") then
                    local all = gval(G.CustomEggs.All)
                    for uid, e in pairs(all or {}) do if e._id == eggName then targetUid = e._uid or uid break end end
                end
                if targetUid then netInvoke("CustomEggs_Hatch", targetUid, maxHatch(eggName)) end
            end
        end)
        task.wait(math.max(0.8, CFG.HatchDelay or 1.0))
    end
end)

-- Vòng lặp báo cáo Status Uptime Webhook
task.spawn(function()
    while state.alive do
        local interval = (CFG.Webhook and CFG.Webhook.StatusInterval) or 600
        task.wait(interval)
        pcall(function()
            local wb = CFG.Webhook
            if wb and wb.Enabled and wb.StatusUrl and wb.StatusUrl ~= "" then
                local upStr = formatUptime()
                local statusDesc = string.format(
                    "⏱️ **Thời gian chạy:** `%s`\n📍 **Khu vực:** `Zone %d/8`\n🍬 **Candy Coins:** `%s`\n📦 **Mail:** Đã gửi `%d`",
                    upStr, state.currentZoneNumber, shorten(currency(K.CURRENCY)), state.mailsSent
                )
                sendWebhook("🟢 [STATUS] " .. LocalPlayer.Name, statusDesc, 0x00E676, nil, wb.StatusUrl)
            end
        end)
    end
end)

genv.Kizhub_HG = {
    Stop = function()
        state.alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(restoreFns) do pcall(fn) end
    end
}