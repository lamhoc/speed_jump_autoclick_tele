-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/CombineHuge.lua
-- Module tự động ghép Combine Egg (Recipe Index 6) sự kiện Halloween PS99
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CombineHuge = {}

local COMBINE_MACHINE_NAME = "HalloweenPetCraftingMachine"
local COMBINE_MACHINE_ID = "HalloweenGamesCombine"
local COMBINE_EGG_INDEX = 6 -- Xác nhận từ Instancing Spy: StartCraft("HalloweenGamesCombine", 6)

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
-- 1. XỬ LÝ DỮ LIỆU & DIRECTORY
-- =========================================================================

function CombineHuge.flagValue(name)
    if not (name and G and type(G.FFlags) == "table" and type(G.FFlags.Keys) == "table" and type(G.FFlags.Get) == "function") then
        return nil
    end
    local key = G.FFlags.Keys[name]
    if key == nil then return nil end
    return Net.gval(G.FFlags.Get, key)
end

local function resolveItemId(it, fallback)
    if it == nil then return fallback or "?" end
    local res = nil
    pcall(function()
        if type(it) == "table" then
            if type(it.GetId) == "function" then
                res = it:GetId()
            elseif it.Id then
                res = tostring(it.Id)
            elseif it._id then
                res = tostring(it._id)
            elseif it.Name then
                res = tostring(it.Name)
            elseif it.Item then
                res = resolveItemId(it.Item)
            end
        elseif type(it) == "string" then
            res = it
        end
    end)
    return res or fallback or tostring(it)
end
CombineHuge.resolveItemId = resolveItemId

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

-- Lấy danh sách UID pet đang trang bị để tránh đếm nhầm
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
    if need <= 1 then
        local cfg = getConfig()
        local rawId = resolveItemId(ing.Item, ""):lower()
        if rawId:find("shard") then
            need = (cfg.CombineIngredients and cfg.CombineIngredients.Shard) or 300
        elseif rawId:find("agony") then
            need = (cfg.CombineIngredients and cfg.CombineIngredients.Agony) or 10
        end
    end
    return need
end

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

function CombineHuge.ingredientHave(dir, ing)
    if not (ing and ing.Item) then return 0 end
    local rawId = resolveItemId(ing.Item, "")
    local isPet = false
    pcall(function()
        isPet = Net.isfn(ing.Item, "IsA") and ing.Item:IsA("Pet")
    end)

    -- Nếu là Pet, ưu tiên đếm từ Save để loại trừ chính xác pet đang Equipped / Locked
    if isPet or rawId:lower():find("agony") then
        local saveCount = countItemFromSave(rawId)
        if saveCount > 0 then return saveCount end
        if rawId:lower():find("agony") then
            return countItemFromSave("agony")
        end
    end

    local okC, have = Net.gcall(function()
        if type(ing.Item.Clone) == "function" and type(ing.Item.CountAny) == "function" then
            local item = ing.Item:Clone()
            local n = item:CountAny()
            if dir and dir.AnyVariantInputs and isPet then
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
        elseif type(ing.Item.CountAny) == "function" then
            return ing.Item:CountAny()
        end
        return 0
    end)

    local n = (okC and tonumber(have)) or 0
    if n <= 0 then
        n = countItemFromSave(rawId)
        if n <= 0 and rawId:lower():find("shard") then
            n = countItemFromSave("shard")
        end
    end
    return n
end

function CombineHuge.combineRecipes()
    local dir = CombineHuge.combineDir()
    local out = {}
    if not dir or type(dir.Recipes) ~= "table" then
        return out, dir
    end

    for i, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result and type(r.Ingredients) == "table" then
            local name = resolveItemId(r.Result, (i == COMBINE_EGG_INDEX and "Combine Egg") or ("Recipe " .. i))
            local lowerName = name:lower()
            local isCombineEgg = (i == COMBINE_EGG_INDEX) or lowerName:find("combine") ~= nil or lowerName:find("egg") ~= nil
            local open = (r.Hidden ~= true or isCombineEgg) and (r.EnabledFFlag == nil or CombineHuge.flagValue(r.EnabledFFlag) ~= false)

            local ready = true
            local missing = {}
            local summary = {}

            for _, ing in ipairs(r.Ingredients) do
                local need = CombineHuge.ingredientNeed(dir, ing)
                local have = CombineHuge.ingredientHave(dir, ing)
                local ingName = resolveItemId(ing.Item, "?")

                local displayName = ingName
                if displayName:find("Shard") then
                    displayName = "Shard"
                elseif displayName:find("Agony") then
                    displayName = "Agony"
                else
                    displayName = displayName:gsub("Halloween ", ""):gsub("Masquerade ", ""):gsub("HalloweenGames", "")
                end

                local itemProgress = string.format("%s %d/%d", displayName, have, need)
                table.insert(summary, itemProgress)
                if have < need then
                    ready = false
                    table.insert(missing, itemProgress)
                end
            end

            out[#out + 1] = {
                index = i,
                name = name,
                isCombineEgg = isCombineEgg,
                open = open,
                ready = ready,
                recipe = r,
                missing = table.concat(missing, ", "),
                summary = table.concat(summary, ", "),
                duration = tonumber(CombineHuge.flagValue(r.DurationFFlag)) or tonumber(r.Duration)
            }
        end
    end
    return out, dir
end

-- =========================================================================
-- 2. TIẾN ĐỘ HIỂN THỊ TRÊN DASHBOARD GUI (KIZCARD)
-- =========================================================================

function CombineHuge.getCombineProgress()
    local cfg = getConfig()
    local recipes, dir = CombineHuge.combineRecipes()

    local eggRecipe = nil
    for _, r in ipairs(recipes) do
        if r.index == COMBINE_EGG_INDEX then
            eggRecipe = r
            break
        end
    end
    if not eggRecipe then
        for _, r in ipairs(recipes) do
            if r.isCombineEgg then
                eggRecipe = r
                break
            end
        end
    end

    local haveAgony = 0
    local needAgony = (cfg.CombineIngredients and cfg.CombineIngredients.Agony) or 10
    local haveShard = 0
    local needShard = (cfg.CombineIngredients and cfg.CombineIngredients.Shard) or 300
    local isReady = false
    local missingList = {}
    local readyList = {}

    if eggRecipe and eggRecipe.recipe and type(eggRecipe.recipe.Ingredients) == "table" then
        isReady = eggRecipe.ready
        for _, ing in ipairs(eggRecipe.recipe.Ingredients) do
            local need = CombineHuge.ingredientNeed(dir, ing)
            local have = CombineHuge.ingredientHave(dir, ing)
            local rawId = resolveItemId(ing.Item, ""):lower()
            if rawId:find("agony") then
                haveAgony = have
                needAgony = need
            elseif rawId:find("shard") then
                haveShard = have
                needShard = need
            end
            if have < need then
                table.insert(missingList, string.format("%s %d/%d (thiếu %d)", resolveItemId(ing.Item, "?"), have, need, need - have))
            else
                table.insert(readyList, string.format("Đủ %s %d/%d", resolveItemId(ing.Item, "?"), have, need))
            end
        end
    else
        haveAgony = countItemFromSave("Agony")
        haveShard = countItemFromSave("Shard")
        isReady = (haveAgony >= needAgony and haveShard >= needShard)
        if haveAgony < needAgony then
            table.insert(missingList, string.format("Agony %d/%d (thiếu %d)", haveAgony, needAgony, needAgony - haveAgony))
        else
            table.insert(readyList, string.format("Đủ Agony %d/%d", haveAgony, needAgony))
        end
        if haveShard < needShard then
            table.insert(missingList, string.format("Shard %d/%d (thiếu %d)", haveShard, needShard, needShard - haveShard))
        else
            table.insert(readyList, string.format("Đủ Shard %d/%d", haveShard, needShard))
        end
    end

    local statusText = ""
    if isReady then
        statusText = string.format("Sẵn sàng mở Combine Egg! (Agony %d/%d, Shard %d/%d)", haveAgony, needAgony, haveShard, needShard)
    elseif #readyList > 0 then
        statusText = string.format("Thiếu %s (%s)", table.concat(missingList, ", "), table.concat(readyList, ", "))
    else
        statusText = string.format("Thiếu %s", table.concat(missingList, ", "))
    end

    local pctAgony = math.clamp(haveAgony / math.max(1, needAgony), 0, 1)
    local pctShard = math.clamp(haveShard / math.max(1, needShard), 0, 1)

    return {
        isReady = isReady,
        eggRecipe = eggRecipe,
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
-- 3. ĐỊNH VỊ BỆ MÁY & CHẶN ANIMATION MỞ TRỨNG
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

function CombineHuge.activeQueues()
    local okQ, queue = Net.netInvoke("HalloweenCraftingMachine_GetQueue")
    if okQ and type(queue) == "table" then
        return queue
    end
    return {}
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
-- 4. SNAPSHOT INVENTORY & GỬI DISCORD WEBHOOK KHI MỞ COMBINE EGG
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
    local localName = (LocalPlayer and LocalPlayer.Name) or "Unknown"

    for uid, p in pairs(pets) do
        local curAm = type(p) == "table" and (tonumber(p._am) or 1) or 1
        local prevAm = prevSnap[uid]
        if (prevAm == nil or curAm > prevAm) and type(p) == "table" and type(p.id) == "string" then
            local isShiny = (p.sh == true)
            local variantStr = (p.pt == 2 and "Rainbow ") or (p.pt == 1 and "Golden ") or ""
            local shinyStr = isShiny and "Shiny " or ""
            local fullPetName = shinyStr .. variantStr .. p.id

            local isGargantuan = (p.id:find("Gargantuan ") ~= nil)
            local isTitanic = (p.id:find("Titanic ") ~= nil)
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter")) ~= nil

            local title = "🥚 [COMBINE EGG MỞ THÀNH CÔNG] 🥚"
            local color = 0x00E676
            local tierName = "Event Pet"

            if isGargantuan then
                title = "💥 [GARGANTUAN NỞ TỪ COMBINE EGG!] 💥"
                color = 0xFF0055
                tierName = "Gargantuan"
            elseif isTitanic then
                title = "🌟 [TITANIC NỞ TỪ COMBINE EGG!] 🌟"
                color = 0xFFD700
                tierName = "Titanic"
            elseif isHuge then
                title = "👑 [HUGE NỞ TỪ COMBINE EGG!] 👑"
                color = 0x9B59B6
                tierName = "Huge"
            end

            print(string.format("[KizHub Combine] %s: %s (UID: %s)", title, fullPetName, tostring(uid)))

            -- Chỉ gửi Webhook nếu là Huge / Titanic / Gargantuan (hoặc cấu hình bật gửi tất cả)
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
-- 5. THỰC THI CRAFT & MỞ NGAY COMBINE EGG (INDEX 6)
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

    local recipes, dir = CombineHuge.combineRecipes()
    local targetRecipe = nil

    -- Ưu tiên lấy đúng Recipe Index 6 (Combine Egg)
    for _, r in ipairs(recipes) do
        if r.index == COMBINE_EGG_INDEX then
            targetRecipe = r
            break
        end
    end
    if not targetRecipe then
        for _, r in ipairs(recipes) do
            if r.isCombineEgg then
                targetRecipe = r
                break
            end
        end
    end

    local targetIndex = targetRecipe and targetRecipe.index or COMBINE_EGG_INDEX
    local targetName = targetRecipe and targetRecipe.name or "Combine Egg"
    local dirId = (dir and dir._id) or (K and K.COMBINE_ID) or COMBINE_MACHINE_ID

    -- Kiểm tra đã đủ nguyên liệu chưa
    local isReady = false
    if targetRecipe then
        isReady = targetRecipe.ready
    else
        local prog = CombineHuge.getCombineProgress()
        isReady = prog and prog.isReady == true
    end

    if not isReady then
        state.combineStatus = (targetRecipe and ("Thiếu " .. targetRecipe.missing)) or CombineHuge.getCombineStatusText()
        state.nextCombineAt = now + (cfg.CombineCooldown or 10)
        return
    end

    -- Bắt đầu di chuyển tới máy để mở trứng Combine Egg
    state.excursion = "combine"
    local savedPos = Net.playerPos()
    toggleEggAnimation(true)

    pcall(function()
        local stand, mach = CombineHuge.combineMachineStand()
        if stand then
            Net.teleportTo(stand)
            task.wait(0.8)
        end

        -- Gửi đúng trình tự kích hoạt máy như Client thật của game
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
        Net.netInvoke("HalloweenCraftingMachine_GetQueue")
        task.wait(0.2)

        -- Lặp craft & mở ngay liên tục chừng nào còn đủ nguyên liệu
        local maxContinuous = 50
        while maxContinuous > 0 and state.alive do
            maxContinuous = maxContinuous - 1

            -- Kiểm tra lại nguyên liệu thời gian thực trước mỗi lượt bấm
            local freshRecipes = CombineHuge.combineRecipes()
            local stillReady = false
            for _, fr in ipairs(freshRecipes) do
                if fr.index == targetIndex then
                    stillReady = fr.ready
                    break
                end
            end
            if #freshRecipes == 0 then
                local prog = CombineHuge.getCombineProgress()
                stillReady = prog and prog.isReady == true
            end

            if not stillReady then
                break
            end

            local preSnap = snapshotPetInventory()
            print(string.format("[KizHub Combine] Gọi StartCraft(%q, %d)...", dirId, targetIndex))

            local okS, resS, msgS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dirId, targetIndex)
            if okS and (resS == true or type(resS) == "table") then
                state.combineStatus = string.format("Đã mở %s!", targetName)
                print(string.format("[KizHub Combine] ✔ Mở thành công %s (Index %d)!", targetName, targetIndex))

                -- Chờ server trả pet từ trứng vào Inventory rồi quét Webhook
                task.wait(1.4)
                checkAndNotifyNewPets(preSnap)
            else
                state.combineStatus = "Từ chối craft: " .. tostring(msgS or resS)
                print(string.format("[KizHub Combine] ✖ StartCraft(%q, %d) bị từ chối: res=%s, msg=%s", dirId, targetIndex, tostring(resS), tostring(msgS)))
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