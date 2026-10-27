local addonName, ns = ...

-- Spanish (Latin America). Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "esMX" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: Cliente, funciones y fuentes de la API",
    STATUS_CLIENT = "Cliente: %s (interfaz %d)",
    STATUS_FEATURES = "Funciones: %s",
    STATUS_API = "API: %s",
    STATUS_DB = "Base de datos: esquema %d · cargada del disco: %s · cargas: %d · personajes: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: Muestra la ventana del registro de depuración",
    LOG_TITLE = "Registro de depuración de GudaBiS",
    LOG_CLEARED = "Registro de depuración borrado.",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: Activa o desactiva el modo de depuración (líneas de depuración en el chat)",
    UNKNOWN_COMMAND = "Comando desconocido '%s'. Escribe /gbis help.",
    DEBUG_ON = "Modo de depuración activado.",
    DEBUG_OFF = "Modo de depuración desactivado.",
}

for key, value in pairs(T) do
    L[key] = value
end
