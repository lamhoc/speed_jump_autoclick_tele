-- =========================================================================
-- PS99_KizHub/Shared/Webhook.lua
-- Hệ thống thông báo Discord Webhook chuyên dụng cho Pet Simulator 99
-- Tích hợp: Xử lý Rate-Limit 429, Đọc retry_after, Chống nghẽn 80 Acc, Huge Watcher
-- =========================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local WebhookHelper = {}

local knownHugeUids = {}
local isHugeCacheInitialized = false
local defaultWebhookUrl = nil

function WebhookHelper.setDefaultUrl(url)
    defaultWebhookUrl = url
end

-- Gửi Webhook với cơ chế xử lý Rate-Limit 429 & Random Jitter chống spam đồng thời
function WebhookHelper.sendWebhook(title, description, color, customUrl, options)
    local targetUrl = customUrl or defaultWebhookUrl
    if type(targetUrl) ~= "string" or not targetUrl:find("^https://") then
        return false, "Invalid Webhook URL"
    end

    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    if not reqFn then
        return false, "Executor HTTP request function not available"
    end

    local opts = options or {}
    local username = opts.username or "kizhub Notifier"
    local avatarUrl = opts.avatar_url or "https://i.imgur.com/8Y1jE6u.png"
    local footerText = opts.footer or "kizhub • Pet Simulator 99"

    local payload = {
        username = username,
        avatar_url = avatarUrl,
        embeds = { {
            title = title,
            description = description,
            color = color or 0xFFA500,
            footer = { text = footerText },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        } }
    }

    task.spawn(function()
        -- Độ trễ ngẫu nhiên (1-3 giây) giúp phân tán request khi 80 account cùng phát sinh sự kiện
        task.wait(math.random(10, 30) / 10)

        local bodyJson = ""
        local okEncode, resEncode = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okEncode then return end
        bodyJson = resEncode

        for attempt = 1, 3 do
            local ok, res = pcall(reqFn, {
                Url = targetUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = bodyJson
            })

            if ok and type(res) == "table" then
                local code = tonumber(res.StatusCode) or 0
                if code == 200 or code == 204 then
                    break -- Gửi thành công mỹ mãn
                elseif code == 429 then
                    -- Bị Discord Rate Limit: Đọc thời gian phạt retry_after từ Discord
                    local waitSec = 5
                    pcall(function()
                        local data = HttpService:JSONDecode(res.Body)
                        if data and data.retry_after then
                            waitSec = tonumber(data.retry_after) or 5
                        end
                    end)
                    task.wait(waitSec + 1)
                else
                    task.wait(2)
                end
            else
                task.wait(2)
            end
        end
    end)
    return true
end

-- Theo dõi nổ Huge / Titanic Pet mới nở hoặc mới nhận từ máy ghép / quà tặng
function WebhookHelper.checkNewHugeHatched(getSaveFn, eventWebhookUrl)
    if type(getSaveFn) ~= "function" then return end
    local s = getSaveFn()
    local pets = s and s.Inventory and s.Inventory.Pet
    if type(pets) ~= "table" then return end

    local targetUrl = eventWebhookUrl or defaultWebhookUrl

    -- Lần đầu khởi động: Nạp toàn bộ danh sách Pet hiện có vào bộ nhớ đệm để không báo trùng pet cũ
    if not isHugeCacheInitialized then
        for uid, p in pairs(pets) do
            if type(p) == "table" and type(p.id) == "string" then
                local isTitanic = (p.IsTitanic and p:IsTitanic()) or (p.id:find("Titanic ") ~= nil)
                local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))
                if isHuge or isTitanic then
                    knownHugeUids[uid] = true
                end
            end
        end
        isHugeCacheInitialized = true
        return
    end

    -- Quét tìm pet Huge / Titanic mới xuất hiện
    for uid, p in pairs(pets) do
        if type(p) == "table" and type(p.id) == "string" then
            local isTitanic = (p.IsTitanic and p:IsTitanic()) or (p.id:find("Titanic ") ~= nil)
            local isHuge = (p.IsHuge and p:IsHuge()) or (p.id:find("Huge ") and not p.id:find("Huge Hunter"))

            if (isHuge or isTitanic) and not knownHugeUids[uid] then
                knownHugeUids[uid] = true
                local pName = (p.sh and "Shiny " or "") .. (p.pt == 2 and "Rainbow " or p.pt == 1 and "Golden " or "") .. p.id
                local playerName = LocalPlayer and LocalPlayer.Name or "Unknown"

                if isTitanic then
                    -- Nổ Siêu Phẩm Titanic: Embed Tím Cực Hiếm
                    WebhookHelper.sendWebhook(
                        "👑👑 [NỔ SIÊU PHẨM TITANIC THÀNH CÔNG] 👑👑",
                        string.format("Người chơi: **%s**\n🌟 Siêu Phẩm: **%s**\nUID: `%s`", playerName, pName, tostring(uid)),
                        0x9B59B6,
                        targetUrl
                    )
                else
                    -- Nổ Huge: Embed Vàng Hoàng Kim
                    WebhookHelper.sendWebhook(
                        "💥 [NỔ HUGE PET THÀNH CÔNG] 💥",
                        string.format("Người chơi: **%s**\nPet nhận được: **%s**\nUID: `%s`", playerName, pName, tostring(uid)),
                        0xFFD700,
                        targetUrl
                    )
                end
            end
        end
    end
end

return WebhookHelper
