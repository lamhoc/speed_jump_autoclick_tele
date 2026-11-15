-- =========================================================================
-- PS99_KizHub/PumpkinTycoonKaitun/TycoonFarm.lua
-- Module điều khiển Farm bãi, di chuyển né nước, phá Bí Ngô Khổng Lồ và mua nút
-- Tác giả: VANTA [JHON369] | KizHub Automation Engine
-- =========================================================================

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TycoonFarm = {}

-- Dependencies
local Modules = nil
local Network = nil
local Config = nil
local K = nil
local Webhook = nil
local inEventFn = nil
local instanceModelFn = nil

-- Cache Client Modules của Tycoon
local IslandCmds = nil
local PTButtons = nil
local ButtonsCmds = nil
local ClientPlot = nil
local BreakableFrontend = nil
local AutoFarmCmds = nil
local PlayerPet = nil

local function safeRequire(pathTbl)
    local cur = ReplicatedStorage
    for _, part in ipairs(pathTbl) do
        cur = cur and cur:FindFirstChild(part)
        if not cur then break end
    end
    if cur and cur:IsA("ModuleScript") then
        local ok, res = pcall(require, cur)
        if ok and res then return res end
    end

    -- Fallback: Tìm đệ quy theo tên module
    local targetName = pathTbl[#pathTbl]
    if targetName then
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local found = lib and lib:FindFirstChild(targetName, true)
        if not found then
            found = ReplicatedStorage:FindFirstChild(targetName, true)
        end
        if found and found:IsA("ModuleScript") then
            local ok, res = pcall(require, found)
            if ok and res then return res end
        end
    end
    return nil
end

local function initGameLibs()
    if not IslandCmds then
        IslandCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Island" })
    end
    if not PTButtons then
        PTButtons = safeRequire({ "Library", "Util", "PumpkinTycoonButtons" })
    end
    if not ButtonsCmds then
        ButtonsCmds = safeRequire({ "Library", "Client", "PumpkinTycoonCmds", "Buttons" })
    end
    if not BreakableFrontend then
        BreakableFrontend = safeRequire({ "Library", "Client", "BreakableFrontend" })
    end
    if not AutoFarmCmds then
        AutoFarmCmds = safeRequire({ "Library", "Client", "AutoFarmCmds" })
    end
    if not PlayerPet then
        PlayerPet = safeRequire({ "Library", "Client", "PlayerPet" })
    end
end

function TycoonFarm.init(deps)
    Modules = deps.Modules
    Network = deps.Network
    Config = deps.Config
    K = deps.K
    Webhook = deps.Webhook
    inEventFn = deps.inEvent
    instanceModelFn = deps.instanceModel
    initGameLibs()

    if Config and Config.InfinitePetSpeed ~= false then
        TycoonFarm.installInfinitePetSpeed()
    end
end

-- =========================================================================
-- 0. INFINITE PET SPEED (DI CHUYỂN SIÊU TỐC TỨC THÌ ĐẬP QUẶNG & BÍ NGÔ)
-- =========================================================================

local isPetSpeedInstalled = false
function TycoonFarm.installInfinitePetSpeed()
    if isPetSpeedInstalled then return end
    isPetSpeedInstalled = true

    task.spawn(function()
        local mult = (Config and Config.PetSpeedMultiplier) or 999999
        for attempt = 1, 30 do
            local hooked = false
            pcall(function()
                initGameLibs()
                local pp = (Modules and Modules.G and Modules.G.PlayerPet) or PlayerPet or safeRequire({ "Library", "Client", "PlayerPet" })
                if type(pp) == "table" and type(pp.CalculateSpeedMultiplier) == "function" then
                    if type(hookfunction) == "function" then
                        local orig = nil
                        orig = hookfunction(pp.CalculateSpeedMultiplier, function(...)
                            return mult
                        end)
                        hooked = true
                    else
                        pp.CalculateSpeedMultiplier = function(...)
                            return mult
                        end
                        hooked = true
                    end
                end
            end)

            if hooked then
                print(string.format("[KizHub Tycoon] ⚡ ĐÃ KÍCH HOẠT INFINITE PET SPEED (Multiplier: %s)!", tostring(mult)))
                break
            end
            task.wait(1.0)
        end
    end)
end

-- =========================================================================
-- 1. TRUY VẤN PLOT VÀ MÔ HÌNH ĐẢO CỦA NGƯỜI CHƠI
-- =========================================================================

local lastIslandInitAttempt = 0

function TycoonFarm.getPlot()
    initGameLibs()
    if ClientPlot and type(ClientPlot.GetByPlayer) == "function" then
        local ok, plot = pcall(ClientPlot.GetByPlayer, LocalPlayer)
        if ok and plot and not (type(plot.IsDestroyed) == "function" and plot:IsDestroyed()) then
            return plot
        end
    end
    if IslandCmds and type(IslandCmds.Plot) == "function" then
        local ok, plot = pcall(IslandCmds.Plot)
        if ok and plot then return plot end
    end

    -- Thử kích hoạt đảo qua IslandCmds nếu client chưa khởi tạo (throttle 3s)
    local now = os.clock()
    if (now - lastIslandInitAttempt >= 3) and IslandCmds then
        lastIslandInitAttempt = now
        pcall(function()
            if type(IslandCmds.OnJoin) == "function" then
                IslandCmds.OnJoin()
            end
            if type(IslandCmds.GetTeleport) == "function" then
                IslandCmds.GetTeleport()
            end
        end)
        if ClientPlot and type(ClientPlot.GetByPlayer) == "function" then
            local ok, plot = pcall(ClientPlot.GetByPlayer, LocalPlayer)
            if ok and plot and not (type(plot.IsDestroyed) == "function" and plot:IsDestroyed()) then
                return plot
            end
        end
        if IslandCmds and type(IslandCmds.Plot) == "function" then
            local ok, plot = pcall(IslandCmds.Plot)
            if ok and plot then return plot end
        end
    end

    -- Fallback 1: tìm trong workspace.__THINGS.Plots theo UserId hoặc Player / OwnerUsername
    local things = workspace:FindFirstChild("__THINGS")
    local plots = things and (things:FindFirstChild("Plots") or things:FindFirstChild("PumpkinTycoonPlots") or things:FindFirstChild("TycoonPlots"))
    if plots and LocalPlayer then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:GetAttribute("Owner") or p:GetAttribute("OwnerUsername") or p:GetAttribute("UserId") or p:GetAttribute("Player") or p:GetAttribute("OwnerId")
            if owner and (owner == LocalPlayer.UserId or owner == LocalPlayer.Name or tostring(owner) == tostring(LocalPlayer.UserId) or tostring(owner) == tostring(LocalPlayer.Name)) then
                return p
            end
        end

        -- Fallback 2: match plot whose SpawnPosition is closest to hrp.Position
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = hrp and hrp.Position or Vector3.zero
        local closestDist = math.huge
        local closestModel = nil
        for _, p in ipairs(plots:GetChildren()) do
            if p:IsA("Model") then
                local spawnPos = p:GetAttribute("SpawnPosition")
                local pPos = nil
                if typeof(spawnPos) == "Vector3" then
                    pPos = spawnPos
                elseif typeof(spawnPos) == "CFrame" then
                    pPos = spawnPos.Position
                else
                    local spawnPart = p:FindFirstChild("Spawn", true) or p:FindFirstChild("SpawnLocation", true)
                    if spawnPart and spawnPart:IsA("BasePart") then
                        pPos = spawnPart.Position
                    else
                        pPos = p:GetPivot().Position
                    end
                end
                if pPos then
                    local dist = (pPos - myPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestModel = p
                    end
                end
            end
        end
        if closestModel then return closestModel end
    end

    -- Fallback 3: Tìm trong Instances
    local instances = things and things:FindFirstChild("Instances")
    local inst = instances and instances:FindFirstChild(K.INSTANCE_ID or "PumpkinTycoon")
    if inst then return inst end

    return nil
end

function TycoonFarm.getPlotModel()
    local plot = TycoonFarm.getPlot()
    if plot then
        if type(plot.GetModel) == "function" then
            local ok, m = pcall(plot.GetModel, plot)
            if ok and m and m:IsA("Model") then return m end
        elseif typeof(plot) == "Instance" and plot:IsA("Model") then
            return plot
        end
    end

    local things = workspace:FindFirstChild("__THINGS")
    if things then
        for _, folderName in ipairs({ "Plots", "PumpkinTycoonPlots", "TycoonPlots", "Tycoons" }) do
            local folder = things:FindFirstChild(folderName)
            if folder then
                if plot and type(plot.GetId) == "function" then
                    local pId = tostring(plot:GetId())
                    if folder:FindFirstChild(pId) then return folder:FindFirstChild(pId) end
                end
                if LocalPlayer then
                    for _, p in ipairs(folder:GetChildren()) do
                        local owner = p:GetAttribute("Owner") or p:GetAttribute("OwnerUsername") or p:GetAttribute("UserId") or p:GetAttribute("Player")
                        if owner and (owner == LocalPlayer.UserId or owner == LocalPlayer.Name or tostring(owner) == tostring(LocalPlayer.UserId) or tostring(owner) == tostring(LocalPlayer.Name)) then
                            return p
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- =========================================================================
-- 2. HỆ THỐNG DI CHUYỂN NÉ NƯỚC & NHẢY CHƯỚNG NGẠI VẬT (RAGE & LEGIT)
-- =========================================================================

local function getCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

function TycoonFarm.moveTo(targetPosOrCF)
    if not targetPosOrCF then return end
    local targetPos = typeof(targetPosOrCF) == "CFrame" and targetPosOrCF.Position or targetPosOrCF

    local char, hrp, hum = getCharacterParts()
    if not hrp or not hum then return end

    if hum.Sit then hum.Sit = false end
    if hum.PlatformStand then hum.PlatformStand = false end

    local cf = typeof(targetPosOrCF) == "CFrame" and targetPosOrCF or CFrame.new(targetPos + Vector3.new(0, 2.5, 0))

    -- Teleport tức thì, chống rơi rụng hoặc lag vật lý
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        char:PivotTo(cf)
        hrp.CFrame = cf
    end)
    pcall(function()
        if Network and type(Network.teleportTo) == "function" then
            Network.teleportTo(cf)
        end
    end)
end

-- =========================================================================
-- 3. QUẢN LÝ QUY TẮC AUTOBREAK, PEDESTAL VÀ AUTO FARM SỰ KIỆN
-- =========================================================================

function TycoonFarm.getPlotPivot()
    local plot = TycoonFarm.getPlot()
    -- 1. Ưu tiên tuyệt đối: plot:GetModel():GetPivot() (khớp 100% logic get_pos.lua đo 5 bãi farm)
    if plot then
        if type(plot.GetModel) == "function" then
            local okM, m = pcall(plot.GetModel, plot)
            if okM and m and m:IsA("Model") then
                return m:GetPivot()
            end
        end
        if typeof(plot) == "Instance" and plot:IsA("Model") then
            return plot:GetPivot()
        end
    end

    -- 2. Fallback: plotModel:GetPivot()
    local plotModel = TycoonFarm.getPlotModel()
    if plotModel and typeof(plotModel) == "Instance" and plotModel:IsA("Model") then
        return plotModel:GetPivot()
    end

    -- 3. Fallback: plot:GetCFrame()
    if plot and type(plot.GetCFrame) == "function" then
        local ok, cf = pcall(plot.GetCFrame, plot)
        if ok and typeof(cf) == "CFrame" and cf.Position.Magnitude > 0 then
            return cf
        end
    end

    -- 4. Fallback: tìm trong workspace.__THINGS.Plots model có SpawnPosition gần nhất
    local things = workspace:FindFirstChild("__THINGS")
    local plots = things and (things:FindFirstChild("Plots") or things:FindFirstChild("PumpkinTycoonPlots") or things:FindFirstChild("TycoonPlots"))
    if plots then
        local char = LocalPlayer and LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = hrp and hrp.Position or Vector3.zero
        local closestDist = math.huge
        local closestCf = nil
        for _, p in ipairs(plots:GetChildren()) do
            if p:IsA("Model") then
                local spawnPos = p:GetAttribute("SpawnPosition")
                local pPos = (typeof(spawnPos) == "Vector3" and spawnPos) or (typeof(spawnPos) == "CFrame" and spawnPos.Position) or p:GetPivot().Position
                local dist = (pPos - myPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestCf = p:GetPivot()
                end
            end
        end
        if closestCf then return closestCf end
    end

    return nil
end

function TycoonFarm.getPlotCFrame()
    return TycoonFarm.getPlotPivot()
end

local FARM_AREAS = {
    [5] = {
        name = "Area 5 (Golden Grove)",
        displayName = "Golden Grove",
        offset = Vector3.new(201.46, 0.36, -60.86),
        zoneAliases = { "GoldenGrove_Zone", "GoldenGrove_Egg", "GoldenGrove_Breakables", "GoldenGrove", "Zone_5", "Zone5", "Golden_Grove" },
        pedIndex = 5,
    },
    [4] = {
        name = "Area 4 (Cider Mill)",
        displayName = "Cider Mill",
        offset = Vector3.new(-70.41, 5.72, -300.74),
        zoneAliases = { "CiderMill_Zone", "CiderMill_Egg", "CiderMill_Breakables", "CiderMill", "Zone_4", "Zone4", "Cider_Mill" },
        pedIndex = 4,
    },
    [3] = {
        name = "Area 3 (Hayride Hill)",
        displayName = "Hayride Hill",
        offset = Vector3.new(-198.58, 0.08, -50.60),
        zoneAliases = { "HayrideHill_Zone", "HayrideHill_Egg", "HayrideHill_Breakables", "HayrideHill", "Zone_3", "Zone3", "Hayride_Hill" },
        pedIndex = 3,
    },
    [2] = {
        name = "Area 2 (Apple Orchard)",
        displayName = "Apple Orchard",
        offset = Vector3.new(-138.68, 4.63, 161.97),
        zoneAliases = { "AppleOrchard_Zone", "AppleOrchard_Egg", "AppleOrchard_Breakables", "AppleOrchard", "Zone_2", "Zone2", "Apple_Orchard" },
        pedIndex = 2,
    },
    [1] = {
        name = "Area 1 (Cocoa Cabin)",
        displayName = "Cocoa Cabin",
        offset = Vector3.new(183.04, 3.86, 125.91),
        zoneAliases = { "CocoaCabin_Zone", "CocoaCabin_Egg", "CocoaCabin", "Zone_1", "Zone1" },
        pedIndex = 1,
    },
}

function TycoonFarm.getActiveAreaIndex()
    if Config and Config.ForceZone then
        return tonumber(Config.ForceZone) or 1
    end

    local plot = TycoonFarm.getPlot()
    if not plot then return 1 end

    initGameLibs()

    -- 1. Lấy trạng thái buttons từ IslandCmds.Get(nil, "Buttons") trước, fallback plot:Save("Buttons")
    local buttonsState = {}
    pcall(function()
        if IslandCmds and type(IslandCmds.Get) == "function" then
            buttonsState = IslandCmds.Get(nil, "Buttons") or {}
        end
    end)
    if not buttonsState or not next(buttonsState) then
        pcall(function()
            if plot and type(plot.Save) == "function" then
                buttonsState = plot:Save("Buttons") or {}
            end
        end)
    end
    if not buttonsState or not next(buttonsState) then
        pcall(function()
            local s = Network.getSave and Network.getSave()
            if s and s.PumpkinTycoon and type(s.PumpkinTycoon.Buttons) == "table" then
                buttonsState = s.PumpkinTycoon.Buttons
            end
        end)
    end

    local function isButtonOwned(btnId)
        if not btnId then return false end
        if buttonsState[btnId] == true or buttonsState[btnId] == 1 then return true end
        if PTButtons and type(PTButtons.Owned) == "function" then
            local okO, resO = pcall(PTButtons.Owned, buttonsState, btnId)
            if okO and resO == true then return true end
        end
        return false
    end

    -- 2. Quét từ bãi cao nhất (Bãi 5) xuống bãi 2: Kiểm tra nút Zone/Egg đã mua (tuyệt đối KHÔNG tính nút Path)
    for zoneIdx = 5, 2, -1 do
        local area = FARM_AREAS[zoneIdx]
        if area and area.zoneAliases then
            for _, alias in ipairs(area.zoneAliases) do
                if isButtonOwned(alias) then
                    return zoneIdx
                end
            end
        end
    end

    -- 3. Fallback: Nếu nhân vật đang đứng tại khu vực bãi farm nào thì giữ nguyên bãi đó
    local char, hrp = getCharacterParts()
    local plotPivot = TycoonFarm.getPlotPivot()
    if hrp and plotPivot then
        for zoneIdx = 5, 2, -1 do
            local area = FARM_AREAS[zoneIdx]
            if area and area.offset then
                local worldPos = plotPivot:PointToWorldSpace(area.offset)
                if (hrp.Position - worldPos).Magnitude <= 70 then
                    return zoneIdx
                end
            end
        end
    end

    return 1
end

local function getBrkData(k, v)
    local brkObj = (type(v) == "table" and v) or (type(k) == "table" and k) or {}
    local uid = brkObj.uid or (type(k) == "string" and k) or (type(v) == "string" and v) or (brkObj.model and brkObj.model.Name)
    local model = brkObj.model or (typeof(v) == "Instance" and v) or (typeof(k) == "Instance" and k)
    local parentID = brkObj.parentID or (model and model:GetAttribute("ParentID"))
    local pos = brkObj.position or (model and model:GetPivot().Position) or (brkObj.GetPosition and brkObj:GetPosition())
    local clientAttrs = brkObj.clientAttributes or (model and model:GetAttributes()) or {}
    return {
        uid = uid,
        model = model,
        parentID = parentID,
        position = pos,
        clientAttributes = clientAttrs,
    }
end

local lastActiveAreaIndex = nil

function TycoonFarm.getSweetPos()
    local areaIdx = TycoonFarm.getActiveAreaIndex()
    local areaData = FARM_AREAS[areaIdx] or FARM_AREAS[1]

    local plotPivot = TycoonFarm.getPlotPivot()
    if not plotPivot then return nil end

    -- Trực tiếp chuyển đổi Relative Offset qua ma trận xoay của Plot, giữ nguyên 100% toạ độ đã lưu
    return plotPivot:PointToWorldSpace(areaData.offset)
end

function TycoonFarm.ensureAutoFarmEnabled(state, sweetPos)
    pcall(function()
        if not AutoFarmCmds then
            AutoFarmCmds = safeRequire({ "Library", "Client", "AutoFarmCmds" })
        end
        if AutoFarmCmds and type(AutoFarmCmds.IsEnabled) == "function" then
            if not AutoFarmCmds.IsEnabled() then
                if type(AutoFarmCmds.Enable) == "function" then
                    AutoFarmCmds.Enable()
                end
                Network.netInvoke("AutoFarm_Enable", true)
            end
            if sweetPos then
                Network.netFire("AutoFarm_LogPosition", sweetPos)
            end
            if state then
                state.autoFarmActive = AutoFarmCmds.IsEnabled()
            end
        else
            Network.netInvoke("AutoFarm_Enable", true)
            if sweetPos then
                Network.netFire("AutoFarm_LogPosition", sweetPos)
            end
            if state then state.autoFarmActive = true end
        end
    end)
end

function TycoonFarm.toggleAutoFarmReset(sweetPos)
    pcall(function()
        if not AutoFarmCmds then
            AutoFarmCmds = safeRequire({ "Library", "Client", "AutoFarmCmds" })
        end

        -- 1. BƯỚC 1: TẮT AUTOFARM ĐANG CHẠY ĐỂ HUỶ ANCHOR QUẶNG BÃI CŨ
        local wasEnabled = false
        if AutoFarmCmds and type(AutoFarmCmds.IsEnabled) == "function" then
            wasEnabled = AutoFarmCmds.IsEnabled()
        end

        -- Tắt bằng tất cả các hàm có thể của AutoFarmCmds
        if AutoFarmCmds then
            if type(AutoFarmCmds.Disable) == "function" then
                pcall(AutoFarmCmds.Disable)
            elseif wasEnabled and type(AutoFarmCmds.Toggle) == "function" then
                pcall(AutoFarmCmds.Toggle)
            elseif type(AutoFarmCmds.Set) == "function" then
                pcall(AutoFarmCmds.Set, false)
            end
        end

        pcall(function() Network.netInvoke("AutoFarm_Enable", false) end)
        pcall(function() Network.netFire("AutoFarm_Enable", false) end)
        pcall(function() Network.netInvoke("AutoFarm: Enable", false) end)
        pcall(function() Network.netFire("AutoFarm: Enable", false) end)
        pcall(function() Network.netInvoke("AutoFarm: Toggle", false) end)
        pcall(function() Network.netFire("AutoFarm: Toggle", false) end)

        task.wait(0.3)

        -- 2. BƯỚC 2: BẬT LẠI AUTOFARM CHO BÃI MỚI VÀ GHI NHẬN TÂM BÃI MỚI
        local isNowEnabled = false
        if AutoFarmCmds and type(AutoFarmCmds.IsEnabled) == "function" then
            isNowEnabled = AutoFarmCmds.IsEnabled()
        end

        if AutoFarmCmds then
            if type(AutoFarmCmds.Enable) == "function" then
                pcall(AutoFarmCmds.Enable)
            elseif (not isNowEnabled) and type(AutoFarmCmds.Toggle) == "function" then
                pcall(AutoFarmCmds.Toggle)
            elseif type(AutoFarmCmds.Set) == "function" then
                pcall(AutoFarmCmds.Set, true)
            end
        end

        pcall(function() Network.netInvoke("AutoFarm_Enable", true) end)
        pcall(function() Network.netFire("AutoFarm_Enable", true) end)
        pcall(function() Network.netInvoke("AutoFarm: Enable", true) end)
        pcall(function() Network.netFire("AutoFarm: Enable", true) end)
        pcall(function() Network.netInvoke("AutoFarm: Toggle", true) end)
        pcall(function() Network.netFire("AutoFarm: Toggle", true) end)

        if sweetPos then
            pcall(function() Network.netFire("AutoFarm_LogPosition", sweetPos) end)
            pcall(function() Network.netInvoke("AutoFarm_LogPosition", sweetPos) end)
        end

        print(string.format("[KizHub Tycoon] 🔄 ĐÃ TẮT ĐI BẬT LẠI AUTOFARM TẠI BÃI MỚI (Tọa độ: %s)", tostring(sweetPos)))
    end)
end

function TycoonFarm.ensureAutoBreakZero()
    local plot = TycoonFarm.getPlot()
    if not plot then return end

    local sweetPos = TycoonFarm.getSweetPos()
    TycoonFarm.ensureAutoFarmEnabled(nil, sweetPos)

    pcall(function()
        local autoBreak = plot:Save("AutoBreak")
        if type(autoBreak) == "table" and autoBreak.Below ~= 0 then
            plot:Invoke(K.VERBS.AutoBreakPolicy, 0)
        end
    end)

    pcall(function()
        local pedestals = plot:Save("Pedestals")
        if type(pedestals) == "table" then
            for idx, ped in pairs(pedestals) do
                if type(ped) == "table" and ped.Locked == true then
                    plot:Invoke(K.VERBS.PedestalShelter, tonumber(idx) or idx, false)
                end
            end
        end
    end)
end

-- =========================================================================
-- 4. TRUY TÌM VÀ PHÁ BÍ NGÔ KHỔNG LỒ (BIG PUMPKIN) ƯU TIÊN CAO NHẤT
-- =========================================================================

local function getPlayerPets()
    local pets = {}
    pcall(function()
        local pp = (Modules and Modules.G and Modules.G.PlayerPet) or PlayerPet or safeRequire({ "Library", "Client", "PlayerPet" })
        if pp and type(pp.GetByPlayer) == "function" then
            local pList = pp.GetByPlayer(LocalPlayer)
            if type(pList) == "table" then
                for _, p in pairs(pList) do
                    table.insert(pets, p)
                end
            end
        end
    end)
    return pets
end

function TycoonFarm.findActiveBigPumpkin()
    local plot = TycoonFarm.getPlot()
    if not plot then return nil end

    initGameLibs()
    local plotId = plot:GetId()
    local sweetPos = TycoonFarm.getSweetPos()
    if not sweetPos then return nil end

    local activeArea = TycoonFarm.getActiveAreaIndex()
    local bestPumpkin = nil
    local maxRung = -1

    local function checkChest(brk)
        if not brk or not brk.position then return end
        local isTycoon = (brk.parentID == "PumpkinTycoon") or (brk.model and brk.model:GetAttribute("ParentID") == "PumpkinTycoon")
        if not isTycoon then return end

        local distSweet = (brk.position - sweetPos).Magnitude

        -- CHỈ ĐÁNH BÍ NGÔ NẰM TRONG BÃI HIỆN TẠI (distSweet <= 110 studs)
        -- Tuyệt đối không nhắm vào Pedestal 1 (Cocoa Cabin Bậc 1) ở đầu đảo khi đang farm Bãi 2, 3, 4, 5
        if distSweet <= 110 then
            local rung = tonumber(brk.clientAttributes.Rung) or (brk.model and tonumber(brk.model:GetAttribute("Rung"))) or 1
            local petName = brk.clientAttributes.PetName or (brk.model and brk.model:GetAttribute("PetName")) or (brk.model and brk.model.Name)
            if K and K.ROSTER_RUNG and petName and K.ROSTER_RUNG[petName] then
                rung = math.max(rung, K.ROSTER_RUNG[petName])
            end
            local pedIndex = brk.clientAttributes.PumpkinPedestal or brk.clientAttributes.Pedestal or activeArea

            if rung > maxRung then
                maxRung = rung
                bestPumpkin = {
                    uid = brk.uid,
                    model = brk.model,
                    pos = brk.position,
                    pedestalIndex = pedIndex,
                    rung = rung,
                }
            end
        end
    end

    if BreakableFrontend and type(BreakableFrontend.AllByInstanceAndClass) == "function" then
        local ok, chests = pcall(BreakableFrontend.AllByInstanceAndClass, "Chest")
        if ok and type(chests) == "table" then
            for k, v in pairs(chests) do
                checkChest(getBrkData(k, v))
            end
        end
    end

    if not bestPumpkin then
        local things = workspace:FindFirstChild("__THINGS")
        local breakables = things and things:FindFirstChild("Breakables")
        if breakables then
            for _, child in ipairs(breakables:GetChildren()) do
                if child:IsA("Model") and (child:GetAttribute("Chest") or child.Name:find("Chest") or child:GetAttribute("PumpkinPedestal")) then
                    checkChest(getBrkData(child.Name, child))
                end
            end
        end
    end

    return bestPumpkin
end

function TycoonFarm.petEuids()
    local equipped = {}
    pcall(function()
        if Modules and Modules.G and Modules.G.PetCmds and Network.isfn(Modules.G.PetCmds, "GetEquippedItems") then
            local ok, items = Network.gcall(Modules.G.PetCmds.GetEquippedItems)
            if ok and type(items) == "table" then
                for _, it in pairs(items) do
                    if type(it) == "string" then
                        table.insert(equipped, it)
                    elseif type(it) == "table" and type(it.GetUID) == "function" then
                        local okU, uid = pcall(it.GetUID, it)
                        if okU and uid then table.insert(equipped, uid) end
                    elseif type(it) == "table" and it._uid then
                        table.insert(equipped, it._uid)
                    end
                end
            end
        end
        if #equipped == 0 then
            local s = Network.getSave()
            if s and type(s.EquippedPets) == "table" then
                for uid, _ in pairs(s.EquippedPets) do
                    table.insert(equipped, uid)
                end
            end
        end
    end)
    return equipped
end

function TycoonFarm.breakBigPumpkinTick(state)
    if state and state.excursion and state.excursion:find("Bí Ngô") then
        state.excursion = nil
    end
    -- Cơ chế game tự động cho pet đánh bí khổng lồ, script không can thiệp để tránh làm lệch vị trí farm
    return false
end

-- =========================================================================
-- 5. FARM BÃI PATCH ĐẢO ĐƠN NHẤT (SINGLE ISLAND SWEET SPOT)
-- =========================================================================

function TycoonFarm.farmBestPatchTick(state)
    if state and state.excursion and state.excursion:find("Bí Ngô") then
        state.excursion = nil
    end

    local plot = TycoonFarm.getPlot()
    if not plot then return end

    initGameLibs()
    local sweetPos = TycoonFarm.getSweetPos()
    if not sweetPos then return end

    local currentArea = TycoonFarm.getActiveAreaIndex()
    local char, hrp = getCharacterParts()
    local needsAreaReset = false

    -- 1. Nếu nhân vật đứng lệch vị trí bãi farm (> 8 studs) -> Teleport tới tâm bãi farm
    if hrp and (hrp.Position - sweetPos).Magnitude > 8 then
        local dist = (hrp.Position - sweetPos).Magnitude
        TycoonFarm.moveTo(sweetPos)
        -- Nếu cự ly dịch chuyển lớn (> 25 studs): Đánh dấu vừa chuyển sang bãi/đảo mới
        if dist > 25 then
            needsAreaReset = true
        end
    end

    -- 2. Phát hiện chuyển đổi bãi farm (đổi zoneIdx hoặc tele cự ly lớn qua đảo mới):
    -- Tự động Tắt -> Chờ 0.3s -> Bật lại AutoFarm với tọa độ mới để dàn Pet snap sang bãi mới 100%
    if (lastActiveAreaIndex ~= nil and lastActiveAreaIndex ~= currentArea) or needsAreaReset then
        TycoonFarm.toggleAutoFarmReset(sweetPos)
    else
        -- Duy trì Auto Farm liên tục
        TycoonFarm.ensureAutoFarmEnabled(state, sweetPos)
    end
    lastActiveAreaIndex = currentArea

    -- Quét quặng Normal trên đảo từ BreakableFrontend (brk.parentID == "PumpkinTycoon" và cự ly <= 65)
    local targets = {}
    if BreakableFrontend and type(BreakableFrontend.AllByInstanceAndClass) == "function" then
        local ok, normals = pcall(BreakableFrontend.AllByInstanceAndClass, "Normal")
        if ok and type(normals) == "table" then
            for k, v in pairs(normals) do
                local brk = getBrkData(k, v)
                local isTycoon = (brk.parentID == "PumpkinTycoon") or (brk.model and brk.model:GetAttribute("ParentID") == "PumpkinTycoon")
                if isTycoon and brk.position and (brk.position - sweetPos).Magnitude <= 65 then
                    table.insert(targets, brk)
                end
            end
        end
    end

    -- Fallback quét thư mục __THINGS.Breakables
    if #targets == 0 then
        local things = workspace:FindFirstChild("__THINGS")
        local breakables = things and things:FindFirstChild("Breakables")
        if breakables then
            for _, b in ipairs(breakables:GetChildren()) do
                if b:IsA("Model") then
                    local bPos = b:GetPivot().Position
                    if (bPos - sweetPos).Magnitude <= 65 then
                        table.insert(targets, {
                            uid = b.Name,
                            model = b,
                            position = bPos,
                        })
                    end
                end
            end
        end
    end

    -- Đánh phụ bằng tay (Player Click Damage) vào quặng gần nhất trong bãi, TUYỆT ĐỐI KHÔNG can thiệp/khóa mục tiêu của Pet
    -- Toàn bộ Pet (kể cả Huge) được cơ chế AutoFarm chính thức của game tự động dẫn đi đập Bí Ngô Khổng Lồ và tự về bãi
    if #targets > 0 then
        local primary = targets[1]
        if primary and primary.uid then
            pcall(function()
                Network.netFire("Breakables_PlayerDealDamage", tonumber(primary.uid) or primary.uid)
            end)
        end
    end
end

-- =========================================================================
-- 6. TỰ ĐỘNG MUA NÚT TYCOON (CÂN ĐỐI NGÂN SÁCH THÔNG MINH) & NHẬN THƯỞNG ĐẢO
-- =========================================================================

-- Lấy trạng thái toàn bộ nút đã mua từ Game Save / Plot Save / IslandCmds
function TycoonFarm.getButtonsState()
    initGameLibs()
    local plot = TycoonFarm.getPlot()
    local buttonsState = {}
    if plot and type(plot.Save) == "function" then
        pcall(function()
            buttonsState = plot:Save("Buttons") or {}
        end)
    end
    if not buttonsState or not next(buttonsState) then
        pcall(function()
            if IslandCmds and type(IslandCmds.Get) == "function" then
                buttonsState = IslandCmds.Get(nil, "Buttons") or {}
            end
        end)
    end
    if not buttonsState or not next(buttonsState) then
        pcall(function()
            local s = Network.getSave and Network.getSave()
            if s and s.PumpkinTycoon and type(s.PumpkinTycoon.Buttons) == "table" then
                buttonsState = s.PumpkinTycoon.Buttons
            end
        end)
    end
    return buttonsState or {}
end

-- Helper lấy giá chuẩn của nút từ PTButtons / thuộc tính dữ liệu
local function getBtnPrice(btn, priceMult)
    if not btn then return 0 end
    priceMult = priceMult or 1
    if PTButtons and type(PTButtons.Price) == "function" then
        local ok, p = pcall(PTButtons.Price, btn, priceMult)
        if ok and tonumber(p) and tonumber(p) > 0 then return tonumber(p) end
        local ok2, p2 = pcall(PTButtons.Price, 1, btn, priceMult)
        if ok2 and tonumber(p2) and tonumber(p2) > 0 then return tonumber(p2) end
        local ok3, p3 = pcall(PTButtons.Price, btn)
        if ok3 and tonumber(p3) and tonumber(p3) > 0 then return tonumber(p3) end
    end
    return tonumber(btn.Cost or btn.Price or btn.cost or btn.price or 0) or 0
end

-- Quét toàn diện các nút có thể mua: Chuẩn decompiled Pet Simulator 99 (PTButtons.Available zones = 5)
function TycoonFarm.getAvailableButtons(buttonsState, priceMult)
    initGameLibs()
    buttonsState = buttonsState or TycoonFarm.getButtonsState()
    priceMult = priceMult or (ButtonsCmds and type(ButtonsCmds.PriceMult) == "function" and ButtonsCmds.PriceMult()) or 1

    local avail = nil

    -- 1. Chuẩn Decompiled Pet Simulator 99: PTButtons.Available(buttonsState, zones, part2, priceMult)
    if PTButtons and type(PTButtons.Available) == "function" then
        local zones = 5
        local part2 = false
        pcall(function() avail = PTButtons.Available(buttonsState, zones, part2, priceMult) end)
        if not (type(avail) == "table" and #avail > 0) then
            pcall(function() avail = PTButtons.Available(buttonsState, zones, part2) end)
        end
        if not (type(avail) == "table" and #avail > 0) then
            pcall(function() avail = PTButtons.Available(buttonsState, zones) end)
        end
        if not (type(avail) == "table" and #avail > 0) then
            for z = 5, 1, -1 do
                pcall(function()
                    local a = PTButtons.Available(buttonsState, z, false, priceMult)
                    if type(a) == "table" and #a > 0 then avail = a end
                end)
                if type(avail) == "table" and #avail > 0 then break end
            end
        end
        if not (type(avail) == "table" and #avail > 0) then
            pcall(function() avail = PTButtons.Available(buttonsState) end)
        end
    end

    -- 2. Thử qua ButtonsCmds client module
    if not (type(avail) == "table" and #avail > 0) and ButtonsCmds then
        if type(ButtonsCmds.Available) == "function" then
            pcall(function() avail = ButtonsCmds.Available() end)
            if not (type(avail) == "table" and #avail > 0) then
                pcall(function() avail = ButtonsCmds.Available(5) end)
            end
        end
        if not (type(avail) == "table" and #avail > 0) and type(ButtonsCmds.GetAvailable) == "function" then
            pcall(function() avail = ButtonsCmds.GetAvailable() end)
        end
    end

    if type(avail) == "table" and #avail > 0 then
        return avail
    end

    -- 3. Fallback: Quét danh mục containers từ PTButtons
    local unownedList = {}
    local seenIds = {}
    local containers = {}
    if PTButtons then
        table.insert(containers, PTButtons)
        if type(PTButtons.Directory) == "table" then table.insert(containers, PTButtons.Directory) end
        if type(PTButtons.Buttons) == "table" then table.insert(containers, PTButtons.Buttons) end
        if type(PTButtons.All) == "table" then table.insert(containers, PTButtons.All) end
        if type(PTButtons.Islands) == "table" and type(PTButtons.Islands[1]) == "table" then
            table.insert(containers, PTButtons.Islands[1])
            if type(PTButtons.Islands[1].Buttons) == "table" then
                table.insert(containers, PTButtons.Islands[1].Buttons)
            end
        end
    end

    for _, container in ipairs(containers) do
        for k, btn in pairs(container) do
            if type(btn) == "table" then
                local bId = btn.Id or btn.id or btn.ButtonId or (type(k) == "string" and k)
                if bId and type(bId) == "string" and not seenIds[bId] and bId ~= "Buttons" and bId ~= "All" and bId ~= "List" and bId ~= "Directory" and bId ~= "Islands" then
                    seenIds[bId] = true

                    local isOwned = (buttonsState[bId] == true or buttonsState[bId] == 1)
                    if not isOwned and PTButtons and type(PTButtons.Owned) == "function" then
                        local okO, resO = pcall(PTButtons.Owned, buttonsState, bId)
                        if okO and resO == true then isOwned = true end
                    end

                    if not isOwned then
                        local depsMet = true
                        local deps = btn.Dependencies or btn.Depends or btn.Prerequisites or btn.Requirements
                        if type(deps) == "table" then
                            for _, depId in ipairs(deps) do
                                local depOwned = (buttonsState[depId] == true or buttonsState[depId] == 1)
                                if not depOwned and PTButtons and type(PTButtons.Owned) == "function" then
                                    local okD, resD = pcall(PTButtons.Owned, buttonsState, depId)
                                    if okD and resD == true then depOwned = true end
                                end
                                if not depOwned then
                                    depsMet = false
                                    break
                                end
                            end
                        end

                        if depsMet then
                            local bCopy = table.clone and table.clone(btn) or btn
                            bCopy.Id = bId
                            table.insert(unownedList, bCopy)
                        end
                    end
                end
            end
        end
    end

    if #unownedList > 0 then
        return unownedList
    end

    -- 4. Quét trực tiếp các bệ nút (Pads) trong Plot Model trên Workspace
    local plotModel = TycoonFarm.getPlotModel()
    if plotModel then
        for _, desc in ipairs(plotModel:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("BasePart") then
                local bId = desc:GetAttribute("ButtonId") or desc:GetAttribute("Id") or desc:GetAttribute("PadId")
                if not bId and (desc.Name:lower():find("button") or desc.Name:lower():find("pad")) then
                    bId = desc.Name
                end
                if bId and not seenIds[tostring(bId)] then
                    seenIds[tostring(bId)] = true
                    local isOwned = (buttonsState[bId] == true or buttonsState[bId] == 1)
                    if not isOwned then
                        local cost = tonumber(desc:GetAttribute("Cost") or desc:GetAttribute("Price")) or 0
                        table.insert(unownedList, {
                            Id = tostring(bId),
                            Name = tostring(bId):gsub("_", " "),
                            Cost = cost,
                            Price = cost,
                        })
                    end
                end
            end
        end
    end

    return unownedList
end

-- Xác định nút mục tiêu tiếp theo để phân bổ ngân sách
function TycoonFarm.getNextTargetButton(priceMult)
    initGameLibs()
    priceMult = priceMult or (ButtonsCmds and type(ButtonsCmds.PriceMult) == "function" and ButtonsCmds.PriceMult()) or 1
    local buttonsState = TycoonFarm.getButtonsState()
    local avail = TycoonFarm.getAvailableButtons(buttonsState, priceMult)

    if not (type(avail) == "table" and #avail > 0) then
        return nil
    end

    -- 1. Ưu tiên nút Critical / Milestone (Egg, Zone, Path, Pedestal, Machine, IslandLuck)
    for _, btn in ipairs(avail) do
        local id = tostring(btn.Id or "")
        if id:find("Egg") or id:find("Zone") or id:find("Machine") or id:find("Pedestal") or id:find("IslandLuck") or btn.Egg then
            local price = getBtnPrice(btn, priceMult)
            return btn, price, true -- isMilestone = true
        end
    end

    -- 2. Nếu không có nút Milestone: Chọn nút rẻ nhất hiện có
    local cheapestBtn = avail[1]
    local minPrice = getBtnPrice(cheapestBtn, priceMult)
    if minPrice == 0 then minPrice = math.huge end
    for i = 2, #avail do
        local p = getBtnPrice(avail[i], priceMult)
        if p > 0 and p < minPrice then
            cheapestBtn = avail[i]
            minPrice = p
        end
    end

    if minPrice == math.huge then minPrice = 0 end
    return cheapestBtn, minPrice, false
end

-- Quét tìm nút có giá rẻ nhất trong toàn bộ danh sách các nút hiện có thể mua
function TycoonFarm.getCheapestAvailableButton(priceMult)
    initGameLibs()
    priceMult = priceMult or (ButtonsCmds and type(ButtonsCmds.PriceMult) == "function" and ButtonsCmds.PriceMult()) or 1
    local buttonsState = TycoonFarm.getButtonsState()
    local avail = TycoonFarm.getAvailableButtons(buttonsState, priceMult)

    if not (type(avail) == "table" and #avail > 0) then
        return nil
    end

    local cheapestBtn = avail[1]
    local minPrice = getBtnPrice(cheapestBtn, priceMult)
    if minPrice == 0 then minPrice = math.huge end
    for i = 2, #avail do
        local p = getBtnPrice(avail[i], priceMult)
        if p > 0 and p < minPrice then
            cheapestBtn = avail[i]
            minPrice = p
        end
    end

    if minPrice == math.huge then minPrice = 0 end
    return cheapestBtn, minPrice
end

-- Lấy thông tin nút tiếp theo kèm số coin còn thiếu để hiển thị trực quan lên GUI
function TycoonFarm.getNextButtonInfo()
    initGameLibs()
    local priceMult = (ButtonsCmds and type(ButtonsCmds.PriceMult) == "function" and ButtonsCmds.PriceMult()) or 1
    local btn, price, isMilestone = TycoonFarm.getNextTargetButton(priceMult)
    if not btn then
        btn, price = TycoonFarm.getCheapestAvailableButton(priceMult)
    end

    -- Fallback quét trực tiếp nếu còn nút chưa sở hữu
    if not btn then
        local buttonsState = TycoonFarm.getButtonsState()
        local avail = TycoonFarm.getAvailableButtons(buttonsState, priceMult)
        if type(avail) == "table" and #avail > 0 then
            btn = avail[1]
            price = getBtnPrice(btn, priceMult)
        end
    end

    -- Fallback đảm bảo không bao giờ nil nếu đảo chưa xong (owned < total)
    if not btn then
        local prog = TycoonFarm.getTycoonProgress()
        if prog and (prog.ownedButtons or 0) < (prog.totalButtons or 0) then
            local buttonsState = TycoonFarm.getButtonsState()
            local plotModel = TycoonFarm.getPlotModel()
            if PTButtons and type(PTButtons.Directory) == "table" then
                for bId, bData in pairs(PTButtons.Directory) do
                    if type(bData) == "table" and not buttonsState[bId] then
                        btn = bData
                        btn.Id = bId
                        price = getBtnPrice(btn, priceMult)
                        break
                    end
                end
            end
            if not btn and plotModel then
                for _, desc in ipairs(plotModel:GetDescendants()) do
                    local bId = desc:GetAttribute("ButtonId") or desc:GetAttribute("Id")
                    if bId and not buttonsState[bId] then
                        btn = {
                            Id = tostring(bId),
                            Name = tostring(bId):gsub("_", " "),
                            Cost = tonumber(desc:GetAttribute("Cost") or desc:GetAttribute("Price")) or 0,
                        }
                        price = btn.Cost
                        break
                    end
                end
            end
        end
    end

    if not btn then return nil end

    local coins = Network.currency(K.CURRENCY) or 0
    price = tonumber(price) or 0
    local missing = math.max(0, price - coins)

    local rawName = tostring(btn.Display or btn.DisplayName or btn.Title or btn.Name or btn.Id or "Nút")
    local btnName = rawName
    if btnName == btn.Id and btnName:find("_") then
        btnName = btnName:gsub("_", " ")
    end

    return {
        id = btn.Id or "Unknown",
        name = btnName,
        price = price,
        coins = coins,
        missing = missing,
        canAfford = (coins >= price),
        isMilestone = isMilestone or false,
    }
end

-- Hàm thực thi mua nút 4 tầng (Server Verb -> Client Cmd -> Remote -> Physical Pad Touch)
function TycoonFarm.buyButton(btn, price)
    if not btn then return false end
    local btnId = btn.Id or btn.id or (type(btn) == "string" and btn)
    if not btnId then return false end

    initGameLibs()
    local bought = false
    local plot = TycoonFarm.getPlot()
    local plotModel = TycoonFarm.getPlotModel()

    -- Tầng 1: plot:Invoke("NZ_Commit", btnId) (Chuẩn Decompiled Big Games ClientPlot Remote)
    if plot and type(plot.Invoke) == "function" then
        local ok, res = pcall(function()
            return plot:Invoke("NZ_Commit", btnId)
        end)
        if ok and (res == true or (res ~= nil and res ~= false and res ~= 0)) then
            bought = true
        end
        if not bought then
            local verbsToTry = { "BuyButton", "PurchaseButton", "Buy" }
            for _, vName in ipairs(verbsToTry) do
                local ok2, res2 = pcall(function() return plot:Invoke(vName, btnId) end)
                if ok2 and (res2 == true or (res2 ~= nil and res2 ~= false and res2 ~= 0)) then
                    bought = true
                    break
                end
            end
        end
    end

    -- Tầng 2: ButtonsCmds Client Module
    if not bought and ButtonsCmds then
        if type(ButtonsCmds.Buy) == "function" then
            local ok, res = pcall(ButtonsCmds.Buy, btnId)
            if ok and (res == true or (res ~= nil and res ~= false)) then bought = true end
            if not bought then
                pcall(function()
                    local ok2, res2 = pcall(ButtonsCmds.Buy, 1, btnId)
                    if ok2 and (res2 == true or (res2 ~= nil and res2 ~= false)) then bought = true end
                end)
            end
        end
        if not bought and type(ButtonsCmds.Purchase) == "function" then
            local ok, res = pcall(ButtonsCmds.Purchase, btnId)
            if ok and (res == true or (res ~= nil and res ~= false)) then bought = true end
        end
    end

    -- Tầng 3: Network Remote Invoke / Fire
    if not bought then
        pcall(function()
            Network.netInvoke("PumpkinTycoon: Buy Button", btnId)
            Network.netInvoke("PumpkinTycoon_BuyButton", btnId)
            Network.netFire("PumpkinTycoon_BuyButton", btnId)
            Network.netInvoke("Tycoon: Buy Button", btnId)
        end)
    end

    -- Tầng 4: Physical Pad Touch: Dịch chuyển nhân vật đạp trực tiếp lên bệ nút
    pcall(function()
        local char, hrp = getCharacterParts()
        if not hrp then return end

        local padSpot = nil
        if PTButtons and type(PTButtons.PadSpot) == "function" and plotModel then
            pcall(function() padSpot = PTButtons.PadSpot(plotModel, btn) end)
            if not padSpot then
                pcall(function() padSpot = PTButtons.PadSpot(plotModel, 5, btn) end)
            end
            if not padSpot then
                pcall(function() padSpot = PTButtons.PadSpot(plotModel, 1, btn) end)
            end
        end

        local pad = nil
        if not padSpot and plotModel then
            pad = plotModel:FindFirstChild(tostring(btnId), true)
            if pad then padSpot = pad:GetPivot() end
        end

        if not padSpot then
            local padFolder = workspace:FindFirstChild("PumpkinTycoonPads")
            pad = padFolder and padFolder:FindFirstChild(tostring(btnId))
            if pad then padSpot = pad:GetPivot() end
        end

        if padSpot then
            local padPos = nil
            if typeof(padSpot) == "CFrame" then
                padPos = padSpot.Position
            elseif typeof(padSpot) == "Vector3" then
                padPos = padSpot
            elseif typeof(padSpot) == "Instance" and padSpot:IsA("BasePart") then
                padPos = padSpot.Position
            end

            if padPos then
                local prevCFrame = hrp.CFrame
                hrp.CFrame = CFrame.new(padPos + Vector3.new(0, 1.5, 0))
                task.wait(0.15)
                if plot and type(plot.Invoke) == "function" then
                    pcall(function() plot:Invoke("NZ_Commit", btnId) end)
                end
                task.wait(0.1)
                hrp.CFrame = prevCFrame
                bought = true
            end
        end
    end)

    return bought
end

function TycoonFarm.checkAndBuyButtons(state)
    if not Config.AutoBuyButtons then return end
    initGameLibs()
    local plot = TycoonFarm.getPlot()
    local buttonsState = TycoonFarm.getButtonsState()
    local priceMult = (ButtonsCmds and type(ButtonsCmds.PriceMult) == "function" and ButtonsCmds.PriceMult()) or 1

    -- 1. Kiểm tra nhận thưởng hoàn thành đảo (100% Island Completion Reward)
    local prog = TycoonFarm.getTycoonProgress()
    local isDone = (prog.percent or 0) >= 1 or ((prog.totalButtons or 0) > 0 and (prog.ownedButtons or 0) >= (prog.totalButtons or 0))
    if Config.AutoClaimIslandReward and isDone and not prog.completed then
        local claimed = false
        if plot and type(plot.Invoke) == "function" then
            local ok, res = pcall(function() return plot:Invoke(K.VERBS.ClaimReward or "BT_Settle") end)
            if ok and res ~= false then claimed = true end
        end
        if not claimed then
            local plotModel = TycoonFarm.getPlotModel()
            local char, hrp = getCharacterParts()
            if plotModel and hrp then
                local rewardObj = plotModel:FindFirstChild("CompletionReward", true) or plotModel:FindFirstChild("CompletionReward_Look", true)
                local pressPart = rewardObj and (rewardObj:FindFirstChild("Press", true) or rewardObj:FindFirstChild("Touch", true) or rewardObj.PrimaryPart or (rewardObj:IsA("BasePart") and rewardObj))
                if pressPart then
                    local prevCFrame = hrp.CFrame
                    hrp.CFrame = CFrame.new(pressPart.Position + Vector3.new(0, 1.5, 0))
                    task.wait(0.2)
                    if plot and type(plot.Invoke) == "function" then
                        pcall(function() plot:Invoke(K.VERBS.ClaimReward or "BT_Settle") end)
                    end
                    task.wait(0.1)
                    hrp.CFrame = prevCFrame
                    claimed = true
                end
            end
        end
        if claimed then
            print("[KizHub Tycoon] 🎉 ĐÃ NHẬN THƯỞNG HOÀN THÀNH ĐẢO PUMPKIN TYCOON (20x Flannel Gift)!")
        end
    end

    local coins = Network.currency(K.CURRENCY) or 0
    if coins <= 0 then return end

    -- 2. Quét toàn bộ nút có sẵn và mua liên tục (Burst Buy) các nút đủ tiền
    local avail = TycoonFarm.getAvailableButtons(buttonsState, priceMult)
    if not (type(avail) == "table" and #avail > 0) then return end

    local hasRank1 = false
    local minRank1Price = math.huge
    local candidates = {}

    for _, btn in ipairs(avail) do
        local id = tostring(btn.Id or "")
        local rank = 3
        if id:find("Egg") or id:find("Zone") or id:find("Machine") or id:find("Pedestal") or id:find("IslandLuck") or btn.Egg then
            rank = 1
        elseif id == "Merchant" then
            rank = 2
        end

        local price = getBtnPrice(btn, priceMult)
        if rank == 1 then
            hasRank1 = true
            if price < minRank1Price then minRank1Price = price end
        end
        if price <= coins then
            table.insert(candidates, { btn = btn, price = price, rank = rank })
        end
    end

    local affordable = {}
    for _, item in ipairs(candidates) do
        local canBuy = false
        if item.price <= coins then
            if item.rank == 1 then
                canBuy = true
            elseif not hasRank1 or minRank1Price > coins then
                -- Nếu không có nút Rank 1 nào mua nổi lúc này -> Mua mọi nút Rank 2/3 có giá <= coins để tiến tới 68/68 hoàn thành đảo
                canBuy = true
            elseif item.price <= math.max(minRank1Price * 0.35, coins * 0.5) then
                canBuy = true
            end
        end
        if canBuy then
            table.insert(affordable, item)
        end
    end

    if #affordable == 0 then return end

    table.sort(affordable, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.price < b.price
    end)

    local boughtCount = 0
    for _, item in ipairs(affordable) do
        if coins >= item.price then
            local ok = TycoonFarm.buyButton(item.btn, item.price)
            if ok then
                coins = math.max(0, coins - item.price)
                boughtCount = boughtCount + 1
                task.wait(0.15)
                if boughtCount >= 10 then break end
            end
        end
    end
end
-- =========================================================================
-- 7. AUTO-TAP VÀ HÚT ORBS / LOOTBAGS
-- =========================================================================

local lastTapTime = 0
function TycoonFarm.runAutoTapTick()
    if not (Config.AutoTap and Config.AutoTap.Enabled) then return end
    local now = os.clock()
    if now - lastTapTime < (Config.AutoTap.TapDelay or 0.2) then return end
    lastTapTime = now

    local char, hrp = getCharacterParts()
    if not hrp then return end

    local things = workspace:FindFirstChild("__THINGS")
    local breakables = things and things:FindFirstChild("Breakables")
    if breakables then
        for _, b in ipairs(breakables:GetChildren()) do
            if b:IsA("Model") and (b:GetPivot().Position - hrp.Position).Magnitude < 35 then
                Network.netFire("Breakables_PlayerDealDamage", b.Name)
                break
            end
        end
    end
end

local orbMapCache = nil
function TycoonFarm.findOrbMap()
    if type(orbMapCache) == "table" then return orbMapCache end
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client") and ReplicatedStorage.Library.Client:FindFirstChild("OrbCmds")
        if not mod or type(getsenv) ~= "function" then return end
        local env = getsenv(mod)
        local fn = type(env) == "table" and env.ProcessCreate or nil
        if type(fn) ~= "function" and type(getgc) == "function" then
            for _, f in ipairs(getgc(false)) do
                if type(f) == "function" and debug.info(f, "n") == "ProcessCreate" then
                    fn = f
                    break
                end
            end
        end
        if type(fn) ~= "function" then return end
        for _, up in pairs(debug.getupvalues(fn)) do
            if type(up) == "table" then
                local strKeys = false
                for k in pairs(up) do
                    if type(k) == "string" then
                        strKeys = true
                        break
                    end
                end
                if not strKeys then
                    orbMapCache = up
                    return
                end
            end
        end
    end)
    return orbMapCache
end

function TycoonFarm.collectOrbsTick()
    pcall(function()
        -- 1. HÚT ORBS TỨC THÌ TỪ BỘ NHỚ CLIENT QUA ORBCMDS (KHÔNG CHỜ RƠI XUỐNG SÀN)
        local map = TycoonFarm.findOrbMap()
        if type(map) == "table" then
            local now = workspace:GetServerTimeNow()
            for _, orb in pairs(map) do
                if type(orb) == "table" and not orb._collected and not orb._destroyed and type(orb.Collect) == "function" then
                    local age = now - (tonumber(orb._timestamp) or now)
                    if age >= (tonumber(orb._pickupDelay) or 0) then
                        pcall(orb.Collect, orb, nil, nil, true)
                    end
                end
            end
        end

        -- 2. HÚT SẠCH TOÀN BỘ ORBS VẬT LÝ TRÊN SÀN (CHIA MẺ 80-100 CÁI/LẦN, KHÔNG SÓT HẠT NÀO)
        local things = workspace:FindFirstChild("__THINGS")
        local orbs = things and things:FindFirstChild("Orbs")
        if orbs then
            local ids = {}
            for _, orb in ipairs(orbs:GetChildren()) do
                local id = tonumber(orb.Name) or orb.Name
                table.insert(ids, id)
                if #ids >= 80 then
                    Network.netFire("Orbs: Collect", ids)
                    ids = {}
                end
            end
            if #ids > 0 then
                Network.netFire("Orbs: Collect", ids)
            end
        end

        -- 3. HÚT SẠCH TOÀN BỘ LOOTBAGS RƠI TRÊN SÀN
        local lootbags = things and things:FindFirstChild("Lootbags")
        if lootbags then
            local uids = {}
            for _, lb in ipairs(lootbags:GetChildren()) do
                table.insert(uids, lb.Name)
                if #uids >= 40 then
                    Network.netFire("Lootbags_Claim", uids)
                    uids = {}
                end
            end
            if #uids > 0 then
                Network.netFire("Lootbags_Claim", uids)
            end
        end
    end)
end

-- =========================================================================
-- 8. THỐNG KÊ TIẾN ĐỘ TYCOON CHO DASHBOARD GUI
-- =========================================================================

function TycoonFarm.getTycoonProgress()
    local plot = TycoonFarm.getPlot()
    if not plot then
        return {
            ownedButtons = 0,
            totalButtons = 0,
            percent = 0,
            activeBigPumpkins = 0,
            activeBigPumpkinRung = 0,
            unlockedPedestals = 0,
            completed = false,
        }
    end

    initGameLibs()
    local buttonsState = plot:Save("Buttons") or {}
    local ownedCount, totalCount, frac = 0, 0, 0
    local isCompleted = false

    if PTButtons and type(PTButtons.Progress) == "function" then
        ownedCount, totalCount, frac = PTButtons.Progress(buttonsState, 1)
        isCompleted = PTButtons.Completed(buttonsState)
    end

    local unlockedPedestals = 0
    pcall(function()
        local peds = plot:Save("Pedestals")
        if type(peds) == "table" then
            for _, p in pairs(peds) do
                if type(p) == "table" and p.Locked ~= true then
                    unlockedPedestals = unlockedPedestals + 1
                end
            end
        end
    end)

    local bigPumpkin = TycoonFarm.findActiveBigPumpkin()

    return {
        ownedButtons = ownedCount or 0,
        totalButtons = totalCount or 1,
        percent = frac or 0,
        activeBigPumpkins = bigPumpkin and 1 or 0,
        activeBigPumpkinRung = bigPumpkin and bigPumpkin.rung or 0,
        unlockedPedestals = unlockedPedestals,
        completed = isCompleted,
    }
end

return TycoonFarm
