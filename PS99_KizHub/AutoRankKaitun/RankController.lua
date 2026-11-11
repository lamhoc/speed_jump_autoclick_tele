-- =========================================================================
-- PS99_KizHub/AutoRankKaitun/RankController.lua
-- Bộ điều phối và xử lý tiến trình Rank 1 -> 11 World 1 cho Pet Simulator 99
-- Tích hợp: Tính sao, Nhận thưởng mốc, Kế hoạch nhiệm vụ (BuildPlan) & Webhook
-- =========================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RankController = {}

-- Dependencies
local G = nil
local Net = nil
local Config = nil
local RankData = nil
local Webhook = nil
local BestZoneFn = nil
local BestZoneIdFn = nil
local BestZoneNameFn = nil
local BestEggFn = nil
local MaxHatchFn = nil
local HatchAmountFn = nil
local CanHatchEggFn = nil

function RankController.init(deps)
    G = deps.Modules.G
    Net = deps.Network
    Config = deps.Config
    RankData = deps.RankData
    Webhook = deps.Webhook
    BestZoneFn = deps.BestZone
    BestZoneIdFn = deps.BestZoneId
    BestZoneNameFn = deps.BestZoneName
    BestEggFn = deps.BestEgg
    MaxHatchFn = deps.MaxHatch
    HatchAmountFn = deps.HatchAmount
    CanHatchEggFn = deps.CanHatchEgg
end

function RankController.IsSupported(t)
    if RankData.FARM_GOALS[t] then return Config.AutoFarm end
    if RankData.HATCH_GOALS[t] then return Config.AutoHatch end
    if RankData.GOLD_GOALS[t] or RankData.RAINBOW_GOALS[t] then return Config.AutoCraftGoldRainbow end
    if t == RankData.T_UPGRADE_POTION then return Config.AutoUpgradePotions end
    if t == RankData.T_UPGRADE_ENCHANT then return Config.AutoUpgradeEnchants end
    if t == RankData.T_USE_POTION then return Config.AutoUsePotions end
    if t == RankData.T_USE_FRUIT then return Config.AutoUseFruits end
    if t == RankData.T_USE_FLAG then return Config.AutoUseFlags end
    if RankData.EVENT_GOAL_KIND[t] then return Config.AutoSpawnEvents end
    return false
end

function RankController.GoalTitle(raw, parsed)
    if type(raw) == "table" and type(raw.Title) == "string" and raw.Title ~= "" then
        return raw.Title
    end
    local name = RankData.GOAL_TYPE_NAMES[parsed.Type] or ("Type " .. tostring(parsed.Type))
    return string.format("%s (%s/%s)", name, Net.int(parsed.Progress), Net.int(parsed.Amount))
end

function RankController.RankInfo()
    local save = Net.getSave()
    if not (save and type(save) == "table") then return nil end

    local info = {}
    info.rankNumber = tonumber(save.Rank) or 1
    info.stars = tonumber(save.RankStars) or 0
    info.rebirths = tonumber(save.Rebirths) or 0
    info.rankId = Net.isfn(G.RanksUtil, "RankIDFromNumber")
            and Net.gval(G.RanksUtil.RankIDFromNumber, info.rankNumber)
        or nil
    info.rankDir = (info.rankId ~= nil and type(G.Ranks) == "table") and G.Ranks[info.rankId] or nil
    info.title = (info.rankDir and info.rankDir.Title) or tostring(info.rankId or ("Rank " .. info.rankNumber))
    info.rewards = (info.rankDir and type(info.rankDir.Rewards) == "table") and info.rankDir.Rewards or {}

    local total = nil
    if info.rankId ~= nil and Net.isfn(G.RanksUtil, "GetTotalStarsRequired") then
        total = Net.gval(G.RanksUtil.GetTotalStarsRequired, info.rankId)
    end
    if type(total) ~= "number" then
        total = 0
        for _, rw in ipairs(info.rewards) do
            total = total + (tonumber(type(rw) == "table" and rw.StarsRequired) or 0)
        end
    end
    info.totalStars = total
    info.redeemed = type(save.RedeemedRankRewards) == "table" and save.RedeemedRankRewards or {}

    local cnt = 0
    for _, v in pairs(info.redeemed) do
        if v then cnt = cnt + 1 end
    end
    info.redeemedCount = cnt
    info.allRedeemed = #info.rewards > 0 and cnt >= #info.rewards
    info.isMax = Net.isfn(G.RankCmds, "IsMaxRank") and Net.gval(G.RankCmds.IsMaxRank) == true
    info.blockedByZone, info.blockedByRebirth = false, false

    if Net.isfn(G.RankCmds, "IsRankBlockedByZone") then
        local ok, bz, br, zn, rn = Net.gcall(G.RankCmds.IsRankBlockedByZone)
        if ok then
            info.blockedByZone = bz == true
            info.blockedByRebirth = br == true
            info.zoneNumberNeeded = zn
            info.rebirthsNeeded = rn
        end
    end
    return info
end

function RankController.EarnedUnclaimedRewards(info)
    local out = {}
    if not info then return out end
    local cum = 0
    for i, rw in ipairs(info.rewards) do
        cum = cum + (tonumber(type(rw) == "table" and rw.StarsRequired) or 0)
        if cum <= info.stars and info.redeemed[tostring(i)] == nil then
            out[#out + 1] = i
        end
    end
    return out
end

function RankController.ActiveGoals()
    local save = Net.getSave()
    local raw = save and type(save.Goals) == "table" and save.Goals or nil
    if not raw and Net.isfn(G.QuestCmds, "GetActive") then
        raw = Net.gval(G.QuestCmds.GetActive)
    end
    if type(raw) ~= "table" then return {}, {} end

    local list, byType = {}, {}
    for tier, g in pairs(raw) do
        if type(g) == "table" and g.Type and g.Amount then
            local amount = tonumber(g.Amount) or 0
            local progress = tonumber(g.Progress) or 0
            local copy = {
                tier = tier,
                Stars = tonumber(g.Stars) or 0,
                Type = g.Type,
                Amount = amount,
                Progress = progress,
                UID = g.UID,
                remaining = math.max(0, amount - progress),
                PotionTier = g.PotionTier,
                EnchantTier = g.EnchantTier,
                BreakableType = g.BreakableType,
                CurrencyID = g.CurrencyID,
                raw = g,
            }
            copy.title = RankController.GoalTitle(g, copy)
            copy.supported = RankController.IsSupported(copy.Type)
            list[#list + 1] = copy
            byType[copy.Type] = byType[copy.Type] or {}
            table.insert(byType[copy.Type], copy)
        end
    end

    table.sort(list, function(a, b)
        if a.Stars ~= b.Stars then
            return a.Stars > b.Stars
        end
        return tostring(a.tier) < tostring(b.tier)
    end)
    return list, byType
end

function RankController.OnRankUp(info, state)
    for i in pairs(state.PendingClaims or {}) do
        state.Counters.Claimed = (state.Counters.Claimed or 0) + 1
        state.PendingClaims[i] = nil
    end
    state.ClaimedAt = {}
    state.ClaimAttempts = {}
    state.TrackCompleteLoggedRank = nil
    state.TrackCompleteAt = nil
    state.RankUpFiredRank = nil

    local elapsed = math.floor(os.clock() - (state.StartedAt or os.clock()))
    local elapsedStr = string.format("%02dh %02dm %02ds", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
    local bestZName = (BestZoneNameFn and BestZoneNameFn()) or ("Zone #" .. tostring((BestZoneIdFn and BestZoneIdFn()) or "?"))

    if info.rankNumber >= (Config.TargetRank or 11) then
        if not state.Rank11WebhookSent then
            state.Rank11WebhookSent = true
            Webhook.sendWebhook(
                "👑 [KIZHUB • HOÀN THÀNH MỤC TIÊU RANK 11!] 👑",
                string.format(
                    "👤 **Tài khoản:** `%s`\n" ..
                    "🏆 **Rank đạt được:** **Rank %d - %s**\n" ..
                    "🗺️ **Khu vực:** World 1 (`%s`)\n" ..
                    "⏱️ **Thời gian cày:** `%s`\n" ..
                    "⭐ **Tổng sao tích lũy:** `%s Stars`\n" ..
                    "🎁 **Phần thưởng đã nhận:** `%d`\n" ..
                    "🥚 **Trứng đã mở:** `%s`\n" ..
                    "⚡ Kaitun World 1 hoàn tất xuất sắc!",
                    LocalPlayer.Name,
                    info.rankNumber,
                    tostring(info.title),
                    bestZName,
                    elapsedStr,
                    Net.int(info.stars),
                    info.redeemedCount or 0,
                    Net.int(state.Counters and state.Counters.Hatched or 0)
                ),
                0xFFD700,
                Config.Webhook and Config.Webhook.Url
            )
        end
    elseif Config.Webhook and Config.Webhook.NotifyEveryRank then
        Webhook.sendWebhook(
            "🎉 [KIZHUB • LÊN RANK THÀNH CÔNG!] 🎉",
            string.format(
                "👤 **Tài khoản:** `%s`\n" ..
                "📈 **Rank mới:** **Rank %d - %s**\n" ..
                "🎯 **Mục tiêu:** Rank %d (Còn %d rank)\n" ..
                "🗺️ **Khu vực:** World 1 (`%s`)\n" ..
                "⏱️ **Thời gian:** `%s`\n" ..
                "⭐ **Stars hiện tại:** `%s / %s`",
                LocalPlayer.Name,
                info.rankNumber,
                tostring(info.title),
                Config.TargetRank or 11,
                math.max(0, (Config.TargetRank or 11) - info.rankNumber),
                bestZName,
                elapsedStr,
                Net.int(info.stars),
                Net.int(info.totalStars)
            ),
            0x00E5BE,
            Config.Webhook and Config.Webhook.Url
        )
    end
end

function RankController.ClaimRewards(info, state)
    if not Config.AutoClaimRewards or not info then return end
    state.PendingClaims = state.PendingClaims or {}
    state.ClaimAttempts = state.ClaimAttempts or {}
    state.ClaimedAt = state.ClaimedAt or {}
    state.Counters = state.Counters or { Claimed = 0 }

    for i in pairs(state.PendingClaims) do
        if info.redeemed[tostring(i)] ~= nil then
            state.Counters.Claimed = state.Counters.Claimed + 1
            state.PendingClaims[i] = nil
        end
    end

    local unclaimed = RankController.EarnedUnclaimedRewards(info)
    if #unclaimed == 0 then return end

    local now = os.clock()
    for _, i in ipairs(unclaimed) do
        local attempts = state.ClaimAttempts[i] or 0
        local last = state.ClaimedAt[i] or 0
        local retry = (attempts >= 6) and 60 or 2
        if now - last >= retry then
            state.ClaimAttempts[i] = attempts + 1
            state.ClaimedAt[i] = now
            state.PendingClaims[i] = true
            local ok, err = Net.netInvoke("Ranks_ClaimReward", i)
            if ok then
                task.wait(0.3)
            end
        end
    end
end

function RankController.CheckTrackComplete(info, state)
    if not info or info.isMax then return end
    if not (info.allRedeemed and info.stars >= info.totalStars) then return end
    if info.blockedByZone or info.blockedByRebirth then return end

    if state.TrackCompleteLoggedRank ~= info.rankNumber then
        state.TrackCompleteLoggedRank = info.rankNumber
        state.TrackCompleteAt = os.clock()
    end
end

function RankController.BuildPlan(state)
    local info = state.Rank
    local Plan = {
        Hatch = false,
        HatchReasons = {},
        HatchEggOnly = true,
        HatchRemaining = nil,
        Crafting = false,
        WaitingChest = false,
    }
    local parts = {}
    local zone = BestZoneFn and BestZoneFn() or nil

    if state.WorldSwitching then
        state.Plan = Plan
        state.Action = string.format("teleporting to World %s", tostring(zone and zone.WorldNumber or "?"))
        return
    end

    if state.WorldMismatch then
        parts[#parts + 1] = string.format("wrong world (best zone is in World %s)", tostring(zone and zone.WorldNumber or "?"))
    elseif info and info.isMax then
        parts[#parts + 1] = "max rank reached"
    elseif Config.AutoFarm then
        local s = string.format(
            "Farming %s (%s pets / %s targets)",
            tostring((BestZoneNameFn and BestZoneNameFn()) or "Zone"),
            Net.int(state.FarmPets or 0),
            Net.int(state.FarmTargets or 0)
        )
        parts[#parts + 1] = s
    end

    for _, goal in ipairs(state.Goals or {}) do
        local t = goal.Type
        if goal.remaining > 0 then
            if RankData.HATCH_GOALS[t] and Config.AutoHatch then
                Plan.Hatch = true
                table.insert(Plan.HatchReasons, RankData.GOAL_TYPE_NAMES[t] or tostring(t))
                if RankData.EGG_COUNT_GOALS[t] then
                    Plan.HatchRemaining = math.max(Plan.HatchRemaining or 0, goal.remaining)
                else
                    Plan.HatchEggOnly = false
                end
            elseif (RankData.GOLD_GOALS[t] or RankData.RAINBOW_GOALS[t]) and Config.AutoCraftGoldRainbow then
                Plan.Crafting = true
                parts[#parts + 1] = string.format(
                    "%s %s/%s",
                    RankData.GOLD_GOALS[t] and "gold crafting" or "rainbow crafting",
                    Net.int(goal.Progress),
                    Net.int(goal.Amount)
                )
            end
        end
    end

    -- Logic NewZoneHatch: Khi đi đến map mới, tự động mở egg tại map đó 3 phút, sau đó tích coin đợi mở map tiếp theo
    local currentZoneId = BestZoneIdFn and BestZoneIdFn() or nil
    local nzCfg = Config.NewZoneHatch
    if nzCfg and nzCfg.Enabled ~= false and currentZoneId and type(currentZoneId) == "string" then
        state.ZoneHatchDone = state.ZoneHatchDone or {}
        if not state.ZoneHatchDone[currentZoneId] then
            if not state.NewZoneHatchSession or state.NewZoneHatchSession.ZoneId ~= currentZoneId then
                state.NewZoneHatchSession = {
                    ZoneId = currentZoneId,
                    StartedAt = os.clock(),
                    Duration = tonumber(nzCfg.Duration) or 180,
                }
            end

            local elapsed = os.clock() - state.NewZoneHatchSession.StartedAt
            local remainingSec = math.max(0, math.ceil(state.NewZoneHatchSession.Duration - elapsed))
            if remainingSec > 0 then
                Plan.Hatch = true
                Plan.HatchEggOnly = true
                Plan.NewZoneSession = true
                table.insert(Plan.HatchReasons, string.format("New Zone Egg (%ds left)", remainingSec))
                parts[#parts + 1] = string.format("Hatching New Zone %s (%ds)", currentZoneId, remainingSec)
            else
                state.ZoneHatchDone[currentZoneId] = true
                state.NewZoneHatchSession = nil
            end
        end
    end

    state.Plan = Plan
    state.Action = #parts > 0 and table.concat(parts, " | ") or "idle"
end

function RankController.ControllerTick(state)
    local info = RankController.RankInfo()
    if info then
        state.Rank = info
        if state.LastRank ~= nil and info.rankNumber ~= state.LastRank then
            RankController.OnRankUp(info, state)
        end
        state.LastRank = info.rankNumber
    end

    local goals, byType = RankController.ActiveGoals()
    state.Goals = goals
    state.GoalsByType = byType

    if not state.Enabled then
        state.Plan = { Hatch = false, HatchReasons = {}, HatchEggOnly = false, HatchRemaining = nil }
        state.Action = "automation paused"
        return
    end

    pcall(RankController.ClaimRewards, info, state)
    pcall(RankController.CheckTrackComplete, info, state)
    RankController.BuildPlan(state)
end

return RankController
