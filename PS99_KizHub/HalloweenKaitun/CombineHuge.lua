-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/CombineHuge.lua
-- Module tự động mở Combine Egg (Recipe Index 6) sự kiện Halloween PS99
-- Tối ưu hóa:
--   - 100% Network Remote thuần túy, loại bỏ hoàn toàn mã click giả lập
--   - Nhắm thẳng mục tiêu Recipe Index 6 (Combine Egg) được xác thực qua Instancing Spy
--   - Đếm nguyên liệu chuẩn xác (Agony & Shard), trừ pet đang Equipped/Locked
--   - Tự động tắt/bật cutscene mở trứng (Egg Animation) chống lag/treo client
--   - Snapshot Inventory bắt Pet mới nở và gửi Discord Webhook khi trúng Huge/Titanic
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CombineHuge = {}

local COMBINE_MACHINE_NAME = "HalloweenPetCraftingMachine"
local COMBINE_MACHINE_ID   = "HalloweenGamesCombine"
local COMBINE_EGG_INDEX    = 6 -- Recipe Index 6 cho Combine Egg (xác nhận từ Instancing Spy)

-- Dependencies truyền từ main.lua qua CombineHuge.init(deps)
local G = nil
local Net = nil
local Config = nil
local K = nil
local Webhook = nil
local inEventFn = nil
local instanceModelFn = nil

local function getConfig()
    if Config and type(Config) == "table" then return Config end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if type(genv.KaitunConfig) == "table" then return genv.KaitunConfig end
    return {}
end

function CombineHuge.init(deps)
    G = deps.Modules and deps.Modules.G or deps.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
end

-- =========================================================================
-- 1. TRUY VẤN DIRECTORY & NGUYÊN LIỆU RECIPE INDEX 6
-- =========================================================================

function CombineHuge.flagValue(name)
    if not (name and G and type(G.FFlags) == "table" and type(G.FFlags.Keys) == "table" and type(G.FFlags.Get) == "function") then
        return nil
    end
    local key = G.FFlags.Keys[name]
    if key == nil then return nil end
    return Net.gval(G.FFlags.Get, key)
end

function CombineHuge.combineDir()
    local all = type(G) == "table" and type(G.Directory) == "table" and rawget(G.Directory, "HalloweenCraftingMachines") or nil
    if all == nil and type(G) == "table" and type(G.Directory) == "table" then
        local ok, v = pcall(function() return G.Directory.HalloweenCraftingMachines end)
        all = ok and v or nil
    end
    if type(all) == "table" then
        local combineId = (K and K.COMBINE_ID) or COMBINE_MACHINE_ID
        if all[combineId] then return all[combineId] end
        if all[COMBINE_MACHINE_ID] then return all[COMBINE_MACHINE_ID] end
        for _, v in pairs(all) do
            if type(v) == "table" and type(v.Recipes) == "table" then
                return v
            end
        end
    end
    return nil
end

function CombineHuge.ingredientNeed(dir, ing)
    if not (ing and type(ing) == "table") then return 1 end
    local amount = tonumber(CombineHuge.flagValue(ing.AmountFFlag)) or tonumber(ing.Amount) or 1
    local need = math.max(1, math.ceil(amount))
    if dir and not ing.NoDiscount and type(dir.IngredientAmount) == "function" then
        local ok, v = pcall(dir.IngredientAmount, nil, need)
        if ok and type(v) == "number" and v == v then
            need = math.max(1, math.ceil(v))
        end
    end
    return need
end

-- Lấy danh sách UID pet đang trang bị để loại trừ không đem craft
local function getEquippedPetUids()
    local equipped = {}
    pcall(function()
        if G and G.PetCmds and Net.isfn(G.PetCmds, "GetEquippedItems") then
            local ok, items = Net.gcall(G.PetCmds.GetEquippedItems)
            if ok and type(items) == "table" then
                for _, it in pairs(items) do
                    if type(it) == "string" then
                        equipped[it] = true
                    elseif type(it) == "table" and type(it.GetUID) == "function" then
                        local okU, uid = pcall(it.GetUID, it)
                        if okU and uid then equipped[uid] = true end
                    end
                end
            end
        end
        local s = Net.getSave()
        if s and type(s.EquippedPets) == "table" then
            for uid, _ in pairs(s.EquippedPets) do
                equipped[uid] = true
            end
        end
    end)
    return equipped
end

-- Đếm số lượng item từ Save.Inventory theo từ khóa tên
local function countItemFromSave(itemNameKeyword)
    local kw = string.lower(tostring(itemNameKeyword or ""))
    local total = 0
    local equipped = getEquippedPetUids()
    pcall(function()
        local s = Net.getSave()
        if not (s and type(s.Inventory) == "table") then return end
        for _, cat in ipairs({ "Pet", "Misc", "Item", "Egg", "Consumable", "Currency" }) do
            if type(s.Inventory[cat]) == "table" then
                for uid, itemData in pairs(s.Inventory[cat]) do
                    if type(itemData) == "table" and type(itemData.id) == "string" then
                        -- Bỏ qua pet đang trang bị hoặc bị khóa
                        local skip = (cat == "Pet" and (equipped[uid] == true or itemData._lk == true))
                        if not skip then
                            local idLower = itemData.id:lower()
                            if idLower == kw or (kw ~= "" and (idLower:find(kw, 1, true) or kw:find(idLower, 1, true))) then
                                total = total + (tonumber(itemData._am) or 1)
                            end
                        end
                    end
                end
            end
        end
    end)
    return total
end
CombineHuge.countItemFromSave = countItemFromSave

-- =========================================================================
-- 2. TIẾN ĐỘ & TRẠNG THÁI HIỂN THỊ (KIZCARD)
-- =========================================================================

function CombineHuge.getCombineProgress()
    local cfg = getConfig()
    local dir = CombineHuge.combineDir()

    local needAgony = (cfg.CombineIngredients and cfg.CombineIngredients.Agony) or 10
    local needShard = (cfg.CombineIngredients and cfg.CombineIngredients.Shard) or 300

    -- Tính chiết khấu thời gian thực nếu Recipe Index 6 có cấu hình trong Directory
    if dir and type(dir.Recipes) == "table" and type(dir.Recipes[COMBINE_EGG_INDEX]) == "table" then
        local r = dir.Recipes[COMBINE_EGG_INDEX]
        if type(r.Ingredients) == "table" then
            for _, ing in ipairs(r.Ingredients) do
                local rawName = ""
                pcall(function()
                    if ing.Item and type(ing.Item.GetId) == "function" then
                        rawName = tostring(ing.Item:GetId() or "")
                    elseif ing.Item and ing.Item.Id then
                        rawName = tostring(ing.Item.Id)
                    elseif ing.Item then
                        rawName = tostring(ing.Item)
                    end
                end)
                rawName = rawName:lower()
                local calculatedNeed = CombineHuge.ingredientNeed(dir, ing)
                if rawName:find("agony") then
                    needAgony = calculatedNeed
                elseif rawName:find("shard") then
                    needShard = calculatedNeed
                end
            end
        end
    end

    local haveAgony = countItemFromSave("Agony")
    local haveShard = countItemFromSave("Shard")
    local isReady = (haveAgony >= needAgony and haveShard >= needShard)

    local statusText = ""
    if isReady then
        statusText = string.format("Sẵn sàng mở Combine Egg! (Agony %d/%d, Shard %d/%d)", haveAgony, needAgony, haveShard, needShard)
    else
        local missing = {}
        local ready = {}
        if haveAgony < needAgony then
            table.insert(missing, string.format("Agony %d/%d (thiếu %d)", haveAgony, needAgony, needAgony - haveAgony))
        else
            table.insert(ready, string.format("Đủ Agony %d/%d", haveAgony, needAgony))
        end
        if haveShard < needShard then
            table.insert(missing, string.format("Shard %d/%d (thiếu %d)", haveShard, needShard, needShard - haveShard))
        else
            table.insert(ready, string.format("Đủ Shard %d/%d", haveShard, needShard))
        end
        if #ready > 0 then
            statusText = string.format("Thiếu %s (%s)", table.concat(missing, ", "), table.concat(ready, ", "))
        else
            statusText = string.format("Thiếu %s", table.concat(missing, ", "))
        end
    end

    local pctAgony = math.clamp(haveAgony / math.max(1, needAgony), 0, 1)
    local pctShard = math.clamp(haveShard / math.max(1, needShard), 0, 1)

    return {
        isReady = isReady,
        statusText = statusText,
        haveAgony = haveAgony,
        needAgony = needAgony,
        missingAgony = math.max(0, needAgony - haveAgony),
        pctAgony = pctAgony,
        haveShard = haveShard,
        needShard = needShard,
        missingShard = math.max(0, needShard - haveShard),
        pctShard = pctShard,
        overallPct = (pctAgony + pctShard) / 2,
    }
end

function CombineHuge.getCombineStatusText()
    local prog = CombineHuge.getCombineProgress()
    return prog and prog.statusText or "Chờ nguyên liệu"
end

-- =========================================================================
-- 3. ĐỊNH VỊ BỆ MÁY & QUẢN LÝ HIỆU ỨNG (ANIMATION)
-- =========================================================================

function CombineHuge.combineMachineStand()
    local mach = nil
    local combineMachineName = (K and K.COMBINE_MACHINE) or COMBINE_MACHINE_NAME

    local function findInMachines(machinesFolder)
        if not machinesFolder then return nil end
        for _, n in ipairs({ combineMachineName, COMBINE_MACHINE_NAME, "Combine-o-Matic", "HalloweenCraftingMachine" }) do
            local found = machinesFolder:FindFirstChild(n)
            if found then return found end
        end
        for _, child in ipairs(machinesFolder:GetChildren()) do
            local nl = child.Name:lower()
            if nl:find("combine") or nl:find("craft") then
                return child
            end
        end
        return nil
    end

    local m = instanceModelFn and instanceModelFn() or nil
    local inter = m and m:FindFirstChild("INTERACT")
    mach = findInMachines(inter and inter:FindFirstChild("Machines"))

    if not mach then
        local things = workspace:FindFirstChild("__THINGS")
        local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = cont and cont:FindFirstChild("Active")
        local inst = act and (act:FindFirstChild((K and K.INSTANCE_ID) or "HalloweenGames") or act:FindFirstChild("HalloweenGames"))
        local iinter = inst and inst:FindFirstChild("INTERACT")
        mach = findInMachines(iinter and iinter:FindFirstChild("Machines"))
    end

    if not mach then
        return Vector3.new(-6721.63, 17.13, -4002.42), nil
    end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then
        return pad.Position + Vector3.new(0, 3, 0), mach
    end
    local cf, _ = mach:GetBoundingBox()
    return cf.Position + Vector3.new(0, 3, 4), mach
end

local function toggleEggAnimation(suppress)
    pcall(function()
        if type(getsenv) ~= "function" then return end
        local ps = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
        local scripts = ps and ps:FindFirstChild("Scripts")
        local gameFolder = scripts and scripts:FindFirstChild("Game")
        local eggScript = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
        if not eggScript then return end
        local env = getsenv(eggScript)
        if type(env) ~= "table" then return end

        if suppress then
            if env._kizOrigPlayEgg == nil and type(env.PlayEggAnimation) == "function" then
                env._kizOrigPlayEgg = env.PlayEggAnimation
                env.PlayEggAnimation = function() end
            end
        else
            if type(env._kizOrigPlayEgg) == "function" then
                env.PlayEggAnimation = env._kizOrigPlayEgg
                env._kizOrigPlayEgg = nil
            end
        end
    end)
end

local function closeAnyMachinePopup()
    pcall(function()
        if G and G.TabController then
            if type(G.TabController.CloseAll) == "function" then pcall(G.TabController.CloseAll) end
            if type(G.TabController.CloseTab) == "function" then pcall(G.TabController.CloseTab) end
        end
    end)
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Enabled and not g.Name:find("KizHub") and not g.Name:find("Chat") and not g.Name:find("TopBar") then
                    local gl = g.Name:lower()
                    if gl:find("combine") or gl:find("craft") or gl:find("matic") then
                        g.Enabled = false
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- 4. SNAPSHOT INVENTORY & GỬI DISCORD WEBHOOK
-- =========================================================================

local function snapshotPetInventory()
    local s = Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    local snap = {}
    if type(pets) == "table" then
        for uid, data in pairs(pets) do
            snap[uid] = type(data) == "table" and (tonumber(data._am) or 1) or 1
        end
    end
    return snap
end

local function checkAndNotifyNewPets(prevSnap)
    if not prevSnap or type(prevSnap) ~= "table" then return end
    local s = Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    local cfg = getConfig()
    local eventsUrl = (cfg.Webhook and cfg.Webhook.EventsUrl) or (Config and Config.Webhook and Config.Webhook.EventsUrl)
    local localName = (LocalPlayer and LocalPlayer.Name) or (Players.LocalPlayer and Players.LocalPlayer.Name) or "Unknown"

    for uid, p in pairs(pets) do
        local prevAm = prevSnap[uid]
        local curAm = type(p) == "table" and (tonumber(p._am) or 1) or 1
        if (prevAm == nil or curAm > prevAm) and type(p) == "table" and type(p.id) == "string" then
            local isShiny = (p.sh == true)
            local variantStr = (p.pt == 2 and "Rainbow ") or (p.pt == 1 and "Golden ") or ""
            local shinyStr = isShiny and "Shiny " or ""
            local rawId = p.id
            local fullPetName = variantStr .. shinyStr .. rawId

            local lowerId = rawId:lower()
            local isHuge = lowerId:find("huge") ~= nil
            local isTitanic = lowerId:find("titanic") ~= nil
            local isGargantuan = lowerId:find("gargantuan") ~= nil

            local tierName = "PET THƯỜNG"
            local color = 0x3b82f6
            local title = "✨ ĐÃ MỞ ĐƯỢC PET MỚI TỪ COMBINE EGG!"

            if isGargantuan then
                tierName = "🌟 GARGANTUAN EXCLUSIVE"
                color = 0xff0055
                title = "🚨 [GARGANTUAN] NỞ ĐƯỢC SIÊU THẦN THÚ GARGANTUAN HALLOWEEN!"
            elseif isTitanic then
                tierName = "🔥 TITANIC EXCLUSIVE"
                color = 0xff4500
                title = "🎉 [TITANIC] ĐÃ NỞ ĐƯỢC TITANIC HALLOWEEN CỰC HIẾM!"
            elseif isHuge then
                tierName = "⭐ HUGE PET"
                color = 0xf59e0b
                title = "💎 [HUGE] ĐÃ NỞ ĐƯỢC HUGE PET TỪ COMBINE EGG!"
            end

            if (isHuge or isTitanic or isGargantuan or cfg.WebhookAllCombinePets == true)
                and Webhook and type(Webhook.sendWebhook) == "function" and eventsUrl and eventsUrl ~= "" then
                local desc = string.format(
                    "Tài khoản: **%s**\nPet nở ra: **%s**\nPhân loại: **%s**\nBiến thể: **%s**\nUID: `%s`\nThời gian: <t:%d:R>",
                    localName,
                    fullPetName,
                    tierName,
                    (isShiny and (variantStr ~= "" and (variantStr .. "Shiny") or "Shiny")) or (variantStr ~= "" and variantStr) or "Normal",
                    tostring(uid),
                    os.time()
                )
                Webhook.sendWebhook(title, desc, color, eventsUrl)
            end
        end
    end
end

-- =========================================================================
-- 5. THỰC THI GỌI MUA TRỰC TIẾP COMBINE EGG (INDEX 6) - ZERO-CLICK PIPELINE
-- Chuỗi gói tin chuẩn xác từ Instancing Spy:
--   1. Machines: Mark Approached -> "HalloweenPetCraftingMachine"
--   2. HalloweenCraftingMachine_GetQueue()
--   3. HalloweenCraftingMachine_StartCraft("HalloweenGamesCombine", 6)
-- =========================================================================

function CombineHuge.checkAndRunCombine(state)
    local cfg = getConfig()
    if cfg.AutoCombine == false or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextCombineAt or 0) then return end

    if G and G.HGForge and Net.isfn(G.HGForge, "CombineMode") and Net.gval(G.HGForge.CombineMode) == false then
        state.combineStatus = "Combine-o-Matic hiện đang đóng"
        state.nextCombineAt = now + 30
        return
    end

    local prog = CombineHuge.getCombineProgress()
    if not (prog and prog.isReady) then
        state.combineStatus = prog and prog.statusText or "Thiếu nguyên liệu Combine Egg"
        state.nextCombineAt = now + (cfg.CombineCooldown or 10)
        return
    end

    -- Bắt đầu hành trình tới máy mở Combine Egg (Recipe Index 6)
    state.excursion = "combine"
    local savedPos = Net.playerPos()
    toggleEggAnimation(true)

    pcall(function()
        local stand, mach = CombineHuge.combineMachineStand()
        if stand then
            Net.teleportTo(stand)
            task.wait(0.8)
        end

        -- Kích hoạt tín hiệu tiếp cận bệ máy
        Net.netFire("Machines: Mark Approached", COMBINE_MACHINE_NAME)
        if mach then
            pcall(function()
                local pad = mach:FindFirstChild("Pad", true)
                local hrp = Net.hrp()
                if pad and hrp and type(firetouchinterest) == "function" then
                    firetouchinterest(hrp, pad, 0)
                    task.wait(0.05)
                    firetouchinterest(hrp, pad, 1)
                end
            end)
        end
        task.wait(0.2)

        -- Đồng bộ hàng đợi máy
        Net.netInvoke("HalloweenCraftingMachine_GetQueue")
        task.wait(0.2)

        -- Bắn Remote StartCraft(COMBINE_MACHINE_ID, 6) liên tục chừng nào còn đủ nguyên liệu
        local maxContinuous = 50
        while maxContinuous > 0 and state.alive do
            maxContinuous = maxContinuous - 1

            local curProg = CombineHuge.getCombineProgress()
            if not (curProg and curProg.isReady) then
                print(string.format("[KizHub Combine] Không còn đủ nguyên liệu (Agony %d/%d, Shard %d/%d). Dừng chuỗi mở.",
                    curProg and curProg.haveAgony or 0, curProg and curProg.needAgony or 10,
                    curProg and curProg.haveShard or 0, curProg and curProg.needShard or 300))
                break
            end

            local preSnap = snapshotPetInventory()
            print(string.format("[KizHub Combine] Bắn Remote StartCraft(%q, %d)...", COMBINE_MACHINE_ID, COMBINE_EGG_INDEX))

            local okS, resS, msgS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", COMBINE_MACHINE_ID, COMBINE_EGG_INDEX)
            if okS and (resS == true or type(resS) == "table") then
                state.combineStatus = "Đã mở Combine Egg!"
                print(string.format("[KizHub Combine] ✔ Mở thành công Combine Egg (Index %d)!", COMBINE_EGG_INDEX))

                -- Chờ server trả Pet từ trứng vào Inventory rồi gửi Webhook
                task.wait(1.4)
                checkAndNotifyNewPets(preSnap)
            else
                state.combineStatus = "Từ chối craft: " .. tostring(msgS or resS)
                print(string.format("[KizHub Combine] ✖ StartCraft(%q, %d) bị từ chối: res=%s, msg=%s", COMBINE_MACHINE_ID, COMBINE_EGG_INDEX, tostring(resS), tostring(msgS)))
                break
            end
        end

        closeAnyMachinePopup()
        task.wait(0.2)
    end)

    toggleEggAnimation(false)

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    closeAnyMachinePopup()

    state.excursion = nil
    state.nextCombineAt = os.clock() + (cfg.CombineCooldown or 10)
end

return CombineHuge
