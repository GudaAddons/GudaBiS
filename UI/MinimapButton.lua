-- The minimap button (GB-081), our own rather than LibDBIcon, built like HeadHunter's.
-- Left-click shows or hides the panel, right-click opens the settings page, dragging
-- moves it around the minimap edge (settings.minimap.angle). The tooltip also says
-- whether auto-roll is on. Hidden from the settings page or with /gbis minimap.
--
-- Built at login only when it is shown; dragging runs an OnUpdate only while the
-- mouse button is held (RULES.md Rule 1).
--
-- Pure part, tested offline: MinimapButton.Offset.

local addonName, ns = ...
local L = ns.L

local MinimapButton = ns:RegisterModule("MinimapButton")

MinimapButton.ICON = "Interface\\AddOns\\GudaBiS\\Assets\\logo.png"
MinimapButton.SIZE = 31

local button

function MinimapButton.Offset(angle, radius)
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

local function Settings()
    return ns.db.settings.minimap
end

local function Place()
    local radius = (Minimap:GetWidth() or 140) / 2 + 10
    local x, y = MinimapButton.Offset(Settings().angle, radius)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and px and scale and scale > 0) then return end
    Settings().angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    Place()
end

local function AutoRollLine()
    local AutoRoll = ns.AutoRoll
    if not AutoRoll:Enabled() then return L.MINIMAP_AUTOROLL_OFF end
    if AutoRoll:GargulLoaded() then return L.MINIMAP_AUTOROLL_GARGUL end
    return L.MINIMAP_AUTOROLL_ON
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(addonName)
    GameTooltip:AddLine(L.MINIMAP_HINT, 1, 1, 1)
    GameTooltip:AddLine(AutoRollLine(), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if not ns.SettingsPanel:Open() then ns:Print(L.SET_UNAVAILABLE) end
    elseif ns.Panel:IsShown() then
        ns.Panel:Close()
    else
        ns.Panel:Open()
    end
end

local function Create()
    button = CreateFrame("Button", "GudaBiSMinimapButton", Minimap)
    button:SetSize(MinimapButton.SIZE, MinimapButton.SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(MinimapButton.ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
end

function MinimapButton:Apply()
    if not Minimap then return end
    if Settings().hidden then
        if button then button:Hide() end
        return
    end
    if not button then Create() end
    button:Show()
end

function MinimapButton:IsShown()
    return button ~= nil and button:IsShown()
end

ns.Events:Register("GBIS_INITIALIZED", function()
    MinimapButton:Apply()
    ns.Events:Register("GBIS_SETTING_CHANGED", function(_, path)
        if path == "minimap.hidden" then MinimapButton:Apply() end
    end, "MinimapButton")
end, "MinimapButton")

ns.SlashCommands:Register("minimap", function()
    ns.Database:SetSetting("minimap.hidden", not Settings().hidden)
    ns:Print(Settings().hidden and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
end, L.HELP_MINIMAP)
