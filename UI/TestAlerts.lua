-- /gbis test: every loot alert at once, solo, with a real item from the MS list, so
-- their look can be checked without a raid. Nothing rolls: the test roll popup's
-- buttons only close it, and the dummy roll frame is ours, not Blizzard's.
--
--   1. the "Your BiS dropped!" toast
--   2. the "Rolling now" popup, 15 s
--   3. a dummy Need/Greed/Pass frame, shaped like Blizzard's group-loot popup, with the
--      badge and the proc glow on its Need button; it closes after 20 s or on any click

local addonName, ns = ...
local L = ns.L

local TestAlerts = ns:RegisterModule("TestAlerts")

local TEST_ROLL_SECONDS = 15
local DUMMY_SECONDS = 20
local SLOT_ORDER = { 1, 5, 7, 3, 10, 6, 8, 9, 2, 15, 11, 12, 13, 14, 16, 17, 18 }

local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-"
local COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-"
local PASS_ART = "Interface\\Buttons\\UI-GroupLoot-Pass-"

local dummy

-- The MS list's head, or the first slot it fills; nil when there is no MS list item.
local function SampleItem()
    local list = ns.Lists:MainSpec()
    if not list then return nil end
    for _, slot in ipairs(SLOT_ORDER) do
        if list.items[slot] then return list.items[slot], slot end
    end
    return nil
end

local function SampleLink(itemID)
    local _, link = ns.GetItemInfo(itemID)
    return link or ("|cffa335ee|Hitem:" .. itemID .. "::::::::70:::::|h[" .. itemID .. "]|h|r")
end

local function RollButton(parent, art, tooltip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    button:SetNormalTexture(art .. "Up")
    button:SetPushedTexture(art .. "Down")
    button:SetHighlightTexture(art .. "Highlight")
    button.tooltip = tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function() dummy:Hide() end)
    return button
end

local function CreateDummy()
    dummy = ns.Theme.Dialog("GudaBiSTestRoll", UIParent)
    dummy:SetSize(300, 84)
    dummy:SetPoint("BOTTOM", 0, 220)
    dummy:SetFrameStrata("DIALOG")
    dummy:Hide()
    dummy.title = dummy:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dummy.title:SetPoint("TOP", 0, -16)
    dummy.title:SetText(L.TEST_FRAME)
    dummy.icon = dummy:CreateTexture(nil, "ARTWORK")
    dummy.icon:SetSize(34, 34)
    dummy.icon:SetPoint("LEFT", 18, -6)
    dummy.name = dummy:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dummy.name:SetPoint("LEFT", dummy.icon, "RIGHT", 8, 0)
    dummy.name:SetWidth(120)
    dummy.name:SetJustifyH("LEFT")
    dummy.name:SetWordWrap(false)
    dummy.pass = RollButton(dummy, PASS_ART, PASS)
    dummy.pass:SetPoint("RIGHT", -16, -6)
    dummy.greed = RollButton(dummy, COIN, GREED)
    dummy.greed:SetPoint("RIGHT", dummy.pass, "LEFT", -4, 0)
    dummy.NeedButton = RollButton(dummy, DICE, NEED)
    dummy.NeedButton:SetPoint("RIGHT", dummy.greed, "LEFT", -4, 0)
end

local function ShowDummy(itemID, link, match)
    if not dummy then CreateDummy() end
    local _, _, _, _, icon = ns.GetItemInfoInstant(itemID)
    dummy.icon:SetTexture(icon)
    local name, _, quality = ns.GetItemInfo(itemID)
    dummy.name:SetText(name or link)
    dummy.name:SetTextColor(ns.Items.QualityColor(quality))
    dummy.token = (dummy.token or 0) + 1
    local token = dummy.token
    dummy:Show()
    ns.Alerts:Badge(dummy, match, dummy.NeedButton)
    C_Timer.After(DUMMY_SECONDS, function()
        if dummy.token == token then dummy:Hide() end
    end)
end

function TestAlerts:Run()
    local itemID, slot = SampleItem()
    if not itemID then
        ns:Print(L.TEST_NO_LIST)
        return
    end
    local link = SampleLink(itemID)
    local match = { role = "ms", rank = 1, slot = slot }
    ns.Alerts:Dropped(link, match)
    ns.Alerts:Rolling(link, match, TEST_ROLL_SECONDS, true)
    ShowDummy(itemID, link, match)
end

ns.SlashCommands:Register("test", function() TestAlerts:Run() end, L.HELP_TEST)
