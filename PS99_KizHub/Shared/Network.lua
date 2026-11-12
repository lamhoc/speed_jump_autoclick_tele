-- =========================================================================
-- PS99_KizHub/Shared/Network.lua
-- Wrapper giao tiếp mạng, RemoteFunction / RemoteEvent an toàn cho PS99
-- Tích hợp: Safe Identity, Timeout chống treo luồng, Helper đọc tiền & vị trí
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local IDENTITY_GAME = 2
local IDENTITY_EXEC = 7
local canSetIdentity = type(setthreadidentity) == "function"
if type(getthreadidentity) == "function" then
    local ok, id = pcall(getthreadidentity)
    if ok and type(id) == "number" then
        IDENTITY_EXEC = id
    end
end

local NetworkHelper = {}

-- Safe call hàm với Identity chuẩn của game để bypass kiểm tra nội bộ
function NetworkHelper.gcall(fn, ...)
    if type(fn) ~= "function" then return false, "not a function" end
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_GAME) end
    local r = table.pack(pcall(fn, ...))
    if canSetIdentity then pcall(setthreadidentity, IDENTITY_EXEC) end
    return table.unpack(r, 1, r.n)
end

function NetworkHelper.gval(fn, ...)
    local ok, a, b, c = NetworkHelper.gcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

function NetworkHelper.isfn(t, k)
    return type(t) == "table" and type(t[k]) == "function"
end

-- Khởi tạo binding với Modules.G
local G = nil
function NetworkHelper.bindModules(modulesTable)
    G = modulesTable
end

local function getG()
    if G then return G end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv.KizHub and genv.KizHub.Modules and genv.KizHub.Modules.G then
        G = genv.KizHub.Modules.G
        return G
    end
    return {}
end

-- Network.Invoke an toàn
function NetworkHelper.netInvoke(name, ...)
    local currentG = getG()
    if NetworkHelper.isfn(currentG.Network, "Invoke") then
        return NetworkHelper.gcall(currentG.Network.Invoke, name, ...)
    end
    return false, "Network.Invoke unavailable"
end

-- Network.Invoke có timeout bảo vệ (chống đứng/đơ luồng 24/24 khi server lagg/không phản hồi)
function NetworkHelper.netInvokeTimeout(timeoutSec, name, ...)
    local currentG = getG()
    if not NetworkHelper.isfn(currentG.Network, "Invoke") then
        return false, "Network.Invoke unavailable"
    end

    timeoutSec = tonumber(timeoutSec) or 5
    local done = false
    local result = nil
    local args = table.pack(...)

    task.spawn(function()
        local r = table.pack(NetworkHelper.gcall(currentG.Network.Invoke, name, table.unpack(args, 1, args.n)))
        result = r
        done = true
    end)

    local start = os.clock()
    while not done do
        if os.clock() - start >= timeoutSec then
            done = true
            return false, "Timeout"
        end
        task.wait(0.1)
    end

    if result then
        return table.unpack(result, 1, result.n)
    end
    return false, "No result"
end

-- Network.Fire an toàn
function NetworkHelper.netFire(name, ...)
    local currentG = getG()
    if NetworkHelper.isfn(currentG.Network, "Fire") then
        return NetworkHelper.gcall(currentG.Network.Fire, name, ...)
    end
    return false, "Network.Fire unavailable"
end

-- Network.UnreliableFire an toàn
function NetworkHelper.netUnreliable(name, ...)
    local currentG = getG()
    if NetworkHelper.isfn(currentG.Network, "UnreliableFire") then
        return NetworkHelper.gcall(currentG.Network.UnreliableFire, name, ...)
    end
    return false, "Network.UnreliableFire unavailable"
end

-- Đọc dữ liệu Save của tài khoản
function NetworkHelper.getSave()
    local currentG = getG()
    if NetworkHelper.isfn(currentG.Save, "Get") then
        return NetworkHelper.gval(currentG.Save.Get)
    end
    return nil
end

-- Đọc tiền tệ đa tầng (CurrencyCmds -> s.Currency -> s.Inventory.Currency)
function NetworkHelper.currency(id)
    local currentG = getG()
    if NetworkHelper.isfn(currentG.CurrencyCmds, "Get") then
        local v = NetworkHelper.gval(currentG.CurrencyCmds.Get, id)
        if type(v) == "number" then return v end
    end
    local s = NetworkHelper.getSave()
    if type(s) == "table" then
        if type(s[id]) == "number" then
            return s[id]
        end
        if type(s.Currency) == "table" and type(s.Currency[id]) == "number" then
            return s.Currency[id]
        end
        local cur = s.Inventory and s.Inventory.Currency
        if type(cur) == "table" then
            for _, v in pairs(cur) do
                if type(v) == "table" and (v.id == id or v._id == id) then
                    return tonumber(v._am or v.Amount) or 0
                end
            end
        end
    end
    return 0
end

-- Rút gọn hiển thị số nguyên lớn (K, M, B, T)
function NetworkHelper.shorten(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

-- Định dạng số nguyên
function NetworkHelper.int(x)
    x = tonumber(x) or 0
    return tostring(math.floor(x + 0.5))
end

-- Vị trí nhân vật & Di chuyển
function NetworkHelper.hrp()
    local c = LocalPlayer and LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

function NetworkHelper.playerPos()
    local r = NetworkHelper.hrp()
    return r and r.Position or nil
end

function NetworkHelper.dist(a, b)
    if not (a and b) then return math.huge end
    return (a - b).Magnitude
end

function NetworkHelper.teleportTo(pos)
    local c = LocalPlayer and LocalPlayer.Character
    local r = NetworkHelper.hrp()
    if not (c and r and pos) then return false end
    local safeTarget = pos + Vector3.new(0, 3.5, 0)
    local cf = CFrame.new(safeTarget) * (r.CFrame - r.CFrame.Position)
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end

return NetworkHelper
