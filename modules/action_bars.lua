EZOCombat = EZOCombat or {}
EZOCombat.ActionBars = EZOCombat.ActionBars or {}

local ADDON = EZOCombat
local ActionBars = ADDON.ActionBars

ActionBars.activityStates = ActionBars.activityStates or {}

local function DebugLog(message)
    if ADDON.DebugLog then
        ADDON.DebugLog("[ActionBars] " .. tostring(message))
    end
end

local function ResolveAbilityId(slotIndex, hotbarCategory)
    if type(GetSlotBoundId) ~= "function" then
        return 0
    end

    local ok, slottedId = pcall(GetSlotBoundId, slotIndex, hotbarCategory)
    if not ok or not slottedId then
        if not ok then
            DebugLog(string.format(
                "GetSlotBoundId failed bar=%s slot=%s error=%s",
                tostring(hotbarCategory),
                tostring(slotIndex),
                tostring(slottedId)
            ))
        end
        return 0
    end

    local abilityId = tonumber(slottedId) or 0
    if type(GetSlotType) == "function"
        and type(GetAbilityIdForCraftedAbilityId) == "function"
        and ACTION_TYPE_CRAFTED_ABILITY ~= nil then
        local typeOk, actionType = pcall(GetSlotType, slotIndex, hotbarCategory)
        if typeOk and actionType == ACTION_TYPE_CRAFTED_ABILITY then
            local craftedOk, craftedAbilityId = pcall(GetAbilityIdForCraftedAbilityId, slottedId)
            if craftedOk and craftedAbilityId then
                abilityId = tonumber(craftedAbilityId) or abilityId
            end
        end
    end

    if abilityId ~= 0
        and hotbarCategory ~= nil
        and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        local effectiveOk, effectiveAbilityId = pcall(
            GetEffectiveAbilityIdForAbilityOnHotbar,
            abilityId,
            hotbarCategory
        )
        effectiveAbilityId = tonumber(effectiveAbilityId) or 0
        if effectiveOk and effectiveAbilityId ~= 0 then
            abilityId = effectiveAbilityId
        end
    end

    return abilityId
end

local function GetAbilityDetails(abilityId)
    local name = ""
    local icon = ""
    if abilityId ~= 0 and type(GetAbilityName) == "function" then
        local ok, value = pcall(GetAbilityName, abilityId)
        if ok and value then
            name = zo_strformat("<<C:1>>", value)
        end
    end
    if abilityId ~= 0 and type(GetAbilityIcon) == "function" then
        local ok, value = pcall(GetAbilityIcon, abilityId)
        if ok and value then
            icon = value
        end
    end
    return name, icon
end

local function GetEntriesForAbility(abilityId)
    local matches = {}
    for _, entries in pairs(ActionBars.bars or {}) do
        for _, entry in ipairs(entries) do
            local equivalent = entry.abilityId == abilityId
            if not equivalent
                and ADDON.AbilityState
                and type(ADDON.AbilityState.AreAbilityIdsEquivalent) == "function" then
                equivalent = ADDON.AbilityState.AreAbilityIdsEquivalent(entry.abilityId, abilityId)
            end
            if equivalent then
                matches[#matches + 1] = entry
            end
        end
    end
    return matches
end

local function ActivityStateKey(state)
    if state.active == true then
        return "active"
    end
    if state.active == false then
        return "inactive"
    end
    return "unknown"
end

local function RefreshOverlays(source)
    if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
        DebugLog("evidence refresh source=" .. tostring(source or "unknown"))
    end
    if ADDON.Overlays and type(ADDON.Overlays.Refresh) == "function" then
        ADDON.Overlays.Refresh()
    end
end

local function BuildBarsSignature(bars)
    local parts = {}
    for _, key in ipairs({ "front", "back" }) do
        local ids = {}
        for _, entry in ipairs(bars[key] or {}) do
            ids[#ids + 1] = tostring(entry.abilityId or 0)
        end
        parts[#parts + 1] = key .. "=" .. table.concat(ids, ",")
    end
    return table.concat(parts, "|")
end

local function PollActivityTransitions()
    if not (ADDON.Priority and type(ADDON.Priority.ListTrackers) == "function") then
        return
    end

    local seen = {}
    local changed = false
    for _, tracker in ipairs(ADDON.Priority.ListTrackers()) do
        local abilityId = tonumber(tracker.abilityId) or 0
        if tracker.enabled == true and tracker.condition ~= ADDON.Priority.CONDITION_SLOTTED and abilityId ~= 0 then
            local state = ActionBars.GetAbilityState(abilityId)
            local stateKey = ActivityStateKey(state)
            seen[abilityId] = true
            if ActionBars.activityStates[abilityId] ~= stateKey then
                ActionBars.activityStates[abilityId] = stateKey
                changed = true
                DebugLog(string.format(
                    "activity transition ability=%s state=%s source=%s phase=%s confidence=%s",
                    tostring(abilityId),
                    stateKey,
                    tostring(state.source),
                    tostring(state.phase),
                    tostring(state.confidence)
                ))
            end
        end
    end

    for abilityId in pairs(ActionBars.activityStates) do
        if not seen[abilityId] then
            ActionBars.activityStates[abilityId] = nil
        end
    end

    if changed then
        RefreshOverlays("activity-transition")
    end
end

function ActionBars.GetSlotRange()
    return ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
end

function ActionBars.ResolveAbilityId(slotIndex, hotbarCategory)
    return ResolveAbilityId(slotIndex, hotbarCategory)
end

function ActionBars.Capture()
    local bars = {}
    local categories = {
        { key = "front", category = HOTBAR_CATEGORY_PRIMARY },
        { key = "back", category = HOTBAR_CATEGORY_BACKUP },
    }
    local firstSlot, lastSlot = ActionBars.GetSlotRange()

    for _, bar in ipairs(categories) do
        local entries = {}
        for slotIndex = firstSlot, lastSlot do
            local abilityId = ResolveAbilityId(slotIndex, bar.category)
            local name, icon = GetAbilityDetails(abilityId)
            entries[#entries + 1] = {
                abilityId = abilityId,
                name = name,
                icon = icon,
                hotbar = bar.key,
                hotbarCategory = bar.category,
                slotIndex = slotIndex,
                isUltimate = slotIndex == lastSlot,
            }
        end
        bars[bar.key] = entries
    end
    return bars
end

function ActionBars.Refresh(source)
    local bars = ActionBars.Capture()
    local signature = BuildBarsSignature(bars)
    local barsChanged = ActionBars.barsSignature ~= signature
    ActionBars.bars = bars
    ActionBars.barsSignature = signature
    if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
        local parts = {}
        for key, entries in pairs(ActionBars.bars) do
            local ids = {}
            for _, entry in ipairs(entries) do
                ids[#ids + 1] = tostring(entry.abilityId)
            end
            parts[#parts + 1] = key .. "=" .. table.concat(ids, ",")
        end
        DebugLog(string.format("refresh source=%s %s", tostring(source or "manual"), table.concat(parts, " ")))
    end
    if ADDON.Window and type(ADDON.Window.RefreshBars) == "function" then
        ADDON.Window.RefreshBars()
    end
    if barsChanged
        and ADDON.Settings
        and type(ADDON.Settings.RequestSettingsRefresh) == "function" then
        ADDON.Settings.RequestSettingsRefresh(true)
    end
    RefreshOverlays(source or "bar-refresh")
end

function ActionBars.DebugSnapshot()
    ActionBars.Refresh("debug-snapshot")
    local selected = ADDON.Window and ADDON.Window.selectedEntry
    if selected and (tonumber(selected.abilityId) or 0) ~= 0 then
        local _, detail = ActionBars.GetAbilityActivityDetails(selected.abilityId)
        DebugLog("selected state " .. tostring(detail))
    end
    if ADDON.AbilityState and type(ADDON.AbilityState.DebugSnapshot) == "function" then
        ADDON.AbilityState.DebugSnapshot()
    end
end

function ActionBars.IsAbilitySlotted(abilityId)
    abilityId = tonumber(abilityId) or 0
    return abilityId ~= 0 and #GetEntriesForAbility(abilityId) > 0
end

function ActionBars.GetActiveEntryForAbility(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId == 0 or type(GetActiveHotbarCategory) ~= "function" then
        return nil
    end
    local ok, activeCategory = pcall(GetActiveHotbarCategory)
    if not ok then
        return nil
    end
    for _, entry in ipairs(GetEntriesForAbility(abilityId)) do
        if entry.hotbarCategory == activeCategory then
            return entry
        end
    end
    return nil
end

function ActionBars.GetAbilityState(abilityId)
    abilityId = tonumber(abilityId) or 0
    local entries = GetEntriesForAbility(abilityId)
    if ADDON.AbilityState and type(ADDON.AbilityState.Resolve) == "function" then
        return ADDON.AbilityState.Resolve(abilityId, entries)
    end
    return {
        abilityId = abilityId,
        slotted = #entries > 0,
        active = nil,
        phase = "unknown",
        source = "unknown",
        confidence = "none",
    }
end

function ActionBars.GetAbilityActivity(abilityId)
    return ActionBars.GetAbilityState(abilityId).active
end

function ActionBars.GetAbilityActivityDetails(abilityId)
    abilityId = tonumber(abilityId) or 0
    local state = ActionBars.GetAbilityState(abilityId)
    local name = GetAbilityDetails(abilityId)
    local detail = "name=" .. tostring(name)
    if ADDON.AbilityState and type(ADDON.AbilityState.Describe) == "function" then
        detail = detail .. "; " .. ADDON.AbilityState.Describe(state)
    end
    return state.active, detail, state
end

function ActionBars.Init()
    ActionBars.Refresh("init")
    if EVENT_ACTION_SLOT_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionSlots", EVENT_ACTION_SLOT_UPDATED, function()
            ActionBars.Refresh("action-slot-updated")
        end)
    end
    if EVENT_HOTBAR_SLOT_UPDATED and EVENT_HOTBAR_SLOT_UPDATED ~= EVENT_ACTION_SLOT_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "HotbarSlots", EVENT_HOTBAR_SLOT_UPDATED, function()
            ActionBars.Refresh("hotbar-slot-updated")
        end)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionBar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        ActionBars.Refresh("active-hotbar-updated")
    end)
    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "AllActionBars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
            ActionBars.Refresh("all-hotbars-updated")
        end)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        if ADDON.AbilityState and type(ADDON.AbilityState.RebuildPlayerEffects) == "function" then
            ADDON.AbilityState.RebuildPlayerEffects()
        end
        ActionBars.Refresh("player-activated")
    end)
    if EVENT_ACTION_SLOT_EFFECT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionSlotEffect", EVENT_ACTION_SLOT_EFFECT_UPDATE, function()
            RefreshOverlays("action-slot-effect")
        end)
    end
    if EVENT_ACTION_SLOT_EFFECTS_CLEARED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionSlotEffectsCleared", EVENT_ACTION_SLOT_EFFECTS_CLEARED, function()
            RefreshOverlays("action-slot-effects-cleared")
        end)
    end
    if EVENT_POWER_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "UltimatePower", EVENT_POWER_UPDATE, function(_, unitTag, _, powerType)
            if unitTag == "player" and powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
                RefreshOverlays("ultimate-power")
            end
        end)
    end
    if EVENT_ULTIMATE_ABILITY_COST_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "UltimateCost", EVENT_ULTIMATE_ABILITY_COST_CHANGED, function()
            RefreshOverlays("ultimate-cost")
        end)
    end
    if EVENT_EFFECT_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "PlayerEffects", EVENT_EFFECT_CHANGED, function(
            _, changeType, effectSlot, _, unitTag, beginTime, endTime, stackCount,
            _, _, _, _, _, _, _, abilityId, sourceType
        )
            if unitTag ~= "player" then
                return
            end
            if ADDON.AbilityState and type(ADDON.AbilityState.HandleEffectChanged) == "function" then
                ADDON.AbilityState.HandleEffectChanged(
                    changeType,
                    effectSlot,
                    beginTime,
                    endTime,
                    stackCount,
                    abilityId,
                    sourceType
                )
            end
            RefreshOverlays("player-effect")
        end)
        if REGISTER_FILTER_UNIT_TAG then
            EVENT_MANAGER:AddFilterForEvent(
                ADDON.name .. "PlayerEffects",
                EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG,
                "player"
            )
        end
    end
    if EVENT_EFFECTS_FULL_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "PlayerEffectsFullUpdate", EVENT_EFFECTS_FULL_UPDATE, function()
            if ADDON.AbilityState and type(ADDON.AbilityState.RebuildPlayerEffects) == "function" then
                ADDON.AbilityState.RebuildPlayerEffects()
            end
            RefreshOverlays("player-effects-full-update")
        end)
    end
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "PredictedActivities", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            local category
            if type(GetActiveHotbarCategory) == "function" then
                local categoryOk, activeCategory = pcall(GetActiveHotbarCategory)
                if categoryOk then
                    category = activeCategory
                end
            end
            local abilityId = ResolveAbilityId(slotIndex, category)
            if abilityId == 0 then
                abilityId = ResolveAbilityId(slotIndex, nil)
            end
            if ADDON.AbilityState
                and type(ADDON.AbilityState.StartPrediction) == "function"
                and ADDON.AbilityState.StartPrediction(abilityId) then
                RefreshOverlays("prediction-start")
            end
        end)
    end
    EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "AbilityStates", 100, function()
        if ADDON.AbilityState and type(ADDON.AbilityState.ExpirePredictions) == "function" then
            ADDON.AbilityState.ExpirePredictions()
        end
        PollActivityTransitions()
    end)
end
