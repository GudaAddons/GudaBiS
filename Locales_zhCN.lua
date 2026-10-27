local addonName, ns = ...

-- Simplified Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhCN" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r：开启或关闭调试模式（在聊天中显示调试信息）",
    UNKNOWN_COMMAND = "未知命令“%s”。请输入 /gbis help。",
    DEBUG_ON = "调试模式已开启。",
    DEBUG_OFF = "调试模式已关闭。",
}

for key, value in pairs(T) do
    L[key] = value
end
