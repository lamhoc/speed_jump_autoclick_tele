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
            local pets = things:FindFirstChild("Pets")
            if pets then
                for _, p in ipairs(pets:GetChildren()) do
                    pcall(function() p:Destroy() end)
                end
            end
            local dmg = things:FindFirstChild("DamageNumbers")
            if dmg then
                for _, d in ipairs(dmg:GetChildren()) do
                    pcall(function() d:Destroy() end)
                end
            end
            local orbs = things:FindFirstChild("Orbs")
            if orbs then
                for _, o in ipairs(orbs:GetChildren()) do
                    pcall(function() o:Destroy() end)
                end
            end
        end

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, deb in ipairs(debris:GetChildren()) do
                pcall(function() deb:Destroy() end)
            end
        end
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
    EngineOptim.set3dRendering(false)
    EngineOptim.startMemoryCleanupLoop()
end

return EngineOptim
