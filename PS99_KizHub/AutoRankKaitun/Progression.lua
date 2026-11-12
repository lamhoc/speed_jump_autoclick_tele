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

-- Cờ bảo vệ chống gọi lặp vĩnh viễn
local StarterDone = false

function Progression.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    CurrentWorldFn = deps.CurrentWorld
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

-- 2. Tự động mở Slot Pet và Slot Mở Trứng bằng Diamonds (Ưu tiên mức độ cao nhất)
function Progression.autoOpenSlots(state)
    if not Config.AutoOpenSlots or not state.Enabled then return end
    if state.WorldSwitching or state.WorldMismatch or state.Hopping then return end

    local now = os.clock()
    if now - (state.LastSlotPurchaseAt or 0) < 5 then return end
    state.LastSlotPurchaseAt = now

    local gems = Net.currency("Diamonds")
    if gems < 25 then return end

    local hrp = Net.hrp()
    if not hrp then return end

    -- 2.1 Tìm vị trí máy EquipSlotsMachine hoặc EggHatchSlotsMachine
    local mach1 = nil
    if Net.isfn(G.MachineCmds, "GetModels") then
        local ok1, mods1 = Net.gcall(G.MachineCmds.GetModels, "EquipSlotsMachine")
        if ok1 and type(mods1) == "table" and mods1[1] and typeof(mods1[1]) == "Instance" then
            mach1 = mods1[1]
        end
    end
    if not mach1 then
        local machFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Machines")
        if machFolder then mach1 = machFolder:FindFirstChild("EquipSlotsMachine") end
    end

    local mach2 = nil
    if Net.isfn(G.MachineCmds, "GetModels") then
        local ok2, mods2 = Net.gcall(G.MachineCmds.GetModels, "EggHatchSlotsMachine")
        if ok2 and type(mods2) == "table" and mods2[1] and typeof(mods2[1]) == "Instance" then
            mach2 = mods2[1]
        end
    end
    if not mach2 then
        local machFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Machines")
        if machFolder then mach2 = machFolder:FindFirstChild("EggHatchSlotsMachine") end
    end

    local targetMach = mach1 or mach2
    local targetPivot = targetMach and targetMach:GetPivot().Position
    local origPos = hrp.CFrame
    local needTeleport = (targetPivot ~= nil and (hrp.Position - targetPivot).Magnitude > 40)

    -- Nếu đứng quá xa máy nâng cấp ở Spawn: Lưu vị trí, nhảy tới trước mặt máy để bypass kiểm tra khoảng cách server
    if needTeleport then
        state.SlotBuying = true
        hrp.CFrame = CFrame.new(targetPivot + Vector3.new(0, 3, 5))
        task.wait(0.2)
    end

    -- 2.2 Kích hoạt Proximity của cả 2 máy nâng cấp slot
    pcall(function()
        Net.netFire("Machines: Mark Approached", "EquipSlotsMachine")
        Net.netFire("Machines: Mark Approached", "EggHatchSlotsMachine")
        if mach1 then
            Net.netFire("Machines: Mark Approached", mach1)
            Net.netFire("Machines: Mark Approached", mach1.Name)
        end
        if mach2 then
            Net.netFire("Machines: Mark Approached", mach2)
            Net.netFire("Machines: Mark Approached", mach2.Name)
        end
    end)
    task.wait(0.1)

    -- 2.3 Mua Slot Pet (Thử tối đa 10 lần liên tiếp để mua hết số slot có thể)
    for _ = 1, 10 do
        local bought = false
        local ok, res = Net.netInvoke("EquipSlotsMachine_RequestPurchase", 1)
        if ok and res ~= false then bought = true end
        if not bought then
            local ok2, res2 = Net.netInvoke("EquipSlotsMachine_RequestPurchase")
            if ok2 and res2 ~= false then bought = true end
        end
        if not bought then
            pcall(function() Net.netFire("EquipSlotsMachine_RequestPurchase", 1) end)
            local okFb, resFb = Net.netInvoke("Upgrades_Purchase", "PetSlots")
            if okFb and resFb ~= false then bought = true end
        end
        if not bought then break end
        task.wait(0.15)
    end

    -- 2.4 Mua Slot Trứng (Chạy độc lập, thử tối đa 10 lần liên tiếp)
    for _ = 1, 10 do
        local bought = false
        local ok, res = Net.netInvoke("EggHatchSlotsMachine_RequestPurchase", 1)
        if ok and res ~= false then bought = true end
        if not bought then
            local ok2, res2 = Net.netInvoke("EggHatchSlotsMachine_RequestPurchase")
            if ok2 and res2 ~= false then bought = true end
        end
        if not bought then
            pcall(function() Net.netFire("EggHatchSlotsMachine_RequestPurchase", 1) end)
            local okFb, resFb = Net.netInvoke("Upgrades_Purchase", "EggSlots")
            if okFb and resFb ~= false then bought = true end
        end
        if not bought then break end
        task.wait(0.15)
    end

    -- 2.5 Dịch chuyển quay lại vị trí farm bãi ban đầu
    if needTeleport and origPos then
        task.wait(0.1)
        pcall(function()
            local curHrp = Net.hrp()
            if curHrp then
                curHrp.CFrame = origPos
                curHrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        state.SlotBuying = false
    end
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
