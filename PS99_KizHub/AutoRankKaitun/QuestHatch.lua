-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/QuestHatch.lua
-- Module tự động mở trứng theo tiến độ sao và nhiệm vụ Rank (Quest-Aware Hatch)
-- Tích hợp: Tự chọn Best Egg, Tính toán số lượng mua tối ưu, Auto Tap fast reveal
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local QuestHatch = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil

local Cache = {
    Egg = nil,
    EggAt = 0,
    MaxHatch = nil,
    MaxHatchAt = 0,
}

local HatchFailures = 0
local HatchBackoffUntil = 0
local HatchNeedsHop = false

function QuestHatch.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config

    if Config.DisableEggAnimation ~= false then
        QuestHatch.installNoEggAnimation()
    end
end

-- ================= 4. DISABLE EGG ANIMATION (BỎ QUA HOẠT ẢNH MỞ TRỨNG) =================
local isEggAnimHooked = false
function QuestHatch.installNoEggAnimation()
    if isEggAnimHooked then return end
    task.spawn(function()
        for attempt = 1, 30 do
            local hookedAny = false

            -- 4.1 Hook LocalScript "Egg Opening Frontend" trong PlayerScripts
            pcall(function()
                local ps = LocalPlayer:FindFirstChild("PlayerScripts")
                local eggScript = ps and ps:FindFirstChild("Egg Opening Frontend", true)
                if eggScript and type(getsenv) == "function" then
                    local env = getsenv(eggScript)
                    if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                        if type(hookfunction) == "function" then
                            hookfunction(env.PlayEggAnimation, function(...) return end)
                        end
                        env.PlayEggAnimation = function(...) return end
                        hookedAny = true
                    end
                end
            end)

            -- 4.2 Disable RemoteEvent OnClientEvent của "Eggs_PlayOpenAnimation"
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local netFolder = RS:FindFirstChild("Network")
                local remote = netFolder and netFolder:FindFirstChild("Eggs_PlayOpenAnimation")
                if remote and type(getconnections) == "function" then
                    for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                        pcall(function() conn:Disable() end)
                        hookedAny = true
                    end
                end
            end)

            -- 4.3 Hook fallback trên ModuleScript EggCmds nếu có
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local eggCmds = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client") and RS.Library.Client:FindFirstChild("EggCmds")
                if eggCmds and type(getsenv) == "function" then
                    local env = getsenv(eggCmds)
                    if type(env) == "table" and type(env.PlayEggAnimation) == "function" then
                        if type(hookfunction) == "function" then
                            hookfunction(env.PlayEggAnimation, function(...) return end)
                        end
                        env.PlayEggAnimation = function(...) return end
                        hookedAny = true
                    end
                end
            end)

            if hookedAny then
                isEggAnimHooked = true
                break
            end
            task.wait(1.0)
        end
    end)
end

function QuestHatch.BestEgg()
    local now = os.clock()
    if Cache.Egg and now - Cache.EggAt < 10 then
        if Cache.Egg.part and Cache.Egg.part.Parent == nil then
            Cache.EggAt = 0
        else
            return Cache.Egg
        end
    end
    if not (Net.isfn(G.EggCmds, "GetHighestEggNumberAvailable") and Net.isfn(G.EggsUtil, "GetIdByNumber")) then
        return Cache.Egg
    end

    local n = Net.gval(G.EggCmds.GetHighestEggNumberAvailable)
    if type(n) ~= "number" then return Cache.Egg end

    local id = Net.gval(G.EggsUtil.GetIdByNumber, n)
    if type(id) == "table" then id = id._id end
    if type(id) ~= "string" then return Cache.Egg end

    local dir = type(G.Eggs) == "table" and G.Eggs[id] or nil
    local petIds = {}
    if dir and type(dir.pets) == "table" then
        for _, e in pairs(dir.pets) do
            if type(e) == "table" and type(e[1]) == "string" then
                petIds[e[1]] = true
            elseif type(e) == "string" then
                petIds[e] = true
            end
        end
    end

    local part = nil
    if Net.isfn(G.EggsUtil, "GetEggPart") then
        local p = Net.gval(G.EggsUtil.GetEggPart, n)
        if typeof(p) == "Instance" then
            if p:IsA("BasePart") then
                part = p
            elseif p:IsA("Model") then
                part = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
            end
        end
    end

    Cache.Egg = { number = n, id = id, dir = dir, petIds = petIds, part = part, name = (dir and dir.name) or id }
    Cache.EggAt = now
    return Cache.Egg
end

function QuestHatch.MaxHatch()
    local now = os.clock()
    if Cache.MaxHatch and now - Cache.MaxHatchAt < 30 then
        return Cache.MaxHatch
    end
    local n = nil
    if Net.isfn(G.EggCmds, "GetMaxHatch") then
        n = Net.gval(G.EggCmds.GetMaxHatch)
    end
    if type(n) ~= "number" or n < 1 then
        n = Cache.MaxHatch or 1
    end
    Cache.MaxHatch = math.max(1, math.floor(n))
    Cache.MaxHatchAt = now
    return Cache.MaxHatch
end

function QuestHatch.HatchAmount(state)
    local amount = QuestHatch.MaxHatch()
    local Plan = state.Plan or {}
    if Plan.HatchEggOnly and type(Plan.HatchRemaining) == "number" and Plan.HatchRemaining > 0 then
        amount = math.min(amount, Plan.HatchRemaining)
    end
    return math.max(1, math.floor(amount))
end

function QuestHatch.HatchPlanned(state)
    return state.Enabled and Config.AutoHatch and (Config.AlwaysHatch or (state.Plan and state.Plan.Hatch == true))
end

function QuestHatch.EggRevealPrompt()
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Animation = PlayerGui and PlayerGui:FindFirstChild("EggOpenAnimation")
    local Prompt = Animation and Animation.Enabled and Animation:FindFirstChild("TapToOpen")
    local Text = Prompt and Prompt:FindFirstChild("TextLabel")
    return Text
        and Text:IsA("TextLabel")
        and Text.Visible
        and Prompt.Visible
        and (
            Text.Text == "Click to open!"
            or Text.Text == "Tap to open!"
            or Text.Text:match("^Tap .+ to open!$") ~= nil
        )
end

function QuestHatch.AutoTapEgg(state)
    if not state.Alive or not state.Enabled or not Config.AutoHatch or not Config.AutoTapEggs or not QuestHatch.EggRevealPrompt() then
        return false
    end
    if type(getconnections) ~= "function" then return false end

    local Scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local Frontend = Scripts and Scripts:FindFirstChild("Egg Opening Frontend", true)
    if not Frontend then return false end

    local Source = Frontend:GetFullName()
    for _, Connection in ipairs(getconnections(LocalPlayer:GetMouse().Button1Down)) do
        local Callback = Connection.Function
        if Connection.Enabled ~= false and type(Callback) == "function" and debug.info(Callback, "s") == Source then
            return Net.gcall(Callback)
        end
    end
    return false
end

function QuestHatch.CanHatchEgg(Egg)
    return Egg ~= nil
        and type(Egg.id) == "string"
        and Net.isfn(G.EggCmds, "IsUnlocked")
        and Net.gval(G.EggCmds.IsUnlocked, Egg.id) == true
        and Net.gval(G.EggCmds.IsEggAvailable, Egg.id) == true
end

function QuestHatch.EggUnitPrice(Egg)
    if not Egg or not Egg.dir then return nil end
    return Net.gval(G.CalcEggPricePlayer, Egg.dir)
end

function QuestHatch.AffordableHatchAmount(Egg, Limit)
    local Price = QuestHatch.EggUnitPrice(Egg)
    local Currency = Egg.dir and Egg.dir.currency
    if type(Price) ~= "number" or not Currency then return 0 end

    local Balance = Net.gval(G.CurrencyCmds.Get, Currency)
    if type(Balance) == "number" then
        return math.clamp(math.floor(Balance / math.max(Price, 1)), 0, Limit)
    end
    for Amount = Limit, 1, -1 do
        if Net.gval(G.CurrencyCmds.CanAfford, Currency, Amount * Price) == true then
            return Amount
        end
    end
    return 0
end

function QuestHatch.HatchTick(state)
    if not QuestHatch.HatchPlanned(state) then
        state.HatchSession = false
        return
    end
    if QuestHatch.EggRevealPrompt() then return end
    if state.WorldSwitching or state.WorldMismatch then return end
    if os.clock() < HatchBackoffUntil then return end

    local egg = QuestHatch.BestEgg()
    if not (egg and egg.id) then
        state.HatchSession = false
        return
    end

    if Net.gval(G.EggCmds.IsEggAvailable, egg.id) ~= true then
        state.HatchSession = false
        HatchBackoffUntil = os.clock() + 5
        return
    end

    local Unlocked = QuestHatch.CanHatchEgg(egg)
    local canAffordAtLeastOne = (QuestHatch.AffordableHatchAmount(egg, 1) >= 1)

    -- Kiểm tra nghiêm ngặt khả năng chi trả trước khi dịch chuyển: Nếu không đủ tiền mở ít nhất 1 quả thì tuyệt đối KHÔNG teleport
    if not canAffordAtLeastOne then
        state.HatchSession = false
        state.Hopping = false
        HatchBackoffUntil = os.clock() + 3
        if state.NewZoneHatchSession then
            state.NewZoneHatchSession = nil
        end
        return
    end

    local Amount = Unlocked and QuestHatch.AffordableHatchAmount(egg, QuestHatch.HatchAmount(state)) or 0
    if Unlocked and Amount < 1 then
        state.HatchSession = false
        state.Hopping = false
        HatchBackoffUntil = os.clock() + 2
        return
    end

    local Root = Net.hrp()
    local Part = egg.part
    local EggPosition = Part and Part.Parent and Part.Position or Net.gval(G.EggsUtil.GetEggPosition, egg.number)
    local Far = Root
        and typeof(EggPosition) == "Vector3"
        and (Root.Position - EggPosition).Magnitude > (Config.HatchMaxDistance or 85)
    local Hopped = Root and typeof(EggPosition) == "Vector3" and (Far or HatchNeedsHop)

    state.HatchSession = true
    if Hopped then
        state.Hopping = true
        Root.CFrame = CFrame.new(EggPosition + Vector3.new(0, 3, 6))
        Root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.25)
    end

    local Ok, Result, Message
    if Unlocked then
        Ok, Result, Message = Net.netInvoke("Eggs_RequestPurchase", egg.id, Amount)
    else
        Ok, Result, Message = Net.netInvoke("Eggs_RequestUnlock", egg.id)
    end

    if Hopped then
        state.Hopping = false
    end

    if not Unlocked then
        HatchBackoffUntil = os.clock() + (Ok and Result == true and 1 or 8)
        return
    end

    if Ok and Result == true then
        HatchFailures = 0
        HatchNeedsHop = false
        state.Counters = state.Counters or {}
        state.Counters.Hatched = (state.Counters.Hatched or 0) + Amount

        local Plan = state.Plan or {}
        if Plan.HatchEggOnly and type(Plan.HatchRemaining) == "number" then
            Plan.HatchRemaining = Plan.HatchRemaining - Amount
            if Plan.HatchRemaining <= 0 then
                Plan.Hatch = false
                state.HatchSession = false
            end
        end
    else
        HatchFailures = HatchFailures + 1
        local delays = { 1, 2, 5 }
        local d = delays[math.min(HatchFailures, 3)]
        HatchBackoffUntil = os.clock() + d
        local reason = Ok and tostring(Message or Result) or tostring(Result)
        HatchNeedsHop = not Hopped
            and typeof(EggPosition) == "Vector3"
            and (Far or reason:lower():find("too far", 1, true) ~= nil)
        if not HatchNeedsHop then
            state.HatchSession = false
        end
    end
end

return QuestHatch
