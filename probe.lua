-- =========================================================================
-- PS99_DIAGNOSTIC_PROBE.lua
-- Script chẩn đoán toàn diện cấu trúc PS99 cho Delta Mobile & PC
-- Tự động quét: Save Data, Currency, Quests, Ranks, Remotes, Orbs, Breakables, Machines
-- Tự động copy vào Clipboard + Tạo file ps99_dump.txt + Hiển thị GUI Copy
-- =========================================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local logs = {}
local function log(fmt, ...)
    local str = string.format(fmt, ...)
    table.insert(logs, str)
    print("[PROBE] " .. str)
end

log("========== BẮT ĐẦU CHẨN ĐOÁN PS99 (VANTA PROBE) ==========")
log("Game PlaceId: %s | JobId: %s | Player: %s", tostring(game.PlaceId), tostring(game.JobId), tostring(LP and LP.Name))

-- Helper require an toàn
local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok then return res end
    return nil
end

local function dumpTableKeys(tbl, maxDepth, depth, prefix)
    if type(tbl) ~= "table" then return tostring(tbl) end
    depth = depth or 1
    maxDepth = maxDepth or 2
    prefix = prefix or ""
    if depth > maxDepth then return "{...}" end

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

-- ================= 1. QUÉT REPLICATEDSTORAGE.NETWORK REMOTES =================
log("\n--- [1] DANH SÁCH REMOTES TRONG REPLICATEDSTORAGE.NETWORK ---")
local netFolder = RS:FindFirstChild("Network")
if netFolder then
    local remotes = {}
    for _, child in ipairs(netFolder:GetChildren()) do
        local n = child.Name
        local isEvent = child:IsA("RemoteEvent")
        local isFunc = child:IsA("RemoteFunction")
        local isUnrel = child:IsA("UnreliableRemoteEvent")
        local kind = isUnrel and "Unreliable" or (isEvent and "Event" or (isFunc and "Func" or child.ClassName))
        
        -- Lọc các remote liên quan mật thiết đến 6 tính năng
        local nl = n:lower()
        if nl:find("rank") or nl:find("orb") or nl:find("break") or nl:find("tap") or nl:find("click")
           or nl:find("slot") or nl:find("machine") or nl:find("egg") or nl:find("currency")
           or nl:find("coin") or nl:find("diamond") or nl:find("gift") or nl:find("upgrade")
           or nl:find("quest") or nl:find("goal") or nl:find("pet") then
            table.insert(remotes, string.format("  [%s] %s", kind, n))
        end
    end
    table.sort(remotes)
    log("Tìm thấy %d remotes trọng tâm:", #remotes)
    for _, r in ipairs(remotes) do
        log(r)
    end
else
    log("KHÔNG TÌM THẤY ReplicatedStorage.Network!")
end

-- ================= 2. QUÉT LIBRARY & CLIENT MODULES =================
log("\n--- [2] MODULES CLIENT ---")
local ClientFolder = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Client")
local SaveMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("Save"))
local CurrencyMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("CurrencyCmds"))
local QuestMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("QuestCmds"))
local RankMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("RankCmds"))
local OrbMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("OrbCmds"))
local NetworkMod = ClientFolder and safeRequire(ClientFolder:FindFirstChild("Network"))

log("SaveMod: %s | CurrencyMod: %s | QuestMod: %s | RankMod: %s | OrbMod: %s | NetworkMod: %s",
    tostring(type(SaveMod)), tostring(type(CurrencyMod)), tostring(type(QuestMod)),
    tostring(type(RankMod)), tostring(type(OrbMod)), tostring(type(NetworkMod)))

-- ================= 3. QUÉT DỮ LIỆU SAVE.GET() =================
log("\n--- [3] CẤU TRÚC SAVE.GET() ---")
if SaveMod and type(SaveMod.Get) == "function" then
    local okSave, save = pcall(SaveMod.Get)
    if okSave and type(save) == "table" then
        log("Save Keys Top-level: %s", dumpTableKeys(save, 1))
        log("save.Rank: %s | save.RankStars: %s | save.Rebirths: %s",
            tostring(save.Rank), tostring(save.RankStars), tostring(save.Rebirths))
        
        -- Tiền tệ trong save
        log("save.Coins: %s | save.Diamonds: %s", tostring(save.Coins), tostring(save.Diamonds))
        if type(save.Currency) == "table" then
            log("save.Currency keys: %s", dumpTableKeys(save.Currency, 2))
            for k, v in pairs(save.Currency) do
                log("  save.Currency[%s] = %s", tostring(k), tostring(v))
            end
        else
            log("save.Currency không phải table (là %s)", type(save.Currency))
        end

        -- Quests / Goals trong save
        log("save.Goals type: %s", type(save.Goals))
        if type(save.Goals) == "table" then
            log("save.Goals keys: %s", dumpTableKeys(save.Goals, 1))
            for tier, g in pairs(save.Goals) do
                if type(g) == "table" then
                    log("  [Goal tier %s]: Type=%s, Amount=%s, Progress=%s, Stars=%s, Title=%s, CurrencyID=%s",
                        tostring(tier), tostring(g.Type), tostring(g.Amount), tostring(g.Progress),
                        tostring(g.Stars), tostring(g.Title), tostring(g.CurrencyID))
                else
                    log("  [Goal tier %s] = %s", tostring(tier), tostring(g))
                end
            end
        end

        if type(save.Quests) == "table" then
            log("save.Quests keys: %s", dumpTableKeys(save.Quests, 1))
        end

        -- Rank Rewards redeemed
        log("save.RedeemedRankRewards: %s", dumpTableKeys(save.RedeemedRankRewards or {}, 1))
        if type(save.RedeemedRankRewards) == "table" then
            local redKeys = {}
            for k, v in pairs(save.RedeemedRankRewards) do
                table.insert(redKeys, string.format("%s=%s", tostring(k), tostring(v)))
            end
            log("  Redeemed items: %s", table.concat(redKeys, ", "))
        end

        -- Slots
        log("save.PetSlots: %s | save.EggSlots: %s | save.EquippedSlots: %s",
            tostring(save.PetSlots), tostring(save.EggSlots), tostring(save.EquippedSlots))
        if type(save.Upgrades) == "table" then
            log("save.Upgrades: %s", dumpTableKeys(save.Upgrades, 2))
        end
    else
        log("Save.Get() pcall thất bại hoặc không trả về table: %s", tostring(save))
    end
else
    log("Không gọi được SaveMod.Get!")
end

-- ================= 4. TEST CURRENCYCMDS =================
log("\n--- [4] TEST CURRENCYCMDS ---")
if CurrencyMod then
    log("CurrencyMod keys/funcs: %s", dumpTableKeys(CurrencyMod, 1))
    if type(CurrencyMod.Get) == "function" then
        local ok1, c1 = pcall(CurrencyMod.Get, "Coins")
        local ok2, c2 = pcall(CurrencyMod.Get, "Diamonds")
        local ok3, c3 = pcall(CurrencyMod.Get, 1)
        log("CurrencyMod.Get('Coins') -> ok=%s, val=%s", tostring(ok1), tostring(c1))
        log("CurrencyMod.Get('Diamonds') -> ok=%s, val=%s", tostring(ok2), tostring(c2))
        log("CurrencyMod.Get(1) -> ok=%s, val=%s", tostring(ok3), tostring(c3))
    end
    if type(CurrencyMod.All) == "function" then
        local okAll, all = pcall(CurrencyMod.All)
        if okAll and type(all) == "table" then
            log("CurrencyMod.All() -> keys: %s", dumpTableKeys(all, 1))
            for k, v in pairs(all) do
                log("  All[%s] = %s", tostring(k), tostring(v))
            end
        end
    end
end

-- ================= 5. TEST QUESTCMDS & DIRECTORY.RANKS =================
log("\n--- [5] TEST QUESTCMDS & DIRECTORY.RANKS ---")
if QuestMod then
    log("QuestMod keys/funcs: %s", dumpTableKeys(QuestMod, 1))
    if type(QuestMod.GetActive) == "function" then
        local okQ, q = pcall(QuestMod.GetActive)
        log("QuestMod.GetActive() -> ok=%s, type=%s", tostring(okQ), type(q))
        if okQ and type(q) == "table" then
            for k, v in pairs(q) do
                if type(v) == "table" then
                    log("  Quest[%s]: Type=%s, Progress=%s/%s, Stars=%s",
                        tostring(k), tostring(v.Type), tostring(v.Progress), tostring(v.Amount), tostring(v.Stars))
                end
            end
        end
    end
end

local DirFolder = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Directory")
local RanksDir = DirFolder and safeRequire(DirFolder:FindFirstChild("Ranks"))
if RanksDir and type(RanksDir) == "table" then
    log("Directory.Ranks tìm thấy! Sample keys: %s", dumpTableKeys(RanksDir, 1))
    -- Thử đọc Rank 1 hoặc 2
    local sampleRank = RanksDir["1"] or RanksDir[1] or RanksDir["Rank 1"] or next(RanksDir)
    if type(sampleRank) == "table" then
        log("Sample Rank info: Title=%s, Rewards count=%d",
            tostring(sampleRank.Title), type(sampleRank.Rewards) == "table" and #sampleRank.Rewards or 0)
    end
else
    log("Directory.Ranks: nil hoặc không require được")
end

-- ================= 6. TEST ORBCMDS & WORKSPACE.__THINGS.ORBS =================
log("\n--- [6] KIỂM TRA ORBS & LOOT ---")
if OrbMod then
    log("OrbMod keys/funcs: %s", dumpTableKeys(OrbMod, 1))
end
local things = workspace:FindFirstChild("__THINGS")
if things then
    local orbsFolder = things:FindFirstChild("Orbs")
    local lootFolder = things:FindFirstChild("Lootbags")
    log("workspace.__THINGS.Orbs tồn tại? %s (Children: %d)",
        tostring(orbsFolder ~= nil), orbsFolder and #orbsFolder:GetChildren() or 0)
    log("workspace.__THINGS.Lootbags tồn tại? %s (Children: %d)",
        tostring(lootFolder ~= nil), lootFolder and #lootFolder:GetChildren() or 0)
    
    if orbsFolder and #orbsFolder:GetChildren() > 0 then
        local firstOrb = orbsFolder:GetChildren()[1]
        log("Sample Orb: Name=%s, Class=%s", firstOrb.Name, firstOrb.ClassName)
        local attrs = firstOrb:GetAttributes()
        local attrList = {}
        for k, v in pairs(attrs) do table.insert(attrList, string.format("%s=%s", k, tostring(v))) end
        log("Sample Orb Attributes: %s", table.concat(attrList, ", "))
    end
else
    log("KHÔNG TÌM THẤY workspace.__THINGS!")
end

-- ================= 7. KIỂM TRA BREAKABLES & AUTO TAP =================
log("\n--- [7] KIỂM TRA BREAKABLES & AUTO TAP ---")
if things then
    local breakables = things:FindFirstChild("Breakables")
    log("workspace.__THINGS.Breakables tồn tại? %s (Children: %d)",
        tostring(breakables ~= nil), breakables and #breakables:GetChildren() or 0)
    if breakables and #breakables:GetChildren() > 0 then
        local sampleB = breakables:GetChildren()[1]
        log("Sample Breakable: Name=%s, Class=%s", sampleB.Name, sampleB.ClassName)
        local attrs = sampleB:GetAttributes()
        local attrList = {}
        for k, v in pairs(attrs) do table.insert(attrList, string.format("%s=%s", k, tostring(v))) end
        log("Sample Breakable Attributes: %s", table.concat(attrList, ", "))
        
        -- Test thử Remote nã sát thương
        local uid = sampleB:GetAttribute("BreakableUID") or sampleB.Name
        log("Testing damage with uid: %s", tostring(uid))
        if netFolder:FindFirstChild("Breakables_PlayerDealDamage") then
            local rem = netFolder.Breakables_PlayerDealDamage
            log("Breakables_PlayerDealDamage Class: %s", rem.ClassName)
        end
    end
end

-- ================= 8. KIỂM TRA MACHINES & SLOTS =================
log("\n--- [8] KIỂM TRA MACHINES & SLOTS ---")
if things then
    local machFolder = things:FindFirstChild("Machines")
    if machFolder then
        local mNames = {}
        for _, m in ipairs(machFolder:GetChildren()) do
            table.insert(mNames, m.Name)
        end
        log("Machines in workspace: %s", table.concat(mNames, ", "))
    else
        log("workspace.__THINGS.Machines không tồn tại!")
    end
end

-- ================= HOÀN TẤT & XUẤT KẾT QUẢ =================
log("\n========== HOÀN TẤT DUMP ==========")
local fullDump = table.concat(logs, "\n")

-- 1. Lưu ra file ps99_dump.txt
if type(writefile) == "function" then
    pcall(writefile, "ps99_dump.txt", fullDump)
    log("[PROBE] Đã lưu kết quả vào file: ps99_dump.txt")
end

-- 2. Đưa vào Clipboard
local clipSuccess = false
if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, fullDump)
    if ok then clipSuccess = true end
elseif type(toclipboard) == "function" then
    local ok = pcall(toclipboard, fullDump)
    if ok then clipSuccess = true end
end
if clipSuccess then
    log("[PROBE] ĐÃ COPY TOÀN BỘ LOG VÀO CLIPBOARD! Chỉ cần Ctrl+V hoặc Dán.")
end

-- 3. Tạo GUI nhỏ trên màn hình (Hỗ trợ tốt nhất cho Delta Mobile)
pcall(function()
    local guiName = "KizHub_Probe_GUI"
    local prev = LP.PlayerGui:FindFirstChild(guiName)
    if prev then prev:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = guiName
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 360, 0, 240)
    frame.Position = UDim2.new(0.5, -180, 0.5, -120)
    frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Text = "KIZHUB DIAGNOSTIC PROBE (DONE)"
    title.TextColor3 = Color3.fromRGB(0, 255, 150)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.BackgroundTransparency = 1

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -20, 0, 50)
    status.Position = UDim2.new(0, 10, 0, 35)
    status.Text = clipSuccess and "✔ ĐÃ TỰ ĐỘNG COPY VÀO CLIPBOARD!\nNhấn nút bên dưới nếu muốn copy lại."
                              or "Chưa copy tự động được. Hãy nhấn nút Copy bên dưới!"
    status.TextColor3 = Color3.fromRGB(220, 220, 220)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextWrapped = true
    status.BackgroundTransparency = 1

    local btnCopy = Instance.new("TextButton", frame)
    btnCopy.Size = UDim2.new(1, -20, 0, 45)
    btnCopy.Position = UDim2.new(0, 10, 0, 95)
    btnCopy.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    btnCopy.Text = "📋 COPY LOG GỬI CHO VANTA"
    btnCopy.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnCopy.Font = Enum.Font.GothamBold
    btnCopy.TextSize = 14
    Instance.new("UICorner", btnCopy).CornerRadius = UDim.new(0, 6)

    btnCopy.MouseButton1Click:Connect(function()
        if type(setclipboard) == "function" then
            setclipboard(fullDump)
        elseif type(toclipboard) == "function" then
            toclipboard(fullDump)
        end
        btnCopy.Text = "✔ ĐÃ COPY THÀNH CÔNG!"
        btnCopy.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    end)

    local btnClose = Instance.new("TextButton", frame)
    btnClose.Size = UDim2.new(1, -20, 0, 35)
    btnClose.Position = UDim2.new(0, 10, 0, 150)
    btnClose.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
    btnClose.Text = "ĐÓNG GIAO DIỆN"
    btnClose.TextColor3 = Color3.fromRGB(200, 200, 200)
    btnClose.Font = Enum.Font.Gotham
    btnClose.TextSize = 12
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)

    btnClose.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    sg.Parent = LP:WaitForChild("PlayerGui", 5)
end)

return fullDump
