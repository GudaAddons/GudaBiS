local addonName, ns = ...

-- Italian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "itIT" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: client, funzionalità e origine delle API",
    STATUS_CLIENT = "Client: %s (interfaccia %d)",
    STATUS_FEATURES = "Funzionalità: %s",
    STATUS_API = "API: %s",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: attiva o disattiva la modalità debug (righe di debug in chat)",
    UNKNOWN_COMMAND = "Comando sconosciuto '%s'. Digita /gbis help.",
    DEBUG_ON = "Modalità debug attivata.",
    DEBUG_OFF = "Modalità debug disattivata.",
}

for key, value in pairs(T) do
    L[key] = value
end
