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
            local rName = (r.name or ""):lower()
            if rName:find("combine") or rName:find("egg") or rName:find("trứng") then
                target = r
                break
            end
        end
        if not target and #recipes >= 2 then
            target = recipes[2] -- Công thức 2 thường là Combine Egg
        elseif not target and #recipes > 0 then
            target = recipes[1]
        end

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

    if not mach then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local n = desc.Name
                if n == K.COMBINE_MACHINE or n == "HalloweenPetCraftingMachine" or n == "Combine-o-Matic" or n == "HalloweenCraftingMachine" then
                    mach = desc
                    break
                end
            end
        end
    end

    if not mach then
        -- Tọa độ Pad thực tế được dump chính xác từ Instance của game
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
-- Bộ hàm tương tác GUI máy Combine-o-Matic theo đúng UI thực tế của game:
-- Tọa độ chuẩn do dj trích xuất trực tiếp:
--   1. Tab "Kết hợp Trứng": Scale (0.340, 0.463)
--   2. Nút "Chế tạo!":      Scale (0.534, 0.710)
--   3. Nút đỏ "X" Tắt UI:  Scale (0.765, 0.229)
-- =========================================================================

local VIM = game:GetService("VirtualInputManager")

local function clickScreenScale(scaleX, scaleY)
    local vp = workspace.CurrentCamera.ViewportSize
    local px = math.floor(scaleX * vp.X)
    local py = math.floor(scaleY * vp.Y)

    local clicked = false
    pcall(function()
        if VIM and type(VIM.SendMouseButtonEvent) == "function" then
            VIM:SendMouseButtonEvent(px, py, 0, true, game, 0)
            task.wait(0.15) -- Giữ chuột 150ms để game Roblox nhận diện click đầy đủ
            VIM:SendMouseButtonEvent(px, py, 0, false, game, 0)
            clicked = true
        end
    end)
    if not clicked and type(mouse1click) == "function" then
        pcall(function()
            if type(mousemoveabs) == "function" then
                mousemoveabs(px, py)
                task.wait(0.05)
            end
            mouse1click()
            clicked = true
        end)
    end
    return clicked
end

local function triggerGuiClick(btn)
    if not btn then return false end
    local triggered = false
    pcall(function()
        if type(firesignal) == "function" then
            if btn.Activated then firesignal(btn.Activated) triggered = true end
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) triggered = true end
            if btn.MouseButton1Down then firesignal(btn.MouseButton1Down) end
            task.wait(0.08)
            if btn.MouseButton1Up then firesignal(btn.MouseButton1Up) end
        end
        if type(getconnections) == "function" then
            if btn.Activated then
                for _, c in ipairs(getconnections(btn.Activated) or {}) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                    triggered = true
                end
            end
            if btn.MouseButton1Click then
                for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                    triggered = true
                end
            end
        end
    end)
    return triggered
end

-- Tìm frame cửa sổ Combine-o-Matic trong PlayerGui
local function findCombineMachineGui()
    local lp = Players.LocalPlayer
    local pgui = lp and lp:FindFirstChildOfClass("PlayerGui")
    if not pgui then return nil end

    for _, gui in ipairs(pgui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local gName = gui.Name:lower()
            if not gName:find("chat") and not gName:find("kizhub") and not gName:find("topbar") and not gName:find("roblox") then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Visible ~= false then
                        local txt = desc.Text:lower()
                        if txt:find("combine-o-matic") or txt:find("chọn thú cưng") or txt:find("kết hợp trứng") or txt:find("combine egg") then
                            local windowFrame = desc:FindFirstAncestorWhichIsA("Frame") or desc.Parent
                            while windowFrame and windowFrame.Parent and windowFrame.Parent:IsA("Frame") and windowFrame.Parent.Size.X.Scale > 0.3 do
                                windowFrame = windowFrame.Parent
                            end
                            return windowFrame or gui
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Kiểm tra xem bảng bên phải có còn đang bị kẹt ở tab "Chim cánh cụt khổng lồ" không
local function isPenguinTabStillActive()
    local lp = Players.LocalPlayer
    local pgui = lp and lp:FindFirstChildOfClass("PlayerGui")
    if not pgui then return false end
    for _, gui in ipairs(pgui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible ~= false then
                    local t = desc.Text:lower()
                    -- Nửa bên phải (Position.X.Scale > 0.45) hiển thị tên recipe đang chọn
                    if (t:find("chim cánh cụt") or t:find("gargantuan") or t:find("penguin")) and desc.Position.X.Scale > 0.45 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- 1. BƯỚC 1 CỦA DJ: Bấm chọn mục "Kết hợp Trứng" (Combine Egg) ở danh sách bên trái
local function selectCombineEggTab(machineGui)
    -- Click nhấp 2 lần cách nhau 0.3s để đảm bảo UI nhận diện
    clickScreenScale(0.340, 0.463)
    task.wait(0.3)
    clickScreenScale(0.340, 0.463)

    -- Fallback quét tìm nút GUI
    local scope = machineGui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    if scope then
        pcall(function()
            for _, desc in ipairs(scope:GetDescendants()) do
                if desc.Visible ~= false then
                    local text = ""
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        text = desc.Text:lower()
                    end

                    local isMatch = false
                    if text:find("kết hợp trứng") or text:find("combine egg") or text:find("combineegg") then
                        isMatch = true
                    elseif (text:find("trứng") or text:find("egg")) and not text:find("chim cánh cụt") and not text:find("penguin") and not text:find("gargantuan") and not text:find("khổng lồ") then
                        isMatch = true
                    end

                    if isMatch then
                        local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton") or desc:FindFirstChildWhichIsA("GuiButton") or desc
                        triggerGuiClick(btn)
                    end
                end
            end
        end)
    end
    return true
end

-- 2. BƯỚC 2 CỦA DJ: Bấm nút "Chế tạo!" (Craft!) ở góc dưới bên phải
local function clickCraftButton(machineGui)
    -- Click tọa độ màn hình chuẩn do dj trích xuất: Scale (0.534, 0.710)
    clickScreenScale(0.534, 0.710)

    -- Fallback quét tìm nút GUI
    local scope = machineGui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    if scope then
        pcall(function()
            for _, desc in ipairs(scope:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton") or desc:IsA("TextLabel")) and desc.Visible ~= false then
                    local text = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower() or ""
                    local isCraft = (text:find("chế tạo") or text:find("craft") or text:find("ghép")) and not text:find("10") and not text:find("3,000") and not text:find("3000")
                    if isCraft then
                        local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton") or desc:FindFirstChildWhichIsA("GuiButton") or desc
                        triggerGuiClick(btn)
                    end
                end
            end
        end)
    end
    return true
end

-- 3. BƯỚC 3 CỦA DJ: Tắt UI (Bấm nút đỏ "X" góc trên bên phải & TabController)
local function closeMachineGui(machineGui)
    -- Click tọa độ nút đỏ X chuẩn do dj trích xuất: Scale (0.765, 0.229)
    clickScreenScale(0.765, 0.229)

    pcall(function()
        local scope = machineGui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
        if scope then
            for _, desc in ipairs(scope:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible ~= false then
                    local bName = desc.Name:lower()
                    local bText = (desc:IsA("TextButton") and desc.Text:lower()) or ""
                    local isClose = (bName == "close" or bName == "closebutton" or bName == "x" or bName:find("exit") or bText == "x" or bText == "✕" or bText == "×")

                    if not isClose and desc:IsA("GuiObject") then
                        local bg = desc.BackgroundColor3
                        local isRedPink = (bg.R > 0.6 and bg.G < 0.4) or (bg.R > 0.7 and bg.B > 0.3)
                        if isRedPink and desc.Position.X.Scale > 0.5 then
                            isClose = true
                        end
                    end

                    if isClose then
                        triggerGuiClick(desc)
                    end
                end
            end
        end
    end)

    pcall(function()
        if G and G.TabController then
            if type(G.TabController.CloseAll) == "function" then
                pcall(G.TabController.CloseAll)
            end
            if type(G.TabController.Close) == "function" then
                pcall(G.TabController.Close, "Combine-o-Matic")
                pcall(G.TabController.Close, "HalloweenPetCraftingMachine")
                pcall(G.TabController.Close, "HalloweenGamesCombine")
                pcall(G.TabController.Close, "Machine")
            end
            if type(G.TabController.CloseTab) == "function" then
                pcall(G.TabController.CloseTab)
            end
        end
    end)

    if machineGui and machineGui:IsA("GuiObject") then
        pcall(function() machineGui.Visible = false end)
    end

    return true
end

-- =========================================================================
-- Vòng lặp kiểm tra và tự động mở Combine Egg
-- =========================================================================
function CombineHuge.checkAndRunCombine(state)
    local cfg = getConfig()
    if not cfg.AutoCombine or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextCombineAt or 0) then return end

    -- 1. Kiểm tra tiến độ nguyên liệu trực tiếp (Yêu cầu nghiêm ngặt: Agony >= 10 và Shard >= 300)
    local prog = CombineHuge.getCombineProgress()
    local recipes, dir = CombineHuge.combineRecipes()
    local dirId = (dir and dir._id) or K.COMBINE_ID or "HalloweenGamesCombine"

    -- 2. Kiểm tra hàng đợi claim
    local q = CombineHuge.activeQueues()
    local readyClaims = {}
    for k, item in pairs(q or {}) do
        if type(item) == "table" then
            local uid = item.UID or (type(k) == "string" and k) or nil
            local recIdx = item.RecipeIndex or (item.Recipe and item.Recipe.Index)
            local rem = tonumber(item.Remaining) or tonumber(item.TimeLeft) or 0
            if recIdx and rem <= 0 and uid then
                table.insert(readyClaims, { UID = uid, RecipeIndex = recIdx })
            end
        end
    end

    -- 3. Đánh giá sẵn sàng ghép: BẮT BUỘC ĐỦ Agony (>= 10) & Shard (>= 300)
    local canCraft = (prog and prog.haveAgony >= 10 and prog.haveShard >= 300)

    if #readyClaims == 0 and not canCraft then
        state.combineStatus = (prog and prog.statusText) or CombineHuge.getCombineStatusText()
        state.nextCombineAt = now + (cfg.CombineCooldown or 15)
        return
    end

    -- 4. Bắt đầu chuyến đi tới máy Combine
    state.excursion = "combine"
    local savedPos = Net.playerPos()

    pcall(function()
        local stand, mach = CombineHuge.combineMachineStand()
        if stand then
            Net.teleportTo(stand)
            task.wait(0.8)
        end

        -- Kích hoạt tiếp cận máy, chạm Pad và ProximityPrompt
        pcall(function()
            Net.netFire("Machines: Mark Approached", dirId)
            Net.netFire("Machines: Mark Approached", K.COMBINE_MACHINE)
            if mach then
                Net.netFire("Machines: Mark Approached", mach)
                Net.netFire("Machines: Mark Approached", mach.Name)
                local pad = mach:FindFirstChild("Pad")
                local hrp = Net.hrp()
                if pad and hrp and type(firetouchinterest) == "function" then
                    firetouchinterest(hrp, pad, 0)
                    task.wait(0.08)
                    firetouchinterest(hrp, pad, 1)
                end
                for _, prompt in ipairs(mach:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        if type(fireproximityprompt) == "function" then
                            fireproximityprompt(prompt)
                        end
                    end
                end
            end
        end)
        task.wait(0.6)

        -- 4.1 Claim các mẻ đã ghép xong nếu có
        for _, claim in ipairs(readyClaims) do
            local preSnap = snapshotPetInventory()
            local okC, resC = Net.netInvoke("HalloweenCraftingMachine_Claim", claim.UID)
            if okC and resC then
                state.combineStatus = "Đã nhận mẻ ghép"
                task.wait(0.6)
                checkAndNotifyNewPets(preSnap)
            end
            task.wait(0.4)
        end

        -- 4.2 [QUAN TRỌNG]: Đợi UI máy nạp đầy đủ (chờ 1.2s cho UI ổn định)
        task.wait(1.2)
        local machGui = findCombineMachineGui()
        if not machGui then
            task.wait(0.6)
            machGui = findCombineMachineGui()
        end

        -- [BƯỚC 1 CỦA DJ]: Chọn mục "Kết hợp Trứng" (Combine Egg) ở danh sách bên trái (Scale 0.340, 0.463)
        selectCombineEggTab(machGui)
        task.wait(1.2) -- Đợi 1.2s để UI chuyển tab và hiển thị đúng công thức Combine Egg

        -- Kiểm tra lại: Nếu bảng bên phải vẫn đang bị kẹt ở tab "Chim cánh cụt khổng lồ", thử click lại lần nữa
        if isPenguinTabStillActive() then
            print("[KizHub Combine] Tab Chim cánh cụt vẫn đang active, nhấp lại vào Kết hợp Trứng...")
            selectCombineEggTab(machGui)
            task.wait(1.0)
        end

        -- Nếu sau 2 lần vẫn còn kẹt ở tab Chim cánh cụt, TUYỆT ĐỐI KHÔNG CLICK CRAFT để tránh báo lỗi!
        if isPenguinTabStillActive() then
            warn("[KizHub Combine] Chưa chuyển sang tab Combine Egg thành công. Hủy lượt craft để tránh lỗi!")
            closeMachineGui(machGui)
            return
        end

        -- Xác định targetIndex chuẩn cho Combine Egg (mặc định 2, bỏ qua công thức 1 Chim cánh cụt khổng lồ)
        local targetIndex = 2
        if type(recipes) == "table" and #recipes > 0 then
            for _, r in ipairs(recipes) do
                local rName = (r.name or ""):lower()
                if rName:find("combine") or rName:find("egg") or rName:find("trứng") then
                    targetIndex = r.index
                    break
                end
            end
        end

        -- [BƯỚC 2 CỦA DJ]: Vòng lặp ấn nút "Chế tạo!" (Craft!)
        -- [LƯU Ý CỦA DJ]: BẮT BUỘC CHECK ĐỦ NGUYÊN LIỆU MỚI ĐƯỢC CLICK TRÁNH LỖI KẸT GAME!
        local maxCraftAttempts = 50
        while maxCraftAttempts > 0 and state.alive do
            maxCraftAttempts = maxCraftAttempts - 1

            -- KIỂM TRA ĐỦ NGUYÊN LIỆU: Cần ít nhất 10 Agony và 300 Shards
            local curProg = CombineHuge.getCombineProgress()
            local hasEnough = (curProg and curProg.haveAgony >= 10 and curProg.haveShard >= 300)
            if not hasEnough then
                print(string.format("[KizHub Combine] Nguyên liệu không đủ (Hiện có: %d/10 Agony, %d/300 Shards). Dừng craft ngay lập tức!", curProg and curProg.haveAgony or 0, curProg and curProg.haveShard or 0))
                break -- Dừng ngay lập tức, tuyệt đối không click bừa
            end

            -- Kiểm tra an toàn: Đảm bảo không bị lật về tab Chim cánh cụt
            if isPenguinTabStillActive() then
                warn("[KizHub Combine] Phát hiện tab bị lệch sang Chim cánh cụt. Dừng craft ngay!")
                break
            end

            local preSnap = snapshotPetInventory()

            -- Click nút Chế tạo! tại Scale (0.534, 0.710) với nhịp bấm chuẩn
            clickCraftButton(machGui)

            -- Đồng thời gọi Remote StartCraft 1 quả
            local okS, resS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dirId, targetIndex, 1)
            if not okS or resS == false then
                okS, resS = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dirId, targetIndex)
            end

            state.combineStatus = string.format("Đã ấn Craft 1 Combine Egg (%d Agony, %d Shard còn)", curProg.haveAgony - 10, curProg.haveShard - 300)
            task.wait(1.5) -- Đợi 1.5s cho hiệu ứng ghép xong và nguyên liệu trong túi cập nhật
            checkAndNotifyNewPets(preSnap)
            task.wait(0.8) -- Khoảng nghỉ 0.8s giữa các mẻ ghép
        end

        -- [BƯỚC 3 CỦA DJ]: Tắt UI máy (Bấm nút đỏ X góc trên bên phải Scale 0.765, 0.229 & TabController)
        task.wait(0.5)
        closeMachineGui(machGui)
        task.wait(0.6)
    end)

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (cfg.CombineCooldown or 30)
end

return CombineHuge
