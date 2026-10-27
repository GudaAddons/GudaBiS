local addonName, ns = ...

-- French. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "frFR" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r : active ou désactive le mode débogage (lignes de débogage dans le chat)",
    UNKNOWN_COMMAND = "Commande inconnue « %s ». Tapez /gbis help.",
    DEBUG_ON = "Mode débogage activé.",
    DEBUG_OFF = "Mode débogage désactivé.",
}

for key, value in pairs(T) do
    L[key] = value
end
