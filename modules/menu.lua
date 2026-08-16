EZOCombat = EZOCombat or {}
EZOCombat.Settings = EZOCombat.Settings or {}

local ADDON = EZOCombat
local Settings = ADDON.Settings
local PANEL_ID = "EZOCombatOptions"
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"

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

local function AbilityLabel(tracker)
    local name = ""
    if type(GetAbilityName) == "function" then
        local ok, value = pcall(GetAbilityName, tracker.abilityId)
        if ok and value then
            name = zo_strformat("<<C:1>>", value)
        end
    end
    return name ~= "" and name or tostring(tracker.abilityId)
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
        pcall(util.RequestRefreshIfNeeded, ADDON._lamPanel)
    end
end

local function BuildOptions()
    local roleLabels, roleValues = RoleChoices()
    local priorityModeLabels, priorityModeValues = PriorityModeChoices()
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

    local trackers = ADDON.Priority.ListTrackers()
    table.insert(options, CreateInfoHeader(
        GetString(SI_EZOCOMBAT_OPTIONS_TRACKERS),
        GetString(SI_EZOCOMBAT_OPTIONS_TRACKERS_TOOLTIP)
    ))
    for _, tracker in ipairs(trackers) do
        local label = AbilityLabel(tracker)
        local priorityLabels, priorityValues = PriorityChoices()
        table.insert(options, {
            type = "checkbox",
            name = label,
            tooltip = GetString(SI_EZOCOMBAT_TRACKER_ENABLED_TOOLTIP),
            getFunc = function()
                return tracker.enabled == true
            end,
            setFunc = function(value)
                ADDON.Priority.SetEnabled(tracker, value == true)
                Settings.RequestSettingsRefresh(false)
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
                return tracker.priority
            end,
            setFunc = function(value)
                ADDON.Priority.SetPriority(tracker, value)
                Settings.RequestSettingsRefresh(false)
            end,
            default = ADDON.Priority.DEFAULT,
            width = "half",
        })
    end
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
