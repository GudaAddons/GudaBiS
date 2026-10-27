local addonName, ns = ...

-- Russian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "ruRU" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "Надето на вас",
    OWNED_BAGS = "В ваших сумках",
    OWNED_BANK = "В вашем банке",
    OWNED_ALT = "У персонажа %s",
    OWNED_MANUAL = "Отмечено как полученное",
    OWNED_SKIP = "Отмечено как ненужное",
    OWNED_ALTERNATIVE = "У вас есть альтернатива: %s",
    OWNED_USING = "На вас надета альтернатива: %s",
    HINT_MARK = "Правый клик: отметить как полученное или ненужное",
    HELP_SHOW = "|cffffff00/gbis|r: показать или скрыть панель лучшей экипировки",
    PANEL_TITLE = "Лучшая экипировка (BiS)",
    PHASE = "Фаза %d",
    PHASE_PRERAID = "До рейдов",
    NO_LIST = "Для вашего класса в этой фазе пока нет списка лучшей экипировки.",
    HINT_RANKED = "Клик: показать рейтинг предметов для этой ячейки",
    NEW_LIST = "Новый список",
    DEFAULT_LIST_NAME = "Мой список %d",
    RENAME_LIST = "Переименовать список",
    DELETE_CONFIRM = "Удалить список \"%s\"?",
    COPY_CURRENT = "Скопировать показанный список",
    TOOLTIP_NEW_LIST = "Новый список",
    TOOLTIP_RENAME = "Переименовать этот список",
    TOOLTIP_DELETE = "Удалить этот список",
    ROLE_MS = "ОС",
    ROLE_OS = "ДС",
    TOOLTIP_MS = "Основная специализация: оповещения о добыче и броски используют этот список. Щёлкните ещё раз, чтобы снять.",
    TOOLTIP_OS = "Дополнительная специализация: оповещения о добыче и броски используют этот список для предметов второй специализации. Щёлкните ещё раз, чтобы снять.",
    HINT_CHOOSE = "Клик: выбрать предмет для этой ячейки",
    HINT_PICK = "Клик: положить этот предмет в ячейку",
    PICK_CLEAR = "Очистить ячейку",
    PICK_ID = "ID предмета или ссылка Wowhead",
    PICK_HINT = "Или Shift-клик либо перетащите сюда любой предмет.",
    PICK_WRONG_SLOT = "Предмет %d не подходит для этой ячейки.",
    TOOLTIP_ITEM_LOADING = "Предмет %d (загрузка...)",
    TOOLTIP_TOGGLE = "GudaBiS: показать или скрыть лучшую экипировку",
    HELP_STATUS = "|cffffff00/gbis status|r: клиент, возможности и источники API",
    STATUS_CLIENT = "Клиент: %s (интерфейс %d)",
    STATUS_FEATURES = "Возможности: %s",
    STATUS_API = "API: %s",
    STATUS_DATA = "Данные BiS: %s · списков: %d · специализаций: %d · фаза по умолчанию %d",
    STATUS_DB ="База данных: схема %d · загружена с диска: %s · загрузок: %d · персонажей: %d",
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
