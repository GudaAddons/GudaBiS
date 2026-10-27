-- A small dropdown: a button showing the current choice and a menu of options.
-- Options are { value = v, text = "..." }. The menu closes on a choice, on a second
-- click of the button, or on a click anywhere else, caught by a full-screen catcher
-- frame behind the menu, so nothing polls while it is open (RULES.md Rule 1).
--
--   local dd = ns.Dropdown.Create(parent, width, onSelect)
--   dd:SetOptions(options, selectedValue)

local addonName, ns = ...

local Dropdown = ns:RegisterModule("Dropdown")

local ROW_HEIGHT = 18

local catcher

local function Catcher()
    if catcher then return catcher end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    catcher:SetScript("OnClick", function(self)
        if self.owner then self.owner:Close() end
    end)
    return catcher
end

local methods = {}

function methods:Close()
    self.menu:Hide()
    local c = Catcher()
    if c.owner == self then
        c.owner = nil
        c:Hide()
    end
end

function methods:Open()
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
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * ROW_HEIGHT)
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
    menu:SetHeight(8 + #self.options * ROW_HEIGHT)
    local c = Catcher()
    if c.owner and c.owner ~= self then c.owner:Close() end
    c.owner = self
    c:Show()
    menu:Show()
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

    local button = ns.Theme.CreateWindow("Button", nil, parent)
    button:SetSize(width, 22)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 8, 0)
    button.text:SetPoint("RIGHT", -20, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(-math.pi / 2)
    button:SetScript("OnClick", function()
        if dd.menu:IsShown() then dd:Close() else dd:Open() end
    end)
    dd.button = button

    -- The menu sits one strata above the catcher (FULLSCREEN_DIALOG), not just a few
    -- frame levels: levels get re-based when the panel is raised, and a catcher drawn
    -- over the rows swallowed every click on an option (in game, 2026-10-28).
    local menu = ns.Theme.CreateWindow("Frame", nil, button)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    menu:Hide()
    menu.rows = {}
    menu:SetScript("OnHide", function() dd:Close() end)
    dd.menu = menu

    return dd
end
