local ADDON = EZOCombat

local CHAT_SYSTEM = CHAT_SYSTEM
local GetCVar = GetCVar
local GetString = GetString
local SLASH_COMMANDS = SLASH_COMMANDS
local tostring = tostring
local type = type
local zo_strlower = zo_strlower
local LOGGER_TAG = "EZOCombat"
local LANGUAGE_INHERIT = "inherit"
local languageCallbackRegistered = false
local ezocoreRegistered = false
local debugControllerRegistered = false
local layoutSurfacesRegistered = {}

local function Print(message)
    if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    else
        d(message)
    end
end

ADDON.Print = Print

local function LogInfo(message)
    if ADDON._debugLoggerUnavailable == true then
        return false
    end

    local lib = _G.LibDebugLogger
    if type(lib) ~= "function" and type(lib) ~= "table" then
        ADDON._debugLoggerUnavailable = true
        return false
    end

    if not ADDON._debugLogger and type(lib) == "function" then
        local ok, logger = pcall(lib, LOGGER_TAG)
        if ok then
            ADDON._debugLogger = logger
        end
    end
    if not ADDON._debugLogger and type(lib) == "table" and type(lib.Create) == "function" then
        local ok, logger = pcall(function()
            return lib:Create(LOGGER_TAG)
        end)
        if ok then
            ADDON._debugLogger = logger
        end
    end

    local logger = ADDON._debugLogger
    if logger and type(logger.Info) == "function" then
        ADDON._debugLoggerUnavailable = false
        return pcall(function()
            logger:Info(tostring(message or ""))
        end)
    end

    ADDON._debugLoggerUnavailable = true
    return false
end

function ADDON.RegisterSlashCommands()
    SLASH_COMMANDS["/ezocombat"] = function()
        if ADDON.Window and type(ADDON.Window.Toggle) == "function" then
            ADDON.Window.Toggle()
        else
            Print(GetString(SI_EZOCOMBAT_USAGE))
        end
    end
    SLASH_COMMANDS["/ezocombatdebug"] = function()
        ADDON.RunDebugSnapshot()
    end
end

function ADDON.IsDebugModeEnabled()
    return ADDON.sv and ADDON.sv.general and ADDON.sv.general.debugMode == true
end

function ADDON.SetDebugModeEnabled(enabled)
    if not (ADDON.sv and ADDON.sv.general) then
        return false
    end
    ADDON.sv.general.debugMode = enabled == true
    return ADDON.sv.general.debugMode == (enabled == true)
end

function ADDON.DebugLog(message)
    if not ADDON.IsDebugModeEnabled() then
        return false
    end
    local text = "[EZOCombat] " .. tostring(message or "")
    local logged = LogInfo(text)
    if ADDON.sv.general.debugChat == true or not logged then
        Print("|cB040FF" .. text .. "|r")
    end
    return logged
end

function ADDON.RunDebugSnapshot()
    if not ADDON.IsDebugModeEnabled() then
        Print(GetString(SI_EZOCOMBAT_DEBUG_DISABLED))
        return false
    end

    ADDON.DebugLog("snapshot begin")
    if ADDON.ActionBars and type(ADDON.ActionBars.DebugSnapshot) == "function" then
        ADDON.ActionBars.DebugSnapshot()
    end
    if ADDON.Priority and type(ADDON.Priority.DebugSnapshot) == "function" then
        ADDON.Priority.DebugSnapshot()
    end
    if ADDON.Layout and type(ADDON.Layout.DebugSnapshot) == "function" then
        ADDON.Layout.DebugSnapshot()
    end
    if ADDON.PvpTarget and type(ADDON.PvpTarget.DebugSnapshot) == "function" then
        ADDON.PvpTarget.DebugSnapshot()
    end
    if ADDON.PvpSct and type(ADDON.PvpSct.DebugSnapshot) == "function" then
        ADDON.PvpSct.DebugSnapshot()
    end
    if ADDON.Window and type(ADDON.Window.DebugSnapshot) == "function" then
        ADDON.Window.DebugSnapshot()
    end
    ADDON.DebugLog("snapshot end")
    if ADDON._debugLoggerUnavailable == true then
        Print(GetString(SI_EZOCOMBAT_DEBUG_CHAT_FALLBACK))
    else
        Print(GetString(SI_EZOCOMBAT_DEBUG_CAPTURED))
    end
    return true
end

function ADDON.GetClientLanguage()
    local language = zo_strlower(tostring(GetCVar("Language.2") or ""))
    return language == "es" and "es" or "en"
end

function ADDON.GetEffectiveLanguage(language)
    language = tostring(language or LANGUAGE_INHERIT)
    if ADDON.IsLanguageManagedByEZOCore and ADDON.IsLanguageManagedByEZOCore() then
        local ok, inherited = pcall(function()
            return EZOCore:GetLanguage()
        end)
        if ok and (inherited == "es" or inherited == "en") then
            return inherited
        end
    end
    if language == LANGUAGE_INHERIT then
        return ADDON.GetClientLanguage()
    end
    if language == "es" or language == "en" then
        return language
    end
    return ADDON.GetClientLanguage()
end

function ADDON.IsLanguageManagedByEZOCore()
    if not (EZOCore and type(EZOCore.IsLanguageGloballyManaged) == "function") then
        return false
    end
    local ok, managed = pcall(function()
        return EZOCore:IsLanguageGloballyManaged()
    end)
    return ok and managed == true
end

function ADDON.ApplyLanguagePreference(language)
    if EZOCombat_Lang and type(EZOCombat_Lang.Apply) == "function" then
        EZOCombat_Lang.Apply(ADDON.GetEffectiveLanguage(language))
    end
end

function ADDON.RegisterEZOCoreLanguageCallback()
    if languageCallbackRegistered
        or not (EZOCore and type(EZOCore.RegisterCallback) == "function") then
        return false
    end

    local eventName = EZOCore.EVENT_LANGUAGE_CHANGED or "EZO_CORE_LANGUAGE_CHANGED"
    local ok, result = pcall(function()
        return EZOCore:RegisterCallback(eventName, function()
            ADDON.ApplyLanguagePreference(LANGUAGE_INHERIT)
        end)
    end)
    languageCallbackRegistered = ok and result == true
    return languageCallbackRegistered
end

function ADDON.RegisterWithEZOCore()
    if ezocoreRegistered
        or not (EZOCore and type(EZOCore.RegisterAddon) == "function") then
        return false
    end

    local ok, result = pcall(function()
        return EZOCore:RegisterAddon({
            id = "ezocombat",
            name = ADDON.name or "EZOCombat",
            version = ADDON.version or "0.0.0",
            addOnVersion = tonumber(ADDON.addOnVersion) or 0,
            apiVersion = 1,
            capabilities = {
                "combat.research",
                "combat.visual-assistance",
                "pvp.enemy-target-frame",
                "pvp.low-health-alert",
                "pvp.sct-cone",
                "family.debug.controller",
                "family.language.consumer",
                "family.layout.consumer",
                "family.settings.consumer",
            },
        })
    end)

    ezocoreRegistered = ok and result == true
    return ezocoreRegistered
end

function ADDON.RegisterLayoutWithEZOCore()
    if not (EZOCore and type(EZOCore.GetService) == "function") then
        return false
    end
    local service = EZOCore:GetService("family.layout", 1)
    if not service or type(service.RegisterSurface) ~= "function" then
        return false
    end

    local registeredAny = false
    local function RegisterSurface(surface)
        if layoutSurfacesRegistered[surface.id] then
            return false
        end
        local ok, result = pcall(function()
            return service:RegisterSurface(surface)
        end)
        layoutSurfacesRegistered[surface.id] = ok and result == true
        registeredAny = registeredAny or layoutSurfacesRegistered[surface.id]
        return layoutSurfacesRegistered[surface.id]
    end

    if ADDON.Layout then
        RegisterSurface({
            id = "ezocombat.icons",
            addonId = "ezocombat",
            addonName = "EZOCombat",
            name = function() return GetString(SI_EZOCOMBAT_LAYOUT_SURFACE) end,
            tooltip = function() return GetString(SI_EZOCOMBAT_LAYOUT_SURFACE_TOOLTIP) end,
            setEditMode = ADDON.Layout.SetEditMode,
            isEditMode = ADDON.Layout.IsEditMode,
            canEdit = function()
                return ADDON.Layout.IsAutomatic()
                    and ADDON.sv
                    and ADDON.sv.general
                    and ADDON.sv.general.enabled == true
            end,
        })
    end

    if ADDON.PvpTarget then
        RegisterSurface({
            id = "ezocombat.pvp_target",
            addonId = "ezocombat",
            addonName = "EZOCombat",
            name = function() return GetString(SI_EZOCOMBAT_PVP_TARGET_SURFACE) end,
            tooltip = function() return GetString(SI_EZOCOMBAT_PVP_TARGET_SURFACE_TOOLTIP) end,
            sortOrder = 110,
            setEditMode = function(enabled)
                if enabled == true
                    and not (ADDON.sv
                        and ADDON.sv.pvpTarget
                        and ADDON.sv.pvpTarget.enabled == true) then
                    return false
                end
                ADDON.PvpTarget.SetMoveMode(enabled == true)
                return ADDON.PvpTarget.IsMoveMode() == (enabled == true)
            end,
            isEditMode = ADDON.PvpTarget.IsMoveMode,
            canEdit = function()
                return ADDON.sv
                    and ADDON.sv.pvpTarget
                    and ADDON.sv.pvpTarget.enabled == true
            end,
        })
    end

    return registeredAny
end

function ADDON.RegisterDebugWithEZOCore()
    if debugControllerRegistered
        or not (EZOCore and type(EZOCore.GetService) == "function") then
        return false
    end
    local service = EZOCore:GetService("family.debug", 1)
    if not service or type(service.RegisterController) ~= "function" then
        return false
    end
    local ok, result = pcall(function()
        return service:RegisterController({
            id = "ezocombat.debug",
            addonId = "ezocombat",
            addonName = "EZOCombat",
            name = function() return GetString(SI_EZOCOMBAT_DEBUG_MODE) end,
            isEnabled = ADDON.IsDebugModeEnabled,
            setEnabled = function(enabled)
                return ADDON.SetDebugModeEnabled(enabled == true)
            end,
        })
    end)
    debugControllerRegistered = ok and result == true
    return debugControllerRegistered
end

function ADDON:Initialize()
    if self._initialized then
        return
    end

    self._initialized = true

    if self.SavedVars and type(self.SavedVars.Init) == "function" then
        self.SavedVars.Init()
    end
    if self.Context and type(self.Context.Init) == "function" then
        self.Context.Init()
    end

    ADDON.ApplyLanguagePreference(LANGUAGE_INHERIT)
    self:RegisterEZOCoreLanguageCallback()
    self:RegisterWithEZOCore()
    self:RegisterDebugWithEZOCore()

    if self.AbilityState and type(self.AbilityState.Init) == "function" then
        self.AbilityState.Init()
    end
    if self.ActionBars and type(self.ActionBars.Init) == "function" then
        self.ActionBars.Init()
    end
    if self.Priority and type(self.Priority.Init) == "function" then
        self.Priority.Init()
    end
    if self.Layout and type(self.Layout.Init) == "function" then
        self.Layout.Init()
    end
    self:RegisterLayoutWithEZOCore()
    if self.Overlays and type(self.Overlays.Init) == "function" then
        self.Overlays.Init()
    end
    if self.PvpTarget and type(self.PvpTarget.Init) == "function" then
        self.PvpTarget.Init()
    end
    if self.PvpSct and type(self.PvpSct.Init) == "function" then
        self.PvpSct.Init()
    end
    if self.Window and type(self.Window.Init) == "function" then
        self.Window.Init()
    end
    if self.Settings and type(self.Settings.Init) == "function" then
        self.Settings.Init()
    end

    self:RegisterSlashCommands()
    LogInfo(GetString(SI_EZOCOMBAT_LOADED))
    Print(GetString(SI_EZOCOMBAT_LOADED))
end
