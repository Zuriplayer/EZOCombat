local ADDON = EZOCombat

local CHAT_SYSTEM = CHAT_SYSTEM
local GetCVar = GetCVar
local GetString = GetString
local SLASH_COMMANDS = SLASH_COMMANDS
local tostring = tostring
local type = type
local zo_strlower = zo_strlower

local function Print(message)
    if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    else
        d(message)
    end
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
    Print(GetString(SI_EZOCOMBAT_LOADED))
end
