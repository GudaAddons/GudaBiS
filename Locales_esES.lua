local addonName, ns = ...

-- Spanish (Spain). Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "esES" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: Cliente, funciones y fuentes de la API",
    STATUS_CLIENT = "Cliente: %s (interfaz %d)",
    STATUS_FEATURES = "Funciones: %s",
    STATUS_API = "API: %s",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Activa o desactiva el modo de depuración (líneas de depuración en el chat)",
    UNKNOWN_COMMAND = "Comando desconocido '%s'. Escribe /gbis help.",
    DEBUG_ON = "Modo de depuración activado.",
    DEBUG_OFF = "Modo de depuración desactivado.",
}

for key, value in pairs(T) do
    L[key] = value
end
