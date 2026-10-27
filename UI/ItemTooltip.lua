-- Item tooltips the way the game's own item buttons show them: with the shift-compare
-- tooltips (in game, 2026-10-28: they were missing on our items).
--
-- After an item tooltip is drawn, ItemTooltip.Compare shows Blizzard's comparison
-- tooltips when the "compare items" modifier is held (Shift by default) or the
-- "Always compare items" option is on. While an item is hovered, MODIFIER_STATE_CHANGED
-- redraws it, so pressing or releasing Shift shows or hides the comparison at once; the
-- event is registered only for the hover (RULES.md Rule 1).
--
--   ItemTooltip.Compare()
--   ItemTooltip.Track(owner, redraw)   while `owner` holds GameTooltip
--   ItemTooltip.Untrack()

local addonName, ns = ...

local ItemTooltip = ns:RegisterModule("ItemTooltip")

local EVENT = "MODIFIER_STATE_CHANGED"

local tracked, redraw

local function Wanted()
    if IsModifiedClick and IsModifiedClick("COMPAREITEMS") then return true end
    local getBool = ns.GetCVarBool
    return getBool ~= nil and getBool("alwaysCompareItems") == true
end

function ItemTooltip.Compare()
    if Wanted() and GameTooltip_ShowCompareItem then
        GameTooltip_ShowCompareItem(GameTooltip)
    end
end

function ItemTooltip.Untrack()
    if not tracked then return end
    tracked, redraw = nil, nil
    ns.Events:Unregister(EVENT, "ItemTooltip")
end

local function OnModifier()
    if tracked and GameTooltip:IsOwned(tracked) then
        redraw(tracked)
    else
        ItemTooltip.Untrack()
    end
end

function ItemTooltip.Track(owner, redrawFn)
    if not tracked then ns.Events:Register(EVENT, OnModifier, "ItemTooltip") end
    tracked, redraw = owner, redrawFn
end
