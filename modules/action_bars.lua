EZOCombat = EZOCombat or {}
EZOCombat.ActionBars = EZOCombat.ActionBars or {}

local ADDON = EZOCombat
local ActionBars = ADDON.ActionBars

ActionBars.activityStates = ActionBars.activityStates or {}

local BAR_REFRESH_UPDATE_NAME = ADDON.name .. "BarsRefresh"
local EMPTY_ENTRIES = {}
local RegisterStateEvents
local StopStateEvents

local function NormalizeAbilityId(abilityId)
    return ADDON.AbilityState.NormalizeAbilityId(abilityId)
end

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
    return ActionBars.entriesByAbility and ActionBars.entriesByAbility[NormalizeAbilityId(abilityId)] or EMPTY_ENTRIES
end

local function HasEntryForAbility(abilityId)
    return #GetEntriesForAbility(abilityId) > 0
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

local function RefreshOverlaysNow(source)
    ActionBars.pendingOverlayRefreshSource = nil
    if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
        DebugLog("evidence refresh source=" .. tostring(source or "unknown"))
    end
    if ADDON.Overlays and type(ADDON.Overlays.Refresh) == "function" then
        ADDON.Overlays.Refresh()
    end
end

local function RequestOverlayRefresh(source)
    -- Native evidence is read once on the next state tick. Rendering occurs
    -- only if activity or stacks changed, not once for every incoming event.
    ActionBars.pendingOverlayRefreshSource = source
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
    local changed = false
    for abilityId in pairs(ActionBars.trackedAbilities) do
        local state = ActionBars.GetAbilityState(abilityId)
        local stateKey = ActivityStateKey(state)
        if ActionBars.activityStates[abilityId] ~= stateKey
            or ActionBars.activityStacks[abilityId] ~= state.stacks then
            ActionBars.activityStates[abilityId] = stateKey
            ActionBars.activityStacks[abilityId] = state.stacks
            changed = true
            if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
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
    return changed
end

function ActionBars.InvalidateStates()
    local cache = ActionBars.stateCache or {}
    for id in pairs(cache) do
        cache[id] = nil
    end
    ActionBars.stateCache = cache
end

local function OnStateTick()
    ActionBars.InvalidateStates()
    ADDON.AbilityState.ExpirePredictions()
    local changed = PollActivityTransitions()
    if changed then
        RefreshOverlaysNow(ActionBars.pendingOverlayRefreshSource or "activity-transition")
    else
        ActionBars.pendingOverlayRefreshSource = nil
    end
end

function ActionBars.SyncTracking()
    local trackers = ADDON.Priority.ListTrackers()
    local enabled = ADDON.sv and ADDON.sv.general and ADDON.sv.general.enabled == true
    if ActionBars.planTrackers == trackers and ActionBars.planBars == ActionBars.bars
        and ActionBars.planEnabled == enabled then
        return
    end
    ActionBars.planTrackers, ActionBars.planBars, ActionBars.planEnabled = trackers, ActionBars.bars, enabled
    local tracked = {}
    local previousUltimate, previousPredictions = ActionBars.trackUltimate, ActionBars.trackPredictions
    ActionBars.trackUltimate, ActionBars.trackPredictions = false, false
    if enabled then
        for _, tracker in ipairs(trackers) do
            if tracker.enabled and HasEntryForAbility(tracker.abilityId)
                and (tracker.condition ~= ADDON.Priority.CONDITION_SLOTTED
                    or ADDON.AbilityState.IsSlotStackProvider(tracker.abilityId)) then
                tracked[NormalizeAbilityId(tracker.abilityId)] = true
                ActionBars.trackPredictions = ActionBars.trackPredictions
                    or ADDON.AbilityState.IsPredictionProvider(tracker.abilityId)
                for _, entry in ipairs(GetEntriesForAbility(tracker.abilityId)) do
                    ActionBars.trackUltimate = ActionBars.trackUltimate or entry.isUltimate
                end
            end
        end
    end
    local previous = ActionBars.trackedAbilities
    local selectionChanged = previous == nil
    if previous then
        for id in pairs(previous) do
            if not tracked[id] then selectionChanged = true; break end
        end
        for id in pairs(tracked) do
            if not previous[id] then selectionChanged = true; break end
        end
    end
    -- Slot moves, equivalent effective IDs and priority edits do not require
    -- rescanning buffs or disconnecting the same native event subscriptions.
    if not selectionChanged and previousUltimate == ActionBars.trackUltimate
        and previousPredictions == ActionBars.trackPredictions then
        return
    end
    ActionBars.trackedAbilities = tracked
    ActionBars.activityStates, ActionBars.activityStacks = {}, {}
    ActionBars.InvalidateStates()
    local active = next(tracked) ~= nil
    if ActionBars.trackingActive then
        StopStateEvents()
    end
    if active then
        RegisterStateEvents()
    end
    if active ~= (ActionBars.trackingActive == true) then
        ActionBars.trackingActive = active
        if active then
            EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "AbilityStates", 100, OnStateTick)
        else
            StopStateEvents()
            EVENT_MANAGER:UnregisterForUpdate(ADDON.name .. "AbilityStates")
        end
    end
    if selectionChanged then
        ADDON.AbilityState.SetTrackedAbilities(tracked)
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
            local previous = ActionBars.bars and ActionBars.bars[bar.key]
                and ActionBars.bars[bar.key][slotIndex - firstSlot + 1]
            if previous and previous.abilityId == abilityId then
                entries[#entries + 1] = previous
            else
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
        end
        bars[bar.key] = entries
    end
    return bars
end

function ActionBars.Refresh(source)
    EVENT_MANAGER:UnregisterForUpdate(BAR_REFRESH_UPDATE_NAME)
    ActionBars.barsRefreshPending = false
    local bars = ActionBars.Capture()
    local signature = BuildBarsSignature(bars)
    local barsChanged = ActionBars.barsSignature ~= signature
    if barsChanged or not ActionBars.bars then
        ActionBars.bars = bars
        local index = {}
        for _, entries in pairs(bars) do
            for _, entry in ipairs(entries) do
                local id = NormalizeAbilityId(entry.abilityId)
                if id ~= 0 then
                    index[id] = index[id] or {}
                    index[id][#index[id] + 1] = entry
                end
            end
        end
        ActionBars.entriesByAbility = index
    end
    ActionBars.barsSignature = signature
    ActionBars.InvalidateStates()
    ActionBars.SyncTracking()
    if source == "player-activated" and ActionBars.trackingActive then
        ADDON.AbilityState.RebuildPlayerEffects()
    end
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
    if (barsChanged or source == "window-show")
        and ADDON.Window and type(ADDON.Window.RefreshBars) == "function" then
        ADDON.Window.RefreshBars()
    end
    if barsChanged
        and ADDON.Settings
        and type(ADDON.Settings.RequestSettingsRefresh) == "function" then
        ADDON.Settings.RequestSettingsRefresh(true)
    end
    RefreshOverlaysNow(source or "bar-refresh")
end

local function FlushBarsRefresh()
    ActionBars.Refresh("coalesced-bars")
end

local function QueueBarsRefresh()
    if not ActionBars.barsRefreshPending then
        ActionBars.barsRefreshPending = true
        EVENT_MANAGER:RegisterForUpdate(BAR_REFRESH_UPDATE_NAME, 1, FlushBarsRefresh)
    end
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
    return abilityId ~= 0 and HasEntryForAbility(abilityId)
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

function ActionBars.GetEntryForAbility(abilityId)
    return GetEntriesForAbility(abilityId)[1]
end

function ActionBars.GetAbilityState(abilityId)
    abilityId = NormalizeAbilityId(abilityId)
    local entries = GetEntriesForAbility(abilityId)
    ActionBars.stateCache = ActionBars.stateCache or {}
    if ActionBars.stateCache[abilityId] then
        return ActionBars.stateCache[abilityId]
    end
    if #entries > 0 and ActionBars.trackedAbilities and ActionBars.trackedAbilities[abilityId] then
        local state = ADDON.AbilityState.Resolve(abilityId, entries)
        ActionBars.stateCache[abilityId] = state
        return state
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
            QueueBarsRefresh()
        end)
    end
    if EVENT_HOTBAR_SLOT_UPDATED and EVENT_HOTBAR_SLOT_UPDATED ~= EVENT_ACTION_SLOT_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "HotbarSlots", EVENT_HOTBAR_SLOT_UPDATED, function()
            QueueBarsRefresh()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionBar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        QueueBarsRefresh()
    end)
    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "AllActionBars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
            QueueBarsRefresh()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        ActionBars.planBars = nil
        ActionBars.Refresh("player-activated")
    end)
end

RegisterStateEvents = function()
    if EVENT_ACTION_SLOT_EFFECT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionSlotEffect", EVENT_ACTION_SLOT_EFFECT_UPDATE, function()
            RequestOverlayRefresh("action-slot-effect")
        end)
    end
    if EVENT_ACTION_SLOT_EFFECTS_CLEARED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "ActionSlotEffectsCleared", EVENT_ACTION_SLOT_EFFECTS_CLEARED, function()
            RequestOverlayRefresh("action-slot-effects-cleared")
        end)
    end
    if EVENT_POWER_UPDATE and ActionBars.trackUltimate then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "UltimatePower", EVENT_POWER_UPDATE, function(_, unitTag, _, powerType)
            if unitTag == "player" and powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
                RequestOverlayRefresh("ultimate-power")
            end
        end)
        if REGISTER_FILTER_UNIT_TAG and REGISTER_FILTER_POWER_TYPE and COMBAT_MECHANIC_FLAGS_ULTIMATE ~= nil then
            EVENT_MANAGER:AddFilterForEvent(
                ADDON.name .. "UltimatePower",
                EVENT_POWER_UPDATE,
                REGISTER_FILTER_UNIT_TAG,
                "player",
                REGISTER_FILTER_POWER_TYPE,
                COMBAT_MECHANIC_FLAGS_ULTIMATE
            )
        end
    end
    if EVENT_ULTIMATE_ABILITY_COST_CHANGED and ActionBars.trackUltimate then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "UltimateCost", EVENT_ULTIMATE_ABILITY_COST_CHANGED, function()
            RequestOverlayRefresh("ultimate-cost")
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
                local changed = ADDON.AbilityState.HandleEffectChanged(
                    changeType,
                    effectSlot,
                    beginTime,
                    endTime,
                    stackCount,
                    abilityId,
                    sourceType
                )
                if not changed then
                    return
                end
            end
            RequestOverlayRefresh("player-effect")
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
            RequestOverlayRefresh("player-effects-full-update")
        end)
    end
    if EVENT_ACTION_SLOT_ABILITY_USED and ActionBars.trackPredictions then
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
            if not ActionBars.trackedAbilities[NormalizeAbilityId(abilityId)] then
                return
            end
            if ADDON.AbilityState
                and type(ADDON.AbilityState.StartPrediction) == "function"
                and ADDON.AbilityState.StartPrediction(abilityId) then
                RequestOverlayRefresh("prediction-start")
            end
        end)
    end
end

StopStateEvents = function()
    local events = {
        ActionSlotEffect = EVENT_ACTION_SLOT_EFFECT_UPDATE,
        ActionSlotEffectsCleared = EVENT_ACTION_SLOT_EFFECTS_CLEARED,
        UltimatePower = EVENT_POWER_UPDATE,
        UltimateCost = EVENT_ULTIMATE_ABILITY_COST_CHANGED,
        PlayerEffects = EVENT_EFFECT_CHANGED,
        PlayerEffectsFullUpdate = EVENT_EFFECTS_FULL_UPDATE,
        PredictedActivities = EVENT_ACTION_SLOT_ABILITY_USED,
    }
    for suffix, event in pairs(events) do
        EVENT_MANAGER:UnregisterForEvent(ADDON.name .. suffix, event)
    end
end
