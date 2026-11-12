-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/Progression.lua
-- Module tự động hóa tiến trình: Chọn Starter Pets, Mở Slots, Quà Free & Mua Zone
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Progression = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local CurrentWorldFn = nil
local EnsureInBestZoneFn = nil
local ZoneArrivalPositionFn = nil

-- Cờ bảo vệ chống gọi lặp vĩnh viễn
local StarterDone = false

function Progression.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    CurrentWorldFn = deps.CurrentWorld
    EnsureInBestZoneFn = deps.EnsureInBestZone
    ZoneArrivalPositionFn = deps.ZoneArrivalPosition
end

-- 1. Tự động chọn 2 Starter Pet cho tài khoản mới (Chạy 1 lần duy nhất rồi tắt vĩnh viễn)
function Progression.autoPickStarterPets(state)
    if StarterDone or (state and state.StarterPetsPicked) then
        return true
    end
    if Config.AutoPickStarterPets == false then
        StarterDone = true
        if state then state.StarterPetsPicked = true end
        return true
    end

    -- 1.1 Kiểm tra save inventory: Chỉ cần có >= 1 pet là tài khoản đã có starter pet
    local save = Net.getSave()
    if save and save.Inventory and type(save.Inventory.Pet) == "table" then
        local petCount = 0
        for _ in pairs(save.Inventory.Pet) do
            petCount = petCount + 1
            if petCount >= 1 then
                StarterDone = true
                if state then state.StarterPetsPicked = true end
                return true
            end
        end
    end

    -- 1.2 Gọi RemoteFunction Network chọn starter pets (Thuần Invoke bọc pcall, tuyệt đối không dùng FireServer)
    local candidatePairs = {
        { "Cat", "Dog" },
        { "Dog", "Cat" },
        { "Dragon", "Bunny" },
        { 1, 2 },
    }
    for _, pair in ipairs(candidatePairs) do
        local ok, res = pcall(function() return Net.netInvoke("Pick Starter Pets", pair[1], pair[2]) end)
        if ok and res ~= nil then break end
        local ok2, res2 = pcall(function() return Net.netInvoke("Pick Starter Pets", pair) end)
        if ok2 and res2 ~= nil then break end
    end

    -- 1.3 Quét PlayerGui nếu có bảng chọn pet giao diện trên màn hình
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pgui then return end
        for _, gui in ipairs(pgui:GetChildren()) do
            local gname = gui.Name:lower()
            if gname:find("starter") or gname:find("intro") or gname:find("tutorial") or gname:find("pick") or gname:find("choose") then
                local petBtns = {}
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("GuiButton") and desc.Visible then
                        local n = desc.Name:lower()
                        local t = desc:IsA("TextButton") and desc.Text:lower() or ""
                        if n:find("cat") or n:find("dog") or n:find("bunny") or n:find("dragon") or
                           t:find("cat") or t:find("dog") or t:find("bunny") or t:find("dragon") then
                            petBtns[#petBtns + 1] = desc
                        end
                    end
                end
                for i = 1, math.min(2, #petBtns) do
                    local btn = petBtns[i]
                    pcall(function()
                        if type(getconnections) == "function" then
                            for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                            end
                            for _, c in ipairs(getconnections(btn.Activated) or {}) do
                                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                            end
                        end
                    end)
                end
                task.wait(0.2)
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("GuiButton") and desc.Visible then
                        local n = desc.Name:lower()
                        local t = desc:IsA("TextButton") and desc.Text:lower() or ""
                        if n:find("confirm") or n:find("select") or n:find("ready") or n:find("claim") or n:find("pick") or
                           t:find("confirm") or t:find("select") or t:find("ready") or t:find("claim") or t:find("ok") then
                            pcall(function()
                                if type(getconnections) == "function" then
                                    for _, c in ipairs(getconnections(desc.MouseButton1Click) or {}) do
                                        if c.Fire then c:Fire() elseif c.Function then c.Function() end
                                    end
                                    for _, c in ipairs(getconnections(desc.Activated) or {}) do
                                        if c.Fire then c:Fire() elseif c.Function then c.Function() end
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)

    task.wait(0.5)
    local saveAfter = Net.getSave()
    if saveAfter and saveAfter.Inventory and type(saveAfter.Inventory.Pet) == "table" then
        local count = 0
        for _ in pairs(saveAfter.Inventory.Pet) do count = count + 1 end
        if count >= 1 then
            StarterDone = true
            if state then state.StarterPetsPicked = true end
            if Net.isfn(G.PetCmds, "EquipBest") then
                pcall(G.PetCmds.EquipBest)
            end
            return true
        end
    end

    if state then
        state.StarterPetAttempts = (state.StarterPetAttempts or 0) + 1
        if state.StarterPetAttempts >= 3 then
            -- Sau 3 lần thử bất kể kết quả gì, khóa vĩnh viễn để tránh spam request gây lỗi
            StarterDone = true
            state.StarterPetsPicked = true
            return true
        end
    end

    return false
end

-- Helper tìm máy nâng cấp
local function findMachineModel(machName)
    if Net.isfn(G.MachineCmds, "GetModels") then
        local ok, models = Net.gcall(G.MachineCmds.GetModels, machName)
        if ok and type(models) == "table" then
            for _, m in pairs(models) do
                if typeof(m) == "Instance" and m.Parent then
                    return m
                end
            end
        end
    end

    local things = workspace:FindFirstChild("__THINGS")
    local machFolder = things and things:FindFirstChild("Machines")
    if machFolder then
        local direct = machFolder:FindFirstChild(machName)
        if direct then return direct end
        for _, m in ipairs(machFolder:GetChildren()) do
            if m.Name:lower():find(machName:lower()) then
                return m
            end
        end
    end

    local map = workspace:FindFirstChild("Map")
    if map then
        for _, desc in ipairs(map:GetDescendants()) do
            if desc:IsA("Model") and (desc.Name == machName or desc.Name:lower():find(machName:lower())) then
                return desc
            end
        end
    end

    return nil
end

local function getMachineStandCFrame(mach, machName)
    if mach and typeof(mach) == "Instance" then
        local prompt = mach:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
            return CFrame.new(prompt.Parent.Position + Vector3.new(0, 3, 3))
        end
        local pad = mach:FindFirstChild("Pad", true) or mach:FindFirstChild("Platform", true)
        if pad and pad:IsA("BasePart") then
            return CFrame.new(pad.Position + Vector3.new(0, 3, 0))
        end
        local p = mach:GetPivot()
        return CFrame.new(p.Position + Vector3.new(0, 3, 4))
    end
    -- Fallback về Spawn nếu không lấy được part máy
    if ZoneArrivalPositionFn then
        local spawnPos = ZoneArrivalPositionFn("Spawn")
        if spawnPos then return CFrame.new(spawnPos + Vector3.new(0, 3, 0)) end
    end
    return nil
end

local function triggerGuiClick(btn)
    if not btn then return false end
    local triggered = false
    if type(firesignal) == "function" then
        pcall(function() firesignal(btn.Activated) triggered = true end)
        pcall(function() firesignal(btn.MouseButton1Click) triggered = true end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
    end
    if type(getconnections) == "function" then
        pcall(function()
            for _, c in ipairs(getconnections(btn.Activated) or {}) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                triggered = true
            end
            for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
                triggered = true
            end
        end)
    end
    return triggered
end

local function clickBuyButtonsInGui(filterKeyword)
    local clicked = false
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pgui then return end
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local gName = gui.Name:lower()
                local isMachineGui = gName:find("slot") or gName:find("machine") or gName:find("upgrade")
                    or gName:find("equip") or gName:find("pet") or gName:find("egg")
                    or (filterKeyword and gName:find(filterKeyword))
                if isMachineGui then
                    for _, btn in ipairs(gui:GetDescendants()) do
                        if (btn:IsA("TextButton") or btn:IsA("ImageButton") or btn:IsA("GuiButton")) and btn.Visible and btn.Active then
                            local bName = btn.Name:lower()
                            local bText = (btn:IsA("TextButton") and btn.Text:lower()) or ""
                            
                            -- Bỏ qua các card đã sở hữu ("Possédé" / "Owned")
                            local isOwned = bText:find("owned") or bText:find("posséd") or bName:find("owned")
                            if not isOwned then
                                local isBuyBtn = bName:find("buy") or bName:find("purchase") or bName:find("cost") or bName:find("price")
                                    or bText:find("buy") or bText:find("purchase") or bText:find("💎")
                                    or bText:find("k") or tonumber(bText:match("%d+"))
                                local hasDiamondChild = btn:FindFirstChildWhichIsA("ImageLabel") ~= nil
                                local isGreenBg = btn.BackgroundColor3.G > 0.6 and btn.BackgroundColor3.G > btn.BackgroundColor3.R

                                if isBuyBtn or hasDiamondChild or isGreenBg then
                                    if triggerGuiClick(btn) then
                                        clicked = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return clicked
end

local function closeAnyMachinePopup()
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pgui then return end
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local gName = gui.Name:lower()
                if gName:find("slot") or gName:find("equip") or gName:find("machine") or gName:find("upgrade") or gName:find("pet") or gName:find("egg") then
                    for _, closeBtn in ipairs(gui:GetDescendants()) do
                        if (closeBtn:IsA("TextButton") or closeBtn:IsA("ImageButton") or closeBtn:IsA("GuiButton")) and closeBtn.Visible then
                            local cName = closeBtn.Name:lower()
                            local cText = (closeBtn:IsA("TextButton") and closeBtn.Text:lower()) or ""
                            if cName == "close" or cName == "x" or cName:find("exit") or cName:find("cross") or cText == "x" then
                                triggerGuiClick(closeBtn)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function buySlotsAtMachine(machName, filterKeyword, remoteName, fallbackUpgrade)
    local mach = findMachineModel(machName)
    local cf = getMachineStandCFrame(mach, machName)
    local hrp = Net.hrp()
    if not hrp then return false end

    -- Teleport tới trước mặt máy
    if cf then
        hrp.CFrame = cf
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        task.wait(0.5)
    end

    -- Kích hoạt tương tác máy
    pcall(function()
        Net.netFire("Machines: Mark Approached", machName)
        if mach then
            Net.netFire("Machines: Mark Approached", mach)
            Net.netFire("Machines: Mark Approached", mach.Name)
            for _, prompt in ipairs(mach:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    pcall(function()
                        if type(fireproximityprompt) == "function" then
                            fireproximityprompt(prompt)
                        end
                    end)
                end
            end
        end
    end)
    task.wait(0.4)

    -- Mua tối đa 15 lần
    local anyBought = false
    for _ = 1, 15 do
        local gems = Net.currency("Diamonds")
        if gems < 25 then break end

        local bought = false
        -- 1. Click nút trực tiếp trên UI
        local clicked = clickBuyButtonsInGui(filterKeyword)
        if clicked then bought = true end

        -- 2. Gọi RemoteFunction của máy
        local ok, res = Net.netInvoke(remoteName)
        if ok and res ~= false then bought = true end

        if not bought then
            local ok2, res2 = Net.netInvoke(remoteName, 1)
            if ok2 and res2 ~= false then bought = true end
        end

        -- 3. Fallback Upgrades_Purchase
        if not bought and fallbackUpgrade then
            local okFb, resFb = Net.netInvoke("Upgrades_Purchase", fallbackUpgrade)
            if okFb and resFb ~= false then bought = true end
        end

        if bought then
            anyBought = true
            task.wait(0.25)
        else
            break
        end
    end

    -- Đóng giao diện UI máy
    closeAnyMachinePopup()
    task.wait(0.3)
    return anyBought
end

-- 2. Tự động mở Slot Pet và Slot Mở Trứng bằng Diamonds (Tele tới 2 máy mua rồi tele về map farm)
function Progression.performSlotPurchaseTrip(state)
    if not Config.AutoOpenSlots or not state.Enabled then return end
    if state.WorldSwitching or state.WorldMismatch or state.Hopping then return end
    if state.SlotBuying then return end

    local gems = Net.currency("Diamonds")
    if gems < 25 then return end

    local hrp = Net.hrp()
    if not hrp then return end

    state.SlotBuying = true
    state.Action = "Buying Slots (Teleport to Machines)"

    -- 1. Teleport tới EquipSlotsMachine (Slot Pet) và mua
    pcall(function()
        buySlotsAtMachine("EquipSlotsMachine", "equip", "EquipSlotsMachine_RequestPurchase", "PetSlots")
    end)
    task.wait(0.3)

    -- 2. Teleport tới EggHatchSlotsMachine (Slot Trứng) và mua
    pcall(function()
        buySlotsAtMachine("EggHatchSlotsMachine", "egg", "EggHatchSlotsMachine_RequestPurchase", "EggSlots")
    end)
    task.wait(0.3)

    -- 3. Teleport quay trở lại bãi farm tốt nhất
    state.SlotBuying = false
    task.wait(0.2)
    pcall(function()
        if EnsureInBestZoneFn then
            state.ReturnAfterHatch = os.clock()
            EnsureInBestZoneFn(state)
        end
    end)
    task.wait(0.5)
end

function Progression.autoOpenSlots(state)
    local now = os.clock()
    if now - (state.LastSlotPurchaseAt or 0) < 15 then return end
    state.LastSlotPurchaseAt = now
    return Progression.performSlotPurchaseTrip(state)
end

-- 3. Tự động nhận Free Gifts định kỳ
function Progression.checkAndClaimFreeGifts(state)
    if not Config.AutoClaimFreeGifts or not state.Enabled then return end
    local now = os.clock()
    if now < (state.NextClaimGiftsAt or 0) then return end
    state.NextClaimGiftsAt = now + 60

    for giftId = 1, 12 do
        pcall(function() Net.netInvoke("Redeem Free Gift", giftId) end)
        pcall(function() Net.netFire("Redeem Free Gift", giftId) end)
        task.wait(0.1)
    end
end

-- 4. Tự động mua Zone mới khi đủ điều kiện
function Progression.HandleBlockedAndZones(info, state)
    if not Config.AutoBuyZones then return end
    if state.WorldSwitching or state.Hopping or os.clock() - (state.LastZoneBuyAt or 0) < 2 then
        return
    end
    if not Net.isfn(G.ZoneCmds, "GetNextZone") then return end

    local ZoneId, Zone = Net.gval(G.ZoneCmds.GetNextZone)
    if type(ZoneId) == "table" then Zone, ZoneId = ZoneId, ZoneId._id end
    Zone = Zone or (type(ZoneId) == "string" and G.Zones and G.Zones[ZoneId])
    if type(Zone) ~= "table" or type(ZoneId) ~= "string" then return end

    local cw = CurrentWorldFn and CurrentWorldFn() or 1
    if Zone.WorldNumber ~= nil and Zone.WorldNumber ~= cw then return end

    -- Kiểm tra nhiệm vụ cổng mở map nếu hàm tồn tại
    if Net.isfn(G.ZoneCmds, "HasCompletedNextZoneQuests") then
        local okQ, resQ = Net.gcall(G.ZoneCmds.HasCompletedNextZoneQuests, ZoneId)
        if not okQ or resQ == nil then
            okQ, resQ = Net.gcall(G.ZoneCmds.HasCompletedNextZoneQuests)
        end
        if okQ and resQ == false then
            return
        end
    end

    local Price = nil
    if Net.isfn(G.Balancing, "CalcGatePrice") then
        Price = Net.gval(G.Balancing.CalcGatePrice, Zone)
    end
    if type(Price) ~= "number" then
        Price = tonumber(Zone.GatePrice or Zone.Price or Zone.Cost or 0)
    end

    local cur = Zone.Currency or "Coins"
    local bal = Net.currency(cur)
    if type(Price) == "number" and Price > 0 and bal < Price then
        return
    end

    state.LastZoneBuyAt = os.clock()
    local ok, res, msg = Net.netInvoke("Zones_RequestPurchase", ZoneId)
    if ok and res == true then
        state.ZoneHatchDone = state.ZoneHatchDone or {}
        state.ZoneHatchDone[ZoneId] = false -- Reset để map mới có cơ hội mở egg nếu đủ coin
    end
end

return Progression
