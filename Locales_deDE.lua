local addonName, ns = ...

-- German. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "deDE" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: Client, Funktionen und API-Quellen",
    STATUS_CLIENT = "Client: %s (Interface %d)",
    STATUS_FEATURES = "Funktionen: %s",
    STATUS_API = "API: %s",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Debug-Modus umschalten (Debug-Zeilen im Chat)",
    UNKNOWN_COMMAND = "Unbekannter Befehl '%s'. Gib /gbis help ein.",
    DEBUG_ON = "Debug-Modus an.",
    DEBUG_OFF = "Debug-Modus aus.",
}

for key, value in pairs(T) do
    L[key] = value
end
