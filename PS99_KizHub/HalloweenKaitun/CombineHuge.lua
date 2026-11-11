-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/CombineHuge.lua
-- Module tự động ghép Huge Bat Hoodie Bunny sự kiện Halloween
-- Tích hợp: Quét công thức, Tính toán chiết khấu ForgeSaver, Claim và Bắt đầu ghép
-- =========================================================================

local CombineHuge = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local K = nil
local inEventFn = nil
local instanceModelFn = nil

function CombineHuge.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
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
    return type(all) == "table" and all[K.COMBINE_ID] or nil
end

function CombineHuge.ingredientNeed(dir, ing)
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

function CombineHuge.ingredientHave(dir, ing)
    local okC, have = Net.gcall(function()
        local item = ing.Item:Clone()
        local n = item:CountAny()
        if dir.AnyVariantInputs and item:IsA("Pet") then
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
    return okC and tonumber(have) or 0
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
            local ready, missing = true, {}

            for _, ing in ipairs(r.Ingredients) do
                local need = CombineHuge.ingredientNeed(dir, ing)
                local have = CombineHuge.ingredientHave(dir, ing)
                if have < need then
                    ready = false
                    local ingName = tostring(Net.gval(function() return ing.Item:GetId() end) or "?"):gsub("Halloween ", ""):gsub("Masquerade ", "")
                    missing[#missing + 1] = string.format("%s %d/%d", ingName, have, need)
                end
            end

            out[#out + 1] = {
                index = i,
                name = name,
                open = open,
                ready = ready,
                missing = table.concat(missing, ", "),
                duration = tonumber(CombineHuge.flagValue(r.DurationFFlag)) or tonumber(r.Duration)
            }
        end
    end
    return out, dir
end

function CombineHuge.combineMachineStand()
    local m = instanceModelFn and instanceModelFn() or nil
    local inter = m and m:FindFirstChild("INTERACT")
    local machines = inter and inter:FindFirstChild("Machines")
    local mach = machines and machines:FindFirstChild(K.COMBINE_MACHINE)
    if not mach then
        local things = workspace:FindFirstChild("__THINGS")
        local cont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = cont and cont:FindFirstChild("Active")
        local inst = act and act:FindFirstChild(K.INSTANCE_ID)
        local iinter = inst and inst:FindFirstChild("INTERACT")
        local imachines = iinter and iinter:FindFirstChild("Machines")
        mach = imachines and imachines:FindFirstChild(K.COMBINE_MACHINE)
    end
    if not mach then return nil end
    local pad = mach:FindFirstChild("Pad", true)
    if pad and pad:IsA("BasePart") then
        return pad.Position + Vector3.new(0, 3, 0)
    end
    return mach:GetPivot().Position + Vector3.new(0, 3, 6)
end

function CombineHuge.activeQueues()
    -- 1. Ưu tiên gọi Remote mạng
    local okQ, queue = Net.netInvoke("HalloweenCraftingMachine_GetQueue")
    if okQ and type(queue) == "table" then
        return queue
    end

    -- 2. Đọc từ s.HalloweenCraftingQueue trong Save.Get()
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

function CombineHuge.checkAndRunCombine(state)
    if not Config.AutoCombine or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextCombineAt or 0) then return end

    local recipes, dir = CombineHuge.combineRecipes()
    if not dir or #recipes == 0 then return end

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

    local targetRecipeName = Config.TargetCombineRecipe or "Huge Bat Hoodie Bunny"
    local starts = {}
    local waiting = {}

    for i = #recipes, 1, -1 do
        local r = recipes[i]
        local isTarget = (r.name == targetRecipeName) or (targetRecipeName == "" or targetRecipeName == nil)
        if isTarget and r.open and not queued[r.index] then
            if r.ready then
                table.insert(starts, r)
            else
                table.insert(waiting, r.missing)
            end
        elseif isTarget and queued[r.index] and (tonumber(queued[r.index].Remaining) or 0) > 0 then
            local rem = tonumber(queued[r.index].Remaining) or 0
            state.combineStatus = string.format("Đang ghép (%ds)", math.floor(rem))
        end
    end

    if #readyClaims == 0 and #starts == 0 then
        if #waiting > 0 then
            state.combineStatus = "Thiếu: " .. waiting[1]
        elseif state.combineStatus == "Rảnh" or state.combineStatus == "Đang Claim Huge" then
            state.combineStatus = "Chờ nguyên liệu"
        end
        state.nextCombineAt = now + (Config.CombineCooldown or 60)
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

        -- 1. Claim các mẻ đã ghép xong
        for _, claim in ipairs(readyClaims) do
            local okC, resC = Net.netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            if okC and resC then
                local recName = targetRecipeName
                for _, r in ipairs(recipes) do
                    if r.index == claim.RecipeIndex then
                        recName = r.name
                    end
                end
                state.combineStatus = "Đã nhận " .. recName
            end
            task.wait(0.6)
        end

        -- 2. Bắt đầu mẻ ghép mới khi đủ nguyên liệu
        for _, r in ipairs(starts) do
            local again = CombineHuge.combineRecipes()
            local fresh
            for _, x in ipairs(again) do
                if x.index == r.index then fresh = x end
            end
            if fresh and fresh.ready then
                local okS, resS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index)
                if okS and resS then
                    local durMin = r.duration and math.floor(r.duration / 60) or 0
                    state.combineStatus = string.format("Đang ghép %s (%dp)", r.name:gsub("Halloween ", ""):gsub("Huge ", ""), durMin)
                else
                    state.combineStatus = "Ghép lỗi: " .. tostring(resS)
                end
            end
            task.wait(0.6)
        end
    end)

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (Config.CombineCooldown or 60)
end

return CombineHuge
