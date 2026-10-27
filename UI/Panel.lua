-- The BiS panel (GB-020/021/022): a paperdoll-style window docked to the right of the
-- Character frame, opened by a side tab or by /gbis.
--
-- The side tab sticks out of the right edge, outside the Character frame, because the
-- inside of the frame is where Outfitter and similar addons put their buttons (author,
-- 2026-10-28). It looks like the spellbook's school tabs and moves to the panel's right
-- edge while the panel is open, so it stays reachable.
--
-- Nothing is built at login (RULES.md Rule 1): the tab is made the first time the
-- Character frame shows, the panel the first time it opens. Switching phase or list
-- repaints the same slot buttons; frames are never rebuilt.
--
-- Pure parts, tested offline: Panel.SlotView, Panel.ListLabel, Panel.PhaseLabel.

local addonName, ns = ...
local L = ns.L

local Panel = ns:RegisterModule("Panel")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

-- The Wowhead gear-planner layout (author, 2026-10-28): left column icon then name,
-- right column name then icon (right-aligned), weapons centred along the bottom with
-- the name under the icon. Each slot has its enchant icon on the outer side and its
-- gems under the name. No shirt or tabard: guides never list them.
Panel.LEFT_SLOTS = { 1, 2, 3, 15, 5, 9, 10 }
Panel.RIGHT_SLOTS = { 6, 7, 8, 11, 12, 13, 14 }
Panel.BOTTOM_SLOTS = { 16, 17, 18 }

local SLOT_SIZE = 32
local ENCHANT_SIZE = 16
local GEM_SIZE = 14
local NAME_WIDTH = 132
local ROW_HEIGHT = 44
local PADDING = 12
local HEADER_HEIGHT = 70
local WEAPON_ROW_HEIGHT = 66
local WEAPON_SPACING = 124
local COLUMN_WIDTH = ENCHANT_SIZE + 4 + SLOT_SIZE + 6 + NAME_WIDTH
local WIDTH = PADDING * 2 + COLUMN_WIDTH * 2 + 12
local HEIGHT = HEADER_HEIGHT + #Panel.LEFT_SLOTS * ROW_HEIGHT + WEAPON_ROW_HEIGHT + PADDING
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local SLOT_NAMES = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
    [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}

local TOGGLE_ICON = "Interface\\Icons\\INV_Chest_Plate06"
local TAB_BACKGROUND = "Interface\\SpellBook\\SpellBook-SkillLineTab"
local TAB_TOP = -60
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local QUALITY_BORDER = "Interface\\Common\\WhiteIconFrame"

local NO_ALTS = {}

-- What one slot button shows for a list (nil list = an empty paperdoll).
function Panel.SlotView(list, slot)
    return {
        slot = slot,
        item = list and list.items[slot] or nil,
        alts = list and list.alts and list.alts[slot] or NO_ALTS,
        enchant = list and list.enchants and list.enchants[slot] or nil,
        gems = list and list.gems and list.gems[slot] or NO_ALTS,
    }
end

-- "Protection · Balanced set": the client's own tree name, then the guide's tab name.
function Panel.ListLabel(list, treeName)
    if treeName and treeName ~= "" then
        return treeName .. " · " .. list.set
    end
    return list.set
end

function Panel.PhaseLabel(phase)
    if phase == 0 then return L.PHASE_PRERAID end
    return string.format(L.PHASE, phase)
end

local frame, tab, phaseDropdown, listDropdown
local PlaceTab
local slotButtons = {}

local QualityColor = ns.Items.QualityColor
local WhenLoaded = ns.Items.WhenLoaded

local function EmptyTexture(slot)
    local ok, _, texture = pcall(GetInventorySlotInfo, SLOT_NAMES[slot])
    return ok and texture or EMPTY_SLOT
end

-- The slot's items in the guide's order: the BiS item, then its alternatives.
function Panel.RankedItems(list, slot)
    local out = {}
    local best = list and list.items[slot]
    if not best then return out end
    out[1] = best
    for _, itemID in ipairs(list.alts and list.alts[slot] or NO_ALTS) do
        out[#out + 1] = itemID
    end
    return out
end

local function PaintName(button)
    local itemID = button.item
    local name, _, quality = GetItemInfo(itemID)
    if name then
        button.name:SetText(name)
        button.name:SetTextColor(QualityColor(quality))
        button.border:SetVertexColor(QualityColor(quality))
        button.border:Show()
        return
    end
    button.name:SetText("")
    button.border:Hide()
    WhenLoaded(itemID, function()
        if button.item == itemID then PaintName(button) end
    end)
end

local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- A slot's check (author, 2026-10-28): green when you have the item shown, yellow when
-- you are wearing one of its ranked alternatives, grey when only another character has
-- the item shown. An alternative merely in your bags or bank puts no check on the slot;
-- the ranked list and the tooltip say so instead.
local CHECK_COLORS = {
    best = { 1, 1, 1, false },
    using = { 1, 0.82, 0, true },
    elsewhere = { 0.7, 0.7, 0.7, true },
}

local function HasItem(itemID) return ns.Owned:Has(itemID) end
local function ItemState(itemID) return ns.Owned:State(itemID) end

local function PaintCheck(button, list)
    local status = ns.Owned.SlotStatus(list, button.slot, HasItem, ItemState)
    local color = status and CHECK_COLORS[status]
    if not color then
        button.check:Hide()
        return
    end
    button.check:SetDesaturated(color[4])
    button.check:SetVertexColor(color[1], color[2], color[3])
    button.check:Show()
end

local function PaintEnchant(button, spellID)
    local enchant = button.enchant
    enchant.spell = spellID
    if not spellID then
        enchant:Hide()
        return
    end
    enchant.icon:SetTexture(ns.GetSpellTexture and ns.GetSpellTexture(spellID) or UNKNOWN_ICON)
    enchant:Show()
end

local function PaintGems(button, gems)
    for i, gemButton in ipairs(button.gems) do
        local gemID = gems[i]
        gemButton.item = gemID
        if gemID then
            local _, _, _, _, icon = GetItemInfoInstant(gemID)
            gemButton.icon:SetTexture(icon or UNKNOWN_ICON)
            gemButton:Show()
        else
            gemButton:Hide()
        end
    end
end

local function PaintSlot(button, view, list)
    button.item = view.item
    button.alts = view.alts
    PaintCheck(button, list)
    PaintEnchant(button, view.item and view.enchant)
    PaintGems(button, view.item and view.gems or NO_ALTS)
    if not view.item then
        button.icon:SetTexture(EmptyTexture(view.slot))
        button.name:SetText("")
        button.border:Hide()
        return
    end
    local _, _, _, _, icon = GetItemInfoInstant(view.item)
    button.icon:SetTexture(icon or EMPTY_SLOT)
    PaintName(button)
end

local function AddOwnedLine(button)
    local text, r, g, b = ns.Owned:Describe(button.item)
    if text then
        GameTooltip:AddLine(text, r, g, b)
        return
    end
    for _, itemID in ipairs(button.alts) do
        if ns.Owned:State(itemID) == "equipped" then
            local name = GetItemInfo(itemID) or tostring(itemID)
            GameTooltip:AddLine(string.format(L.OWNED_USING, name), 1, 0.82, 0)
            return
        end
    end
    for _, itemID in ipairs(button.alts) do
        if ns.Owned:Has(itemID) then
            local name = GetItemInfo(itemID) or tostring(itemID)
            GameTooltip:AddLine(string.format(L.OWNED_ALTERNATIVE, name), 1, 0.82, 0)
            return
        end
    end
end

local function ShowTooltip(button)
    if not button.item then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(button.item)
    GameTooltip:AddLine(" ")
    AddOwnedLine(button)
    if #button.alts > 0 then
        GameTooltip:AddLine(L.HINT_RANKED, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(L.HINT_MARK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnSlotClick(button, mouseButton)
    if not button.item then return end
    if mouseButton == "RightButton" then
        ns.Owned:ToggleManual(button.item)
        if GameTooltip:IsOwned(button) then ShowTooltip(button) end
        return
    end
    if IsModifiedClick() then
        local _, link = GetItemInfo(button.item)
        if link then HandleModifiedItemClick(link) end
        return
    end
    GameTooltip:Hide()
    ns.RankFlyout:Toggle(button, Panel.RankedItems(frame.list, button.slot))
end

local function HideTooltip() GameTooltip:Hide() end

local function ShowEnchantTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.spell)
    GameTooltip:Show()
end

local function ShowGemTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    GameTooltip:Show()
end

local function SmallIcon(parent, size, onEnter)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(size, size)
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetAllPoints()
    icon:SetScript("OnEnter", onEnter)
    icon:SetScript("OnLeave", HideTooltip)
    icon:Hide()
    return icon
end

local MAX_GEMS = 3

-- side: "left" (icon, then name), "right" (name, then icon, right-aligned) or
-- "bottom" (name under the icon, gems to the right of it).
local function CreateSlotButton(slot, side)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture(QUALITY_BORDER)
    button.border:SetAllPoints()
    button.check = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.check:SetTexture(CHECK_TEXTURE)
    button.check:SetSize(16, 16)
    button.check:SetPoint("BOTTOMRIGHT", 4, -4)
    button.check:Hide()
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnClick", OnSlotClick)
    button.slot = slot
    button.alts = NO_ALTS

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetWordWrap(false)
    button.name = name

    local enchant = SmallIcon(frame, ENCHANT_SIZE, ShowEnchantTooltip)
    button.enchant = enchant

    button.gems = {}
    for i = 1, MAX_GEMS do
        button.gems[i] = SmallIcon(frame, GEM_SIZE, ShowGemTooltip)
    end

    if side == "left" then
        enchant:SetPoint("RIGHT", button, "LEFT", -4, 0)
        name:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, -2)
        name:SetWidth(NAME_WIDTH)
        name:SetJustifyH("LEFT")
        for i, gem in ipairs(button.gems) do
            gem:SetPoint("TOPLEFT", name, "BOTTOMLEFT", (i - 1) * (GEM_SIZE + 3), -4)
        end
    elseif side == "right" then
        enchant:SetPoint("LEFT", button, "RIGHT", 4, 0)
        name:SetPoint("TOPRIGHT", button, "TOPLEFT", -6, -2)
        name:SetWidth(NAME_WIDTH)
        name:SetJustifyH("RIGHT")
        for i, gem in ipairs(button.gems) do
            gem:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", -(i - 1) * (GEM_SIZE + 3), -4)
        end
    else
        enchant:SetPoint("RIGHT", button, "LEFT", -4, 0)
        name:SetPoint("TOP", button, "BOTTOM", 0, -3)
        name:SetWidth(WEAPON_SPACING - 8)
        name:SetJustifyH("CENTER")
        for i, gem in ipairs(button.gems) do
            gem:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, -(i - 1) * (GEM_SIZE + 1))
        end
    end

    slotButtons[slot] = button
    return button
end

local function LayoutSlots()
    local slotX = PADDING + ENCHANT_SIZE + 4
    for row, slot in ipairs(Panel.LEFT_SLOTS) do
        local button = CreateSlotButton(slot, "left")
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", slotX, -HEADER_HEIGHT - (row - 1) * ROW_HEIGHT)
    end
    for row, slot in ipairs(Panel.RIGHT_SLOTS) do
        local button = CreateSlotButton(slot, "right")
        button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -slotX, -HEADER_HEIGHT - (row - 1) * ROW_HEIGHT)
    end
    local weaponTop = -HEADER_HEIGHT - #Panel.LEFT_SLOTS * ROW_HEIGHT - 4
    local middle = (#Panel.BOTTOM_SLOTS + 1) / 2
    for i, slot in ipairs(Panel.BOTTOM_SLOTS) do
        local button = CreateSlotButton(slot, "bottom")
        button:SetPoint("TOP", frame, "TOP", (i - middle) * WEAPON_SPACING, weaponTop)
    end
end

local function Create()
    frame = ns.Theme.CreateWindow("Frame", "GudaBiSPanel", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "GudaBiSPanel")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PADDING, -10)
    title:SetText(L.PANEL_TITLE)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() Panel:Close() end)

    phaseDropdown = ns.Dropdown.Create(frame, 96, function(phase)
        ns.Lists:SetPhase(phase)
        Panel:Refresh()
    end)
    phaseDropdown.button:SetPoint("TOPLEFT", PADDING, -32)

    listDropdown = ns.Dropdown.Create(frame, WIDTH - PADDING * 2 - 104, function(id)
        ns.Lists:Select(id)
        Panel:Refresh()
    end)
    listDropdown.button:SetPoint("LEFT", phaseDropdown.button, "RIGHT", 8, 0)

    frame.emptyNote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.emptyNote:SetPoint("TOP", 0, -HEADER_HEIGHT + 14)
    frame.emptyNote:SetText(L.NO_LIST)

    LayoutSlots()

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
        ns.RankFlyout:Close()
        PlaceTab()
    end)
end

-- The Character frame's art has a transparent margin on Classic clients (wider than
-- 360), so anything docked to it moves in to sit against the visible edge.
local function CharacterEdge()
    local classicArt = (CharacterFrame:GetWidth() or 0) > 360
    return classicArt and -32 or 0, classicArt and -12 or 0
end

local function Anchor()
    frame:ClearAllPoints()
    if CharacterFrame and CharacterFrame:IsShown() then
        local x, y = CharacterEdge()
        frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", x, y)
        frame.docked = true
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        frame.docked = false
    end
end

PlaceTab = function()
    if not tab then return end
    tab:ClearAllPoints()
    local open = frame ~= nil and frame:IsShown() and frame.docked
    if open then
        tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, TAB_TOP)
    else
        local x, y = CharacterEdge()
        tab:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", x, y + TAB_TOP)
    end
    tab:SetChecked(open)
end

function Panel:Refresh()
    if not frame then return end
    local Lists = ns.Lists
    local phaseOptions = {}
    for i, phase in ipairs(ns.Data:Phases()) do
        phaseOptions[i] = { value = phase, text = Panel.PhaseLabel(phase) }
    end
    phaseDropdown:SetOptions(phaseOptions, Lists:Phase())

    local current = Lists:Current()
    local listOptions = {}
    for i, list in ipairs(Lists:Choices()) do
        listOptions[i] = { value = list.id, text = Panel.ListLabel(list, ns.Spec:TreeName(list.tree)) }
    end
    listDropdown:SetOptions(listOptions, current and current.id)
    frame.emptyNote:SetShown(current == nil)

    frame.list = current
    ns.RankFlyout:Close()
    for slot, button in pairs(slotButtons) do
        PaintSlot(button, Panel.SlotView(current, slot), current)
    end
end

-- Owned changes repaint only the checks of an open panel, and an open tooltip.
function Panel:RefreshChecks()
    if not self:IsShown() then return end
    for _, button in pairs(slotButtons) do
        PaintCheck(button, frame.list)
        if GameTooltip:IsOwned(button) then ShowTooltip(button) end
    end
end

ns.Events:Register("GBIS_OWNED_CHANGED", function() Panel:RefreshChecks() end, "Panel")

function Panel:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Panel:Open()
    if not frame then Create() end
    Anchor()
    self:Refresh()
    frame:Show()
    PlaceTab()
end

function Panel:Close()
    if frame then frame:Hide() end
    PlaceTab()
end

-- The player's choice from the side tab is remembered, so the panel comes back with
-- the Character frame.
function Panel:Toggle()
    if self:IsShown() then
        self:Close()
    else
        self:Open()
    end
    ns.Database:SetSetting("panelOpen", self:IsShown())
end

-- Built like the spellbook's SpellBookSkillLineTabTemplate, without inheriting it:
-- that template's scripts belong to the spellbook.
local function CreateTab()
    tab = CreateFrame("CheckButton", nil, CharacterFrame)
    tab:SetSize(32, 32)
    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(TAB_BACKGROUND)
    background:SetSize(64, 64)
    background:SetPoint("TOPLEFT", -3, 11)
    tab:SetNormalTexture(TOGGLE_ICON)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    tab:GetCheckedTexture():SetBlendMode("ADD")
    tab:SetScript("OnClick", function() Panel:Toggle() end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_TOGGLE)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Panel.tab = tab
end

local function OnCharacterShow()
    if not tab then CreateTab() end
    if ns.Database:GetSetting("panelOpen") then
        Panel:Open()
    else
        PlaceTab()
    end
end

local function OnCharacterHide()
    if frame and frame.docked then frame:Hide() end
end

ns.Events:Register("GBIS_INITIALIZED", function()
    if not CharacterFrame then return end
    CharacterFrame:HookScript("OnShow", OnCharacterShow)
    CharacterFrame:HookScript("OnHide", OnCharacterHide)
end, "Panel")

ns.SlashCommands:Register("show", function()
    if Panel:IsShown() then Panel:Close() else Panel:Open() end
end, L.HELP_SHOW)
