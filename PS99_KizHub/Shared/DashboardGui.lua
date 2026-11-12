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

-- =========================================================================
-- KHỞI TẠO GIAO DIỆN KIZHUB DASHBOARD VỚI BIỂU TƯỢNG 👑 & THEO DÕI 4 QUESTS
-- Chuẩn 100% theo bản KizHub Dashboard gốc: 👑 KIZHUB, Thanh tiến trình Rank,
-- 4 Hàng Quests kèm thanh phần trăm nạp trực tiếp, Khu vực, Hành động & Totals
-- =========================================================================
function DashboardGui.createKizHub(config)
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

    if config.ToggleKey then
        toggleKey = config.ToggleKey
    end

    local parent = getSafeGuiParent()

    local old = parent:FindFirstChild("KizHub_Blackout_Dashboard") or parent:FindFirstChild("FrostHub_BlackScreen") or parent:FindFirstChild("Kizhub_BlackScreen")
    if old then
        pcall(function() old:Destroy() end)
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KizHub_Blackout_Dashboard"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent

    -- 1. Fullscreen Blackout Frame (AMOLED Dark)
    local enableBlackout = (config.Blackout ~= false)
    BlackBackground = Instance.new("Frame", ScreenGui)
    BlackBackground.Name = "BlackoutFrame"
    BlackBackground.Size = UDim2.new(1, 0, 1, 0)
    BlackBackground.Position = UDim2.new(0, 0, 0, 0)
    BlackBackground.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
    BlackBackground.BorderSizePixel = 0
    BlackBackground.Active = true
    BlackBackground.Visible = enableBlackout

    -- 2. Center Dashboard Panel
    local Panel = Instance.new("Frame", BlackBackground)
    Panel.Name = "DashboardPanel"
    Panel.AnchorPoint = Vector2.new(0.5, 0.5)
    Panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    Panel.Size = UDim2.fromOffset(560, 680)
    Panel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Panel.BorderSizePixel = 0
    KizCard = Panel

    local pCorner = Instance.new("UICorner", Panel)
    pCorner.CornerRadius = UDim.new(0, 14)

    local pStroke = Instance.new("UIStroke", Panel)
    pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pStroke.Color = Color3.fromRGB(0, 229, 190)
    pStroke.Transparency = 0.2
    pStroke.Thickness = 1.5

    local pScale = Instance.new("UIScale", Panel)
    local function FitPanel()
        if not BlackBackground or not BlackBackground.Parent then return end
        local vp = BlackBackground.AbsoluteSize
        local scale = math.clamp(math.min((vp.X - 24) / 560, (vp.Y - 24) / 680), 0.35, 1.1)
        pScale.Scale = scale
    end
    BlackBackground:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitPanel)
    task.defer(FitPanel)

    -- Header
    local Header = Instance.new("Frame", Panel)
    Header.Name = "Header"
    Header.Size = UDim2.new(1, -32, 0, 50)
    Header.Position = UDim2.new(0, 16, 0, 14)
    Header.BackgroundTransparency = 1

    local Title = Instance.new("TextLabel", Header)
    Title.Text = "👑 KIZHUB"
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 22
    Title.TextColor3 = Color3.fromRGB(0, 229, 190)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.Size = UDim2.new(0, 140, 0, 26)
    Title.BackgroundTransparency = 1

    local SubTitle = Instance.new("TextLabel", Header)
    SubTitle.Text = config.Subtitle or "PET SIMULATOR 99 • AUTORANK KAITUN (WORLD 1 ➔ RANK 11)"
    SubTitle.Font = Enum.Font.GothamMedium
    SubTitle.TextSize = 10
    SubTitle.TextColor3 = Color3.fromRGB(140, 150, 175)
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Position = UDim2.new(0, 0, 0, 26)
    SubTitle.Size = UDim2.new(0, 360, 0, 16)
    SubTitle.BackgroundTransparency = 1

    -- Quick Toggle 3D Button (Top right mini)
    local Toggle3D = Instance.new("TextButton", Header)
    Toggle3D.Name = "Toggle3D"
    Toggle3D.AnchorPoint = Vector2.new(1, 0)
    Toggle3D.Position = UDim2.new(1, -135, 0, 8)
    Toggle3D.Size = UDim2.fromOffset(80, 28)
    Toggle3D.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
    Toggle3D.Font = Enum.Font.GothamMedium
    Toggle3D.Text = "👁️ 3D Game"
    Toggle3D.TextSize = 11
    Toggle3D.TextColor3 = Color3.fromRGB(220, 225, 240)
    Instance.new("UICorner", Toggle3D).CornerRadius = UDim.new(0, 6)
    Toggle3D.Activated:Connect(function()
        DashboardGui.toggleBlackout()
    end)
    uiElements.ToggleBtn = Toggle3D

    local StatusBadge = Instance.new("Frame", Header)
    StatusBadge.Name = "StatusBadge"
    StatusBadge.AnchorPoint = Vector2.new(1, 0)
    StatusBadge.Position = UDim2.new(1, 0, 0, 8)
    StatusBadge.Size = UDim2.fromOffset(125, 28)
    StatusBadge.BackgroundColor3 = Color3.fromRGB(10, 40, 30)
    StatusBadge.BorderSizePixel = 0
    Instance.new("UICorner", StatusBadge).CornerRadius = UDim.new(0, 6)
    local sbStroke = Instance.new("UIStroke", StatusBadge)
    sbStroke.Color = Color3.fromRGB(0, 229, 190)
    sbStroke.Thickness = 1

    local StatusText = Instance.new("TextLabel", StatusBadge)
    StatusText.Text = "● RUNNING"
    StatusText.Font = Enum.Font.GothamBold
    StatusText.TextSize = 11
    StatusText.TextColor3 = Color3.fromRGB(0, 255, 170)
    StatusText.Size = UDim2.new(1, 0, 1, 0)
    StatusText.BackgroundTransparency = 1
    uiElements.StatusText = StatusText

    -- Account Row
    local AccountBar = Instance.new("Frame", Panel)
    AccountBar.Size = UDim2.new(1, -32, 0, 32)
    AccountBar.Position = UDim2.new(0, 16, 0, 72)
    AccountBar.BackgroundColor3 = Color3.fromRGB(22, 23, 30)
    AccountBar.BorderSizePixel = 0
    Instance.new("UICorner", AccountBar).CornerRadius = UDim.new(0, 6)

    local AccountLabel = Instance.new("TextLabel", AccountBar)
    AccountLabel.Text = "👤 " .. tostring(LocalPlayer and LocalPlayer.Name or "Player")
    AccountLabel.Font = Enum.Font.GothamSemibold
    AccountLabel.TextSize = 12
    AccountLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    AccountLabel.Position = UDim2.new(0, 12, 0, 0)
    AccountLabel.Size = UDim2.new(0.5, -12, 1, 0)
    AccountLabel.TextXAlignment = Enum.TextXAlignment.Left
    AccountLabel.BackgroundTransparency = 1
    uiElements.AccountLabel = AccountLabel

    local ElapsedLabel = Instance.new("TextLabel", AccountBar)
    ElapsedLabel.Text = "⏱️ 00:00:00"
    ElapsedLabel.Font = Enum.Font.GothamMedium
    ElapsedLabel.TextSize = 12
    ElapsedLabel.TextColor3 = Color3.fromRGB(160, 175, 205)
    ElapsedLabel.AnchorPoint = Vector2.new(1, 0)
    ElapsedLabel.Position = UDim2.new(1, -12, 0, 0)
    ElapsedLabel.Size = UDim2.new(0.5, -12, 1, 0)
    ElapsedLabel.TextXAlignment = Enum.TextXAlignment.Right
    ElapsedLabel.BackgroundTransparency = 1
    uiElements.ElapsedLabel = ElapsedLabel
    uiElements.UptimeLabel = ElapsedLabel

    -- CARD 1: RANK & STATS
    local RankCard = Instance.new("Frame", Panel)
    RankCard.Name = "RankCard"
    RankCard.Size = UDim2.new(1, -32, 0, 128)
    RankCard.Position = UDim2.new(0, 16, 0, 114)
    RankCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    RankCard.BorderSizePixel = 0
    Instance.new("UICorner", RankCard).CornerRadius = UDim.new(0, 10)

    local rcTitle = Instance.new("TextLabel", RankCard)
    rcTitle.Text = "🏆 TIẾN TRÌNH RANK (WORLD 1 ➔ RANK 11)"
    rcTitle.Font = Enum.Font.GothamBold
    rcTitle.TextSize = 11
    rcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    rcTitle.TextXAlignment = Enum.TextXAlignment.Left
    rcTitle.Position = UDim2.new(0, 14, 0, 10)
    rcTitle.Size = UDim2.new(1, -28, 0, 16)
    rcTitle.BackgroundTransparency = 1

    local RankValue = Instance.new("TextLabel", RankCard)
    RankValue.Text = "RANK 1 • ..."
    RankValue.Font = Enum.Font.GothamBold
    RankValue.TextSize = 17
    RankValue.TextColor3 = Color3.fromRGB(255, 215, 0)
    RankValue.TextXAlignment = Enum.TextXAlignment.Left
    RankValue.Position = UDim2.new(0, 14, 0, 30)
    RankValue.Size = UDim2.new(0.65, 0, 0, 24)
    RankValue.BackgroundTransparency = 1
    uiElements.RankValue = RankValue
    uiElements.CombineLabel = RankValue

    local TargetRankLabel = Instance.new("TextLabel", RankCard)
    TargetRankLabel.Text = "Mục tiêu: Rank 11"
    TargetRankLabel.Font = Enum.Font.GothamMedium
    TargetRankLabel.TextSize = 12
    TargetRankLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
    TargetRankLabel.TextXAlignment = Enum.TextXAlignment.Right
    TargetRankLabel.AnchorPoint = Vector2.new(1, 0)
    TargetRankLabel.Position = UDim2.new(1, -14, 0, 30)
    TargetRankLabel.Size = UDim2.new(0.35, 0, 0, 24)
    TargetRankLabel.BackgroundTransparency = 1
    uiElements.TargetRankLabel = TargetRankLabel

    local StarsLabel = Instance.new("TextLabel", RankCard)
    StarsLabel.Text = "⭐ Stars: 0 / 0 (0%)"
    StarsLabel.Font = Enum.Font.GothamSemibold
    StarsLabel.TextSize = 12
    StarsLabel.TextColor3 = Color3.fromRGB(230, 235, 250)
    StarsLabel.TextXAlignment = Enum.TextXAlignment.Left
    StarsLabel.Position = UDim2.new(0, 14, 0, 58)
    StarsLabel.Size = UDim2.new(1, -28, 0, 18)
    StarsLabel.BackgroundTransparency = 1
    uiElements.StarsLabel = StarsLabel
    uiElements.MailLabel = StarsLabel

    local StarBarBg = Instance.new("Frame", RankCard)
    StarBarBg.Size = UDim2.new(1, -28, 0, 10)
    StarBarBg.Position = UDim2.new(0, 14, 0, 78)
    StarBarBg.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
    StarBarBg.BorderSizePixel = 0
    Instance.new("UICorner", StarBarBg).CornerRadius = UDim.new(0, 5)

    local StarBarFill = Instance.new("Frame", StarBarBg)
    StarBarFill.Size = UDim2.new(0, 0, 1, 0)
    StarBarFill.BackgroundColor3 = Color3.fromRGB(0, 229, 190)
    StarBarFill.BorderSizePixel = 0
    Instance.new("UICorner", StarBarFill).CornerRadius = UDim.new(0, 5)
    uiElements.StarBarFill = StarBarFill

    local RankSubStats = Instance.new("TextLabel", RankCard)
    RankSubStats.Text = "🎁 Quà: 0/0  |  🔄 Rebirth: 0  |  ⚡ Trạng thái: Cày sao"
    RankSubStats.Font = Enum.Font.GothamMedium
    RankSubStats.TextSize = 11
    RankSubStats.TextColor3 = Color3.fromRGB(150, 160, 185)
    RankSubStats.TextXAlignment = Enum.TextXAlignment.Left
    RankSubStats.Position = UDim2.new(0, 14, 0, 96)
    RankSubStats.Size = UDim2.new(1, -28, 0, 20)
    RankSubStats.BackgroundTransparency = 1
    uiElements.RankSubStats = RankSubStats
    uiElements.DaycareLabel = RankSubStats

    -- CARD 2: ZONE INFO
    local ZoneCard = Instance.new("Frame", Panel)
    ZoneCard.Name = "ZoneCard"
    ZoneCard.Size = UDim2.new(1, -32, 0, 68)
    ZoneCard.Position = UDim2.new(0, 16, 0, 252)
    ZoneCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    ZoneCard.BorderSizePixel = 0
    Instance.new("UICorner", ZoneCard).CornerRadius = UDim.new(0, 10)

    local zcTitle = Instance.new("TextLabel", ZoneCard)
    zcTitle.Text = "🗺️ KHU VỰC HIỆN TẠI (WORLD 1)"
    zcTitle.Font = Enum.Font.GothamBold
    zcTitle.TextSize = 11
    zcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    zcTitle.TextXAlignment = Enum.TextXAlignment.Left
    zcTitle.Position = UDim2.new(0, 14, 0, 10)
    zcTitle.Size = UDim2.new(1, -28, 0, 16)
    zcTitle.BackgroundTransparency = 1

    local ZoneLabel = Instance.new("TextLabel", ZoneCard)
    ZoneLabel.Text = "Zone #1: Spawn"
    ZoneLabel.Font = Enum.Font.GothamSemibold
    ZoneLabel.TextSize = 14
    ZoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ZoneLabel.TextXAlignment = Enum.TextXAlignment.Left
    ZoneLabel.Position = UDim2.new(0, 14, 0, 28)
    ZoneLabel.Size = UDim2.new(0.65, 0, 0, 20)
    ZoneLabel.BackgroundTransparency = 1
    uiElements.ZoneLabel = ZoneLabel

    local ActionLabel = Instance.new("TextLabel", ZoneCard)
    ActionLabel.Text = "Hành động: Farming..."
    ActionLabel.Font = Enum.Font.GothamMedium
    ActionLabel.TextSize = 11
    ActionLabel.TextColor3 = Color3.fromRGB(150, 160, 185)
    ActionLabel.TextXAlignment = Enum.TextXAlignment.Left
    ActionLabel.Position = UDim2.new(0, 14, 0, 48)
    ActionLabel.Size = UDim2.new(1, -28, 0, 16)
    ActionLabel.BackgroundTransparency = 1
    uiElements.ActionLabel = ActionLabel
    uiElements.DetailBox = ActionLabel

    -- CARD 3: ACTIVE QUESTS (4 HÀNG QUESTS KÈM PROGRESS BAR)
    local QuestCard = Instance.new("Frame", Panel)
    QuestCard.Name = "QuestCard"
    QuestCard.Size = UDim2.new(1, -32, 0, 220)
    QuestCard.Position = UDim2.new(0, 16, 0, 330)
    QuestCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    QuestCard.BorderSizePixel = 0
    Instance.new("UICorner", QuestCard).CornerRadius = UDim.new(0, 10)

    local qcTitle = Instance.new("TextLabel", QuestCard)
    qcTitle.Text = "📜 NHIỆM VỤ RANK ĐANG LÀM (ACTIVE QUESTS)"
    qcTitle.Font = Enum.Font.GothamBold
    qcTitle.TextSize = 11
    qcTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    qcTitle.TextXAlignment = Enum.TextXAlignment.Left
    qcTitle.Position = UDim2.new(0, 14, 0, 10)
    qcTitle.Size = UDim2.new(1, -28, 0, 16)
    qcTitle.BackgroundTransparency = 1

    local QuestRows = {}
    for i = 1, 4 do
        local qRow = Instance.new("Frame", QuestCard)
        qRow.Name = "QuestRow_" .. i
        qRow.Size = UDim2.new(1, -28, 0, 42)
        qRow.Position = UDim2.new(0, 14, 0, 30 + (i - 1) * 46)
        qRow.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
        qRow.BorderSizePixel = 0
        qRow.Visible = false
        Instance.new("UICorner", qRow).CornerRadius = UDim.new(0, 6)

        local qStars = Instance.new("TextLabel", qRow)
        qStars.Text = "[⭐ 1]"
        qStars.Font = Enum.Font.GothamBold
        qStars.TextSize = 11
        qStars.TextColor3 = Color3.fromRGB(255, 200, 50)
        qStars.Position = UDim2.new(0, 8, 0, 4)
        qStars.Size = UDim2.new(0, 42, 0, 16)
        qStars.TextXAlignment = Enum.TextXAlignment.Left
        qStars.BackgroundTransparency = 1

        local qName = Instance.new("TextLabel", qRow)
        qName.Text = "Quest Name..."
        qName.Font = Enum.Font.GothamSemibold
        qName.TextSize = 12
        qName.TextColor3 = Color3.fromRGB(240, 245, 255)
        qName.Position = UDim2.new(0, 52, 0, 4)
        qName.Size = UDim2.new(1, -165, 0, 16)
        qName.TextXAlignment = Enum.TextXAlignment.Left
        qName.TextTruncate = Enum.TextTruncate.AtEnd
        qName.BackgroundTransparency = 1

        local qProgText = Instance.new("TextLabel", qRow)
        qProgText.Text = "0 / 0"
        qProgText.Font = Enum.Font.GothamMedium
        qProgText.TextSize = 11
        qProgText.TextColor3 = Color3.fromRGB(0, 229, 190)
        qProgText.AnchorPoint = Vector2.new(1, 0)
        qProgText.Position = UDim2.new(1, -8, 0, 4)
        qProgText.Size = UDim2.new(0, 110, 0, 16)
        qProgText.TextXAlignment = Enum.TextXAlignment.Right
        qProgText.BackgroundTransparency = 1

        local qBarBg = Instance.new("Frame", qRow)
        qBarBg.Size = UDim2.new(1, -16, 0, 6)
        qBarBg.Position = UDim2.new(0, 8, 0, 26)
        qBarBg.BackgroundColor3 = Color3.fromRGB(40, 43, 55)
        qBarBg.BorderSizePixel = 0
        Instance.new("UICorner", qBarBg).CornerRadius = UDim.new(0, 3)

        local qBarFill = Instance.new("Frame", qBarBg)
        qBarFill.Size = UDim2.new(0, 0, 1, 0)
        qBarFill.BackgroundColor3 = Color3.fromRGB(0, 229, 190)
        qBarFill.BorderSizePixel = 0
        Instance.new("UICorner", qBarFill).CornerRadius = UDim.new(0, 3)

        table.insert(QuestRows, {
            Frame = qRow,
            Stars = qStars,
            Name = qName,
            ProgressText = qProgText,
            BarFill = qBarFill
        })
    end
    uiElements.QuestRows = QuestRows

    -- CARD 4: ACTIVITY TOTALS
    local FooterBar = Instance.new("Frame", Panel)
    FooterBar.Size = UDim2.new(1, -32, 0, 64)
    FooterBar.Position = UDim2.new(0, 16, 0, 560)
    FooterBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    FooterBar.BorderSizePixel = 0
    Instance.new("UICorner", FooterBar).CornerRadius = UDim.new(0, 10)

    local fbTitle = Instance.new("TextLabel", FooterBar)
    fbTitle.Text = "📊 THỐNG KÊ HOẠT ĐỘNG PHIÊN TREO"
    fbTitle.Font = Enum.Font.GothamBold
    fbTitle.TextSize = 11
    fbTitle.TextColor3 = Color3.fromRGB(0, 229, 190)
    fbTitle.TextXAlignment = Enum.TextXAlignment.Left
    fbTitle.Position = UDim2.new(0, 14, 0, 10)
    fbTitle.Size = UDim2.new(1, -28, 0, 16)
    fbTitle.BackgroundTransparency = 1

    local TotalsLabel = Instance.new("TextLabel", FooterBar)
    TotalsLabel.Text = "💰 Xu: 0  |  💎 Gems: 0  |  🥚 Trứng: 0"
    TotalsLabel.Font = Enum.Font.GothamSemibold
    TotalsLabel.TextSize = 12
    TotalsLabel.TextColor3 = Color3.fromRGB(220, 230, 250)
    TotalsLabel.TextXAlignment = Enum.TextXAlignment.Left
    TotalsLabel.Position = UDim2.new(0, 14, 0, 32)
    TotalsLabel.Size = UDim2.new(1, -28, 0, 22)
    TotalsLabel.BackgroundTransparency = 1
    uiElements.TotalsLabel = TotalsLabel
    uiElements.CoinsLabel = TotalsLabel
    uiElements.TreatsLabel = TotalsLabel

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
