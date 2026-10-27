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
-- A click picks a row, "Clear" empties, the box takes an ID or a Wowhead/item link, and
-- while an item or gem picker is open, shift-clicking any item anywhere picks it.
--
-- One flyout for the whole panel, rows reused. It closes when its slot is clicked again,
-- when another slot opens it, when the panel changes list or phase, and with the panel.
--
--   RankFlyout:Toggle(anchor, ids, picker)
--       picker = { kind = "item"|"enchant"|"gem", slot, socket = colour, onPick(id|nil) }
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
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ID_PLACEHOLDER = { item = "PICK_ID", gem = "PICK_GEM_ID", enchant = "PICK_ENCHANT_ID" }

local flyout
local rows = {}
local owner
local ids
local picker
local linkingOwnRow = false

local function Kind()
    return picker and picker.kind or "item"
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
        GameTooltip:SetItemByID(row.id)
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
        GameTooltip:AddLine(L.HINT_MARK, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
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
        row.check:SetDesaturated(false)
        row.check:SetVertexColor(1, 1, 1)
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

local function OnIdEntered(edit)
    local text = edit:GetText()
    local id
    if Kind() == "enchant" then
        id = ns.Lists.ParseSpellID(text)
    else
        id = ns.Lists.ParseItemID(text)
    end
    edit:SetText("")
    edit:ClearFocus()
    if id then Pick(id) end
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
    edit:SetScript("OnTextChanged", function(self) placeholder:SetShown(self:GetText() == "") end)
    footer.placeholder = placeholder
    local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, -6)
    hint:SetPoint("RIGHT", 0, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PICK_HINT)
    footer.hint = hint
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
    for _, id in ipairs(ids) do
        count = count + 1
        local row = rows[count] or CreateRow(count)
        row.clear = nil
        row.id = id
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
    local footer = flyout.footer
    footer:SetShown(picker ~= nil)
    if picker then
        footer.placeholder:SetText(L[ID_PLACEHOLDER[picker.kind]])
        footer.hint:SetShown(picker.kind ~= "enchant")
    end
    flyout:SetHeight(12 + count * ROW_HEIGHT + (picker and PICKER_FOOTER or 0))
end

function RankFlyout:IsOpenFor(anchor)
    return flyout ~= nil and flyout:IsShown() and owner == anchor
end

function RankFlyout:Toggle(anchor, choices, pickerOptions)
    if self:IsOpenFor(anchor) then
        self:Close()
        return
    end
    if not flyout then Create() end
    flyout:Hide()
    owner = anchor
    ids = choices
    picker = pickerOptions
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
