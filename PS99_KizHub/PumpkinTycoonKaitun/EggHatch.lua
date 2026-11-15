-- =========================================================================
-- PS99_KizHub/PumpkinTycoonKaitun/EggHatch.lua
-- Module tự động mở Trứng Custom cao nhất trên đảo Pumpkin Patch Tycoon
-- Tác giả: VANTA [JHON369] | KizHub Automation Engine
-- =========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local EggHatch = {}

-- Dependencies
local Modules = nil
local Network = nil
local Config = nil
local K = nil
local Webhook = nil
local inEventFn = nil
local instanceModelFn = nil

local EggCmds = nil
local CustomEggsCmds = nil
local PTButtons = nil
local TycoonFarm = nil

local function safeRequire(pathTbl)
    local cur = ReplicatedStorage
    for _, part in ipairs(pathTbl) do
        cur = cur and cur:FindFirstChild(part)
        if not cur then return nil end
    end
    local ok, res = pcall(require, cur)
    return ok and res or nil
end

local function initEggLibs()
    if not EggCmds then
        EggCmds = safeRequire({ "Library", "Client", "EggCmds" })
    end
    if not CustomEggsCmds then
        CustomEggsCmds = safeRequire({ "Library", "Client", "CustomEggsCmds" })
    end
    if not PTButtons then
        PTButtons = safeRequire({ "Library", "Util", "PumpkinTycoonButtons" })
    end
end

function EggHatch.init(deps)
    Modules = deps.Modules
    Network = deps.Network
    Config = deps.Config
    K = deps.K
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
    TycoonFarm = deps.TycoonFarm
    initEggLibs()
end

-- =========================================================================
-- 1. CHẶN CUTSCENE ANIMATION MỞ TRỨNG (ZERO-LAG HATCHING)
-- =========================================================================

function EggHatch.installNoHatchAnimation()
    pcall(function()
        initEggLibs()
        if EggCmds and type(EggCmds.PlayEggAnimation) == "function" then
            EggCmds.PlayEggAnimation = function() end
        end
    end)

    pcall(function()
        if type(getsenv) ~= "function" then return end
        local ps = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
        local scripts = ps and ps:FindFirstChild("Scripts")
        local gameFolder = scripts and scripts:FindFirstChild("Game")
        local eggScript = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
        if eggScript then
            local env = getsenv(eggScript)
            if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                env.PlayEggAnimation = function() end
            end
        end
    end)
end

-- =========================================================================
-- 2. TÌM TRỨNG CUSTOM ĐÃ MỞ KHÓA TỐT NHẤT TRÊN ĐẢO
-- =========================================================================

local function getPlot()
    local islandCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Island" })
    if islandCmds and type(islandCmds.Plot) == "function" then
        local ok, plot = pcall(islandCmds.Plot)
        if ok and plot then return plot end
    end
    return nil
end

local function getPlotModel()
    local plot = getPlot()
    if not plot then return nil end
    local ok, m = pcall(function() return plot:GetModel() end)
    if ok and m then return m end

    local plotId = tostring(plot:GetId())
    local things = workspace:FindFirstChild("__THINGS")
    local plots = things and things:FindFirstChild("Plots")
    return plots and plots:FindFirstChild(plotId)
end

local EGG_AREAS = {
    [5] = {
        name = "Egg 5 (Golden Grove)",
        eggName = "Golden Grove Egg",
        displayName = "Golden Grove",
        offset = Vector3.new(201.46, 0.36, -60.86),
        btnId = "GoldenGrove_Egg",
        attrName = "GoldenGrove_Egg",
        unitCost = 15000,
    },
    [4] = {
        name = "Egg 4 (Cider Mill)",
        eggName = "Cider Mill Egg",
        displayName = "Cider Mill",
        offset = Vector3.new(-70.41, 5.72, -300.74),
        btnId = "CiderMill_Egg",
        attrName = "CiderMill_Egg",
        unitCost = 8000,
    },
    [3] = {
        name = "Egg 3 (Hayride Hill)",
        eggName = "Hayride Hill Egg",
        displayName = "Hayride Hill",
        offset = Vector3.new(-198.58, 0.08, -50.60),
        btnId = "HayrideHill_Egg",
        attrName = "HayrideHill_Egg",
        unitCost = 4000,
    },
    [2] = {
        name = "Egg 2 (Apple Orchard)",
        eggName = "Apple Orchard Egg",
        displayName = "Apple Orchard",
        offset = Vector3.new(-138.68, 4.63, 161.97),
        btnId = "AppleOrchard_Egg",
        attrName = "AppleOrchard_Egg",
        unitCost = 1000,
    },
    [1] = {
        name = "Egg 1 (Cocoa Cabin)",
        eggName = "Cocoa Cabin Egg",
        displayName = "Cocoa Cabin",
        offset = Vector3.new(183.04, 3.86, 125.91),
        btnId = "CocoaCabin_Egg",
        attrName = "CocoaCabin_Egg",
        unitCost = 200,
    },
}

function EggHatch.getBestUnlockedEgg()
    local plot = getPlot()
    local plotModel = getPlotModel()
    if not plot or not plotModel then return nil end

    initEggLibs()
    local plotPivot = plotModel:GetPivot()

    -- 1. Tìm CustomEggsCmds.All() từ client module
    local allCustomEggs = nil
    pcall(function()
        if not CustomEggsCmds then
            CustomEggsCmds = safeRequire({ "Library", "Client", "CustomEggsCmds" })
        end
        if CustomEggsCmds and type(CustomEggsCmds.All) == "function" then
            allCustomEggs = CustomEggsCmds.All()
        end
    end)

    local things = workspace:FindFirstChild("__THINGS")
    local customEggsFolder = things and things:FindFirstChild("CustomEggs")

    local activeZone = (TycoonFarm and type(TycoonFarm.getActiveAreaIndex) == "function" and TycoonFarm.getActiveAreaIndex()) or 5

    -- Quét theo thứ tự ưu tiên từ bãi hiện tại (activeZone) trở xuống bãi 1
    for zoneIdx = activeZone, 1, -1 do
        local area = EGG_AREAS[zoneIdx]
        local expectedPos = nil

        local eggAttr = plotModel:GetAttribute(area.attrName)
        if typeof(eggAttr) == "CFrame" then
            expectedPos = eggAttr.Position
        elseif typeof(eggAttr) == "Vector3" then
            expectedPos = eggAttr
        elseif area.offset and plotPivot then
            expectedPos = plotPivot:PointToWorldSpace(area.offset)
        end

        -- A. Quét trong CustomEggsCmds.All()
        if allCustomEggs and expectedPos then
            for uid, eggObj in pairs(allCustomEggs) do
                if type(eggObj) == "table" then
                    local eggId = eggObj._id or ""
                    local eggPos = eggObj._position or (eggObj._model and eggObj._model:GetPivot().Position)
                    if eggPos and (eggPos - expectedPos).Magnitude <= 45 then
                        return {
                            zoneIndex = zoneIdx,
                            eggName = area.eggName,
                            eggBtnId = area.btnId,
                            displayName = area.displayName,
                            eggInstance = eggObj._model,
                            eggUid = eggObj._uid or uid or (eggObj._model and eggObj._model.Name),
                            pos = eggPos,
                        }
                    end
                end
            end
        end

        -- B. Quét trong workspace.__THINGS.CustomEggs
        if customEggsFolder and expectedPos then
            local bestDist = 45
            local foundEgg = nil
            for _, egg in ipairs(customEggsFolder:GetChildren()) do
                local dist = (egg:GetPivot().Position - expectedPos).Magnitude
                if dist <= bestDist then
                    bestDist = dist
                    foundEgg = egg
                end
            end

            if foundEgg then
                return {
                    zoneIndex = zoneIdx,
                    eggName = area.eggName,
                    eggBtnId = area.btnId,
                    displayName = area.displayName,
                    eggInstance = foundEgg,
                    eggUid = foundEgg.Name,
                    pos = foundEgg:GetPivot().Position,
                }
            end
        end
    end

    -- Fallback: Trứng nào gần plot nhất (< 250 studs)
    if customEggsFolder and plotPivot then
        local bestPlotDist = 250
        local closestEgg = nil
        for _, egg in ipairs(customEggsFolder:GetChildren()) do
            local dist = (egg:GetPivot().Position - plotPivot.Position).Magnitude
            if dist <= bestPlotDist then
                bestPlotDist = dist
                closestEgg = egg
            end
        end
        if closestEgg then
            return {
                zoneIndex = 1,
                eggName = "Cocoa Cabin Egg",
                eggBtnId = "CocoaCabin_Egg",
                displayName = "Cocoa Cabin",
                eggInstance = closestEgg,
                eggUid = closestEgg.Name,
                pos = closestEgg:GetPivot().Position,
            }
        end
    end

    return nil
end

-- =========================================================================
-- 3. THỰC THI MỞ TRỨNG TỪ XA VÀ CÂN ĐỐI NGÂN SÁCH TYCOON THÔNG MINH
-- =========================================================================

local EGG_UNIT_COSTS = {
    [1] = 200,
    [2] = 1000,
    [3] = 4000,
    [4] = 8000,
    [5] = 15000,
}

local lastHatchAttempt = 0
local hatchCycleCount = 0
local waitingForButtonId = nil
local waitingForButtonPrice = 0
local zone5EggUnlockedTime = nil

function EggHatch.onButtonBought(btnId)
    if not waitingForButtonId or waitingForButtonId == btnId then
        waitingForButtonId = nil
        waitingForButtonPrice = 0
        hatchCycleCount = 0
    end
end

function EggHatch.hatchBestEggTick(state)
    if not Config.AutoHatchBestEgg then return end

    local now = os.clock()
    if now - lastHatchAttempt < (Config.HatchDelay or 1.0) then return end
    lastHatchAttempt = now

    local coins = Network.currency(K.CURRENCY) or 0
    if coins <= 0 then
        local s = Network.getSave()
        if s then
            local cur = (s.Inventory and s.Inventory.Currency) or s.Currencies or s.Currency
            if type(cur) == "table" then
                for _, v in pairs(cur) do
                    if type(v) == "table" and (v.id == K.CURRENCY or v._id == K.CURRENCY) then
                        coins = tonumber(v._am or v.Amount) or 0
                        break
                    end
                end
            end
        end
    end

    local targetEgg = EggHatch.getBestUnlockedEgg()
    if not targetEgg or not targetEgg.eggUid then return end

    local activeZone = (TycoonFarm and type(TycoonFarm.getActiveAreaIndex) == "function" and TycoonFarm.getActiveAreaIndex()) or 1
    -- Nếu egg tìm được thuộc bãi cũ hơn bãi farm hiện tại -> Không lùi về bãi cũ, ưu tiên đứng bãi mới farm tiền mua egg bãi mới
    if (targetEgg.zoneIndex or 1) < activeZone then
        state.hatchStatus = string.format("Đang farm Bãi %d -> Chờ mua Egg Bãi %d", activeZone, activeZone)
        return
    end

    state.currentEggName = targetEgg.eggName or "Cocoa Cabin Egg"

    -- Đảm bảo nhân vật ở tại phạm vi mở trứng (trong vòng 30 studs) NGAY TỪ ĐẦU
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and targetEgg.pos and (hrp.Position - targetEgg.pos).Magnitude > 30 then
        pcall(function()
            local safePos = targetEgg.pos + Vector3.new(0, 2.5, 6)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            char:PivotTo(CFrame.new(safePos, targetEgg.pos))
            hrp.CFrame = CFrame.new(safePos, targetEgg.pos)
        end)
    end

    local eggCost = EGG_UNIT_COSTS[targetEgg.zoneIndex or 1] or 200
    if coins < eggCost then return end

    -- =====================================================================
    -- CƠ CHẾ CHU KỲ & LOGIC TIẾN TRÌNH BÃI 5 (GOLDEN GROVE):
    -- Giai đoạn 1: Khi vừa mở Bãi 5 -> Mở trứng liên tục trong 3 phút đầu để lấy dàn Pet mạnh gánh dame
    -- Giai đoạn 2: Sau 3 phút -> Ngưng mở trứng hoàn toàn, tích 100% coin mua sạch nút để đạt 100% đảo
    -- Giai đoạn 3: Khi đảo đã đạt 100% -> Chuyển sang Infinite Hatch vĩnh viễn
    -- =====================================================================
    local isFinalEgg = (targetEgg.zoneIndex or 1) >= 5
    local infiniteFinal = false
    local maxCycles = (Config.Economy and Config.Economy.HatchCyclesBeforeButtonCheck) or 3

    if isFinalEgg then
        if not zone5EggUnlockedTime then
            zone5EggUnlockedTime = os.clock()
        end

        local elapsedZone5 = os.clock() - zone5EggUnlockedTime
        local prog = (TycoonFarm and type(TycoonFarm.getTycoonProgress) == "function" and TycoonFarm.getTycoonProgress()) or {}
        local isIsland100 = (prog.completed == true) or ((prog.percent or 0) >= 1) or ((prog.totalButtons or 0) > 0 and (prog.ownedButtons or 0) >= (prog.totalButtons or 0))

        if isIsland100 then
            -- GIAI ĐOẠN 3: Đảo đã hoàn thành 100% -> Infinite Hatch vĩnh viễn
            infiniteFinal = true
            waitingForButtonId = nil
            waitingForButtonPrice = 0
            hatchCycleCount = 0
        elseif elapsedZone5 <= 180 then
            -- GIAI ĐOẠN 1: Trong 3 phút đầu khi vừa mở Bãi 5 -> Mở trứng liên tục kiếm pet mạnh
            infiniteFinal = true
            waitingForButtonId = nil
            waitingForButtonPrice = 0
            hatchCycleCount = 0
        else
            -- GIAI ĐOẠN 2: Sau 3 phút & đảo CHƯA đạt 100% -> TÍCH 100% COIN MUA SẠCH NÚT ĐỂ ĐẠT 100% ĐẢO
            local percentVal = math.floor(((prog.percent or 0) * 100) * 10) / 10
            state.hatchStatus = string.format("Tích coin hoàn thành 100%% đảo (%d/%d nút • %.1f%%)", prog.ownedButtons or 0, prog.totalButtons or 0, percentVal)
            return -- Ngưng mở trứng hoàn toàn để dành 100% coins cho TycoonFarm mua nút!
        end
    else
        -- A. Nếu đang trong trạng thái chờ mua nút sau khi đã mở đủ 3 lần
        if waitingForButtonId then
            local plot = TycoonFarm and TycoonFarm.getPlot and TycoonFarm.getPlot()
            local buttonsState = plot and plot:Save("Buttons") or {}
            local isOwned = false
            if buttonsState[waitingForButtonId] == true then
                isOwned = true
            elseif PTButtons and type(PTButtons.Owned) == "function" and PTButtons.Owned(buttonsState, waitingForButtonId) then
                isOwned = true
            end

            if isOwned then
                waitingForButtonId = nil
                waitingForButtonPrice = 0
                hatchCycleCount = 0
            else
                -- Vẫn chưa mua được -> Kiểm tra nút rẻ nhất / mục tiêu hiện tại
                local nextBtn, btnPrice = nil, 0
                if TycoonFarm and type(TycoonFarm.getNextTargetButton) == "function" then
                    nextBtn, btnPrice = TycoonFarm.getNextTargetButton()
                end
                if not nextBtn and TycoonFarm and type(TycoonFarm.getCheapestAvailableButton) == "function" then
                    nextBtn, btnPrice = TycoonFarm.getCheapestAvailableButton()
                end

                if not nextBtn then
                    -- Hết nút cần mua trên đảo
                    waitingForButtonId = nil
                    waitingForButtonPrice = 0
                    hatchCycleCount = 0
                else
                    waitingForButtonId = nextBtn.Id
                    waitingForButtonPrice = btnPrice or 0
                    local curCoins = Network.currency(K.CURRENCY) or 0
                    state.hatchStatus = string.format("Đã mở 3 lần -> Chờ mua %s (%s / %s)", tostring(waitingForButtonId), Network.shorten(curCoins), Network.shorten(waitingForButtonPrice))
                    return -- NGƯNG MỞ EGG NỮA!
                end
            end
        end

        -- B. Nếu đã mở đủ 3 lần nhưng chưa gán waitingForButtonId
        if hatchCycleCount >= maxCycles then
            local nextBtn, btnPrice = nil, 0
            if TycoonFarm and type(TycoonFarm.getNextTargetButton) == "function" then
                nextBtn, btnPrice = TycoonFarm.getNextTargetButton()
            end
            if not nextBtn and TycoonFarm and type(TycoonFarm.getCheapestAvailableButton) == "function" then
                nextBtn, btnPrice = TycoonFarm.getCheapestAvailableButton()
            end

            if nextBtn and btnPrice and btnPrice > 0 then
                waitingForButtonId = nextBtn.Id
                waitingForButtonPrice = btnPrice
                local curCoins = Network.currency(K.CURRENCY) or 0
                state.hatchStatus = string.format("Đã mở %d lần -> Chờ mua %s (%s / %s)", hatchCycleCount, tostring(nextBtn.Id), Network.shorten(curCoins), Network.shorten(waitingForButtonPrice))
                return -- NGƯNG MỞ EGG NỮA!
            else
                hatchCycleCount = 0
            end
        end
    end

    -- Tính toán số lượng trứng tối đa tài khoản có thể mở mỗi lần
    initEggLibs()
    local accountMaxHatch = 1
    pcall(function()
        if EggCmds and type(EggCmds.GetMaxHatch) == "function" then
            accountMaxHatch = math.clamp(tonumber(EggCmds.GetMaxHatch()) or 1, 1, 99)
        elseif Modules and Modules.G and Modules.G.EggCmds and Network.isfn(Modules.G.EggCmds, "GetMaxHatch") then
            accountMaxHatch = math.clamp(tonumber(Network.gval(Modules.G.EggCmds.GetMaxHatch)) or 1, 1, 99)
        end
    end)

    local allowedHatch = accountMaxHatch

    if infiniteFinal then
        -- Chế độ Infinite Hatch tại Bãi Cuối: Cứ có tiền là mở tối đa, không cần trích lập quỹ nút
        allowedHatch = math.clamp(math.floor(coins / eggCost), 1, accountMaxHatch)
        if (targetEgg.zoneIndex or 1) >= 5 and zone5EggUnlockedTime then
            local elapsedZone5 = os.clock() - zone5EggUnlockedTime
            if elapsedZone5 <= 180 then
                local remSec = math.max(0, math.floor(180 - elapsedZone5))
                state.hatchStatus = string.format("🥚 Bãi 5 (3p đầu còn %ds): Mở trứng (+%d)", remSec, allowedHatch)
            else
                state.hatchStatus = string.format("🥚 Đảo 100%%: Infinite Hatch (+%d)", allowedHatch)
            end
        else
            state.hatchStatus = string.format("🥚 Infinite Hatch: %s (+%d)", targetEgg.displayName or targetEgg.eggName, allowedHatch)
        end
    else
        -- CÂN ĐỐI NGÂN SÁCH TYCOON (DÀNH CHO CÁC BÃI 1-4): MUA NÚT VS MỞ TRỨNG
        local targetBtn, btnPrice, isMilestone = nil, 0, false
        if TycoonFarm and type(TycoonFarm.getNextTargetButton) == "function" then
            targetBtn, btnPrice, isMilestone = TycoonFarm.getNextTargetButton()
        end

        if targetBtn and btnPrice > 0 then
            local hatchBatchCost = eggCost * accountMaxHatch

            -- 1. NÚT MỐC QUAN TRỌNG (Egg hoặc Zone button):
            -- ƯU TIÊN 100% TIỀN: Gom tiền mua nút mốc trước để nhảy vọt kinh tế!
            if isMilestone then
                if coins < btnPrice then
                    -- Chưa đủ tiền mua nút mốc -> Tạm dừng mở trứng để dồn tiền
                    state.hatchStatus = string.format("Dồn tiền mua %s (%s / %s)", tostring(targetBtn.Id or "Nút Mốc"), Network.shorten(coins), Network.shorten(btnPrice))
                    return
                else
                    -- Đã đủ tiền mua nút mốc -> Mua nút trước, chỉ dùng phần tiền dư sau mua để mở trứng
                    local surplus = coins - btnPrice
                    if surplus < eggCost then
                        state.hatchStatus = "Chờ mua nút mốc quan trọng"
                        return
                    end
                    allowedHatch = math.clamp(math.floor(surplus / eggCost), 1, accountMaxHatch)
                end
            -- 2. NÚT THƯỜNG GIÁ RẺ (<= 2 lần tiền mở 1 lượt maxHatch):
            elseif btnPrice <= hatchBatchCost * 2 then
                if coins < btnPrice then
                    state.hatchStatus = string.format("Tiết kiệm mua nút %s (%s)", tostring(targetBtn.Id or "Nút"), Network.shorten(btnPrice))
                    return
                else
                    local surplus = coins - btnPrice
                    if surplus < eggCost then return end
                    allowedHatch = math.clamp(math.floor(surplus / eggCost), 1, accountMaxHatch)
                end
            -- 3. NÚT THƯỜNG GIÁ CAO (Càng về sau nút càng đắt, ví dụ 500k - 20M coins):
            -- Giữ 60% tiền làm quỹ tích lũy, dùng tối đa 40% thặng dư để hatch liên tục
            else
                local reserveRatio = (Config.Economy and Config.Economy.ReserveRatioForExpensive) or 0.6
                local reserve = btnPrice * reserveRatio
                if coins > reserve then
                    local surplus = coins - reserve
                    if surplus < eggCost then return end
                    allowedHatch = math.clamp(math.floor(surplus / eggCost), 1, accountMaxHatch)
                elseif coins >= hatchBatchCost * 3 then
                    -- Nếu chưa đạt reserve nhưng tiền có sẵn gấp 3 lần lượt hatch: Hatch nhỏ giọt 20%
                    local disposable = coins * 0.2
                    allowedHatch = math.clamp(math.floor(disposable / eggCost), 1, accountMaxHatch)
                else
                    state.hatchStatus = string.format("Tích quỹ mua nút đắt (%s / %s)", Network.shorten(coins), Network.shorten(btnPrice))
                    return
                end
            end
        end
    end

    -- Đảm bảo cutscene bị triệt tiêu
    EggHatch.installNoHatchAnimation()

    -- Gọi Remote mở trứng Custom (CustomEggs_Hatch)
    local hatchedThisTick = false
    local okH, resH = Network.netInvoke("CustomEggs_Hatch", targetEgg.eggUid, allowedHatch)
    if okH and (resH == true or type(resH) == "table") then
        state.totalEggsHatched = (state.totalEggsHatched or 0) + allowedHatch
        hatchedThisTick = true
    else
        -- Fallback thử với tên trứng eggName
        if targetEgg.eggName then
            local okName, resName = Network.netInvoke("CustomEggs_Hatch", targetEgg.eggName, allowedHatch)
            if okName and (resName == true or type(resName) == "table") then
                state.totalEggsHatched = (state.totalEggsHatched or 0) + allowedHatch
                hatchedThisTick = true
            end
        end
        -- Fallback với 1 quả nếu không đủ tiền mở full lượt
        if not hatchedThisTick and allowedHatch > 1 then
            local ok1, res1 = Network.netInvoke("CustomEggs_Hatch", targetEgg.eggUid, 1)
            if ok1 and (res1 == true or type(res1) == "table") then
                state.totalEggsHatched = (state.totalEggsHatched or 0) + 1
                hatchedThisTick = true
            elseif targetEgg.eggName then
                local ok1N, res1N = Network.netInvoke("CustomEggs_Hatch", targetEgg.eggName, 1)
                if ok1N and (res1N == true or type(res1N) == "table") then
                    state.totalEggsHatched = (state.totalEggsHatched or 0) + 1
                    hatchedThisTick = true
                end
            end
        end
    end

    -- Cập nhật chu kỳ mở trứng & Kiểm tra Webhook nổ Huge / Titanic
    if hatchedThisTick then
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

        if infiniteFinal then
            -- Muted log để tránh spam console khi treo nhiều acc
        else
            hatchCycleCount = hatchCycleCount + 1
            if hatchCycleCount >= maxCycles then
                local nextBtn, btnPrice = nil, 0
                if TycoonFarm and type(TycoonFarm.getNextTargetButton) == "function" then
                    nextBtn, btnPrice = TycoonFarm.getNextTargetButton()
                end
                if not nextBtn and TycoonFarm and type(TycoonFarm.getCheapestAvailableButton) == "function" then
                    nextBtn, btnPrice = TycoonFarm.getCheapestAvailableButton()
                end

                if nextBtn and btnPrice and btnPrice > 0 then
                    waitingForButtonId = nextBtn.Id
                    waitingForButtonPrice = btnPrice
                    local curCoins = Network.currency(K.CURRENCY) or 0
                    state.hatchStatus = string.format("Đã mở %d lần -> Chờ mua %s (%s / %s)", hatchCycleCount, tostring(nextBtn.Id), Network.shorten(curCoins), Network.shorten(waitingForButtonPrice))
                else
                    hatchCycleCount = 0
                end
            end
        end
    end
end

return EggHatch
