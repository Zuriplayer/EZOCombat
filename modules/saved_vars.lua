EZOCombat = EZOCombat or {}
EZOCombat.SavedVars = EZOCombat.SavedVars or {}

local ADDON = EZOCombat
local SavedVars = ADDON.SavedVars
local SAVED_VARIABLES_NAME = "EZOCombat_Saved"
local SCHEMA_VERSION = 3
local DEFAULT_ICON_SIZE = 54
local MIN_ICON_SIZE = 32
local MAX_ICON_SIZE = 128
local DEFAULT_LAYOUT_SPACING = 8
local DEFAULT_PRIORITY_SPACING = 18

local function GetWorld()
    if type(GetWorldName) ~= "function" then
        return "Default"
    end
    local ok, world = pcall(GetWorldName)
    return ok and tostring(world or "Default") or "Default"
end

local defaults = {
    general = {
        enabled = true,
        roleMode = "auto",
        role = "dd",
        debugMode = false,
        debugChat = false,
        priorityMode = "all",
        iconSize = DEFAULT_ICON_SIZE,
    },
    window = {
        enabled = true,
    },
    layout = {
        mode = "manual",
        alignment = "start",
        iconSpacing = DEFAULT_LAYOUT_SPACING,
        prioritySpacing = DEFAULT_PRIORITY_SPACING,
        anchors = {},
    },
    pvpTarget = {
        enabled = true,
        scope = "pvp",
        lowHealthAlert = true,
        healthThreshold = 30,
    },
    pvpSct = {
        enabled = false,
        scope = "pvp",
        tipDistance = 20,
        coneWidth = 70,
        rowSpacing = 18,
        minimumSpacing = 90,
    },
    abilityState = {
        capabilities = {},
    },
    profiles = {},
}

function SavedVars.Init()
    ADDON.sv = ZO_SavedVars:NewCharacterIdSettings(
        SAVED_VARIABLES_NAME,
        SCHEMA_VERSION,
        GetWorld(),
        defaults
    )

    local sv = ADDON.sv
    sv.general = sv.general or {}
    sv.general.enabled = sv.general.enabled ~= false
    sv.general.roleMode = sv.general.roleMode == "manual" and "manual" or "auto"
    sv.general.role = sv.general.role or "dd"
    sv.general.debugMode = sv.general.debugMode == true
    sv.general.debugChat = sv.general.debugChat == true
    if sv.general.priorityMode ~= "highest" and sv.general.priorityMode ~= "top_two" then
        sv.general.priorityMode = "all"
    end
    local iconSize = tonumber(sv.general.iconSize) or DEFAULT_ICON_SIZE
    sv.general.iconSize = math.max(MIN_ICON_SIZE, math.min(MAX_ICON_SIZE, math.floor(iconSize + 0.5)))
    sv.window = sv.window or {}
    sv.window.enabled = sv.window.enabled ~= false
    sv.layout = type(sv.layout) == "table" and sv.layout or {}
    if sv.layout.mode ~= "vertical" and sv.layout.mode ~= "horizontal" then
        sv.layout.mode = "manual"
    end
    if sv.layout.alignment ~= "center" and sv.layout.alignment ~= "end" then
        sv.layout.alignment = "start"
    end
    local iconSpacing = tonumber(sv.layout.iconSpacing) or DEFAULT_LAYOUT_SPACING
    sv.layout.iconSpacing = math.max(0, math.min(40, math.floor(iconSpacing + 0.5)))
    local prioritySpacing = tonumber(sv.layout.prioritySpacing) or DEFAULT_PRIORITY_SPACING
    sv.layout.prioritySpacing = math.max(0, math.min(80, math.floor(prioritySpacing + 0.5)))
    sv.layout.anchors = type(sv.layout.anchors) == "table" and sv.layout.anchors or {}
    sv.pvpTarget = sv.pvpTarget or {}
    sv.pvpTarget.enabled = sv.pvpTarget.enabled ~= false
    if sv.pvpTarget.scope ~= "test" then
        sv.pvpTarget.scope = "pvp"
    end
    sv.pvpTarget.lowHealthAlert = sv.pvpTarget.lowHealthAlert ~= false
    local healthThreshold = tonumber(sv.pvpTarget.healthThreshold) or 30
    sv.pvpTarget.healthThreshold = math.max(5, math.min(95, math.floor(healthThreshold + 0.5)))
    sv.pvpSct = sv.pvpSct or {}
    sv.pvpSct.enabled = sv.pvpSct.enabled == true
    if sv.pvpSct.scope ~= "test" then
        sv.pvpSct.scope = "pvp"
    end
    local tipDistance = tonumber(sv.pvpSct.tipDistance) or 20
    sv.pvpSct.tipDistance = math.max(0, math.min(120, math.floor(tipDistance + 0.5)))
    local coneWidth = tonumber(sv.pvpSct.coneWidth) or 70
    sv.pvpSct.coneWidth = math.max(0, math.min(240, math.floor(coneWidth + 0.5)))
    local rowSpacing = tonumber(sv.pvpSct.rowSpacing) or 18
    sv.pvpSct.rowSpacing = math.max(8, math.min(50, math.floor(rowSpacing + 0.5)))
    local minimumSpacing = tonumber(sv.pvpSct.minimumSpacing) or 90
    sv.pvpSct.minimumSpacing = math.max(0, math.min(500, math.floor(minimumSpacing + 0.5)))
    sv.abilityState = sv.abilityState or {}
    sv.abilityState.capabilities = sv.abilityState.capabilities or {}
    sv.profiles = sv.profiles or {}
end

function SavedVars.GetProfile(classKey, role)
    local sv = ADDON.sv
    if not sv then
        return nil
    end

    classKey = tostring(classKey or "class-unknown")
    role = tostring(role or "dd")
    sv.profiles[classKey] = sv.profiles[classKey] or {}
    sv.profiles[classKey][role] = sv.profiles[classKey][role] or {
        trackers = {},
        layoutAnchors = {},
    }

    local profile = sv.profiles[classKey][role]
    profile.trackers = profile.trackers or {}
    profile.layoutAnchors = type(profile.layoutAnchors) == "table" and profile.layoutAnchors or {}
    return profile
end
