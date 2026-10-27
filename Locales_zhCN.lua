local addonName, ns = ...

-- Simplified Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhCN" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r：客户端、功能和 API 来源",
    STATUS_CLIENT = "客户端：%s（界面版本 %d）",
    STATUS_FEATURES = "功能：%s",
    STATUS_API = "API：%s",
    STATUS_DATA = "BiS 数据：%s · %d 个列表 · %d 个专精 · 默认阶段 %d",
    STATUS_DB ="数据库：结构版本 %d · 从磁盘加载：%s · 加载次数：%d · 角色：%d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r：显示调试日志窗口",
    LOG_TITLE = "GudaBiS 调试日志",
    LOG_CLEARED = "调试日志已清空。",
    HELP_PROBE = "|cffffff00/gbis probe|r：检查此客户端提供哪些 WoW API（写入调试日志）",
    PROBE_DONE = "检查结果已写入调试日志（/gbis log）。",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r：开启或关闭调试模式（在聊天中显示调试信息）",
    UNKNOWN_COMMAND = "未知命令“%s”。请输入 /gbis help。",
    DEBUG_ON = "调试模式已开启。",
    DEBUG_OFF = "调试模式已关闭。",
}

for key, value in pairs(T) do
    L[key] = value
end
