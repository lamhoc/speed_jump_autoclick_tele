-- =========================================================================
-- PS99_KizHub/PumpkinTycoonKaitun/TycoonMachines.lua
-- Module tự động hóa các máy trạm & tính năng phụ trợ trên đảo Pumpkin Tycoon
-- Bao gồm:
--   1. Auto Nâng cấp máy Upgrade Machine (Tokens)
--   2. Auto Merchant & Auto Đặt hàng vào Pedestal (Stock Allocation)
--   3. Auto Mua & Duy trì Hot Cocoa Boosts (VB_Extend)
--   4. Auto Chế tạo Pet Vàng & Cầu Vồng (Roster Rung)
--   5. Auto Mở Quà Flannel Gift & Quà miễn phí
-- Tác giả: VANTA [JHON369] | KizHub Automation Engine
-- =========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TycoonMachines = {}

-- Dependencies
local Modules = nil
local Network = nil
local Config = nil
local K = nil
local Webhook = nil
local inEventFn = nil
local instanceModelFn = nil

-- Cache Client Modules
local IslandCmds = nil
local PTButtons = nil
local UpgradesCmds = nil
local UpgradesTypes = nil
local MerchantCmds = nil
local StockCmds = nil
local MerchantTypes = nil
local PTCocoa = nil
local CocoaCmds = nil

local function safeRequire(pathTbl)
    local cur = ReplicatedStorage
    for _, part in ipairs(pathTbl) do
        cur = cur and cur:FindFirstChild(part)
        if not cur then return nil end
    end
    local ok, res = pcall(require, cur)
    return ok and res or nil
end

local function initMachineLibs()
    if not IslandCmds then
        IslandCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Island" })
    end
    if not PTButtons then
        PTButtons = safeRequire({ "Library", "Util", "PumpkinTycoonButtons" })
    end
    if not UpgradesCmds then
        UpgradesCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Upgrades" })
    end
    if not UpgradesTypes then
        UpgradesTypes = safeRequire({ "Library", "Types", "PumpkinTycoon", "Upgrades" })
    end
    if not MerchantCmds then
        MerchantCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Merchant" })
    end
    if not StockCmds then
        StockCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Stock" })
    end
    if not MerchantTypes then
        MerchantTypes = safeRequire({ "Library", "Types", "PumpkinTycoon", "Merchant" })
    end
    if not PTCocoa then
        PTCocoa = safeRequire({ "Library", "Util", "PumpkinTycoonCocoa" })
    end
    if not CocoaCmds then
        CocoaCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Cocoa" })
    end
end

function TycoonMachines.init(deps)
    Modules = deps.Modules
    Network = deps.Network
    Config = deps.Config
    K = deps.K
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
    initMachineLibs()
end

local function getPlot()
    initMachineLibs()
    if IslandCmds and type(IslandCmds.Plot) == "function" then
        local ok, p = pcall(IslandCmds.Plot)
        if ok and p then return p end
    end
    return nil
end

-- =========================================================================
-- 1. AUTO NÂNG CẤP MÁY UPGRADE MACHINE (SỬ DỤNG PUMPKIN TOKENS)
-- =========================================================================

local lastUpgradeCheck = 0
local function runUpgrades(plot, buttonsState)
    if not Config.AutoUpgrades then return end
    local now = os.clock()
    if now - lastUpgradeCheck < (Config.UpgradeInterval or 10) then return end
    lastUpgradeCheck = now

    local hasMachine = false
    if PTButtons and type(PTButtons.Owned) == "function" then
        hasMachine = PTButtons.Owned(buttonsState, "UpgradeMachine")
    else
        hasMachine = (buttonsState["UpgradeMachine"] == true or buttonsState["UpgradeMachine"] == 1)
    end
    if not hasMachine then return end

    local tokens = Network.currency(K.TOKENS) or 0
    if tokens <= 0 then return end

    local order = Config.UpgradeOrder or K.UPGRADE_TRACKS
    for _, track in ipairs(order) do
        local curTier = 0
        local cost = 999999999

        pcall(function()
            if UpgradesCmds and type(UpgradesCmds.Tier) == "function" then
                curTier = UpgradesCmds.Tier(track) or 0
            end
            if UpgradesTypes and type(UpgradesTypes.Cost) == "function" then
                cost = UpgradesTypes.Cost(track, curTier + 1) or 999999999
            elseif UpgradesCmds and type(UpgradesCmds.Cost) == "function" then
                cost = UpgradesCmds.Cost(track, curTier + 1) or 999999999
            end
        end)

        if tokens >= cost then
            local okU = pcall(function()
                plot:Invoke(K.VERBS.Upgrade, track)
            end)
            if okU then
                tokens = tokens - cost
                task.wait(0.2)
            end
        end
    end
end

-- =========================================================================
-- 2. AUTO MERCHANT & AUTO PLACE STOCK VÀO BỆ PEDESTAL
-- =========================================================================

local lastMerchantCheck = 0
local function runMerchantAndStock(plot, buttonsState)
    if not (Config.AutoMerchant or Config.AutoPlaceStock) then return end
    local now = os.clock()
    if now - lastMerchantCheck < (Config.MerchantInterval or 3) then return end
    lastMerchantCheck = now

    local hasMerchant = false
    if PTButtons and type(PTButtons.Owned) == "function" then
        hasMerchant = PTButtons.Owned(buttonsState, "Merchant") or PTButtons.Owned(buttonsState, "PumpkinMerchant") or PTButtons.Owned(buttonsState, "MerchantStand")
    end
    if not hasMerchant then
        hasMerchant = (buttonsState["Merchant"] == true or buttonsState["Merchant"] == 1 or buttonsState["PumpkinMerchant"] == true or buttonsState["MerchantStand"] == true)
    end
    if not hasMerchant and MerchantCmds and type(MerchantCmds.Unlocked) == "function" then
        pcall(function()
            hasMerchant = (MerchantCmds.Unlocked() == true)
        end)
    end
    -- Fallback: Nếu không đọc được nút nhưng plot tồn tại thì luôn thử thực thi an toàn
    if not hasMerchant and plot then
        hasMerchant = true
    end
    if not hasMerchant then return end

    -- 1. Bật cờ Server Auto-Merchant nếu chưa bật
    pcall(function()
        local mAuto = plot:Save("MerchantAuto")
        if mAuto == false then
            plot:Invoke(K.VERBS.AutoMerchant or "AutoMerchant", true)
        end
    end)

    -- 2. Tự động mua hàng Merchant theo thứ tự Rarity Band nếu kho Stock còn chỗ
    if Config.AutoMerchant then
        pcall(function()
            local stockData = plot:Save("Stock")
            local stockList = (MerchantTypes and type(MerchantTypes.CleanStock) == "function" and MerchantTypes.CleanStock(stockData)) or stockData or {}
            local maxSlots = (MerchantCmds and type(MerchantCmds.Slots) == "function" and MerchantCmds.Slots()) or 8

            if #stockList < maxSlots then
                -- Thử gọi trực tiếp MerchantCmds client nếu có
                if MerchantCmds then
                    if type(MerchantCmds.Buy) == "function" then pcall(MerchantCmds.Buy) end
                    if type(MerchantCmds.BuyAll) == "function" then pcall(MerchantCmds.BuyAll) end
                end

                local bands = Config.MerchantBandOrder or { "ExoticPlus", "MythicalPlus", "LegendaryPlus", "EpicPlus", "RarePlus", "Exotic", "Mythical", "Legendary", "Epic", "Rare" }
                for _, band in ipairs(bands) do
                    local okB = pcall(function()
                        plot:Invoke(K.VERBS.BuyStock or "BuyStock", band)
                    end)
                    if okB then
                        task.wait(0.08)
                    end
                end
                pcall(function()
                    plot:Invoke(K.VERBS.BuyStock or "BuyStock")
                end)
            end
        end)
    end

    -- 3. Bật cờ Server Auto-Place Stock nếu chưa bật
    if Config.AutoPlaceStock then
        pcall(function()
            local spAuto = plot:Save("StockAutoPlace")
            if spAuto == false then
                plot:Invoke(K.VERBS.AutoPlaceStock or "AutoPlaceStock", true)
            end
        end)

        -- 4. Phân phối hàng tồn kho vào các bệ Pedestal còn trống
        pcall(function()
            local peds = (StockCmds and type(StockCmds.Pedestals) == "function" and StockCmds.Pedestals()) or plot:Save("Pedestals") or {}
            local stock = (StockCmds and type(StockCmds.Stock) == "function" and StockCmds.Stock()) or plot:Save("Stock") or {}

            if #stock > 0 then
                for idx, ped in pairs(peds) do
                    local pIdx = tonumber(idx) or (type(ped) == "table" and ped.index)
                    local isEmpty = (type(ped) == "table" and (ped.empty == true or ped.Band == nil or ped.Band == ""))
                    local isUnlocked = (type(ped) == "table" and ped.Locked ~= true)

                    if pIdx and isEmpty and isUnlocked then
                        local bestBand = stock[1]
                        if type(bestBand) == "table" and bestBand.Band then
                            bestBand = bestBand.Band
                        end
                        if bestBand then
                            plot:Invoke(K.VERBS.PlaceStock or "PlaceStock", pIdx, bestBand)
                            task.wait(0.12)
                        end
                    end
                end
            end
        end)
    end
end

-- =========================================================================
-- 3. AUTO MUA & DUY TRÌ HOT COCOA BOOSTS
-- =========================================================================

local lastCocoaCheck = 0
local function runHotCocoa(plot, buttonsState)
    if not Config.AutoHotCocoa then return end
    local now = os.clock()
    if now - lastCocoaCheck < (Config.CocoaInterval or 60) then return end
    lastCocoaCheck = now

    local hasStand = false
    if PTButtons and type(PTButtons.Owned) == "function" then
        hasStand = PTButtons.Owned(buttonsState, "CocoaStand")
    else
        hasStand = (buttonsState["CocoaStand"] == true or buttonsState["CocoaStand"] == 1)
    end

    if hasStand and PTCocoa and type(PTCocoa.OFFERS) == "table" then
        local minSec = Config.CocoaMinRemainingSeconds or 900
        for _, offer in ipairs(PTCocoa.OFFERS) do
            local rem = 0
            if CocoaCmds and type(CocoaCmds.Remaining) == "function" then
                rem = CocoaCmds.Remaining(offer.Id) or 0
            end

            if rem < minSec then
                pcall(function()
                    plot:Invoke(K.VERBS.ExtendCocoa, offer.Key, 15)
                end)
                task.wait(0.1)
            end
        end
    end

    -- Tự động sử dụng các bình Buff / Vật phẩm Hot Cocoa / Boost Event trong túi đồ
    if Config.AutoConsumeBoosts ~= false then
        pcall(function()
            local s = Network.getSave()
            local inv = s and s.Inventory
            if not inv then return end

            local itemsToConsume = {
                "Patch Coin Boost",
                "Pumpkin Damage Boost",
                "Island Luck Boost",
                "Hot Cocoa",
                "Pumpkin Boost",
                "Tycoon Boost",
                "Event Luck Potion",
                "Event Potion",
            }
            local eventKeywords = { "boost", "cocoa", "pumpkin", "patch" }

            for _, cat in ipairs({ "Consumable", "Misc", "Item", "Potion" }) do
                if type(inv[cat]) == "table" then
                    for uid, itemData in pairs(inv[cat]) do
                        if type(itemData) == "table" and type(itemData.id) == "string" then
                            local idLower = string.lower(itemData.id)
                            local matched = false

                            for _, exactName in ipairs(itemsToConsume) do
                                if itemData.id == exactName or idLower == string.lower(exactName) then
                                    matched = true
                                    break
                                end
                            end

                            if not matched then
                                for _, kw in ipairs(eventKeywords) do
                                    if idLower:find(kw) then
                                        matched = true
                                        break
                                    end
                                end
                            end

                            if matched then
                                -- THEO LỆNH MỚI CỦA DJ:
                                -- Tự động sử dụng toàn bộ Boost (cả Tier 1 và Tier 2) để buff tối đa tốc độ farm & mở trứng
                                local amt = tonumber(itemData._am) or 1
                                if amt > 0 then
                                    if cat == "Potion" then
                                        Network.netFire("Potions: Consume", itemData.id)
                                    else
                                        -- Thử HotCocoa_Consume nếu là Cocoa
                                        if idLower:find("cocoa") then
                                            local okCocoa = Network.netInvoke("HotCocoa_Consume", uid)
                                            if not okCocoa then
                                                Network.netFire("HotCocoa_Consume", uid)
                                            end
                                        end
                                        -- Gọi Consumables_Consume chuẩn (hỗ trợ mọi Tier)
                                        local okCons = Network.netInvoke("Consumables_Consume", uid, 1)
                                        if not okCons then
                                            Network.netFire("Consumables_Consume", uid, 1)
                                        end
                                    end
                                    task.wait(0.08)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- =========================================================================
-- 4. AUTO CHẾ TẠO PET VÀNG & CẦU VỒNG (ROSTER RUNG PETS)
-- =========================================================================

local lastGoldRainbowCheck = 0
local function runGoldRainbowPets(buttonsState)
    if not Config.AutoGoldRainbowPets then return end
    local now = os.clock()
    if now - lastGoldRainbowCheck < (Config.GoldRainbowInterval or 20) then return end
    lastGoldRainbowCheck = now

    local hasGold = false
    local hasRainbow = false
    if PTButtons and type(PTButtons.Owned) == "function" then
        hasGold = PTButtons.Owned(buttonsState, "GoldMachine")
        hasRainbow = PTButtons.Owned(buttonsState, "RainbowMachine")
    else
        hasGold = (buttonsState["GoldMachine"] == true or buttonsState["GoldMachine"] == 1)
        hasRainbow = (buttonsState["RainbowMachine"] == true or buttonsState["RainbowMachine"] == 1)
    end

    if not hasGold and not hasRainbow then return end

    local s = Network.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    -- Lấy danh sách UID pet đang trang bị để không động vào
    local equipped = {}
    pcall(function()
        if Modules and Modules.G and Modules.G.PetCmds and Network.isfn(Modules.G.PetCmds, "GetEquippedItems") then
            local ok, items = Network.gcall(Modules.G.PetCmds.GetEquippedItems)
            if ok and type(items) == "table" then
                for _, it in pairs(items) do
                    if type(it) == "string" then equipped[it] = true
                    elseif type(it) == "table" and type(it.GetUID) == "function" then
                        local okU, uid = pcall(it.GetUID, it)
                        if okU and uid then equipped[uid] = true end
                    end
                end
            end
        end
        if s.EquippedPets then
            for uid, _ in pairs(s.EquippedPets) do equipped[uid] = true end
        end
    end)

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" and not equipped[uid] and p._lk ~= true and p.locked ~= true then
            local idLower = p.id:lower()
            -- Tuyệt đối bỏ qua Huge, Titanic, Gargantuan
            local isSpecial = idLower:find("huge") or idLower:find("titanic") or idLower:find("gargantuan")

            if not isSpecial and K.ROSTER_RUNG[p.id] then
                local am = tonumber(p._am) or 1
                local isGold = (p.pt == 1 or p.g == true)
                local isRainbow = (p.pt == 2 or p.r == true)

                -- 1. Nâng lên Vàng (cần ít nhất 10 con thường)
                if hasGold and not isGold and not isRainbow and am >= 10 then
                    local batches = math.floor(am / 10)
                    local okM = Network.netInvoke("GoldMachine_Activate", uid, batches)
                    if okM then
                        task.wait(0.3)
                    end
                end

                -- 2. Nâng lên Cầu Vồng (cần ít nhất 10 con vàng)
                if hasRainbow and isGold and not isRainbow and am >= 10 then
                    local batches = math.floor(am / 10)
                    local okR = Network.netInvoke("RainbowMachine_Activate", uid, batches)
                    if okR then
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end

-- =========================================================================
-- 5. AUTO MỞ QUÀ FLANNEL GIFT & QUÀ MIỄN PHÍ
-- =========================================================================

local lastGiftCheck = 0
local function runFlannelGifts(plot)
    if not Config.AutoOpenFlannelGifts then return end
    local now = os.clock()
    if now - lastGiftCheck < (Config.GiftOpenInterval or 60) then return end
    lastGiftCheck = now

    pcall(function()
        local s = Network.getSave()
        local inv = s and s.Inventory
        if not inv then return end

        local targetCategories = { "Lootbox", "Box", "Gift", "Misc", "Consumable" }
        for _, cat in ipairs(targetCategories) do
            local folder = inv[cat]
            if type(folder) == "table" then
                for uid, item in pairs(folder) do
                    if type(item) == "table" then
                        local itemId = tostring(item.id or item._id or uid or "")
                        if itemId:lower():find("flannel") then
                            local am = tonumber(item._am or item.Amount or item.am or 1) or 1
                            local count = math.clamp(am, 1, 100)

                            -- Mở quà chuẩn xác 100% theo chữ ký LootboxCmds.Open & Remote YR_Hydrate đã bắt được từ game
                            local itemObj = {
                                class = item.Class or cat or "Lootbox",
                                data = { id = item.id or "Flannel Gift" },
                                uid = uid,
                            }

                            local LootboxCmds = safeRequire({ "Library", "Client", "LootboxCmds" })
                            local opened = false
                            if LootboxCmds and type(LootboxCmds.Open) == "function" then
                                local okLb = pcall(LootboxCmds.Open, itemObj, count)
                                if okLb then opened = true end
                            end

                            if not opened then
                                pcall(function()
                                    Network.netInvoke("YR_Hydrate", uid, count, {})
                                end)
                            end

                            task.wait(0.2)
                            pcall(function()
                                local genv = (type(getgenv) == "function" and getgenv()) or _G
                                local eventsUrl = (Config and Config.Webhook and Config.Webhook.EventsUrl)
                                if (not eventsUrl or eventsUrl == "") and genv then
                                    eventsUrl = genv.EventsUrl or genv.WebhookUrl
                                end
                                if eventsUrl and eventsUrl ~= "" and Webhook and type(Webhook.checkNewHugeHatched) == "function" then
                                    Webhook.checkNewHugeHatched(Network.getSave, eventsUrl)
                                end
                            end)
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- 6. TỰ ĐỘNG NHẬN 12 MỐC QUÀ FREE GIFTS THEO THỜI GIAN CHƠI
-- =========================================================================

local lastFreeGiftCheck = 0
local function runFreeGifts()
    if not Config.AutoClaimFreeGifts then return end
    local now = os.clock()
    if now - lastFreeGiftCheck < 90 then return end
    lastFreeGiftCheck = now

    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local FreeGiftsCmds = safeRequire({ "Library", "Client", "FreeGiftsCmds" })
        for i = 1, 12 do
            local claimed = false
            if FreeGiftsCmds and type(FreeGiftsCmds.Claim) == "function" then
                local ok, res = pcall(FreeGiftsCmds.Claim, i)
                if ok and res == true then claimed = true end
            end
            if not claimed then
                local okInv, resInv = Network.netInvoke("Redeem Free Gift", i)
                if okInv and resInv == true then claimed = true end
            end
            if not claimed then
                Network.netFire("Redeem Free Gift", i)
            end
            if not claimed then
                local r = RS:FindFirstChild("Network") and RS.Network:FindFirstChild("Redeem Free Gift")
                if r then
                    if r:IsA("RemoteFunction") then pcall(function() r:InvokeServer(i) end)
                    elseif r:IsA("RemoteEvent") then pcall(function() r:FireServer(i) end) end
                end
            end
            task.wait(0.1)
        end
    end)
end

-- =========================================================================
-- 7. TỔNG HỢP VÒNG LẶP MÁY & TÓM TẮT DỮ LIỆU UI
-- =========================================================================

function TycoonMachines.runAllMachinesTick(state)
    local plot = getPlot()
    if plot then
        local buttonsState = plot:Save("Buttons") or {}
        runUpgrades(plot, buttonsState)
        runMerchantAndStock(plot, buttonsState)
        runHotCocoa(plot, buttonsState)
        runGoldRainbowPets(buttonsState)
        runFlannelGifts(plot)
    end
    runFreeGifts()
end

local UPGRADE_TRACK_SPECS = {
    { id = "SpawnLuck", name = "Spawn Luck", max = 10 },
    { id = "PumpkinCoins", name = "Coins", max = 10 },
    { id = "PumpkinDamage", name = "Damage", max = 10 },
    { id = "RespawnSpeed", name = "Spawns", max = 8 },
    { id = "StockSlots", name = "Stock", max = 5 },
    { id = "ChaseOdds", name = "Chase", max = 8 },
    { id = "EggLuck", name = "Egg Luck", max = 10 },
    { id = "MerchantLuck", name = "Merchant", max = 8 },
    { id = "AutoBreakRules", name = "AutoBreak", max = 5 },
}

function TycoonMachines.getMachineSummary()
    initMachineLibs()
    local plot = getPlot()

    local buttonsState = {}
    pcall(function()
        if IslandCmds and type(IslandCmds.Get) == "function" then
            buttonsState = IslandCmds.Get(nil, "Buttons") or {}
        end
    end)
    if not buttonsState or not next(buttonsState) then
        pcall(function()
            if plot and type(plot.Save) == "function" then
                buttonsState = plot:Save("Buttons") or {}
            end
        end)
    end

    local hasMachine = false
    if PTButtons and type(PTButtons.Owned) == "function" then
        hasMachine = PTButtons.Owned(buttonsState, "UpgradeMachine")
    else
        hasMachine = (buttonsState["UpgradeMachine"] == true or buttonsState["UpgradeMachine"] == 1)
    end
    if not hasMachine and UpgradesCmds and type(UpgradesCmds.Unlocked) == "function" then
        pcall(function()
            hasMachine = (UpgradesCmds.Unlocked() == true)
        end)
    end

    local tokens = Network.currency(K.TOKENS) or 0
    if tokens <= 0 then
        local s = Network.getSave and Network.getSave()
        if s then
            local cur = (s.Inventory and s.Inventory.Currency) or s.Currencies or s.Currency
            if type(cur) == "table" then
                for _, v in pairs(cur) do
                    if type(v) == "table" and (v.id == K.TOKENS or v._id == K.TOKENS) then
                        tokens = tonumber(v._am or v.Amount) or 0
                        break
                    end
                end
            end
        end
    end

    local totalTiers = 0
    local maxTiers = 74
    local trackTiers = {}
    local nextUpgrade = nil

    local order = (Config and Config.UpgradeOrder) or {}
    local checkedTracks = {}
    local orderedSpecs = {}

    for _, trId in ipairs(order) do
        for _, spec in ipairs(UPGRADE_TRACK_SPECS) do
            if spec.id == trId then
                table.insert(orderedSpecs, spec)
                checkedTracks[spec.id] = true
                break
            end
        end
    end
    for _, spec in ipairs(UPGRADE_TRACK_SPECS) do
        if not checkedTracks[spec.id] then
            table.insert(orderedSpecs, spec)
        end
    end

    for _, spec in ipairs(orderedSpecs) do
        local curTier = 0
        pcall(function()
            if UpgradesCmds and type(UpgradesCmds.Tier) == "function" then
                curTier = tonumber(UpgradesCmds.Tier(spec.id)) or 0
            end
        end)
        totalTiers = totalTiers + curTier
        trackTiers[spec.id] = curTier

        if curTier < spec.max and not nextUpgrade then
            local cost = 999999999
            pcall(function()
                if UpgradesTypes and type(UpgradesTypes.Cost) == "function" then
                    cost = UpgradesTypes.Cost(spec.id, curTier + 1) or 999999999
                elseif UpgradesCmds and type(UpgradesCmds.Cost) == "function" then
                    cost = UpgradesCmds.Cost(spec.id, curTier + 1) or 999999999
                end
            end)
            nextUpgrade = {
                id = spec.id,
                name = spec.name,
                curTier = curTier,
                nextTier = curTier + 1,
                maxTier = spec.max,
                cost = cost,
            }
        end
    end

    local activeCocoa = 0
    pcall(function()
        if CocoaCmds and type(CocoaCmds.Remaining) == "function" and PTCocoa and PTCocoa.OFFERS then
            for _, o in ipairs(PTCocoa.OFFERS) do
                local rem = CocoaCmds.Remaining(o.Id) or 0
                if rem > 0 then
                    activeCocoa = math.max(activeCocoa, math.floor(rem / 60))
                end
            end
        end
    end)

    local stockCount = 0
    pcall(function()
        local s = plot and plot:Save("Stock")
        if type(s) == "table" then stockCount = #s end
    end)

    local flannelGiftCount = 0
    pcall(function()
        local s = Network.getSave and Network.getSave()
        if s and s.Inventory and s.Inventory.Lootbox then
            for _, box in pairs(s.Inventory.Lootbox) do
                if type(box) == "table" and (box.id == "Flannel Gift" or box._id == "Flannel Gift") then
                    flannelGiftCount = flannelGiftCount + (tonumber(box._am or box.Amount) or 1)
                end
            end
        end
    end)

    local merchantStatus = "Rảnh"
    pcall(function()
        local hasMerchant = (buttonsState["Merchant"] == true)
        if not hasMerchant then
            merchantStatus = "Chưa mở"
        else
            merchantStatus = "Tự động mua"
        end
    end)

    return {
        hasMachine = hasMachine,
        tokens = tokens,
        totalTiers = totalTiers,
        maxTiers = maxTiers,
        percent = maxTiers > 0 and (totalTiers / maxTiers) or 0,
        trackTiers = trackTiers,
        nextUpgrade = nextUpgrade,
        activeCocoaMin = activeCocoa,
        stockCount = stockCount,
        stockMax = 15,
        flannelGiftCount = flannelGiftCount,
        merchantStatus = merchantStatus,
    }
end

return TycoonMachines
