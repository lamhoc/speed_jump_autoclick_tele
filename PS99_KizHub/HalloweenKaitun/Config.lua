-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/Config.lua
-- Cấu hình toàn diện cho sự kiện Halloween Event Pet Simulator 99
-- Chứa: Tùy chọn hoạt động, Webhook URLs, Hằng số Zones & Upgrades K
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G

local Config = {
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
        TapDelay = 0.5,
    },

    AutoTreatUpgrades = true,
    UpgradeCooldown = 180,

    AutoCombine = true,
    TargetCombineRecipe = "Combine Egg",
    CombineCooldown = 30,

    -- [BẬT / TẮT AUTO DAYCARE]: true = Bật, false = Tắt hoàn toàn
    AutoDaycare = false,

    AutoMailHuge = true,
    MailRetryInterval = 1800, -- Nếu gửi không được: đúng 30 phút sau mới thử lại, chống spam

    -- [CHỐNG KICK 15']: Nhịp 35s giữ liên lạc liên tục với server
    AfkPulseInterval = 35,

    Webhook = {
        Enabled = true,
        EventsUrl = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
        StatusUrl = "https://discord.com/api/webhooks/1372817821293219860/0RlqBFpPwUX-TjWsrcpLhDDEfOqW9jN6x7iTszrDk02Y82F2g8fS_523F43g",
        StatusInterval = 1800, -- 30 phút gửi 1 lần
    },
}

-- Hằng số khu vực & Nâng cấp sự kiện Halloween
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

-- Trộn cấu hình đã có từ genv nếu tồn tại
if type(genv.KaitunConfig) == "table" then
    for k, v in pairs(genv.KaitunConfig) do
        Config[k] = v
    end
else
    genv.KaitunConfig = Config
end

-- Tự động đảm bảo công thức ghép là Combine Egg
if Config.TargetCombineRecipe == "Huge Bat Hoodie Bunny" or Config.TargetCombineRecipe == nil or Config.TargetCombineRecipe == "" then
    Config.TargetCombineRecipe = "Combine Egg"
    if type(genv.KaitunConfig) == "table" then
        genv.KaitunConfig.TargetCombineRecipe = "Combine Egg"
    end
end

return {
    Config = Config,
    K = K,
}
