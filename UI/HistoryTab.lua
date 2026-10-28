-- The panel's History tab (GB-071): a character dropdown (the current one first), a
-- session dropdown (newest first, raids and dungeons together) and that session's drops,
-- one row each: item, who received it ("seen" while nobody has), and how it matched
-- the character's lists at the time.
--
-- Built the first time the tab opens (RULES.md Rule 1), over the gear view of the same
-- panel; the gear view stays as it is underneath. A fixed pool of rows is scrolled with
-- the mouse wheel and repainted, never rebuilt.
--
-- Pure parts, tested offline: HistoryTab.SessionLabel, HistoryTab.Winner,
-- HistoryTab.Tag, HistoryTab.SessionsOf.

local addonName, ns = ...
local L = ns.L

local HistoryTab = ns:RegisterModule("HistoryTab")

local ROWS = 15
local ROW_HEIGHT = 22
local ICON_SIZE = 18
local PADDING = 14
local INSET = 4
local INSET_TOP = 24
local DROPDOWN_TOP = 28
local LIST_TOP = 40
local CHAR_WIDTH = 150
local WINNER_WIDTH = 90
local TAG_WIDTH = 60
local DATE_FORMAT = "%Y-%m-%d %H:%M"
local TAG_COLORS = { ms = "|cff40ff40%s|r", os = "|cff40c0ff%s|r" }

local view, charDropdown, sessionDropdown
local rows = {}
local selectedChar, selectedSession
local offset = 0

function HistoryTab.SessionLabel(session)
    local name = session.difficulty and session.difficulty ~= ""
        and string.format("%s (%s)", session.name, session.difficulty) or session.name
    return string.format(L.HISTORY_SESSION, name, date(DATE_FORMAT, session.started), #session.drops)
end

function HistoryTab.Winner(drop)
    return drop.winner or L.HISTORY_SEEN
end

function HistoryTab.Tag(drop)
    if not drop.role then return "" end
    return string.format(TAG_COLORS[drop.role], ns.Match.Label(drop))
end

-- Every session of one character, raids and dungeons together, newest first.
function HistoryTab.SessionsOf(char)
    local out = ns.History:Sessions("raids", char)
    for _, session in ipairs(ns.History:Sessions("dungeons", char)) do out[#out + 1] = session end
    table.sort(out, function(a, b) return a.started > b.started end)
    return out
end

local function ShowDropTooltip(row)
    if not row.link then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.link)
    ns.ItemTooltip.Compare()
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PADDING - INSET, -LIST_TOP - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", view, "RIGHT", INSET - PADDING, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT")
    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.tag:SetWidth(TAG_WIDTH)
    row.tag:SetJustifyH("RIGHT")
    row.tag:SetPoint("RIGHT")
    row.winner = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.winner:SetWidth(WINNER_WIDTH)
    row.winner:SetJustifyH("LEFT")
    row.winner:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.winner, "LEFT", -6, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:SetScript("OnEnter", ShowDropTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

local function PaintRows()
    local drops = selectedSession and selectedSession.drops or {}
    for i, row in ipairs(rows) do
        local drop = drops[i + offset]
        row.link = drop and drop.link
        if drop then
            row.icon:SetTexture(GetItemIcon and GetItemIcon(drop.itemID) or nil)
            row.name:SetText(drop.link)
            row.winner:SetText(HistoryTab.Winner(drop))
            row.tag:SetText(HistoryTab.Tag(drop))
        end
        row:SetShown(drop ~= nil)
    end
    view.emptyNote:SetShown(#drops == 0)
end

local function OnWheel(_, delta)
    local count = selectedSession and #selectedSession.drops or 0
    offset = math.max(0, math.min(offset - delta * 3, count - ROWS))
    PaintRows()
end

local function SelectSession(session)
    selectedSession = session
    offset = 0
    PaintRows()
end

local function Create(panel)
    view = CreateFrame("Frame", "GudaBiSHistoryView", panel)
    view:SetPoint("TOPLEFT", INSET, -INSET_TOP)
    view:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    view:SetFrameLevel(panel:GetFrameLevel() + 20)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", OnWheel)
    local background = view:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.06, 0.06, 1)

    local margin = ns.Theme.DROPDOWN_MARGIN
    charDropdown = ns.Dropdown.Create(view, CHAR_WIDTH + margin * 2, function(char)
        selectedChar = char
        HistoryTab:Refresh()
    end)
    charDropdown.button:SetPoint("TOPLEFT", PADDING - INSET - margin, INSET_TOP - DROPDOWN_TOP)
    local sessionWidth = panel:GetWidth() - PADDING * 2 - CHAR_WIDTH - 6
    sessionDropdown = ns.Dropdown.Create(view, sessionWidth + margin * 2, SelectSession)
    sessionDropdown.button:SetPoint("LEFT", charDropdown.button, "RIGHT", 6 - margin * 2, 0)

    view.emptyNote = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.emptyNote:SetPoint("TOP", 0, -LIST_TOP - 10)
    view.emptyNote:SetWidth(300)
    view.emptyNote:SetText(L.HISTORY_EMPTY)

    for i = 1, ROWS do CreateRow(i) end
    view:SetScript("OnHide", function() GameTooltip:Hide() end)
end

function HistoryTab:Refresh()
    if not (view and view:IsShown()) then return end
    local player = ns.Database:PlayerKey()
    local chars = ns.History:Characters()
    local options, hasPlayer = {}, false
    for _, char in ipairs(chars) do
        if char == player then hasPlayer = true end
    end
    if player and not hasPlayer then options[1] = { value = player, text = player } end
    for _, char in ipairs(chars) do options[#options + 1] = { value = char, text = char } end
    selectedChar = selectedChar or player
    charDropdown:SetOptions(options, selectedChar)

    local sessions = HistoryTab.SessionsOf(selectedChar)
    local sessionOptions, found = {}, false
    for i, session in ipairs(sessions) do
        sessionOptions[i] = { value = session, text = HistoryTab.SessionLabel(session) }
        if session == selectedSession then found = true end
    end
    if not found then selectedSession, offset = sessions[1], 0 end
    sessionDropdown:SetOptions(sessionOptions, selectedSession)
    PaintRows()
end

function HistoryTab:SetShown(panel, shown)
    if shown and not view then Create(panel) end
    if not view then return end
    view:SetShown(shown)
    if shown then self:Refresh() end
end

function HistoryTab:IsShown()
    return view ~= nil and view:IsShown()
end

ns.Events:Register("GBIS_HISTORY_CHANGED", function() HistoryTab:Refresh() end, "HistoryTab")
