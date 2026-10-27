local addonName, ns = ...

-- Traditional Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhTW" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "已裝備",
    OWNED_BAGS = "在你的背包中",
    OWNED_BANK = "在你的銀行中",
    OWNED_ALT = "在 %s 身上",
    OWNED_MANUAL = "已標記為擁有",
    OWNED_SKIP = "已標記為不需要",
    OWNED_ALTERNATIVE = "你有替代裝備：%s",
    OWNED_USING = "你正裝備替代裝備：%s",
    HINT_MARK = "右鍵：標記為擁有或不需要",
    HELP_SHOW = "|cffffff00/gbis|r：顯示或隱藏最佳裝備面板",
    PANEL_TITLE = "最佳裝備（BiS）",
    PHASE = "第%d階段",
    PHASE_PRERAID = "團隊副本前",
    NO_LIST = "本階段還沒有你職業的最佳裝備清單。",
    HINT_RANKED = "點擊：顯示此欄位的裝備排名",
    TOOLTIP_ITEM_LOADING = "物品 %d（載入中...）",
    TOOLTIP_TOGGLE = "GudaBiS：顯示或隱藏最佳裝備",
    HELP_STATUS = "|cffffff00/gbis status|r：用戶端、功能與 API 來源",
    STATUS_CLIENT = "用戶端：%s（介面版本 %d）",
    STATUS_FEATURES = "功能：%s",
    STATUS_API = "API：%s",
    STATUS_DATA = "BiS 資料：%s · %d 個清單 · %d 個專精 · 預設階段 %d",
    STATUS_DB ="資料庫：結構版本 %d · 從磁碟載入：%s · 載入次數：%d · 角色：%d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r：顯示除錯記錄視窗",
    LOG_TITLE = "GudaBiS 除錯記錄",
    LOG_CLEARED = "除錯記錄已清除。",
    HELP_PROBE = "|cffffff00/gbis probe|r：檢查此用戶端提供哪些 WoW API（寫入除錯記錄）",
    PROBE_DONE = "檢查結果已寫入除錯記錄（/gbis log）。",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r：開啟或關閉除錯模式（在聊天中顯示除錯訊息）",
    UNKNOWN_COMMAND = "未知指令「%s」。請輸入 /gbis help。",
    DEBUG_ON = "除錯模式已開啟。",
    DEBUG_OFF = "除錯模式已關閉。",
}

for key, value in pairs(T) do
    L[key] = value
end
