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

-- Quét kiểm tra máy Combine-o-Matic đã có Combine Egg hay chưa (phát hiện server cũ)
function CombineHuge.scanCombineEggAvailability()
    local dir = CombineHuge.combineDir()
    if not dir then
        local RS = game:GetService("ReplicatedStorage")
        local mod = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Directory") and RS.Library.Directory:FindFirstChild("HalloweenCraftingMachines")
        if mod then
            local ok, m = pcall(require, mod)
            if ok and type(m) == "table" then
                dir = m[K.COMBINE_ID] or m["HalloweenGamesCombine"] or m["Combine-o-Matic"] or next(m)
            end
        end
    end

    if not dir or type(dir.Recipes) ~= "table" or #dir.Recipes == 0 then
        return false, "Chưa nạp được dữ liệu máy Combine-o-Matic"
    end

    for _, r in ipairs(dir.Recipes) do
        local rName = ""
        if r.Result then
            pcall(function()
                if type(r.Result.GetId) == "function" then
                    rName = tostring(r.Result:GetId() or "")
                elseif r.Result.Id then
                    rName = tostring(r.Result.Id)
                elseif r.Result.Name then
                    rName = tostring(r.Result.Name)
                end
            end)
        end
        local nl = rName:lower()
        if (nl:find("combine") and nl:find("egg")) or nl == "combine egg" then
            return true, rName
        end
    end

    local oldNames = {}
    for _, r in ipairs(dir.Recipes) do
        if r.Result then
            pcall(function()
                local n = type(r.Result.GetId) == "function" and r.Result:GetId() or r.Result.Id or r.Result.Name or "?"
                table.insert(oldNames, tostring(n))
            end)
        end
    end
    local detail = #oldNames > 0 and table.concat(oldNames, ", ") or "Chưa có công thức mới"
    return false, string.format("Server cũ: Chưa có Combine Egg (Đang có: %s)", detail)
end

-- Chức năng Server Hop tìm server mới đã cập nhật Combine Egg
local isHoppingServer = false
local lastHopAttempt = 0

function CombineHuge.hopServer()
    local now = os.clock()
    if isHoppingServer and (now - lastHopAttempt < 15) then
        return
    end
    isHoppingServer = true
    lastHopAttempt = now

    local loader = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/main/PS99_KizHub/HalloweenKaitun/main.lua"))()'
    if type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, loader)
    end

    task.spawn(function()
        local TeleportService = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")
        local placeId = game.PlaceId
        local candidateServers = {}
        local cursor = ""
        local reqFn = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (type(http) == "table" and type(http.request) == "function" and http.request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)

        for page = 1, 3 do
            local url = string.format(
                "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100%s",
                tostring(placeId),
                (cursor ~= "" and ("&cursor=" .. cursor) or "")
            )
            local body = nil
            if reqFn then
                local ok, resp = pcall(reqFn, { Url = url, Method = "GET" })
                if ok and type(resp) == "table" and resp.Body then
                    body = resp.Body
                end
            end
            if not body and type(game.HttpGet) == "function" then
                local ok, res = pcall(game.HttpGet, game, url)
                if ok and type(res) == "string" and #res > 0 then
                    body = res
                end
            end

            if body then
                local okD, data = pcall(HttpService.JSONDecode, HttpService, body)
                if okD and data and type(data.data) == "table" then
                    for _, s in ipairs(data.data) do
                        if type(s) == "table" and s.id and s.id ~= game.JobId then
                            local pl = tonumber(s.playing) or 0
                            local maxPl = tonumber(s.maxPlayers) or 20
                            if pl >= 1 and pl <= (maxPl - 2) then
                                table.insert(candidateServers, s.id)
                            end
                        end
                    end
                    if data.nextPageCursor and tostring(data.nextPageCursor) ~= "" and data.nextPageCursor ~= "null" then
                        cursor = tostring(data.nextPageCursor)
                    else
                        break
                    end
                else
                    break
                end
            else
                break
            end
            task.wait(0.2)
        end

        if #candidateServers > 0 then
            local chosen = candidateServers[math.random(1, math.min(#candidateServers, 10))]
            print(string.format("[KizHub ServerHop] Đang dịch chuyển sang Server mới: %s...", tostring(chosen)))
            local okTp, errTp = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, chosen, game:GetService("Players").LocalPlayer)
            end)
            if not okTp then
                warn("[KizHub ServerHop] Lỗi TeleportToPlaceInstance: " .. tostring(errTp))
                isHoppingServer = false
            end
        else
            warn("[KizHub ServerHop] Không tìm thấy server từ API, gọi TeleportService...")
            local okTp = pcall(function()
                TeleportService:Teleport(placeId, game:GetService("Players").LocalPlayer)
            end)
            if not okTp then
                isHoppingServer = false
            end
        end
    end)
end

-- Lắng nghe sự kiện nếu Teleport thất bại thì cho phép thử lại
pcall(function()
    local TeleportService = game:GetService("TeleportService")
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        warn(string.format("[KizHub ServerHop] Dịch chuyển thất bại (%s): %s. Đang thử server khác...", tostring(teleportResult), tostring(errorMessage)))
        isHoppingServer = false
        task.wait(2)
        CombineHuge.hopServer()
    end)
end)

-- Quét kiểm tra phiên bản server ngay khi load script
function CombineHuge.checkServerVersionOnStartup(state)
    local cfg = getConfig()
    if not cfg.AutoHopIfOldServer then return end
    task.wait(2.5)
    for attempt = 1, 8 do
        local hasEgg, statusMsg = CombineHuge.scanCombineEggAvailability()
        if hasEgg then
            print("[KizHub] ✔ Server hiện tại là Server MỚI (Đã có Combine Egg). Bắt đầu farm!")
            if state then
                state.serverHasCombineEgg = true
                state.combineStatus = "Sẵn sàng (Đã có Combine Egg)"
            end
            return true
        else
            print(string.format("[KizHub] [Kiểm tra %d/8] %s", attempt, tostring(statusMsg)))
            if statusMsg and statusMsg:find("Server cũ", 1, true) then
                print("[KizHub] ⚠ XÁC NHẬN SERVER CŨ: Chưa có Combine Egg -> TỰ ĐỘNG SERVER HOP NGAY!")
                if state then
                    state.combineStatus = "⚠ Server cũ -> Đang chuyển server mới..."
                end
                task.wait(1.0)
                CombineHuge.hopServer()
                return false
            end
        end
        task.wait(1.5)
    end
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
    local cfg = getConfig()
    if not cfg.AutoCombine or (inEventFn and not inEventFn()) or state.excursion ~= nil then return end
    local now = os.clock()
    if now < (state.nextCombineAt or 0) then return end

    -- 1. Quét kiểm tra xem máy Combine-o-Matic trên server hiện tại đã có Combine Egg hay chưa
    local hasCombineEgg, eggStatusMsg = CombineHuge.scanCombineEggAvailability()
    if not hasCombineEgg then
        state.combineStatus = "⚠ " .. tostring(eggStatusMsg)
        state.serverHasCombineEgg = false

        if cfg.AutoHopIfOldServer then
            state.combineStatus = "⚠ Server cũ -> Đang chuyển server mới có Combine Egg..."
            task.wait(2.0)
            CombineHuge.hopServer()
            state.nextCombineAt = now + 90
            return
        end

        state.nextCombineAt = now + (cfg.CombineCooldown or 30)
        return
    end

    state.serverHasCombineEgg = true

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

    local targetRecipeName = Config.TargetCombineRecipe or "Combine Egg"
    local starts = {}
    local waiting = {}

    for i = #recipes, 1, -1 do
        local r = recipes[i]
        local isTarget = false
        if targetRecipeName == nil or targetRecipeName == "" then
            isTarget = true
        elseif r.name == targetRecipeName then
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
        state.nextCombineAt = now + (Config.CombineCooldown or 30)
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
            task.wait(0.4)
        end

        -- 2. Bắt đầu ghép: Mở Combine Egg (Hỗ trợ Open 10 và Craft liên tục cho tới khi hết nguyên liệu)
        for _, r in ipairs(starts) do
            local maxTries = 30
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

                -- Thử gọi Open 10 nếu đủ điều kiện
                local crafted = false
                local ok10, res10 = Net.netInvoke("HalloweenCraftingMachine_StartCraft", dir._id, r.index, 10)
                if ok10 and (res10 == true or type(res10) == "table") then
                    crafted = true
                    state.combineStatus = "Đã mở 10 " .. r.name
                else
                    -- Fallback craft 1
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
                task.wait(0.35)
            end
        end
    end)

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    state.excursion = nil
    state.nextCombineAt = os.clock() + (Config.CombineCooldown or 30)
end

return CombineHuge
