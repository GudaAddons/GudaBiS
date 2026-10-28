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
local PADDING = 14
local DROPDOWN_TOP = 28
local PHASE_DROPDOWN_WIDTH = 100
local ROLE_DROPDOWN_WIDTH = 60
local HEADER_HEIGHT = 66
local WEAPON_ROW_HEIGHT = 52
local WEAPON_SPACING = 124
local COLUMN_WIDTH = ENCHANT_SIZE + 4 + SLOT_SIZE + 6 + NAME_WIDTH
local WIDTH = PADDING * 2 + COLUMN_WIDTH * 2 + 12
local BOTTOM_PADDING = 8
local HEIGHT = HEADER_HEIGHT + #Panel.LEFT_SLOTS * ROW_HEIGHT + WEAPON_ROW_HEIGHT + BOTTOM_PADDING
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Item names one size below GameFontHighlightSmall (author, 2026-10-28). The client's
-- font file is kept, so every locale's alphabet still renders.
local NAME_FONT_SIZE = 9

local SLOT_NAMES = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
    [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}

local TOGGLE_ICON = "Interface\\AddOns\\GudaBiS\\Assets\\logo.png"
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

-- "Protection · Balanced set  by Zephan": the client's own tree name, the guide's tab
-- name, and in grey the guide's writer when the data names one (author, 2026-10-28). A
-- custom list shows its own name. role ("ms"/"os") adds a coloured MS/OS tag.
local ROLE_TAGS = { ms = "|cff40ff40%s|r ", os = "|cff40c0ff%s|r " }
local AUTHOR_TAG = "  |cff808080%s|r"

function Panel.ListLabel(list, treeName, role)
    local label
    if list.custom then
        label = list.name
    elseif treeName and treeName ~= "" then
        label = treeName .. " · " .. list.set
    else
        label = list.set
    end
    if not list.custom and list.author then
        label = label .. string.format(AUTHOR_TAG, string.format(L.LIST_BY, list.author))
    end
    if role then
        label = string.format(ROLE_TAGS[role], role == "ms" and L.ROLE_MS or L.ROLE_OS) .. label
    end
    return label
end

function Panel.PhaseLabel(phase)
    if phase == 0 then return L.PHASE_PRERAID end
    return string.format(L.PHASE, phase)
end

local frame, tab, phaseDropdown, listDropdown, roleDropdown
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

-- Repaints one slot from the list shown (an item's data arriving can add its name and,
-- on a custom list, its sockets). Defined after PaintSlot.
local RepaintSlot

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
        if button.item == itemID then RepaintSlot(button) end
    end)
end

local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- A slot's check means only "you have this exact item" (author, 2026-10-28): green on
-- this character, grey on another one. A missing item gets no mark at all, and owning
-- or wearing an alternative never marks the slot (yellow checks read as "owned" and
-- were dropped); the tooltip and the ranked list say it instead.
local CHECK_COLORS = {
    best = { 1, 1, 1, false },
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

local EMPTY_ENCHANT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local EMPTY_SOCKET = "Interface\\ItemSocketingFrame\\UI-EmptySocket-"
local SOCKET_TEXTURE_NAMES = { META = "Meta", RED = "Red", YELLOW = "Yellow", BLUE = "Blue" }

-- editable: a custom list with an item in the slot; then an empty enchant shows a
-- placeholder to click.
local function PaintEnchant(button, spellID, editable)
    local enchant = button.enchant
    enchant.spell = spellID
    enchant.editable = editable
    if spellID then
        enchant.icon:SetTexture(ns.GetSpellTexture and ns.GetSpellTexture(spellID) or UNKNOWN_ICON)
        enchant.icon:SetDesaturated(false)
        enchant:Show()
    elseif editable then
        enchant.icon:SetTexture(EMPTY_ENCHANT)
        enchant.icon:SetDesaturated(true)
        enchant:Show()
    else
        enchant:Hide()
    end
end

-- Guide lists show their gems. A custom list shows one icon per socket the item really
-- has (Items.Sockets): the chosen gem, or the game's empty-socket art of that colour.
local function PaintGems(button, gems, editable)
    local sockets = editable and ns.Items.Sockets(button.item) or NO_ALTS
    for i, gemButton in ipairs(button.gems) do
        local gemID = gems[i]
        if gemID == 0 then gemID = nil end
        gemButton.item = gemID
        gemButton.index = i
        gemButton.socket = sockets[i]
        gemButton.editable = editable
        if gemID then
            local _, _, _, _, icon = GetItemInfoInstant(gemID)
            gemButton.icon:SetTexture(icon or UNKNOWN_ICON)
            gemButton:Show()
        elseif editable and sockets[i] then
            gemButton.icon:SetTexture(EMPTY_SOCKET .. SOCKET_TEXTURE_NAMES[sockets[i]])
            gemButton:Show()
        else
            gemButton:Hide()
        end
    end
end

local WARN_COLOR = { 1, 0.25, 0.25 }

local function Warn(icon, on)
    if on then
        icon.icon:SetVertexColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3])
        icon.warn:Show()
    else
        icon.icon:SetVertexColor(1, 1, 1)
        icon.warn:Hide()
    end
end

-- Red enchant and gem icons where the equipped item misses what the list asks for.
local function PaintFinish(button, list)
    local state = button.item and ns.Enchants:ForSlot(list, button.slot) or nil
    button.enchant.missing = state ~= nil and state.missingEnchant
    Warn(button.enchant, button.enchant.missing)
    for i, gem in ipairs(button.gems) do
        gem.state = state and state.gems[i] or nil
        Warn(gem, gem.state == "empty" or gem.state == "wrong")
    end
end

local function PaintSlot(button, view, list)
    button.item = view.item
    button.alts = view.alts
    local editable = view.item ~= nil and ns.Lists.IsCustom(list)
    PaintCheck(button, list)
    PaintEnchant(button, view.item and view.enchant, editable)
    PaintGems(button, view.item and view.gems or NO_ALTS, editable)
    PaintFinish(button, list)
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

RepaintSlot = function(button)
    if not frame then return end
    PaintSlot(button, Panel.SlotView(frame.list, button.slot), frame.list)
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

local function EditingCustom()
    return frame ~= nil and ns.Lists.IsCustom(frame.list)
end

local function ShowTooltip(button)
    if not button.item then
        if not EditingCustom() then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.HINT_CHOOSE)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(button.item)
    GameTooltip:AddLine(" ")
    AddOwnedLine(button)
    if EditingCustom() then
        GameTooltip:AddLine(L.HINT_CHOOSE, 0.6, 0.6, 0.6)
    elseif #button.alts > 0 then
        GameTooltip:AddLine(L.HINT_RANKED, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(L.HINT_MARK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
    ns.ItemTooltip.Compare()
    ns.ItemTooltip.Track(button, ShowTooltip)
end

-- Puts itemID (nil clears) into the slot of the custom list being shown, when it fits.
local function SetCustomSlot(slot, itemID)
    if itemID then
        local _, _, _, equipLoc = GetItemInfoInstant(itemID)
        if not ns.Lists.FitsSlot(equipLoc, slot) then
            ns:Print(string.format(L.PICK_WRONG_SLOT, itemID))
            return
        end
    end
    ns.Lists:SetSlot(frame.list.id, slot, itemID)
    Panel:Refresh()
end

-- An item dropped on a custom list's slot (dragged from bags or the picker).
local function OnSlotReceiveDrag(button)
    if not EditingCustom() then return false end
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return false end
    ClearCursor()
    SetCustomSlot(button.slot, itemID)
    return true
end

local function OpenPicker(button)
    local slot = button.slot
    ns.RankFlyout:Toggle(button, ns.Lists:GuideItemsForSlot(slot), {
        kind = "item",
        slot = slot,
        onPick = function(itemID)
            ns.Lists:SetSlot(frame.list.id, slot, itemID)
            Panel:Refresh()
        end,
    })
end

local function OpenEnchantPicker(icon)
    if not (icon.editable and EditingCustom()) then return end
    local slot = icon.owner.slot
    GameTooltip:Hide()
    ns.RankFlyout:Toggle(icon, ns.Lists:GuideEnchantsForSlot(slot), {
        kind = "enchant",
        slot = slot,
        onPick = function(spellID)
            ns.Lists:SetEnchant(frame.list.id, slot, spellID)
            Panel:Refresh()
        end,
    })
end

local function OpenGemPicker(icon)
    if not (icon.editable and EditingCustom()) then return end
    local slot, index = icon.owner.slot, icon.index
    GameTooltip:Hide()
    ns.RankFlyout:Toggle(icon, ns.Lists:GuideGems(), {
        kind = "gem",
        slot = slot,
        socket = icon.socket,
        onPick = function(gemID)
            ns.Lists:SetGem(frame.list.id, slot, index, gemID)
            Panel:Refresh()
        end,
    })
end

-- A gem dragged onto a socket of a custom list.
local function OnGemReceiveDrag(icon)
    if not (icon.editable and EditingCustom()) then return end
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return end
    ClearCursor()
    if not ns.Items.IsGem(itemID) then
        ns:Print(string.format(L.PICK_NOT_GEM, itemID))
        return
    end
    ns.Lists:SetGem(frame.list.id, icon.owner.slot, icon.index, itemID)
    Panel:Refresh()
end

local function OnSlotClick(button, mouseButton)
    if OnSlotReceiveDrag(button) then return end
    if mouseButton == "RightButton" then
        if not button.item then return end
        ns.Owned:ToggleManual(button.item)
        if GameTooltip:IsOwned(button) then ShowTooltip(button) end
        return
    end
    if button.item and IsModifiedClick() then
        local _, link = GetItemInfo(button.item)
        if link then HandleModifiedItemClick(link) end
        return
    end
    GameTooltip:Hide()
    if EditingCustom() then
        OpenPicker(button)
    elseif button.item then
        ns.RankFlyout:Toggle(button, Panel.RankedItems(frame.list, button.slot))
    end
end

local function HideTooltip()
    ns.ItemTooltip.Untrack()
    GameTooltip:Hide()
end

local function ShowEnchantTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spell then
        GameTooltip:SetSpellByID(self.spell)
    else
        GameTooltip:SetText(L.ENCHANT_NONE)
    end
    if self.missing then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.ENCHANT_MISSING, WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3])
    end
    if self.editable and EditingCustom() then
        GameTooltip:AddLine(L.HINT_EDIT_ENCHANT, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local GEM_LINES = {
    ok = { "GEM_OK", 0.1, 1, 0.1 },
    empty = { "GEM_EMPTY", WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3] },
    wrong = { "GEM_WRONG", WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3] },
}

local function ShowGemTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item then
        GameTooltip:SetItemByID(self.item)
        if not ns.Items.GemMatches(self.item, self.socket) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.GEM_COLOR_MISMATCH, 1, 0.5, 0.25)
        end
    else
        GameTooltip:SetText(_G["EMPTY_SOCKET_" .. (self.socket or "")] or L.SOCKET_EMPTY)
    end
    local line = self.state and GEM_LINES[self.state]
    if line then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L[line[1]], line[2], line[3], line[4])
    end
    if self.editable and EditingCustom() then
        GameTooltip:AddLine(L.HINT_EDIT_GEM, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- An enchant or gem icon. On a custom list a click opens its picker, and a gem icon
-- also takes a dragged gem.
local function SmallIcon(owner, size, onEnter, onClick, onDrag)
    local icon = CreateFrame("Button", nil, frame)
    icon:SetSize(size, size)
    icon.owner = owner
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetAllPoints()
    icon.warn = icon:CreateTexture(nil, "OVERLAY")
    icon.warn:SetTexture(QUALITY_BORDER)
    icon.warn:SetAllPoints()
    icon.warn:SetVertexColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3])
    icon.warn:Hide()
    icon:SetScript("OnEnter", onEnter)
    icon:SetScript("OnLeave", HideTooltip)
    icon:SetScript("OnClick", onClick)
    if onDrag then icon:SetScript("OnReceiveDrag", onDrag) end
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
    ns.Theme.SlotFrame(button, SLOT_SIZE)
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
    button:SetScript("OnReceiveDrag", OnSlotReceiveDrag)
    button.slot = slot
    button.alts = NO_ALTS

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local fontFile, _, fontFlags = name:GetFont()
    if fontFile then name:SetFont(fontFile, NAME_FONT_SIZE, fontFlags) end
    name:SetWordWrap(false)
    button.name = name

    local enchant = SmallIcon(button, ENCHANT_SIZE, ShowEnchantTooltip, OpenEnchantPicker)
    button.enchant = enchant

    button.gems = {}
    for i = 1, MAX_GEMS do
        button.gems[i] = SmallIcon(button, GEM_SIZE, ShowGemTooltip, OpenGemPicker, OnGemReceiveDrag)
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

-- New / Rename / Delete are action rows at the bottom of the list menu, each with its
-- old toolbar icon (author, 2026-10-28: the toolbar row is gone).
local NEW_ICON = "|TInterface\\PaperDollInfoFrame\\Character-Plus:14|t "
local RENAME_ICON = "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:14|t "
local DELETE_ICON = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14|t "

-- The role dropdown at the end of the dropdown row: the list being shown is this
-- character's main spec, off spec, or neither (author, 2026-10-28: instead of the MS
-- and OS buttons). "None" clears the list's role; when that makes it the default MS
-- again (a guide list of the active tree that was OS), MS is cleared too, so the
-- dropdown shows what was chosen.
local ROLE_NONE = "none"
local ROLE_COLORS = { ms = "|cff40ff40%s|r", os = "|cff40c0ff%s|r", none = "|cff808080%s|r" }

function Panel.RoleOptions()
    return {
        { value = "ms", text = string.format(ROLE_COLORS.ms, L.ROLE_MS) },
        { value = "os", text = string.format(ROLE_COLORS.os, L.ROLE_OS) },
        { value = ROLE_NONE, text = string.format(ROLE_COLORS.none, "—") },
    }
end

local function SetRole(role)
    local list = frame.list
    if not list then return end
    local current = ns.Lists:RoleOf(list.id)
    ns.Lists:Select(list.id)
    if role == ROLE_NONE then
        if current then ns.Lists:ToggleRole(current, list.id) end
        local fallback = ns.Lists:RoleOf(list.id)
        if fallback then ns.Lists:ToggleRole(fallback, list.id) end
    elseif role ~= current then
        ns.Lists:ToggleRole(role, list.id)
    end
    Panel:Refresh()
end

-- A new custom list from a Wowhead gear-planner link (GB-043). Returns an error text for
-- the dialog when the link does not read; a set for another class imports with a note.
local function ImportList(name, link)
    local result, problem = ns.GearPlanner:Read(link)
    if not result then return problem end
    local _, count = ns.Lists:CreateImported(name, result.slots)
    local playerClass = ns.Spec:PlayerClass()
    if result.class and playerClass and result.class ~= playerClass then
        local names = LOCALIZED_CLASS_NAMES_MALE or {}
        ns:Print(string.format(L.IMPORT_OTHER_CLASS, names[result.class] or result.class))
    end
    ns:Print(string.format(L.IMPORT_DONE, count, name))
    Panel:Refresh()
    return nil
end

local function NewList()
    local count = 0
    for _ in pairs(ns.db.lists or {}) do count = count + 1 end
    local copyFrom = frame.list
    ns.NameDialog:Open({
        title = L.NEW_LIST,
        text = string.format(L.DEFAULT_LIST_NAME, count + 1),
        showCopy = copyFrom ~= nil,
        showLink = true,
        onAccept = function(name, copy, link)
            if link ~= "" then return ImportList(name, link) end
            ns.Lists:CreateCustom(name, copy and copyFrom or nil)
            Panel:Refresh()
        end,
    })
end

local function RenameList()
    local list = frame.list
    if not ns.Lists.IsCustom(list) then return end
    ns.NameDialog:Open({
        title = L.RENAME_LIST,
        text = list.name,
        onAccept = function(name)
            ns.Lists:Rename(list.id, name)
            Panel:Refresh()
        end,
    })
end

local function DeleteList()
    local list = frame.list
    if not ns.Lists.IsCustom(list) then return end
    ns.NameDialog:Open({
        title = string.format(L.DELETE_CONFIRM, list.name),
        confirm = true,
        onAccept = function()
            ns.Lists:Delete(list.id)
            Panel:Refresh()
        end,
    })
end

-- The action rows under the lists: New always, Rename and Delete on a custom list.
function Panel.ListActions(current)
    local actions = {
        { action = NewList, text = NEW_ICON .. L.TOOLTIP_NEW_LIST, separator = true },
    }
    if ns.Lists.IsCustom(current) then
        actions[2] = { action = RenameList, text = RENAME_ICON .. L.TOOLTIP_RENAME }
        actions[3] = { action = DeleteList, text = DELETE_ICON .. L.TOOLTIP_DELETE }
    end
    return actions
end

-- Gear, Wishlist and History tabs under the panel, the same as the Character frame's own tabs on
-- this client (GB-071; author, 2026-10-28: generic tabs looked foreign next to them).
-- Classic flavors draw those with CharacterFrameTabButtonTemplate, Retail with
-- PanelTabButtonTemplate; the first one the client has is used, a plain button last.
-- The Character tab template's own click and tooltip scripts belong to the Character
-- frame, so they are replaced.
local TABS = {
    { key = "gear", text = "TAB_GEAR" },
    { key = "wishlist", text = "TAB_WISHLIST" },
    { key = "history", text = "TAB_HISTORY" },
}
local TAB_TEMPLATES = { "CharacterFrameTabButtonTemplate", "PanelTabButtonTemplate" }
local TAB_OVERLAP = -14

local function CreateTabButton(name)
    for _, template in ipairs(TAB_TEMPLATES) do
        local ok, button = pcall(CreateFrame, "Button", name, frame, template)
        if ok and button then return button end
    end
    local button = CreateFrame("Button", name, frame, "UIPanelButtonTemplate")
    button:SetSize(90, 22)
    return button
end

local function CreateTabs()
    local previous
    for i, info in ipairs(TABS) do
        local tabButton = CreateTabButton("GudaBiSPanelTab" .. i)
        tabButton:SetScript("OnEnter", nil)
        tabButton:SetScript("OnLeave", nil)
        tabButton:SetScript("OnShow", nil)
        tabButton:SetID(i)
        tabButton:SetText(L[info.text])
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tabButton, 0) end
        if previous then
            tabButton:SetPoint("LEFT", previous, "RIGHT", TAB_OVERLAP, 0)
        else
            tabButton:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 10, 2)
        end
        tabButton:SetScript("OnClick", function() Panel:ShowTab(info.key) end)
        previous = tabButton
    end
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(frame, #TABS) end
    frame.activeTab = "gear"
    if PanelTemplates_SetTab then PanelTemplates_SetTab(frame, 1) end
end

local function Create()
    local title, close
    frame, title, close = ns.Theme.Panel("GudaBiSPanel", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "GudaBiSPanel")

    title:SetText(L.PANEL_TITLE)
    close:SetScript("OnClick", function() Panel:Close() end)

    -- Dropdown frames are wider than their art by DROPDOWN_MARGIN per side, so they
    -- start that far left of the padding and overlap by twice that between them.
    local margin = ns.Theme.DROPDOWN_MARGIN
    local phaseWidth = PHASE_DROPDOWN_WIDTH + margin * 2
    phaseDropdown = ns.Dropdown.Create(frame, phaseWidth, function(phase)
        ns.Lists:SetPhase(phase)
        Panel:Refresh()
    end)
    phaseDropdown.button:SetPoint("TOPLEFT", PADDING - margin, -DROPDOWN_TOP)

    local listWidth = WIDTH - PADDING * 2 - PHASE_DROPDOWN_WIDTH - ROLE_DROPDOWN_WIDTH - 12 + margin * 2
    frame.listWidths = { withPhase = listWidth, alone = listWidth + PHASE_DROPDOWN_WIDTH + 6 }
    listDropdown = ns.Dropdown.Create(frame, listWidth, function(id)
        ns.Lists:Select(id)
        Panel:Refresh()
    end)
    listDropdown.button:SetPoint("LEFT", phaseDropdown.button, "RIGHT", 6 - margin * 2, 0)

    roleDropdown = ns.Dropdown.Create(frame, ROLE_DROPDOWN_WIDTH + margin * 2, SetRole, L.TOOLTIP_ROLE)
    roleDropdown.button:SetPoint("LEFT", listDropdown.button, "RIGHT", 6 - margin * 2, 0)
    Panel.phaseDropdown, Panel.listDropdown, Panel.roleDropdown = phaseDropdown, listDropdown, roleDropdown

    frame.emptyNote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.emptyNote:SetPoint("TOP", 0, -HEADER_HEIGHT + 14)
    frame.emptyNote:SetText(L.NO_LIST)

    LayoutSlots()
    CreateTabs()

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

-- Without phases (Retail, or a client with no guide data yet) the phase dropdown hides
-- and the list dropdown takes its place and width.
local function LayoutDropdowns(withPhases)
    local margin = ns.Theme.DROPDOWN_MARGIN
    phaseDropdown.button:SetShown(withPhases)
    local button = listDropdown.button
    button:ClearAllPoints()
    if withPhases then
        button:SetWidth(frame.listWidths.withPhase)
        button:SetPoint("LEFT", phaseDropdown.button, "RIGHT", 6 - margin * 2, 0)
    else
        button:SetWidth(frame.listWidths.alone)
        button:SetPoint("TOPLEFT", PADDING - margin, -DROPDOWN_TOP)
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
    LayoutDropdowns(#phaseOptions > 0 and ns.Features.HasPhases)

    local current = Lists:Current()
    local listOptions = {}
    for i, list in ipairs(Lists:Choices()) do
        listOptions[i] = {
            value = list.id,
            text = Panel.ListLabel(list, ns.Spec:TreeName(list.tree), Lists:RoleOf(list.id)),
        }
    end
    for _, action in ipairs(Panel.ListActions(current)) do listOptions[#listOptions + 1] = action end
    listDropdown:SetOptions(listOptions, current and current.id)
    frame.emptyNote:SetShown(current == nil)
    roleDropdown.button:SetShown(current ~= nil)
    roleDropdown:SetOptions(Panel.RoleOptions(), current and Lists:RoleOf(current.id) or "none")

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
        PaintFinish(button, frame.list)
        if GameTooltip:IsOwned(button) then ShowTooltip(button) end
    end
end

ns.Events:Register("GBIS_OWNED_CHANGED", function() Panel:RefreshChecks() end, "Panel")

-- Enchanting or socketing a worn item changes no equipment, only the item; this is the
-- event that says so. It also fires for durability, so it only repaints an open panel.
ns.Events:Register("UNIT_INVENTORY_CHANGED", function(_, unit)
    if unit == "player" then Panel:RefreshChecks() end
end, "Panel")

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

-- "gear", "wishlist" or "history"; opens the panel first when it is closed.
function Panel:ShowTab(key)
    if not self:IsShown() then self:Open() end
    frame.activeTab = key
    for i, info in ipairs(TABS) do
        if info.key == key and PanelTemplates_SetTab then PanelTemplates_SetTab(frame, i) end
    end
    ns.RankFlyout:Close()
    ns.WishlistTab:SetShown(frame, key == "wishlist")
    ns.HistoryTab:SetShown(frame, key == "history")
end

function Panel:ActiveTab()
    return frame and frame.activeTab or "gear"
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

ns.SlashCommands:Register("wishlist", function()
    Panel:ShowTab("wishlist")
end, L.HELP_WISHLIST)

ns.SlashCommands:Register("history", function()
    Panel:ShowTab("history")
end, L.HELP_HISTORY)
