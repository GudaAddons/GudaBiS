-- The ranked items of one slot (author, 2026-10-28): clicking a slot in the panel opens
-- "1. the BiS item, 2., 3. ... the guide's alternatives" next to it, each with its own
-- owned check.
--
-- On a custom list the same flyout is the picker (GB-041, GB-052), for one of three
-- kinds of choice:
--   item    the slot's item: every guide item for the slot; must fit the slot
--   enchant the slot's enchant: every guide enchant for the slot; a spell ID box
--   gem     one socket's gem: every gem the class's guides use; must be a gem; a note
--           when its colour misses the socket (allowed: socket bonuses are sometimes
--           skipped on purpose)
-- A click picks a row, "Clear" empties, and while an item or gem picker is open,
-- shift-clicking any item anywhere picks it; a note at the top of the picker says so.
--
-- The picker shows VISIBLE_ROWS choices at a time, scrolled with the mouse wheel (author,
-- 2026-10-28: a slot can have dozens of guide items). Its box searches the choices by
-- name as you type, or takes an ID or a Wowhead/item link; Enter picks the ID, or the
-- first match. The slot (or enchant/gem icon) being filled stays highlighted while the
-- picker is open. The ranked list (a guide list, no picker) shows every row.
--
-- One flyout for the whole panel, rows reused. It closes when its slot is clicked again,
-- when another slot opens it, when the panel changes list or phase, and with the panel.
--
--   RankFlyout:Toggle(anchor, ids, picker[, ranked])
--       ranked = { list, slot }: the ranked view of a list, whose rows can say how many
--       top players wear each item (top-player lists, GB-131)
--       picker = { kind = "item"|"enchant"|"gem", slot, socket = colour, onPick(id|nil) }
--   RankFlyout:Close(), RankFlyout:Refresh()
--   RankFlyout.Filter(ids, query, nameOf) -> the ids whose name contains query

local addonName, ns = ...
local L = ns.L

local RankFlyout = ns:RegisterModule("RankFlyout")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant
local QualityColor = ns.Items.QualityColor

local WIDTH = 230
local ROW_HEIGHT = 22
local ICON_SIZE = 18
local VISIBLE_ROWS = 4
local PICKER_HEADER = 58
local RANKED_TOP = 6
local PICKING_TEXTURE = "Interface\\Buttons\\CheckButtonHilight"
local RANGE_FORMAT = "%d-%d / %d"
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ID_PLACEHOLDER = { item = "PICK_ID", gem = "PICK_GEM_ID", enchant = "PICK_ENCHANT_ID" }

local flyout
local rows = {}
local owner
local ids
local picker
local linkingOwnRow = false
local ranked
local offset = 0
local shown = {}

local function Kind()
    return picker and picker.kind or "item"
end

local function ParseID(text)
    if Kind() == "enchant" then return ns.Lists.ParseSpellID(text) end
    return ns.Lists.ParseItemID(text)
end

function RankFlyout.Filter(choices, query, nameOf)
    if not query then return choices end
    local out = {}
    for _, id in ipairs(choices) do
        local name = nameOf(id)
        if name and name:lower():find(query, 1, true) then out[#out + 1] = id end
    end
    return out
end

-- An item whose name is not cached yet asks for it; the picker repaints when it arrives.
local function NameOf(id)
    if Kind() == "enchant" then return ns.Compat.SpellName(id) end
    local name = GetItemInfo(id)
    if not name then ns.Items.WhenLoaded(id, function() RankFlyout:Refresh() end) end
    return name
end

-- The search text, lowercased, or nil when the box is empty or holds an ID or a link.
local function Query()
    local text = strtrim(flyout.search.edit:GetText() or "")
    if text == "" or ParseID(text) then return nil end
    return text:lower()
end

local function Mark(anchor, on)
    if not anchor then return end
    local mark = anchor.gudaBiSPicking
    if not mark and on then
        mark = anchor:CreateTexture(nil, "OVERLAY", nil, 3)
        mark:SetTexture(PICKING_TEXTURE)
        mark:SetBlendMode("ADD")
        mark:SetAllPoints()
        anchor.gudaBiSPicking = mark
    end
    if mark then mark:SetShown(on) end
end

-- An error text when id may not go where the picker puts it, else nil.
local function Refusal(id)
    local kind = picker.kind
    if kind == "item" then
        local _, _, _, equipLoc = GetItemInfoInstant(id)
        if not ns.Lists.FitsSlot(equipLoc, picker.slot) then
            return string.format(L.PICK_WRONG_SLOT, id)
        end
    elseif kind == "gem" and not ns.Items.IsGem(id) then
        return string.format(L.PICK_NOT_GEM, id)
    end
    return nil
end

local function Pick(id)
    if not picker then return false end
    local refusal = id and Refusal(id)
    if refusal then
        ns:Print(refusal)
        return false
    end
    local onPick = picker.onPick
    RankFlyout:Close()
    onPick(id)
    return true
end

local function ShowRowTooltip(row)
    if not row.id then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local kind = Kind()
    if kind == "enchant" then
        GameTooltip:SetSpellByID(row.id)
    else
        ns.Items.SetTooltipItem(GameTooltip, ranked and ranked.list, row.id)
    end
    if kind == "item" then
        local text, r, g, b = ns.Owned:Describe(row.id)
        if text then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(text, r, g, b)
        end
    elseif kind == "gem" and not ns.Items.GemMatches(row.id, picker.socket) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GEM_COLOR_MISMATCH, 1, 0.5, 0.25)
    end
    if picker then
        GameTooltip:AddLine(L.HINT_PICK, 0.6, 0.6, 0.6)
    else
        local usage = ranked and ns.Panel.UsageText(ranked.list, ranked.slot, row.index)
        if usage then GameTooltip:AddLine(usage, 0.6, 0.8, 1) end
        GameTooltip:AddLine(L.HINT_MARK, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
    if kind == "item" then
        ns.ItemTooltip.Compare()
        ns.ItemTooltip.Track(row, ShowRowTooltip)
    end
end

local function OnRowClick(row, mouseButton)
    if row.clear then
        Pick(nil)
        return
    end
    local kind = Kind()
    if mouseButton == "RightButton" then
        if kind == "item" then ns.Owned:ToggleManual(row.id) end
        return
    end
    if IsModifiedClick() and kind ~= "enchant" then
        local _, link = GetItemInfo(row.id)
        if link then
            linkingOwnRow = true
            HandleModifiedItemClick(link)
            linkingOwnRow = false
        end
        return
    end
    if picker then Pick(row.id) end
end

local function PlaceRow(row, index, top)
    local y = -top - (index - 1) * ROW_HEIGHT
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 6, y)
    row:SetPoint("TOPRIGHT", -6, y)
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, flyout)
    row:SetHeight(ROW_HEIGHT)
    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("LEFT", 0, 0)
    row.rank:SetWidth(18)
    row.rank:SetJustifyH("RIGHT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture(CHECK_TEXTURE)
    row.check:SetSize(14, 14)
    row.check:SetPoint("RIGHT", -2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.check, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    row:GetHighlightTexture():SetVertexColor(unpack(ns.Theme.COLORS.highlight))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function()
        ns.ItemTooltip.Untrack()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", OnRowClick)
    rows[index] = row
    return row
end

local function PaintCheck(row)
    if Kind() ~= "item" then
        row.check:Hide()
        return
    end
    local state = ns.Owned:State(row.id)
    if state == "alt" then
        row.check:SetDesaturated(true)
        row.check:SetVertexColor(0.7, 0.7, 0.7)
        row.check:Show()
    elseif ns.Owned:Has(row.id) then
        -- The check texture is green itself: yellow needs it greyed first, then tinted.
        local lower = ranked and ns.Owned:LevelState(ranked.list, row.id) == "lower"
        row.check:SetDesaturated(lower)
        if lower then
            row.check:SetVertexColor(1, 0.82, 0)
        else
            row.check:SetVertexColor(1, 1, 1)
        end
        row.check:Show()
    else
        row.check:Hide()
    end
end

local function PaintEnchantRow(row)
    local spellID = row.id
    row.icon:SetTexture(ns.GetSpellTexture and ns.GetSpellTexture(spellID) or UNKNOWN_ICON)
    row.name:SetText(ns.Compat.SpellName(spellID) or string.format(L.SPELL_UNKNOWN, spellID))
    row.name:SetTextColor(1, 1, 1)
end

local function PaintItemRow(row)
    local itemID = row.id
    local _, _, _, _, icon = GetItemInfoInstant(itemID)
    row.icon:SetTexture(icon)
    local name, _, quality = GetItemInfo(itemID)
    if name then
        row.name:SetText(name)
        row.name:SetTextColor(QualityColor(quality))
    else
        row.name:SetText(string.format(L.TOOLTIP_ITEM_LOADING, itemID))
        row.name:SetTextColor(0.6, 0.6, 0.6)
        ns.Items.WhenLoaded(itemID, function()
            if row.id == itemID and flyout:IsShown() then PaintItemRow(row) end
        end)
    end
end

local function PaintRow(row)
    if Kind() == "enchant" then
        PaintEnchantRow(row)
    else
        PaintItemRow(row)
    end
    PaintCheck(row)
end

local function PaintClearRow(row)
    row.id = nil
    row.rank:SetText("")
    row.icon:SetTexture(CLEAR_ICON)
    row.name:SetText(L.PICK_CLEAR)
    row.name:SetTextColor(1, 0.82, 0)
    row.check:Hide()
end

local function OnEnterPressed(edit)
    local text = edit:GetText() or ""
    local id = ParseID(text)
    if not id and Query() then id = shown[1] end
    edit:SetText("")
    edit:ClearFocus()
    if id then Pick(id) end
end

local function CreatePickerHeader()
    local header = CreateFrame("Frame", nil, flyout)
    header:SetHeight(PICKER_HEADER)
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -6, -6)
    local note = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", 4, -2)
    note:SetPoint("RIGHT", -4, 0)
    note:SetJustifyH("LEFT")
    note:SetText(L.PICK_HINT)
    header.note = note
    local edit = CreateFrame("EditBox", nil, header, "InputBoxTemplate")
    edit:SetHeight(20)
    edit:SetPoint("BOTTOMLEFT", 6, 4)
    edit:SetPoint("BOTTOMRIGHT", 0, 4)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", OnEnterPressed)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    header.edit = edit
    local placeholder = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    edit:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        offset = 0
        RankFlyout:Refresh()
    end)
    header.placeholder = placeholder
    flyout.search = header

    local empty = flyout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 12, -PICKER_HEADER - 10)
    empty:SetText(L.PICK_NO_MATCH)
    flyout.empty = empty
    local range = flyout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    range:SetPoint("BOTTOMRIGHT", -12, 10)
    flyout.range = range
end

local function OnWheel(_, delta)
    if not picker then return end
    offset = offset - delta
    RankFlyout:Refresh()
end

local function Create()
    flyout = ns.Theme.Popup("Frame", "GudaBiSRankFlyout", UIParent)
    flyout:SetWidth(WIDTH)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetClampedToScreen(true)
    flyout:EnableMouse(true)
    flyout:EnableMouseWheel(true)
    flyout:SetScript("OnMouseWheel", OnWheel)
    flyout:Hide()
    tinsert(UISpecialFrames, "GudaBiSRankFlyout")
    CreatePickerHeader()
    flyout:SetScript("OnHide", function()
        Mark(owner, false)
        owner = nil
        picker = nil
        ranked = nil
        GameTooltip:Hide()
    end)
end

local function Row(index, top)
    local row = rows[index] or CreateRow(index)
    PlaceRow(row, index, top)
    row:Show()
    return row
end

local function RefreshRanked()
    for i, id in ipairs(ids) do
        local row = Row(i, RANKED_TOP)
        row.clear = nil
        row.id = id
        row.index = i
        row.rank:SetText(i .. ".")
        PaintRow(row)
    end
    return #ids, RANKED_TOP
end

-- VISIBLE_ROWS of the matching choices from offset, then Clear; "a-b / n" when there
-- are more than fit.
local function RefreshPicker()
    local matches = RankFlyout.Filter(ids, Query(), NameOf)
    wipe(shown)
    for i, id in ipairs(matches) do shown[i] = id end
    offset = math.max(0, math.min(offset, #shown - VISIBLE_ROWS))
    local count = math.min(VISIBLE_ROWS, #shown)
    for i = 1, count do
        local row = Row(i, PICKER_HEADER)
        row.clear = nil
        row.id = shown[offset + i]
        row.rank:SetText("")
        PaintRow(row)
    end
    flyout.empty:SetShown(#shown == 0)
    local slots = math.max(count, 1)
    if count == 0 then Row(1, PICKER_HEADER):Hide() end
    local clear = Row(slots + 1, PICKER_HEADER)
    clear.clear = true
    PaintClearRow(clear)
    local range = flyout.range
    range:SetShown(#shown > VISIBLE_ROWS)
    range:SetText(string.format(RANGE_FORMAT, offset + 1, offset + count, #shown))
    flyout.search.placeholder:SetText(L[ID_PLACEHOLDER[picker.kind]])
    flyout.search.note:SetShown(picker.kind ~= "enchant")
    return slots + 1, PICKER_HEADER
end

function RankFlyout:Refresh()
    if not (flyout and flyout:IsShown()) then return end
    flyout.search:SetShown(picker ~= nil)
    flyout.empty:Hide()
    flyout.range:Hide()
    local count, top
    if picker then
        count, top = RefreshPicker()
    else
        count, top = RefreshRanked()
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    flyout:SetHeight(top + count * ROW_HEIGHT + 8)
end

function RankFlyout:IsOpenFor(anchor)
    return flyout ~= nil and flyout:IsShown() and owner == anchor
end

function RankFlyout:Toggle(anchor, choices, pickerOptions, rankedOptions)
    if self:IsOpenFor(anchor) then
        self:Close()
        return
    end
    if not flyout then Create() end
    flyout:Hide()
    owner = anchor
    ids = choices
    picker = pickerOptions
    ranked = rankedOptions
    offset = 0
    flyout.search.edit:SetText("")
    Mark(anchor, picker ~= nil)
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    flyout:Show()
    self:Refresh()
end

function RankFlyout:Close()
    if flyout then flyout:Hide() end
end

-- Shift-clicking an item anywhere while an item or gem picker is open picks it. A
-- post-hook, so the click still does what the game does with it.
local function OnModifiedItemClick(link)
    if linkingOwnRow or not picker or picker.kind == "enchant" then return end
    if not (flyout and flyout:IsShown()) then return end
    local itemID = ns.Lists.ParseItemID(link)
    if itemID then Pick(itemID) end
end

ns.Events:Register("GBIS_INITIALIZED", function()
    if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick) end
end, "RankFlyout")

ns.Events:Register("GBIS_OWNED_CHANGED", function() RankFlyout:Refresh() end, "RankFlyout")
