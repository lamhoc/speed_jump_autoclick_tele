-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/EggHatch.lua
-- Module tự động mở trứng sự kiện Halloween (Custom Eggs Hatch)
-- Tích hợp: Bỏ qua Animation mở trứng, Quét Trứng thông minh, Watchdog chống kẹt
-- =========================================================================

local RS = game:GetService("ReplicatedStorage")
local EggHatch = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local K = nil

function EggHatch.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    K = deps.K
end

-- Vô hiệu hóa hoạt ảnh (Animation) mở trứng để tăng tốc độ hatch tối đa
function EggHatch.installNoHatchAnimation()
    task.spawn(function()
        for attempt = 1, 15 do
            local ok, hooked = pcall(function()
                local eggCmds = RS:FindFirstChild("Library")
                    and RS.Library:FindFirstChild("Client")
                    and RS.Library.Client:FindFirstChild("EggCmds")
                if not eggCmds or type(getsenv) ~= "function" then return false end
                local env = getsenv(eggCmds)
                if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                    env.PlayEggAnimation = function() return end
                    return true
                end
                return false
            end)

            if ok and hooked == true then break end
            task.wait(1.0)
        end
    end)

    pcall(function()
        if type(G.PlayerPet) == "table" and type(G.PlayerPet.CalculateSpeedMultiplier) == "function" then
            local orig = G.PlayerPet.CalculateSpeedMultiplier
            G.PlayerPet.CalculateSpeedMultiplier = function(...)
                return 10
            end
        end
    end)
end

-- Tìm đối tượng trứng trong sự kiện theo ID
function EggHatch.findCustomEggById(eggId)
    if Net.isfn(G.CustomEggs, "All") then
        local all = Net.gval(G.CustomEggs.All)
        if type(all) == "table" then
            for uid, e in pairs(all) do
                if type(e) == "table" and (e._id == eggId or uid == eggId) then
                    local pos = e._position
                    if typeof(pos) ~= "Vector3" and e._model and e._model.Parent then
                        pcall(function() pos = e._model:GetPivot().Position end)
                    end
                    return {
                        uid = e._uid or uid,
                        id = e._id,
                        dir = e._dir or (G.Eggs and G.Eggs[e._id]) or nil,
                        pos = pos,
                        maxCount = e._maxEggCount,
                    }
                end
            end
        end
    end

    local things = workspace:FindFirstChild("__THINGS")
    local customEggsFolder = things and things:FindFirstChild("CustomEggs")
    if customEggsFolder then
        for _, eggModel in ipairs(customEggsFolder:GetChildren()) do
            if eggModel:IsA("Model") and (eggModel.Name:find(eggId) or eggModel:GetAttribute("EggId") == eggId) then
                local realUid = eggModel:GetAttribute("UID") or eggModel.Name
                return {
                    uid = realUid,
                    id = eggId,
                    dir = G.Eggs and G.Eggs[eggId] or nil,
                    pos = eggModel:GetPivot().Position,
                    maxCount = 99
                }
            end
        end
    end
    return nil
end

-- Lấy số lượng trứng tối đa có thể mở cùng lúc của tài khoản
function EggHatch.getAccountMaxHatch(egg)
    local bestMax = 1
    if Net.isfn(G.EggCmds, "GetMaxHatch") then
        local n = Net.gval(G.EggCmds.GetMaxHatch, egg and egg.dir or nil)
        if type(n) == "number" and n > bestMax then
            bestMax = math.floor(n)
        end
    end
    if egg and type(egg.maxCount) == "number" and egg.maxCount > bestMax then
        bestMax = math.floor(egg.maxCount)
    end
    return math.max(1, bestMax)
end

-- Thực hiện hatch trứng khu vực
function EggHatch.hatchZoneEgg(egg, state)
    if not egg then return false, 0 end
    local now = os.clock()
    if now < (state.nextHatchAttemptAt or 0) then return false, 0 end

    -- Kiểm tra số dư coin trước khi gửi Remote! Chống spam request khi hết tiền
    local curBal = Net.currency(K.CURRENCY) or 0
    if curBal <= 0 then
        state.nextHatchAttemptAt = now + 3.0 -- Nghỉ 3s chờ farm thêm coins
        return false, 0
    end

    local maxAmount = EggHatch.getAccountMaxHatch(egg)
    local target = egg.uid or egg.id
    if not target then return false, 0 end

    local ok, res = Net.netInvoke("CustomEggs_Hatch", target, maxAmount)
    if ok and res == true then
        state.totalEggsHatched = (state.totalEggsHatched or 0) + maxAmount
        state.lastSuccessfulHatch = os.clock()
        return true, maxAmount
    else
        -- Nếu mở bulk thất bại: Thử mở 1 quả
        if maxAmount > 1 then
            local ok1, res1 = Net.netInvoke("CustomEggs_Hatch", target, 1)
            if ok1 and res1 == true then
                state.totalEggsHatched = (state.totalEggsHatched or 0) + 1
                state.lastSuccessfulHatch = os.clock()
                return true, 1
            end
        end
        -- Thất bại do hết coin hoặc server cooldown -> giãn nhịp 3.5 giây
        state.nextHatchAttemptAt = now + 3.5
        return false, 0
    end
end

-- Kiểm tra Watchdog chống kẹt map khi mở trứng
function EggHatch.runWatchdogCheck(state, hasBreakablesFn, forceRejoinFn)
    local wCfg = Config.Watchdog
    if not (wCfg and wCfg.Enabled) then return end
    if state.excursion ~= nil or state.isRejoining then return end

    -- Nếu nhân vật đang farm hoặc còn coin -> Không kích hoạt Watchdog
    local char = game:GetService("Players").LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        local currentZone = state.currentZoneNumber or 1
        if (hasBreakablesFn and hasBreakablesFn(currentZone)) or (Net.currency(K.CURRENCY) or 0) > 0 then
            state.lastSuccessfulHatch = os.clock()
            return
        end
    end

    local maxIdleSec = (wCfg.MaxIdleHatchMinutes or 30) * 60
    if (os.clock() - (state.lastSuccessfulHatch or os.clock())) >= maxIdleSec then
        if type(forceRejoinFn) == "function" then
            forceRejoinFn(string.format("Kẹt cứng không hatch/farm được quá %d phút.", math.floor(maxIdleSec / 60)))
        end
    end
end

return EggHatch
