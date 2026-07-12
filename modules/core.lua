local ADDON = EZOCombat

local CHAT_SYSTEM = CHAT_SYSTEM
local GetCVar = GetCVar
local GetString = GetString
local SLASH_COMMANDS = SLASH_COMMANDS
local tostring = tostring
local type = type
local zo_strlower = zo_strlower
local LOGGER_TAG = "EZOCombat"

local function Print(message)
    if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    else
        d(message)
    end
end

local function LogInfo(message)
    local lib = _G.LibDebugLogger
    if type(lib) ~= "function" and type(lib) ~= "table" then
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
        return pcall(function()
            logger:Info(tostring(message or ""))
        end)
    end

    return false
end

function ADDON:RegisterSlashCommands()
    SLASH_COMMANDS["/ezocombat"] = function()
        Print(GetString(SI_EZOCOMBAT_USAGE))
    end
end

function ADDON:Initialize()
    if self._initialized then
        return
    end

    self._initialized = true

    if EZOCombat_Lang and type(EZOCombat_Lang.Apply) == "function" then
        local language = zo_strlower(tostring(GetCVar("Language.2") or ""))
        EZOCombat_Lang.Apply(language == "es" and "es" or "en")
    end

    self:RegisterSlashCommands()
    LogInfo(GetString(SI_EZOCOMBAT_LOADED))
    Print(GetString(SI_EZOCOMBAT_LOADED))
end
