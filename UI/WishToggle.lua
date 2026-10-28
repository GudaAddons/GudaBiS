-- The wishlist toggle other addons' item buttons get (GB-072): a small GudaBiS shield on
-- the item icon, dim and grey while the item is not on this character's wishlist, in
-- full colour while it is. A click adds or removes it; the tooltip says which.
--
-- The integrations (AtlasLoot, ForeverDungeonJournal) reuse their item buttons, so the
-- toggle is made once per button, the first time that button shows an item, and
-- repainted on every fill. Shown toggles repaint when the wishlist changes anywhere.
--
-- Also here: "On your GudaBiS wishlist" on any item tooltip for a wished item.
--
--   WishToggle.Paint(owner, anchor, point, x, y, itemID[, source])
--   WishToggle.Hide(owner)

local addonName, ns = ...
local L = ns.L

local WishToggle = ns:RegisterModule("WishToggle")

local SIZE = 14
local ICON = "Interface\\AddOns\\GudaBiS\\Assets\\logo.png"
local OFF_ALPHA = 0.45
local TOOLTIP_COLOR = { 1, 0.6, 1 }

local toggles = setmetatable({}, { __mode = "k" })

local function PaintState(toggle)
    local on = ns.Wishlist:Has(toggle.itemID)
    toggle.icon:SetDesaturated(not on)
    toggle.icon:SetAlpha(on and 1 or OFF_ALPHA)
    toggle.on = on
end

local function ShowTooltip(toggle)
    GameTooltip:SetOwner(toggle, "ANCHOR_RIGHT")
    GameTooltip:SetText(toggle.on and L.WISH_REMOVE or L.WISH_ADD)
    GameTooltip:Show()
end

local function OnClick(toggle)
    ns.Wishlist:Toggle(toggle.itemID, toggle.source)
    PaintState(toggle)
    if GameTooltip:IsOwned(toggle) then ShowTooltip(toggle) end
end

local function Create(owner)
    local toggle = CreateFrame("Button", nil, owner)
    toggle:SetSize(SIZE, SIZE)
    toggle:SetFrameLevel((owner:GetFrameLevel() or 0) + 5)
    toggle.icon = toggle:CreateTexture(nil, "OVERLAY")
    toggle.icon:SetTexture(ICON)
    toggle.icon:SetAllPoints()
    toggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    toggle:SetScript("OnClick", OnClick)
    toggle:SetScript("OnEnter", ShowTooltip)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    owner.gudaBiSWish = toggle
    toggles[toggle] = true
    return toggle
end

function WishToggle.Paint(owner, anchor, point, x, y, itemID, source)
    local toggle = owner.gudaBiSWish or Create(owner)
    toggle:ClearAllPoints()
    toggle:SetPoint(point, anchor or owner, point, x, y)
    toggle.itemID = itemID
    toggle.source = source
    PaintState(toggle)
    toggle:Show()
    return toggle
end

function WishToggle.Hide(owner)
    local toggle = owner and owner.gudaBiSWish
    if toggle then toggle:Hide() end
end

ns.Events:Register("GBIS_WISHLIST_CHANGED", function()
    for toggle in pairs(toggles) do
        if toggle:IsShown() and toggle.itemID then PaintState(toggle) end
    end
end, "WishToggle")

local function AddTooltipLine(tooltip)
    if not (tooltip and tooltip.GetItem) then return end
    local _, link = tooltip:GetItem()
    local itemID = ns.Match.ItemIDFromLink(link)
    if itemID and ns.Wishlist:Has(itemID) then
        tooltip:AddLine(L.WISHLIST_TOOLTIP, TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3])
    end
end

-- Retail draws item tooltips from tooltip data; the Classic flavors fire
-- OnTooltipSetItem. Whichever the client has is used.
local function HookTooltips()
    local processor = TooltipDataProcessor
    local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if processor and processor.AddTooltipPostCall and itemType then
        processor.AddTooltipPostCall(itemType, AddTooltipLine)
        return
    end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip and tooltip.HookScript then tooltip:HookScript("OnTooltipSetItem", AddTooltipLine) end
    end
end

ns.Events:Register("GBIS_INITIALIZED", HookTooltips, "WishToggle")
