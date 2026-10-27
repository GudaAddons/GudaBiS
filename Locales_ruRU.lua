local addonName, ns = ...

-- Russian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "ruRU" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: клиент, возможности и источники API",
    STATUS_CLIENT = "Клиент: %s (интерфейс %d)",
    STATUS_FEATURES = "Возможности: %s",
    STATUS_API = "API: %s",
    STATUS_DB = "База данных: схема %d · загружена с диска: %s · загрузок: %d · персонажей: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: окно журнала отладки",
    LOG_TITLE = "Журнал отладки GudaBiS",
    LOG_CLEARED = "Журнал отладки очищен.",
    HELP_PROBE = "|cffffff00/gbis probe|r: какие API WoW есть в этом клиенте (в журнал отладки)",
    PROBE_DONE = "Проверка записана в журнал отладки (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: включить или выключить режим отладки (строки отладки в чате)",
    UNKNOWN_COMMAND = "Неизвестная команда '%s'. Введите /gbis help.",
    DEBUG_ON = "Режим отладки включён.",
    DEBUG_OFF = "Режим отладки выключен.",
}

for key, value in pairs(T) do
    L[key] = value
end
