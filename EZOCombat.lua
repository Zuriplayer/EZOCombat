EZOCombat = EZOCombat or {}
local ADDON = EZOCombat

ADDON.name = "EZOCombat"
ADDON.version = "0.1.0-beta"
ADDON.addOnVersion = 100
ADDON.modules = ADDON.modules or {}
ADDON._initialized = false

local EVENT_MANAGER = EVENT_MANAGER

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

    if ADDON.Initialize then
        ADDON:Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
