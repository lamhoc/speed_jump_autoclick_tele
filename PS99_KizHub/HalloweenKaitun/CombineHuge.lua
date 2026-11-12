-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/CombineHuge.lua
-- Module tự động ghép Combine Egg sự kiện Halloween Pet Simulator 99
-- Tích hợp: Quét công thức, Tính toán chiết khấu ForgeSaver, Craft/Open 10,
--           Snapshot Inventory bắt Pet mới nở và Gửi Discord Webhook
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CombineHuge = {}

-- Dependencies
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
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
end

function CombineHuge.flagValue(name)
    if not (name and type(G.FFlags) == "table" and type(G.FFlags.Keys) == "table" and type(G.FFlags.Get) == "function") then
        return nil
    end
    local key = G.FFlags.Keys[name]
    if key == nil then return nil end
    return Net.gval(G.FFlags.Get, key)
end

function CombineHuge.combineDir()
    local all = type(G.Directory) == "table" and rawget(G.Directory, "HalloweenCraftingMachines") or nil
    if all == nil and type(G.Directory) == "table" then
        local ok, v = pcall(function() return G.Directory.HalloweenCraftingMachines end)
        all = ok and v or nil
    end
    if type(all) == "table" then
        if all[K.COMBINE_ID] then return all[K.COMBINE_ID] end
        if all["HalloweenGamesCombine"] then return all["HalloweenGamesCombine"] end
        if all["Combine-o-Matic"] then return all["Combine-o-Matic"] end
        for _, v in pairs(all) do
            if type(v) == "table" and type(v.Recipes) == "table" then
                return v
            end
        end
    end
    return nil
end

function CombineHuge.ingredientNeed(dir, ing)
    local cfg = getConfig()
    local rawId = ""
    if ing.Item then
        pcall(function()
            if type(ing.Item.GetId) == "function" then
                rawId = tostring(ing.Item:GetId() or "")
            elseif ing.Item.Id then
                rawId = tostring(ing.Item.Id)
            else
                rawId = tostring(ing.Item)
            end
        end)
    end

    local isShard = rawId:find("Shard") or (ing.AmountFFlag and tostring(ing.AmountFFlag):find("Shard"))
    local isAgony = rawId:find("Agony") or (ing.AmountFFlag and tostring(ing.AmountFFlag):find("Agony"))

    local targetAgony = (cfg.CombineIngredients and cfg.CombineIngredients.Agony) or 10
    local targetShard = (cfg.CombineIngredients and cfg.CombineIngredients.Shard) or 300

    -- Công thức chuẩn Combine Egg: 10 Masquerade Agony & 300 Shards
    if isShard then
        return targetShard
    elseif isAgony then
        return targetAgony
    end

    local amount = tonumber(CombineHuge.flagValue(ing.AmountFFlag)) or tonumber(ing.Amount) or 1
    local need = math.max(1, math.ceil(amount))
    if not ing.NoDiscount and type(dir.IngredientAmount) == "function" then
        local ok, v = pcall(dir.IngredientAmount, nil, need)
        if ok and type(v) == "number" and v == v then
            need = math.max(1, math.ceil(v))
        end
    end
    return need
end

local function countItemFromSave(itemNameKeyword)
    local kw = string.lower(tostring(itemNameKeyword or ""))
    local total = 0
    pcall(function()
        local s = Net.getSave()
        if not (s and s.Inventory) then return end

        if type(s.Inventory.Pet) == "table" then
            for _, p in pairs(s.Inventory.Pet) do
                if type(p) == "table" and type(p.id) == "string" and string.find(string.lower(p.id), kw, 1, true) then
                    total = total + (tonumber(p._am) or 1)
                end
            end
        end

        if type(s.Inventory.Misc) == "table" then
            for _, m in pairs(s.Inventory.Misc) do
                if type(m) == "table" and type(m.id) == "string" and string.find(string.lower(m.id), kw, 1, true) then
                    total = total + (tonumber(m._am) or 1)
                end
            end
        end

        if type(s.Inventory.Currency) == "table" then
            for _, c in pairs(s.Inventory.Currency) do
                if type(c) == "table" and type(c.id) == "string" and string.find(string.lower(c.id), kw, 1, true) then
                    total = total + (tonumber(c._am) or 1)
                end
            end
        end

        if type(s.Inventory.Item) == "table" then
            for _, it in pairs(s.Inventory.Item) do
                if type(it) == "table" and type(it.id) == "string" and string.find(string.lower(it.id), kw, 1, true) then
                    total = total + (tonumber(it._am) or 1)
                end
            end
        end
    end)
    return total
end

function CombineHuge.countItemFromSave(itemNameKeyword)
    return countItemFromSave(itemNameKeyword)
end

function CombineHuge.ingredientHave(dir, ing)
    local okC, have = Net.gcall(function()
        local item = ing.Item:Clone()
        local n = item:CountAny()
        if dir and dir.AnyVariantInputs and item:IsA("Pet") then
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
    end)
    local val = (okC and tonumber(have)) or 0
    if val <= 0 and ing and ing.Item then
        local rawId = ""
        pcall(function()
            if type(ing.Item.GetId) == "function" then
                rawId = tostring(ing.Item:GetId() or "")
            elseif ing.Item.Id then
                rawId = tostring(ing.Item.Id)
            else
                rawId = tostring(ing.Item)
            end
        end)
        if rawId:find("Agony") then
            val = countItemFromSave("Agony")
        elseif rawId:find("Shard") then
            val = countItemFromSave("Shard")
        end
    end
    return val
end

function CombineHuge.combineRecipes()
    local dir = CombineHuge.combineDir()
    local out = {}
    if not dir or type(dir.Recipes) ~= "table" then
        return out, dir
    end

    for i, r in ipairs(dir.Recipes) do
        if type(r) == "table" and r.Result and type(r.Ingredients) == "table" and r.Hidden ~= true then
            local name = tostring(Net.gval(function() return r.Result:GetId() end) or ("Recipe " .. i))
            local open = r.EnabledFFlag == nil or CombineHuge.flagValue(r.EnabledFFlag) ~= false
            local ready = true
            local missing = {}
            local summary = {}

            for _, ing in ipairs(r.Ingredients) do
                local need = CombineHuge.ingredientNeed(dir, ing)
                local have = CombineHuge.ingredientHave(dir, ing)
                local rawName = tostring(Net.gval(function() return ing.Item:GetId() end) or "?")
                
                -- Rút gọn tên nguyên liệu để hiển thị gọn đẹp trên UI
                local ingName = rawName
                if ingName:find("Shard") then
                    ingName = "Shard"
                elseif ingName:find("Agony") then
                    ingName = "Agony"
                else
                    ingName = ingName:gsub("Halloween ", ""):gsub("Masquerade ", ""):gsub("HalloweenGames", "")
                end

                local itemProgress = string.format("%s %d/%d", ingName, have, need)
                table.insert(summary, itemProgress)
                if have < need then
                    ready = false
                    table.insert(missing, itemProgress)
                end
            end

            out[#out + 1] = {
                index = i,
                name = name,
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

-- Lấy cấu trúc chi tiết nguyên liệu và tiến độ ghép Combine Egg
function CombineHuge.getCombineProgress()
    local cfg = getConfig()
    local targetAgony = (cfg.CombineIngredients and cfg.CombineIngredients.Agony) or 10
    local targetShard = (cfg.CombineIngredients and cfg.CombineIngredients.Shard) or 300

    -- 1. Quét số lượng từ Save làm baseline
    local haveAgony = countItemFromSave("Agony")
    local haveShard = countItemFromSave("Shard")

    -- 2. Nếu có công thức máy game, đồng bộ theo công thức
    local recipes, dir = CombineHuge.combineRecipes()
    if dir and type(recipes) == "table" and #recipes > 0 then
        local target = nil
        for _, r in ipairs(recipes) do
            if r.index == 1 or r.name:lower():find("combine") or r.name:lower():find("egg") then
                target = r
                break
            end
        end
        if not target and #recipes > 0 then target = recipes[1] end

        if target and target.recipe and type(target.recipe.Ingredients) == "table" then
            for _, ing in ipairs(target.recipe.Ingredients) do
                local need = CombineHuge.ingredientNeed(dir, ing)
                local have = CombineHuge.ingredientHave(dir, ing)
                local rawId = ""
                pcall(function()
                    if type(ing.Item.GetId) == "function" then rawId = tostring(ing.Item:GetId() or "") end
                end)
                if rawId:find("Agony") then
                    targetAgony = need
                    if have > 0 or haveAgony == 0 then haveAgony = have end
                elseif rawId:find("Shard") then
                    targetShard = need
                    if have > 0 or haveShard == 0 then haveShard = have end
                end
            end
        end
    end

    -- 3. Kiểm tra xem có mẻ đang ghép trong hàng đợi không
    local craftingRem = nil
    pcall(function()
        local q = CombineHuge.activeQueues()
        for _, item in pairs(q or {}) do
            if type(item) == "table" then
                local rem = tonumber(item.Remaining) or tonumber(item.TimeLeft) or 0
                if rem > 0 then
                    craftingRem = math.floor(rem)
                    break
                end
            end
        end
    end)

    local missingAgony = math.max(0, targetAgony - haveAgony)
    local missingShard = math.max(0, targetShard - haveShard)
    local isReady = (missingAgony == 0 and missingShard == 0)

    local statusText = ""
    if craftingRem then
        statusText = string.format("Đang ghép (%ds)", craftingRem)
    elseif isReady then
        statusText = string.format("Sẵn sàng mở! (Agony %d/%d, Shard %d/%d)", haveAgony, targetAgony, haveShard, targetShard)
    else
        local missList = {}
        if missingAgony > 0 then
            table.insert(missList, string.format("Agony %d/%d (thiếu %d)", haveAgony, targetAgony, missingAgony))
        end
        if missingShard > 0 then
            table.insert(missList, string.format("Shard %d/%d (thiếu %d)", haveShard, targetShard, missingShard))
        end

        local readyList = {}
        if missingAgony == 0 then
            table.insert(readyList, string.format("Đủ Agony %d/%d", haveAgony, targetAgony))
        end
        if missingShard == 0 then
            table.insert(readyList, string.format("Đủ Shard %d/%d", haveShard, targetShard))
        end

        if #readyList > 0 then
            statusText = string.format("Thiếu %s (%s)", table.concat(missList, ", "), table.concat(readyList, ", "))
        else
            statusText = string.format("Thiếu %s", table.concat(missList, ", "))
        end
    end

    local pctAgony = math.clamp(haveAgony / math.max(1, targetAgony), 0, 1)
    local pctShard = math.clamp(haveShard / math.max(1, targetShard), 0, 1)
    local overallPct = (pctAgony + pctShard) / 2

    return {
        isReady = isReady,
        craftingRem = craftingRem,
        statusText = statusText,
        haveAgony = haveAgony,
        needAgony = targetAgony,
        missingAgony = missingAgony,
        pctAgony = pctAgony,
        haveShard = haveShard,
        needShard = targetShard,
        missingShard = missingShard,
        pctShard = pctShard,
        overallPct = overallPct,
    }
end

-- Lấy văn bản chi tiết nguyên liệu còn thiếu cho GUI
function CombineHuge.getCombineStatusText()
    local prog = CombineHuge.getCombineProgress()
    return prog and prog.statusText or "Chờ nguyên liệu"
end

function CombineHuge.combineMachineStand()
    local mach = nil
    local function findInMachines(machinesFolder)
        if not machinesFolder then return nil end
        for _, n in ipairs({ K.COMBINE_MACHINE, "Combine-o-Matic", "HalloweenPetCraftingMachine", "HalloweenCraftingMachine", "CombineMachine" }) do
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
        local inst = act and act:FindFirstChild(K.INSTANCE_ID)
        local iinter = inst and inst:FindFirstChild("INTERACT")
        mach = findInMachines(iinter and iinter:FindFirstChild("Machines"))
    end
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then
        return pad.Position + Vector3.new(0, 3, 0)
    end
    return mach:GetPivot().Position + Vector3.new(0, 3, 6)
end

function CombineHuge.activeQueues()
    local okQ, queue = Net.netInvoke("HalloweenCraftingMachine_GetQueue")
    if okQ and type(queue) == "table" then
        return queue
    end

    local s = Net.getSave()
    if type(s) == "table" then
        if type(s.HalloweenCraftingQueue) == "table" then
            return s.HalloweenCraftingQueue
        end
        local iv = s.InstanceVars and s.InstanceVars[K.INSTANCE_ID]
        local cm = iv and iv.HalloweenCraftingMachines
        local m = cm and cm[K.COMBINE_ID]
        if type(m) == "table" and type(m.Queue) == "table" then
            return m.Queue
        end
    end
    return {}
end

-- =========================================================================
-- Snapshot & Webhook thông báo kết quả nở Combine Egg
-- =========================================================================
local function snapshotPetInventory()
    local s = Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    local snap = {}
    if type(pets) == "table" then
        for uid, _ in pairs(pets) do
            snap[uid] = true
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
        if not prevSnap[uid] and type(p) == "table" and type(p.id) == "string" then
            local isShiny = (p.sh == true)
            local variantStr = (p.pt == 2 and "Rainbow ") or (p.pt == 1 and "Golden ") or ""
            local shinyStr = isShiny and "Shiny " or ""
            local fullPetName = shinyStr .. variantStr .. p.id

            local isGargantuan = (p.id:find("Gargantuan ") ~= nil)
            local isTitanic = (p.id:find("Titanic ") ~= nil)
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter")) ~= nil

            local title = "🐾 [COMBINE EGG NỞ THÀNH CÔNG] 🐾"
            local color = 0x00E676
            local tierName = "Exclusive Pet"

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

            if Webhook and type(Webhook.sendWebhook) == "function" and eventsUrl and eventsUrl ~= "" then
                local desc = string.format(
                    "Tài khoản: **%s**\nPet nhận được: **%s**\nPhân loại: **%s**\nBiến thể: **%s**\nUID: `%s`\nThời gian: <t:%d:R>",
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
-- Vòng lặp kiểm tra và tự động mở Combine Egg
-- =========================================================================
function CombineHuge.checkAndRunCombine(state)
    local cfg = getConfig()
    if not cfg.AutoCombine or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextCombineAt or 0) then return end

    local recipes, dir = CombineHuge.combineRecipes()
    if not dir or #recipes == 0 then
        state.combineStatus = "Chưa nạp công thức máy"
        state.nextCombineAt = now + (cfg.CombineCooldown or 30)
        return
    end

    local q = CombineHuge.activeQueues()
    local readyClaims, queued = {}, {}
    for k, item in pairs(q) do
        if type(item) == "table" then
            local uid = item.UID or (type(k) == "string" and k) or nil
            local recIdx = item.RecipeIndex or (item.Recipe and item.Recipe.Index)
            local rem = tonumber(item.Remaining) or tonumber(item.TimeLeft) or 0
            if recIdx then
                if rem <= 0 and uid then
                    table.insert(readyClaims, { UID = uid, RecipeIndex = recIdx })
                else
                    queued[recIdx] = item
                end
            end
        end
    end

    local targetRecipeName = cfg.TargetCombineRecipe or "Combine Egg"
    local starts = {}
    local waiting = {}

    for i = #recipes, 1, -1 do
        local r = recipes[i]
        local isTarget = false
        if targetRecipeName == nil or targetRecipeName == "" then
            isTarget = true
        elseif r.name == targetRecipeName then
            isTarget = true
        elseif targetRecipeName == "Combine Egg" and (r.index == 1 or r.name:lower():find("combine") or r.name:lower():find("egg")) then
            isTarget = true
        elseif r.name:lower():find("combine") or r.name:lower():find("egg") then
            isTarget = true
        elseif #recipes == 1 then
            isTarget = true
        end

        if isTarget and r.open and not queued[r.index] then
            if r.ready then
                table.insert(starts, r)
            else
                local missText = (r.missing and r.missing ~= "") and r.missing or r.summary
                table.insert(waiting, missText)
            end
        elseif isTarget and queued[r.index] and (tonumber(queued[r.index].Remaining) or 0) > 0 then
            local rem = tonumber(queued[r.index].Remaining) or 0
            state.combineStatus = string.format("Đang ghép (%ds)", math.floor(rem))
        end
    end

    if #readyClaims == 0 and #starts == 0 then
        if #waiting > 0 then
            state.combineStatus = "Thiếu: " .. waiting[1]
        else
            state.combineStatus = CombineHuge.getCombineStatusText()
        end
        state.nextCombineAt = now + (cfg.CombineCooldown or 15)
        return
    end

    state.excursion = "combine"
    local savedPos = Net.playerPos()

    pcall(function()
        local stand = CombineHuge.combineMachineStand()
        if stand then
            Net.teleportTo(stand)
            task.wait(0.8)
        end

        -- 1. Claim các mẻ đã ghép xong nếu có queue
        for _, claim in ipairs(readyClaims) do
            local preSnap = snapshotPetInventory()
            local okC, resC = Net.netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            if okC and resC then
                local recName = targetRecipeName
                for _, r in ipairs(recipes) do
                    if r.index == claim.RecipeIndex then
                        recName = r.name
                    end
                end
                state.combineStatus = "Đã nhận " .. recName
                task.wait(0.5)
                checkAndNotifyNewPets(preSnap)
            end
            task.wait(0.4)
        end

        -- 2. Bắt đầu ghép: Mở Combine Egg (Hỗ trợ Open 10 và Craft liên tục cho tới khi hết nguyên liệu)
        for _, r in ipairs(starts) do
            local maxTries = 50
            while maxTries > 0 do
                maxTries = maxTries - 1
                local again = CombineHuge.combineRecipes()
                local fresh = nil
                for _, x in ipairs(again) do
                    if x.index == r.index then fresh = x break end
                end
                if not (fresh and fresh.ready) then
                    break -- Đã hết nguyên liệu
                end

                local preSnap = snapshotPetInventory()
                local crafted = false

                -- Thử gọi Open 10 trước nếu đủ nguyên liệu
                local ok10, res10 = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index, 10)
                if ok10 and (res10 == true or type(res10) == "table") then
                    crafted = true
                    state.combineStatus = "Đã mở 10 " .. r.name
                else
                    -- Fallback gọi Craft 1
                    local okS, resS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index, 1)
                    if not okS or resS == false then
                        okS, resS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index)
                    end
                    if okS and (resS == true or type(resS) == "table") then
                        crafted = true
                        state.combineStatus = "Đã mở 1 " .. r.name
                    else
                        state.combineStatus = "Ghép dừng: " .. tostring(resS or res10)
                        break
                    end
                end

                if crafted then
                    task.wait(0.6) -- Chờ server sinh pet vào Inventory
                    checkAndNotifyNewPets(preSnap)
                end
                task.wait(0.4)
            end
        end
    end)

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (cfg.CombineCooldown or 30)
end

return CombineHuge
