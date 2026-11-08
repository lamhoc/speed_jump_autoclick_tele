-- =========================================================================
-- PS99 KAITUN: HALLOWEEN GAMES (KIZHUB EDITION - FULLSCREEN DASHBOARD)
-- Tối ưu: Màn trắng GPU 0%, Fullscreen GUI cố định, Logo Vương miện,
-- Auto Mail liên tục theo mốc MinAmount, Auto Claim Mail, Discord Webhook.
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.Kizhub_HG) == "table" and type(genv.Kizhub_HG.Stop) == "function" then
    pcall(genv.Kizhub_HG.Stop)
    task.wait(0.3)
end

-- ================= CẤU HÌNH KAITUN KIZHUB =================
genv.KaitunConfig = genv.KaitunConfig or {
    Enabled = true,

    -- 1. Logo Vương Miện & Giao Diện Full Màn Hình
    LogoAssetId = "rbxassetid://10709791437", -- Asset ID icon Vương miện

    -- 2. Chu trình mở trứng 8 Zone (Tọa độ Pos chuẩn 100% halloween.lua)
    First7ZonesHatchTimes = 5,           -- 7 khu đầu mỗi khu mở đúng 5 lần (Max trứng/lần)
    HatchDelay = 0.5,                    -- Tốc độ mở trứng

    -- 3. Nâng cấp sự kiện (Treat Upgrades)
    AutoTreatUpgrades = true,
    UpgradeCooldown = 600,               -- Đúng 10 phút (600 giây) kiểm tra ghé máy 1 lần

    -- 4. Ghép Huge Bat Hoodie Bunny
    AutoCombine = true,
    TargetCombineRecipe = "Huge Bat Hoodie Bunny",
    CombineCooldown = 40,

    -- 5. Auto Mail (Đủ đồ là gửi ngay lập tức) & Auto Claim Mail
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

    -- 6. Discord Webhook Thông Báo
    Webhook = {
        Enabled = true,                    -- Đổi thành true để bật thông báo Discord
        Url = "https://discord.com/api/webhooks/1444485821909569558/ONQp3ZOyvQevUptUSVbLQpkm5SZZDUOEUr0LTZGoYNPeh_NlMwTxeIS8kEre_u7qEvfC",                           -- ⚠️ DÁN LINK WEBHOOK CỦA BẠN VÀO ĐÂY
        NotifyOnHuge = true,
        NotifyOnMail = true,
    },

    -- 7. Auto Buffs (Chống Spam: Đúng thời gian hết hạn mới dùng lại)
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
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
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

-- ================= DỮ LIỆU TỌA ĐỘ VỊ TRÍ 8 ZONE (CHUẨN HALLOWEEN.LUA) =================
local K = {
    INSTANCE_ID     = "HalloweenGames",
    CURRENCY        = "HalloweenGamesCoins",
    TREATS          = "HalloweenGamesTreats",
    UPGRADE_MACHINE = "HalloweenGamesUpgradeMachine",
    COMBINE_ID      = "HalloweenGamesCombine",
    COMBINE_MACHINE = "HalloweenPetCraftingMachine",
    ZONES = {
        [1] = { Number = 1, Name = "Scarecrow Field",  Egg = "Straw Egg",       Pos = Vector3.new(-5315.60400390625, 16.19723892211914, -3939.5205078125) },
        [2] = { Number = 2, Name = "Statue Graveyard", Egg = "Marble Egg",      Pos = Vector3.new(-5496.83203125, 16.239492416381836, -3940
