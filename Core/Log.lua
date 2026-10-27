-- In-memory debug log (ring buffer) with a copyable viewer, /gbis log.
-- Anything silent (detection, integrations, probes) writes here through ns:Debug
-- instead of chat. The last lines are kept in GudaBiS_DB.log at logout, so what
-- happened before a /reload can still be read after it.

local addonName, ns = ...
local L = ns.L

local Log = ns:RegisterModule("Log")

local MAX_LINES = 300
local lines = {}
local head = 0
local count = 0

local function Push(line)
    head = head % MAX_LINES + 1
    lines[head] = line
    if count < MAX_LINES then count = count + 1 end
end

function Log:Add(level, msg)
    Push(string.format("%s [%s] %s", date("%H:%M:%S"), level, tostring(msg)))
    if self.frame and self.frame:IsShown() then
        self:RequestRefresh()
    end
end

-- Oldest first.
function Log:Lines()
    local out = {}
    local start = (count < MAX_LINES) and 1 or (head % MAX_LINES + 1)
    for i = 0, count - 1 do
        out[#out + 1] = lines[(start - 1 + i) % MAX_LINES + 1]
    end
    return out
end

function Log:Clear()
    wipe(lines)
    head, count = 0, 0
    if self.frame and self.frame:IsShown() then self:Refresh() end
end

-- The saved lines first, then the ones already logged this session.
function Log:Restore(saved)
    if type(saved) ~= "table" then return end
    local current = self:Lines()
    wipe(lines)
    head, count = 0, 0
    for _, line in ipairs(saved) do
        if type(line) == "string" then Push(line) end
    end
    self:Add("info", "reload")
    for _, line in ipairs(current) do Push(line) end
end

ns.Events:Register("GBIS_INITIALIZED", function()
    Log:Restore(ns.db and ns.db.log)
end, "Log")

ns.Events:Register("PLAYER_LOGOUT", function()
    if ns.db then ns.db.log = Log:Lines() end
end, "Log")

local function CreateLogFrame()
    local name = "GudaBiSLogFrame"
    local ok, frame = pcall(CreateFrame, "Frame", name, UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        frame = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    end
    frame:SetSize(640, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, name)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.LOG_TITLE)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(580)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    scroll:SetScrollChild(edit)

    frame.scroll = scroll
    frame.edit = edit
    frame:Hide()
    return frame
end

function Log:Refresh()
    if not self.frame then return end
    self.frame.edit:SetText(table.concat(self:Lines(), "\n"))
    self.frame.scroll:SetVerticalScroll(self.frame.scroll:GetVerticalScrollRange())
end

-- Bursts of log lines become one redraw.
function Log:RequestRefresh()
    if self.refreshPending then return end
    self.refreshPending = true
    C_Timer.After(0.2, function()
        self.refreshPending = false
        self:Refresh()
    end)
end

function Log:Toggle()
    self.frame = self.frame or CreateLogFrame()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end

ns.SlashCommands:Register("log", function(args)
    if args[1] and args[1]:lower() == "clear" then
        Log:Clear()
        ns:Print(L.LOG_CLEARED)
        return
    end
    Log:Toggle()
end, L.HELP_LOG)
