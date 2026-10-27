local addonName, ns = ...

-- Traditional Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhTW" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r：用戶端、功能與 API 來源",
    STATUS_CLIENT = "用戶端：%s（介面版本 %d）",
    STATUS_FEATURES = "功能：%s",
    STATUS_API = "API：%s",
    STATUS_DB = "資料庫：結構版本 %d · 從磁碟載入：%s · 載入次數：%d · 角色：%d",
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
