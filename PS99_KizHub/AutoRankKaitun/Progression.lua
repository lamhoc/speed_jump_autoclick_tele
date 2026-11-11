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

function Progression.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    CurrentWorldFn = deps.CurrentWorld
end

-- 1. Tự động chọn 2 Starter Pet cho tài khoản mới
function Progression.autoPickStarterPets(state)
    if not Config.AutoPickStarterPets then return end
    if state.StarterPetsPicked then return end

    local now = os.clock()
    if now - (state.LastStarterPetCheckAt or 0) < 5 then return end
    state.LastStarterPetCheckAt = now

    -- Kiểm tra save inventory
    local save = Net.getSave()
    if save and save.Inventory and type(save.Inventory.Pet) == "table" then
        local petCount = 0
        for _ in pairs(save.Inventory.Pet) do
            petCount = petCount + 1
            if petCount >= 2 then
                state.StarterPetsPicked = true
                return
            end
        end
    end

    -- Bắn Remote Network chọn starter pets
    local candidatePairs = {
        { "Cat", "Dog" },
        { "Dog", "Cat" },
        { "Dragon", "Bunny" },
        { 1, 2 },
    }
    for _, pair in ipairs(candidatePairs) do
        pcall(function() Net.netInvoke("Pick Starter Pets", pair[1], pair[2]) end)
        pcall(function() Net.netInvoke("Pick Starter Pets", pair) end)
        pcall(function() Net.netFire("Pick Starter Pets", pair[1], pair[2]) end)
        pcall(function() Net.netFire("Pick Starter Pets", pair) end)
    end

    -- Quét PlayerGui nếu có bảng chọn pet giao diện
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
        if count >= 2 then
            state.StarterPetsPicked = true
            if Net.isfn(G.PetCmds, "EquipBest") then
                pcall(G.PetCmds.EquipBest)
            end
        end
    end
end

-- 2. Tự động mở Slot Pet và Slot Mở Trứng bằng Diamonds
function Progression.autoOpenSlots(state)
    if not Config.AutoOpenSlots or not state.Enabled then return end
    if state.WorldSwitching or state.WorldMismatch or state.Hopping then return end

    local now = os.clock()
    if now - (state.LastSlotPurchaseAt or 0) < 15 then return end
    state.LastSlotPurchaseAt = now

    pcall(function()
        Net.netFire("Machines: Mark Approached", "EquipSlotsMachine")
        Net.netFire("Machines: Mark Approached", "EggHatchSlotsMachine")
    end)
    task.wait(0.1)

    -- Mua Slot Pet
    for _ = 1, 5 do
        local ok, res = Net.netInvoke("EquipSlotsMachine_RequestPurchase")
        if not ok or res == false then
            local okFb, resFb = Net.netInvoke("Upgrades_Purchase", "PetSlots")
            if not okFb or resFb == false then break end
        end
        task.wait(0.15)
    end

    -- Mua Slot Trứng
    for _ = 1, 5 do
        local ok, res = Net.netInvoke("EggHatchSlotsMachine_RequestPurchase")
        if not ok or res == false then
            local okFb, resFb = Net.netInvoke("Upgrades_Purchase", "EggSlots")
            if not okFb or resFb == false then break end
        end
        task.wait(0.15)
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
    if state.WorldSwitching or state.Hopping or state.HatchSession or os.clock() - (state.LastZoneBuyAt or 0) < 2 then
        return
    end
    if not Net.isfn(G.ZoneCmds, "GetNextZone") then return end

    local ZoneId, Zone = Net.gval(G.ZoneCmds.GetNextZone)
    if type(ZoneId) == "table" then Zone, ZoneId = ZoneId, ZoneId._id end
    Zone = Zone or (type(ZoneId) == "string" and G.Zones and G.Zones[ZoneId])
    if type(Zone) ~= "table" or type(ZoneId) ~= "string" then return end

    local cw = CurrentWorldFn and CurrentWorldFn() or 1
    if Zone.WorldNumber ~= cw then return end
    if Net.gval(G.ZoneCmds.HasCompletedNextZoneQuests) ~= true then return end

    local Price = Net.gval(G.Balancing and G.Balancing.CalcGatePrice, Zone)
    if type(Price) ~= "number" or not Zone.Currency or Net.gval(G.CurrencyCmds.CanAfford, Zone.Currency, Price) ~= true then
        return
    end

    state.LastZoneBuyAt = os.clock()
    Net.netInvoke("Zones_RequestPurchase", ZoneId)
end

return Progression
