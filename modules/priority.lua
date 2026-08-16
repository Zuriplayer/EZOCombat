EZOCombat = EZOCombat or {}
EZOCombat.Priority = EZOCombat.Priority or {}

local ADDON = EZOCombat
local Priority = ADDON.Priority

local function DebugLog(message)
    if ADDON.DebugLog then
        ADDON.DebugLog("[Priority] " .. tostring(message))
    end
end

Priority.CONDITION_SLOTTED = "slotted"
Priority.CONDITION_ACTIVE = "active"
Priority.CONDITION_INACTIVE = "inactive"
Priority.MODE_ALL = "all"
Priority.MODE_HIGHEST = "highest"
Priority.MODE_TOP_TWO = "top_two"
Priority.ALWAYS = 0
Priority.MIN = 1
Priority.MAX = 5
Priority.DEFAULT = 3

local function NormalizePriority(value)
    value = tonumber(value) or Priority.DEFAULT
    if value == Priority.ALWAYS then
        return Priority.ALWAYS
    end
    return math.max(Priority.MIN, math.min(Priority.MAX, math.floor(value)))
end

local function IsKnownMode(mode)
    return mode == Priority.MODE_ALL
        or mode == Priority.MODE_HIGHEST
        or mode == Priority.MODE_TOP_TWO
end

local function SortRank(priority)
    return priority == Priority.ALWAYS and Priority.MAX + 1 or priority
end

local function IsKnownCondition(condition)
    return condition == Priority.CONDITION_SLOTTED
        or condition == Priority.CONDITION_ACTIVE
        or condition == Priority.CONDITION_INACTIVE
end

local function TrackerId(abilityId)
    return "ability-" .. tostring(tonumber(abilityId) or 0)
end

function Priority.GetProfile()
    return ADDON.Context and ADDON.Context.GetActiveProfile and ADDON.Context.GetActiveProfile() or nil
end

function Priority.ListTrackers()
    local profile = Priority.GetProfile()
    local trackers = {}
    if not profile then
        return trackers
    end
    for _, tracker in pairs(profile.trackers or {}) do
        tracker.priority = NormalizePriority(tracker.priority)
        tracker.enabled = tracker.enabled ~= false
        tracker.condition = IsKnownCondition(tracker.condition) and tracker.condition or Priority.CONDITION_SLOTTED
        trackers[#trackers + 1] = tracker
    end
    table.sort(trackers, function(a, b)
        local aRank = SortRank(a.priority)
        local bRank = SortRank(b.priority)
        if aRank == bRank then
            return tostring(a.id) < tostring(b.id)
        end
        return aRank < bRank
    end)
    return trackers
end

function Priority.GetTracker(abilityId)
    local profile = Priority.GetProfile()
    return profile and profile.trackers and profile.trackers[TrackerId(abilityId)] or nil
end

function Priority.EnsureTracker(entry)
    local profile = Priority.GetProfile()
    if not profile or not entry or (tonumber(entry.abilityId) or 0) == 0 then
        return nil
    end

    local id = TrackerId(entry.abilityId)
    local tracker = profile.trackers[id]
    if not tracker then
        tracker = {
            id = id,
            abilityId = tonumber(entry.abilityId),
            enabled = true,
            condition = Priority.CONDITION_SLOTTED,
            priority = Priority.DEFAULT,
        }
        profile.trackers[id] = tracker
        DebugLog(string.format("created tracker id=%s ability=%s priority=%s", id, tostring(tracker.abilityId), tostring(tracker.priority)))
    end
    return tracker
end

function Priority.SetEnabled(tracker, enabled)
    if not tracker then
        return
    end
    tracker.enabled = enabled == true
    DebugLog(string.format("enabled id=%s value=%s", tostring(tracker.id), tostring(tracker.enabled)))
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
end

function Priority.SetPriority(tracker, value)
    if not tracker then
        return
    end
    tracker.priority = NormalizePriority(value)
    DebugLog(string.format(
        "priority id=%s value=%s",
        tostring(tracker.id),
        tracker.priority == Priority.ALWAYS and "always" or "P" .. tostring(tracker.priority)
    ))
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
end

function Priority.GetMode()
    local mode = ADDON.sv and ADDON.sv.general and ADDON.sv.general.priorityMode
    return IsKnownMode(mode) and mode or Priority.MODE_ALL
end

function Priority.SetMode(mode)
    if not (ADDON.sv and ADDON.sv.general) or not IsKnownMode(mode) then
        return false
    end
    ADDON.sv.general.priorityMode = mode
    DebugLog("management mode=" .. tostring(mode))
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Priority.SetCondition(tracker, condition)
    if not tracker or not IsKnownCondition(condition) then
        return
    end
    tracker.condition = condition
    DebugLog(string.format("condition id=%s value=%s", tostring(tracker.id), tostring(tracker.condition)))
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
end

function Priority.SetPosition(tracker, x, y)
    if not tracker then
        return
    end
    tracker.x = tonumber(x)
    tracker.y = tonumber(y)
end

function Priority.IsEligible(tracker)
    if not (tracker
        and tracker.enabled == true
        and ADDON.ActionBars
        and ADDON.ActionBars.IsAbilitySlotted(tracker.abilityId)) then
        return false
    end

    if tracker.condition == Priority.CONDITION_SLOTTED then
        return true
    end

    local state = ADDON.ActionBars.GetAbilityState(tracker.abilityId)
    if state.active == nil then
        return false
    end
    return tracker.condition == Priority.CONDITION_ACTIVE and state.active
        or tracker.condition == Priority.CONDITION_INACTIVE and not state.active
end

function Priority.Evaluate(showAllConfigured)
    local candidates = {}
    local visible = {}
    local eligibleLevels = {}
    if not (ADDON.sv and ADDON.sv.general and ADDON.sv.general.enabled) then
        return visible, nil
    end

    for _, tracker in ipairs(Priority.ListTrackers()) do
        local configuredForCurrentBars = tracker.enabled == true
            and ADDON.ActionBars
            and ADDON.ActionBars.IsAbilitySlotted(tracker.abilityId)
        if showAllConfigured == true and configuredForCurrentBars then
            visible[#visible + 1] = tracker
        elseif showAllConfigured ~= true and Priority.IsEligible(tracker) then
            candidates[#candidates + 1] = tracker
            if tracker.priority ~= Priority.ALWAYS then
                eligibleLevels[tracker.priority] = true
            end
        end
    end

    if showAllConfigured == true then
        if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
            local ids = {}
            for _, tracker in ipairs(visible) do
                ids[#ids + 1] = tostring(tracker.id)
            end
            DebugLog("evaluate preview=all-configured visible=" .. table.concat(ids, ","))
        end
        return visible, nil
    end

    local mode = Priority.GetMode()
    local selectedLevels = {}
    if mode ~= Priority.MODE_ALL then
        local limit = mode == Priority.MODE_HIGHEST and 1 or 2
        for priority = Priority.MIN, Priority.MAX do
            if eligibleLevels[priority] then
                selectedLevels[priority] = true
                limit = limit - 1
                if limit == 0 then
                    break
                end
            end
        end
    end

    for _, tracker in ipairs(candidates) do
        if tracker.priority == Priority.ALWAYS
            or mode == Priority.MODE_ALL
            or selectedLevels[tracker.priority] then
            visible[#visible + 1] = tracker
        end
    end
    if ADDON.IsDebugModeEnabled and ADDON.IsDebugModeEnabled() then
        local ids = {}
        local levels = {}
        for priority = Priority.MIN, Priority.MAX do
            if selectedLevels[priority] then
                levels[#levels + 1] = "P" .. tostring(priority)
            end
        end
        for _, tracker in ipairs(visible) do
            ids[#ids + 1] = tostring(tracker.id)
        end
        DebugLog(string.format(
            "evaluate mode=%s levels=%s visible=%s",
            tostring(mode),
            #levels > 0 and table.concat(levels, ",") or "all-or-none",
            table.concat(ids, ",")
        ))
    end
    return visible, selectedLevels
end

function Priority.DebugSnapshot()
    local trackers = Priority.ListTrackers()
    local showAllConfigured = ADDON.Window
        and type(ADDON.Window.IsShowingAllConfigured) == "function"
        and ADDON.Window.IsShowingAllConfigured()
    local visibleTrackers = Priority.Evaluate(showAllConfigured)
    local visibleIds = {}
    for _, tracker in ipairs(visibleTrackers) do
        visibleIds[tracker.id] = true
    end
    local rows = {}
    for _, tracker in ipairs(trackers) do
        local active, detail, state
        if ADDON.ActionBars and ADDON.ActionBars.GetAbilityActivityDetails then
            active, detail, state = ADDON.ActionBars.GetAbilityActivityDetails(tracker.abilityId)
        end
        rows[#rows + 1] = string.format(
            "%s ability=%s enabled=%s condition=%s activeOrReady=%s phase=%s source=%s confidence=%s priority=%s eligible=%s visible=%s state=[%s]",
            tostring(tracker.id),
            tostring(tracker.abilityId),
            tostring(tracker.enabled),
            tostring(tracker.condition),
            tostring(active),
            tostring(state and state.phase),
            tostring(state and state.source),
            tostring(state and state.confidence),
            tracker.priority == Priority.ALWAYS and "always" or "P" .. tostring(tracker.priority),
            tostring(Priority.IsEligible(tracker)),
            tostring(visibleIds[tracker.id] == true),
            tostring(detail)
        )
    end
    DebugLog(string.format(
        "previewAllConfigured=%s trackers=%s",
        tostring(showAllConfigured),
        #rows > 0 and table.concat(rows, " | ") or "none"
    ))
end

function Priority.Init()
    -- State providers extend eligibility without changing persistence or priorities.
end
