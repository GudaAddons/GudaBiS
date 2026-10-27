local addonName, ns = ...

-- German. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "deDE" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "Du hast es angelegt",
    OWNED_BAGS = "In deinen Taschen",
    OWNED_BANK = "In deiner Bank",
    OWNED_ALT = "Bei %s",
    OWNED_MANUAL = "Als vorhanden markiert",
    OWNED_SKIP = "Als nicht benötigt markiert",
    OWNED_ALTERNATIVE = "Du hast eine Alternative: %s",
    HINT_MARK = "Rechtsklick: als vorhanden oder nicht benötigt markieren",
    HELP_SHOW = "|cffffff00/gbis|r: Best-in-Slot-Fenster zeigen oder verbergen",
    PANEL_TITLE = "Beste Ausrüstung (BiS)",
    PHASE = "Phase %d",
    PHASE_PRERAID = "Vor den Schlachtzügen",
    NO_LIST = "Für deine Klasse gibt es in dieser Phase noch keine Best-in-Slot-Liste.",
    HINT_RANKED = "Klick: Rangliste der Gegenstände für diesen Platz zeigen",
    TOOLTIP_ITEM_LOADING = "Gegenstand %d (wird geladen ...)",
    TOOLTIP_TOGGLE = "GudaBiS: Best-in-Slot-Ausrüstung zeigen oder verbergen",
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
