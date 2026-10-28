-- A small dropdown: a button showing the current choice and a menu of options.
-- Options are { value = v, text = "..." }, or action rows { action = fn, text = "...",
-- separator = true } that run fn instead of choosing (New / Rename / Delete under the
-- list menu, author 2026-10-28); separator draws a line above the row. The menu is at
-- least as wide as the button and widens to fit its longest text, so a name the button
-- cuts off reads in full when open. The menu closes on a choice, on a second click of
-- the button, or on a click anywhere else.
--
-- "Anywhere else" is the client's GLOBAL_MOUSE_DOWN, listened to only while a menu is
-- open (RULES.md Rule 1). An earlier full-screen catcher frame behind the menu ended up
-- drawn over the options in game and swallowed every click on them (2026-10-28), so
-- nothing may sit between the player and the rows.
--
--   local dd = ns.Dropdown.Create(parent, width, onSelect[, tooltip])
--   dd:SetOptions(options, selectedValue)

local addonName, ns = ...

local Dropdown = ns:RegisterModule("Dropdown")

local ROW_HEIGHT = 18
local SEPARATOR_GAP = 6
local TEXT_PADDING = 24
local ACTION_COLOR = { 0.6, 0.8, 1 }
local OUTSIDE_EVENT = "GLOBAL_MOUSE_DOWN"

local open

local function OutsideClicksSupported()
    local utils = C_EventUtils
    if not (utils and utils.IsEventValid) then return false end
    local ok, valid = pcall(utils.IsEventValid, OUTSIDE_EVENT)
    return ok and valid == true
end

local function OnMouseDown()
    if open and not open.menu:IsMouseOver() and not open.button:IsMouseOver() then
        open:Close()
    end
end

local methods = {}

-- Retail and MoP Classic (ns.Features.HasNativeDropdowns) have their own dropdown widget
-- and menu system (WowStyle1DropdownTemplate on a DropdownButton): there the button and
-- the open menu are Blizzard's (author, 2026-10-28: ours looked out of place). Options become radio
-- entries, action rows plain buttons after a divider. It sits inside the same holder
-- frame, so every anchor and width stays the same. Nil where the client has no such
-- widget: the drawn dropdown below is used instead.
local function NativeDropdown(dd, holder)
    if not ns.Features.HasNativeDropdowns then return nil end
    local ok, native = pcall(CreateFrame, "DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    if not ok or not native or type(native.SetupMenu) ~= "function" then return nil end
    local margin = ns.Theme.DROPDOWN_MARGIN
    native:SetPoint("LEFT", holder, "LEFT", margin, 0)
    native:SetPoint("RIGHT", holder, "RIGHT", -margin, 0)
    native:SetupMenu(function(_, root)
        for _, option in ipairs(dd.options) do
            if option.separator and root.CreateDivider then root:CreateDivider() end
            if option.action then
                root:CreateButton(option.text, option.action)
            else
                root:CreateRadio(option.text,
                    function() return dd.value == option.value end,
                    function() dd:Choose(option.value) end)
            end
        end
    end)
    return native
end

function methods:Close()
    if self.native then
        if self.native.CloseMenu then pcall(self.native.CloseMenu, self.native) end
        return
    end
    self.menu:Hide()
    if open == self then
        open = nil
        ns.Events:Unregister(OUTSIDE_EVENT, "Dropdown")
    end
end

function methods:Open()
    if self.native then
        if self.native.OpenMenu then pcall(self.native.OpenMenu, self.native) end
        return
    end
    if open and open ~= self then open:Close() end
    local menu = self.menu
    local rows = menu.rows
    local y, widest = -6, 0
    for i, option in ipairs(self.options) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(ROW_HEIGHT)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 6, 0)
            row.text:SetJustifyH("LEFT")
            row.line = row:CreateTexture(nil, "ARTWORK")
            row.line:SetColorTexture(1, 1, 1, 0.15)
            row.line:SetHeight(1)
            row.line:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 4, SEPARATOR_GAP / 2)
            row.line:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -4, SEPARATOR_GAP / 2)
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
            row:GetHighlightTexture():SetVertexColor(unpack(ns.Theme.COLORS.highlight))
            row:SetScript("OnClick", function(r)
                self:Close()
                if r.action then r.action() else self:Choose(r.value) end
            end)
            rows[i] = row
        end
        if option.separator then y = y - SEPARATOR_GAP end
        row.line:SetShown(option.separator and true or false)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, y)
        row:SetPoint("TOPRIGHT", -6, y)
        y = y - ROW_HEIGHT
        row.value = option.value
        row.action = option.action
        row.text:SetText(option.text)
        if option.action then
            row.text:SetTextColor(unpack(ACTION_COLOR))
        elseif option.value == self.value then
            row.text:SetTextColor(1, 0.82, 0)
        else
            row.text:SetTextColor(1, 1, 1)
        end
        widest = math.max(widest, row.text:GetStringWidth() or 0)
        row:Show()
    end
    for i = #self.options + 1, #rows do rows[i]:Hide() end
    local margin = ns.Theme.DROPDOWN_MARGIN
    local minWidth = self.button:GetWidth() - margin * 2
    menu:SetWidth(math.max(minWidth, widest + TEXT_PADDING))
    menu:SetHeight(-y + 6)
    menu:Show()
    if open ~= self then
        open = self
        if OutsideClicksSupported() then
            ns.Events:Register(OUTSIDE_EVENT, OnMouseDown, "Dropdown")
        end
    end
end

function methods:Choose(value)
    self.value = value
    self:Refresh()
    if self.onSelect then self.onSelect(value) end
end

function methods:Refresh()
    for _, option in ipairs(self.options) do
        if not option.action and option.value == self.value then
            self.button.text:SetText(option.text)
            return
        end
    end
    self.button.text:SetText("")
end

function methods:SetOptions(options, value)
    self.options = options
    self.value = value
    self:Refresh()
    if self.native then
        if self.native.GenerateMenu then pcall(self.native.GenerateMenu, self.native) end
        return
    end
    if self.menu:IsShown() then self:Open() end
end

local function ShowTooltip(frame, text)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function Dropdown.Create(parent, width, onSelect, tooltip)
    local dd = { options = {}, onSelect = onSelect }
    for name, fn in pairs(methods) do dd[name] = fn end

    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    dd.native = NativeDropdown(dd, button)
    if dd.native then
        button:SetHeight(ns.Theme.DROPDOWN_HEIGHT)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:Hide()
    else
        button.text = ns.Theme.DropdownArt(button)
        button:SetScript("OnClick", function()
            if dd.menu:IsShown() then dd:Close() else dd:Open() end
        end)
    end
    if tooltip then
        button.tooltip = tooltip
        local target = dd.native or button
        target:HookScript("OnEnter", function(self) ShowTooltip(self, tooltip) end)
        target:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    dd.button = button

    local menu = ns.Theme.Popup("Frame", nil, button)
    menu:SetFrameStrata("TOOLTIP")
    local margin = ns.Theme.DROPDOWN_MARGIN
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", margin, 6)
    menu:Hide()
    menu.rows = {}
    menu:SetScript("OnHide", function() dd:Close() end)
    dd.menu = menu

    return dd
end
