-- =========================================================================
-- PS99_KizHub/Shared/AntiAFK.lua
-- Hệ thống God Mode Anti-AFK & Chống Kick 15 Phút của Big Games
-- Tích hợp: Dập Idled, Reset Idle Timer Server, Virtual Mouse & Key F mỗi 35s
-- =========================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local AntiAFK = {}
local isInstalled = false
local connections = {}
local running = true

-- Nhịp tác động chống AFK ảo lên Client và Server Big Games
local function performAfkNudge(netFireFn)
    pcall(function()
        -- 1. Bắn Remote dập tắt bộ đếm idle timer trên server Big Games (Xóa sổ cơ chế AFK Kick 15'/20')
        if type(netFireFn) == "function" then
            netFireFn("Idle Tracking: Stop Timer")
            netFireFn("Idle Tracking: Update Timer")
            netFireFn("Idle Tracking: Focus Changed", true)
        end

        -- 2. Nhảy nhẹ nhân vật
        local char = LocalPlayer and LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            hum.Jump = true
        end

        -- 3. VirtualUser Click chuột phải vào Camera
        local cam = workspace.CurrentCamera
        if VirtualUser and cam then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
                task.wait(0.05)
                VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
            end)
        end

        -- 4. VirtualInputManager gửi Click chuột trái & Nhấn phím F ảo
        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)
        end
    end)
end

-- Cài đặt toàn bộ hệ thống God Mode Anti-AFK
function AntiAFK.installGodModeAntiAfk(netFireFn, pulseInterval)
    if isInstalled then return end
    isInstalled = true
    pulseInterval = tonumber(pulseInterval) or 35

    -- 1. Vô hiệu hóa Idled Connection mặc định của Roblox Core
    pcall(function()
        if type(getconnections) == "function" and LocalPlayer then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then
                    c:Disable()
                elseif c.Disconnect then
                    c:Disconnect()
                end
            end
        end
    end)

    -- 2. Watchdog kiểm tra lỗi ngắt kết nối (Error Code) để giải phóng tài nguyên cho auto-rejoin
    task.spawn(function()
        while running do
            task.wait(5)
            pcall(function()
                if GuiService and typeof(GuiService.GetErrorCode) == "function" then
                    local code = GuiService:GetErrorCode().Value
                    if code and code > 0 and code ~= 769 then
                        local genv = (type(getgenv) == "function" and getgenv()) or _G
                        if genv.client and typeof(genv.client.Disconnect) == "function" then
                            pcall(function() genv.client:Disconnect() end)
                        end
                    end
                end
            end)
        end
    end)

    -- 3. Bắt sự kiện Idled của LocalPlayer
    if LocalPlayer then
        local c1 = LocalPlayer.Idled:Connect(function()
            if not running then return end
            performAfkNudge(netFireFn)
        end)
        table.insert(connections, c1)
    end

    -- 4. Bắt sự kiện khi cửa sổ game mất Focus (Treo tab chạy ngầm nhiều account)
    if UserInputService then
        local c2 = UserInputService.WindowFocusReleased:Connect(function()
            if not running then return end
            performAfkNudge(netFireFn)
        end)
        table.insert(connections, c2)
    end

    -- 5. Vòng lặp nhịp Pulse định kỳ mỗi 35 giây (hoặc cấu hình tùy chỉnh)
    task.spawn(function()
        while running do
            task.wait(pulseInterval)
            if not running then break end
            performAfkNudge(netFireFn)
        end
    end)
end

function AntiAFK.stop()
    running = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
end

return AntiAFK
