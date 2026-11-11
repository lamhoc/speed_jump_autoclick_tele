-- =========================================================================
-- SyncDeltaWorkspace.lua
-- Script tự động tải & đồng bộ toàn bộ Code KizHub vào thư mục workspace của Delta
-- Giúp chạy mượt mà trên Delta Mobile / PC mà không cần dùng Volt
-- =========================================================================

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

local REPO_BASE = "https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/main/PS99_KizHub/"
local PROBE_URL = "https://raw.githubusercontent.com/lamhoc/speed_jump_autoclick_tele/main/probe.lua"

local FILES = {
    -- Shared
    "Shared/Modules.lua",
    "Shared/Network.lua",
    "Shared/EngineOptim.lua",
    "Shared/AntiAFK.lua",
    "Shared/Webhook.lua",
    "Shared/DashboardGui.lua",

    -- AutoRankKaitun
    "AutoRankKaitun/Config.lua",
    "AutoRankKaitun/RankData.lua",
    "AutoRankKaitun/RankController.lua",
    "AutoRankKaitun/QuestFarm.lua",
    "AutoRankKaitun/QuestHatch.lua",
    "AutoRankKaitun/QuestCraft.lua",
    "AutoRankKaitun/QuestItems.lua",
    "AutoRankKaitun/Progression.lua",
    "AutoRankKaitun/main.lua",

    -- HalloweenKaitun
    "HalloweenKaitun/Config.lua",
    "HalloweenKaitun/TreatUpgrades.lua",
    "HalloweenKaitun/CombineHuge.lua",
    "HalloweenKaitun/Daycare.lua",
    "HalloweenKaitun/AutoMail.lua",
    "HalloweenKaitun/BuffsAndGifts.lua",
    "HalloweenKaitun/ZoneFarm.lua",
    "HalloweenKaitun/EggHatch.lua",
    "HalloweenKaitun/main.lua",
}

-- Helper tạo thư mục cha an toàn
local function ensureParentDirs(filePath)
    if type(makefolder) ~= "function" then return end
    local parts = filePath:gsub("\\", "/"):split("/")
    local current = ""
    for i = 1, #parts - 1 do
        current = current .. (current == "" and "" or "/") .. parts[i]
        local exists = false
        if type(isfolder) == "function" then
            local ok, res = pcall(isfolder, current)
            if ok and res == true then exists = true end
        end
        if not exists then
            pcall(makefolder, current)
        end
    end
end

-- Helper tải nội dung qua HTTP
local function httpGet(url)
    local content = nil
    if type(game.HttpGet) == "function" then
        local ok, res = pcall(game.HttpGet, game, url)
        if ok and type(res) == "string" and #res > 0 then
            content = res
        end
    end
    if not content then
        local reqFn = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (type(http) == "table" and type(http.request) == "function" and http.request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        if reqFn then
            local ok, resp = pcall(reqFn, { Url = url, Method = "GET" })
            if ok and type(resp) == "table" and type(resp.Body) == "string" and #resp.Body > 0 then
                content = resp.Body
            end
        end
    end
    return content
end

-- ================= TẠO GIAO DIỆN ĐỒNG BỘ TRÊN DELTA =================
local guiName = "KizHub_Sync_GUI"
pcall(function()
    local prev = LP.PlayerGui:FindFirstChild(guiName)
    if prev then prev:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name = guiName
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 360, 0, 230)
frame.Position = UDim2.new(0.5, -180, 0.5, -115)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
frame.BorderSizePixel = 0
frame.Parent = sg

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(0, 200, 255)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 32)
title.Text = "KIZHUB DELTA WORKSPACE SYNC"
title.TextColor3 = Color3.fromRGB(0, 255, 150)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.BackgroundTransparency = 1

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -20, 0, 30)
status.Position = UDim2.new(0, 10, 0, 35)
status.Text = "Đang chuẩn bị thư mục workspace..."
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.BackgroundTransparency = 1

local barBg = Instance.new("Frame", frame)
barBg.Size = UDim2.new(1, -20, 0, 14)
barBg.Position = UDim2.new(0, 10, 0, 72)
barBg.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
barBg.BorderSizePixel = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 7)

local barFill = Instance.new("Frame", barBg)
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
barFill.BorderSizePixel = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 7)

local detailLabel = Instance.new("TextLabel", frame)
detailLabel.Size = UDim2.new(1, -20, 0, 20)
detailLabel.Position = UDim2.new(0, 10, 0, 92)
detailLabel.Text = "Khởi tạo..."
detailLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
detailLabel.Font = Enum.Font.Gotham
detailLabel.TextSize = 10
detailLabel.BackgroundTransparency = 1

local actionFrame = Instance.new("Frame", frame)
actionFrame.Size = UDim2.new(1, -20, 0, 95)
actionFrame.Position = UDim2.new(0, 10, 0, 120)
actionFrame.BackgroundTransparency = 1
actionFrame.Visible = false

local btnRunAutoRank = Instance.new("TextButton", actionFrame)
btnRunAutoRank.Size = UDim2.new(1, 0, 0, 42)
btnRunAutoRank.Position = UDim2.new(0, 0, 0, 0)
btnRunAutoRank.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
btnRunAutoRank.Text = "▶ CHẠY AUTO RANK NGAY (TỪ WORKSPACE)"
btnRunAutoRank.TextColor3 = Color3.fromRGB(255, 255, 255)
btnRunAutoRank.Font = Enum.Font.GothamBold
btnRunAutoRank.TextSize = 13
Instance.new("UICorner", btnRunAutoRank).CornerRadius = UDim.new(0, 6)

local btnRunProbe = Instance.new("TextButton", actionFrame)
btnRunProbe.Size = UDim2.new(0.48, 0, 0, 36)
btnRunProbe.Position = UDim2.new(0, 0, 0, 50)
btnRunProbe.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
btnRunProbe.Text = "🔍 CHẠY PROBE"
btnRunProbe.TextColor3 = Color3.fromRGB(255, 255, 255)
btnRunProbe.Font = Enum.Font.GothamBold
btnRunProbe.TextSize = 11
Instance.new("UICorner", btnRunProbe).CornerRadius = UDim.new(0, 6)

local btnClose = Instance.new("TextButton", actionFrame)
btnClose.Size = UDim2.new(0.48, 0, 0, 36)
btnClose.Position = UDim2.new(0.52, 0, 0, 50)
btnClose.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
btnClose.Text = "ĐÓNG GIAO DIỆN"
btnClose.TextColor3 = Color3.fromRGB(200, 200, 200)
btnClose.Font = Enum.Font.Gotham
btnClose.TextSize = 11
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)

btnClose.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

btnRunAutoRank.MouseButton1Click:Connect(function()
    btnRunAutoRank.Text = "ĐANG KHỞI CHẠY..."
    task.defer(function()
        local scriptPath = "PS99_KizHub/AutoRankKaitun/main.lua"
        if type(dofile) == "function" then
            pcall(dofile, scriptPath)
        elseif type(loadfile) == "function" then
            local fn = loadfile(scriptPath)
            if fn then fn() end
        elseif type(readfile) == "function" then
            local ok, code = pcall(readfile, scriptPath)
            if ok and code then
                local fn = loadstring(code, "=" .. scriptPath)
                if fn then fn() end
            end
        end
        sg:Destroy()
    end)
end)

btnRunProbe.MouseButton1Click:Connect(function()
    btnRunProbe.Text = "ĐANG CHẠY PROBE..."
    task.defer(function()
        local scriptPath = "PS99_KizHub/probe.lua"
        if type(readfile) == "function" then
            local ok, code = pcall(readfile, scriptPath)
            if ok and code then
                local fn = loadstring(code, "=probe.lua")
                if fn then fn() end
            end
        end
        sg:Destroy()
    end)
end)

sg.Parent = LP:WaitForChild("PlayerGui", 5)

-- ================= TIẾN TRÌNH ĐỒNG BỘ FILE =================
task.spawn(function()
    task.wait(0.5)

    -- 1. Tạo các folder chính trong workspace
    ensureParentDirs("PS99_KizHub/Shared/dummy.lua")
    ensureParentDirs("PS99_KizHub/AutoRankKaitun/dummy.lua")
    ensureParentDirs("PS99_KizHub/HalloweenKaitun/dummy.lua")

    local total = #FILES + 1 -- cộng thêm probe.lua
    local successCount = 0

    for idx, relPath in ipairs(FILES) do
        local targetPath = "PS99_KizHub/" .. relPath
        local url = REPO_BASE .. relPath
        
        detailLabel.Text = string.format("[%d/%d] Đang tải: %s", idx, total, relPath)
        local progress = (idx - 1) / total
        barFill.Size = UDim2.new(progress, 0, 1, 0)

        local data = httpGet(url)
        if data and type(writefile) == "function" then
            ensureParentDirs(targetPath)
            local okWrite = pcall(writefile, targetPath, data)
            if okWrite then
                successCount = successCount + 1
            end
        end
        task.wait(0.05)
    end

    -- Tải thêm probe.lua vào workspace
    detailLabel.Text = string.format("[%d/%d] Đang tải: probe.lua", total, total)
    local probeData = httpGet(PROBE_URL)
    if probeData and type(writefile) == "function" then
        pcall(writefile, "probe.lua", probeData)
        pcall(writefile, "PS99_KizHub/probe.lua", probeData)
        successCount = successCount + 1
    end

    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 120)

    if successCount >= (#FILES * 0.8) then
        status.Text = string.format("✔ ĐÃ ĐỒNG BỘ THÀNH CÔNG %d/%d FILE VÀO WORKSPACE!", successCount, total)
        status.TextColor3 = Color3.fromRGB(0, 255, 150)
        detailLabel.Text = "Tất cả file đã nằm trong Delta/workspace/PS99_KizHub/"
    else
        status.Text = string.format("Đã lưu %d/%d file (Kiểm tra lại kết nối mạng)", successCount, total)
        status.TextColor3 = Color3.fromRGB(255, 200, 50)
    end

    actionFrame.Visible = true
end)

return true
