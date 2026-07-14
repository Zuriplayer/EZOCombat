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

local function Print(message)
    if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    else
        d(message)
    end
end

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

function ADDON:RegisterSlashCommands()
    SLASH_COMMANDS["/ezocombat"] = function()
        Print(GetString(SI_EZOCOMBAT_USAGE))
    end
end

function ADDON:GetClientLanguage()
    local language = zo_strlower(tostring(GetCVar("Language.2") or ""))
    return language == "es" and "es" or "en"
end

function ADDON:GetEffectiveLanguage(language)
    language = tostring(language or LANGUAGE_INHERIT)
    if language == LANGUAGE_INHERIT then
        if EZOCore and type(EZOCore.GetLanguage) == "function" then
            local ok, inherited = pcall(function()
                return EZOCore:GetLanguage()
            end)
            if ok and (inherited == "es" or inherited == "en") then
                return inherited
            end
        end
        return self:GetClientLanguage()
    end
    if language == "es" or language == "en" then
        return language
    end
    return self:GetClientLanguage()
end

function ADDON:ApplyLanguagePreference(language)
    if EZOCombat_Lang and type(EZOCombat_Lang.Apply) == "function" then
        EZOCombat_Lang.Apply(self:GetEffectiveLanguage(language))
    end
end

function ADDON:RegisterEZOCoreLanguageCallback()
    if languageCallbackRegistered
        or not (EZOCore and type(EZOCore.RegisterCallback) == "function") then
        return false
    end

    local eventName = EZOCore.EVENT_LANGUAGE_CHANGED or "EZO_CORE_LANGUAGE_CHANGED"
    local ok, result = pcall(function()
        return EZOCore:RegisterCallback(eventName, function()
            self:ApplyLanguagePreference(LANGUAGE_INHERIT)
        end)
    end)
    languageCallbackRegistered = ok and result == true
    return languageCallbackRegistered
end

function ADDON:Initialize()
    if self._initialized then
        return
    end

    self._initialized = true

    self:ApplyLanguagePreference(LANGUAGE_INHERIT)
    self:RegisterEZOCoreLanguageCallback()

    self:RegisterSlashCommands()
    LogInfo(GetString(SI_EZOCOMBAT_LOADED))
    Print(GetString(SI_EZOCOMBAT_LOADED))
end
