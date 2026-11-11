-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/Daycare.lua
-- Module tự động quản lý Daycare (Nhận thưởng & Gửi pet mạnh nhất)
-- Tích hợp: Lọc pet Stat cao nhất, Báo Webhook chuẩn (Meebo / Gargantuan Hippomelon Egg)
-- =========================================================================

local Daycare = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local Webhook = nil
local petEuidsFn = nil

function Daycare.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    Webhook = deps.Webhook
    petEuidsFn = deps.petEuids
end

function Daycare.daycareStandPos()
    if Net.isfn(G.MachineCmds, "GetModels") then
        local ok, models = Net.gcall(G.MachineCmds.GetModels, "Daycare")
        if ok and type(models) == "table" then
            for _, m in pairs(models) do
                if typeof(m) == "Instance" then
                    local pad = m:FindFirstChild("Pad", true)
                    if pad and pad:IsA("BasePart") then
                        return pad.Position + Vector3.new(0, 3, 0)
                    end
                    return m:GetPivot().Position + Vector3.new(0, 3, 6)
                end
            end
        end
    end
    local map = workspace:FindFirstChild("Map")
    local beach = map and map:FindFirstChild("20 | Beach")
    local inter = beach and beach:FindFirstChild("INTERACT")
    local machs = inter and inter:FindFirstChild("Machines")
    local dc = machs and (machs:FindFirstChild("DaycareMachine") or machs:FindFirstChild("Daycare"))
    if dc then
        local pad = dc:FindFirstChild("Pad", true)
        if pad and pad:IsA("BasePart") then
            return pad.Position + Vector3.new(0, 3, 0)
        end
        return dc:GetPivot().Position + Vector3.new(0, 3, 6)
    end
    return Vector3.new(130.26, 16.56, 509.21)
end

function Daycare.getDaycareInfo()
    local s = Net.getSave()
    local active = s and s.DaycareActive
    local maxSlots = 10
    if Net.isfn(G.DaycareCmds, "GetMaxSlots") then
        local okM, m = Net.gcall(G.DaycareCmds.GetMaxSlots)
        if okM and type(m) == "number" then maxSlots = m end
    end

    local enrolled = 0
    if Net.isfn(G.DaycareCmds, "GetUsedSlots") then
        local okU, u = Net.gcall(G.DaycareCmds.GetUsedSlots)
        if okU and type(u) == "number" then enrolled = u end
    end
    if enrolled == 0 and type(active) == "table" then
        for _ in pairs(active) do enrolled = enrolled + 1 end
    end

    local readyToClaim = false
    local minRemaining = math.huge
    local now = os.time()

    if type(active) == "table" then
        for uid, v in pairs(active) do
            if type(v) == "table" then
                local remain = nil
                if Net.isfn(G.DaycareCmds, "ComputeRemainingTime") then
                    local okR, r = Net.gcall(G.DaycareCmds.ComputeRemainingTime, v)
                    if okR and type(r) == "number" then remain = r end
                end

                if not remain then
                    local readyAt = tonumber(v.ReadyTime or v.ReadyAt or v.ClaimTime or v.EndTime)
                    if readyAt then
                        remain = readyAt - now
                    elseif tonumber(v.CreationTime) and tonumber(v.CreationAge) then
                        remain = math.max(0, 21600 - (now - v.CreationTime))
                    end
                end

                if remain then
                    if remain <= 0 then
                        readyToClaim = true
                        minRemaining = 0
                    else
                        if remain < minRemaining then minRemaining = remain end
                    end
                end
            end
        end
    end

    if minRemaining == math.huge then minRemaining = 0 end
    return {
        enrolled = enrolled,
        maxSlots = math.max(10, maxSlots),
        readyToClaim = readyToClaim,
        minRemaining = minRemaining
    }
end

function Daycare.getPetPower(p)
    if type(p) ~= "table" or type(p.id) ~= "string" then return 0 end
    if Net.isfn(G.PetCmds, "GetPower") then
        local ok, pow = Net.gcall(G.PetCmds.GetPower, p)
        if ok and type(pow) == "number" then return pow end
    end
    if Net.isfn(G.PetCmds, "GetStrength") then
        local ok, str = Net.gcall(G.PetCmds.GetStrength, p)
        if ok and type(str) == "number" then return str end
    end
    local basePower = 1
    local dir = (G.Directory and G.Directory.Pets and G.Directory.Pets[p.id]) or (G.Pets and G.Pets[p.id])
    if type(dir) == "table" then
        basePower = tonumber(dir.strength or dir.power or dir.damage or dir.BaseDamage) or 1
    end
    local mult = 1
    if p.pt == 1 then mult = mult * 1.5
    elseif p.pt == 2 then mult = mult * 2.5
    end
    if p.sh == true then mult = mult * 2.0
    end
    return basePower * mult
end

function Daycare.checkAndRunDaycare(state)
    if not Config.AutoDaycare then
        state.daycareStatus = "Đã tắt (Config)"
        return
    end
    if state.excursion ~= nil then return end

    local now = os.clock()
    if now < (state.nextDaycareCheckAt or 0) then return end
    state.nextDaycareCheckAt = now + 40

    local dcInfo = Daycare.getDaycareInfo()
    local slotsOpen = dcInfo.maxSlots - dcInfo.enrolled

    local needClaim = dcInfo.readyToClaim or (dcInfo.enrolled > 0 and dcInfo.minRemaining <= 0)
    local needEnroll = slotsOpen > 0

    if not (needClaim or needEnroll) then
        if dcInfo.enrolled > 0 then
            local remMins = math.ceil(dcInfo.minRemaining / 60)
            local hrs = math.floor(remMins / 60)
            local mins = remMins % 60
            if hrs > 0 then
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dh %dp)", dcInfo.enrolled, dcInfo.maxSlots, hrs, mins)
            else
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dp)", dcInfo.enrolled, dcInfo.maxSlots, mins)
            end
        end
        return
    end

    local s = Net.getSave()
    local pets = s and s.Inventory and s.Inventory.Pet
    local candidates = {}
    if needEnroll and type(pets) == "table" then
        local equippedSet = {}
        if Net.isfn(G.PetCmds, "GetEquipped") then
            local okEq, eqList = Net.gcall(G.PetCmds.GetEquipped)
            if okEq and type(eqList) == "table" then
                for _, eqUid in pairs(eqList) do
                    if type(eqUid) == "string" then equippedSet[eqUid] = true end
                end
            end
        end
        if type(s and s.EquippedPets) == "table" then
            for _, eqUid in pairs(s.EquippedPets) do
                if type(eqUid) == "string" then equippedSet[eqUid] = true end
            end
        end
        if petEuidsFn then
            for _, activePet in ipairs(petEuidsFn()) do
                if activePet ~= nil then equippedSet[tostring(activePet)] = true end
            end
        end

        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") ~= nil)
                local isTitanic = (p.id:find("Titanic ") ~= nil)
                local isExclusive = (p.id:find("Exclusive") ~= nil)
                local isLocked = (p.lk == true or p._lk == true or p.Locked == true)
                local isEquipped = (p._eq == true or p.eq == true or equippedSet[uid] == true)

                if not (isHuge or isTitanic or isExclusive or isLocked or isEquipped) then
                    table.insert(candidates, {
                        uid = uid,
                        id = p.id,
                        power = Daycare.getPetPower(p)
                    })
                end
            end
        end

        if #candidates > 1 then
            table.sort(candidates, function(a, b)
                return (a.power or 0) > (b.power or 0)
            end)
        end
    end

    if not needClaim and #candidates == 0 then
        if dcInfo.enrolled == 0 then
            state.daycareStatus = "Hết pet thường để gửi"
        end
        return
    end

    local savedPos = Net.playerPos()
    local stand = Daycare.daycareStandPos()
    if not stand then return end

    state.excursion = "Daycare"
    state.daycareStatus = "Đang tới bục Daycare..."
    Net.teleportTo(stand)
    task.wait(0.5)

    pcall(function()
        Net.netFire("Machines: Mark Approached", "Daycare")
    end)
    task.wait(0.2)

    -- 1. Nhận quà Daycare
    if needClaim then
        state.daycareStatus = "Đang nhận quà Daycare..."
        local sBefore = Net.getSave()
        local diaBefore = 0
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Currency) == "table" then
            for _, v in pairs(sBefore.Inventory.Currency) do
                if type(v) == "table" and v.id == "Diamonds" then diaBefore = tonumber(v._am) or 0 end
            end
        end

        local petsBefore = {}
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Pet) == "table" then
            for uid, p in pairs(sBefore.Inventory.Pet) do
                if type(p) == "table" then petsBefore[uid] = true end
            end
        end

        local eggsBefore = {}
        if type(sBefore and sBefore.Inventory and sBefore.Inventory.Egg) == "table" then
            for uid, e in pairs(sBefore.Inventory.Egg) do
                if type(e) == "table" and e.id then
                    eggsBefore[e.id] = (eggsBefore[e.id] or 0) + (tonumber(e._am) or 1)
                end
            end
        end

        local okC = false
        local claimData = nil
        if Net.isfn(G.DaycareCmds, "Claim") then
            local ok, res = Net.gcall(G.DaycareCmds.Claim)
            if ok and res then
                okC = true
                claimData = res
            end
        end
        if not okC then
            local ok, res = Net.netInvoke("Daycare: Claim")
            if ok and res then
                okC = true
                claimData = res
            end
        end

        if okC then
            task.wait(0.6)
            dcInfo = Daycare.getDaycareInfo()
            slotsOpen = dcInfo.maxSlots - dcInfo.enrolled

            local sAfter = Net.getSave()
            local diaAfter = 0
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Currency) == "table" then
                for _, v in pairs(sAfter.Inventory.Currency) do
                    if type(v) == "table" and v.id == "Diamonds" then diaAfter = tonumber(v._am) or 0 end
                end
            end
            local diaGained = math.max(0, diaAfter - diaBefore)

            local hugeFound = {}
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Pet) == "table" then
                for uid, p in pairs(sAfter.Inventory.Pet) do
                    if type(p) == "table" and not petsBefore[uid] then
                        local isHuge = (p.IsHuge and p:IsHuge()) or (type(p.id) == "string" and p.id:find("Huge "))
                        if isHuge then
                            local hName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. tostring(p.id)
                            table.insert(hugeFound, hName)
                        end
                    end
                end
            end

            local eggsFound = {}
            if type(sAfter and sAfter.Inventory and sAfter.Inventory.Egg) == "table" then
                for uid, e in pairs(sAfter.Inventory.Egg) do
                    if type(e) == "table" and e.id then
                        local oldAmt = eggsBefore[e.id] or 0
                        local newAmt = tonumber(e._am) or 1
                        if newAmt > oldAmt then
                            table.insert(eggsFound, string.format("%dx %s", newAmt - oldAmt, tostring(e.id)))
                        end
                    end
                end
            end

            if type(claimData) == "table" then
                for _, item in pairs(claimData) do
                    if type(item) == "table" then
                        local id = tostring(item.id or item.Id or "")
                        if id:find("Huge ") and #hugeFound == 0 then
                            table.insert(hugeFound, id)
                        elseif (id:find("Egg") or item.Class == "Egg") and #eggsFound == 0 then
                            table.insert(eggsFound, string.format("%dx %s", tonumber(item._am or item.Amount) or 1, id))
                        end
                    end
                end
            end

            -- Bắn Webhook chỉ khi có Meebo in a Spaceship hoặc Gargantuan Machine Hippomelon Egg
            pcall(function()
                local targetHugeFound = {}
                for _, h in ipairs(hugeFound) do
                    local strH = tostring(h)
                    if strH:find("Meebo in a Spaceship") or strH:find("Meebo") or strH:find("Huge ") then
                        table.insert(targetHugeFound, strH)
                    end
                end

                local targetEggFound = {}
                for _, e in ipairs(eggsFound) do
                    local strE = tostring(e)
                    if strE:find("Gargantuan Machine Hippomelon Egg") or strE:find("Hippomelon") or strE:find("Gargantuan") then
                        table.insert(targetEggFound, strE)
                    end
                end

                local playerName = game:GetService("Players").LocalPlayer.Name

                if #targetHugeFound > 0 then
                    Webhook.sendWebhook(
                        "🚨🚨 [NỔ HUGE DAYCARE: MEEBO IN A SPACESHIP] 🚨🚨",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "🎉 **PET NỔ:** **%s**\n" ..
                            "💎 **Gems thu hoạch:** `+%s Gems`",
                            playerName,
                            table.concat(targetHugeFound, ", "),
                            Net.shorten(diaGained)
                        ),
                        0xFFD700,
                        Config.Webhook and Config.Webhook.EventsUrl
                    )
                elseif #targetEggFound > 0 then
                    Webhook.sendWebhook(
                        "🥚🔥 [TRÚNG TRỨNG GARGANTUAN HIPPOMELON TỪ DAYCARE] 🔥🥚",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "📦 **TRỨNG ĐỈNH:** **%s**\n" ..
                            "💎 **Gems thu hoạch:** `+%s Gems`",
                            playerName,
                            table.concat(targetEggFound, ", "),
                            Net.shorten(diaGained)
                        ),
                        0x00E676,
                        Config.Webhook and Config.Webhook.EventsUrl
                    )
                end
            end)
        end
    end

    -- 2. Gửi pet vào slot trống
    if slotsOpen > 0 and #candidates > 0 then
        local toEnrollDict = {}
        local count = math.min(slotsOpen, #candidates)
        for i = 1, count do
            toEnrollDict[candidates[i].uid] = 1
        end

        state.daycareStatus = string.format("Đang gửi %d pet...", count)
        local okE = false
        local errReason = nil

        local ok, res = Net.netInvoke("Daycare: Enroll", toEnrollDict)
        if ok and res == true then
            okE = true
        else
            errReason = tostring(res)
            if Net.isfn(G.DaycareCmds, "Enroll") then
                local ok2, res2 = Net.gcall(G.DaycareCmds.Enroll, toEnrollDict)
                if ok2 and res2 then okE = true else errReason = tostring(res2) end
            end
        end

        if okE then
            state.daycareStatus = string.format("Đã gửi %d pet vào Daycare", count)
            task.wait(0.5)
            dcInfo = Daycare.getDaycareInfo()
        else
            state.daycareStatus = "Gửi thất bại (" .. tostring(errReason or "Từ chối") .. ")"
        end
    end

    if savedPos and state.alive then
        Net.teleportTo(savedPos)
    end
    state.excursion = nil

    if dcInfo.enrolled > 0 then
        if dcInfo.minRemaining > 0 then
            local remMins = math.ceil(dcInfo.minRemaining / 60)
            local hrs = math.floor(remMins / 60)
            local mins = remMins % 60
            if hrs > 0 then
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dh %dp)", dcInfo.enrolled, dcInfo.maxSlots, hrs, mins)
            else
                state.daycareStatus = string.format("Đang gửi %d/%d (còn %dp)", dcInfo.enrolled, dcInfo.maxSlots, mins)
            end
        else
            state.daycareStatus = string.format("Đang gửi %d/%d (Đã xong, chờ nhận)", dcInfo.enrolled, dcInfo.maxSlots)
        end
    elseif slotsOpen > 0 and (state.daycareStatus == "Rảnh" or state.daycareStatus == "Đang tải...") then
        state.daycareStatus = string.format("Trống %d/%d slot", slotsOpen, dcInfo.maxSlots)
    end
end

return Daycare
