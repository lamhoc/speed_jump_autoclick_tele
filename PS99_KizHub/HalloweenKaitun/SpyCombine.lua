-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/SpyCombine.lua
-- SPY SIÊU AN TOÀN & KHÔNG LỖI CHO SỰ KIỆN HALLOWEEN PET SIMULATOR 99
-- Tác giả: VANTA [JHON369] | Dành riêng cho dj
-- Thiết kế:
--   - KHÔNG can thiệp vào Library.Network (tránh làm rỗng UI công thức)
--   - Hook __namecall thụ động 100% bằng newcclosure, xử lý log trong luồng riêng
--   - Bộ tuần tự hóa safeSerialize chống crash khi gặp Instance, CFrame, Circular Table
--   - Bắt chính xác tên Remote, Method (Invoke/Fire), và toàn bộ tham số
--   - Có sẵn các nút bấm test tương tác GUI trực tiếp trên màn hình
-- =========================================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Hỗ trợ Clipboard đa nền tảng
local setclip = setclipboard or toclipboard or (Clipboard and Clipboard.set) or function() end
local getgenvFn = (type(getgenv) == "function" and getgenv) or function() return _G end

-- Gỡ bỏ phiên bản cũ nếu đang chạy
if getgenvFn()._HalloweenSpyGui then
    pcall(function() getgenvFn()._HalloweenSpyGui:Destroy() end)
    getgenvFn()._HalloweenSpyGui = nil
end

-- =========================================================================
-- 1. HÀM CHUYỂN ĐỔI THAM SỐ AN TOÀN TUYỆT ĐỐI (KHÔNG CRASH)
-- =========================================================================
local function safeSerialize(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 3 then return "..." end

    local t = typeof(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "nil" then
        return "nil"
    elseif t == "Instance" then
        return string.format("game.%s", val:GetFullName())
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        local p = val.Position
        return string.format("CFrame.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "table" then
        if visited[val] then return "<CircularTable>" end
        visited[val] = true

        local parts = {}
        local count = 0
        local isArray = true
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then isArray = false end
            if count > 8 then table.insert(parts, "..."); break end
        end

        local cur = 0
        for k, v in pairs(val) do
            cur = cur + 1
            if cur > 8 then break end
            local vStr = safeSerialize(v, depth + 1, visited)
            if isArray then
                table.insert(parts, vStr)
            else
                local kStr = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or string.format("[%s]", safeSerialize(k, depth + 1, visited))
                table.insert(parts, string.format("%s = %s", kStr, vStr))
            end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return string.format("<%s>", tostring(val))
    end
end

-- =========================================================================
-- 2. TẠO GIAO DIỆN SPY UI NỔI TRÊN MÀN HÌNH
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KizHub_HalloweenSpy_Safe"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    else
        ScreenGui.Parent = CoreGui
    end
end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end
getgenvFn()._HalloweenSpyGui = ScreenGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 380)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(147, 51, 234)
Stroke.Thickness = 1.5

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Text = "🔮 KizHub | Safe Remote Spy - Halloween Combine"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(216, 180, 254)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
CloseBtn.Position = UDim2.new(1, -32, 0, 6)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(51, 25, 35)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Status Box
local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Name = "StatusLabel"
StatusLabel.Text = "📡 Trạng thái: Đang theo dõi... Hãy tới máy và tự tay ấn nút!"
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 11
StatusLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
StatusLabel.Position = UDim2.new(0, 12, 0, 44)
StatusLabel.Size = UDim2.new(1, -24, 0, 20)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.BackgroundTransparency = 1

-- Log Scroll
local LogScroll = Instance.new("ScrollingFrame", MainFrame)
LogScroll.Name = "LogScroll"
LogScroll.Position = UDim2.new(0, 12, 0, 68)
LogScroll.Size = UDim2.new(1, -24, 1, -125)
LogScroll.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 5
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 6)

local LogListLayout = Instance.new("UIListLayout", LogScroll)
LogListLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogListLayout.Padding = UDim.new(0, 4)

local LogPadding = Instance.new("UIPadding", LogScroll)
LogPadding.PaddingTop = UDim.new(0, 6)
LogPadding.PaddingBottom = UDim.new(0, 6)
LogPadding.PaddingLeft = UDim.new(0, 8)
LogPadding.PaddingRight = UDim.new(0, 8)

-- Footer Buttons
local BtnContainer = Instance.new("Frame", MainFrame)
BtnContainer.Position = UDim2.new(0, 12, 1, -48)
BtnContainer.Size = UDim2.new(1, -24, 0, 36)
BtnContainer.BackgroundTransparency = 1

local function createBtn(text, xPos, width, color, callback)
    local btn = Instance.new("TextButton", BtnContainer)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(248, 250, 252)
    btn.BackgroundColor3 = color
    btn.Position = UDim2.new(0, xPos, 0, 0)
    btn.Size = UDim2.new(0, width, 1, 0)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local lastCapturedCommand = ""

local function addLog(text, color)
    print("[HalloweenSpy] " .. text)
    local row = Instance.new("TextLabel", LogScroll)
    row.Text = string.format("[%s] %s", os.date("%H:%M:%S"), text)
    row.Font = Enum.Font.Code
    row.TextSize = 10
    row.TextColor3 = color or Color3.fromRGB(224, 231, 255)
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextWrapped = true
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1

    local children = LogScroll:GetChildren()
    if #children > 120 then
        children[3]:Destroy()
    end
    task.defer(function()
        LogScroll.CanvasPosition = Vector2.new(0, 999999)
    end)
end

-- =========================================================================
-- 3. HOOK __NAMECALL THỤ ĐỘNG - 100% AN TOÀN, KHÔNG CHẶN, KHÔNG SỬA TRẢ VỀ
-- =========================================================================
pcall(function()
    if type(hookmetamethod) ~= "function" then
        addLog("⚠️ Executor không hỗ trợ hookmetamethod! Vui lòng dùng Volt/Delta/Wave.", Color3.fromRGB(239, 68, 68))
        return
    end

    local oldNamecall = nil
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        
        if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
            local rName = self.Name
            local rLower = rName:lower()

            -- Lọc các Remote liên quan tới Craft, Machine, Halloween, Combine, Egg, Start, Claim
            local isRelevant = rLower:find("craft") or rLower:find("combine") or rLower:find("halloween")
                or rLower:find("machine") or rLower:find("egg") or rLower:find("start") or rLower:find("claim")
                or rLower:find("forge")

            if isRelevant then
                local rawArgs = { ... }
                -- Tách việc format và hiển thị vào thread riêng biệt hoàn toàn
                task.spawn(function()
                    local formatted = {}
                    for _, a in ipairs(rawArgs) do
                        table.insert(formatted, safeSerialize(a))
                    end
                    local codePayload = string.format("game:GetService(\"ReplicatedStorage\").Network[%q]:%s(%s)", rName, method, table.concat(formatted, ", "))
                    local displayLine = string.format("[%s] %s(%s)", method, rName, table.concat(formatted, ", "))
                    
                    lastCapturedCommand = codePayload
                    addLog(displayLine, Color3.fromRGB(244, 114, 182))
                    StatusLabel.Text = "🎯 Bắt Remote: " .. rName
                    pcall(function() setclip(codePayload) end)
                end)
            end
        end

        -- Luôn luôn thực thi và trả về nguyên trạng dữ liệu gốc
        return oldNamecall(self, ...)
    end))

    addLog("✓ Đã cài đặt Safe Hook __namecall (Bảo toàn dữ liệu game)", Color3.fromRGB(56, 189, 248))
end)

-- =========================================================================
-- 4. THEO DÕI NÚT GUI CLICK (KHÔNG LẶP QUÉT NẶNG MÁY)
-- =========================================================================
pcall(function()
    UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = UserInputService:GetMouseLocation()
            task.defer(function()
                pcall(function()
                    for _, gui in ipairs(PlayerGui:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "KizHub_HalloweenSpy_Safe" then
                            for _, desc in ipairs(gui:GetDescendants()) do
                                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                                    local ap = desc.AbsolutePosition
                                    local as = desc.AbsoluteSize
                                    if mousePos.X >= ap.X and mousePos.X <= ap.X + as.X
                                       and mousePos.Y >= ap.Y and mousePos.Y <= ap.Y + as.Y then
                                        
                                        local bText = (desc:IsA("TextButton") and desc.Text) or "(ImageButton)"
                                        local side = (ap.X < (workspace.CurrentCamera.ViewportSize.X / 2)) and "BÊN TRÁI" or "BÊN PHẢI"
                                        addLog(string.format("[CLICK GUI] %s | Nút: %q | Text: %q", side, desc.Name, bText), Color3.fromRGB(250, 204, 21))
                                    end
                                end
                            end
                        end
                    end
                end)
            end)
        end
    end)
    addLog("✓ Đã kích hoạt theo dõi click nút giao diện", Color3.fromRGB(56, 189, 248))
end)

-- =========================================================================
-- 5. CÁC NÚT ĐIỀU KHIỂN & TEST TRỰC TIẾP TRÊN MÀN HÌNH
-- =========================================================================
local function triggerBtn(btn)
    if not btn then return false end
    pcall(function()
        if type(firesignal) == "function" then
            if btn.Activated then firesignal(btn.Activated) end
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
        end
        if type(getconnections) == "function" then
            if btn.Activated then
                for _, c in ipairs(getconnections(btn.Activated) or {}) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                end
            end
            if btn.MouseButton1Click then
                for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                end
            end
        end
    end)
    return true
end

-- Nút 1: Teleport tới Pad máy Combine
createBtn("🚀 Tele Máy", 0, 80, Color3.fromRGB(16, 185, 129), function()
    pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-6721.63, 17.13, -4002.42)
            StatusLabel.Text = "🚀 Đã tới trước mặt máy Combine!"
            addLog("Đã teleport tới Pad máy Combine (-6721.63, 17.13, -4002.42)", Color3.fromRGB(52, 211, 153))
        end
    end)
end)

-- Nút 2: Test tự động click tab Combine Egg (Kết hợp Trứng) bên trái
createBtn("🎯 Chọn Tab", 85, 80, Color3.fromRGB(14, 165, 233), function()
    pcall(function()
        local found = false
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "KizHub_HalloweenSpy_Safe" then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc.Visible ~= false then
                        local txt = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower() or ""
                        if txt:find("kết hợp trứng") or txt:find("combine egg") or txt:find("combineegg") then
                            local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton") or desc:FindFirstChildWhichIsA("GuiButton") or desc
                            triggerBtn(b)
                            found = true
                            addLog("🎯 Đã kích hoạt click vào tab: " .. txt, Color3.fromRGB(56, 189, 248))
                            StatusLabel.Text = "🎯 Đã click tab: " .. txt
                        end
                    end
                end
            end
        end
        if not found then
            addLog("⚠️ Không tìm thấy nút tab Kết hợp Trứng trên màn hình!", Color3.fromRGB(251, 146, 60))
        end
    end)
end)

-- Nút 3: Test tự động click nút Chế tạo! (Craft!) bên phải
createBtn("⚡ Test Craft", 170, 80, Color3.fromRGB(168, 85, 247), function()
    pcall(function()
        local found = false
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "KizHub_HalloweenSpy_Safe" then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if (desc:IsA("TextButton") or desc:IsA("ImageButton") or desc:IsA("TextLabel")) and desc.Visible ~= false then
                        local txt = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower() or ""
                        local isCraft = (txt:find("chế tạo") or txt:find("craft")) and not txt:find("10") and not txt:find("3,000") and not txt:find("3000")
                        if isCraft then
                            local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton") or desc:FindFirstChildWhichIsA("GuiButton") or desc
                            triggerBtn(b)
                            found = true
                            addLog("⚡ Đã kích hoạt click nút Craft: " .. txt, Color3.fromRGB(192, 132, 252))
                            StatusLabel.Text = "⚡ Đã click nút Craft: " .. txt
                        end
                    end
                end
            end
        end
        if not found then
            addLog("⚠️ Không tìm thấy nút Chế tạo! trên màn hình!", Color3.fromRGB(251, 146, 60))
        end
    end)
end)

-- Nút 4: Copy Remote mới nhất
createBtn("📋 Copy", 255, 65, Color3.fromRGB(37, 99, 235), function()
    if lastCapturedCommand ~= "" then
        setclip(lastCapturedCommand)
        StatusLabel.Text = "📋 Đã copy lệnh Remote vào Clipboard!"
        addLog("Đã copy vào Clipboard: " .. lastCapturedCommand, Color3.fromRGB(96, 165, 250))
    else
        StatusLabel.Text = "⚠️ Chưa có lệnh Remote nào được bắt!"
    end
end)

-- Nút 5: Tắt UI máy
createBtn("❌ Tắt UI", 325, 75, Color3.fromRGB(225, 29, 72), function()
    pcall(function()
        local Library = nil
        pcall(function() Library = require(RS:WaitForChild("Library", 3)) end)
        if Library and Library.TabController and type(Library.TabController.CloseAll) == "function" then
            Library.TabController.CloseAll()
        end
        -- Tìm nút đỏ X trong PlayerGui
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "KizHub_HalloweenSpy_Safe" then
                for _, btn in ipairs(gui:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                        local bName = btn.Name:lower()
                        local bText = (btn:IsA("TextButton") and btn.Text:lower()) or ""
                        if bName == "close" or bName == "x" or bText == "x" or bText == "✕" or bText == "×" then
                            triggerBtn(btn)
                        end
                    end
                end
            end
        end
    end)
    StatusLabel.Text = "Đã tắt UI máy"
    addLog("Đã gửi tín hiệu đóng toàn bộ UI máy", Color3.fromRGB(248, 113, 113))
end)

-- Nút 6: Xóa Log
createBtn("🗑️ Xóa", 405, 55, Color3.fromRGB(71, 85, 105), function()
    for _, child in ipairs(LogScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    StatusLabel.Text = "📡 Đã xóa log. Sẵn sàng bắt tiếp..."
end)

addLog("SẴN SÀNG! Phiên bản Safe Spy không can thiệp game, không làm rỗng UI.", Color3.fromRGB(52, 211, 153))
addLog("Bây giờ bạn có thể tới máy, mọi tương tác đều hiển thị bình thường!", Color3.fromRGB(224, 231, 255))
