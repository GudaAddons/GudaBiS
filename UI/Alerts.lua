-- What the player sees when a BiS item comes up (GB-061/062):
--
--   Alerts:Badge(frame, match, itemIcon)     a "Your BiS" label above someone else's
--                                            roll frame (Blizzard, Gargul, RCLootCouncil)
--                                            and the proc glow on its item icon, if given.
--                                            The label sits on a dark plate inside the
--                                            same glow, readable on any background
--                                            (author, 2026-10-28: green text alone was
--                                            hard to see)
--   Alerts:ClearBadge(frame)
--   Alerts:Dropped(link, match)              "Your BiS dropped!" card, 15 s
--   Alerts:Rolling(link, match, seconds)     "Rolling now" card with MS (1-100) and
--                                            OS (1-99) buttons and a countdown; only when
--                                            no other addon shows its own roll window
--   Alerts:Sound()
--
-- Both cards share one look (author, 2026-10-28: "more fancy", a close button on the
-- drop card): gold-bordered, they fade and scale in with a light burst behind the item,
-- the item icon carries the proc glow, the item name and its slot (the game's own slot
-- names) sit under a large title, a gold bar along the bottom drains over the time left,
-- and they fade out. Every effect is a client animation; nothing runs per frame. The
-- MS/OS roll buttons stay plain (author: no highlight on them).
--
-- Frames are built on first use. The roll card never rolls by itself: RandomRoll runs
-- only from the player's click (RULES.md Rule 4).

local addonName, ns = ...
local L = ns.L

local Alerts = ns:RegisterModule("Alerts")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

local TOAST_SECONDS = 15
local DEFAULT_ROLL_SECONDS = 30
local BADGE_COLORS = { ms = { 1, 1, 1 }, os = { 0.55, 0.85, 1 }, wish = { 1, 0.6, 1 } }
local TITLE_COLORS = { ms = { 1, 0.82, 0 }, os = { 0.55, 0.85, 1 }, wish = { 1, 0.6, 1 } }
local BADGE_PADDING = 18
local RAID_WARNING_SOUND = 8959

local ALERT_ART = "Interface\\SpellActivationOverlay\\IconAlert"
local SPARK_COORDS = { 0.00781250, 0.61718750, 0.00390625, 0.26953125 }

local SLOT_LABELS = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [15] = "BACKSLOT", [5] = "CHESTSLOT",
    [9] = "WRISTSLOT", [10] = "HANDSSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT",
    [11] = "FINGER0SLOT", [12] = "FINGER1SLOT", [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
    [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT",
}

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
    local plate = CreateFrame("Frame", nil, overlay)
    plate:SetHeight(20)
    plate:SetPoint("BOTTOM", overlay, "TOP", 0, 6)
    local background = plate:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)
    local label = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    plate:Hide()
    overlay.plate = plate
    overlay.label = label
    frame:HookScript("OnHide", function() Alerts:ClearBadge(frame) end)
    frame.gudaBiSBadge = overlay
    return overlay
end

function Alerts:Badge(frame, match, itemIcon)
    if not frame then return end
    local overlay = Overlay(frame)
    local color = BADGE_COLORS[match.role]
    overlay.label:SetText(BadgeText(match))
    overlay.label:SetTextColor(color[1], color[2], color[3])
    overlay.plate:SetWidth(overlay.label:GetStringWidth() + BADGE_PADDING)
    overlay.plate:Show()
    overlay:Show()
    ns.Glow.Show(overlay.plate)
    if itemIcon then
        ns.Glow.Show(itemIcon)
        overlay.glowTarget = itemIcon
    end
end

function Alerts:ClearBadge(frame)
    local overlay = frame and frame.gudaBiSBadge
    if not overlay then return end
    if overlay.glowTarget then
        ns.Glow.Hide(overlay.glowTarget)
        overlay.glowTarget = nil
    end
    ns.Glow.Hide(overlay.plate)
    overlay.plate:Hide()
end

local function ItemIcon(link)
    local itemID = ns.Match.ItemIDFromLink(link)
    local _, _, _, _, icon = GetItemInfoInstant(itemID or 0)
    return icon
end

local function ItemName(link)
    local name, _, quality = GetItemInfo(link)
    if name then
        local r, g, b = ns.Items.QualityColor(quality)
        return name, r, g, b
    end
    return link:match("%[(.-)%]") or link, 1, 1, 1
end

local function ShowLinkTooltip(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
    ns.ItemTooltip.Compare()
    ns.ItemTooltip.Track(self, ShowLinkTooltip)
end

local function ItemButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    ns.Theme.SlotFrame(button, size)
    button:SetScript("OnEnter", ShowLinkTooltip)
    button:SetScript("OnLeave", function()
        ns.ItemTooltip.Untrack()
        GameTooltip:Hide()
    end)
    return button
end

-- A scale animation from one scale to another on any client: SetScaleFrom/To where
-- the client has them, else the older relative SetScale.
local function ScaleAnim(group, target, from, to, duration, origin)
    local anim = group:CreateAnimation("Scale")
    anim:SetTarget(target)
    if anim.SetScaleFrom then
        anim:SetScaleFrom(from[1], from[2])
        anim:SetScaleTo(to[1], to[2])
    else
        anim:SetScale(to[1] / from[1], to[2] / from[2])
    end
    anim:SetDuration(duration)
    if origin then anim:SetOrigin(origin, 0, 0) end
    return anim
end

local function AlphaAnim(group, target, from, to, duration, order)
    local anim = group:CreateAnimation("Alpha")
    anim:SetTarget(target)
    anim:SetFromAlpha(from)
    anim:SetToAlpha(to)
    anim:SetDuration(duration)
    if order then anim:SetOrder(order) end
    return anim
end

local methods = {}

-- Shows the card for `seconds`: entrance, light burst, glowing icon, draining bar.
function methods:Present(seconds)
    self.exit:Stop()
    self:SetAlpha(1)
    self:Show()
    self.entrance:Play()
    self.burst:Play()
    self.barTime:SetDuration(seconds)
    self.drain:Play()
    ns.Glow.Show(self.item)
end

-- Fades the card out, then hides it.
function methods:Dismiss()
    if not self:IsShown() then return end
    self.exit:Play()
end

local function Card(name, width, height, strata)
    local card = ns.Theme.Popup("Frame", name, UIParent)
    for key, fn in pairs(methods) do card[key] = fn end
    card:SetSize(width, height)
    card:SetFrameStrata(strata)
    card:EnableMouse(true)
    card:SetBackdropBorderColor(1, 0.82, 0, 1)
    card:Hide()

    card.item = ItemButton(card, 44)
    card.item:SetPoint("TOPLEFT", 16, -16)

    local spark = card:CreateTexture(nil, "BORDER")
    spark:SetTexture(ALERT_ART)
    spark:SetTexCoord(SPARK_COORDS[1], SPARK_COORDS[2], SPARK_COORDS[3], SPARK_COORDS[4])
    spark:SetBlendMode("ADD")
    spark:SetSize(120, 120)
    spark:SetPoint("CENTER", card.item, "CENTER")
    spark:SetAlpha(0)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.title:SetPoint("TOPLEFT", card.item, "TOPRIGHT", 12, -1)
    card.title:SetPoint("RIGHT", -30, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.name:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.name:SetPoint("RIGHT", -16, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.slot = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.slot:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)

    local bar = card:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(1, 0.82, 0, 0.9)
    bar:SetHeight(3)
    bar:SetPoint("BOTTOMLEFT", 6, 6)
    bar:SetPoint("BOTTOMRIGHT", -6, 6)
    card.bar = bar

    local close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() card:Dismiss() end)
    card.close = close

    card.entrance = card:CreateAnimationGroup()
    AlphaAnim(card.entrance, card, 0, 1, 0.25)
    ScaleAnim(card.entrance, card, { 0.85, 0.85 }, { 1, 1 }, 0.25)

    card.burst = card:CreateAnimationGroup()
    AlphaAnim(card.burst, spark, 0, 1, 0.15, 1)
    AlphaAnim(card.burst, spark, 1, 0, 0.6, 2)
    ScaleAnim(card.burst, spark, { 0.5, 0.5 }, { 1.4, 1.4 }, 0.75)

    card.drain = card:CreateAnimationGroup()
    card.barTime = ScaleAnim(card.drain, bar, { 1, 1 }, { 0.001, 1 }, TOAST_SECONDS, "LEFT")

    card.exit = card:CreateAnimationGroup()
    AlphaAnim(card.exit, card, 1, 0, 0.4)
    card.exit:SetScript("OnFinished", function() card:Hide() end)

    card:SetScript("OnHide", function()
        card.drain:Stop()
        ns.Glow.Hide(card.item)
    end)
    return card
end

local function Fill(card, link, match, titleKey)
    local color = TITLE_COLORS[match.role]
    card.title:SetText(string.format(L[titleKey], ns.Match.Label(match)))
    card.title:SetTextColor(color[1], color[2], color[3])
    local name, r, g, b = ItemName(link)
    card.name:SetText(name)
    card.name:SetTextColor(r, g, b)
    local slotKey = SLOT_LABELS[match.slot]
    card.slot:SetText(slotKey and _G[slotKey] or "")
    card.item.link = link
    card.item.icon:SetTexture(ItemIcon(link))
end

local toast

function Alerts:Dropped(link, match)
    if not toast then
        toast = Card("GudaBiSDropToast", 340, 80, "HIGH")
        toast:SetPoint("TOP", 0, -140)
    end
    Fill(toast, link, match, "ALERT_DROPPED")
    toast.token = (toast.token or 0) + 1
    local token = toast.token
    toast:Present(TOAST_SECONDS)
    C_Timer.After(TOAST_SECONDS, function()
        if toast.token == token then toast:Dismiss() end
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

local function ClosePopup()
    StopCountdown()
    popup:Dismiss()
end

-- A test card (/gbis test) closes without rolling. popup.onRoll tells Detect the player
-- rolled for the item, so a later announcement of it opens no second card.
local function Roll(low, high)
    if not popup.test then
        RandomRoll(low, high)
        if popup.onRoll then popup.onRoll() end
    end
    ClosePopup()
end

local function CreatePopup()
    popup = Card("GudaBiSRollPopup", 340, 118, "DIALOG")
    popup:SetPoint("TOP", 0, -235)
    popup.close:SetScript("OnClick", ClosePopup)
    popup.countdown = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.countdown:SetPoint("TOPRIGHT", -16, -56)
    local ms = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    ms:SetSize(130, 22)
    ms:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -6, 16)
    ms:SetText(L.ROLL_MS)
    ms:SetScript("OnClick", function() Roll(1, 100) end)
    popup.ms = ms
    local off = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    off:SetSize(130, 22)
    off:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 6, 16)
    off:SetText(L.ROLL_OS)
    off:SetScript("OnClick", function() Roll(1, 99) end)
    popup.os = off
    popup:HookScript("OnHide", StopCountdown)
end

function Alerts:Rolling(link, match, seconds, test, onRoll)
    if not popup then CreatePopup() end
    StopCountdown()
    popup.test = test and true or false
    popup.onRoll = onRoll
    Fill(popup, link, match, "ALERT_ROLLING")
    local remaining = seconds or DEFAULT_ROLL_SECONDS
    popup.countdown:SetText(string.format(L.ROLL_SECONDS, remaining))
    popup.ticker = C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        if remaining <= 0 then
            ClosePopup()
            return
        end
        popup.countdown:SetText(string.format(L.ROLL_SECONDS, remaining))
    end, remaining)
    popup:Present(remaining)
    self:Sound()
end
