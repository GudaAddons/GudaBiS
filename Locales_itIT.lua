local addonName, ns = ...

-- Italian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "itIT" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: client, funzionalità e origine delle API",
    STATUS_CLIENT = "Client: %s (interfaccia %d)",
    STATUS_FEATURES = "Funzionalità: %s",
    STATUS_API = "API: %s",
    STATUS_DB = "Database: schema %d · caricato dal disco: %s · caricamenti: %d · personaggi: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: mostra la finestra del registro di debug",
    LOG_TITLE = "Registro di debug di GudaBiS",
    LOG_CLEARED = "Registro di debug svuotato.",
    HELP_PROBE = "|cffffff00/gbis probe|r: quali API di WoW offre questo client (nel registro di debug)",
    PROBE_DONE = "Verifica scritta nel registro di debug (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: attiva o disattiva la modalità debug (righe di debug in chat)",
    UNKNOWN_COMMAND = "Comando sconosciuto '%s'. Digita /gbis help.",
    DEBUG_ON = "Modalità debug attivata.",
    DEBUG_OFF = "Modalità debug disattivata.",
}

for key, value in pairs(T) do
    L[key] = value
end
