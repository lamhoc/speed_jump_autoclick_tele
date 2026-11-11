-- =========================================================================
-- dump_combine.lua
-- Script chuyên sâu dump dữ liệu máy Combine-o-Matic & Combine Egg
-- Dành cho Delta Mobile & PC: Tự động copy vào Clipboard + Lưu file workspace
-- =========================================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local logs = {}
local function log(fmt, ...)
    local str = string.format(fmt, ...)
    table.insert(logs, str)
    print("[COMBINE-DUMP] " .. str)
end

log("========== BẮT ĐẦU DUMP DỮ LIỆU COMBINE-O-MATIC ==========")
log("PlaceId: %s | JobId: %s | Player: %s", tostring(game.PlaceId), tostring(game.JobId), tostring(LP and LP.Name))

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok then return res end
    return nil
end

local function dumpKeys(tbl, maxDepth, depth)
    if type(tbl) ~= "table" then return tostring(tbl) end
    depth = depth or 1
    maxDepth = maxDepth or 2
    if depth > maxDepth then return "{...}" end

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

-- ================= 1. QUÉT REPLICATEDSTORAGE.LIBRARY.DIRECTORY =================
log("\n--- [1] QUÉT THƯ MỤC DIRECTORY TRONG REPLICATEDSTORAGE ---")
local dirFolder = RS:FindFirstChild("Library") and RS.Library:FindFirstChild("Directory")
if dirFolder then
    local dirChildren = {}
    for _, child in ipairs(dirFolder:GetChildren()) do
        table.insert(dirChildren, child.Name)
    end
    table.sort(dirChildren)
    log("Tất cả Module trong Directory (%d): %s", #dirChildren, table.concat(dirChildren, ", "))

    -- Tìm các module liên quan tới Crafting / Combine / Machines
    for _, child in ipairs(dirFolder:GetChildren()) do
        local nl = child.Name:lower()
        if nl:find("craft") or nl:find("combine") or nl:find("machine") or nl:find("halloween") or nl:find("forge") then
            log("\n>>> Đọc chi tiết Module: %s (%s)", child.Name, child.ClassName)
            local modData = safeRequire(child)
            if type(modData) == "table" then
                log("  Keys: %s", dumpKeys(modData, 1))
                for k, v in pairs(modData) do
                    log("  [%s] (type %s)", tostring(k), type(v))
                    if type(v) == "table" then
                        log("    Sub-keys: %s", dumpKeys(v, 1))
                        if type(v.Recipes) == "table" then
                            log("    -> TÌM THẤY BẢNG RECIPES (%d công thức) trong [%s]:", #v.Recipes, tostring(k))
                            for idx, r in ipairs(v.Recipes) do
                                local rName = "?"
                                if type(r) == "table" and r.Result then
                                    pcall(function()
                                        if type(r.Result.GetId) == "function" then
                                            rName = tostring(r.Result:GetId() or "")
                                        elseif r.Result.Id then
                                            rName = tostring(r.Result.Id)
                                        elseif r.Result.Name then
                                            rName = tostring(r.Result.Name)
                                        else
                                            rName = dumpKeys(r.Result, 1)
                                        end
                                    end)
                                end
                                local ingList = {}
                                if type(r) == "table" and type(r.Ingredients) == "table" then
                                    for _, ing in ipairs(r.Ingredients) do
                                        local ingName = "?"
                                        if ing.Item then
                                            pcall(function()
                                                if type(ing.Item.GetId) == "function" then
                                                    ingName = tostring(ing.Item:GetId() or "")
                                                elseif ing.Item.Id then
                                                    ingName = tostring(ing.Item.Id)
                                                else
                                                    ingName = tostring(ing.Item)
                                                end
                                            end)
                                        end
                                        table.insert(ingList, string.format("%s x%s", ingName, tostring(ing.Amount or 1)))
                                    end
                                end
                                log("      Công thức #%d: Tên='%s' | Yêu cầu: [%s] | Duration=%s | Hidden=%s",
                                    idx, tostring(rName), table.concat(ingList, ", "), tostring(r.Duration), tostring(r.Hidden))
                            end
                        end
                    end
                end
            else
                log("  require() không trả về table (kết quả: %s)", tostring(modData))
            end
        end
    end
else
    log("KHÔNG TÌM THẤY ReplicatedStorage.Library.Directory!")
end

-- ================= 2. QUÉT WORKSPACE CHO MÁY COMBINE-O-MATIC =================
log("\n--- [2] QUÉT MÁY TRONG WORKSPACE ---")
local things = workspace:FindFirstChild("__THINGS")
local instCont = things and things:FindFirstChild("__INSTANCE_CONTAINER")
local activeInst = instCont and instCont:FindFirstChild("Active")
if activeInst then
    log("Active Instances: %s", dumpKeys(activeInst:GetChildren(), 1))
    for _, inst in ipairs(activeInst:GetChildren()) do
        log("Kiểm tra Instance: %s", inst.Name)
        local inter = inst:FindFirstChild("INTERACT")
        local machs = inter and inter:FindFirstChild("Machines")
        if machs then
            local machNames = {}
            for _, m in ipairs(machs:GetChildren()) do
                table.insert(machNames, m.Name)
            end
            log("  Máy trong %s/INTERACT/Machines: %s", inst.Name, table.concat(machNames, ", "))
            for _, m in ipairs(machs:GetChildren()) do
                local ml = m.Name:lower()
                if ml:find("combine") or ml:find("craft") or ml:find("matic") or ml:find("pet") then
                    log("  >>> Chi tiết máy: %s (Class: %s)", m.Name, m.ClassName)
                    local attrs = m:GetAttributes()
                    local attrList = {}
                    for ak, av in pairs(attrs) do table.insert(attrList, string.format("%s=%s", ak, tostring(av))) end
                    log("      Attributes: %s", table.concat(attrList, ", "))
                    local children = {}
                    for _, c in ipairs(m:GetChildren()) do table.insert(children, string.format("%s (%s)", c.Name, c.ClassName)) end
                    log("      Children: %s", table.concat(children, ", "))
                end
            end
        else
            log("  Không thấy INTERACT/Machines trong %s", inst.Name)
        end
    end
else
    log("Không tìm thấy __INSTANCE_CONTAINER.Active trong workspace!")
end

-- ================= 3. QUÉT REMOTES LIÊN QUAN TRONG NETWORK =================
log("\n--- [3] QUÉT REMOTES LIÊN QUAN TRONG REPLICATEDSTORAGE.NETWORK ---")
local net = RS:FindFirstChild("Network")
if net then
    local remotesFound = {}
    for _, child in ipairs(net:GetChildren()) do
        local nl = child.Name:lower()
        if nl:find("craft") or nl:find("combine") or nl:find("forge") or nl:find("halloween") or nl:find("egg") then
            table.insert(remotesFound, string.format("[%s] %s", child.ClassName, child.Name))
        end
    end
    table.sort(remotesFound)
    log("Tìm thấy %d remotes:", #remotesFound)
    for _, r in ipairs(remotesFound) do
        log("  %s", r)
    end
end

-- ================= 4. QUÉT PLAYERGUI CHO GIAO DIỆN COMBINE =================
log("\n--- [4] QUÉT PLAYERGUI TÌM GIAO DIỆN COMBINE-O-MATIC ---")
if LP and LP:FindFirstChild("PlayerGui") then
    local pgui = LP.PlayerGui
    local foundGuis = {}
    for _, g in ipairs(pgui:GetChildren()) do
        local gl = g.Name:lower()
        if gl:find("combine") or gl:find("craft") or gl:find("matic") or gl:find("halloween") then
            table.insert(foundGuis, g.Name)
            log("  Tìm thấy Gui: %s (Enabled=%s)", g.Name, tostring(g.Enabled))
            -- Quét các text trong GUI
            for _, desc in ipairs(g:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text ~= "" then
                    log("    [%s] '%s' (Text: '%s')", desc.ClassName, desc.Name, desc.Text)
                end
            end
        end
    end
    if #foundGuis == 0 then
        log("  Hiện tại không có GUI Combine nào đang mở trong PlayerGui")
    end
end

-- ================= HOÀN TẤT & LƯU =================
log("\n========== HOÀN TẤT DUMP COMBINE ==========")
local fullDump = table.concat(logs, "\n")

-- 1. Lưu file workspace
if type(writefile) == "function" then
    pcall(writefile, "combine_dump.txt", fullDump)
    pcall(function()
        if type(makefolder) == "function" and not (type(isfolder) == "function" and isfolder("PS99_KizHub")) then
            pcall(makefolder, "PS99_KizHub")
        end
        writefile("PS99_KizHub/combine_dump.txt", fullDump)
    end)
    log("[COMBINE-DUMP] Đã lưu file: workspace/combine_dump.txt")
end

-- 2. Đưa vào Clipboard
local clipOk = false
if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, fullDump)
    if ok then clipOk = true end
elseif type(toclipboard) == "function" then
    local ok = pcall(toclipboard, fullDump)
    if ok then clipOk = true end
end
if clipOk then
    log("[COMBINE-DUMP] ĐÃ COPY TOÀN BỘ VÀO CLIPBOARD!")
end

-- 3. Tạo GUI Copy trên màn hình
pcall(function()
    local gName = "KizHub_CombineDump_GUI"
    local prev = LP.PlayerGui:FindFirstChild(gName)
    if prev then prev:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = gName
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 360, 0, 220)
    frame.Position = UDim2.new(0.5, -180, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 255, 150)
    stroke.Thickness = 1.5

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 32)
    title.Text = "COMBINE-O-MATIC DUMP HOÀN TẤT"
    title.TextColor3 = Color3.fromRGB(0, 255, 150)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.BackgroundTransparency = 1

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -20, 0, 50)
    status.Position = UDim2.new(0, 10, 0, 35)
    status.Text = clipOk and "✔ ĐÃ TỰ ĐỘNG COPY VÀO CLIPBOARD!\n(Đã lưu file workspace/combine_dump.txt)"
                          or "Đã lưu file workspace/combine_dump.txt\nNhấn nút Copy bên dưới để copy log!"
    status.TextColor3 = Color3.fromRGB(220, 220, 220)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextWrapped = true
    status.BackgroundTransparency = 1

    local btnCopy = Instance.new("TextButton", frame)
    btnCopy.Size = UDim2.new(1, -20, 0, 45)
    btnCopy.Position = UDim2.new(0, 10, 0, 95)
    btnCopy.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    btnCopy.Text = "📋 COPY LOG DUMP CHO VANTA"
    btnCopy.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnCopy.Font = Enum.Font.GothamBold
    btnCopy.TextSize = 14
    Instance.new("UICorner", btnCopy).CornerRadius = UDim.new(0, 6)

    btnCopy.MouseButton1Click:Connect(function()
        if type(setclipboard) == "function" then setclipboard(fullDump) end
        btnCopy.Text = "✔ ĐÃ COPY THÀNH CÔNG!"
        btnCopy.BackgroundColor3 = Color3.fromRGB(0, 220, 120)
    end)

    local btnClose = Instance.new("TextButton", frame)
    btnClose.Size = UDim2.new(1, -20, 0, 35)
    btnClose.Position = UDim2.new(0, 10, 0, 150)
    btnClose.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
    btnClose.Text = "ĐÓNG GIAO DIỆN"
    btnClose.TextColor3 = Color3.fromRGB(200, 200, 200)
    btnClose.Font = Enum.Font.Gotham
    btnClose.TextSize = 12
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)

    btnClose.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    sg.Parent = LP:WaitForChild("PlayerGui", 5)
end)

return fullDump
