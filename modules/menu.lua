EZOCombat = EZOCombat or {}
EZOCombat.Settings = EZOCombat.Settings or {}

local ADDON = EZOCombat
local Settings = ADDON.Settings
local PANEL_ID = "EZOCombatOptions"
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"
local TRACKER_SELECTOR_REFERENCE = "EZOCombatTrackerSelector"

Settings.trackerChoiceLabels = Settings.trackerChoiceLabels or {}
Settings.trackerChoiceValues = Settings.trackerChoiceValues or {}

local function CreateInfoHeader(name, tooltip)
    return {
        type = "header",
        name = zo_strformat("<<1>> |cB040FF|t26:26:<<2>>:inheritcolor|t|r", name, INFO_HEADER_TEXTURE),
        tooltip = tooltip,
    }
end

local function RoleChoices()
    return {
        ADDON.Context.GetRoleLabel("dd"),
        ADDON.Context.GetRoleLabel("tank"),
        ADDON.Context.GetRoleLabel("healer"),
    }, { "dd", "tank", "healer" }
end

local function PriorityChoices()
    local labels = { GetString(SI_EZOCOMBAT_PRIORITY_ALWAYS) }
    local values = { ADDON.Priority.ALWAYS }
    for priority = ADDON.Priority.MIN, ADDON.Priority.MAX do
        labels[#labels + 1] = zo_strformat(GetString(SI_EZOCOMBAT_PRIORITY_LABEL), priority)
        values[#values + 1] = priority
    end
    return labels, values
end

local function PriorityModeChoices()
    return {
        GetString(SI_EZOCOMBAT_PRIORITY_MODE_ALL),
        GetString(SI_EZOCOMBAT_PRIORITY_MODE_HIGHEST),
        GetString(SI_EZOCOMBAT_PRIORITY_MODE_TOP_TWO),
    }, {
        ADDON.Priority.MODE_ALL,
        ADDON.Priority.MODE_HIGHEST,
        ADDON.Priority.MODE_TOP_TWO,
    }
end

local function AbilityLabel(tracker, currentName)
    local name = tostring(currentName or "")
    if type(GetAbilityName) == "function" then
        if name == "" then
            local ok, value = pcall(GetAbilityName, tracker.abilityId)
            if ok and value then
                name = value
            end
        end
    end
    return name ~= "" and zo_strformat("<<C:1>>", name) or tostring(tracker.abilityId)
end

local function ClearArray(values)
    for index = #values, 1, -1 do
        values[index] = nil
    end
end

local function FindSelectedTracker(trackers)
    local selectedAbilityId = tonumber(Settings.selectedTrackerAbilityId)
    if selectedAbilityId then
        for _, tracker in ipairs(trackers) do
            if tracker.abilityId == selectedAbilityId then
                return tracker
            end
        end
    end
    return trackers[1]
end

local function FindTrackerForAbility(trackers, abilityId)
    for _, tracker in ipairs(trackers) do
        local equivalent = tracker.abilityId == abilityId
        if not equivalent
            and ADDON.AbilityState
            and type(ADDON.AbilityState.AreAbilityIdsEquivalent) == "function" then
            equivalent = ADDON.AbilityState.AreAbilityIdsEquivalent(tracker.abilityId, abilityId)
        end
        if equivalent then
            return tracker
        end
    end
    return nil
end

local function GetOrderedTrackerRows(trackers)
    local rows = {}
    local seen = {}
    local bars = ADDON.ActionBars and ADDON.ActionBars.bars or {}
    local orderedBars = {
        { key = "front", label = GetString(SI_EZOCOMBAT_FRONT_BAR) },
        { key = "back", label = GetString(SI_EZOCOMBAT_BACK_BAR) },
    }

    for _, bar in ipairs(orderedBars) do
        for _, entry in ipairs(bars[bar.key] or {}) do
            local tracker = FindTrackerForAbility(trackers, entry.abilityId)
            if tracker and not seen[tracker.id] then
                seen[tracker.id] = true
                rows[#rows + 1] = {
                    tracker = tracker,
                    label = zo_strformat(
                        GetString(SI_EZOCOMBAT_TRACKER_BAR_LABEL),
                        bar.label,
                        AbilityLabel(tracker, entry.name)
                    ),
                }
            end
        end
    end

    for _, tracker in ipairs(trackers) do
        if not seen[tracker.id] then
            rows[#rows + 1] = {
                tracker = tracker,
                label = zo_strformat(
                    GetString(SI_EZOCOMBAT_TRACKER_UNSLOTTED_LABEL),
                    AbilityLabel(tracker)
                ),
            }
        end
    end
    return rows
end

local function RefreshTrackerChoices()
    local labels = Settings.trackerChoiceLabels
    local values = Settings.trackerChoiceValues
    local trackers = ADDON.Priority.ListTrackers()
    local selectedTracker = FindSelectedTracker(trackers)
    local rows = GetOrderedTrackerRows(trackers)

    ClearArray(labels)
    ClearArray(values)
    for _, row in ipairs(rows) do
        labels[#labels + 1] = row.label
        values[#values + 1] = row.tracker.abilityId
    end

    if selectedTracker then
        Settings.selectedTrackerAbilityId = selectedTracker.abilityId
    else
        labels[1] = GetString(SI_EZOCOMBAT_TRACKER_NONE)
        values[1] = 0
        Settings.selectedTrackerAbilityId = nil
    end
    return labels, values
end

local function GetSelectedTracker()
    local trackers = ADDON.Priority.ListTrackers()
    local tracker = FindSelectedTracker(trackers)
    if tracker then
        Settings.selectedTrackerAbilityId = tracker.abilityId
    else
        Settings.selectedTrackerAbilityId = nil
    end
    return tracker
end

local function RefreshStandaloneTrackerSelector()
    if not ADDON._lamPanel then
        return
    end
    local labels, values = RefreshTrackerChoices()
    local control = _G[TRACKER_SELECTOR_REFERENCE]
    if control and type(control.UpdateChoices) == "function" then
        control:UpdateChoices(labels, values)
        if type(control.UpdateValue) == "function" then
            control:UpdateValue()
        end
    end
end

function Settings.RequestSettingsRefresh(forceRebuild)
    local function RefreshHostedPanel()
        if ADDON.ezoSettingsRegistered and EZOCore and type(EZOCore.RefreshSettingsPanel) == "function" then
            pcall(function()
                EZOCore:RefreshSettingsPanel(forceRebuild == true)
            end)
        end
    end

    if forceRebuild and type(zo_callLater) == "function" then
        zo_callLater(RefreshHostedPanel, 1)
    else
        RefreshHostedPanel()
    end

    local util = LibAddonMenu2 and LibAddonMenu2.util
    if util and type(util.RequestRefreshIfNeeded) == "function" and ADDON._lamPanel then
        RefreshStandaloneTrackerSelector()
        pcall(util.RequestRefreshIfNeeded, ADDON._lamPanel)
    end
end

local function BuildOptions()
    local roleLabels, roleValues = RoleChoices()
    local priorityModeLabels, priorityModeValues = PriorityModeChoices()
    local trackerLabels, trackerValues = RefreshTrackerChoices()
    local priorityLabels, priorityValues = PriorityChoices()
    local options = {
        CreateInfoHeader(GetString(SI_EZOCOMBAT_OPTIONS_GENERAL), GetString(SI_EZOCOMBAT_OPTIONS_GENERAL_TOOLTIP)),
        {
            type = "button",
            name = GetString(SI_EZOCOMBAT_OPEN_WINDOW),
            tooltip = GetString(SI_EZOCOMBAT_OPEN_WINDOW_TOOLTIP),
            func = function()
                ADDON.Window.Show()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_ENABLE_OVERLAYS),
            tooltip = GetString(SI_EZOCOMBAT_ENABLE_OVERLAYS_TOOLTIP),
            getFunc = function()
                return ADDON.sv.general.enabled == true
            end,
            setFunc = function(value)
                ADDON.sv.general.enabled = value == true
                ADDON.Overlays.Refresh()
                Settings.RequestSettingsRefresh(false)
            end,
            default = true,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_ICON_SIZE),
            tooltip = GetString(SI_EZOCOMBAT_ICON_SIZE_TOOLTIP),
            min = ADDON.Overlays.MIN_ICON_SIZE,
            max = ADDON.Overlays.MAX_ICON_SIZE,
            step = 2,
            decimals = 0,
            getFunc = ADDON.Overlays.GetIconSize,
            setFunc = function(value)
                ADDON.Overlays.SetIconSize(value)
                Settings.RequestSettingsRefresh(false)
            end,
            default = ADDON.Overlays.DEFAULT_ICON_SIZE,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_EZOCOMBAT_PRIORITY_MODE),
            tooltip = GetString(SI_EZOCOMBAT_PRIORITY_MODE_TOOLTIP),
            choices = priorityModeLabels,
            choicesValues = priorityModeValues,
            getFunc = ADDON.Priority.GetMode,
            setFunc = function(value)
                ADDON.Priority.SetMode(value)
                Settings.RequestSettingsRefresh(false)
            end,
            default = ADDON.Priority.MODE_ALL,
            width = "full",
        },
        CreateInfoHeader(GetString(SI_EZOCOMBAT_OPTIONS_PVP_TARGET), GetString(SI_EZOCOMBAT_OPTIONS_PVP_TARGET_TOOLTIP)),
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_ENABLE_PVP_TARGET),
            tooltip = GetString(SI_EZOCOMBAT_ENABLE_PVP_TARGET_TOOLTIP),
            getFunc = ADDON.PvpTarget.IsEnabled,
            setFunc = function(value)
                ADDON.PvpTarget.SetEnabled(value == true)
                Settings.RequestSettingsRefresh(true)
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_ENABLE_PVP_LOW_HEALTH_ALERT),
            tooltip = GetString(SI_EZOCOMBAT_ENABLE_PVP_LOW_HEALTH_ALERT_TOOLTIP),
            getFunc = ADDON.PvpTarget.IsLowHealthAlertEnabled,
            setFunc = function(value)
                ADDON.PvpTarget.SetLowHealthAlertEnabled(value == true)
                Settings.RequestSettingsRefresh(true)
            end,
            disabled = function()
                return not ADDON.PvpTarget.IsEnabled()
            end,
            default = true,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_PVP_HEALTH_THRESHOLD),
            tooltip = GetString(SI_EZOCOMBAT_PVP_HEALTH_THRESHOLD_TOOLTIP),
            min = 5,
            max = 95,
            step = 5,
            decimals = 0,
            getFunc = ADDON.PvpTarget.GetHealthThreshold,
            setFunc = function(value)
                ADDON.PvpTarget.SetHealthThreshold(value)
            end,
            disabled = function()
                return not ADDON.PvpTarget.IsEnabled() or not ADDON.PvpTarget.IsLowHealthAlertEnabled()
            end,
            default = 30,
        },
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_PVP_MOVE_FRAME),
            tooltip = GetString(SI_EZOCOMBAT_PVP_MOVE_FRAME_TOOLTIP),
            getFunc = ADDON.PvpTarget.IsMoveMode,
            setFunc = function(value)
                ADDON.PvpTarget.SetMoveMode(value == true)
                Settings.RequestSettingsRefresh(false)
            end,
            disabled = function()
                return not ADDON.PvpTarget.IsEnabled()
            end,
            default = false,
        },
        CreateInfoHeader(GetString(SI_EZOCOMBAT_OPTIONS_PVP_SCT), GetString(SI_EZOCOMBAT_OPTIONS_PVP_SCT_TOOLTIP)),
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_ENABLE_PVP_SCT),
            tooltip = GetString(SI_EZOCOMBAT_ENABLE_PVP_SCT_TOOLTIP),
            getFunc = ADDON.PvpSct.IsEnabled,
            setFunc = function(value)
                ADDON.PvpSct.SetEnabled(value == true)
                Settings.RequestSettingsRefresh(true)
            end,
            default = false,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_PVP_SCT_TIP_DISTANCE),
            tooltip = GetString(SI_EZOCOMBAT_PVP_SCT_TIP_DISTANCE_TOOLTIP),
            min = 0,
            max = 120,
            step = 5,
            decimals = 0,
            getFunc = ADDON.PvpSct.GetTipDistance,
            setFunc = function(value)
                ADDON.PvpSct.SetTipDistance(value)
            end,
            disabled = function()
                return not ADDON.PvpSct.IsEnabled()
            end,
            default = 20,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_PVP_SCT_CONE_WIDTH),
            tooltip = GetString(SI_EZOCOMBAT_PVP_SCT_CONE_WIDTH_TOOLTIP),
            min = 0,
            max = 240,
            step = 10,
            decimals = 0,
            getFunc = ADDON.PvpSct.GetConeWidth,
            setFunc = function(value)
                ADDON.PvpSct.SetConeWidth(value)
            end,
            disabled = function()
                return not ADDON.PvpSct.IsEnabled()
            end,
            default = 70,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_PVP_SCT_ROW_SPACING),
            tooltip = GetString(SI_EZOCOMBAT_PVP_SCT_ROW_SPACING_TOOLTIP),
            min = 8,
            max = 50,
            step = 2,
            decimals = 0,
            getFunc = ADDON.PvpSct.GetRowSpacing,
            setFunc = function(value)
                ADDON.PvpSct.SetRowSpacing(value)
            end,
            disabled = function()
                return not ADDON.PvpSct.IsEnabled()
            end,
            default = 18,
        },
        {
            type = "slider",
            name = GetString(SI_EZOCOMBAT_PVP_SCT_MINIMUM_SPACING),
            tooltip = GetString(SI_EZOCOMBAT_PVP_SCT_MINIMUM_SPACING_TOOLTIP),
            min = 0,
            max = 500,
            step = 10,
            decimals = 0,
            getFunc = ADDON.PvpSct.GetMinimumSpacing,
            setFunc = function(value)
                ADDON.PvpSct.SetMinimumSpacing(value)
            end,
            disabled = function()
                return not ADDON.PvpSct.IsEnabled()
            end,
            default = 90,
        },
        CreateInfoHeader(GetString(SI_EZOCOMBAT_OPTIONS_DEBUG), GetString(SI_EZOCOMBAT_OPTIONS_DEBUG_TOOLTIP)),
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_DEBUG_MODE),
            tooltip = GetString(SI_EZOCOMBAT_DEBUG_MODE_TOOLTIP),
            getFunc = ADDON.IsDebugModeEnabled,
            setFunc = function(value)
                ADDON.SetDebugModeEnabled(value == true)
                Settings.RequestSettingsRefresh(true)
            end,
            default = false,
            width = "half",
        },
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_DEBUG_CHAT),
            tooltip = GetString(SI_EZOCOMBAT_DEBUG_CHAT_TOOLTIP),
            getFunc = function()
                return ADDON.sv.general.debugChat == true
            end,
            setFunc = function(value)
                ADDON.sv.general.debugChat = value == true
            end,
            disabled = function()
                return not ADDON.IsDebugModeEnabled()
            end,
            default = false,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_EZOCOMBAT_DEBUG_CAPTURE),
            tooltip = GetString(SI_EZOCOMBAT_DEBUG_CAPTURE_TOOLTIP),
            func = ADDON.RunDebugSnapshot,
            disabled = function()
                return not ADDON.IsDebugModeEnabled()
            end,
            width = "full",
        },
        CreateInfoHeader(GetString(SI_EZOCOMBAT_OPTIONS_PROFILE), GetString(SI_EZOCOMBAT_OPTIONS_PROFILE_TOOLTIP)),
        {
            type = "checkbox",
            name = GetString(SI_EZOCOMBAT_ROLE_AUTO),
            tooltip = GetString(SI_EZOCOMBAT_ROLE_AUTO_TOOLTIP),
            getFunc = ADDON.Context.IsRoleAuto,
            setFunc = function(value)
                ADDON.sv.general.roleMode = value and "auto" or "manual"
                ADDON.Overlays.Refresh()
                Settings.RequestSettingsRefresh(true)
            end,
            default = true,
            width = "half",
        },
        {
            type = "dropdown",
            name = GetString(SI_EZOCOMBAT_ROLE),
            tooltip = GetString(SI_EZOCOMBAT_ROLE_TOOLTIP),
            choices = roleLabels,
            choicesValues = roleValues,
            getFunc = ADDON.Context.GetActiveRole,
            setFunc = function(value)
                ADDON.sv.general.role = value
                ADDON.Overlays.Refresh()
                Settings.RequestSettingsRefresh(true)
            end,
            disabled = ADDON.Context.IsRoleAuto,
            default = "dd",
            width = "half",
        },
    }

    table.insert(options, CreateInfoHeader(
        GetString(SI_EZOCOMBAT_OPTIONS_TRACKERS),
        GetString(SI_EZOCOMBAT_OPTIONS_TRACKERS_TOOLTIP)
    ))
    table.insert(options, {
        type = "dropdown",
        name = GetString(SI_EZOCOMBAT_TRACKER_SELECT),
        tooltip = GetString(SI_EZOCOMBAT_TRACKER_SELECT_TOOLTIP),
        choices = trackerLabels,
        choicesValues = trackerValues,
        getFunc = function()
            local tracker = GetSelectedTracker()
            return tracker and tracker.abilityId or 0
        end,
        setFunc = function(value)
            Settings.selectedTrackerAbilityId = tonumber(value)
            Settings.RequestSettingsRefresh(false)
        end,
        reference = TRACKER_SELECTOR_REFERENCE,
        width = "full",
    })
    table.insert(options, {
        type = "checkbox",
        name = GetString(SI_EZOCOMBAT_TRACKER_ENABLED),
        tooltip = GetString(SI_EZOCOMBAT_TRACKER_ENABLED_TOOLTIP),
        getFunc = function()
            local tracker = GetSelectedTracker()
            return tracker and tracker.enabled == true or false
        end,
        setFunc = function(value)
            local tracker = GetSelectedTracker()
            ADDON.Priority.SetEnabled(tracker, value == true)
            Settings.RequestSettingsRefresh(false)
        end,
        disabled = function()
            return GetSelectedTracker() == nil
        end,
        width = "half",
    })
    table.insert(options, {
        type = "dropdown",
        name = GetString(SI_EZOCOMBAT_PRIORITY),
        tooltip = GetString(SI_EZOCOMBAT_PRIORITY_TOOLTIP),
        choices = priorityLabels,
        choicesValues = priorityValues,
        getFunc = function()
            local tracker = GetSelectedTracker()
            return tracker and tracker.priority or ADDON.Priority.DEFAULT
        end,
        setFunc = function(value)
            local tracker = GetSelectedTracker()
            ADDON.Priority.SetPriority(tracker, value)
            Settings.RequestSettingsRefresh(false)
        end,
        disabled = function()
            return GetSelectedTracker() == nil
        end,
        default = ADDON.Priority.DEFAULT,
        width = "half",
    })
    return options
end

function Settings.Init()
    if not LibAddonMenu2 then
        return
    end
    local panelData = {
        type = "panel",
        name = "EZOCombat",
        displayName = "E|cB040FFZ|rOCombat",
        author = "@Zuriplayer",
        version = ADDON.version,
        registerForRefresh = true,
        registerForDefaults = false,
    }
    if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
        local registered = EZOCore:RegisterSettingsPanel(ADDON.name, PANEL_ID, panelData, BuildOptions)
        if registered then
            ADDON.ezoSettingsRegistered = true
            return
        end
    end
    ADDON._lamPanel = LibAddonMenu2:RegisterAddonPanel(PANEL_ID, panelData)
    LibAddonMenu2:RegisterOptionControls(PANEL_ID, BuildOptions())
end
