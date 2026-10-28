-- AtlasLoot (GB-072): the wishlist shield at the right end of every item row AtlasLoot
-- shows, left of the row's faction icon or second item icon when it has one (author,
-- 2026-10-28: beside the item, not on its icon). Wishing an item saves the instance and boss
-- AtlasLoot shows as its source.
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

-- Where the item drops, from what AtlasLoot shows now (author, 2026-10-28: items wished
-- from AtlasLoot had no source): its selection AtlasLoot.db.GUI.selected = { module,
-- instance, boss, ... }, named by ItemDB content :GetName() and :GetNameForItemTable(boss),
-- the same calls AtlasLoot uses for its own title. Nil when any of it is missing.
local function Call(object, method, ...)
    if type(object) ~= "table" or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    return ok and type(value) == "string" and value ~= "" and value or nil
end

function AtlasLootBridge.Source()
    local atlasLoot = _G.AtlasLoot
    local gui = type(atlasLoot) == "table" and type(atlasLoot.db) == "table" and atlasLoot.db.GUI
    local selected = type(gui) == "table" and gui.selected
    local itemDB = type(atlasLoot) == "table" and atlasLoot.ItemDB
    if type(selected) ~= "table" or type(itemDB) ~= "table" or type(itemDB.Get) ~= "function" then return nil end
    local ok, module = pcall(itemDB.Get, itemDB, selected[1])
    local content = ok and type(module) == "table" and module[selected[2]] or nil
    if type(content) ~= "table" then return nil end
    local dungeon = Call(content, "GetName")
    local boss = selected[3] and Call(content, "GetNameForItemTable", selected[3])
    if not (dungeon or boss) then return nil end
    return { dungeon = dungeon, boss = boss }
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
        ns.WishToggle.Paint(button, "RIGHT", neighbour, "LEFT", -GAP, 0, itemID, AtlasLootBridge.Source())
    else
        ns.WishToggle.Paint(button, "RIGHT", button, "RIGHT", -GAP, 0, itemID, AtlasLootBridge.Source())
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
-- The core addon is "AtlasLoot" (AtlasLootClassic Continued, TBC and Retail) or
-- "AtlasLootClassic" (Classic Era); both create the global AtlasLoot.
local ADDON_NAMES = { AtlasLoot = true, AtlasLootClassic = true }

ns.Events:Register("ADDON_LOADED", function(_, name)
    if ADDON_NAMES[name] then AtlasLootBridge:Hook() end
end, "AtlasLootBridge")
