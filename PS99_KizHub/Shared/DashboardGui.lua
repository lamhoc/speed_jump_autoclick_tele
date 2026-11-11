-- =========================================================================
-- PS99_KizHub/Shared/DashboardGui.lua
-- Giao diện AMOLED KizCard & Blackout Màn Hình Đen Toàn Diện
-- Tích hợp: Phím tắt RightControl, Bật/Tắt 3D Rendering, Drag thả thẻ thông tin
-- =========================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local DashboardGui = {}

local ScreenGui = nil
local BlackBackground = nil
local KizCard = nil
local uiElements = {}
local isBlackoutVisible = true
local toggleKey = Enum.KeyCode.RightControl

-- Lấy parent GUI an toàn
local function getSafeGuiParent()
    if type(gethui) == "function" then
        return gethui()
    end
    if syn and syn.protect_gui and CoreGui then
        return CoreGui
    end
    if CoreGui then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Chuyển đổi trạng thái hiển thị Blackout Màn Hình Đen & 3D Rendering
function DashboardGui.setBlackout(visible)
    isBlackoutVisible = visible
    if BlackBackground then
        BlackBackground.Visible = visible
    end
    if KizCard then
        KizCard.Visible = true
    end
    if uiElements and uiElements.ToggleBtn then
        uiElements.ToggleBtn.BackgroundColor3 = visible and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(0, 220, 130)
        if uiElements.ToggleBtn:FindFirstChild("Indicator") then
            uiElements.ToggleBtn.Indicator.Text = visible and "●" or "👁"
        end
    end
    pcall(function()
        if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
            RunService:Set3dRenderingEnabled(not visible)
        end
    end)
end

function DashboardGui.toggleBlackout()
    DashboardGui.setBlackout(not isBlackoutVisible)
end

-- Khởi tạo Giao diện AMOLED KizCard
function DashboardGui.create(config)
    config = config or {}
    if config.ShowGui == false then
        DashboardGui.destroy()
        pcall(function()
            if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(true)
            end
        end)
        return nil
    end

    local titleText = config.Title or "PS99 KIZHUB AUTOMATION"
    local subText = config.Subtitle or "Auto Farm • Auto Combine Huge • Daycare • Upgrades"
    local logoAssetId = config.LogoAssetId or "rbxassetid://10709791437"
    if config.ToggleKey then
        toggleKey = config.ToggleKey
    end

    local parent = getSafeGuiParent()

    -- Hủy GUI cũ nếu có
    local old = parent:FindFirstChild("Kizhub_BlackScreen") or parent:FindFirstChild("KizHub_Blackout_Dashboard")
    if old then
        pcall(function() old:Destroy() end)
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kizhub_BlackScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parent

    -- Background Đen AMOLED (Chỉ bật nếu Blackout == true)
    local enableBlackout = (config.Blackout ~= false)
    BlackBackground = Instance.new("Frame", ScreenGui)
    BlackBackground.Name = "BlackBackground"
    BlackBackground.Size = UDim2.new(1, 0, 1, 0)
    BlackBackground.Position = UDim2.new(0, 0, 0, 0)
    BlackBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BlackBackground.BorderSizePixel = 0
    BlackBackground.ZIndex = 0
    BlackBackground.Visible = enableBlackout

    -- Thẻ KizCard hiển thị thông số
    KizCard = Instance.new("Frame", ScreenGui)
    KizCard.Name = "KizCard"
    KizCard.AnchorPoint = Vector2.new(1, 0)
    KizCard.Position = UDim2.new(1, -20, 0, 20)
    KizCard.Size = UDim2.new(0, 430, 0, 390)
    KizCard.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    KizCard.BackgroundTransparency = 0.05
    KizCard.BorderSizePixel = 0
    KizCard.ClipsDescendants = true
    KizCard.Active = true
    KizCard.Draggable = true
    KizCard.ZIndex = 2

    Instance.new("UICorner", KizCard).CornerRadius = UDim.new(0, 14)
    local CardStroke = Instance.new("UIStroke", KizCard)
    CardStroke.Color = Color3.fromRGB(255, 140, 0)
    CardStroke.Thickness = 1.8

    -- Header Frame
    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Name = "HeaderFrame"
    HeaderFrame.Size = UDim2.new(1, 0, 0, 95)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.ZIndex = 5

    -- Nút cam tròn trên Header điều khiển Ẩn / Hiện màn hình đen & 3D Render
    local ToggleBtn = Instance.new("TextButton", HeaderFrame)
    ToggleBtn.Name = "ToggleBlackoutButton"
    ToggleBtn.Size = UDim2.new(0, 26, 0, 26)
    ToggleBtn.Position = UDim2.new(1, -38, 0, 14)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    ToggleBtn.BorderSizePixel = 0
    ToggleBtn.AutoButtonColor = true
    ToggleBtn.Active = true
    ToggleBtn.ZIndex = 25
    ToggleBtn.Text = ""
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0) -- Hình tròn hoàn hảo

    local BtnStroke = Instance.new("UIStroke", ToggleBtn)
    BtnStroke.Color = Color3.fromRGB(255, 255, 255)
    BtnStroke.Thickness = 1.2
    BtnStroke.Transparency = 0.4

    local Indicator = Instance.new("TextLabel", ToggleBtn)
    Indicator.Name = "Indicator"
    Indicator.Text = "●"
    Indicator.Font = Enum.Font.GothamBold
    Indicator.TextSize = 13
    Indicator.TextColor3 = Color3.fromRGB(255, 255, 255)
    Indicator.Size = UDim2.new(1, 0, 1, 0)
    Indicator.BackgroundTransparency = 1
    Indicator.ZIndex = 26

    local function onToggleActivated()
        DashboardGui.toggleBlackout()
    end
    ToggleBtn.Activated:Connect(onToggleActivated)
    ToggleBtn.MouseButton1Click:Connect(onToggleActivated)
    uiElements.ToggleBtn = ToggleBtn

    local CrownLogo = Instance.new("ImageButton", HeaderFrame)
    CrownLogo.Name = "CrownLogo"
    CrownLogo.Size = UDim2.new(0, 56, 0, 56)
    CrownLogo.Position = UDim2.new(0, 18, 0, 10)
    CrownLogo.BackgroundTransparency = 1
    CrownLogo.Image = logoAssetId
    CrownLogo.ScaleType = Enum.ScaleType.Fit
    CrownLogo.ZIndex = 10
    CrownLogo.Active = true
    CrownLogo.Activated:Connect(onToggleActivated)
    CrownLogo.MouseButton1Click:Connect(onToggleActivated)

    local BrandText = Instance.new("TextLabel", HeaderFrame)
    BrandText.Name = "BrandText"
    BrandText.Text = "kizhub"
    BrandText.Font = Enum.Font.GothamBold
    BrandText.TextSize = 16
    BrandText.TextColor3 = Color3.fromRGB(255, 140, 0)
    BrandText.TextXAlignment = Enum.TextXAlignment.Center
    BrandText.BackgroundTransparency = 1
    BrandText.Position = UDim2.new(0, 18, 0, 68)
    BrandText.Size = UDim2.new(0, 56, 0, 20)
    BrandText.ZIndex = 10

    local TitleInfo = Instance.new("TextLabel", HeaderFrame)
    TitleInfo.Text = titleText
    TitleInfo.Font = Enum.Font.GothamBold
    TitleInfo.TextSize = 15
    TitleInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleInfo.TextXAlignment = Enum.TextXAlignment.Left
    TitleInfo.BackgroundTransparency = 1
    TitleInfo.Position = UDim2.new(0, 88, 0, 18)
    TitleInfo.Size = UDim2.new(1, -130, 0, 20)
    TitleInfo.ZIndex = 5

    local SubInfo = Instance.new("TextLabel", HeaderFrame)
    SubInfo.Text = subText
    SubInfo.Font = Enum.Font.Gotham
    SubInfo.TextSize = 11
    SubInfo.TextColor3 = Color3.fromRGB(160, 160, 175)
    SubInfo.TextXAlignment = Enum.TextXAlignment.Left
    SubInfo.BackgroundTransparency = 1
    SubInfo.Position = UDim2.new(0, 90, 0, 40)
    SubInfo.Size = UDim2.new(1, -90, 0, 16)
    SubInfo.ZIndex = 2

    local KeyInfo = Instance.new("TextLabel", HeaderFrame)
    KeyInfo.Text = "[ Phím RightControl: Ẩn / Hiện GUI ]"
    KeyInfo.Font = Enum.Font.GothamMedium
    KeyInfo.TextSize = 10
    KeyInfo.TextColor3 = Color3.fromRGB(255, 180, 50)
    KeyInfo.TextXAlignment = Enum.TextXAlignment.Left
    KeyInfo.BackgroundTransparency = 1
    KeyInfo.Position = UDim2.new(0, 90, 0, 58)
    KeyInfo.Size = UDim2.new(1, -90, 0, 16)
    KeyInfo.ZIndex = 2

    local SepLine = Instance.new("Frame", KizCard)
    SepLine.Size = UDim2.new(1, -36, 0, 1)
    SepLine.Position = UDim2.new(0, 18, 0, 92)
    SepLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SepLine.BorderSizePixel = 0
    SepLine.ZIndex = 2

    -- Container chứa các dòng thông tin
    local InfoContainer = Instance.new("Frame", KizCard)
    InfoContainer.Name = "InfoContainer"
    InfoContainer.Size = UDim2.new(1, -36, 1, -102)
    InfoContainer.Position = UDim2.new(0, 18, 0, 100)
    InfoContainer.BackgroundTransparency = 1
    InfoContainer.ZIndex = 2

    local function createRow(labelText, defaultVal, yPos, highlightColor)
        local lbl = Instance.new("TextLabel", InfoContainer)
        lbl.Text = labelText
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextColor3 = Color3.fromRGB(200, 200, 215)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 0, 0, yPos)
        lbl.Size = UDim2.new(0, 140, 0, 18)
        lbl.ZIndex = 2

        local val = Instance.new("TextLabel", InfoContainer)
        val.Text = defaultVal
        val.Font = Enum.Font.GothamBold
        val.TextSize = 11
        val.TextColor3 = highlightColor or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(0, 140, 0, yPos)
        val.Size = UDim2.new(1, -140, 0, 18)
        val.ZIndex = 2
        return val
    end

    uiElements.UptimeLabel  = createRow("Thời Gian Chạy:", "00:00:00 (0.0 phút)", 0, Color3.fromRGB(0, 255, 140))
    uiElements.ZoneLabel    = createRow("Zone Hiện Tại:", "Đang tải...", 20)
    uiElements.CombineLabel = createRow("Combine Egg:", "Rảnh", 40, Color3.fromRGB(255, 215, 0))
    uiElements.MailLabel    = createRow("Auto Mailbox:", "Rảnh", 60, Color3.fromRGB(0, 200, 255))
    uiElements.DaycareLabel = createRow("Auto Daycare:", "Đang tải...", 80, Color3.fromRGB(180, 130, 255))
    uiElements.CoinsLabel   = createRow("Tiền Tệ / Coins:", "0", 100)
    uiElements.TreatsLabel  = createRow("Treats / Trứng Nở:", "0 / 0", 120)

    local SubTitleLabel = Instance.new("TextLabel", InfoContainer)
    SubTitleLabel.Name = "SubTitleLabel"
    SubTitleLabel.Text = "Tiến Trình & Trạng Thái Chi Tiết:"
    SubTitleLabel.Font = Enum.Font.GothamBold
    SubTitleLabel.TextSize = 11
    SubTitleLabel.TextColor3 = Color3.fromRGB(255, 140, 0)
    SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubTitleLabel.BackgroundTransparency = 1
    SubTitleLabel.Position = UDim2.new(0, 0, 0, 144)
    SubTitleLabel.Size = UDim2.new(1, 0, 0, 18)
    SubTitleLabel.ZIndex = 2
    uiElements.SubTitleLabel = SubTitleLabel

    local DetailBox = Instance.new("TextLabel", InfoContainer)
    DetailBox.Name = "DetailBox"
    DetailBox.Text = "Đang nạp dữ liệu hoạt động..."
    DetailBox.Font = Enum.Font.Code
    DetailBox.TextSize = 10
    DetailBox.TextColor3 = Color3.fromRGB(180, 235, 200)
    DetailBox.TextXAlignment = Enum.TextXAlignment.Left
    DetailBox.TextYAlignment = Enum.TextYAlignment.Top
    DetailBox.TextWrapped = true
    DetailBox.BackgroundTransparency = 1
    DetailBox.Position = UDim2.new(0, 0, 0, 164)
    DetailBox.Size = UDim2.new(1, 0, 0, 115)
    DetailBox.ZIndex = 2
    uiElements.DetailBox = DetailBox

    -- Lắng nghe phím RightControl (PC) & Tạo nút bấm cảm ứng (Mobile Delta)
    if UserInputService then
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == toggleKey then
                DashboardGui.toggleBlackout()
            end
        end)

        if UserInputService.TouchEnabled then
            local MobileBtn = Instance.new("TextButton", ScreenGui)
            MobileBtn.Name = "KizHubMobileToggle"
            MobileBtn.Text = "KIZHUB"
            MobileBtn.Font = Enum.Font.GothamBold
            MobileBtn.TextSize = 10
            MobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            MobileBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
            MobileBtn.Position = UDim2.new(0, 10, 0, 10)
            MobileBtn.Size = UDim2.new(0, 65, 0, 26)
            MobileBtn.ZIndex = 10
            MobileBtn.Active = true
            MobileBtn.Draggable = true
            Instance.new("UICorner", MobileBtn).CornerRadius = UDim.new(0, 8)
            MobileBtn.Activated:Connect(function()
                DashboardGui.toggleBlackout()
            end)
        end
    end

    if enableBlackout then
        DashboardGui.setBlackout(true)
    else
        DashboardGui.setBlackout(false)
        if KizCard then
            KizCard.Visible = true
        end
        if BlackBackground then
            BlackBackground.Visible = false
        end
        pcall(function()
            if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(true)
            end
        end)
    end
    return uiElements
end

function DashboardGui.getElements()
    return uiElements
end

function DashboardGui.destroy()
    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
        ScreenGui = nil
        BlackBackground = nil
        KizCard = nil
        uiElements = {}
    end
    pcall(function()
        if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
            RunService:Set3dRenderingEnabled(true)
        end
    end)
end

return DashboardGui
