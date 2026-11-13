-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/SpyCombine.lua
-- Công cụ giám sát thời gian thực & Dump dữ liệu sự kiện Halloween PS99
-- Tác giả: VANTA [JHON369] | Dành riêng cho dj
-- Chức năng:
-- 1. Bắt trọn gói mọi RemoteFunction / RemoteEvent khi ấn Craft Combine Egg
-- 2. Bắt chi tiết nút GUI được click (Tên, Text, Vị trí X/Y trái/phải, Đường dẫn)
-- 3. Dump toàn bộ Game Data (Directory, Recipes, Model Máy, Tọa độ, Queue, Inventory)
-- 4. Tự động sao chép mã lệnh thực thi vào Clipboard
-- =========================================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Kiểm tra hỗ trợ Executor
local setclip = setclipboard or toclipboard or (Clipboard and Clipboard.set) or function() end
local getgenvFn = (type(getgenv) == "function" and getgenv) or function() return _G end

-- Gỡ bỏ phiên bản cũ nếu đang chạy
if getgenvFn()._HalloweenSpyGui then
    pcall(function() getgenvFn()._HalloweenSpyGui:Destroy() end)
    getgenvFn()._HalloweenSpyGui = nil
end

-- =========================================================================
-- 1. TẠO GIAO DIỆN SPY UI NỔI TRÊN MÀN HÌNH
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KizHub_HalloweenSpy"
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
MainFrame.Size = UDim2.new(0, 480, 0, 360)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(168, 85, 247) -- Tím Halloween neon
Stroke.Thickness = 1.5

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(22, 27, 40)
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Text = "🔮 KizHub | Halloween Combine Spy & Dumper"
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
CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 24, 34)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Status Box
local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Name = "StatusLabel"
StatusLabel.Text = "📡 Trạng thái: Đang theo dõi... Hãy tới máy và tự ấn nút Craft!"
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
LogScroll.Size = UDim2.new(1, -24, 1, -120)
LogScroll.BackgroundColor3 = Color3.fromRGB(8, 11, 18)
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
BtnContainer.Position = UDim2.new(0, 12, 1, -44)
BtnContainer.Size = UDim2.new(1, -24, 0, 34)
BtnContainer.BackgroundTransparency = 1

local function createBtn(text, xPos, width, color, callback)
    local btn = Instance.new("TextButton", BtnContainer)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(248, 250, 252)
    btn.BackgroundColor3 = color
    btn.Position = UDim2.new(0, xPos, 0, 0)
    btn.Size = UDim2.new(0, width, 1, 0)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local lastCapturedText = ""

local function addLog(text, color)
    print("[HalloweenSpy] " .. text)
    lastCapturedText = text

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

    -- Giới hạn số dòng tối đa 100
    local children = LogScroll:GetChildren()
    if #children > 102 then
        children[3]:Destroy()
    end
    task.defer(function()
        LogScroll.CanvasPosition = Vector2.new(0, 999999)
    end)
end

-- =========================================================================
-- 2. HÀM DUMP DỮ LIỆU SỰ KIỆN HALLOWEEN TOÀN DIỆN
-- =========================================================================
local function dumpHalloweenData()
    addLog("=== BẮT ĐẦU DUMP DỮ LIỆU SỰ KIỆN HALLOWEEN ===", Color3.fromRGB(250, 204, 21))
    local dumpResult = {}
    table.insert(dumpResult, "==================================================")
    table.insert(dumpResult, "PET SIMULATOR 99 - HALLOWEEN EVENT DATA DUMP")
    table.insert(dumpResult, "Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(dumpResult, "Player: " .. LocalPlayer.Name)
    table.insert(dumpResult, "==================================================\n")

    -- 2.1 Quét Save Data (Save.InstanceVars & Inventory)
    pcall(function()
        local Library = nil
        pcall(function() Library = require(RS:WaitForChild("Library", 3)) end)
        if not Library then
            pcall(function() Library = require(RS:WaitForChild("LibraryClient", 3):WaitForChild("Library", 3)) end)
        end

        local Save = nil
        if Library and Library.Save and type(Library.Save.Get) == "function" then
            Save = Library.Save.Get()
        end

        if Save then
            table.insert(dumpResult, "[1. SAVE DATA]")
            table.insert(dumpResult, "- MaximumZone: " .. tostring(Save.MaximumZone))
            if Save.HalloweenCraftingQueue then
                table.insert(dumpResult, "- HalloweenCraftingQueue: " .. HttpService:JSONEncode(Save.HalloweenCraftingQueue))
            end
            if Save.InstanceVars and Save.InstanceVars.HalloweenGames then
                table.insert(dumpResult, "- InstanceVars.HalloweenGames: " .. HttpService:JSONEncode(Save.InstanceVars.HalloweenGames))
            end

            -- Quét Shards & Agony trong Save.Inventory
            local agonyCount = 0
            local shardCount = 0
            if Save.Inventory then
                if type(Save.Inventory.Pet) == "table" then
                    for uid, p in pairs(Save.Inventory.Pet) do
                        if type(p) == "table" and type(p.id) == "string" and p.id:lower():find("agony") then
                            agonyCount = agonyCount + (tonumber(p._am) or 1)
                        end
                    end
                end
                for _, folderName in ipairs({ "Misc", "Currency", "Item" }) do
                    if type(Save.Inventory[folderName]) == "table" then
                        for _, it in pairs(Save.Inventory[folderName]) do
                            if type(it) == "table" and type(it.id) == "string" and it.id:lower():find("shard") then
                                shardCount = shardCount + (tonumber(it._am) or 1)
                            end
                        end
                    end
                end
            end
            table.insert(dumpResult, string.format("- Inventory Shards: %d | Agony Pets: %d\n", shardCount, agonyCount))
        end

        -- 2.2 Quét Directory (HalloweenCraftingMachines)
        local Dir = (Library and Library.Directory) or nil
        if Dir then
            table.insert(dumpResult, "[2. DIRECTORY CRAFTING MACHINES]")
            local craftMachines = rawget(Dir, "HalloweenCraftingMachines") or rawget(Dir, "CraftingMachines")
            if type(craftMachines) == "table" then
                for machKey, machData in pairs(craftMachines) do
                    table.insert(dumpResult, string.format("Machine Key: %s (Type: %s)", tostring(machKey), tostring(machData._id or "N/A")))
                    if type(machData.Recipes) == "table" then
                        table.insert(dumpResult, string.format("  -> Total Recipes: %d", #machData.Recipes))
                        for idx, rec in ipairs(machData.Recipes) do
                            local resId = (rec.Result and type(rec.Result.GetId) == "function" and rec.Result:GetId()) or tostring(rec.Result)
                            table.insert(dumpResult, string.format("  [Recipe #%d]: %s", idx, tostring(resId)))
                            if type(rec.Ingredients) == "table" then
                                for ingIdx, ing in ipairs(rec.Ingredients) do
                                    local ingId = (ing.Item and type(ing.Item.GetId) == "function" and ing.Item:GetId()) or tostring(ing.Item)
                                    local ingAmt = tostring(ing.Amount or ing.AmountFFlag or "?")
                                    table.insert(dumpResult, string.format("    - Ing #%d: %s (Amount: %s)", ingIdx, tostring(ingId), ingAmt))
                                end
                            end
                        end
                    end
                end
            else
                table.insert(dumpResult, "  Không tìm thấy bảng HalloweenCraftingMachines trong Directory!\n")
            end
        end

        -- 2.3 Quét Models trong Workspace
        table.insert(dumpResult, "\n[3. WORKSPACE MACHINES MODELS]")
        local foundModels = 0
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local nl = desc.Name:lower()
                if nl:find("craft") or nl:find("combine") or nl:find("halloween") then
                    foundModels = foundModels + 1
                    local cf = desc:GetPivot()
                    table.insert(dumpResult, string.format("- Model: %s | Class: %s | Pos: %s", desc:GetFullName(), desc.ClassName, tostring(cf.Position)))
                    for _, child in ipairs(desc:GetChildren()) do
                        if child:IsA("ProximityPrompt") then
                            table.insert(dumpResult, string.format("  * Has ProximityPrompt: %s (ActionText: %s)", child.Name, child.ActionText))
                        elseif child.Name == "Pad" then
                            table.insert(dumpResult, string.format("  * Has Pad at: %s", tostring(child.Position)))
                        end
                    end
                end
            end
        end
        if foundModels == 0 then
            table.insert(dumpResult, "  Không tìm thấy model máy nào trong Workspace!")
        end
    end)

    table.insert(dumpResult, "\n==================================================")
    table.insert(dumpResult, "DUMP HOÀN TẤT - ĐÃ COPY TOÀN BỘ VÀO CLIPBOARD!")
    table.insert(dumpResult, "==================================================")

    local fullDumpText = table.concat(dumpResult, "\n")
    setclip(fullDumpText)
    addLog("ĐÃ DUMP XONG! Toàn bộ data sự kiện đã được copy vào Clipboard.", Color3.fromRGB(52, 211, 153))
    StatusLabel.Text = "✅ Dump thành công! Dữ liệu đã lưu vào Clipboard."
end

-- =========================================================================
-- 3. HOOK THEO DÕI REMOTES (InvokeServer & FireServer)
-- =========================================================================
pcall(function()
    local oldNamecall = nil
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if method == "InvokeServer" or method == "FireServer" then
            local rName = tostring(self.Name)
            local rLower = rName:lower()

            -- Lọc các remote liên quan tới sự kiện Halloween, Craft, Machine, Combine, Egg, v.v.
            local isRelevant = rLower:find("craft") or rLower:find("combine") or rLower:find("halloween")
                or rLower:find("machine") or rLower:find("egg") or rLower:find("start") or rLower:find("claim")
                or rLower:find("forge")

            if isRelevant then
                local formattedArgs = {}
                for i, arg in ipairs(args) do
                    local t = type(arg)
                    if t == "string" then
                        table.insert(formattedArgs, string.format("%q", arg))
                    elseif t == "number" or t == "boolean" then
                        table.insert(formattedArgs, tostring(arg))
                    elseif t == "table" then
                        pcall(function() table.insert(formattedArgs, HttpService:JSONEncode(arg)) end)
                    else
                        table.insert(formattedArgs, string.format("<%s>", tostring(arg)))
                    end
                end

                local callStr = string.format("[%s] %s:%s(%s)", method, rName, method, table.concat(formattedArgs, ", "))
                addLog(callStr, Color3.fromRGB(244, 114, 182))
                StatusLabel.Text = "🎯 Bắt được: " .. rName

                -- Tự động copy câu lệnh chuẩn vào Clipboard
                pcall(function()
                    setclip(string.format("[Remote] %s:%s(%s)", rName, method, table.concat(formattedArgs, ", ")))
                end)
            end
        end

        return oldNamecall(self, ...)
    end)
    addLog("✓ Đã cài đặt Hook __namecall RemoteSpy", Color3.fromRGB(56, 189, 248))
end)

-- Hook tầng 2: Network module nội bộ của Pet Simulator 99
task.spawn(function()
    pcall(function()
        local Library = nil
        pcall(function() Library = require(RS:WaitForChild("Library", 3)) end)
        if not Library then
            pcall(function() Library = require(RS:WaitForChild("LibraryClient", 3):WaitForChild("Library", 3)) end)
        end
        local Net = Library and Library.Network
        if Net then
            if type(Net.Invoke) == "function" then
                local origInvoke = Net.Invoke
                Net.Invoke = function(name, ...)
                    local args = { ... }
                    local nLower = tostring(name):lower()
                    if nLower:find("craft") or nLower:find("combine") or nLower:find("halloween") or nLower:find("machine") then
                        addLog(string.format("[Network.Invoke] %s (args: %s)", tostring(name), HttpService:JSONEncode(args)), Color3.fromRGB(192, 132, 252))
                    end
                    return origInvoke(name, ...)
                end
            end
            if type(Net.Fire) == "function" then
                local origFire = Net.Fire
                Net.Fire = function(name, ...)
                    local args = { ... }
                    local nLower = tostring(name):lower()
                    if nLower:find("craft") or nLower:find("combine") or nLower:find("halloween") or nLower:find("machine") then
                        addLog(string.format("[Network.Fire] %s (args: %s)", tostring(name), HttpService:JSONEncode(args)), Color3.fromRGB(167, 139, 250))
                    end
                    return origFire(name, ...)
                end
            end
            addLog("✓ Đã cài đặt Hook PS99 Library.Network", Color3.fromRGB(56, 189, 248))
        end
    end)
end)

-- =========================================================================
-- 4. THEO DÕI NÚT GUI ĐƯỢC CLICK (Xác định nút bên trái hay bên phải)
-- =========================================================================
pcall(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = UserInputService:GetMouseLocation()
            task.defer(function()
                pcall(function()
                    for _, gui in ipairs(PlayerGui:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "KizHub_HalloweenSpy" then
                            for _, desc in ipairs(gui:GetDescendants()) do
                                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                                    local absPos = desc.AbsolutePosition
                                    local absSize = desc.AbsoluteSize
                                    if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
                                       and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
                                        
                                        local bText = (desc:IsA("TextButton") and desc.Text) or "(ImageButton)"
                                        local side = (desc.Position.X.Scale < 0.5 or desc.AnchorPoint.X < 0.5) and "BÊN TRÁI" or "BÊN PHẢI"
                                        local fullPath = desc:GetFullName()

                                        local clickLog = string.format("[GUI CLICK] Nút: %q | Text: %q | Vị trí: %s (X: %.0f) | Path: %s", desc.Name, bText, side, absPos.X, fullPath)
                                        addLog(clickLog, Color3.fromRGB(250, 204, 21))
                                        StatusLabel.Text = string.format("🖱️ Đã click nút: %s (%s)", desc.Name, side)
                                    end
                                end
                            end
                        end
                    end
                end)
            end)
        end
    end)
    addLog("✓ Đã kích hoạt GUI Button Tracker (Nhận diện click trái/phải)", Color3.fromRGB(56, 189, 248))
end)

-- Hook ProximityPrompt
pcall(function()
    local PPS = game:GetService("ProximityPromptService")
    PPS.PromptTriggered:Connect(function(prompt, player)
        if player == LocalPlayer then
            addLog(string.format("[PROMPT TRIGGER] Object: %s | Action: %s", prompt.Parent and prompt.Parent:GetFullName() or "Unknown", prompt.ActionText), Color3.fromRGB(56, 189, 248))
        end
    end)
end)

-- Tạo các nút bấm điều khiển
createBtn("🚀 Tele Máy", 0, 95, Color3.fromRGB(16, 185, 129), function()
    pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-6721.63, 17.13, -4002.42)
            StatusLabel.Text = "🚀 Đã tới trước mặt máy Combine!"
            addLog("Đã teleport tới Pad máy Combine (-6721.63, 17.13, -4002.42)", Color3.fromRGB(52, 211, 153))
        end
    end)
end)

createBtn("📋 Copy Log", 100, 95, Color3.fromRGB(37, 99, 235), function()
    if lastCapturedText ~= "" then
        setclip(lastCapturedText)
        StatusLabel.Text = "📋 Đã copy log mới nhất vào Clipboard!"
    else
        StatusLabel.Text = "⚠️ Chưa có log nào để copy!"
    end
end)

createBtn("💾 Dump Data", 200, 110, Color3.fromRGB(147, 51, 234), function()
    dumpHalloweenData()
end)

createBtn("🗑️ Xóa Log", 315, 65, Color3.fromRGB(75, 85, 99), function()
    for _, child in ipairs(LogScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    StatusLabel.Text = "📡 Trạng thái: Đang theo dõi..."
end)

createBtn("❌ Tắt UI Máy", 385, 71, Color3.fromRGB(225, 29, 72), function()
    pcall(function()
        local Library = nil
        pcall(function() Library = require(RS.Library) end)
        if Library and Library.TabController and type(Library.TabController.CloseAll) == "function" then
            Library.TabController.CloseAll()
        end
    end)
    StatusLabel.Text = "Đã gọi CloseAll UI máy"
end)

addLog("SẴN SÀNG! Ấn '🚀 Tele Máy' để tới ngay trước mặt máy Combine.", Color3.fromRGB(52, 211, 153))
addLog("Sau đó dj tự tay click nút Craft bên trái, bảng sẽ bắt trọn Remote!", Color3.fromRGB(203, 213, 225))
