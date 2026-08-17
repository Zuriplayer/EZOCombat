EZOCombat = EZOCombat or {}
EZOCombat.Context = EZOCombat.Context or {}

local ADDON = EZOCombat
local Context = ADDON.Context

local ROLE_STRING = {
    dd = "SI_EZOCOMBAT_ROLE_DD",
    tank = "SI_EZOCOMBAT_ROLE_TANK",
    healer = "SI_EZOCOMBAT_ROLE_HEALER",
}

function Context.GetDetectedRole()
    if type(GetSelectedLFGRole) ~= "function" then
        return nil
    end

    local ok, role = pcall(GetSelectedLFGRole)
    if not ok then
        return nil
    end
    if role == LFG_ROLE_TANK then
        return "tank"
    end
    if role == LFG_ROLE_HEAL then
        return "healer"
    end
    if role == LFG_ROLE_DPS then
        return "dd"
    end
    return nil
end

function Context.IsRoleAuto()
    return ADDON.sv and ADDON.sv.general and ADDON.sv.general.roleMode ~= "manual"
end

function Context.GetActiveRole()
    if Context.IsRoleAuto() then
        local detected = Context.GetDetectedRole()
        if detected then
            return detected
        end
    end
    return ADDON.sv and ADDON.sv.general and ADDON.sv.general.role or "dd"
end

function Context.GetRoleLabel(role)
    local stringId = _G[ROLE_STRING[role or ""] or ""]
    return stringId and GetString(stringId) or tostring(role or "dd")
end

function Context.GetClassId()
    if type(GetUnitClassId) ~= "function" then
        return 0
    end
    local ok, classId = pcall(GetUnitClassId, "player")
    return ok and tonumber(classId) or 0
end

function Context.GetClassKey()
    return "class-" .. tostring(Context.GetClassId())
end

function Context.GetClassLabel()
    if type(GetUnitClass) == "function" then
        local ok, className = pcall(GetUnitClass, "player")
        if ok and type(className) == "string" and className ~= "" then
            return className
        end
    end
    return string.format("%s %d", GetString(SI_EZOCOMBAT_CLASS), Context.GetClassId())
end

local function IsRadialMenuShown(menu)
    if not menu or type(menu.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(menu.IsShown, menu)
    return ok and shown == true
end

local function IsRadialControllerShown(controller)
    return controller
        and (IsRadialMenuShown(controller.menu) or IsRadialMenuShown(controller.radialMenu))
end

function Context.IsHudOverlayBlocked()
    if INTERACTIVE_WHEEL_MANAGER and type(INTERACTIVE_WHEEL_MANAGER.IsInteracting) == "function" then
        local ok, interacting = pcall(INTERACTIVE_WHEEL_MANAGER.IsInteracting, INTERACTIVE_WHEEL_MANAGER)
        if ok and interacting == true then
            return true
        end
    end

    local controllers = {
        _G.UTILITY_WHEEL_KEYBOARD,
        _G.UTILITY_WHEEL_GAMEPAD,
        _G.FISHING_KEYBOARD,
        _G.FISHING_GAMEPAD,
        _G.TARGET_MARKER_WHEEL_KEYBOARD,
        _G.TARGET_MARKER_WHEEL_GAMEPAD,
        _G.ACCESSIBLE_ASSIGNABLE_UTILITY_WHEEL_GAMEPAD,
    }
    for _, controller in ipairs(controllers) do
        if IsRadialControllerShown(controller) then
            return true
        end
    end

    if PLAYER_TO_PLAYER then
        if IsRadialMenuShown(PLAYER_TO_PLAYER.gamepadMenu)
            or IsRadialMenuShown(PLAYER_TO_PLAYER.keyboardMenu) then
            return true
        end
    end

    return false
end

function Context.RefreshHudVisibility()
    local blocked = Context.IsHudOverlayBlocked()
    if Context._hudOverlayBlocked == blocked then
        return
    end
    Context._hudOverlayBlocked = blocked

    if ADDON.Overlays and type(ADDON.Overlays.Refresh) == "function" then
        ADDON.Overlays.Refresh()
    end
    if ADDON.Window and type(ADDON.Window.RefreshVisibility) == "function" then
        ADDON.Window.RefreshVisibility()
    end
end

function Context.GetActiveProfile()
    if not ADDON.SavedVars or type(ADDON.SavedVars.GetProfile) ~= "function" then
        return nil
    end
    return ADDON.SavedVars.GetProfile(Context.GetClassKey(), Context.GetActiveRole())
end

function Context.Refresh()
    local activeRole = Context.GetActiveRole()
    if Context._activeRole == activeRole then
        return
    end
    Context._activeRole = activeRole

    if ADDON.Overlays and type(ADDON.Overlays.Refresh) == "function" then
        ADDON.Overlays.Refresh()
    end
    if ADDON.Window and type(ADDON.Window.RefreshContext) == "function" then
        ADDON.Window.RefreshContext()
    end
    if ADDON.Settings and type(ADDON.Settings.RequestSettingsRefresh) == "function" then
        ADDON.Settings.RequestSettingsRefresh(true)
    end
end

function Context.Init()
    Context._activeRole = Context.GetActiveRole()
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "RoleContext", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, Context.Refresh)
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "RoleActivated", EVENT_PLAYER_ACTIVATED, Context.Refresh)
    if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForUpdate) == "function" then
        EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "HudVisibility", 100, Context.RefreshHudVisibility)
    end

    -- Keyboard preferred-role controls publish this callback when the player
    -- changes the Group Finder role. The fallback events cover other clients.
    if PREFERRED_ROLES and type(PREFERRED_ROLES.RegisterCallback) == "function" then
        PREFERRED_ROLES:RegisterCallback("LFGRoleChanged", Context.Refresh)
    end
end
