-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/Config.lua
-- Cấu hình toàn diện cho AutoRank Kaitun World 1 (Rank 1 -> 11)
-- =========================================================================

local Config = {
    -- AutoRank & Kaitun A-Z
    AutoRankEnabled = true,
    TargetRank = 11,
    StayInWorld1 = true,
    AutoWorldTeleport = false, -- Khóa chặt ở World 1, cày đủ Rank 11 không qua World 2
    AutoClaimRewards = true,
    AutoFarm = true,
    AutoHatch = true,
    AutoTapEggs = true,
    AlwaysHatch = false,
    AutoCraftGoldRainbow = true,
    AutoUsePotions = true,
    AutoUpgradePotions = true,
    AutoUpgradeEnchants = true,
    AutoUseFruits = true,
    AutoUseFlags = true,
    AutoSpawnEvents = true,
    AutoBuyZones = true,
    AutoEquipBestPets = false, -- Game đã tự động equip, tắt để không can thiệp

    -- 5 Tính Năng Bổ Trợ Đặc Tả (Mới tích hợp)
    AutoTapBreakables = true,     -- [1. Auto Click]: Click phá bãi farm 10Hz song song cùng pet
    AutoTapDelay = 0.1,           -- Độ trễ nhịp tap (0.1s = 10Hz)
    MaxPetSpeed = true,           -- [2. Infinite Pet Speed]: Hook CalculateSpeedMultiplier math.huge di chuyển tức thì
    AutoCollectOrbs = true,       -- [3. Orb Collector]: Hút sạch hạt rơi và lootbag vật lý mỗi 0.35s
    OrbCollectInterval = 0.35,
    DisableEggAnimation = true,   -- [4. Skip Egg Animation]: Triệt tiêu toàn bộ cutscene ấp trứng
    AutoBuffs = {                 -- [5. Auto Buffs]: Tự động duy trì trạng thái buff kho đồ
        Enabled = true,
        Fruits = true,            -- Tự ăn hoa quả gom nhóm tối đa 20 quả/đợt
        FruitInterval = 60,
        Potions = true,           -- Tự cắn bình thuốc Damage, Coins, Luck, Speed, Treasure
        PotionInterval = 90,
        Toys = true,              -- Tự chơi Đồ chơi (Toy Ball, Toy Bone, Squeaky Toy)
        ToyInterval = 180,
    },

    -- [TÍNH NĂNG MỞ ĐỦ 30 TRỨNG TẠI MAP MỚI & TÍCH COIN CHỜ MAP TIẾP]
    NewZoneHatch = {
        Enabled = true,
        TargetEggs = 30,          -- Mở đủ 30 quả trứng tại map mới; nếu thiếu coin tự động farm bãi và quay lại mở tiếp
    },

    -- Tự động hóa tài khoản mới & Nâng cấp
    AutoPickStarterPets = true,   -- Tự chọn 2 pet starter cho acc mới
    AutoOpenSlots = true,         -- Tự động mua slot pet và slot hatch trứng bằng Gems
    AutoClaimFreeGifts = true,    -- Tự nhận 12 mốc quà Free Gifts định kỳ

    -- Discord Webhook Notifications
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
        NotifyEveryRank = true,
        TargetRank = 11,
    },

    -- Frost Hub Blackout GUI & Performance (Đen toàn màn hình 100% không chừa khoảng trống)
    ShowGui = true,             -- [BẬT GUI FROST CARD]: Hiển thị thẻ thông số và badge đỉnh
    BlackoutGui = true,         -- [ĐEN TOÀN MÀN HÌNH]: Màn hình đen tuyền AMOLED 100%
    Disable3DRendering = true,  -- [TẮT 3D RENDERING]: Tiết kiệm CPU / GPU tối đa cho máy farm nhiều acc
    TargetFPS = 5,              -- Khóa 5 FPS theo yêu cầu để tối ưu tài nguyên tối đa
    GuiToggleKey = Enum.KeyCode.RightControl,

    FarmTick = 0.25,
    HatchDelay = 0.75,
    HatchMaxDistance = 85,
    ControllerTick = 1.0,
    CraftTick = 4.0,
    EventTick = 3.0,
    ZonePositionTolerance = 25,
    MaxInventoryPotionTier = 10,
    PotionUsePriority = { "Lucky", "Coins", "Diamonds", "Treasure Hunter", "Damage" },
    PotionUpgradePriority = { "Coins", "Diamonds", "Lucky", "Treasure Hunter", "Damage" },
    EnchantUpgradePriority = {
        "Coins",
        "Diamonds",
        "Tap Power",
        "Criticals",
        "Lucky Eggs",
        "Strong Pets",
        "Treasure Hunter",
    },
    FruitUsePriority = { "Apple", "Orange", "Pineapple", "Banana", "Watermelon", "Rainbow" },
    AllowShinyFruit = false,
    FlagPriority = {
        "Coins Flag",
        "Diamonds Flag",
        "Hasty Flag",
        "Strength Flag",
        "Magnet Flag",
        "Fortune Flag",
        "Shiny Flag",
    },
    CoinJarPriority = { "Basic Coin Jar", "Giant Coin Jar", "Magic Coin Jar" },
    ProtectedPetIds = {},
    UseShinyPetsAsFodder = false,
    WorkspaceFile = "PS99-AutoRank.luau",
    ShowGui = true,
    ReduceMotion = false,
    ShowOverviewStats = true,
}

local SavedOptions = {
    { "ReduceMotion", "Reduce motion", "Appearance" },
    { "ShowOverviewStats", "Show activity totals", "Appearance" },
    { "AutoFarm", "Farm breakables", "Progression" },
    { "AutoEquipBestPets", "Equip best pets", "Progression" },
    { "AutoPickStarterPets", "Pick starter pets", "Progression" },
    { "AutoOpenSlots", "Buy pet & egg slots", "Progression" },
    { "AutoClaimFreeGifts", "Claim free gifts", "Progression" },
    { "AutoClaimRewards", "Auto claim rank rewards", "Progression" },
    { "AutoBuyZones", "Buy zones", "Progression" },
    { "AutoWorldTeleport", "Switch worlds", "Progression" },
    { "AutoSpawnEvents", "Use event items", "Items" },
    { "AutoUsePotions", "Use potions", "Items" },
    { "AutoUpgradePotions", "Upgrade potions", "Items" },
    { "AutoUpgradeEnchants", "Upgrade enchants", "Items" },
    { "AutoUseFruits", "Use fruit", "Items" },
    { "AutoUseFlags", "Use flags", "Items" },
    { "AutoHatch", "Hatch eggs", "Hatching" },
    { "AutoTapEggs", "Tap eggs to open", "Hatching" },
    { "AlwaysHatch", "Hatch without a quest", "Hatching" },
    { "AutoCraftGoldRainbow", "Craft gold and rainbow", "Crafting" },
}

return {
    Config = Config,
    SavedOptions = SavedOptions,
}
