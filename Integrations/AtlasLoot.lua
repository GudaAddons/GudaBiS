-- AtlasLoot (GB-072): the wishlist shield at the right end of every item row AtlasLoot
-- shows, left of the row's faction icon or second item icon when it has one (author,
-- 2026-10-28: beside the item, not on its icon).
--
-- Read from AtlasLootClassic Continued 12455 (Button/Item_type.lua, Button/Button.lua).
-- Item buttons are reused for every page and boss: the "Item" button type's Refresh
-- fills one (button.ItemID is set first, and Refresh runs again when item info
-- arrives), OnClear empties one before it may become a header or a set. Both are looked
-- up on the shared type table, so post-hooks on it see every button. The small second
-- icon on a row (button.secButton, type "secButton") gets no shield of its own, so a row
-- never shows two, and the set/token popup (IsExtraItemFrameButton) is left alone.
--
-- Nothing here is a documented API: every access is guarded, and a failure only means
-- no shields (RULES.md Rule 5).

local addonName, ns = ...

local AtlasLootBridge = ns:RegisterModule("AtlasLootBridge")

local hooked = false

local GAP = 4

local function Shown(frame)
    return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown()
end

-- The shield's place at the row's right end: left of the faction icon or the second
-- item icon when the row shows one, else against the row's right edge.
local function Neighbour(button)
    if Shown(button.factionIcon) then return button.factionIcon end
    if Shown(button.secButton) then return button.secButton end
    return nil
end

local function OnRefresh(button)
    if type(button) ~= "table" or button.IsExtraItemFrameButton or button.type == "secButton" then return end
    local itemID = tonumber(button.ItemID)
    if not itemID or itemID <= 0 then
        ns.WishToggle.Hide(button)
        return
    end
    local neighbour = Neighbour(button)
    if neighbour then
        ns.WishToggle.Paint(button, "RIGHT", neighbour, "LEFT", -GAP, 0, itemID)
    else
        ns.WishToggle.Paint(button, "RIGHT", button, "RIGHT", -GAP, 0, itemID)
    end
end

local function OnClear(button)
    if type(button) ~= "table" then return end
    ns.WishToggle.Hide(button)
    if type(button.secButton) == "table" then ns.WishToggle.Hide(button.secButton) end
end

local function Guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then ns:Debug("AtlasLoot shield:", err) end
    end
end

local function ItemType()
    local atlasLoot = _G.AtlasLoot
    local buttons = type(atlasLoot) == "table" and atlasLoot.Button
    if type(buttons) ~= "table" or type(buttons.GetType) ~= "function" then return nil end
    local ok, itemType = pcall(buttons.GetType, buttons, "Item")
    return ok and type(itemType) == "table" and itemType or nil
end

function AtlasLootBridge:Hook()
    if hooked then return true end
    local itemType = ItemType()
    if not (itemType and type(itemType.Refresh) == "function") then return false end
    hooksecurefunc(itemType, "Refresh", Guarded(OnRefresh))
    if type(itemType.OnClear) == "function" then hooksecurefunc(itemType, "OnClear", Guarded(OnClear)) end
    hooked = true
    return true
end

ns.Events:Register("GBIS_INITIALIZED", function() AtlasLootBridge:Hook() end, "AtlasLootBridge")
ns.Events:Register("ADDON_LOADED", function(_, name)
    if name == "AtlasLoot" then AtlasLootBridge:Hook() end
end, "AtlasLootBridge")
