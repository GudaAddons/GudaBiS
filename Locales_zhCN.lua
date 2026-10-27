local addonName, ns = ...

-- Simplified Chinese. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "zhCN" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "已装备",
    OWNED_BAGS = "在你的背包中",
    OWNED_BANK = "在你的银行中",
    OWNED_ALT = "在 %s 身上",
    OWNED_MANUAL = "已标记为拥有",
    OWNED_SKIP = "已标记为不需要",
    OWNED_ALTERNATIVE = "你有替代装备：%s",
    OWNED_USING = "你正装备替代装备：%s",
    HINT_MARK = "右键：标记为拥有或不需要",
    HELP_SHOW = "|cffffff00/gbis|r：显示或隐藏最佳装备面板",
    PANEL_TITLE = "最佳装备（BiS）",
    PHASE = "第%d阶段",
    PHASE_PRERAID = "团队副本前",
    NO_LIST = "本阶段还没有你职业的最佳装备列表。",
    HINT_RANKED = "点击：显示此栏位的装备排名",
    NEW_LIST = "新建列表",
    DEFAULT_LIST_NAME = "我的列表 %d",
    RENAME_LIST = "重命名列表",
    DELETE_CONFIRM = "删除列表“%s”？",
    COPY_CURRENT = "复制当前显示的列表",
    TOOLTIP_NEW_LIST = "新建列表",
    TOOLTIP_RENAME = "重命名此列表",
    TOOLTIP_DELETE = "删除此列表",
    ROLE_MS = "主",
    ROLE_OS = "副",
    TOOLTIP_MS = "主天赋：拾取提醒和掷骰使用此列表。再次点击可取消。",
    TOOLTIP_OS = "副天赋：副天赋装备的拾取提醒和掷骰使用此列表。再次点击可取消。",
    HINT_CHOOSE = "点击：为此栏位选择装备",
    HINT_PICK = "点击：把此装备放入栏位",
    PICK_CLEAR = "清空此栏位",
    PICK_ID = "物品 ID 或 Wowhead 链接",
    PICK_HINT = "或按住 Shift 点击或拖动任意物品到这里。",
    PICK_WRONG_SLOT = "物品 %d 不适合此栏位。",
    TOOLTIP_ITEM_LOADING = "物品 %d（加载中...）",
    TOOLTIP_TOGGLE = "GudaBiS：显示或隐藏最佳装备",
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
