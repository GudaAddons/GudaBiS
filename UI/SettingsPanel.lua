-- GudaBiS's page in the game options, Esc -> Options -> AddOns (GB-080). /gbis options
-- and a right-click on the minimap button open it. Built like HeadHunter's: our own
-- frame with plain checkboxes, a grey line under each, registered as a Settings API
-- canvas category (the only options API TBC Anniversary has, probe 2026-10-28), with
-- the older InterfaceOptions list as a fallback.
--
-- Only an empty frame exists at login, because the category needs one; its widgets are
-- built the first time the page shows (RULES.md Rule 1). Every change goes through
-- Database:SetSetting, so the minimap button and the slash commands follow at once.
--
-- Sections: loot alerts, auto-roll (unavailable while Gargul is loaded), panel and
-- minimap button, and About with the Wowhead credit (RULES.md Rule 7).
--
-- Pure parts, tested offline: SettingsPanel.OPTIONS, Get, Set, Available.

local addonName, ns = ...
local L = ns.L

local SettingsPanel = ns:RegisterModule("SettingsPanel")

local LEFT = 16
local CHECK_LEFT = 20
local TIP_INDENT = 30
local SECTION_GAP = 12
local ROW_GAP = 40

-- kind "toggle" only for now; invert shows the opposite of the stored value.
SettingsPanel.OPTIONS = {
    { section = "SET_SECTION_ALERTS" },
    { key = "alerts", path = "alerts.enabled", label = "SET_ALERTS", tip = "SET_ALERTS_TIP" },
    { key = "sound", path = "alerts.sound", label = "SET_SOUND", tip = "SET_SOUND_TIP" },
    { key = "alts", path = "alerts.alts", label = "SET_ALTS", tip = "SET_ALTS_TIP" },
    { section = "SET_SECTION_AUTOROLL" },
    { key = "autoRoll", path = "autoRoll", label = "SET_AUTOROLL", tip = "SET_AUTOROLL_TIP",
        available = function() return not ns.AutoRoll:GargulLoaded() end, unavailable = "SET_AUTOROLL_GARGUL" },
    { section = "SET_SECTION_DISPLAY" },
    { key = "panelOpen", path = "panelOpen", label = "SET_PANEL_OPEN", tip = "SET_PANEL_OPEN_TIP" },
    { key = "minimap", path = "minimap.hidden", invert = true, label = "SET_MINIMAP", tip = "SET_MINIMAP_TIP" },
}

function SettingsPanel.Option(key)
    for _, option in ipairs(SettingsPanel.OPTIONS) do
        if option.key == key then return option end
    end
    return nil
end

function SettingsPanel.Available(option)
    return option.available == nil or option.available() == true
end

function SettingsPanel.Get(option)
    local value = ns.Database:GetSetting(option.path) == true
    if option.invert then return not value end
    return value
end

function SettingsPanel.Set(option, value)
    if not SettingsPanel.Available(option) then return false end
    value = value and true or false
    if option.invert then value = not value end
    ns.Database:SetSetting(option.path, value)
    return true
end

local panel, built
local widgets = {}

local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

local function AddToggle(option, y)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", CHECK_LEFT, y)
    local label = Label(panel, L[option.label])
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    local tip = Label(panel, L[option.tip], "GameFontDisableSmall")
    tip:SetPoint("TOPLEFT", check, "BOTTOMLEFT", TIP_INDENT, 4)
    tip:SetPoint("RIGHT", panel, "RIGHT", -LEFT, 0)
    local note = option.unavailable and Label(panel, L[option.unavailable], "GameFontRedSmall")
    if note then note:SetPoint("LEFT", label, "RIGHT", 8, 0) end
    check:SetScript("OnClick", function(self)
        SettingsPanel.Set(option, self:GetChecked())
        widgets[option.key]()
    end)
    widgets[option.key] = function()
        local available = SettingsPanel.Available(option)
        check:SetChecked(SettingsPanel.Get(option))
        if available then check:Enable() else check:Disable() end
        label:SetFontObject(available and "GameFontHighlight" or "GameFontDisable")
        if note then note:SetShown(not available) end
    end
    return y - ROW_GAP
end

local function AddAbout(y)
    local header = Label(panel, L.SET_SECTION_ABOUT, "GameFontNormal")
    header:SetPoint("TOPLEFT", LEFT, y - SECTION_GAP)
    local author = Label(panel, string.format(L.SET_ABOUT_AUTHOR, ns.author))
    author:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -8)
    local credit = Label(panel, L.SET_ABOUT_WOWHEAD, "GameFontHighlightSmall")
    credit:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -6)
    credit:SetPoint("RIGHT", panel, "RIGHT", -LEFT, 0)
end

local function Build()
    built = true
    local title = Label(panel, addonName, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", LEFT, -LEFT)
    local version = Label(panel, "v" .. tostring(ns.version), "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    local y = -48
    for _, option in ipairs(SettingsPanel.OPTIONS) do
        if option.section then
            local header = Label(panel, L[option.section], "GameFontNormal")
            header:SetPoint("TOPLEFT", LEFT, y - SECTION_GAP)
            y = y - SECTION_GAP - 20
        else
            y = AddToggle(option, y)
        end
    end
    AddAbout(y)
end

function SettingsPanel:Refresh()
    if not built then return end
    for _, refresh in pairs(widgets) do refresh() end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "GudaBiSSettingsPanel", UIParent)
    panel.name = addonName
    panel:Hide()
    panel:SetScript("OnShow", function()
        if not built then Build() end
        SettingsPanel:Refresh()
    end)
    panel.okay, panel.cancel, panel.default = function() end, function() end, function() end
    panel.refresh = function() SettingsPanel:Refresh() end
end

-- "settings", "interface" or nil.
function SettingsPanel:Register()
    if not panel then CreatePanel() end
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, addonName)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            self.category = category
            return "settings"
        end
    end
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        return "interface"
    end
    return nil
end

function SettingsPanel:Open()
    if self.registered == "settings" and Settings.OpenToCategory then
        local id = self.category.GetID and self.category:GetID() or self.category.ID
        pcall(Settings.OpenToCategory, id)
        return true
    end
    if self.registered == "interface" and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
        return true
    end
    return false
end

ns.Events:Register("GBIS_INITIALIZED", function()
    SettingsPanel.registered = SettingsPanel:Register()
    ns.Events:Register("GBIS_SETTING_CHANGED", function()
        if panel:IsShown() then SettingsPanel:Refresh() end
    end, "SettingsPanel")
end, "SettingsPanel")

ns.SlashCommands:Register("options", function()
    if not SettingsPanel:Open() then ns:Print(L.SET_UNAVAILABLE) end
end, L.HELP_OPTIONS)
