local addonName, ns = ...

-- Russian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "ruRU" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: включить или выключить режим отладки (строки отладки в чате)",
    UNKNOWN_COMMAND = "Неизвестная команда '%s'. Введите /gbis help.",
    DEBUG_ON = "Режим отладки включён.",
    DEBUG_OFF = "Режим отладки выключен.",
}

for key, value in pairs(T) do
    L[key] = value
end
