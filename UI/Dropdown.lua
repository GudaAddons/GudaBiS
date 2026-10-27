-- A small dropdown: a button showing the current choice and a menu of options.
-- Options are { value = v, text = "..." }. The menu closes on a choice, on a second
-- click of the button, or on a click anywhere else.
--
-- "Anywhere else" is the client's GLOBAL_MOUSE_DOWN, listened to only while a menu is
-- open (RULES.md Rule 1). An earlier full-screen catcher frame behind the menu ended up
-- drawn over the options in game and swallowed every click on them (2026-10-28), so
-- nothing may sit between the player and the rows.
--
--   local dd = ns.Dropdown.Create(parent, width, onSelect)
--   dd:SetOptions(options, selectedValue)

local addonName, ns = ...

local Dropdown = ns:RegisterModule("Dropdown")

local ROW_HEIGHT = 18
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

function methods:Close()
    self.menu:Hide()
    if open == self then
        open = nil
        ns.Events:Unregister(OUTSIDE_EVENT, "Dropdown")
    end
end

function methods:Open()
    if open and open ~= self then open:Close() end
    local menu = self.menu
    local rows = menu.rows
    for i, option in ipairs(self.options) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(ROW_HEIGHT)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 6, 0)
            row.text:SetJustifyH("LEFT")
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
            row:GetHighlightTexture():SetVertexColor(unpack(ns.Theme.COLORS.highlight))
            row:SetScript("OnClick", function(r)
                self:Close()
                self:Choose(r.value)
            end)
            rows[i] = row
        end
        row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * ROW_HEIGHT)
        row.value = option.value
        row.text:SetText(option.text)
        if option.value == self.value then
            row.text:SetTextColor(1, 0.82, 0)
        else
            row.text:SetTextColor(1, 1, 1)
        end
        row:Show()
    end
    for i = #self.options + 1, #rows do rows[i]:Hide() end
    menu:SetHeight(12 + #self.options * ROW_HEIGHT)
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
        if option.value == self.value then
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
    if self.menu:IsShown() then self:Open() end
end

function Dropdown.Create(parent, width, onSelect)
    local dd = { options = {}, onSelect = onSelect }
    for name, fn in pairs(methods) do dd[name] = fn end

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    ns.Theme.DropdownArt(button)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 4, 1)
    button.text:SetPoint("RIGHT", -22, 1)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button:SetScript("OnClick", function()
        if dd.menu:IsShown() then dd:Close() else dd:Open() end
    end)
    dd.button = button

    local menu = ns.Theme.Popup("Frame", nil, button)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -4, -4)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 4, -4)
    menu:Hide()
    menu.rows = {}
    menu:SetScript("OnHide", function() dd:Close() end)
    dd.menu = menu

    return dd
end
