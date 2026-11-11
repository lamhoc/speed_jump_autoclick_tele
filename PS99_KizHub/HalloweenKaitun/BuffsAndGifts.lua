-- =========================================================================
-- PS99_KizHub/HalloweenKaitun/BuffsAndGifts.lua
-- Module tự động sử dụng Buffs (Trái cây, Bình thuốc, Đồ chơi) & Nhận Free Gifts
-- Tích hợp: Giãn nhịp an toàn, Không spam request, Tiết kiệm CPU
-- =========================================================================

local BuffsAndGifts = {}

-- Dependencies
local Net = nil
local Config = nil

function BuffsAndGifts.init(deps)
    Net = deps.Network
    Config = deps.Config
end

-- Tự động nhận 12 mốc quà Free Gifts định kỳ mỗi 3 phút
function BuffsAndGifts.checkAndClaimFreeGifts(state)
    if not Config.AutoClaimFreeGifts then return end
    local now = os.clock()
    if now < (state.nextClaimGiftsAt or 0) then return end
    state.nextClaimGiftsAt = now + 180 -- Nhận quà mỗi 3 phút, chống spam remote

    pcall(function()
        for i = 1, 12 do
            Net.netInvoke("Redeem Free Gift", i)
            task.wait(0.2)
        end
    end)
end

-- Tự động cắn Fruit, Potion và kích hoạt Toys để tối ưu sức mạnh farm
function BuffsAndGifts.runDelayedBuffs(state)
    local bCfg = Config.AutoBuffs or {
        Fruits = true,
        Potions = true,
        Toys = true,
    }
    local now = os.clock()

    -- 1. Fruits: Tối đa 20 quả/lần theo tên quả
    if bCfg.Fruits and now >= (state.nextFruitAt or 0) then
        state.nextFruitAt = now + 60
        pcall(function()
            local s = Net.getSave()
            local fruits = s and s.Inventory and s.Inventory.Fruit
            if type(fruits) == "table" then
                for _, item in pairs(fruits) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local amt = tonumber(item._am) or 0
                        if amt > 0 then
                            local eatAmt = math.clamp(amt, 1, 20)
                            Net.netFire("Fruits: Consume", item.id, eatAmt)
                            task.wait(0.08)
                        end
                    end
                end
            end
        end)
    end

    -- 2. Potions: Tự cắn Potions (damage, coins, luck, speed, treasure)
    if bCfg.Potions and now >= (state.nextPotionAt or 0) then
        state.nextPotionAt = now + 90
        pcall(function()
            local s = Net.getSave()
            local potions = s and s.Inventory and s.Inventory.Potion
            if type(potions) == "table" then
                local targetTypes = { "damage", "coins", "luck", "lucky", "speed", "treasure" }
                for _, item in pairs(potions) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local lowerId = string.lower(item.id)
                        local matched = false
                        for _, kw in ipairs(targetTypes) do
                            if lowerId:find(kw) then
                                matched = true
                                break
                            end
                        end
                        if matched and (tonumber(item._am) or 0) > 0 then
                            Net.netFire("Potions: Consume", item.id)
                            task.wait(0.08)
                        end
                    end
                end
            end
        end)
    end

    -- 3. Toys: Dùng Toys truyền đúng UID từ Inventory.Misc
    if bCfg.Toys and now >= (state.nextToyAt or 0) then
        state.nextToyAt = now + 180
        pcall(function()
            local s = Net.getSave()
            local misc = s and s.Inventory and s.Inventory.Misc
            if type(misc) == "table" then
                for uid, item in pairs(misc) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local toyUid = item._uid or uid
                        if item.id == "Toy Ball" then
                            Net.netInvoke("ToyBall_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id == "Toy Bone" then
                            Net.netInvoke("ToyBone_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id == "Squeaky Toy" then
                            Net.netInvoke("SqueakyToy_Consume", toyUid)
                            task.wait(0.15)
                        elseif item.id:lower():find("toy") then
                            Net.netInvoke("Consumables_Consume", toyUid)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end)
    end
end

return BuffsAndGifts
