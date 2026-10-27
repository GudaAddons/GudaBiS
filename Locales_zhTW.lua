local addonName, ns = ...

-- Traditional Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhTW" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r：開啟或關閉除錯模式（在聊天中顯示除錯訊息）",
    UNKNOWN_COMMAND = "未知指令「%s」。請輸入 /gbis help。",
    DEBUG_ON = "除錯模式已開啟。",
    DEBUG_OFF = "除錯模式已關閉。",
}

for key, value in pairs(T) do
    L[key] = value
end
