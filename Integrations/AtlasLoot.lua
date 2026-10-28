-- AtlasLoot (GB-072): the wishlist shield on every item AtlasLoot shows, on the item
-- icon's bottom-left corner (its own favourite star sits top-left, the "completed"
-- check and count bottom-right).
--
-- Read from AtlasLootClassic Continued 12455 (Button/Item_type.lua, Button/Button.lua).
-- Item buttons are reused for every page and boss: the "Item" button type's Refresh
-- fills one (button.ItemID is set first, and Refresh runs again when item info
-- arrives), OnClear empties one before it may become a header or a set. Both are looked
-- up on the shared type table, so post-hooks on it see every button, including the
-- small second icon on the right of a row (button.secButton). The set/token popup's
-- buttons (IsExtraItemFrameButton) are left alone (author, 2026-10-28).
--
-- Nothing here is a documented API: every access is guarded, and a failure only means
-- no shields (RULES.md Rule 5).

local addonName, ns = ...

local AtlasLootBridge = ns:RegisterModule("AtlasLootBridge")

local hooked = false

local function OnRefresh(button)
    if type(button) ~= "table" or button.IsExtraItemFrameButton then return end
    local itemID = tonumber(button.ItemID)
    if not itemID or itemID <= 0 then
        ns.WishToggle.Hide(button)
        return
    end
    ns.WishToggle.Paint(button, button.icon, "BOTTOMLEFT", -2, -2, itemID)
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
