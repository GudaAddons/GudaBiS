local addonName, ns = ...

-- Missing keys fall back to the key itself, so an untranslated string is visible
-- rather than an error.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

ns.locale = type(GetLocale) == "function" and GetLocale() or "enUS"

-- enUS (default). Other languages are in Locales_<locale>.lua and replace these keys.
L.HELP_HEADER = "|cff33ccff========== GudaBiS ==========|r"
L.HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Toggle debug mode (debug lines in chat)"

L.UNKNOWN_COMMAND = "Unknown command '%s'. Type /gbis help."
L.DEBUG_ON = "Debug mode on."
L.DEBUG_OFF = "Debug mode off."
