-- What the player sees when a BiS item comes up (GB-061/062):
--
--   Alerts:Badge(frame, match, needButton)   "Your BiS" on someone else's roll frame
--                                            (Blizzard, Gargul, RCLootCouncil) and a
--                                            pulsing glow on its Need button, if given
--   Alerts:ClearBadge(frame)
--   Alerts:Dropped(link, match)              "Your BiS dropped!" toast, 15 s
--   Alerts:Rolling(link, match, seconds)     "Rolling now" popup with MS (1-100) and
--                                            OS (1-99) buttons and a countdown; only when
--                                            no other addon shows its own roll window
--   Alerts:Sound()
--
-- Frames are built on first use. The popup never rolls by itself: RandomRoll runs only
-- from the player's click (RULES.md Rule 4).

local addonName, ns = ...
local L = ns.L

local Alerts = ns:RegisterModule("Alerts")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

local TOAST_SECONDS = 15
local DEFAULT_ROLL_SECONDS = 30
local ROLE_COLORS = { ms = { 0.25, 1, 0.25 }, os = { 0.25, 0.75, 1 } }
local RAID_WARNING_SOUND = 8959

local function Setting(key)
    local alerts = ns.db and ns.db.settings.alerts
    if not alerts then return true end
    return alerts[key] ~= false
end

function Alerts:Enabled()
    return Setting("enabled")
end

function Alerts:Sound()
    if not Setting("sound") then return end
    local sound = SOUNDKIT and SOUNDKIT.RAID_WARNING or RAID_WARNING_SOUND
    PlaySound(sound, "Master")
end

local function BadgeText(match)
    return string.format(L.BADGE, ns.Match.Label(match))
end

-- One overlay per foreign frame, made the first time that frame gets a badge, and
-- hidden whenever the frame hides (frames are reused for the next roll).
local function Overlay(frame)
    local overlay = frame.gudaBiSBadge
    if overlay then return overlay end
    overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", overlay, "TOP", 0, 2)
    overlay.label = label
    frame:HookScript("OnHide", function() Alerts:ClearBadge(frame) end)
    frame.gudaBiSBadge = overlay
    return overlay
end

function Alerts:Badge(frame, match, needButton)
    if not frame then return end
    local overlay = Overlay(frame)
    local color = ROLE_COLORS[match.role]
    overlay.label:SetText(BadgeText(match))
    overlay.label:SetTextColor(color[1], color[2], color[3])
    overlay.label:Show()
    if needButton then
        ns.Glow.Show(needButton)
        overlay.glowTarget = needButton
    end
    overlay:Show()
end

function Alerts:ClearBadge(frame)
    local overlay = frame and frame.gudaBiSBadge
    if not overlay then return end
    if overlay.glowTarget then
        ns.Glow.Hide(overlay.glowTarget)
        overlay.glowTarget = nil
    end
    overlay.label:Hide()
end

local function ItemIcon(link)
    local itemID = ns.Match.ItemIDFromLink(link)
    local _, _, _, _, icon = GetItemInfoInstant(itemID or 0)
    return icon
end

local function ShowLinkTooltip(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function ItemButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    ns.Theme.SlotFrame(button, size)
    button:SetScript("OnEnter", ShowLinkTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local toast

local function CreateToast()
    toast = ns.Theme.Popup("Frame", "GudaBiSDropToast", UIParent)
    toast:SetSize(300, 52)
    toast:SetPoint("TOP", 0, -150)
    toast:SetFrameStrata("HIGH")
    toast:Hide()
    toast.item = ItemButton(toast, 34)
    toast.item:SetPoint("LEFT", 10, 0)
    toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.title:SetPoint("TOPLEFT", toast.item, "TOPRIGHT", 8, -1)
    toast.name = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toast.name:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
    toast.name:SetPoint("RIGHT", -10, 0)
    toast.name:SetJustifyH("LEFT")
    toast.name:SetWordWrap(false)
end

local function ItemName(link)
    local name, _, quality = GetItemInfo(link)
    if name then
        local r, g, b = ns.Items.QualityColor(quality)
        return name, r, g, b
    end
    return link:match("%[(.-)%]") or link, 1, 1, 1
end

function Alerts:Dropped(link, match)
    if not toast then CreateToast() end
    local color = ROLE_COLORS[match.role]
    toast.title:SetText(string.format(L.ALERT_DROPPED, ns.Match.Label(match)))
    toast.title:SetTextColor(color[1], color[2], color[3])
    local name, r, g, b = ItemName(link)
    toast.name:SetText(name)
    toast.name:SetTextColor(r, g, b)
    toast.item.link = link
    toast.item.icon:SetTexture(ItemIcon(link))
    toast.token = (toast.token or 0) + 1
    local token = toast.token
    toast:Show()
    C_Timer.After(TOAST_SECONDS, function()
        if toast.token == token then toast:Hide() end
    end)
    self:Sound()
end

local popup

local function StopCountdown()
    if popup and popup.ticker then
        popup.ticker:Cancel()
        popup.ticker = nil
    end
end

local function Roll(low, high)
    RandomRoll(low, high)
    StopCountdown()
    popup:Hide()
end

local function CreatePopup()
    popup = ns.Theme.Dialog("GudaBiSRollPopup", UIParent)
    popup:SetSize(320, 116)
    popup:SetPoint("TOP", 0, -210)
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup:Hide()
    popup.item = ItemButton(popup, 36)
    popup.item:SetPoint("TOPLEFT", 20, -20)
    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOPLEFT", popup.item, "TOPRIGHT", 8, 0)
    popup.title:SetPoint("RIGHT", -20, 0)
    popup.title:SetJustifyH("LEFT")
    popup.name = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.name:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -3)
    popup.name:SetPoint("RIGHT", -20, 0)
    popup.name:SetJustifyH("LEFT")
    popup.name:SetWordWrap(false)
    popup.countdown = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.countdown:SetPoint("TOPRIGHT", -20, -20)
    local ms = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    ms:SetSize(120, 22)
    ms:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 18)
    ms:SetText(L.ROLL_MS)
    ms:SetScript("OnClick", function() Roll(1, 100) end)
    popup.ms = ms
    local off = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    off:SetSize(120, 22)
    off:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 18)
    off:SetText(L.ROLL_OS)
    off:SetScript("OnClick", function() Roll(1, 99) end)
    popup.os = off
    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        StopCountdown()
        popup:Hide()
    end)
end

function Alerts:Rolling(link, match, seconds)
    if not popup then CreatePopup() end
    StopCountdown()
    local color = ROLE_COLORS[match.role]
    popup.title:SetText(string.format(L.ALERT_ROLLING, ns.Match.Label(match)))
    popup.title:SetTextColor(color[1], color[2], color[3])
    local name, r, g, b = ItemName(link)
    popup.name:SetText(name)
    popup.name:SetTextColor(r, g, b)
    popup.item.link = link
    popup.item.icon:SetTexture(ItemIcon(link))
    if match.role == "ms" then popup.ms:LockHighlight() else popup.ms:UnlockHighlight() end
    if match.role == "os" then popup.os:LockHighlight() else popup.os:UnlockHighlight() end
    local remaining = seconds or DEFAULT_ROLL_SECONDS
    popup.countdown:SetText(string.format(L.ROLL_SECONDS, remaining))
    popup.ticker = C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        if remaining <= 0 then
            StopCountdown()
            popup:Hide()
            return
        end
        popup.countdown:SetText(string.format(L.ROLL_SECONDS, remaining))
    end, remaining)
    popup:Show()
    self:Sound()
end

function Alerts:CloseRolling()
    if popup then
        StopCountdown()
        popup:Hide()
    end
end
