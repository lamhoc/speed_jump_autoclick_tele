-- =========================================================================
-- KizHub - Remote & GUI Spy for Slot Purchase
-- Dành cho dj: Chạy script này, đến máy bấm MUA 1 SLOT (Pet hoặc Egg)
-- Script sẽ bắt chính xác Remote + Tham số + Nút bấm và tự copy vào Clipboard!
-- =========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function copyText(str)
    local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if type(fn) == "function" then
        pcall(fn, str)
        return true
    end
    return false
end

-- Tạo GUI hiển thị kết quả
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KizHub_SlotSpy"
screenGui.ResetOnSpawn = false

local parentTarget = (type(gethui) == "function" and gethui()) or CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:FindFirstChildOfClass("PlayerGui")
screenGui.Parent = parentTarget

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 420, 0, 240)
frame.Position = UDim2.new(0.5, -210, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(245, 158, 11)
stroke.Thickness = 1.5
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 35)
title.Position = UDim2.new(0, 15, 0, 5)
title.BackgroundTransparency = 1
title.Text = "👑 Kiz Hub | Slot Purchase Sniffer"
title.TextColor3 = Color3.fromRGB(251, 191, 36)
title.TextSize = 15
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

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -30, 0, 25)
infoLabel.Position = UDim2.new(0, 15, 0, 40)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
infoLabel.TextSize = 12
infoLabel.Font = Enum.Font.Gotham
infoLabel.Text = "Hướng dẫn: Đến máy và bấm MUA 1 SLOT bằng tay. Kết quả sẽ hiện dưới đây:"
infoLabel.TextWrapped = true
infoLabel.Parent = frame

local resultBox = Instance.new("TextBox")
resultBox.Size = UDim2.new(1, -30, 0, 115)
resultBox.Position = UDim2.new(0, 15, 0, 70)
resultBox.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
resultBox.TextColor3 = Color3.fromRGB(56, 189, 248)
resultBox.TextSize = 12
resultBox.Font = Enum.Font.Code
resultBox.TextXAlignment = Enum.TextXAlignment.Left
resultBox.TextYAlignment = Enum.TextYAlignment.Top
resultBox.TextWrapped = true
resultBox.ClearTextOnFocus = false
resultBox.Text = "Đang chờ bắt tín hiệu mua slot..."
resultBox.Parent = frame
local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0, 6)
resultCorner.Parent = resultBox

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(1, -30, 0, 35)
copyBtn.Position = UDim2.new(0, 15, 0, 192)
copyBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
copyBtn.Text = "📋 Copy Toàn Bộ Kết Quả"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 13
copyBtn.Parent = frame
local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyBtn

local function serialize(val)
    local t = typeof(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "Instance" then
        return string.format("game.%s", val:GetFullName())
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local kStr = (type(k) == "string" and string.format("[%q]", k)) or string.format("[%s]", tostring(k))
            table.insert(parts, string.format("%s = %s", kStr, serialize(v)))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(val)
end

local lastLog = ""

local function logCaptured(source, remoteName, method, args)
    local argStrs = {}
    for i = 1, #args do
        table.insert(argStrs, serialize(args[i]))
    end
    local formattedArgs = table.concat(argStrs, ", ")
    
    local line = string.format("[%s] %s:%s(%s)", source, remoteName, method, formattedArgs)
    print("------------------------------------------")
    print("👑 [KIZHUB SNIFFER CAPTURED]")
    print(line)
    print("------------------------------------------")
    
    lastLog = line
    resultBox.Text = line
    copyText(line)
    infoLabel.Text = "✓ Đã bắt được Remote & tự động copy vào Clipboard!"
    infoLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
end

copyBtn.MouseButton1Click:Connect(function()
    if lastLog ~= "" then
        copyText(lastLog)
        copyBtn.Text = "✓ Đã Copy Vào Clipboard!"
        task.delay(2, function() copyBtn.Text = "📋 Copy Toàn Bộ Kết Quả" end)
    end
end)

-- Hook __namecall & InvokeServer / FireServer
local hookDone = false
pcall(function()
    if type(hookmetamethod) == "function" then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" or method == "FireServer" then
                local rName = tostring(self.Name or "")
                local rLow = rName:lower()
                if rLow:find("slot") or rLow:find("machine") or rLow:find("upgrade") or rLow:find("equip") or rLow:find("hatch") or rLow:find("purchase") then
                    local args = table.pack(...)
                    task.spawn(function()
                        logCaptured(self.ClassName, rName, method, args)
                    end)
                end
            end
            return oldNamecall(self, ...)
        end)
        hookDone = true
    end
end)

-- Hook Network module của game nếu có
pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local lib = RS:FindFirstChild("Library")
    local client = lib and lib:FindFirstChild("Client")
    local netMod = client and client:FindFirstChild("Network")
    if netMod and type(require) == "function" then
        local net = require(netMod)
        if type(net) == "table" then
            if type(net.Invoke) == "function" and type(hookfunction) == "function" then
                local oldInv
                oldInv = hookfunction(net.Invoke, function(name, ...)
                    local nLow = tostring(name):lower()
                    if nLow:find("slot") or nLow:find("machine") or nLow:find("upgrade") or nLow:find("equip") or nLow:find("hatch") or nLow:find("purchase") then
                        local args = table.pack(...)
                        task.spawn(function()
                            logCaptured("Network.Invoke", tostring(name), "Invoke", args)
                        end)
                    end
                    return oldInv(name, ...)
                end)
            end
            if type(net.Fire) == "function" and type(hookfunction) == "function" then
                local oldFire
                oldFire = hookfunction(net.Fire, function(name, ...)
                    local nLow = tostring(name):lower()
                    if nLow:find("slot") or nLow:find("machine") or nLow:find("upgrade") or nLow:find("equip") or nLow:find("hatch") or nLow:find("purchase") then
                        local args = table.pack(...)
                        task.spawn(function()
                            logCaptured("Network.Fire", tostring(name), "Fire", args)
                        end)
                    end
                    return oldFire(name, ...)
                end)
            end
        end
    end
end)

-- Bắt sự kiện Click nút trên UI
local function hookGui()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pgui then return end
    
    local function checkButton(btn)
        if btn:IsA("GuiButton") and not btn:GetAttribute("SnifferHooked") then
            btn:SetAttribute("SnifferHooked", true)
            btn.Activated:Connect(function()
                local bText = (btn:IsA("TextButton") and btn.Text) or btn.Name
                local path = btn:GetFullName()
                if path:lower():find("slot") or path:lower():find("machine") or path:lower():find("equip") or path:lower():find("egg") or bText:find("💎") or tonumber(bText:match("%d+")) then
                    print("[KizHub UI Click] Clicked: " .. path .. " | Text: " .. tostring(bText))
                end
            end)
        end
    end

    pgui.DescendantAdded:Connect(checkButton)
    for _, d in ipairs(pgui:GetDescendants()) do
        checkButton(d)
    end
end
task.spawn(hookGui)
