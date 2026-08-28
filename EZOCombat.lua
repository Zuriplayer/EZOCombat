EZOCombat = EZOCombat or {}
local ADDON = EZOCombat

ADDON.name = "EZOCombat"
ADDON.version = "0.2.39-beta"
ADDON.addOnVersion = 239
ADDON.modules = ADDON.modules or {}
ADDON._initialized = false

local EVENT_MANAGER = EVENT_MANAGER

local function IsAddonInstalledAndEnabled(addonName)
    local manager
    if type(GetAddOnManager) == "function" then
        local ok, resolved = pcall(GetAddOnManager)
        if ok then
            manager = resolved
        end
    end
    manager = manager or AddOnManager or ADD_ON_MANAGER
    if not manager or type(manager.GetNumAddOns) ~= "function" or type(manager.GetAddOnInfo) ~= "function" then
        return false
    end

    local ok, enabled = pcall(function()
        for index = 1, manager:GetNumAddOns() do
            local name, _, _, _, isEnabled = manager:GetAddOnInfo(index)
            if name == addonName then
                return isEnabled == true
            end
        end
        return false
    end)
    return ok and enabled == true
end

local function IsBindingAssignedToOtherAction(targetKey, targetMod1, targetMod2, targetMod3, targetMod4, excludedAction)
    if type(GetNumActionLayers) ~= "function"
        or type(GetActionLayerInfo) ~= "function"
        or type(GetActionLayerCategoryInfo) ~= "function"
        or type(GetActionInfo) ~= "function"
        or type(GetMaxBindingsPerAction) ~= "function"
        or type(GetActionBindingInfo) ~= "function" then
        return true
    end

    local ok, assigned = pcall(function()
        for layerIndex = 1, GetNumActionLayers() do
            local _, categoryCount = GetActionLayerInfo(layerIndex)
            for categoryIndex = 1, categoryCount do
                local _, actionCount = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
                for actionIndex = 1, actionCount do
                    local actionName = GetActionInfo(layerIndex, categoryIndex, actionIndex)
                    if actionName ~= excludedAction then
                        for bindingIndex = 1, GetMaxBindingsPerAction() do
                            local key, mod1, mod2, mod3, mod4 = GetActionBindingInfo(
                                layerIndex,
                                categoryIndex,
                                actionIndex,
                                bindingIndex
                            )
                            if key == targetKey
                                and mod1 == targetMod1
                                and mod2 == targetMod2
                                and mod3 == targetMod3
                                and mod4 == targetMod4 then
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end)
    return not ok or assigned == true
end

local function RegisterDefaultKeybind()
    if not IsAddonInstalledAndEnabled(ADDON.name) or type(CreateDefaultActionBind) ~= "function" then
        return false
    end
    if IsBindingAssignedToOtherAction(
        KEY_NUMPAD3,
        KEY_SHIFT,
        KEY_INVALID,
        KEY_INVALID,
        KEY_INVALID,
        "EZO_COMBAT_TOGGLE_WINDOW"
    ) then
        return false
    end
    return pcall(
        CreateDefaultActionBind,
        "EZO_COMBAT_TOGGLE_WINDOW",
        KEY_NUMPAD3,
        KEY_SHIFT,
        KEY_INVALID,
        KEY_INVALID,
        KEY_INVALID
    )
end

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

if EVENT_KEYBINDINGS_LOADED then
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "_DefaultBind", EVENT_KEYBINDINGS_LOADED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON.name .. "_DefaultBind", EVENT_KEYBINDINGS_LOADED)
        RegisterDefaultKeybind()
    end)
end
