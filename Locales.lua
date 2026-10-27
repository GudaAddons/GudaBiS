local addonName, ns = ...

-- Missing keys fall back to the key itself, so an untranslated string is visible
-- rather than an error.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

ns.locale = type(GetLocale) == "function" and GetLocale() or "enUS"

-- enUS (default). Other languages are in Locales_<locale>.lua and replace these keys.
L.HELP_HEADER = "|cff33ccff========== GudaBiS ==========|r"
L.HELP_STATUS = "|cffffff00/gbis status|r: Client, feature flags and API sources"
L.HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Toggle debug mode (debug lines in chat)"
L.HELP_LOG = "|cffffff00/gbis log [clear]|r: Show the debug log window"
L.HELP_PROBE = "|cffffff00/gbis probe|r: Report which WoW APIs this client offers (written to the debug log)"
L.PROBE_DONE = "Probe written to the debug log (/gbis log)."

L.LOG_TITLE = "GudaBiS debug log"
L.LOG_CLEARED = "Debug log cleared."
L.STATUS_DB = "Database: schema %d · loaded from disk: %s · loads: %d · characters: %d"

L.STATUS_CLIENT = "Client: %s (interface %d)"
L.STATUS_FEATURES = "Features: %s"
L.STATUS_API = "API: %s"

L.UNKNOWN_COMMAND = "Unknown command '%s'. Type /gbis help."
L.DEBUG_ON = "Debug mode on."
L.DEBUG_OFF = "Debug mode off."
