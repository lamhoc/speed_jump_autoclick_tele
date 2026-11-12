-- =========================================================================
-- PS99_KizHub/Shared/DashboardGui.lua
-- Giao diện AMOLED Frost Hub & Blackout Màn Hình Đen Toàn Diện (Zero Gaps)
-- Chuẩn 100% theo giao diện Frost Hub: Màn đen tuyền, Card bo góc ở chính giữa,
-- Badge viên thuốc trên đỉnh, Đo FPS thời gian thực, Tắt 3D Rendering tối đa FPS.
-- Tích hợp: 👑 Kiz Hub, Theo dõi 4 Quest Rank có Progress Bar, Thống kê thời gian thực.
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

    local titleRaw = config.Title or "Kiz Hub"
    local cleanTitle = titleRaw:gsub("^[❄👑%s]+", "")
    if cleanTitle == "" then cleanTitle = "Kiz Hub" end
    local titleText = "👑 " .. cleanTitle
    local badgeText = config.BadgeTitle or "👑 Kiz Hub | Auto Rank"
    local subText = config.Subtitle or "Black Screen: the 3D world is not drawn, the script keeps playing"
    local discordText = config.Discord or "discord.gg/kizhub"
    if config.ToggleKey then
        toggleKey = config.ToggleKey
    end

    local parent = getSafeGuiParent()

    -- Hủy GUI cũ nếu có
    local old = parent:FindFirstChild("KizHub_Blackout_Dashboard")
        or parent:FindFirstChild("FrostHub_BlackScreen")
        or parent:FindFirstChild("Kizhub_BlackScreen")
    if old then
        pcall(function() old:Destroy() end)
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KizHub_Blackout_Dashboard"
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
    BlackBackground.Active = true
    BlackBackground.Visible = enableBlackout

    -- Áp dụng tắt 3D Rendering ngay từ đầu nếu bật blackout
    if enableBlackout then
        pcall(function()
            if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(false)
            end
        end)
    end

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

    -- 2. Thẻ Card trung tâm (Frost Hub Card phong cách 👑 Kiz Hub)
    KizCard = Instance.new("Frame", ScreenGui)
    KizCard.Name = "KizCard"
    KizCard.AnchorPoint = Vector2.new(0.5, 0.5)
    KizCard.Position = UDim2.new(0.5, 0, 0.5, 0)
    KizCard.Size = UDim2.new(0, 520, 0, 420)
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

    -- Auto-scale cho màn hình nhỏ
    local pScale = Instance.new("UIScale", KizCard)
    local function FitPanel()
        if not ScreenGui or not ScreenGui.Parent then return end
        local vp = ScreenGui.AbsoluteSize
        if vp.X > 0 and vp.Y > 0 then
            local scale = math.clamp(math.min((vp.X - 20) / 520, (vp.Y - 20) / 420), 0.35, 1.0)
            pScale.Scale = scale
        end
    end
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitPanel)
    task.defer(FitPanel)

    -- Padding bên trong Card
    local CardPadding = Instance.new("UIPadding", KizCard)
    CardPadding.PaddingTop = UDim.new(0, 16)
    CardPadding.PaddingBottom = UDim.new(0, 14)
    CardPadding.PaddingLeft = UDim.new(0, 20)
    CardPadding.PaddingRight = UDim.new(0, 20)

    -- Header Frame
    local HeaderFrame = Instance.new("Frame", KizCard)
    HeaderFrame.Name = "HeaderFrame"
    HeaderFrame.Size = UDim2.new(1, 0, 0, 46)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.ZIndex = 3

    local TitleLabel = Instance.new("TextLabel", HeaderFrame)
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Text = titleText
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
    ContentFrame.Size = UDim2.new(1, 0, 1, -94)
    ContentFrame.Position = UDim2.new(0, 0, 0, 52)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ZIndex = 3

    -- Dòng nổi bật (Main Highlight Row): Night 1 • Game 2 of 6 / Rank 1 • Zone 1
    local MainHighlightRow = Instance.new("TextLabel", ContentFrame)
    MainHighlightRow.Name = "MainHighlightRow"
    MainHighlightRow.Text = "Rank 1 · Zone 1 (Spawn) · World 1"
    MainHighlightRow.Font = Enum.Font.GothamBold
    MainHighlightRow.TextSize = 13
    MainHighlightRow.TextColor3 = Color3.fromRGB(248, 250, 252)
    MainHighlightRow.TextXAlignment = Enum.TextXAlignment.Left
    MainHighlightRow.TextTruncate = Enum.TextTruncate.AtEnd
    MainHighlightRow.BackgroundTransparency = 1
    MainHighlightRow.Position = UDim2.new(0, 0, 0, 0)
    MainHighlightRow.Size = UDim2.new(1, 0, 0, 20)
    MainHighlightRow.ZIndex = 4
    uiElements.ZoneLabel = MainHighlightRow
    uiElements.MainRow = MainHighlightRow
    uiElements.RankValue = MainHighlightRow

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

    -- Dòng 1: Stars / Mục tiêu Rank
    local StarsLabel = createInfoLine("StarsLabel", "⭐ Sao: 0 / 25 (0%)", 22, Color3.fromRGB(250, 204, 21))
    uiElements.StarsLabel = StarsLabel

    -- Dòng 2: Coins / Diamonds
    local CoinsLabel = createInfoLine("CoinsLabel", "💰 Xu: 0  |  💎 Gems: 0", 42, Color3.fromRGB(203, 213, 225))
    uiElements.CoinsLabel = CoinsLabel
    uiElements.TotalsLabel = CoinsLabel
    uiElements.TreatsLabel = CoinsLabel

    -- Dòng 3: Hatched / Quests Done / Rewards
    local StatsLabel = createInfoLine("StatsLabel", "🥚 Trứng: 0  |  🎁 Quà: 0/0  |  🔄 Rebirth: 0", 62, Color3.fromRGB(148, 163, 184))
    uiElements.RankSubStats = StatsLabel
    uiElements.MailLabel = StatsLabel
    uiElements.CombineLabel = StatsLabel
    uiElements.DaycareLabel = StatsLabel

    -- Dòng 4: Doing / Hành động hiện tại
    local ActionLabel = createInfoLine("ActionLabel", "Doing: Farming bãi vỡ...", 82, Color3.fromRGB(56, 189, 248))
    uiElements.ActionLabel = ActionLabel
    uiElements.DetailBox = ActionLabel

    -- Khung 4 Nhiệm vụ Rank (Active Quests) kèm Progress Bar
    local QuestContainer = Instance.new("Frame", ContentFrame)
    QuestContainer.Name = "QuestContainer"
    QuestContainer.Size = UDim2.new(1, 0, 0, 150)
    QuestContainer.Position = UDim2.new(0, 0, 0, 104)
    QuestContainer.BackgroundTransparency = 1
    QuestContainer.ZIndex = 3

    local QuestRows = {}
    for i = 1, 4 do
        local qRow = Instance.new("Frame", QuestContainer)
        qRow.Name = "QuestRow_" .. i
        qRow.Size = UDim2.new(1, 0, 0, 34)
        qRow.Position = UDim2.new(0, 0, 0, (i - 1) * 37)
        qRow.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
        qRow.BorderSizePixel = 0
        qRow.Visible = false
        qRow.ZIndex = 4
        Instance.new("UICorner", qRow).CornerRadius = UDim.new(0, 6)

        local qStars = Instance.new("TextLabel", qRow)
        qStars.Text = "[⭐ 1]"
        qStars.Font = Enum.Font.GothamBold
        qStars.TextSize = 10
        qStars.TextColor3 = Color3.fromRGB(255, 200, 50)
        qStars.Position = UDim2.new(0, 8, 0, 2)
        qStars.Size = UDim2.new(0, 38, 0, 16)
        qStars.TextXAlignment = Enum.TextXAlignment.Left
        qStars.BackgroundTransparency = 1
        qStars.ZIndex = 5

        local qName = Instance.new("TextLabel", qRow)
        qName.Text = "Nhiệm vụ..."
        qName.Font = Enum.Font.GothamSemibold
        qName.TextSize = 11
        qName.TextColor3 = Color3.fromRGB(224, 231, 255)
        qName.Position = UDim2.new(0, 48, 0, 2)
        qName.Size = UDim2.new(1, -160, 0, 16)
        qName.TextXAlignment = Enum.TextXAlignment.Left
        qName.TextTruncate = Enum.TextTruncate.AtEnd
        qName.BackgroundTransparency = 1
        qName.ZIndex = 5

        local qProgText = Instance.new("TextLabel", qRow)
        qProgText.Text = "0 / 0"
        qProgText.Font = Enum.Font.GothamMedium
        qProgText.TextSize = 10
        qProgText.TextColor3 = Color3.fromRGB(56, 189, 248)
        qProgText.AnchorPoint = Vector2.new(1, 0)
        qProgText.Position = UDim2.new(1, -8, 0, 2)
        qProgText.Size = UDim2.new(0, 110, 0, 16)
        qProgText.TextXAlignment = Enum.TextXAlignment.Right
        qProgText.BackgroundTransparency = 1
        qProgText.ZIndex = 5

        local qBarBg = Instance.new("Frame", qRow)
        qBarBg.Size = UDim2.new(1, -16, 0, 5)
        qBarBg.Position = UDim2.new(0, 8, 0, 22)
        qBarBg.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
        qBarBg.BorderSizePixel = 0
        qBarBg.ZIndex = 5
        Instance.new("UICorner", qBarBg).CornerRadius = UDim.new(0, 3)

        local qBarFill = Instance.new("Frame", qBarBg)
        qBarFill.Size = UDim2.new(0, 0, 1, 0)
        qBarFill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
        qBarFill.BorderSizePixel = 0
        qBarFill.ZIndex = 6
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

    -- Dummy TargetRankLabel & StarBarFill để main.lua update không ném nil
    local dummyTarget = Instance.new("TextLabel")
    uiElements.TargetRankLabel = dummyTarget
    local dummyFill = Instance.new("Frame")
    uiElements.StarBarFill = dummyFill

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
            origUptimeText = tostring(v):gsub("^[⏱️%s]+", "")
            UptimeLabel.Text = string.format("Running %s • %d FPS", origUptimeText, currentFPS)
        else
            UptimeLabel[k] = v
        end
    end
    uiElements.UptimeLabel = uptimeProxy
    uiElements.ElapsedLabel = uptimeProxy

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

-- createKizHub dùng chung chuẩn Frost Card hoàn hảo
function DashboardGui.createKizHub(config)
    return DashboardGui.create(config)
end

return DashboardGui
