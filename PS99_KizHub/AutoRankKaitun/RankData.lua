-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/RankData.lua
-- Bảng dữ liệu tra cứu nhiệm vụ, mục tiêu và hằng số Rank cho Pet Simulator 99
-- =========================================================================

local RankData = {}

RankData.WORLD_PLACE_IDS = {
    [8737899170] = 1,
    [16498369169] = 2,
    [17503543197] = 3,
    [140403681187145] = 4,
}

RankData.GOAL_TYPE_NAMES = {
    [1] = "BREAKABLE",
    [2] = "PET",
    [3] = "EGG",
    [4] = "GOLD_PET",
    [5] = "RAINBOW_PET",
    [6] = "ZONE",
    [7] = "CURRENCY",
    [8] = "MINI_CHEST",
    [9] = "DIAMOND_BREAKABLE",
    [10] = "BUY_POTION",
    [11] = "BUY_ENCHANT",
    [12] = "UPGRADE_POTION",
    [13] = "UPGRADE_ENCHANT",
    [14] = "COLLECT_POTION",
    [15] = "COLLECT_ENCHANT",
    [18] = "FREE_GIFT",
    [19] = "FUSE_PETS",
    [20] = "BEST_EGG",
    [21] = "CURRENT_BREAKABLE",
    [22] = "SPAWN_OBBY",
    [23] = "MINEFIELD",
    [24] = "ATLANTIS",
    [25] = "DIGSITE",
    [26] = "FISHING",
    [27] = "ICE_OBBY",
    [28] = "PYRAMID_OBBY",
    [29] = "JUNGLE_OBBY",
    [30] = "CHEST_RUSH",
    [31] = "COIN_JAR",
    [32] = "COMET",
    [33] = "USE_FLAG",
    [34] = "USE_POTION",
    [35] = "USE_FRUIT",
    [36] = "SLED_RACE",
    [37] = "BEST_COIN_JAR",
    [38] = "BEST_COMET",
    [39] = "BEST_MINI_CHEST",
    [40] = "BEST_GOLD_PET",
    [41] = "BEST_RAINBOW_PET",
    [42] = "HATCH_RARE_PET",
    [43] = "BEST_PINATA",
    [44] = "BEST_LUCKYBLOCK",
    [45] = "ADVANCED_DIGSITE",
    [46] = "ADVANCED_FISHING",
    [47] = "INDEX_PET",
    [66] = "PINATA",
    [67] = "LUCKYBLOCK",
    [68] = "RANDOM_COIN_JAR",
    [69] = "RANDOM_COMET",
    [70] = "RANDOM_PINATA",
    [71] = "RANDOM_LUCKYBLOCK",
    [72] = "RANDOM_MINI_CHEST",
    [75] = "SUPERIOR_MINI_CHEST",
    [76] = "BEST_SUPERIOR_MINI_CHEST",
    [77] = "RANDOM_SUPERIOR_MINI_CHEST",
    [80] = "EQUIP_PET",
    [81] = "SPECIFIC_ZONE",
}

local function MakeSet(list)
    local s = {}
    for _, v in ipairs(list) do
        s[v] = true
    end
    return s
end

RankData.MakeSet = MakeSet

RankData.FARM_GOALS = MakeSet({ 1, 21, 9, 7, 14, 15, 8, 39, 75, 76 })
RankData.CHEST_GOALS = MakeSet({ 8, 39, 75, 76 })
RankData.HATCH_GOALS = MakeSet({ 20, 42, 3, 2 })
RankData.EGG_COUNT_GOALS = MakeSet({ 20, 3 })
RankData.GOLD_GOALS = MakeSet({ 40, 4 })
RankData.RAINBOW_GOALS = MakeSet({ 41, 5 })
RankData.BEST_EGG_ONLY_CRAFT = MakeSet({ 40, 41 })

RankData.T_ZONE = 6
RankData.T_DIAMOND = 9
RankData.T_UPGRADE_POTION = 12
RankData.T_UPGRADE_ENCHANT = 13
RankData.T_USE_FLAG = 33
RankData.T_USE_POTION = 34
RankData.T_USE_FRUIT = 35

RankData.EVENT_GOAL_KIND = {
    [38] = "Comet",
    [32] = "Comet",
    [43] = "Pinata",
    [66] = "Pinata",
    [44] = "LuckyBlock",
    [67] = "LuckyBlock",
    [37] = "CoinJar",
    [31] = "CoinJar",
}

RankData.EVENT_DEFS = {
    Comet = { items = { "Comet" }, remote = "Comet_Spawn", label = "comet", match = { "comet" } },
    Pinata = { items = { "Mini Pinata" }, remote = "MiniPinata_Consume", label = "pinata", match = { "pinata" } },
    LuckyBlock = {
        items = { "Mini Lucky Block" },
        remote = "MiniLuckyBlock_Consume",
        label = "lucky block",
        match = { "luckyblock" },
    },
    CoinJar = { items = { "Basic Coin Jar", "Giant Coin Jar", "Magic Coin Jar" }, remote = "CoinJar_Spawn", label = "coin jar", match = { "coinjar" } },
}

RankData.EVENT_BREAKABLE_WORDS = { "comet", "pinata", "jar", "lucky", "chest" }

RankData.POTION_TIER_REQ_FALLBACK = { 3, 3, 4, 5, 5, 5, 5, 5, 7, 7, 7 }
RankData.ENCHANT_TIER_REQ_FALLBACK = { 3, 3, 3, 5, 5, 5, 5, 5, 8, 8 }

return RankData
