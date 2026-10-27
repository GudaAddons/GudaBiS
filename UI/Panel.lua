-- The BiS panel (GB-020/021/022): a paperdoll-style window docked to the right of the
-- Character frame, opened by a button on the paperdoll or by /gbis.
--
-- Nothing is built at login (RULES.md Rule 1): the toggle button is made the first time
-- the Character frame shows, the panel the first time it opens. Switching phase or list
-- repaints the same slot buttons; frames are never rebuilt.
--
-- Pure parts, tested offline: Panel.SlotView, Panel.ListLabel, Panel.PhaseLabel.

local addonName, ns = ...
local L = ns.L

local Panel = ns:RegisterModule("Panel")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

local SLOT_SIZE = 30
local NAME_WIDTH = 112
local ROW_HEIGHT = 34
local COLUMN_WIDTH = SLOT_SIZE + 6 + NAME_WIDTH
local PADDING = 12
local HEADER_HEIGHT = 74
local WIDTH = PADDING * 2 + COLUMN_WIDTH * 2 + 8

Panel.LEFT_SLOTS = { 1, 2, 3, 15, 5, 9, 16, 17, 18 }
Panel.RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }

local HEIGHT = HEADER_HEIGHT + #Panel.LEFT_SLOTS * ROW_HEIGHT + PADDING

local SLOT_NAMES = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
    [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}

local TOGGLE_ICON = "Interface\\Icons\\INV_Chest_Plate06"
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local QUALITY_BORDER = "Interface\\Common\\WhiteIconFrame"

local NO_ALTS = {}

-- What one slot button shows for a list (nil list = an empty paperdoll).
function Panel.SlotView(list, slot)
    return {
        slot = slot,
        item = list and list.items[slot] or nil,
        alts = list and list.alts and list.alts[slot] or NO_ALTS,
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

local frame, toggleButton, phaseDropdown, listDropdown
local slotButtons = {}
local pendingLoads = {}

local function EmptyTexture(slot)
    local ok, _, texture = pcall(GetInventorySlotInfo, SLOT_NAMES[slot])
    return ok and texture or EMPTY_SLOT
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- Runs fn once the client has the item's data. Only uncached items are requested, and
-- each at most once at a time, so a tooltip redraw can never loop.
local function WhenLoaded(itemID, fn)
    if pendingLoads[itemID] or not (Item and Item.CreateFromItemID) then return end
    pendingLoads[itemID] = true
    Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
        pendingLoads[itemID] = nil
        fn()
    end)
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

local function PaintSlot(button, view)
    button.item = view.item
    button.alts = view.alts
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

local function ShowTooltip(button)
    if not button.item then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(button.item)
    if #button.alts > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TOOLTIP_ALTERNATIVES, 1, 0.82, 0)
        for i, itemID in ipairs(button.alts) do
            local name, _, quality = GetItemInfo(itemID)
            if name then
                local r, g, b = QualityColor(quality)
                GameTooltip:AddLine(i .. ". " .. name, r, g, b)
            else
                GameTooltip:AddLine(string.format(L.TOOLTIP_ITEM_LOADING, itemID), 0.6, 0.6, 0.6)
                WhenLoaded(itemID, function()
                    if GameTooltip:IsOwned(button) then ShowTooltip(button) end
                end)
            end
        end
    end
    GameTooltip:Show()
end

local function OnSlotClick(button)
    if not button.item or not IsModifiedClick() then return end
    local _, link = GetItemInfo(button.item)
    if link then HandleModifiedItemClick(link) end
end

local function CreateSlotButton(parent, slot)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture(QUALITY_BORDER)
    button.border:SetAllPoints()
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.name:SetPoint("LEFT", button, "RIGHT", 6, 0)
    button.name:SetWidth(NAME_WIDTH)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", OnSlotClick)
    button.slot = slot
    button.alts = NO_ALTS
    return button
end

local function LayoutColumn(slots, x)
    for row, slot in ipairs(slots) do
        local button = CreateSlotButton(frame, slot)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -HEADER_HEIGHT - (row - 1) * ROW_HEIGHT)
        slotButtons[slot] = button
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

    LayoutColumn(Panel.LEFT_SLOTS, PADDING)
    LayoutColumn(Panel.RIGHT_SLOTS, PADDING + COLUMN_WIDTH + 8)

    frame:SetScript("OnHide", function() GameTooltip:Hide() end)
end

-- Docked: the Character frame's art has a transparent margin on Classic clients
-- (wider than 360), so the panel overlaps it to sit against the visible edge.
local function Anchor()
    frame:ClearAllPoints()
    local character = CharacterFrame
    if character and character:IsShown() then
        local classicArt = (character:GetWidth() or 0) > 360
        frame:SetPoint("TOPLEFT", character, "TOPRIGHT", classicArt and -32 or 0, classicArt and -12 or 0)
        frame.docked = true
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        frame.docked = false
    end
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

    for slot, button in pairs(slotButtons) do
        PaintSlot(button, Panel.SlotView(current, slot))
    end
end

function Panel:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Panel:Open()
    if not frame then Create() end
    Anchor()
    self:Refresh()
    frame:Show()
end

function Panel:Close()
    if frame then frame:Hide() end
end

-- The player's choice from the paperdoll button is remembered, so the panel comes back
-- with the Character frame.
function Panel:Toggle()
    if self:IsShown() then
        self:Close()
    else
        self:Open()
    end
    ns.Database:SetSetting("panelOpen", self:IsShown())
end

local function CreateToggleButton()
    toggleButton = CreateFrame("Button", nil, PaperDollFrame or CharacterFrame)
    toggleButton:SetSize(26, 26)
    toggleButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -44, -40)
    toggleButton:SetNormalTexture(TOGGLE_ICON)
    toggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    toggleButton:SetScript("OnClick", function() Panel:Toggle() end)
    toggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_TOGGLE)
        GameTooltip:Show()
    end)
    toggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function OnCharacterShow()
    if not toggleButton then CreateToggleButton() end
    if ns.Database:GetSetting("panelOpen") then Panel:Open() end
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
