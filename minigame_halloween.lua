-- Halloween Games Auto Minigame (Pet Simulator 99)
-- Modular State Machine & Round Dispatcher

local Config = {
    Enabled = true,
    DebugLog = true,

    -- Night selection: "Highest" (5 -> 1), "Recommended" (meets Luck requirement), or "Fixed"
    NightSelectMode = "Highest",
    FixedNight = 5,
    MaxNight = 5,

    -- Match progression: false = always play through Final for 2x Bag + Midnight Gifts + Huge chance
    AutoCashOut = false,
    CashOutMinTreats = 500,

    -- Leave match immediately if eliminated / turned into a ghost
    ExitOnEliminated = true,

    -- Trick consumables usage
    AutoUseLuckyCharm = true,
    AutoUseLanternInFinal = true,

    -- Auto enter HalloweenGames instance portal if currently in main world
    AutoEnterInstance = true,

    -- Re-execute automatically across Lobby <-> Match place teleports
    AutoQueueOnTeleport = true,

    -- Performance, Map Deletion & 3D Rendering Optimization
    OptimizeFPS = true,
    DeleteUnneededMap = true,
    HideOtherPlayersAndBots = true,
    Disable3DRendering = false,
    FPSCap = 60,

    -- Auto Open Midnight Gift & Auto Mail Huge
    AutoOpenMidnightGift = true,
    OpenGiftInterval = 5,
    AutoMailHuge = true,
    MailRecipient = "Kizmoii_VNG",
    MailRetryInterval = 1800,

    -- Auto Server Hop after Minigame & Gift opening
    AutoServerHop = true,
    ServerHopDelay = 3,

    -- Discord Webhook Notifications
    Webhook = {
        Enabled = true,
        Url = "https://discord.com/api/webhooks/1569204576253513918/UzaQdQWSz6pDvHMRjb_u34Q0tkUdg3flpiew1IYej3Mw1YZTHwnPTNQ2RKNaAY-Tb405",
    },
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Clean up previous instance if re-executed
local env = (getgenv and getgenv()) or _G
if type(env.__HG_AUTO_CLEANUP) == "function" then
    pcall(env.__HG_AUTO_CLEANUP)
end

local State = {
    Running = true,
    Connections = {},
    Restorers = {},
    LastLog = "",
    LastCirclePickAt = 0,
    LastCircleMoveAt = 0,
    LastExitAt = 0,
    LastLeaveAttemptAt = 0,
    LastHopAttemptAt = 0,
    PostMatchPending = false,
    LastPortalEnterAt = os.clock() + 12.0,
    LastLobbyJoinAt = 0,
    LastOptimizeAt = 0,
    EngineOptimized = false,
    OptHooksInstalled = false,
    CurrentNightId = nil,
    LuckyCharmUsedNightId = nil,
    LanternUsedRoundId = nil,

    Round = {
        Id = nil,
        Arena = nil,
        Info = nil,
        Phase = nil,

        -- BroomSweep state
        BroomOrigin = nil,
        BroomConfig = nil,
        BroomLead = 0,
        LastJumpAt = 0,
        LastDuckAt = 0,

        -- HotPumpkin state
        HotHolders = {},
        HotBombs = {},
        LastPassAt = 0,

        -- LightsOut state
        Blackout = false,
        BlackoutSchedule = {},
        LightStartAt = 0,
        LightPos = nil,
        LightVel = Vector3.zero,
        LightRadius = 16,
        ActiveAttack = nil,

        -- BumperPumpkins state
        RingCenter = nil,
        RingRadius = 30,
        BumperRingRel = Vector3.zero,
        BumperCars = {},
        LastSteerAt = 0,
        LastBoostAt = 0,

        -- PumpkinColors state
        SafeColors = {},
        SafePads = {},
        ColorCallEndsAt = 0,

        -- TrickOrTreatDoors state
        DoorWave = 0,
        ActiveDoors = {},
        RevealedDoors = {},
        TakenDoors = {},
        HiddenDoors = {},
        SniffDoorId = nil,
        LanternDoorId = nil,
        CommittedDoorId = nil,
        DoorPhase = "enter",
        LastCommitAt = 0,

        -- ScarecrowStare state
        ScarecrowLight = "staging",
        ScarecrowFinished = false,
    },
}

local function log(msg)
    if not Config.DebugLog then
        return
    end
    local text = "[HalloweenGames] " .. tostring(msg)
    if text ~= State.LastLog then
        State.LastLog = text
        print(text)
    end
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then
        return nil, nil, nil
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hrp:IsA("BasePart") and hum) then
        return nil, nil, nil
    end
    return char, hrp, hum
end

-- Lazy-loaded game modules
local Modules = {}

local function getModules()
    if Modules.HalloweenGamesCmds and Modules.HalloweenGames then
        return Modules
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if not lib then
        return nil
    end
    local typesFolder = lib:FindFirstChild("Types")
    local clientFolder = lib:FindFirstChild("Client")
    local hgTypesMod = typesFolder and typesFolder:FindFirstChild("HalloweenGames")
    local hgCmdsMod = clientFolder and clientFolder:FindFirstChild("HalloweenGamesCmds")
    if not (hgTypesMod and hgCmdsMod) then
        return nil
    end

    local tabCtrlMod = clientFolder:FindFirstChild("TabController")
    local saveModScript = clientFolder:FindFirstChild("Save")

    local ok1, hgTypes = pcall(require, hgTypesMod)
    local ok2, hgCmds = pcall(require, hgCmdsMod)
    local ok3, tabCtrl = pcall(function()
        return tabCtrlMod and require(tabCtrlMod) or nil
    end)
    local ok4, saveMod = pcall(function()
        return saveModScript and require(saveModScript) or nil
    end)

    if ok1 and ok2 then
        Modules.HalloweenGames = hgTypes
        Modules.HalloweenGamesCmds = hgCmds
        Modules.TabController = ok3 and tabCtrl or nil
        Modules.Save = ok4 and saveMod or nil
        Modules.Night = hgCmds.Feature("Night")
        Modules.NightSelect = hgCmds.Feature("NightSelect")
        Modules.Match = hgCmds.Feature("Match")
        Modules.Results = hgCmds.Feature("Results")
        return Modules
    end
    return nil
end

-- ================= NETWORK REMOTES HELPER =================
local function netInvoke(name, ...)
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local netMod = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("Network")
    if netMod then
        local ok, n = pcall(require, netMod)
        if ok and type(n) == "table" and type(n.Invoke) == "function" then
            return pcall(n.Invoke, name, ...)
        end
    end
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    local remote = netFolder and netFolder:FindFirstChild(name)
    if remote and remote:IsA("RemoteFunction") then
        return pcall(remote.InvokeServer, remote, ...)
    end
    return false, "Remote not found: " .. tostring(name)
end

local function netFire(name, ...)
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local netMod = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("Network")
    if netMod then
        local ok, n = pcall(require, netMod)
        if ok and type(n) == "table" and type(n.Fire) == "function" then
            return pcall(n.Fire, name, ...)
        end
    end
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    local remote = netFolder and netFolder:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        return pcall(remote.FireServer, remote, ...)
    end
    return false, "Remote not found: " .. tostring(name)
end

local function netInvokeTimeout(timeout, name, ...)
    local done, ok, res = false, false, nil
    local args = { ... }
    task.spawn(function()
        ok, res = netInvoke(name, table.unpack(args))
        done = true
    end)
    local t0 = os.clock()
    while not done and (os.clock() - t0) < timeout do
        task.wait(0.1)
    end
    if not done then
        return false, "Timeout calling " .. tostring(name)
    end
    return ok, res
end

-- ================= SAVE & CURRENCY HELPER =================
local function getSaveData()
    local m = getModules()
    if m and m.Save and type(m.Save.Get) == "function" then
        local ok, data = pcall(m.Save.Get)
        if ok and type(data) == "table" then return data end
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local sMod = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("Save")
    if sMod then
        local ok, s = pcall(require, sMod)
        if ok and type(s) == "table" and type(s.Get) == "function" then
            local okG, data = pcall(s.Get)
            if okG and type(data) == "table" then return data end
        end
    end
    return nil
end

local function getDiamonds()
    local s = getSaveData()
    local cur = s and s.Inventory and s.Inventory.Currency
    if type(cur) == "table" then
        for _, v in pairs(cur) do
            if type(v) == "table" and v.id == "Diamonds" then
                return tonumber(v._am or v.am or 0) or 0
            end
        end
    end
    return 0
end

-- ================= DISCORD WEBHOOK ENGINE (CHỐNG RATE-LIMIT 429) =================
local function sendWebhook(title, description, color, customUrl)
    local wb = Config.Webhook
    if not (wb and wb.Enabled) then return end

    local targetUrl = customUrl or wb.Url
    if type(targetUrl) ~= "string" or not targetUrl:find("^https://") then return end

    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then return end

    local payload = {
        username = "kizhub • Halloween Games",
        avatar_url = "https://i.imgur.com/8Y1jE6u.png",
        embeds = { {
            title = title,
            description = description,
            color = color or 0xFFA500,
            footer = { text = "kizhub • Pet Simulator 99" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        } }
    }

    task.spawn(function()
        local bodyJson = HttpService:JSONEncode(payload)
        for attempt = 1, 3 do
            local ok, res = pcall(reqFn, {
                Url = targetUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = bodyJson
            })

            if ok and type(res) == "table" then
                local code = tonumber(res.StatusCode) or 0
                if code == 200 or code == 204 then
                    break
                elseif code == 429 then
                    local waitSec = 5
                    pcall(function()
                        local data = HttpService:JSONDecode(res.Body)
                        if data and data.retry_after then waitSec = tonumber(data.retry_after) or 5 end
                    end)
                    task.wait(waitSec + 1)
                else
                    task.wait(2)
                end
            else
                task.wait(2)
            end
        end
    end)
end

-- ================= AUTO OPEN MIDNIGHT GIFT & AUTO MAIL HUGE =================
local knownHugeUids = {}
local isHugeCacheInitialized = false
local pendingMailHuges = {}
local FailedUIDBlacklist = {}
local nextMailAttemptAt = 0

local function getMidnightGifts()
    local s = getSaveData()
    if not (s and s.Inventory) then return 0, {} end
    local total = 0
    local list = {}
    local folders = { s.Inventory.Lootbox, s.Inventory.Box, s.Inventory.Misc }
    for _, f in ipairs(folders) do
        if type(f) == "table" then
            for uid, item in pairs(f) do
                if type(item) == "table" and type(item.id) == "string" then
                    if item.id:lower():find("midnight gift") or item.id == "Midnight Gift" then
                        local count = tonumber(item._am or item.am or 1) or 1
                        total = total + count
                        table.insert(list, { UID = uid, Count = count, Id = item.id })
                    end
                end
            end
        end
    end
    return total, list
end

local function openMidnightGifts()
    if not Config.AutoOpenMidnightGift then return end
    local total, list = getMidnightGifts()
    if total <= 0 then return end

    log(string.format("Đang tự động mở %d Midnight Gift...", total))

    local m = getModules()
    -- 1. Thử HalloweenGamesCmds.Gift hoặc Feature("Gift") hoặc Library.Client.HalloweenGamesCmds.Gift
    local giftMod = (m and m.HalloweenGamesCmds and (m.HalloweenGamesCmds.Feature and m.HalloweenGamesCmds.Feature("Gift") or m.HalloweenGamesCmds.Gift))
    if not giftMod then
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local clientFolder = lib and lib:FindFirstChild("Client")
        local hgFolder = clientFolder and clientFolder:FindFirstChild("HalloweenGamesCmds")
        local gScript = hgFolder and hgFolder:FindFirstChild("Gift")
        if gScript then
            local okG, gRes = pcall(require, gScript)
            if okG then giftMod = gRes end
        end
    end
    if giftMod and type(giftMod.Open) == "function" then
        pcall(giftMod.Open, total)
        task.wait(0.5)
    end

    -- 2. Thử LootboxCmds
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local lbMod = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("LootboxCmds")
    if lbMod then
        local ok, lb = pcall(require, lbMod)
        if ok and type(lb) == "table" and type(lb.Open) == "function" then
            pcall(lb.Open, "Midnight Gift", total)
            task.wait(0.5)
        end
    end

    -- 3. Gọi Remote mạng
    netInvoke("Lootbox: Open", "Midnight Gift", total)
    netFire("Lootbox: Open", "Midnight Gift", total)
    netInvoke("HalloweenGames_OpenGift", total)
    netFire("HalloweenGames_OpenGift", total)
end

local function checkNewHugeDrop()
    local s = getSaveData()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    if not isHugeCacheInitialized then
        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                local isTitanic = (p.IsTitanic and p:IsTitanic()) or (p.id:find("Titanic ") ~= nil)
                if isHuge or isTitanic then
                    knownHugeUids[uid] = true
                end
            end
        end
        isHugeCacheInitialized = true
        return
    end

    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
            local isTitanic = (p.IsTitanic and p:IsTitanic()) or (p.id:find("Titanic ") ~= nil)
            if (isHuge or isTitanic) and not knownHugeUids[uid] then
                knownHugeUids[uid] = true

                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                log(string.format("🎉 NỔ HUGE TỪ MIDNIGHT GIFT: %s (UID: %s)", pName, tostring(uid)))

                -- 1. BẮN WEBHOOK THÔNG BÁO NỔ HUGE
                if isTitanic then
                    sendWebhook(
                        "🌌💥 [SIÊU PHẨM TITANIC TỪ MIDNIGHT GIFT!] 💥🌌",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "💎 **PET NỔ:** **%s**\n" ..
                            "🆔 **UID:** `%s`\n" ..
                            "🎁 **Nguồn:** Hộp quà Midnight Gift\n" ..
                            "⚡ Tự động chuẩn bị gửi Mail về `%s`!",
                            LocalPlayer.Name, pName, tostring(uid), Config.MailRecipient
                        ),
                        0x9B59B6
                    )
                else
                    sendWebhook(
                        "🎉🎉 [CHÚC MỪNG: NỔ HUGE TỪ MIDNIGHT GIFT!] 🎉🎉",
                        string.format(
                            "👑 **TÀI KHOẢN:** `%s`\n" ..
                            "🐾 **HUGE NỔ:** **%s**\n" ..
                            "🆔 **UID:** `%s`\n" ..
                            "🎁 **Nguồn:** Hộp quà Midnight Gift\n" ..
                            "📬 Tự động chuẩn bị gửi Mail về `%s`!",
                            LocalPlayer.Name, pName, tostring(uid), Config.MailRecipient
                        ),
                        0xFFD700
                    )
                end

                -- 2. ĐƯA VÀO DANH SÁCH CHỜ GỬI MAIL
                table.insert(pendingMailHuges, {
                    UID = uid,
                    Id = p.id,
                    Name = pName,
                    IsLocked = (p.lk == true or p._lk == true or p.Locked == true)
                })
            end
        end
    end
end

local function stepAutoMailHuge()
    if not Config.AutoMailHuge then return end
    if #pendingMailHuges == 0 then
        -- Quét thêm từ inventory nếu có Huge chưa gửi
        local s = getSaveData()
        local pets = s and s.Inventory and s.Inventory.Pet
        if type(pets) == "table" then
            for uid, p in pairs(pets) do
                if type(p) == "table" and type(p.id) == "string" then
                    local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                    if isHuge and not FailedUIDBlacklist[uid] then
                        if p.sb ~= true and p._sb ~= true and p.Soulbound ~= true and p.Untradable ~= true then
                            local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                            table.insert(pendingMailHuges, {
                                UID = uid,
                                Id = p.id,
                                Name = pName,
                                IsLocked = (p.lk == true or p._lk == true or p.Locked == true)
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    if #pendingMailHuges == 0 then return end

    local now = os.clock()
    if now < nextMailAttemptAt then return end

    local targetHuge = table.remove(pendingMailHuges, 1)
    if not targetHuge or FailedUIDBlacklist[targetHuge.UID] then return end

    local currentDiamonds = getDiamonds()
    if currentDiamonds < 10000 then
        log("Thiếu Gems gửi Mail (Cần tối thiểu 10k Gems). Thử lại sau.")
        table.insert(pendingMailHuges, 1, targetHuge)
        nextMailAttemptAt = now + (Config.MailRetryInterval or 1800)
        return
    end

    log(string.format("Đang gửi Mail Huge %s (UID: %s) tới %s...", targetHuge.Name, targetHuge.UID, Config.MailRecipient))

    -- Mở khóa pet nếu đang bị khóa
    if targetHuge.IsLocked then
        pcall(function()
            netInvoke("Locking_SetLocked", targetHuge.UID, false)
            netFire("Pets_Unlock", targetHuge.UID)
        end)
        task.wait(0.4)
    end

    pcall(function()
        netFire("Machines: Mark Approached", "Mailbox")
    end)
    task.wait(0.3)

    local diaBefore = getDiamonds()
    local okSend, resSend = netInvokeTimeout(8, "Mailbox: Send", Config.MailRecipient, "Gift Midnight #" .. tostring(math.random(100, 999)), "Pet", targetHuge.UID, 1)
    local diaAfter = getDiamonds()
    local actualCost = math.max(0, diaBefore - diaAfter)

    if okSend and resSend == true then
        log(string.format("Đã gửi Mail thành công %s (Cước: %d Gems)", targetHuge.Name, actualCost))
        sendWebhook(
            "📦 [GỬI MAIL HUGE MIDNIGHT GIFT THÀNH CÔNG] 📦",
            string.format(
                "👑 **Người gửi:** `%s`\n" ..
                "📬 **Người nhận:** `%s`\n" ..
                "🐾 **Pet gửi:** **%s**\n" ..
                "🆔 **UID:** `%s`\n" ..
                "💎 **Cước phí Mail:** `%d Gems`\n" ..
                "⚡ Tự động chuyển Huge an toàn về tài khoản chính!",
                LocalPlayer.Name, Config.MailRecipient, targetHuge.Name, targetHuge.UID, actualCost
            ),
            0x00E676
        )
        task.wait(60) -- Cooldown giữa các lần gửi mail
    else
        local errStr = string.lower(tostring(resSend))
        log(string.format("Gửi Mail thất bại: %s. Thử lại sau.", tostring(resSend)))
        if errStr:find("soulbound") or errStr:find("untradable") or errStr:find("cannot be traded") or errStr:find("not tradable") then
            FailedUIDBlacklist[targetHuge.UID] = true
            log(string.format("Pet %s là Soulbound / Untradable, đưa vào Blacklist.", targetHuge.Name))
        else
            table.insert(pendingMailHuges, 1, targetHuge)
            nextMailAttemptAt = now + (Config.MailRetryInterval or 1800)
        end
        sendWebhook(
            "⚠️ [GỬI MAIL HUGE THẤT BẠI] ⚠️",
            string.format(
                "👑 **Tài khoản:** `%s`\n" ..
                "🐾 **Pet:** **%s**\n" ..
                "❌ **Lỗi:** `%s`\n" ..
                "⏳ Sẽ tự động thử lại sau 30 phút.",
                LocalPlayer.Name, targetHuge.Name, tostring(resSend)
            ),
            0xFF5252
        )
    end
end

local function getActiveInstanceModel()
    local m = getModules()
    local inst = m and m.HalloweenGamesCmds and m.HalloweenGamesCmds.Instance()
    if inst and inst.model then
        return inst.model
    end
    local things = workspace:FindFirstChild("__THINGS")
    local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local active = container and container:FindFirstChild("Active")
    return active and active:FindFirstChild("HalloweenGames") or nil
end

local HALLOWEEN_MAP_PLACE_ID = 140030158342766

local function isDedicatedMatchPlace()
    return game.PlaceId == 93869716229773 or game.PlaceId == 82075097396409
end

local function isInHalloweenMap()
    if isDedicatedMatchPlace() then return false end
    if getActiveInstanceModel() ~= nil then return false end
    local models = workspace:FindFirstChild("Models")
    if models and models:FindFirstChild("Pad") then
        local innerPad = models.Pad:FindFirstChild("Pad")
        local netFolder = ReplicatedStorage:FindFirstChild("Network")
        if innerPad and netFolder and netFolder:FindFirstChild("RequestRegister") then
            return false -- Đang ở trong Queue Lobby place
        end
    end
    return true
end

local function findInstanceExitPart(model)
    if not model then return nil end
    local teleports = model:FindFirstChild("Teleports")
    if teleports then
        local p = teleports:FindFirstChild("Leave") or teleports:FindFirstChild("Exit") or teleports:FindFirstChild("Out")
        if p and p:IsA("BasePart") then return p end
    end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Name == "Leave" or desc.Name == "Exit" or desc.Name == "PortalLeave") then
            return desc
        end
    end
    return nil
end

local function leaveMinigameToHalloweenMap()
    local now = os.clock()
    if (now - State.LastLeaveAttemptAt) < 2.0 then return end
    State.LastLeaveAttemptAt = now

    log("Đang thoát sảnh chờ / instance để về lại Map Halloween...")

    -- 1. Nếu đang ở Dedicated Match Place -> Teleport về Halloween Map
    if isDedicatedMatchPlace() then
        log(string.format("Đang ở Match Place (%d), dịch chuyển về Map Halloween (%d)...", game.PlaceId, HALLOWEEN_MAP_PLACE_ID))
        local TeleportService = game:GetService("TeleportService")
        pcall(function()
            TeleportService:Teleport(HALLOWEEN_MAP_PLACE_ID, LocalPlayer)
        end)
        return
    end

    -- 2. Thoát thông qua Remotes của hệ thống Instancing
    pcall(function()
        netFire("Instancing_PlayerLeaveInstance")
        netFire("Instancing_ForceLeave")
        netInvoke("Instancing_PlayerLeaveInstance")
    end)

    -- 3. Gọi InstancingCmds.Leave / Exit nếu có
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local instMod = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("InstancingCmds")
    if instMod then
        local okI, inst = pcall(require, instMod)
        if okI and type(inst) == "table" then
            if type(inst.Leave) == "function" then pcall(inst.Leave) end
            if type(inst.Exit) == "function" then pcall(inst.Exit) end
            if type(inst.LeaveInstance) == "function" then pcall(inst.LeaveInstance) end
        end
    end

    -- 4. Chạm vào portal Leave / Exit vật lý bên trong Instance
    local _, hrp = getCharacter()
    local activeModel = getActiveInstanceModel()
    if hrp and activeModel then
        local exitPart = findInstanceExitPart(activeModel)
        if exitPart and exitPart:IsA("BasePart") then
            log("Di chuyển tới portal thoát: " .. exitPart:GetFullName())
            hrp.CFrame = exitPart.CFrame + Vector3.new(0, 3, 0)
        end
    end
end

local function closeEliminatedScreenIfOpen(nightMod)
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local instGui = pgui and pgui:FindFirstChild("_INSTANCES")
    local elimGui = instGui and instGui:FindFirstChild("HalloweenGamesEliminated")
    if elimGui and elimGui.Enabled then
        elimGui.Enabled = false
        if nightMod and (os.clock() - State.LastExitAt) > 2.0 then
            State.LastExitAt = os.clock()
            pcall(nightMod.MatchExit)
        end
    end
end

local function triggerPostMatchFlow(nightMod)
    if State.PostMatchPending then return end
    State.PostMatchPending = true
    log("Chơi xong minigame. Kích hoạt quy trình: Out sảnh chờ -> Về Map Halloween -> Mở Midnight Gift -> Hop Server.")

    task.spawn(function()
        if nightMod then
            closeEliminatedScreenIfOpen(nightMod)
            pcall(nightMod.MatchExit)
        end
        task.wait(1)
        leaveMinigameToHalloweenMap()
    end)
end

local function serverHop()
    local now = os.clock()
    if (now - State.LastHopAttemptAt) < 10 then return end
    State.LastHopAttemptAt = now

    log("Đang quét danh sách Server công khai để Hop...")

    local targetPlaceId = (isDedicatedMatchPlace() and HALLOWEEN_MAP_PLACE_ID) or game.PlaceId
    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    local TeleportService = game:GetService("TeleportService")

    local candidateServers = {}
    local cursor = ""
    local attempts = 0

    while attempts < 4 and #candidateServers < 10 do
        attempts = attempts + 1
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100%s",
            targetPlaceId,
            (cursor ~= "" and ("&cursor=" .. cursor) or "")
        )

        local responseBody = nil
        if reqFn then
            local ok, r = pcall(reqFn, { Url = url, Method = "GET" })
            if ok and type(r) == "table" and r.Body then
                responseBody = r.Body
            end
        elseif game.HttpGet then
            local ok, r = pcall(game.HttpGet, game, url)
            if ok and type(r) == "string" then
                responseBody = r
            end
        end

        if responseBody then
            local okD, parsed = pcall(HttpService.JSONDecode, HttpService, responseBody)
            if okD and parsed and type(parsed.data) == "table" then
                for _, srv in ipairs(parsed.data) do
                    if type(srv) == "table" and srv.id and srv.id ~= game.JobId then
                        local playing = tonumber(srv.playing) or 0
                        local maxPlayers = tonumber(srv.maxPlayers) or 20
                        if playing >= 1 and playing <= (maxPlayers - 2) then
                            table.insert(candidateServers, srv.id)
                        end
                    end
                end
                if parsed.nextPageCursor and tostring(parsed.nextPageCursor) ~= "" then
                    cursor = tostring(parsed.nextPageCursor)
                else
                    break
                end
            else
                break
            end
        else
            break
        end
        task.wait(0.5)
    end

    if #candidateServers > 0 then
        local chosenJobId = candidateServers[math.random(1, #candidateServers)]
        log(string.format("Đã chọn Server mới: %s. Đang dịch chuyển...", tostring(chosenJobId)))
        local okTp, errTp = pcall(function()
            TeleportService:TeleportToPlaceInstance(targetPlaceId, chosenJobId, LocalPlayer)
        end)
        if not okTp then
            log("Lỗi TeleportToPlaceInstance: " .. tostring(errTp) .. ". Thử Teleport thông thường...")
            pcall(function()
                TeleportService:Teleport(targetPlaceId, LocalPlayer)
            end)
        end
    else
        log("Không lấy được server từ API, gọi TeleportService:Teleport trực tiếp...")
        pcall(function()
            TeleportService:Teleport(targetPlaceId, LocalPlayer)
        end)
    end
end

local function resetRoundState(roundId, arena, info)
    local r = State.Round
    r.Id = roundId
    r.Arena = arena
    r.Info = info
    r.Phase = "intro"

    r.BroomOrigin = arena and arena:GetPivot() or nil
    r.BroomConfig = (info and info.config and info.config.t0) and info.config or nil
    r.BroomLead = 0
    r.LastJumpAt = 0
    r.LastDuckAt = 0

    table.clear(r.HotHolders)
    table.clear(r.HotBombs)
    r.LastPassAt = 0

    r.Blackout = false
    table.clear(r.BlackoutSchedule)
    r.LightStartAt = 0
    r.LightPos = arena and arena:GetPivot().Position or nil
    r.LightVel = Vector3.zero
    r.LightRadius = 16
    r.ActiveAttack = nil

    r.RingCenter = arena and arena:GetPivot().Position or nil
    r.RingRadius = 30
    r.BumperRingRel = Vector3.zero
    table.clear(r.BumperCars)
    r.LastSteerAt = 0
    r.LastBoostAt = 0

    table.clear(r.SafeColors)
    table.clear(r.SafePads)
    r.ColorCallEndsAt = 0

    r.DoorWave = 0
    table.clear(r.ActiveDoors)
    table.clear(r.RevealedDoors)
    table.clear(r.TakenDoors)
    table.clear(r.HiddenDoors)
    r.SniffDoorId = nil
    r.LanternDoorId = nil
    r.CommittedDoorId = nil
    r.DoorPhase = "enter"
    r.LastCommitAt = 0

    r.ScarecrowLight = "staging"
    r.ScarecrowFinished = false
end

-- Check if player owns a specific Trick consumable in Save inventory
local function hasTrickItem(itemId)
    local m = getModules()
    if not (m and m.Save) then
        return false
    end
    local ok, data = pcall(m.Save.Get)
    if not (ok and type(data) == "table" and type(data.Inventory) == "table") then
        return false
    end
    local misc = data.Inventory.Misc or data.Inventory.Consumable
    if type(misc) ~= "table" then
        return false
    end
    for _, item in pairs(misc) do
        if type(item) == "table" and item.id == itemId and (tonumber(item._am) or 1) > 0 then
            return true
        end
    end
    return false
end

-- Ensure internal Autopilot upvalue on LightsOut is disabled (nil) so our custom solver controls movement
local function tryEnableNativeAutopilot(roundName, roundMod)
    local setupval = (debug and debug.setupvalue) or setupvalue
    if type(setupval) == "function" and roundName == "LightsOut" and type(roundMod and roundMod.Autopilot) == "function" then
        pcall(setupval, roundMod.Autopilot, 2, nil)
    end
    return false
end

-- ============================================================================
-- FPS, MAP DELETION & 3D RENDERING OPTIMIZER
-- ============================================================================
local THINGS_BLOAT_FOLDERS = {
    "Breakables",
    "Pets",
    "Orbs",
    "Lootbags",
    "RenderedEggs",
    "CustomEggs",
    "VFX",
    "AnimatedBreakables",
    "Booths",
    "Flags",
    "Hoverboards",
    "RandomEvents",
    "Chests",
    "Shinies",
    "Ultimates",
}

local WORLD_BLOAT_NAMES = {
    "Map",
    "Zone 1",
    "GREYBOX_WIP",
    "PSX Hall",
    "Border",
    "FlyBorder",
}

local HG_ACTIVE_DELETE_NAMES = {
    "Map",
    "Border",
    "BREAK_ZONES",
    "INTERACT",
}

local LOBBY_MODELS_KEEP = {
    Pad = true,
    GROUND = true,
    Board = true,
    TeleportHide = true,
    Billboard = true,
    RemainingPlayers = true,
    RemainingIcons = true,
    Animations = true,
}

local function simplifyVisualTree(root)
    if not root then
        return
    end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("BasePart") then
            if not desc:GetAttribute("HGOpt") then
                desc:SetAttribute("HGOpt", true)
                desc.Material = Enum.Material.SmoothPlastic
                desc.CastShadow = false
                desc.Reflectance = 0
            end
        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Fire") or desc:IsA("Smoke") or desc:IsA("Sparkles") then
            desc.Enabled = false
        elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
            desc.Enabled = false
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 1
        end
    end
end

local function applyEngineOptimization()
    if State.EngineOptimized then
        return
    end
    State.EngineOptimized = true

    pcall(function()
        RunService:Set3dRenderingEnabled(not Config.Disable3DRendering)
    end)
    table.insert(State.Restorers, function()
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end)

    if Config.FPSCap and tonumber(Config.FPSCap) and tonumber(Config.FPSCap) > 0 then
        local capFn = setfpscap or set_fps_cap
        if type(capFn) == "function" then
            pcall(capFn, tonumber(Config.FPSCap))
        end
    end

    if not Config.OptimizeFPS then
        return
    end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("Sky") then
                if child:IsA("PostEffect") then
                    child.Enabled = false
                else
                    child:Destroy()
                end
            end
        end
    end)

    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            for _, child in ipairs(terrain:GetChildren()) do
                if child:IsA("Clouds") then
                    child:Destroy()
                end
            end
            terrain:Clear()
        end
    end)
end

local function installOptimizationHooks()
    if State.OptHooksInstalled or not Config.OptimizeFPS then
        return
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local clientLib = lib and lib:FindFirstChild("Client")
    local hgCmds = clientLib and clientLib:FindFirstChild("HalloweenGamesCmds")
    if not hgCmds then
        return
    end
    State.OptHooksInstalled = true

    -- Suppress HalloweenGamesCmds.Fx particles & screen shakes
    local fxScript = hgCmds:FindFirstChild("Fx")
    local okFx, fxMod = pcall(function()
        return fxScript and require(fxScript)
    end)
    if okFx and type(fxMod) == "table" then
        for _, fnName in ipairs({ "Burst", "Celebrate", "Through", "RoundStart", "Countdown", "Poof" }) do
            local orig = fxMod[fnName]
            if type(orig) == "function" then
                fxMod[fnName] = function() end
                table.insert(State.Restorers, function()
                    fxMod[fnName] = orig
                end)
            end
        end
        local origEmitter = fxMod.Emitter
        if type(origEmitter) == "function" then
            fxMod.Emitter = function(...)
                local em = origEmitter(...)
                if em and typeof(em) == "Instance" and em:IsA("ParticleEmitter") then
                    em.Enabled = false
                    em.Rate = 0
                end
                return em
            end
            table.insert(State.Restorers, function()
                fxMod.Emitter = origEmitter
            end)
        end
    end

    -- Suppress CurrencyBurst particle bursts
    local cbScript = clientLib:FindFirstChild("CurrencyBurst")
    local okCb, cbMod = pcall(function()
        return cbScript and require(cbScript)
    end)
    if okCb and type(cbMod) == "table" and type(cbMod.Play) == "function" then
        local origPlay = cbMod.Play
        cbMod.Play = function()
            return 0
        end
        table.insert(State.Restorers, function()
            cbMod.Play = origPlay
        end)
    end

    -- Suppress 19-bot 8-limb BulkMoveTo animations every RenderStepped while preserving PrimaryPart for HotPumpkin
    if Config.HideOtherPlayersAndBots then
        local rigsScript = hgCmds:FindFirstChild("Rigs")
        local okRigs, rigsMod = pcall(function()
            return rigsScript and require(rigsScript)
        end)
        if okRigs and type(rigsMod) == "table" then
            if type(rigsMod.Update) == "function" then
                local origUpdate = rigsMod.Update
                rigsMod.Update = function(_, model, cf)
                    if model and model.PrimaryPart and typeof(cf) == "CFrame" then
                        model.PrimaryPart.CFrame = cf * CFrame.new(0, 3, 0)
                    end
                end
                table.insert(State.Restorers, function()
                    rigsMod.Update = origUpdate
                end)
            end
            if type(rigsMod.Poof) == "function" then
                local origPoof = rigsMod.Poof
                rigsMod.Poof = function() end
                table.insert(State.Restorers, function()
                    rigsMod.Poof = origPoof
                end)
            end
        end
    end
end

local function stepOptimization()
    if not (Config.OptimizeFPS or Config.DeleteUnneededMap or Config.HideOtherPlayersAndBots) then
        return
    end
    local now = os.clock()
    if (now - State.LastOptimizeAt) < 2.0 then
        return
    end
    State.LastOptimizeAt = now

    installOptimizationHooks()

    -- 1. Clear temporary debris
    local debris = workspace:FindFirstChild("__DEBRIS")
    if debris then
        for _, child in ipairs(debris:GetChildren()) do
            pcall(child.Destroy, child)
        end
    end

    -- 2. Hide other players & bot rigs while keeping HumanoidRootPart / PrimaryPart for HotPumpkin
    if Config.HideOtherPlayersAndBots then
        local botsFolder = workspace:FindFirstChild("HalloweenGamesBots")
        if botsFolder then
            for _, botModel in ipairs(botsFolder:GetChildren()) do
                local pp = botModel:IsA("Model") and botModel.PrimaryPart or nil
                for _, child in ipairs(botModel:GetChildren()) do
                    if child == pp then
                        child.Transparency = 1
                        child.CastShadow = false
                    else
                        pcall(child.Destroy, child)
                    end
                end
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, desc in ipairs(plr.Character:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.Transparency = 1
                        desc.CastShadow = false
                    elseif desc:IsA("Decal") or desc:IsA("Texture") then
                        desc.Transparency = 1
                    elseif desc:IsA("Accessory") or desc:IsA("Clothing") or desc:IsA("ShirtGraphic") or desc:IsA("CharacterMesh") then
                        pcall(desc.Destroy, desc)
                    elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("BillboardGui") then
                        pcall(desc.Destroy, desc)
                    end
                end
            end
        end
    end

    if not Config.DeleteUnneededMap then
        return
    end

    -- 3. Clean World 1 / Match Place bloat folders
    local things = workspace:FindFirstChild("__THINGS")
    if things then
        for _, folderName in ipairs(THINGS_BLOAT_FOLDERS) do
            local f = things:FindFirstChild(folderName)
            if f then
                for _, child in ipairs(f:GetChildren()) do
                    pcall(child.Destroy, child)
                end
            end
        end
    end

    for _, name in ipairs(WORLD_BLOAT_NAMES) do
        local obj = workspace:FindFirstChild(name)
        if obj then
            pcall(obj.Destroy, obj)
        end
    end

    -- 4. Clean inside Active.HalloweenGames (preserve ArenaSlots, Hub.Circle/Model, Teleports, ZONE_GROUND, SAFETY_NET)
    local activeModel = getActiveInstanceModel()
    if activeModel then
        for _, delName in ipairs(HG_ACTIVE_DELETE_NAMES) do
            local target = activeModel:FindFirstChild(delName)
            if target then
                pcall(target.Destroy, target)
            end
        end
        local hub = activeModel:FindFirstChild("Hub")
        if hub then
            local props = hub:FindFirstChild("Props")
            if props then
                pcall(props.Destroy, props)
            end
            simplifyVisualTree(hub)
        end
        local zg = activeModel:FindFirstChild("ZONE_GROUND")
        if zg then
            simplifyVisualTree(zg)
        end
        local slots = activeModel:FindFirstChild("ArenaSlots")
        if slots then
            simplifyVisualTree(slots)
        end
    end

    -- 5. Clean Multiplayer Queue Lobby ("Want to Play? Join Here!")
    local models = workspace:FindFirstChild("Models")
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if models and netFolder and netFolder:FindFirstChild("RequestRegister") then
        for _, child in ipairs(models:GetChildren()) do
            if not LOBBY_MODELS_KEEP[child.Name] then
                pcall(child.Destroy, child)
            end
        end
        local padModel = models:FindFirstChild("Pad")
        if padModel then
            simplifyVisualTree(padModel)
        end
        local groundModel = models:FindFirstChild("GROUND")
        if groundModel then
            simplifyVisualTree(groundModel)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 1: BroomSweep
-- ============================================================================
local function sweptMult(events, t)
    local total = 0
    local prevAt = 0
    local mult = 1
    for _, ev in ipairs(events or {}) do
        if t <= ev.at then
            break
        end
        total = total + mult * (ev.at - prevAt)
        local dt = math.min(ev.ramp, t - ev.at)
        total = total + (mult + (mult + (ev.mult - mult) * dt / ev.ramp)) / 2 * dt
        if dt < ev.ramp then
            return total
        end
        prevAt = ev.at + ev.ramp
        mult = ev.mult
    end
    return total + mult * (t - prevAt)
end

local function sweepAngle(cfg, elapsed)
    if not cfg or elapsed <= (cfg.intro or 0) then
        return 0
    end
    local omega = (math.pi * 2) / (cfg.period or 6)
    local afterIntro = elapsed - (cfg.intro or 0)
    local countdown = cfg.countdown or 3
    if afterIntro <= countdown then
        return omega * afterIntro * afterIntro / (2 * countdown)
    end
    local baseAngle = omega * countdown / 2
    return baseAngle + omega * sweptMult(cfg.events, afterIntro - countdown)
end

local function nextCrossTime(cfg, armKind, playerAngle, playerRadius, startElapsed)
    if not cfg then
        return nil
    end
    local poleRadius = cfg.poleRadius or 3
    local rimRadius = cfg.rimRadius or 24
    local reach = cfg[armKind .. "Reach"] or rimRadius
    if playerRadius < poleRadius or playerRadius > math.min(reach, rimRadius) then
        return nil
    end

    local offset = (armKind == "high") and (math.pi / 2) or 0
    local prevDiff = (playerAngle - (sweepAngle(cfg, startElapsed) + offset)) % math.pi
    local t = startElapsed
    while t < startElapsed + 4 do
        t = t + 0.02
        local curDiff = (playerAngle - (sweepAngle(cfg, t) + offset)) % math.pi
        if prevDiff < curDiff then
            return t
        end
        prevDiff = curDiff
    end
    return nil
end

local function performBroomJump(hum, hrp)
    if hum.FloorMaterial == Enum.Material.Air then
        return
    end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    local vel = hrp.AssemblyLinearVelocity
    local jumpVy = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, jumpVy), vel.Z)
end

local function performBroomDuck(nightMod, cfg)
    local cooldown = (cfg and cfg.cooldown) or 1
    local now = os.clock()
    if now - State.Round.LastDuckAt < cooldown then
        return
    end
    State.Round.LastDuckAt = now
    if nightMod then
        nightMod.Input("duck", {})
    end
end

local function recoverBroomStateIfMissing()
    local r = State.Round
    if r.BroomConfig and r.BroomConfig.t0 then
        return
    end
    local getupvals = (debug and debug.getupvalues) or getupvalues
    if type(getupvals) ~= "function" then
        return
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local rounds = cmds and cmds:FindFirstChild("Rounds")
    local bsModScript = rounds and rounds:FindFirstChild("BroomSweep")
    if not bsModScript then
        return
    end
    local ok, bsMod = pcall(require, bsModScript)
    if not (ok and type(bsMod) == "table") then
        return
    end
    local fn = bsMod.__HG_ORIG_ONSTATE or bsMod.OnState
    if type(fn) ~= "function" then
        return
    end
    local okUp, upvals = pcall(getupvals, fn)
    if not (okUp and type(upvals) == "table") then
        return
    end
    for _, v in pairs(upvals) do
        if type(v) == "table" and v.t0 and v.period then
            r.BroomConfig = v
        elseif typeof(v) == "CFrame" then
            r.BroomOrigin = v
        end
    end
end

local function stepBroomSweep(nightMod)
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local now = os.clock()
    recoverBroomStateIfMissing()

    local cfg = State.Round.BroomConfig

    -- Immediate check via BroomSweepSign billboard so it works even before/without sweep config
    local sign = hrp:FindFirstChild("BroomSweepSign")
    if sign and sign:IsA("BillboardGui") and sign.Enabled then
        local label = sign:FindFirstChild("Label")
        local txt = label and label.Text or ""
        if txt == "JUMP!" and (now - State.Round.LastJumpAt) > 0.45 then
            State.Round.LastJumpAt = now
            performBroomJump(hum, hrp)
        elseif txt == "DIVE!" then
            performBroomDuck(nightMod, cfg)
        end
    end

    local origin = State.Round.BroomOrigin or (State.Round.Arena and State.Round.Arena:GetPivot())
    if not (cfg and cfg.t0 and origin) then
        return
    end

    local elapsed = workspace:GetServerTimeNow() - cfg.t0
    local startActive = (cfg.intro or 0) + (cfg.countdown or 0)
    local endActive = startActive + (cfg.active or 60)
    if elapsed < startActive - 0.3 or elapsed > endActive then
        return
    end

    local rel = origin:PointToObjectSpace(hrp.Position)
    local pAngle = math.atan2(rel.Z, rel.X)
    local pRadius = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)

    local searchFrom = math.max(elapsed, startActive - 0.2)
    local lowCross = nextCrossTime(cfg, "low", pAngle, pRadius, searchFrom)
    local highCross = nextCrossTime(cfg, "high", pAngle, pRadius, searchFrom)
    local leadBonus = State.Round.BroomLead or 0

    if lowCross and lowCross >= startActive and lowCross <= endActive then
        local leadLow = lowCross - elapsed
        if leadLow <= (0.35 + leadBonus) and leadLow >= -0.08 and (now - State.Round.LastJumpAt) > 0.45 then
            State.Round.LastJumpAt = now
            performBroomJump(hum, hrp)
        end
    end

    if highCross and highCross >= startActive and highCross <= endActive then
        local leadHigh = highCross - elapsed
        if leadHigh <= (0.22 + leadBonus) and leadHigh >= -0.08 then
            performBroomDuck(nightMod, cfg)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 2: HotPumpkin
-- ============================================================================
local function getContestantRoot(nightMod, id)
    if not nightMod then
        return nil
    end
    local nState = nightMod.State()
    if id == nState.me then
        local _, hrp = getCharacter()
        return hrp
    end
    if id < 0 then
        local rig = nightMod.Rig and nightMod.Rig(id)
        if rig then
            return rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChild("Body")
        end
        return nil
    end
    local c = nightMod.Contestant and nightMod.Contestant(id)
    local plr = c and c.UserId and Players:GetPlayerByUserId(c.UserId)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getRoundModuleTable(roundName)
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local rounds = cmds and cmds:FindFirstChild("Rounds")
    local modScript = rounds and rounds:FindFirstChild(roundName)
    if not modScript then
        return nil
    end
    local ok, mod = pcall(require, modScript)
    return (ok and type(mod) == "table") and mod or nil
end

local function stepHotPumpkin(nightMod)
    local char, hrp, hum = getCharacter()
    if not (char and hrp and hum) then
        return
    end

    local nState = nightMod.State()
    local myId = nState.me
    if not myId then
        return
    end

    -- 1. Collect all active bomb holders from Workspace models, OnState upvalue u135, and tracked HotBombs
    local holdingBomb = false
    local holderIds = {}
    local holderRoots = {}

    for _, hId in pairs(State.Round.HotBombs) do
        holderIds[hId] = true
    end
    for hId in pairs(State.Round.HotHolders) do
        holderIds[hId] = true
    end

    local getupvals = (debug and debug.getupvalues) or getupvalues
    local hpMod = getRoundModuleTable("HotPumpkin")
    local origFn = hpMod and (hpMod.__HG_ORIG_ONSTATE or hpMod.OnState)
    if type(getupvals) == "function" and type(origFn) == "function" then
        local okUp, upvals = pcall(getupvals, origFn)
        if okUp and type(upvals) == "table" then
            for _, uVal in pairs(upvals) do
                if type(uVal) == "table" then
                    for _, entry in pairs(uVal) do
                        if type(entry) == "table" and tonumber(entry.holder) and entry.model then
                            holderIds[tonumber(entry.holder)] = true
                        end
                    end
                end
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and string.find(child.Name, "^HotPumpkin%d+$") then
            local hl = child:FindFirstChildOfClass("Highlight")
            local adornee = hl and hl.Adornee
            if adornee then
                if adornee == char then
                    holdingBomb = true
                else
                    local root = adornee:FindFirstChild("HumanoidRootPart") or adornee.PrimaryPart or adornee:FindFirstChild("Body")
                    if root then
                        holderRoots[root] = true
                    end
                end
            end
        end
    end

    if holderIds[myId] then
        holdingBomb = true
    end

    for hId in pairs(holderIds) do
        if hId ~= myId then
            local root = getContestantRoot(nightMod, hId)
            if root then
                holderRoots[root] = true
            end
        end
    end

    local contestants = nightMod.Contestants and nightMod.Contestants() or {}

    if holdingBomb then
        -- Chase nearest valid non-holder contestant and pass the pumpkin immediately
        local bestId = nil
        local bestRoot = nil
        local bestDist = math.huge

        for id, c in pairs(contestants) do
            if id ~= myId and c.Alive ~= false and not c.Ghost and c.Sitting ~= true and not holderIds[id] then
                local root = getContestantRoot(nightMod, id)
                if root and not holderRoots[root] then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestId = id
                        bestRoot = root
                    end
                end
            end
        end

        if bestRoot then
            hum:MoveTo(bestRoot.Position)
            local now = os.clock()
            if bestDist > 3.2 and (now - State.Round.LastPassAt) >= 0.2 then
                hrp.CFrame = CFrame.new(bestRoot.Position + Vector3.new(1.5, 0, 0))
            end
            if (now - State.Round.LastPassAt) >= 0.25 then
                State.Round.LastPassAt = now
                nightMod.Input("pass", { id = bestId })
            end
        end
    else
        -- Orbit around the arena ring at the point that maximizes minimum distance to all bomb holders
        local arenaCenter = (State.Round.Arena and State.Round.Arena:GetPivot().Position) or nState.origin or hrp.Position
        local nearestHolderDist = math.huge
        for root in pairs(holderRoots) do
            local d = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z).Magnitude
            if d < nearestHolderDist then
                nearestHolderDist = d
            end
        end

        if nearestHolderDist < math.huge then
            local bestCand = hrp.Position
            local bestScore = -math.huge
            local orbitRadius = 17

            for i = 0, 15 do
                local ang = (i * math.pi * 2) / 16
                local cand = Vector3.new(
                    arenaCenter.X + math.cos(ang) * orbitRadius,
                    hrp.Position.Y,
                    arenaCenter.Z + math.sin(ang) * orbitRadius
                )
                local minDistToHolder = math.huge
                for root in pairs(holderRoots) do
                    local hd = Vector3.new(cand.X - root.Position.X, 0, cand.Z - root.Position.Z).Magnitude
                    if hd < minDistToHolder then
                        minDistToHolder = hd
                    end
                end
                local moveDist = Vector3.new(cand.X - hrp.Position.X, 0, cand.Z - hrp.Position.Z).Magnitude
                local score = minDistToHolder - (moveDist * 0.15)
                if score > bestScore then
                    bestScore = score
                    bestCand = cand
                end
            end

            if nearestHolderDist < 11.0 then
                hrp.CFrame = CFrame.new(bestCand.X, hrp.Position.Y, bestCand.Z)
            else
                hum:MoveTo(bestCand)
            end
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 3: LightsOut
-- ============================================================================
local function isInsideAttackZone(attack, pos, margin)
    if not attack then
        return false
    end
    if attack.k == "pounce" then
        return Vector3.new(pos.X - attack.to.X, 0, pos.Z - attack.to.Z).Magnitude <= (attack.r + margin)
    end
    local seg = Vector3.new(attack.to.X - attack.from.X, 0, attack.to.Z - attack.from.Z)
    local rel = Vector3.new(pos.X - attack.from.X, 0, pos.Z - attack.from.Z)
    local t = math.clamp(rel:Dot(seg) / math.max(seg:Dot(seg), 1e-6), 0, 1)
    return (rel - seg * t).Magnitude <= (attack.w / 2 + margin)
end

local function computeAttackEscape(attack, pos, lightCenter)
    if attack.k ~= "pounce" then
        local seg = Vector3.new(attack.to.X - attack.from.X, 0, attack.to.Z - attack.from.Z)
        local perp = Vector3.new(-seg.Z, 0, seg.X)
        local unit = (perp.Magnitude > 0.1) and perp.Unit or Vector3.new(1, 0, 0)
        local side = Vector3.new(pos.X - attack.from.X, 0, pos.Z - attack.from.Z):Dot(unit)
        local sign = (side >= 0) and 1 or -1
        return pos + unit * sign * (attack.w / 2 + 4 - math.abs(side))
    end

    local refCenter = lightCenter or pos
    local bestPos = attack.to
    local bestScore = math.huge
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local cand = attack.to + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (attack.r + 3.5)
        local score = (cand - pos).Magnitude + 0.35 * (cand - refCenter).Magnitude
        if score < bestScore then
            bestScore = score
            bestPos = cand
        end
    end
    return Vector3.new(bestPos.X, pos.Y, bestPos.Z)
end

local function stepLightsOut()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local pos = hrp.Position

    -- Keep native LightsOut Autopilot disabled (u137 = nil) because native steer() has a blackout window bug
    local loMod = getRoundModuleTable("LightsOut")
    if loMod then
        if type(loMod.Autopilot) == "function" and type(debug) == "table" and type(debug.setupvalue) == "function" then
            pcall(debug.setupvalue, loMod.Autopilot, 2, nil)
        end
        local fn = loMod.__HG_ORIG_ONSTATE or loMod.OnState
        if type(fn) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
            local ok, ups = pcall(debug.getupvalues, fn)
            if ok and type(ups) == "table" then
                for _, v in pairs(ups) do
                    if type(v) == "number" and v > 1e9 and v < 2e10 then
                        r.LightStartAt = v
                    elseif type(v) == "table" and type(v[1]) == "table" and #v[1] == 2 and type(v[1][1]) == "number" and v[1][1] < 200 then
                        r.BlackoutSchedule = v
                    elseif type(v) == "function" then
                        local ok2, fups = pcall(debug.getupvalues, v)
                        if ok2 and type(fups) == "table" and fups[2] == Players and type(fups[9]) == "function" then
                            -- lightCheck() upvalues: 1=u112(phase), 2=Players, 3=u108(lightPos), 4=u111(blackout), 5=u105(radius), 8=u149(attack)
                            if typeof(fups[3]) == "Vector3" then
                                r.LightPos = fups[3]
                            end
                            r.Blackout = (fups[4] == true)
                            if type(fups[5]) == "number" and fups[5] > 0 then
                                r.LightRadius = fups[5]
                            end
                            r.ActiveAttack = type(fups[8]) == "table" and fups[8] or nil
                        end
                    end
                end
            end
        end
    end

    -- Fallback: read visual LightFill cylinder in workspace.LightsOutClient
    local loFolder = workspace:FindFirstChild("LightsOutClient")
    local lightFill = loFolder and loFolder:FindFirstChild("LightFill")
    if lightFill and lightFill:IsA("BasePart") and lightFill.Transparency < 0.95 then
        r.LightPos = Vector3.new(lightFill.Position.X, pos.Y, lightFill.Position.Z)
        if lightFill.Size.Y > 2 then
            r.LightRadius = lightFill.Size.Y / 2
        end
    end

    -- Check if blackout pulse is active or within [start - 0.55s, end + 0.25s]
    local blackoutImminent = r.Blackout
    if not blackoutImminent and r.LightStartAt > 0 then
        local elapsed = workspace:GetServerTimeNow() - r.LightStartAt
        for _, window in ipairs(r.BlackoutSchedule) do
            local wStart = tonumber(window[1]) or 0
            local wDur = tonumber(window[2]) or 2.5
            if elapsed >= (wStart - 0.55) and elapsed <= (wStart + wDur + 0.25) then
                blackoutImminent = true
                break
            end
        end
    end

    -- Freeze completely during blackout (never move or teleport while dark)
    if blackoutImminent then
        hum:Move(Vector3.zero)
        hum:MoveTo(pos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end

    local lightCenter = r.LightPos or pos
    local safeRadius = math.max((r.LightRadius or 12) - 2.5, 4)

    -- Pick safe spot inside the light circle that avoids any active Gloomkin attack
    local target = Vector3.new(lightCenter.X, pos.Y, lightCenter.Z)
    if r.ActiveAttack and (isInsideAttackZone(r.ActiveAttack, pos, 3.5) or isInsideAttackZone(r.ActiveAttack, target, 3.5)) then
        local bestCand = nil
        local bestScore = math.huge
        for _, radFrac in ipairs({ 0.35, 0.7 }) do
            local rad = safeRadius * radFrac
            for i = 0, 15 do
                local ang = (i / 16) * math.pi * 2
                local cand = Vector3.new(lightCenter.X + math.cos(ang) * rad, pos.Y, lightCenter.Z + math.sin(ang) * rad)
                if not isInsideAttackZone(r.ActiveAttack, cand, 3.5) then
                    local score = (cand - pos).Magnitude + 0.25 * (cand - target).Magnitude
                    if score < bestScore then
                        bestScore = score
                        bestCand = cand
                    end
                end
            end
        end
        if not bestCand then
            bestCand = computeAttackEscape(r.ActiveAttack, pos, lightCenter)
        end
        target = Vector3.new(bestCand.X, pos.Y, bestCand.Z)
    end

    local flatDist = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z).Magnitude
    local distFromLight = Vector3.new(lightCenter.X - pos.X, 0, lightCenter.Z - pos.Z).Magnitude
    local inDanger = (distFromLight > safeRadius * 0.8)
        or (r.ActiveAttack ~= nil and isInsideAttackZone(r.ActiveAttack, pos, 3.0))

    if inDanger or flatDist > 7.5 then
        hrp.CFrame = CFrame.new(target.X, pos.Y, target.Z) * hrp.CFrame.Rotation
        hum:MoveTo(target)
    elseif flatDist > 1.8 then
        hum:MoveTo(target)
    end
end

-- ============================================================================
-- ROUND SOLVER 4: BumperPumpkins
-- ============================================================================
local function computeDefensiveBumperSteer(myId, ringCenterRel, ringRadius, carsMap, carsHistMap)
    local myPos = carsMap[myId]
    if not myPos then
        return 0, 0, false
    end

    local rx = ringCenterRel.X
    local rz = ringCenterRel.Z
    local rad = math.max(ringRadius or 28, 6)

    -- Compute our velocity from history
    local vx, vz = 0, 0
    local myHist = carsHistMap and carsHistMap[myId]
    if type(myHist) == "table" and #myHist >= 2 then
        local p1 = myHist[#myHist - 1]
        local p2 = myHist[#myHist]
        local dt = (tonumber(p2.t) or 0) - (tonumber(p1.t) or 0)
        if dt > 0.001 then
            vx = ((tonumber(p2.x) or 0) - (tonumber(p1.x) or 0)) / dt
            vz = ((tonumber(p2.z) or 0) - (tonumber(p1.z) or 0)) / dt
        end
    end

    -- Project position 0.45s ahead to counter outward momentum early
    local predX = myPos.X + vx * 0.45
    local predZ = myPos.Z + vz * 0.45

    local offsetX = myPos.X - rx
    local offsetZ = myPos.Z - rz
    local distCenter = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)

    local predOffX = predX - rx
    local predOffZ = predZ - rz
    local predDistCenter = math.sqrt(predOffX * predOffX + predOffZ * predOffZ)

    -- Desired target starts at ring center
    local goalX = rx
    local goalZ = rz

    -- Repulsion from other cars (prevent getting rammed toward the edge)
    local repX, repZ = 0, 0
    for otherId, otherPos in pairs(carsMap) do
        if otherId ~= myId and otherPos then
            local ox = otherPos.X
            local oz = otherPos.Z
            local ovx, ovz = 0, 0
            local oHist = carsHistMap and carsHistMap[otherId]
            if type(oHist) == "table" and #oHist >= 2 then
                local op1 = oHist[#oHist - 1]
                local op2 = oHist[#oHist]
                local odt = (tonumber(op2.t) or 0) - (tonumber(op1.t) or 0)
                if odt > 0.001 then
                    ovx = ((tonumber(op2.x) or 0) - (tonumber(op1.x) or 0)) / odt
                    ovz = ((tonumber(op2.z) or 0) - (tonumber(op1.z) or 0)) / odt
                end
            end
            local futureOx = ox + ovx * 0.25
            local futureOz = oz + ovz * 0.25
            local dx = myPos.X - futureOx
            local dz = myPos.Z - futureOz
            local d = math.sqrt(dx * dx + dz * dz)
            if d < 12.0 and d > 0.05 then
                -- Sidestep perpendicular/inward rather than outward!
                local weight = ((12.0 - d) / 12.0) ^ 1.5 * 8.0
                repX = repX + (dx / d) * weight
                repZ = repZ + (dz / d) * weight
            end
        end
    end

    -- Clamp goal strictly inside 38% of ring radius so avoidance never pushes us toward the ring edge
    local rawGoalOffX = (goalX + repX) - rx
    local rawGoalOffZ = (goalZ + repZ) - rz
    local rawGoalDist = math.sqrt(rawGoalOffX * rawGoalOffX + rawGoalOffZ * rawGoalOffZ)
    local maxSafeOrbit = math.max(rad * 0.35, 2.5)
    if rawGoalDist > maxSafeOrbit and rawGoalDist > 0.01 then
        rawGoalOffX = rawGoalOffX / rawGoalDist * maxSafeOrbit
        rawGoalOffZ = rawGoalOffZ / rawGoalDist * maxSafeOrbit
    end
    goalX = rx + rawGoalOffX
    goalZ = rz + rawGoalOffZ

    -- PD velocity controller: desired velocity toward goal minus current velocity
    local toGoalX = goalX - myPos.X
    local toGoalZ = goalZ - myPos.Z
    local toGoalDist = math.sqrt(toGoalX * toGoalX + toGoalZ * toGoalZ)

    local desSpeed = math.clamp(toGoalDist * 3.2, 0, 28)
    if distCenter > rad * 0.55 or predDistCenter > rad * 0.62 then
        -- Emergency inward recovery: point straight at ring center at full speed
        toGoalX = rx - myPos.X
        toGoalZ = rz - myPos.Z
        toGoalDist = math.sqrt(toGoalX * toGoalX + toGoalZ * toGoalZ)
        desSpeed = 32
    end

    local desVx, desVz = 0, 0
    if toGoalDist > 0.05 then
        desVx = (toGoalX / toGoalDist) * desSpeed
        desVz = (toGoalZ / toGoalDist) * desSpeed
    end

    -- Subtract current velocity (damping) so car brakes instead of overshooting center
    local steerX = desVx - vx * 0.85
    local steerZ = desVz - vz * 0.85
    local steerMag = math.sqrt(steerX * steerX + steerZ * steerZ)
    if steerMag > 0.05 then
        steerX = steerX / steerMag
        steerZ = steerZ / steerMag
    else
        steerX, steerZ = 0, 0
    end

    -- Only boost when recovering inward from outer half OR dodging an imminent ram while pointing inward
    local outSpeed = 0
    if distCenter > 0.5 then
        outSpeed = (vx * offsetX + vz * offsetZ) / distCenter
    end
    local wantBoost = (distCenter > rad * 0.58) or (predDistCenter > rad * 0.68) or (distCenter > rad * 0.42 and outSpeed > 10)

    return steerX, steerZ, wantBoost
end

local function stepBumperPumpkins(nightMod)
    local now = os.clock()
    if now - State.Round.LastSteerAt < 0.06 then
        return
    end
    State.Round.LastSteerAt = now

    local nState = nightMod.State()
    local myId = nState.me
    if not myId then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local setupval = (debug and debug.setupvalue) or setupvalue
    local bpMod = getRoundModuleTable("BumperPumpkins")
    local carsHistMap = nil

    if bpMod and type(getupval) == "function" then
        -- 1. Read live ring and car positions directly from decode upvalue of BumperPumpkins.OnState
        --    Note: inside decode(a1), u166 = ringRadius (#2), u168 = ringZ (#4), u169 = ringHistory (#5), u165 = carsHistMap (#6)
        local origOnState = bpMod.__HG_ORIG_ONSTATE
        if not origOnState and type(bpMod.OnState) == "function" then
            local okU, u3 = pcall(getupval, bpMod.OnState, 3)
            origOnState = (okU and type(u3) == "function") and u3 or bpMod.OnState
        end
        if type(origOnState) == "function" then
            local okD, decodeFn = pcall(getupval, origOnState, 1)
            local okA, arenaCf = pcall(getupval, origOnState, 3)
            if okD and type(decodeFn) == "function" then
                local _, ringR = pcall(getupval, decodeFn, 2)
                local _, ringHist = pcall(getupval, decodeFn, 5)
                local _, cMap = pcall(getupval, decodeFn, 6)
                if tonumber(ringR) and ringR > 0 then
                    r.RingRadius = tonumber(ringR)
                end
                if type(ringHist) == "table" and #ringHist > 0 then
                    local latestRing = ringHist[#ringHist]
                    if latestRing and tonumber(latestRing.x) and tonumber(latestRing.z) then
                        r.BumperRingRel = Vector3.new(latestRing.x, 0, latestRing.z)
                        if tonumber(latestRing.r) and latestRing.r > 0 then
                            r.RingRadius = tonumber(latestRing.r)
                        end
                        if okA and typeof(arenaCf) == "CFrame" then
                            r.RingCenter = arenaCf:PointToWorldSpace(r.BumperRingRel)
                        end
                    end
                end
                if type(cMap) == "table" then
                    carsHistMap = cMap
                    for id, hist in pairs(cMap) do
                        if type(hist) == "table" and #hist > 0 then
                            local latest = hist[#hist]
                            if latest and tonumber(latest.x) and tonumber(latest.z) then
                                r.BumperCars[id] = Vector3.new(latest.x, 0, latest.z)
                            end
                        end
                    end
                end
            end
        end

        -- 2. Hook steerFn's moveVector (upvalue #14) AND boostFn's moveVector (upvalue #10)
        --    with our defensive PD ring-center + anti-ram controller!
        if type(setupval) == "function" then
            local origEnter = bpMod.__HG_ORIG_ENTER
            if not origEnter and type(bpMod.Enter) == "function" then
                local okE, u6 = pcall(getupval, bpMod.Enter, 6)
                origEnter = (okE and type(u6) == "function") and u6 or bpMod.Enter
            end
            if type(origEnter) == "function" then
                local okR, renderFn = pcall(getupval, origEnter, 17)
                if okR and type(renderFn) == "function" then
                    local okS, steerFn = pcall(getupval, renderFn, 3)
                    if okS and type(steerFn) == "function" then
                        local _, boostFn = pcall(getupval, steerFn, 13)
                        local _, curMoveVecFn = pcall(getupval, steerFn, 14)

                        if curMoveVecFn ~= r.HookedMoveVecFn then
                            r.HookedMoveVecFn = function()
                                local _, arenaCf = pcall(getupval, steerFn, 10)
                                local sx, sz, wantBoost = computeDefensiveBumperSteer(
                                    myId,
                                    r.BumperRingRel,
                                    r.RingRadius,
                                    r.BumperCars,
                                    carsHistMap
                                )
                                if wantBoost and type(boostFn) == "function" and (os.clock() - r.LastBoostAt) > 0.5 then
                                    r.LastBoostAt = os.clock()
                                    task.defer(pcall, boostFn)
                                end
                                local localVec = Vector3.new(sx, 0, sz)
                                if localVec.Magnitude > 1 then
                                    localVec = localVec.Unit
                                end
                                if typeof(arenaCf) == "CFrame" then
                                    return arenaCf:VectorToWorldSpace(localVec)
                                end
                                return localVec
                            end
                            pcall(setupval, steerFn, 14, r.HookedMoveVecFn)
                            if type(boostFn) == "function" then
                                pcall(setupval, boostFn, 10, r.HookedMoveVecFn)
                            end
                            log("BumperPumpkins hooked defensive PD moveVector on steer + boost")
                        end
                    end
                end
            end
        end
    end

    -- Fallback if steerFn moveVector could not be hooked
    if not r.HookedMoveVecFn then
        local sx, sz, wantBoost = computeDefensiveBumperSteer(
            myId,
            r.BumperRingRel,
            r.RingRadius,
            r.BumperCars,
            carsHistMap
        )
        local arena = r.Arena
        local worldDir = Vector3.new(sx, 0, sz)
        if arena and worldDir.Magnitude > 0.01 then
            worldDir = arena:GetPivot():VectorToWorldSpace(worldDir)
        end
        nightMod.Input("steer", {
            x = math.floor(worldDir.X * 100) / 100,
            z = math.floor(worldDir.Z * 100) / 100,
        })
        if wantBoost and (now - r.LastBoostAt) > 0.8 then
            r.LastBoostAt = now
            nightMod.Input("boost", {
                x = math.floor(worldDir.X * 100) / 100,
                z = math.floor(worldDir.Z * 100) / 100,
            })
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 5: PumpkinColors
-- ============================================================================
local function stepPumpkinColors()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local pcMod = getRoundModuleTable("PumpkinColors")
    local origFn = pcMod and (pcMod.__HG_ORIG_ONSTATE or pcMod.OnState)
    if not origFn and pcMod and type(pcMod.OnState) == "function" and type(getupval) == "function" then
        local okU, u3 = pcall(getupval, pcMod.OnState, 3)
        origFn = (okU and type(u3) == "function") and u3 or pcMod.OnState
    end

    local directPadsMap = nil
    local unsafePadsSet = {}

    if type(getupval) == "function" and type(origFn) == "function" then
        -- u64 (upvalue #4): { text, first, second, round, startsAt, endsAt }
        local okCall, u64 = pcall(getupval, origFn, 4)
        if okCall and type(u64) == "table" and type(u64.first) == "string" and tonumber(u64.endsAt) then
            r.SafeColors = { u64.first }
            if type(u64.second) == "string" then
                table.insert(r.SafeColors, u64.second)
            end
            r.ColorCallEndsAt = tonumber(u64.endsAt)
        end
        -- u67 (upvalue #15): array of UNSAFE pad BaseParts for the active call
        local okUnsafe, u67 = pcall(getupval, origFn, 15)
        if okUnsafe and type(u67) == "table" then
            for _, p in ipairs(u67) do
                unsafePadsSet[p] = true
            end
        end
        -- u59 (upvalue #16): map of padIndex -> BasePart (all 16 pads)
        local okPads, u59 = pcall(getupval, origFn, 16)
        if okPads and type(u59) == "table" then
            directPadsMap = u59
        end
    end

    local nowServer = workspace:GetServerTimeNow()
    if #r.SafeColors == 0 or nowServer >= (r.ColorCallEndsAt - 0.02) then
        return
    end

    local allowedColor = {}
    for _, cName in ipairs(r.SafeColors) do
        allowedColor[cName] = true
    end

    local bestPad = nil
    local bestDist = math.huge

    -- Priority 1: Use u59 (all pads) minus u67 (unsafe pads) from PumpkinColors.OnState upvalues
    if directPadsMap and next(unsafePadsSet) ~= nil then
        for _, pad in pairs(directPadsMap) do
            if typeof(pad) == "Instance" and pad:IsA("BasePart") and not unsafePadsSet[pad] and pad:GetAttribute("Hidden") ~= true then
                local d = Vector3.new(pad.Position.X - hrp.Position.X, 0, pad.Position.Z - hrp.Position.Z).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPad = pad
                end
            end
        end
    end

    -- Priority 2: Scan arena descendants by ColorName attribute
    local arena = r.Arena
    if not bestPad and arena then
        for _, desc in ipairs(arena:GetDescendants()) do
            if desc:IsA("BasePart") then
                local cName = desc:GetAttribute("ColorName")
                local hidden = desc:GetAttribute("Hidden")
                if cName and allowedColor[cName] and hidden ~= true and not unsafePadsSet[desc] then
                    local d = Vector3.new(desc.Position.X - hrp.Position.X, 0, desc.Position.Z - hrp.Position.Z).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestPad = desc
                    end
                end
            end
        end
    end

    if bestPad then
        local targetPos = Vector3.new(bestPad.Position.X, hrp.Position.Y, bestPad.Position.Z)
        if bestDist > 5.0 or ((r.ColorCallEndsAt - nowServer) < 1.8 and bestDist > 1.0) then
            hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
            hum:MoveTo(targetPos)
        elseif bestDist > 0.75 then
            hum:MoveTo(targetPos)
        else
            hum:Move(Vector3.zero)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 6: TrickOrTreatDoors (Part 2 Final Round)
-- ============================================================================
local function findDoorBoothTrigger(arena, doorId, directDoorsMap)
    if type(directDoorsMap) == "table" and type(directDoorsMap[doorId]) == "table" then
        local entry = directDoorsMap[doorId]
        if typeof(entry.trigger) == "Instance" and entry.trigger:IsA("BasePart") then
            return entry.trigger
        end
    end
    if not arena then
        return nil
    end
    local booths = arena:FindFirstChild("DoorBooths") or arena
    for _, booth in ipairs(booths:GetChildren()) do
        local attrId = booth:GetAttribute("DoorId") or booth:GetAttribute("Id") or tonumber(string.match(booth.Name, "%d+"))
        if attrId == doorId then
            local trig = booth:FindFirstChild("Trigger", true)
                or booth:FindFirstChild("Pad", true)
                or booth:FindFirstChildWhichIsA("BasePart", true)
            if trig then
                return trig
            end
        end
    end
    return nil
end

local function isDoorPickable(doorId)
    local r = State.Round
    if r.RevealedDoors[doorId] == "trick" then
        return false
    end
    if r.TakenDoors[doorId] == true then
        return false
    end
    if r.HiddenDoors[doorId] ~= nil then
        return false
    end
    return true
end

local function chooseBestDoorId()
    local r = State.Round
    if #r.ActiveDoors == 0 then
        return nil
    end

    local candidates = {}
    for _, doorId in ipairs(r.ActiveDoors) do
        if doorId ~= r.LanternDoorId and isDoorPickable(doorId) then
            table.insert(candidates, doorId)
        end
    end

    if #candidates == 0 then
        -- Fallback to any pickable door even if Lantern flagged it (shouldn't happen unless 1 door)
        for _, doorId in ipairs(r.ActiveDoors) do
            if isDoorPickable(doorId) then
                return doorId
            end
        end
        return r.ActiveDoors[1]
    end

    -- 1. Prefer doors already revealed as "treat" that are still pickable
    for _, doorId in ipairs(candidates) do
        if r.RevealedDoors[doorId] == "treat" and doorId ~= r.SniffDoorId then
            return doorId
        end
    end

    -- 2. Prefer unopened doors not flagged by SniffHint ("smells funny" = likely trick)
    for _, doorId in ipairs(candidates) do
        if doorId ~= r.SniffDoorId and r.RevealedDoors[doorId] == nil then
            return doorId
        end
    end

    -- 3. Any candidate not flagged by SniffHint
    for _, doorId in ipairs(candidates) do
        if doorId ~= r.SniffDoorId then
            return doorId
        end
    end

    return candidates[1]
end

local function stepTrickOrTreatDoors(nightMod)
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local tdMod = getRoundModuleTable("TrickOrTreatDoors")
    local origFn = tdMod and (tdMod.__HG_ORIG_ONSTATE or tdMod.OnState)
    if not origFn and tdMod and type(tdMod.OnState) == "function" and type(getupval) == "function" then
        local okU, u3 = pcall(getupval, tdMod.OnState, 3)
        origFn = (okU and type(u3) == "function") and u3 or tdMod.OnState
    end

    local directDoorsMap = nil
    local setPreviewFn = nil
    if type(getupval) == "function" and type(origFn) == "function" then
        -- Verified TrickOrTreatDoors.OnState upvalue layout:
        -- #1 u83 (activeDoors array), #2 u84 (activeMap), #3 u85 (revealedMap),
        -- #4 u86 (takenDoors map!), #5 u87 (doorPhase string!),
        -- #10 u105 (waveIndex), #12 u88 (committedDoorId!),
        -- #15 setPreview(doorId), #17 u94 (sniffDoorId!),
        -- #19 u95 (lanternDoorId!), #21 u82 (doorsMap!), #23 u99 (hiddenDoorsMap!)
        local _, u83 = pcall(getupval, origFn, 1)
        local _, u85 = pcall(getupval, origFn, 3)
        local _, u86 = pcall(getupval, origFn, 4)
        local _, u87 = pcall(getupval, origFn, 5)
        local _, u105 = pcall(getupval, origFn, 10)
        local _, u88 = pcall(getupval, origFn, 12)
        local _, spFn = pcall(getupval, origFn, 15)
        local _, u94 = pcall(getupval, origFn, 17)
        local _, u95 = pcall(getupval, origFn, 19)
        local _, u82 = pcall(getupval, origFn, 21)
        local _, u99 = pcall(getupval, origFn, 23)

        if type(u83) == "table" and #u83 > 0 then
            r.ActiveDoors = u83
        end
        if type(u85) == "table" then
            r.RevealedDoors = u85
        end
        if type(u86) == "table" then
            r.TakenDoors = u86
        end
        if type(u87) == "string" and u87 ~= "" then
            r.DoorPhase = u87
        end
        if tonumber(u105) and tonumber(u105) > 0 then
            r.DoorWave = tonumber(u105)
        end
        r.CommittedDoorId = u88
        if type(spFn) == "function" then
            setPreviewFn = spFn
        end
        r.SniffDoorId = tonumber(u94) or r.SniffDoorId
        r.LanternDoorId = tonumber(u95) or r.LanternDoorId
        if type(u82) == "table" then
            directDoorsMap = u82
        end
        if type(u99) == "table" then
            r.HiddenDoors = u99
        end
    end

    if (r.DoorPhase ~= "pick" and r.DoorPhase ~= "sniff") or r.CommittedDoorId ~= nil then
        return
    end

    local m = getModules()
    if Config.AutoUseLanternInFinal and m and m.HalloweenGames and r.DoorPhase == "pick" then
        local nState = nightMod.State()
        local waveKey = tostring(nState.roundId) .. "_" .. tostring(r.DoorWave)
        if State.LanternUsedRoundId ~= waveKey and hasTrickItem(m.HalloweenGames.TRICKS.Lantern) then
            State.LanternUsedRoundId = waveKey
            log("Using Lantern in TrickOrTreatDoors")
            nightMod.Trick("Lantern")
        end
    end

    local targetDoorId = chooseBestDoorId()
    if not targetDoorId then
        return
    end

    local trig = findDoorBoothTrigger(r.Arena, targetDoorId, directDoorsMap)
    if trig then
        -- Stand right inside the trigger box (same check as TrickOrTreatDoors.step(): |X|<=Size.X/2, |Z|<=Size.Z/2)
        local targetPos = Vector3.new(trig.Position.X, hrp.Position.Y, trig.Position.Z)
        local dist = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z).Magnitude
        if dist > 2.2 then
            hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
            hum:MoveTo(targetPos)
        else
            hum:MoveTo(targetPos)
        end
        if r.DoorPhase == "pick" then
            if type(setPreviewFn) == "function" then
                pcall(setPreviewFn, targetDoorId)
            end
            if (os.clock() - r.LastCommitAt) > 0.32 then
                r.LastCommitAt = os.clock()
                nightMod.Input("CommitDoor", { doorId = targetDoorId })
            end
        end
    elseif r.DoorPhase == "pick" then
        if (os.clock() - r.LastCommitAt) > 0.4 then
            r.LastCommitAt = os.clock()
            nightMod.Input("CommitDoor", { doorId = targetDoorId })
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 7: ScarecrowStare (Part 1 Round 1)
-- ============================================================================
local function stepScarecrowStare()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    if r.ScarecrowFinished then
        hum:Move(Vector3.zero)
        return
    end

    if r.ScarecrowLight == "green" then
        local arena = r.Arena
        local finish = arena and (arena:FindFirstChild("FinishWall", true) or arena:FindFirstChild("ScarecrowRig", true))
        if finish then
            local finishPos = finish:IsA("BasePart") and finish.Position or finish:GetPivot().Position
            hum:MoveTo(Vector3.new(finishPos.X, hrp.Position.Y, finishPos.Z))
        end
    else
        hum:MoveTo(hrp.Position)
        hum:Move(Vector3.zero)
    end
end

-- ============================================================================
-- HOOK ROUND MODULES (Enter / OnState / Leave)
-- ============================================================================
local function handleRoundOnState(roundName, packet)
    if type(packet) ~= "table" then
        return
    end
    local ev = packet.event
    local data = packet.data or {}
    local r = State.Round

    if roundName == "BroomSweep" then
        if ev == "sweep" then
            r.BroomConfig = data
            if typeof(data.origin) == "CFrame" then
                r.BroomOrigin = data.origin
            end
        elseif ev == "luck" then
            r.BroomLead = tonumber(data.lead) or 0
        elseif ev == "phase" then
            r.Phase = data.phase
        end

    elseif roundName == "HotPumpkin" then
        if ev == "light" then
            if data.k and data.holder then
                r.HotBombs[data.k] = data.holder
            end
        elseif ev == "pass" then
            if data.k and data.to then
                r.HotBombs[data.k] = data.to
            end
        elseif ev == "pop" then
            if data.k then
                r.HotBombs[data.k] = nil
            end
        elseif ev == "over" or ev == "boom" then
            table.clear(r.HotBombs)
            table.clear(r.HotHolders)
        end
        table.clear(r.HotHolders)
        for _, hId in pairs(r.HotBombs) do
            r.HotHolders[hId] = true
        end

    elseif roundName == "LightsOut" then
        if ev == "pulse" or ev == "blackout" then
            r.Blackout = (data.on == true) or (data.active == true)
        elseif ev == "intro" then
            local y = data.floorY or (r.LightPos and r.LightPos.Y) or 0
            if type(data.center) == "table" and data.center.x and data.center.z then
                r.LightPos = Vector3.new(data.center.x, y, data.center.z)
            end
            if tonumber(data.radius) then
                r.LightRadius = tonumber(data.radius)
            end
        elseif ev == "drop" or ev == "hunt" or ev == "start" or ev == "init" then
            if type(data.pulses) == "table" then
                r.BlackoutSchedule = data.pulses
            elseif type(data.blackouts) == "table" then
                r.BlackoutSchedule = data.blackouts
            end
            if tonumber(data.at) then
                r.LightStartAt = tonumber(data.at)
            elseif tonumber(data.t0) then
                r.LightStartAt = tonumber(data.t0)
            end
            if tonumber(data.radius) then
                r.LightRadius = tonumber(data.radius)
            end
        elseif ev == "state" or ev == "light" or ev == "candle" then
            local cx = data.cx or data.x
            local cz = data.cz or data.z
            if cx and cz then
                local y = r.LightPos and r.LightPos.Y or 0
                r.LightPos = Vector3.new(cx, y, cz)
            end
            if data.vx and data.vz then
                r.LightVel = Vector3.new(data.vx, 0, data.vz)
            end
            if data.r and data.r > 0 then
                r.LightRadius = data.r
            end
        elseif ev == "attack" or ev == "telegraph" then
            local y = r.LightPos and r.LightPos.Y or 0
            r.ActiveAttack = {
                k = data.k,
                from = Vector3.new(data.fx or 0, y, data.fz or 0),
                to = Vector3.new(data.tx or 0, y, data.tz or 0),
                r = data.r or 7,
                w = data.w or 7,
                at = data.at or (workspace:GetServerTimeNow() + 1.2),
            }
        elseif ev == "strike" or ev == "land" or ev == "clear" then
            r.ActiveAttack = nil
        elseif ev == "flare" then
            r.Blackout = false
            r.ActiveAttack = nil
        end

    elseif roundName == "BumperPumpkins" then
        if typeof(data) == "buffer" and buffer.len(data) >= 16 and buffer.readu8(data, 0) == 2 then
            local carCount = buffer.readu8(data, 1)
            r.RingRadius = buffer.readu16(data, 2) / 64
            local rx = buffer.readi16(data, 12) / 32
            local rz = buffer.readi16(data, 14) / 32
            r.BumperRingRel = Vector3.new(rx, 0, rz)
            if r.Arena then
                r.RingCenter = r.Arena:GetPivot():PointToWorldSpace(r.BumperRingRel)
            end
            local len = buffer.len(data)
            for i = 0, carCount - 1 do
                local offset = 16 + i * 8
                if offset + 6 <= len then
                    local id = buffer.readi16(data, offset)
                    local cx = buffer.readi16(data, offset + 2) / 32
                    local cz = buffer.readi16(data, offset + 4) / 32
                    r.BumperCars[id] = Vector3.new(cx, 0, cz)
                end
            end
        end

    elseif roundName == "PumpkinColors" then
        if ev == "call" then
            r.SafeColors = data.called or {}
            r.SafePads = data.safe or {}
            r.ColorCallEndsAt = tonumber(data.endsAt) or (workspace:GetServerTimeNow() + 4)
        elseif ev == "board" or ev == "drop" then
            table.clear(r.SafeColors)
        end

    elseif roundName == "TrickOrTreatDoors" then
        if ev == "wave" then
            r.DoorWave = (tonumber(data.waveIndex) or (r.DoorWave + 1))
            r.ActiveDoors = data.doors or {}
            table.clear(r.RevealedDoors)
            table.clear(r.TakenDoors)
            r.SniffDoorId = nil
            r.LanternDoorId = nil
            r.CommittedDoorId = nil
            r.DoorPhase = "sniff"
        elseif ev == "SniffHint" then
            r.SniffDoorId = data.doorId
        elseif ev == "lantern" then
            r.LanternDoorId = data.doorId
        elseif ev == "taken" and data.doorId then
            r.TakenDoors[data.doorId] = true
        elseif ev == "pick" then
            r.DoorPhase = "pick"
        elseif ev == "DoorRevealed" and data.doorId then
            r.RevealedDoors[data.doorId] = data.result
        elseif ev == "committed" then
            local m = getModules()
            local nState = m and m.Night and m.Night.State()
            if nState and data.id == nState.me then
                r.CommittedDoorId = data.doorId
            end
        elseif ev == "WaveResult" then
            r.DoorPhase = "reveal"
        end

    elseif roundName == "ScarecrowStare" then
        if ev == "light" then
            r.ScarecrowLight = tostring(data.state or "red")
        elseif ev == "early" then
            r.ScarecrowLight = "tell"
        elseif ev == "finished" then
            local m = getModules()
            local nState = m and m.Night and m.Night.State()
            if nState and data.id == nState.me then
                r.ScarecrowFinished = true
            end
        end
    end
end

local function installRoundHooks()
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local roundsFolder = cmds and cmds:FindFirstChild("Rounds")
    if not roundsFolder then
        return false
    end

    for _, modScript in ipairs(roundsFolder:GetChildren()) do
        if modScript:IsA("ModuleScript") and modScript.Name ~= "_Sample" then
            local ok, roundMod = pcall(require, modScript)
            if ok and type(roundMod) == "table" and not roundMod.__HG_HOOKED then
                local roundName = modScript.Name
                local origEnter = roundMod.Enter
                local origOnState = roundMod.OnState
                local origLeave = roundMod.Leave

                roundMod.__HG_HOOKED = true
                roundMod.__HG_ORIG_ENTER = origEnter
                roundMod.__HG_ORIG_ONSTATE = origOnState

                if type(origEnter) == "function" then
                    roundMod.Enter = function(arena, info, ...)
                        resetRoundState(roundName, arena, info)
                        tryEnableNativeAutopilot(roundName, roundMod)
                        log("Entered round: " .. roundName)
                        return origEnter(arena, info, ...)
                    end
                end

                if type(origOnState) == "function" then
                    roundMod.OnState = function(packet, ...)
                        pcall(handleRoundOnState, roundName, packet)
                        return origOnState(packet, ...)
                    end
                end

                if type(origLeave) == "function" then
                    roundMod.Leave = function(...)
                        if State.Round.Id == roundName then
                            State.Round.Id = nil
                        end
                        return origLeave(...)
                    end
                end

                table.insert(State.Restorers, function()
                    roundMod.Enter = origEnter
                    roundMod.OnState = origOnState
                    roundMod.Leave = origLeave
                    roundMod.__HG_ORIG_ENTER = nil
                    roundMod.__HG_ORIG_ONSTATE = nil
                    roundMod.__HG_HOOKED = nil
                end)
            end
        end
    end
    return true
end

-- ============================================================================
-- CORE LOBBY / MATCH LOOP
-- ============================================================================
local function getCirclePart()
    local model = getActiveInstanceModel()
    if not model then
        return nil
    end
    if model.Name ~= "Models" and model:FindFirstChild("Models") then
        model = model.Models
    end
    local hub = model:FindFirstChild("Hub")
    local circle = hub and hub:FindFirstChild("Circle")
    if circle and circle:IsA("BasePart") then
        return circle
    end
    return nil
end

local function selectBestNight(nightMod, nightSelectMod)
    if not (nightMod and nightSelectMod and type(nightSelectMod.DebugJson) == "function") then
        return
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(nightSelectMod.DebugJson())
    end)
    if not (ok and type(decoded) == "table") then
        return
    end

    if decoded.last ~= "pick" and not decoded.open then
        return
    end

    local unlocked = {}
    for _, n in ipairs(decoded.nights or {}) do
        unlocked[tonumber(n) or 0] = true
    end

    local chosen = nil
    local maxN = math.clamp(Config.MaxNight or 5, 1, 5)

    if Config.NightSelectMode == "Fixed" then
        local fixed = math.clamp(Config.FixedNight or 5, 1, maxN)
        if unlocked[fixed] then
            chosen = fixed
        end
    elseif Config.NightSelectMode == "Recommended" and type(decoded.rows) == "table" then
        for n = maxN, 1, -1 do
            local row = decoded.rows[n] or decoded.rows[tostring(n)]
            if unlocked[n] and row and row.ready == true then
                chosen = n
                break
            end
        end
    end

    if not chosen then
        for n = maxN, 1, -1 do
            if unlocked[n] then
                chosen = n
                break
            end
        end
    end

    if chosen and (os.clock() - State.LastCirclePickAt) > 1.5 then
        State.LastCirclePickAt = os.clock()
        log("Selecting Night " .. tostring(chosen))
        nightMod.Circle("pick", chosen)
        local m = getModules()
        if m and m.TabController and m.TabController.IsOpen("HalloweenGamesNightSelect") then
            pcall(m.TabController.CloseTab)
        end
    end
end

-- Handle the multiplayer Queue Lobby place ("Want to Play? Join Here!")
local function stepQueueLobby(hrp)
    local models = workspace:FindFirstChild("Models")
    local padModel = models and models:FindFirstChild("Pad")
    local innerPad = padModel and padModel:FindFirstChild("Pad")
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if not (innerPad and netFolder and netFolder:FindFirstChild("RequestRegister")) then
        return false
    end

    -- Nếu đang trong chu kỳ PostMatchPending -> Không vào pad sảnh chờ, kích hoạt thoát ra Map Halloween
    if State.PostMatchPending then
        leaveMinigameToHalloweenMap()
        return true
    end

    -- Do not pull player back if server already started teleporting to match
    local board = models:FindFirstChild("Board")
    local sgui = board and board:FindFirstChild("SurfaceGui")
    local frame = sgui and sgui:FindFirstChild("Frame")
    local timerLabel = frame and frame:FindFirstChild("Timer")
    if timerLabel and (timerLabel.Text == "Teleporting!" or timerLabel.Text == "Closed right now") then
        return true
    end

    local tpHide = models:FindFirstChild("TeleportHide")
    if tpHide and tpHide:IsA("BasePart") and (hrp.Position - tpHide.Position).Magnitude < 25 then
        return true
    end

    local padPos = innerPad:GetPivot().Position
    local safeRadius = math.max((innerPad.Size.X / 2) - 4, 6)
    local flatDist = Vector3.new(hrp.Position.X - padPos.X, 0, hrp.Position.Z - padPos.Z).Magnitude
    local registered = (padModel:GetAttribute("Registered") == true)

    if flatDist > safeRadius or math.abs(hrp.Position.Y - padPos.Y) > 12 or not registered then
        if (os.clock() - State.LastLobbyJoinAt) > 1.5 then
            State.LastLobbyJoinAt = os.clock()
            log("Joining Queue Lobby Pad")
            hrp.CFrame = CFrame.new(padPos + Vector3.new(0, 3.5, 0))
            local reqReg = netFolder:FindFirstChild("RequestRegister")
            if reqReg and reqReg:IsA("RemoteFunction") then
                task.spawn(function()
                    local ok, res = pcall(reqReg.InvokeServer, reqReg)
                    if ok and res == true then
                        padModel:SetAttribute("Registered", true)
                    end
                end)
            end
        end
    end

    return true
end

local function syncRoundFromNightState(activeModel, nState)
    if not (activeModel and nState and nState.roundId) then
        return
    end
    local r = State.Round
    if r.Id ~= nState.roundId or not r.Arena then
        local model = activeModel
        if model.Name ~= "Models" and model:FindFirstChild("Models") then
            model = model.Models
        end
        local slots = model:FindFirstChild("ArenaSlots")
        local slotFolder = slots and slots:FindFirstChild("Slot" .. tostring(nState.slot or 1))
        local arenaName = (nState.config and nState.config.Arena) or nState.roundId
        local arena = slotFolder and slotFolder:FindFirstChild(arenaName)
        if r.Id ~= nState.roundId then
            resetRoundState(nState.roundId, arena, { config = nState.config })
            log("Round active: " .. tostring(nState.roundId))
        else
            r.Arena = arena or r.Arena
            if nState.config and nState.config.t0 then
                r.BroomConfig = nState.config
            end
            if not r.BroomOrigin and r.Arena then
                r.BroomOrigin = r.Arena:GetPivot()
            end
        end
    end
end

local function isOngoingMatchSpectator(nightMod, nightSelectMod)
    if nightSelectMod and type(nightSelectMod.Circle) == "function" then
        local getupval = (debug and debug.getupvalue) or getupvalue
        if type(getupval) == "function" then
            local okU, u55 = pcall(getupval, nightSelectMod.Circle, 1)
            if okU and type(u55) == "table" and u55.phase == "wait" and type(u55.reason) == "string" then
                if string.find(string.lower(u55.reason), "match is on") then
                    return true
                end
            end
        end
    end
    local nState = nightMod and nightMod.State() or {}
    if type(nState.banner) == "string" and string.find(string.lower(nState.banner), "match is on") then
        return true
    end
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local hgHud = pgui and pgui:FindFirstChild("HalloweenGamesHud")
    if hgHud then
        for _, desc in ipairs(hgHud:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and string.find(string.lower(desc.Text), "match is on") then
                return true
            end
        end
    end
    return false
end

local function stepMainLoop()
    if not Config.Enabled or not State.Running then
        return
    end

    applyEngineOptimization()
    stepOptimization()

    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    -- 1. Check if in Multiplayer Queue Lobby ("Want to Play? Join Here!")
    if stepQueueLobby(hrp) then
        return
    end

    -- 2. Check if inside HalloweenGames instance
    local activeModel = getActiveInstanceModel()
    if not activeModel then
        -- Only use World 1 portal when NOT in a dedicated match place and not in post-match flow
        if Config.AutoEnterInstance and not isDedicatedMatchPlace() and not State.PostMatchPending and (os.clock() - State.LastPortalEnterAt) > 3.0 then
            local things = workspace:FindFirstChild("__THINGS")
            local instances = things and things:FindFirstChild("Instances")
            local hgPortal = instances and instances:FindFirstChild("HalloweenGames")
            local teleports = hgPortal and hgPortal:FindFirstChild("Teleports")
            local enterPart = teleports and teleports:FindFirstChild("Enter")
            if enterPart and enterPart:IsA("BasePart") then
                State.LastPortalEnterAt = os.clock()
                log("Entering HalloweenGames portal")
                hrp.CFrame = enterPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
        return
    end

    installRoundHooks()

    local m = getModules()
    if not (m and m.Night) then
        return
    end

    local nightMod = m.Night
    local nState = nightMod.State() or {}
    local inActiveNight = (nState.nightId ~= nil and nState.phase ~= "ended")

    if not inActiveNight then
        closeEliminatedScreenIfOpen(nightMod)

        -- Recover if character is falling into void while waiting in match server
        if hrp.Position.Y < -200 then
            local circle = getCirclePart()
            if circle then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(circle.Position + Vector3.new(0, 5, 0))
            end
        end

        if isOngoingMatchSpectator(nightMod, m.NightSelect) then
            if (os.clock() - State.LastExitAt) > 3.0 then
                State.LastExitAt = os.clock()
                log("Ongoing match spectator detected, kích hoạt quy trình Post-Match")
                triggerPostMatchFlow(nightMod)
            end
            return
        end

        if nState.phase == "ended" and (isDedicatedMatchPlace() or nState.match == true) then
            if (os.clock() - State.LastExitAt) > 3.0 then
                State.LastExitAt = os.clock()
                log("Trận đấu kết thúc, kích hoạt quy trình Post-Match")
                triggerPostMatchFlow(nightMod)
            end
            return
        end

        -- In the dedicated 20-player Match place, wait for the server to start the match; do not teleport to Hub.Circle
        if isDedicatedMatchPlace() or nState.match == true then
            return
        end

        local circle = getCirclePart()
        if circle then
            local flatDist = Vector3.new(hrp.Position.X - circle.Position.X, 0, hrp.Position.Z - circle.Position.Z).Magnitude
            local maxRadius = math.max(circle.Size.Y, circle.Size.Z) / 2
            if flatDist > maxRadius or math.abs(hrp.Position.Y - circle.Position.Y) > 12 then
                if (os.clock() - State.LastCircleMoveAt) > 1.0 then
                    State.LastCircleMoveAt = os.clock()
                    log("Moving to Hub.Circle")
                    hrp.CFrame = CFrame.new(circle.Position + Vector3.new(0, 3.5, 0))
                end
            else
                selectBestNight(nightMod, m.NightSelect)
            end
        end
        return
    end

    syncRoundFromNightState(activeModel, nState)

    -- Inside an active Night
    local meContestant = nState.contestants and nState.me and nState.contestants[nState.me]
    local isEliminated = (nState.ghost == true)
        or (nState.out == true)
        or (meContestant ~= nil and meContestant.Alive == false)

    if isEliminated then
        closeEliminatedScreenIfOpen(nightMod)
        if Config.ExitOnEliminated and (os.clock() - State.LastExitAt) > 2.0 then
            State.LastExitAt = os.clock()
            log("Bị loại khỏi trận, kích hoạt quy trình Post-Match")
            triggerPostMatchFlow(nightMod)
        end
        return
    end

    -- Optional CashOut (disabled by default to reach Final)
    if Config.AutoCashOut and nState.cashoutOpen == true and (tonumber(nState.bag) or 0) >= Config.CashOutMinTreats then
        log("Cashing out with bag: " .. tostring(nState.bag))
        pcall(nightMod.CashOut)
        triggerPostMatchFlow(nightMod)
        return
    end

    -- Active round execution
    if nState.phase == "play" then
        if Config.AutoUseLuckyCharm and State.LuckyCharmUsedNightId ~= nState.nightId then
            State.LuckyCharmUsedNightId = nState.nightId
            if m.HalloweenGames and hasTrickItem(m.HalloweenGames.TRICKS.LuckyCharm) then
                log("Activating Lucky Charm")
                nightMod.Trick("LuckyCharm")
            end
        end

        local roundId = nState.roundId or State.Round.Id
        if roundId == "BroomSweep" then
            stepBroomSweep(nightMod)
        elseif roundId == "HotPumpkin" then
            stepHotPumpkin(nightMod)
        elseif roundId == "LightsOut" then
            stepLightsOut()
        elseif roundId == "BumperPumpkins" then
            stepBumperPumpkins(nightMod)
        elseif roundId == "PumpkinColors" then
            stepPumpkinColors()
        elseif roundId == "TrickOrTreatDoors" then
            stepTrickOrTreatDoors(nightMod)
        elseif roundId == "ScarecrowStare" then
            stepScarecrowStare()
        end
    end
end

-- Bind main Heartbeat dispatcher
table.insert(
    State.Connections,
    RunService.Heartbeat:Connect(function()
        local ok, err = pcall(stepMainLoop)
        if not ok and Config.DebugLog then
            warn("[HalloweenGames] Loop error: " .. tostring(err))
        end
    end)
)

-- ================= VÒNG LẶP MỞ MIDNIGHT GIFT & GỬI MAIL HUGE & HOP SERVER =================
task.spawn(function()
    while State.Running do
        pcall(function()
            -- 1. Quét nổ Huge toàn cục từ Midnight Gift
            checkNewHugeDrop()

            -- 2. Kiểm tra vị trí hiện tại của người chơi
            local inHalloweenMap = isInHalloweenMap()

            -- 3. Nếu đang ở Map Halloween -> Thực hiện mở Midnight Gift và xử lý Post-Match
            if inHalloweenMap then
                local totalGifts, _ = getMidnightGifts()

                -- Tự động mở quà nếu còn gift trong túi
                if totalGifts > 0 and Config.AutoOpenMidnightGift then
                    openMidnightGifts()
                    task.wait(1.5)
                    checkNewHugeDrop()
                end

                -- Gửi mail Huge nếu có Huge đang chờ trong hàng đợi
                if #pendingMailHuges > 0 and Config.AutoMailHuge then
                    stepAutoMailHuge()
                end

                -- Nếu đang trong chu kỳ Post-Match (vừa chơi xong minigame và đã về Map Halloween):
                if State.PostMatchPending then
                    local giftsRemaining, _ = getMidnightGifts()
                    -- Đảm bảo toàn bộ Gift đã mở hết và không còn Huge đang kẹt gửi dở
                    if giftsRemaining == 0 and #pendingMailHuges == 0 then
                        if Config.AutoServerHop then
                            log("Đã hoàn tất mở Gift và xử lý Huge trên Map Halloween. Chuẩn bị Hop Server...")
                            task.wait(Config.ServerHopDelay or 3)
                            serverHop()
                        else
                            log("Đã mở xong Gift trên Map Halloween. Sẵn sàng vào lại minigame.")
                            State.PostMatchPending = false
                        end
                    end
                end
            else
                -- Đang ở trong minigame instance hoặc sảnh chờ:
                -- Nếu có cờ PostMatchPending mà chưa về Map Halloween, tiếp tục kích hoạt thoát ra
                if State.PostMatchPending then
                    leaveMinigameToHalloweenMap()
                end
            end
        end)
        task.wait(Config.OpenGiftInterval or 5)
    end
end)

env.__HG_AUTO_CLEANUP = function()
    State.Running = false
    for _, conn in ipairs(State.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(State.Connections)
    for _, restore in ipairs(State.Restorers) do
        pcall(restore)
    end
    table.clear(State.Restorers)
    log("Stopped previous instance")
end

if Config.AutoQueueOnTeleport and not env.__HG_QOT_REGISTERED then
    local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(qot) == "function" then
        env.__HG_QOT_REGISTERED = true
        pcall(
            qot,
            'repeat task.wait() until game:IsLoaded(); local f = (isfile and isfile("minigame_halloween.lua") and "minigame_halloween.lua") or (isfile and isfile("__hg_auto_minigame.lua") and "__hg_auto_minigame.lua"); if f and readfile then loadstring(readfile(f))() end'
        )
        log("Registered queue_on_teleport")
    end
end

log("Auto Minigame initialized")