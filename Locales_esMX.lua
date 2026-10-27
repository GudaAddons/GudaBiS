local addonName, ns = ...

-- Spanish (Latin America). Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "esMX" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Activa o desactiva el modo de depuración (líneas de depuración en el chat)",
    UNKNOWN_COMMAND = "Comando desconocido '%s'. Escribe /gbis help.",
    DEBUG_ON = "Modo de depuración activado.",
    DEBUG_OFF = "Modo de depuración desactivado.",
}

for key, value in pairs(T) do
    L[key] = value
end
