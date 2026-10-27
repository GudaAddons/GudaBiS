-- The ranked items of one slot (author, 2026-10-28): clicking a slot in the panel opens
-- "1. the BiS item, 2., 3. ... the guide's alternatives" next to it, each with its own
-- owned check.
--
-- On a custom list the same flyout is the item picker (GB-041): the rows are every
-- guide item for that slot, a click puts one in the slot, a "Clear" row empties it, and
-- a box takes an item ID or a Wowhead/item link. While the picker is open, shift-clicking
-- any item (bags, chat, AtlasLoot) also picks it; items that do not fit the slot are
-- refused with a chat line.
--
-- One flyout for the whole panel, rows reused. It closes when its slot is clicked again,
-- when another slot opens it, when the panel changes list or phase, and with the panel.
--
--   RankFlyout:Toggle(slotButton, items, picker)   picker = { slot, onPick(itemID|nil) }
--   RankFlyout:Close(), RankFlyout:Refresh()

local addonName, ns = ...
local L = ns.L

local RankFlyout = ns:RegisterModule("RankFlyout")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant
local QualityColor = ns.Items.QualityColor

local WIDTH = 230
local ROW_HEIGHT = 22
local ICON_SIZE = 18
local PICKER_FOOTER = 52
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local flyout
local rows = {}
local owner
local items
local picker
local linkingOwnRow = false

-- Puts itemID in the picker's slot when it fits there; says why not otherwise.
local function Pick(itemID)
    if not picker then return false end
    if itemID then
        local _, _, _, equipLoc = GetItemInfoInstant(itemID)
        if not ns.Lists.FitsSlot(equipLoc, picker.slot) then
            ns:Print(string.format(L.PICK_WRONG_SLOT, itemID))
            return false
        end
    end
    local onPick = picker.onPick
    RankFlyout:Close()
    onPick(itemID)
    return true
end

local function ShowRowTooltip(row)
    if not row.item then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.item)
    local text, r, g, b = ns.Owned:Describe(row.item)
    if text then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(text, r, g, b)
    end
    GameTooltip:AddLine(picker and L.HINT_PICK or L.HINT_MARK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnRowClick(row, mouseButton)
    if row.clear then
        Pick(nil)
        return
    end
    if mouseButton == "RightButton" then
        ns.Owned:ToggleManual(row.item)
        return
    end
    if IsModifiedClick() then
        local _, link = GetItemInfo(row.item)
        if link then
            linkingOwnRow = true
            HandleModifiedItemClick(link)
            linkingOwnRow = false
        end
        return
    end
    if picker then Pick(row.item) end
end

local function RowTop(index)
    return -6 - (index - 1) * ROW_HEIGHT
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, flyout)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 6, RowTop(index))
    row:SetPoint("TOPRIGHT", -6, RowTop(index))
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
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", OnRowClick)
    rows[index] = row
    return row
end

local function PaintCheck(row)
    local state = ns.Owned:State(row.item)
    if state == "alt" then
        row.check:SetDesaturated(true)
        row.check:SetVertexColor(0.7, 0.7, 0.7)
        row.check:Show()
    elseif ns.Owned:Has(row.item) then
        row.check:SetDesaturated(false)
        row.check:SetVertexColor(1, 1, 1)
        row.check:Show()
    else
        row.check:Hide()
    end
end

local function PaintRow(row)
    local itemID = row.item
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
            if row.item == itemID and flyout:IsShown() then PaintRow(row) end
        end)
    end
    PaintCheck(row)
end

local function PaintClearRow(row)
    row.item = nil
    row.rank:SetText("")
    row.icon:SetTexture(CLEAR_ICON)
    row.name:SetText(L.PICK_CLEAR)
    row.name:SetTextColor(1, 0.82, 0)
    row.check:Hide()
end

local function OnIdEntered(edit)
    local itemID = ns.Lists.ParseItemID(edit:GetText())
    edit:SetText("")
    edit:ClearFocus()
    if itemID then Pick(itemID) end
end

local function CreateFooter()
    local footer = CreateFrame("Frame", nil, flyout)
    footer:SetHeight(PICKER_FOOTER)
    footer:SetPoint("BOTTOMLEFT", 6, 6)
    footer:SetPoint("BOTTOMRIGHT", -6, 6)
    local edit = CreateFrame("EditBox", nil, footer, "InputBoxTemplate")
    edit:SetHeight(20)
    edit:SetPoint("TOPLEFT", 6, -2)
    edit:SetPoint("TOPRIGHT", 0, -2)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", OnIdEntered)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    footer.edit = edit
    local placeholder = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(L.PICK_ID)
    edit:SetScript("OnTextChanged", function(self) placeholder:SetShown(self:GetText() == "") end)
    local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, -6)
    hint:SetPoint("RIGHT", 0, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PICK_HINT)
    flyout.footer = footer
end

local function Create()
    flyout = ns.Theme.Popup("Frame", "GudaBiSRankFlyout", UIParent)
    flyout:SetWidth(WIDTH)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetClampedToScreen(true)
    flyout:EnableMouse(true)
    flyout:Hide()
    tinsert(UISpecialFrames, "GudaBiSRankFlyout")
    CreateFooter()
    flyout:SetScript("OnHide", function()
        owner = nil
        picker = nil
        GameTooltip:Hide()
    end)
end

function RankFlyout:Refresh()
    if not (flyout and flyout:IsShown()) then return end
    local count = 0
    for _, itemID in ipairs(items) do
        count = count + 1
        local row = rows[count] or CreateRow(count)
        row.clear = nil
        row.item = itemID
        row.rank:SetText(picker and "" or (count .. "."))
        PaintRow(row)
        row:Show()
    end
    if picker then
        count = count + 1
        local row = rows[count] or CreateRow(count)
        row.clear = true
        PaintClearRow(row)
        row:Show()
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    flyout.footer:SetShown(picker ~= nil)
    flyout:SetHeight(12 + count * ROW_HEIGHT + (picker and PICKER_FOOTER or 0))
end

function RankFlyout:IsOpenFor(button)
    return flyout ~= nil and flyout:IsShown() and owner == button
end

function RankFlyout:Toggle(button, rankedItems, pickerOptions)
    if self:IsOpenFor(button) then
        self:Close()
        return
    end
    if not flyout then Create() end
    flyout:Hide()
    owner = button
    items = rankedItems
    picker = pickerOptions
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0)
    flyout:Show()
    self:Refresh()
end

function RankFlyout:Close()
    if flyout then flyout:Hide() end
end

-- Shift-clicking an item anywhere while the picker is open picks it. A post-hook, so
-- the click still does what the game does with it.
local function OnModifiedItemClick(link)
    if linkingOwnRow or not picker or not (flyout and flyout:IsShown()) then return end
    local itemID = ns.Lists.ParseItemID(link)
    if itemID then Pick(itemID) end
end

ns.Events:Register("GBIS_INITIALIZED", function()
    if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick) end
end, "RankFlyout")

ns.Events:Register("GBIS_OWNED_CHANGED", function() RankFlyout:Refresh() end, "RankFlyout")
