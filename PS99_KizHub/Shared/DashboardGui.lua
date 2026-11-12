-- =========================================================================
-- PS99_KizHub/Shared/DashboardGui.lua
-- Giao diện AMOLED Frost Hub & Blackout Màn Hình Đen Toàn Diện (Zero Gaps)
-- Chuẩn 100% theo giao diện Frost Hub: Màn đen tuyền, Card bo góc ở chính giữa,
-- Badge viên thuốc trên đỉnh, Đo FPS thời gian thực, Tắt 3D Rendering tối đa FPS.
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
local TopBadge = nil
local uiElements = {}
local isBlackoutVisible = true
local toggleKey = Enum.KeyCode.RightControl

-- Đo FPS thời gian thực
local currentFPS = 60
local frameCount = 0
local lastFpsTime = os.clock()
pcall(function()
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = os.clock()
        if now - lastFpsTime >= 1.0 then
            currentFPS = math.max(1, frameCount)
            frameCount = 0
            lastFpsTime = now
        end
    end)
end)

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
    if TopBadge then
        TopBadge.BackgroundColor3 = visible and Color3.fromRGB(15, 23, 42) or Color3.fromRGB(30, 41, 59)
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

function DashboardGui.destroy()
    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
        ScreenGui = nil
    end
    BlackBackground = nil
    KizCard = nil
    TopBadge = nil
    uiElements = {}
end

-- Khởi tạo Giao diện AMOLED Frost Hub Card
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

    local titleText = config.Title or "Frost Hub"
    local badgeText = config.BadgeTitle or "❄ Frost Hub | Halloween Games"
    local subText = config.Subtitle or "Black Screen: the 3D world is not drawn, the script keeps playing"
    local discordText = config.Discord or "discord.gg/frostps99"
    if config.ToggleKey then
        toggleKey = config.ToggleKey
    end

    local parent = getSafeGuiParent()

    -- Hủy GUI cũ nếu có
    local old = parent:FindFirstChild("Kizhub_BlackScreen") or parent:FindFirstChild("KizHub_Blackout_Dashboard") or parent:FindFirstChild("FrostHub_BlackScreen")
    if old then
        pcall(function() old:Destroy() end)
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FrostHub_BlackScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    -- ĐEN TOÀN MÀN HÌNH KHÔNG CHỪA 1 KHOẢNG TRỐNG NÀO CẢ (Phủ cả Topbar Roblox)
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent

    -- Background Đen AMOLED toàn màn hình 100%
    local enableBlackout = (config.Blackout ~= false)
    BlackBackground = Instance.new("Frame", ScreenGui)
    BlackBackground.Name = "BlackBackground"
    BlackBackground.Size = UDim2.new(1, 0, 1, 0)
    BlackBackground.Position = UDim2.new(0, 0, 0, 0)
    BlackBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BlackBackground.BorderSizePixel = 0
    BlackBackground.ZIndex = 0
    BlackBackground.Visible = enableBlackout

    -- 1. Badge hình viên thuốc ở chính giữa đỉnh màn hình (Top Capsule Badge)
    TopBadge = Instance.new("TextButton", ScreenGui)
    TopBadge.Name = "TopBadge"
    TopBadge.AnchorPoint = Vector2.new(0.5, 0)
    TopBadge.Position = UDim2.new(0.5, 0, 0, 16)
    TopBadge.Size = UDim2.new(0, 240, 0, 28)
    TopBadge.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    TopBadge.BorderSizePixel = 0
    TopBadge.AutoButtonColor = true
    TopBadge.Text = badgeText
    TopBadge.Font = Enum.Font.GothamBold
    TopBadge.TextSize = 11
    TopBadge.TextColor3 = Color3.fromRGB(224, 242, 254)
    TopBadge.ZIndex = 10
    Instance.new("UICorner", TopBadge).CornerRadius = UDim.new(1, 0)

    local TopBadgeStroke = Instance.new("UIStroke", TopBadge)
    TopBadgeStroke.Color = Color3.fromRGB(56, 189, 248)
    TopBadgeStroke.Thickness = 1.0
    TopBadgeStroke.Transparency = 0.45

    TopBadge.Activated:Connect(function()
        DashboardGui.toggleBlackout()
    end)
    uiElements.ToggleBtn = TopBadge

    -- 2. Thẻ Card trung tâm (Frost Hub Card)
    KizCard = Instance.new("Frame", ScreenGui)
    KizCard.Name = "FrostCard"
    KizCard.AnchorPoint = Vector2.new(0.5, 0.5)
    KizCard.Position = UDim2.new(0.5, 0, 0.5, 0)
    KizCard.Size = UDim2.new(0, 500, 0, 340)
    KizCard.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
    KizCard.BackgroundTransparency = 0.05
    KizCard.BorderSizePixel = 0
    KizCard.ClipsDescendants = true
    KizCard.Active = true
    KizCard.Draggable = true
    KizCard.ZIndex = 2

    Instance.new("UICorner", KizCard).CornerRadius = UDim.new(0, 14)
    local CardStroke = Instance.new("UIStroke", KizCard)
    CardStroke.Color = Color3.fromRGB(38, 70, 110)
    CardStroke.Thickness = 1.5
    CardStroke.Transparency = 0.2

    -- Padding bên trong Card
    local CardPadding = Instance.new("UIPadding", KizCard)
    CardPadding.PaddingTop = UDim.new(0, 18)
    CardPadding.PaddingBottom = UDim.new(0, 18)
    CardPadding.PaddingLeft = UDim.new(0, 22)
    CardPadding.PaddingRight = UDim.new(0, 22)

    -- Header Frame
    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Name = "HeaderFrame"
    HeaderFrame.Size = UDim2.new(1, 0, 0, 48)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.ZIndex = 3

    local TitleLabel = Instance.new("TextLabel", HeaderFrame)
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Text = "❄ " .. titleText
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 17
    TitleLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 0, 0, 0)
    TitleLabel.Size = UDim2.new(1, 0, 0, 22)
    TitleLabel.ZIndex = 4

    local SubtitleLabel = Instance.new("TextLabel", HeaderFrame)
    SubtitleLabel.Name = "SubtitleLabel"
    SubtitleLabel.Text = subText
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.TextSize = 11
    SubtitleLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Position = UDim2.new(0, 0, 0, 24)
    SubtitleLabel.Size = UDim2.new(1, 0, 0, 18)
    SubtitleLabel.ZIndex = 4

    -- Content Container
    local ContentFrame = Instance.new("Frame", KizCard)
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, 0, 1, -100)
    ContentFrame.Position = UDim2.new(0, 0, 0, 54)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ZIndex = 3

    -- Dòng nổi bật (Main Highlight Row) - VD: Night 1 • Game 2 of 6 • Hot Pumpkin • 100 in the bag
    local MainHighlightRow = Instance.new("TextLabel", ContentFrame)
    MainHighlightRow.Name = "MainHighlightRow"
    MainHighlightRow.Text = "Đang khởi động..."
    MainHighlightRow.Font = Enum.Font.GothamBold
    MainHighlightRow.TextSize = 13
    MainHighlightRow.TextColor3 = Color3.fromRGB(248, 250, 252)
    MainHighlightRow.TextXAlignment = Enum.TextXAlignment.Left
    MainHighlightRow.TextTruncate = Enum.TextTruncate.AtEnd
    MainHighlightRow.BackgroundTransparency = 1
    MainHighlightRow.Position = UDim2.new(0, 0, 0, 4)
    MainHighlightRow.Size = UDim2.new(1, 0, 0, 20)
    MainHighlightRow.ZIndex = 4
    uiElements.ZoneLabel = MainHighlightRow
    uiElements.MainRow = MainHighlightRow

    local function createInfoLine(name, defaultText, yOffset, textColor)
        local lbl = Instance.new("TextLabel", ContentFrame)
        lbl.Name = name
        lbl.Text = defaultText
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextColor3 = textColor or Color3.fromRGB(203, 213, 225)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 0, 0, yOffset)
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.ZIndex = 4
        return lbl
    end

    -- Dòng 1: Treats / Coins
    uiElements.TreatsLabel = createInfoLine("TreatsLabel", "Treats: 0", 28, Color3.fromRGB(203, 213, 225))

    -- Dòng 2: Candy Coins / Gems
    uiElements.CoinsLabel = createInfoLine("CoinsLabel", "Candy Coins: 0", 48, Color3.fromRGB(203, 213, 225))

    -- Dòng 3: Combine Egg Status / Rank Goals
    uiElements.CombineLabel = createInfoLine("CombineLabel", "Combine Egg: Rảnh", 68, Color3.fromRGB(250, 204, 21))

    -- Dòng 4: Hatched / Gifts / Upgrades (hoặc Mail / Daycare)
    uiElements.MailLabel = createInfoLine("MailLabel", "Hatched: 0   Gifts: 0   Upgrades: 0", 88, Color3.fromRGB(148, 163, 184))
    uiElements.DaycareLabel = createInfoLine("DaycareLabel", "Auto Daycare: Đang tải...", 108, Color3.fromRGB(180, 130, 255))
    uiElements.DaycareLabel.Visible = false -- Ẩn mặc định cho gọn

    -- Dòng 5: Doing / Detail / Quests Box
    local DetailBox = Instance.new("TextLabel", ContentFrame)
    DetailBox.Name = "DetailBox"
    DetailBox.Text = "Doing: Đang chuẩn bị hoạt động..."
    DetailBox.Font = Enum.Font.Gotham
    DetailBox.TextSize = 11
    DetailBox.TextColor3 = Color3.fromRGB(148, 163, 184)
    DetailBox.TextXAlignment = Enum.TextXAlignment.Left
    DetailBox.TextYAlignment = Enum.TextYAlignment.Top
    DetailBox.TextWrapped = true
    DetailBox.BackgroundTransparency = 1
    DetailBox.Position = UDim2.new(0, 0, 0, 110)
    DetailBox.Size = UDim2.new(1, 0, 0, 80)
    DetailBox.ZIndex = 4
    uiElements.DetailBox = DetailBox

    -- Footer Frame
    local FooterFrame = Instance.new("Frame", KizCard)
    FooterFrame.Name = "FooterFrame"
    FooterFrame.Size = UDim2.new(1, 0, 0, 36)
    FooterFrame.Position = UDim2.new(0, 0, 1, -36)
    FooterFrame.BackgroundTransparency = 1
    FooterFrame.ZIndex = 3

    -- Uptime & FPS label: Running 0:01:55 • 406 FPS
    local UptimeLabel = Instance.new("TextLabel", FooterFrame)
    UptimeLabel.Name = "UptimeLabel"
    UptimeLabel.Text = "Running 0:00:00 • 60 FPS"
    UptimeLabel.Font = Enum.Font.GothamMedium
    UptimeLabel.TextSize = 10
    UptimeLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
    UptimeLabel.TextXAlignment = Enum.TextXAlignment.Left
    UptimeLabel.BackgroundTransparency = 1
    UptimeLabel.Position = UDim2.new(0, 0, 0, 0)
    UptimeLabel.Size = UDim2.new(1, 0, 0, 16)
    UptimeLabel.ZIndex = 4

    -- Bọc hàm update uptime để tự động ghép FPS vào đuôi
    local origUptimeText = ""
    local uptimeProxy = newproxy(true)
    local meta = getmetatable(uptimeProxy)
    meta.__index = function(_, k)
        if k == "Text" then return origUptimeText end
        return UptimeLabel[k]
    end
    meta.__newindex = function(_, k, v)
        if k == "Text" then
            origUptimeText = tostring(v)
            UptimeLabel.Text = string.format("Running %s • %d FPS", origUptimeText, currentFPS)
        else
            UptimeLabel[k] = v
        end
    end
    uiElements.UptimeLabel = uptimeProxy

    -- Discord / Brand Link
    local DiscordLabel = Instance.new("TextLabel", FooterFrame)
    DiscordLabel.Name = "DiscordLabel"
    DiscordLabel.Text = discordText
    DiscordLabel.Font = Enum.Font.GothamBold
    DiscordLabel.TextSize = 11
    DiscordLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    DiscordLabel.TextXAlignment = Enum.TextXAlignment.Left
    DiscordLabel.BackgroundTransparency = 1
    DiscordLabel.Position = UDim2.new(0, 0, 0, 18)
    DiscordLabel.Size = UDim2.new(1, 0, 0, 16)
    DiscordLabel.ZIndex = 4
    uiElements.DiscordLabel = DiscordLabel

    -- Phím tắt RightControl: Ẩn / Hiện GUI
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            DashboardGui.toggleBlackout()
        end
    end)

    return uiElements
end

return DashboardGui
