local addonName, ns = ...

-- German. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "deDE" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: Client, Funktionen und API-Quellen",
    STATUS_CLIENT = "Client: %s (Interface %d)",
    STATUS_FEATURES = "Funktionen: %s",
    STATUS_API = "API: %s",
    STATUS_DATA = "BiS-Daten: %s · %d Listen · %d Spezialisierungen · Standardphase %d",
    STATUS_DB ="Datenbank: Schema %d · von der Festplatte geladen: %s · Ladevorgänge: %d · Charaktere: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: Fenster mit dem Debug-Protokoll",
    LOG_TITLE = "GudaBiS Debug-Protokoll",
    LOG_CLEARED = "Debug-Protokoll geleert.",
    HELP_PROBE = "|cffffff00/gbis probe|r: welche WoW-APIs dieser Client bietet (ins Debug-Protokoll)",
    PROBE_DONE = "Prüfung ins Debug-Protokoll geschrieben (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Debug-Modus umschalten (Debug-Zeilen im Chat)",
    UNKNOWN_COMMAND = "Unbekannter Befehl '%s'. Gib /gbis help ein.",
    DEBUG_ON = "Debug-Modus an.",
    DEBUG_OFF = "Debug-Modus aus.",
}

for key, value in pairs(T) do
    L[key] = value
end
