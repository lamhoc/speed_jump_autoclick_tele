-- =========================================================================
-- PS99_KizHub/Shared/EngineOptim.lua
-- Tối ưu hóa triệt để Engine, GPU, RAM và CPU cho hệ thống cày 80+ tài khoản
-- Tích hợp: Cap FPS 5, Dọn rác mô hình 60s, Tắt 3D Rendering, Thu gom Garbage
-- =========================================================================

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local EngineOptim = {}
local isOptimized = false
local gcThreadRunning = false

-- Khóa FPS ở mức tối thiểu để giảm tải CPU
function EngineOptim.setFps(fps)
    fps = tonumber(fps) or 5
    pcall(function()
        if type(setfpscap) == "function" then
            setfpscap(fps)
        end
        if settings and settings().Rendering then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
end

-- Tắt toàn bộ âm thanh trong game
function EngineOptim.muteAllSounds()
    pcall(function()
        SoundService.RespectFilteringEnabled = true
        for _, s in ipairs(game:GetDescendants()) do
            if s:IsA("Sound") then
                s.Volume = 0
                s:Stop()
            end
        end
    end)
end

-- Tối ưu ánh sáng và tắt các hiệu ứng hậu kỳ
function EngineOptim.disableHeavyLighting()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.Technology = Enum.Technology.Compatibility

        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
                v.Enabled = false
            end
        end
    end)
end

-- Dọn sạch hiệu ứng hình ảnh nặng (particles, trails, pet models client, damage numbers, orbs rơi)
-- Lưu ý: Không dùng DescendantAdded listener để tránh memory leak / crash tab khi treo 24/24
function EngineOptim.purgeHeavyVisuals()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    end)

    pcall(function()
        local things = workspace:FindFirstChild("__THINGS")
        if things then
            -- TUYỆT ĐỐI KHÔNG xóa folder Pets hoặc Highlight của Pets (tránh lỗi Infinite yield trên PetCmds và tự tháo pet)
            -- TUYỆT ĐỐI KHÔNG xóa folder Orbs để tránh triệt tiêu ngọc trước khi bot hút kịp
            local dmg = things:FindFirstChild("DamageNumbers")
            if dmg then
                for _, d in ipairs(dmg:GetChildren()) do
                    pcall(function() d:Destroy() end)
                end
            end
        end
        -- Không can thiệp __DEBRIS tránh xung đột locked parent với ArrowPointer3D
    end)
end

-- Dừng toàn bộ animation nhân vật
function EngineOptim.stopAnimations()
    pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local anim = hum and hum:FindFirstChildOfClass("Animator")
        if anim then
            for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
                t:Stop(0)
            end
        end
    end)
end

-- Ẩn toàn bộ người chơi khác để tối ưu CPU / FPS cực đại (Hide Other Players)
local isHidePlayersInstalled = false
function EngineOptim.hideOtherPlayers()
    if isHidePlayersInstalled then return end
    isHidePlayersInstalled = true

    local function hideModel(model)
        if not model or (LocalPlayer and model == LocalPlayer.Character) then return end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = 1
                part.Transparency = 1
                part.CanCollide = false
                part.CastShadow = false
            elseif part:IsA("Decal") then
                part.Transparency = 1
            elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
                part.Enabled = false
            end
        end
    end

    local function onPlayerAdded(p)
        if p == LocalPlayer then return end
        if p.Character then
            hideModel(p.Character)
        end
        p.CharacterAdded:Connect(function(char)
            task.wait(0.2)
            hideModel(char)
            char.DescendantAdded:Connect(function(desc)
                if desc:IsA("BasePart") or desc:IsA("Decal") then
                    pcall(function() desc.Transparency = 1 end)
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                    pcall(function() desc.Enabled = false end)
                end
            end)
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)

    task.spawn(function()
        while isHidePlayersInstalled do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    hideModel(p.Character)
                end
            end
            task.wait(5)
        end
    end)
end

-- Bật / Tắt kết xuất 3D (3D Rendering)
function EngineOptim.set3dRendering(enabled)
    pcall(function()
        if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
            RunService:Set3dRenderingEnabled(enabled)
        end
    end)
end

-- Bắt đầu chu kỳ dọn rác và thu gom bộ nhớ mỗi 60s
function EngineOptim.startMemoryCleanupLoop()
    if gcThreadRunning then return end
    gcThreadRunning = true

    task.spawn(function()
        while gcThreadRunning do
            task.wait(60)
            pcall(EngineOptim.purgeHeavyVisuals)
            pcall(function()
                collectgarbage("collect")
            end)
        end
    end)
end

-- Phục hồi màn hình hiển thị bình thường (3D Rendering ON, FPS 60, bật lại hiệu ứng để theo dõi)
function EngineOptim.restoreNormal(targetFps)
    pcall(function()
        if RunService:IsClient() and type(RunService.Set3dRenderingEnabled) == "function" then
            RunService:Set3dRenderingEnabled(true)
        end
        if type(setfpscap) == "function" then
            setfpscap(tonumber(targetFps) or 60)
        end
    end)
end

-- Áp dụng toàn bộ cấu hình tối ưu một chạm
function EngineOptim.applyAll(targetFps, disable3d)
    if disable3d == false then
        EngineOptim.restoreNormal(targetFps or 60)
        return
    end

    if isOptimized then return end
    isOptimized = true

    EngineOptim.setFps(targetFps or 5)
    EngineOptim.muteAllSounds()
    EngineOptim.disableHeavyLighting()
    EngineOptim.purgeHeavyVisuals()
    EngineOptim.stopAnimations()
    EngineOptim.hideOtherPlayers()
    EngineOptim.set3dRendering(false)
    EngineOptim.startMemoryCleanupLoop()
end

return EngineOptim
