EZOCombat = EZOCombat or {}
EZOCombat.SavedVars = EZOCombat.SavedVars or {}

local ADDON = EZOCombat
local SavedVars = ADDON.SavedVars
local SAVED_VARIABLES_NAME = "EZOCombat_Saved"
local SCHEMA_VERSION = 1

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
    },
    window = {
        enabled = true,
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
    sv.window = sv.window or {}
    sv.window.enabled = sv.window.enabled ~= false
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
    }

    local profile = sv.profiles[classKey][role]
    profile.trackers = profile.trackers or {}
    return profile
end
