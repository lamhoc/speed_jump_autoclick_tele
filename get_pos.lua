-- =========================================================
-- KizHub - Tool Lưu & Lấy Tọa Độ (Position / CFrame Logger)
-- Dành cho dj: Chạy script, đứng trước máy và bấm Copy
-- =========================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function getRoot()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char and char:WaitForChild("HumanoidRootPart", 5)
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if type(fn) == "function" then
        pcall(fn, text)
        return true
    end
    return false
end

-- Tạo ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KizHub_PosLogger"
screenGui.ResetOnSpawn = false

local parentTarget = (type(gethui) == "function" and gethui()) or CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:FindFirstChildOfClass("PlayerGui")
screenGui.Parent = parentTarget

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 360, 0, 190)
frame.Position = UDim2.new(0.5, -180, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(56, 189, 248)
stroke.Thickness = 1.5
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 35)
title.Position = UDim2.new(0, 15, 0, 5)
title.BackgroundTransparency = 1
title.Text = "👑 Kiz Hub | Position Logger"
title.TextColor3 = Color3.fromRGB(248, 250, 252)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = frame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local posLabel = Instance.new("TextLabel")
posLabel.Size = UDim2.new(1, -30, 0, 48)
posLabel.Position = UDim2.new(0, 15, 0, 42)
posLabel.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
posLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
posLabel.TextSize = 12
posLabel.Font = Enum.Font.Code
posLabel.TextWrapped = true
posLabel.Text = "Đang lấy tọa độ..."
posLabel.Parent = frame
local posCorner = Instance.new("UICorner")
posCorner.CornerRadius = UDim.new(0, 6)
posCorner.Parent = posLabel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 0, 18)
statusLabel.Position = UDim2.new(0, 15, 0, 96)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = ""
statusLabel.Parent = frame

local copyCfBtn = Instance.new("TextButton")
copyCfBtn.Size = UDim2.new(0.48, -10, 0, 38)
copyCfBtn.Position = UDim2.new(0, 15, 0, 122)
copyCfBtn.BackgroundColor3 = Color3.fromRGB(14, 165, 233)
copyCfBtn.Text = "📋 Copy CFrame"
copyCfBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyCfBtn.Font = Enum.Font.GothamBold
copyCfBtn.TextSize = 13
copyCfBtn.Parent = frame
local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = copyCfBtn

local copyVecBtn = Instance.new("TextButton")
copyVecBtn.Size = UDim2.new(0.48, -10, 0, 38)
copyVecBtn.Position = UDim2.new(0.52, 5, 0, 122)
copyVecBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
copyVecBtn.Text = "📋 Copy Vector3"
copyVecBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyVecBtn.Font = Enum.Font.GothamBold
copyVecBtn.TextSize = 13
copyVecBtn.Parent = frame
local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = copyVecBtn

local lastPosStr = ""
local lastCfStr = ""

RunService.RenderStepped:Connect(function()
    pcall(function()
        local hrp = getRoot()
        if hrp then
            local p = hrp.Position
            lastPosStr = string.format("Vector3.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
            lastCfStr = string.format("CFrame.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
            posLabel.Text = string.format("Pos: %.1f, %.1f, %.1f\nCFrame: %s", p.X, p.Y, p.Z, lastCfStr)
        end
    end)
end)

copyCfBtn.MouseButton1Click:Connect(function()
    if lastCfStr ~= "" then
        copyToClipboard(lastCfStr)
        print("[Kiz Hub Pos] " .. lastCfStr)
        statusLabel.Text = "✓ Đã copy CFrame vào Clipboard & F9 Console!"
        task.delay(3, function() statusLabel.Text = "" end)
    end
end)

copyVecBtn.MouseButton1Click:Connect(function()
    if lastPosStr ~= "" then
        copyToClipboard(lastPosStr)
        print("[Kiz Hub Pos] " .. lastPosStr)
        statusLabel.Text = "✓ Đã copy Vector3 vào Clipboard & F9 Console!"
        task.delay(3, function() statusLabel.Text = "" end)
    end
end)
