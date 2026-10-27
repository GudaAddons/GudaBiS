-- The ranked items of one slot (author, 2026-10-28): clicking a slot in the panel opens
-- "1. the BiS item, 2., 3. ... the guide's alternatives" next to it, each with its own
-- owned check. It replaces the alternatives list that used to sit in the slot tooltip.
--
-- One flyout for the whole panel, rows reused. It closes when its slot is clicked again,
-- when another slot opens it, when the panel changes list or phase, and with the panel.
-- M4's item picker for custom lists reuses it.
--
--   RankFlyout:Toggle(slotButton, items)   opens to the right of the slot
--   RankFlyout:Close(), RankFlyout:Refresh()

local addonName, ns = ...
local L = ns.L

local RankFlyout = ns:RegisterModule("RankFlyout")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

local WIDTH = 230
local ROW_HEIGHT = 22
local ICON_SIZE = 18
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

local QualityColor = ns.Items.QualityColor

local flyout
local rows = {}
local owner
local items

local function ShowRowTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.item)
    local text, r, g, b = ns.Owned:Describe(row.item)
    if text then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(text, r, g, b)
    end
    GameTooltip:AddLine(L.HINT_MARK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnRowClick(row, mouseButton)
    if mouseButton == "RightButton" then
        ns.Owned:ToggleManual(row.item)
        return
    end
    if not IsModifiedClick() then return end
    local _, link = GetItemInfo(row.item)
    if link then HandleModifiedItemClick(link) end
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, flyout)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", -6, -6 - (index - 1) * ROW_HEIGHT)
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
    local state = ns.Owned:State(itemID)
    if state == "alt" then
        row.check:SetDesaturated(true)
        row.check:SetVertexColor(0.7, 0.7, 0.7)
        row.check:Show()
    elseif ns.Owned:Has(itemID) then
        row.check:SetDesaturated(false)
        row.check:SetVertexColor(1, 1, 1)
        row.check:Show()
    else
        row.check:Hide()
    end
end

local function Create()
    flyout = ns.Theme.CreateWindow("Frame", "GudaBiSRankFlyout", UIParent)
    flyout:SetWidth(WIDTH)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetClampedToScreen(true)
    flyout:EnableMouse(true)
    flyout:Hide()
    tinsert(UISpecialFrames, "GudaBiSRankFlyout")
    flyout:SetScript("OnHide", function()
        owner = nil
        GameTooltip:Hide()
    end)
end

function RankFlyout:Refresh()
    if not (flyout and flyout:IsShown()) then return end
    for i, itemID in ipairs(items) do
        local row = rows[i] or CreateRow(i)
        row.item = itemID
        row.rank:SetText(i .. ".")
        PaintRow(row)
        row:Show()
    end
    for i = #items + 1, #rows do rows[i]:Hide() end
    flyout:SetHeight(12 + #items * ROW_HEIGHT)
end

function RankFlyout:IsOpenFor(button)
    return flyout ~= nil and flyout:IsShown() and owner == button
end

function RankFlyout:Toggle(button, rankedItems)
    if self:IsOpenFor(button) then
        self:Close()
        return
    end
    if not flyout then Create() end
    owner = button
    items = rankedItems
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0)
    flyout:Show()
    self:Refresh()
end

function RankFlyout:Close()
    if flyout then flyout:Hide() end
end

ns.Events:Register("GBIS_OWNED_CHANGED", function() RankFlyout:Refresh() end, "RankFlyout")
