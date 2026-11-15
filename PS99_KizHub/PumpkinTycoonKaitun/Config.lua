-- =========================================================================
-- PS99_KizHub/PumpkinTycoonKaitun/Config.lua
-- Cấu hình trung tâm cho Suite tự động hóa Pumpkin Patch Tycoon Pet Simulator 99
-- Tác giả: VANTA [JHON369] | KizHub Automation Engine
-- =========================================================================

local genv = (type(getgenv) == "function" and getgenv()) or _G

local Config = {
    -- Cài đặt chung & Hiệu năng (BẢN TEST DELTA - ẨN GUI HOÀN TOÀN, KHÔNG OPTIMIZE)
    Enabled = true,
    ShowGui = false,            -- [DELTA]: Ẩn hoàn toàn GUI bảng điều khiển trên màn hình theo yêu cầu của dj
    CPUSaver = false,           -- [BẢN TEST]: Tắt CPU Saver để quan sát nhân vật, pet và hiệu ứng 3D
    TargetFPS = 60,             -- FPS mượt mà 60 FPS
    Blackout = false,           -- Tắt màn hình đen
    HidePlayers = false,        -- Hiện người chơi bình thường
    AfkPulseInterval = 35,

    -- Tốc độ Pet siêu tốc (Infinite Pet Speed)
    InfinitePetSpeed = true,    -- [Infinite Pet Speed]: Hook CalculateSpeedMultiplier 999999 di chuyển và tiếp cận quặng/bí ngô tức thì
    PetSpeedMultiplier = 999999,

    -- Tự động sử dụng Buffs (Trái cây, Bình thuốc, Đồ chơi) - TUYỆT ĐỐI KHÔNG CẮM CỜ
    AutoBuffs = {
        Enabled = true,
        Fruits = true,          -- Tự động ăn Fruit (Apple, Banana, Orange, Rainbow...) tối đa 20 quả/lần
        Potions = true,         -- Tự động uống Potions (Damage, Coins, Luck, Speed, Treasure, Lightning...)
        Toys = true,            -- Tự động kích hoạt Đồ chơi (Toy Ball, Toy Bone, Squeaky Toy)
        NoFlags = true,         -- TUYỆT ĐỐI KHÔNG CẮM CỜ (Event này cấm cắm cờ)
        FruitInterval = 60,
        PotionInterval = 90,
        ToyInterval = 180,
    },

    -- Chế độ di chuyển: "Rage" = Teleport tức thì; "Legit" = Pathfinding né nước & nhảy chướng ngại
    MovementMode = "Rage",

    -- Farm đảo & Quái Bí Ngô
    AutoFarmTycoon = true,
    ForceZone = nil, -- Đặt 1, 2, 3, 4, 5 nếu muốn cố định bãi farm; để nil để tự động theo tiến độ đảo
    BreakBigPumpkins = false,
    BigPumpkinMaxDistance = 400,

    -- Mua nút Tycoon & Nhận thưởng đảo
    AutoBuyButtons = true,
    ButtonBuyInterval = 2.0,
    AutoClaimIslandReward = true,

    -- Mở Trứng Custom tốt nhất
    AutoHatchBestEgg = true,
    HatchDelay = 1.0,

    -- Auto Click / Gõ quặng (giãn cách 1.5s tối ưu CPU)
    AutoTap = {
        Enabled = true,
        TapDelay = 1.5,
    },

    -- Nâng cấp máy Upgrade Machine
    AutoUpgrades = true,
    UpgradeInterval = 10,
    UpgradeOrder = {
        "SpawnLuck",
        "PumpkinCoins",
        "PumpkinDamage",
        "RespawnSpeed",
        "StockSlots",
        "ChaseOdds",
        "EggLuck",
        "MerchantLuck",
        "AutoBreakRules",
    },

    -- Trạm Hot Cocoa Boost
    AutoHotCocoa = true,
    CocoaInterval = 60,
    CocoaMinRemainingSeconds = 900, -- Mua thêm khi còn dưới 15 phút
    AutoConsumeBoosts = true,

    -- Chế tạo Pet Vàng / Cầu Vồng Tycoon
    AutoGoldRainbowPets = true,
    GoldRainbowInterval = 20,
    GoldRainbowBatchSize = 10,

    -- Merchant & Quầy hàng Pedestal
    AutoMerchant = true,
    AutoPlaceStock = true,
    MerchantInterval = 3,
    MerchantBandOrder = {
        "ExoticPlus",
        "MythicalPlus",
        "LegendaryPlus",
        "EpicPlus",
        "RarePlus",
        "Exotic",
        "Mythical",
        "Legendary",
        "Epic",
        "Rare",
    },

    -- Quà Flannel & Quà miễn phí
    AutoOpenFlannelGifts = true,
    GiftOpenInterval = 60,
    AutoClaimFreeGifts = true,

    -- Mailbox & Quà tặng
    AutoDaycare = false,
    AutoMailHuge = true,
    AutoMailTier2Boosts = true, -- Tự động gift qua Mailbox khi có Tier 2 Boost (Island Luck, Patch Coin, Pumpkin Damage) dù chỉ 1 cái
    AutoConsumeTier1Boosts = true, -- Tự động cắn Boost Tier 1 để tối ưu farm
    MailRecipient = genv.MailRecipient or "Kizmoii_VNG",
    MailRetryInterval = 1800,
    MailCooldownSec = 61,

    -- Cân đối ngân sách Tycoon thông minh (Mua Button vs Mở Egg)
    Economy = {
        HatchCyclesBeforeButtonCheck = 3, -- Cứ mở egg 3 lần sẽ check nút rẻ nhất tiếp theo và ngưng mở egg cho tới khi mua xong nút (ở bãi 1-4)
        InfiniteHatchAtFinalEgg = true,  -- Khi đã mở được Egg ở bãi farm cuối (Bãi 5): Mở vô hạn liên tục (Infinite Hatch), bỏ qua giới hạn 3 lần và không chờ mua nút
        PrioritizeEggButtons = true,    -- Luôn gom 100% tiền mua ngay nút Egg & Zone khi xuất hiện
        ReserveRatioForExpensive = 0.6, -- Với nút giá cao: Giữ 60% tiền làm quỹ tích lũy, dùng thặng dư hatch
    },

    -- Discord Webhook
    Webhook = {
        Enabled = true,
        EventsUrl = genv.EventsUrl or genv.WebhookUrl or "",
        StatusUrl = genv.StatusUrl or genv.WebhookUrl or "",
        StatusInterval = 1800,
        NotifyHuge = true,
        NotifyTitanic = true,
    },
}

-- Bảng hằng số & API Game Pumpkin Tycoon
local K = {
    INSTANCE_ID = "PumpkinTycoon",
    CURRENCY    = "PumpkinTycoonCoins",
    TOKENS      = "PumpkinTokens",

    -- Verbs gọi Server Plot: plot:Invoke(verb, ...)
    VERBS = {
        BuyButton       = "NZ_Commit",
        ClaimReward     = "BT_Settle",
        AutoBreakPolicy = "QW_Policy",
        PedestalShelter = "KT_Shelter",
        AutoMerchant    = "HM_Sustain",
        BuyStock        = "FZ_Reserve",
        AutoPlaceStock  = "JD_Prefer",
        PlaceStock      = "XC_Allocate",
        Upgrade         = "OQ_Advance",
        ExtendCocoa     = "VB_Extend",
        OpenGift        = "KX_Release",
    },

    -- 5 Khu vực bãi cày & Trứng tương ứng
    ZONES = {
        [1] = { Egg = "Cocoa Cabin Egg",   EggBtn = "CocoaCabin_Egg",   Section = "CocoaCabin",   DisplayName = "Cocoa Cabin" },
        [2] = { Egg = "Apple Orchard Egg", EggBtn = "AppleOrchard_Egg", Section = "AppleOrchard", DisplayName = "Apple Orchard" },
        [3] = { Egg = "Hayride Hill Egg",  EggBtn = "HayrideHill_Egg",  Section = "HayrideHill",  DisplayName = "Hayride Hill" },
        [4] = { Egg = "Cider Mill Egg",    EggBtn = "CiderMill_Egg",    Section = "CiderMill",    DisplayName = "Cider Mill" },
        [5] = { Egg = "Golden Grove Egg",  EggBtn = "GoldenGrove_Egg",  Section = "GoldenGrove",  DisplayName = "Golden Grove" },
    },

    -- Phân hạng bậc Roster Pet của Pumpkin Tycoon
    ROSTER_RUNG = {
        ["Gourd Toad"]      = 1,
        ["Toasty Monkey"]   = 2,
        ["Toasty Otter"]    = 3,
        ["Toasty Capybara"] = 3,
        ["Gourd Piggy"]     = 4,
        ["Gourd Koala"]     = 4,
        ["Orchard Hedgehog"]= 5,
        ["Orchard Moose"]   = 5,
        ["Orchard Pony"]    = 6,
        ["Maple Lion"]      = 6,
        ["Maple Kitsune"]   = 7,
        ["Pumpkin Dragon"]  = 8,
    },

    UPGRADE_TRACKS = {
        "SpawnLuck",
        "PumpkinCoins",
        "PumpkinDamage",
        "RespawnSpeed",
        "StockSlots",
        "ChaseOdds",
        "EggLuck",
        "MerchantLuck",
        "AutoBreakRules",
    },
}

-- Đồng bộ cấu hình từ genv nếu đã tồn tại
if type(genv.KaitunConfig) == "table" then
    for k, v in pairs(genv.KaitunConfig) do
        Config[k] = v
    end
else
    genv.KaitunConfig = Config
end

return {
    Config = Config,
    K = K,
}
