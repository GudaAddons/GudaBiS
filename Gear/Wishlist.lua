-- The wishlist (GB-072): items a character wants that are not on its MS/OS lists, marked
-- from AtlasLoot, the Dungeon Journal addon, or the panel's Wishlist tab. Per character
-- (author, 2026-10-28), in GudaBiS_DB.chars[key].wishlist:
--   [itemID] = { added = time(), dungeon = "Karazhan"?, boss = "Prince Malchezaar"? }
--
-- Any item may go on it, not only gear. A wished item alerts like a list item, labelled
-- "wishlist item" (Match), until the character owns it; the owned check only knows
-- equippable items (Owned), so anything else stays until it is removed. Auto-roll never
-- rolls for it (RULES.md Rule 4: only MS/OS list items).
--
--   Wishlist:Has(itemID), :Add(itemID[, source]), :Remove(itemID), :Toggle(itemID[, source])
--   Wishlist:Items() -> { { itemID, added, dungeon, boss }, ... } newest first
--   Wishlist.SourceText(entry) -> "Karazhan · Prince Malchezaar" | ""
-- Every change fires GBIS_WISHLIST_CHANGED(itemID).

local addonName, ns = ...

local Wishlist = ns:RegisterModule("Wishlist")

local function Store(create)
    local char = ns.Database:Char()
    if not char then return nil end
    if not char.wishlist and create then char.wishlist = {} end
    return char.wishlist
end

local function Changed(itemID)
    ns.Events:Fire("GBIS_WISHLIST_CHANGED", itemID)
end

function Wishlist:Has(itemID)
    local store = itemID and Store(false)
    return store ~= nil and store[itemID] ~= nil
end

function Wishlist:Add(itemID, source)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    local store = Store(true)
    if not store or store[itemID] then return false end
    store[itemID] = {
        added = time(),
        dungeon = source and source.dungeon or nil,
        boss = source and source.boss or nil,
    }
    Changed(itemID)
    return true
end

function Wishlist:Remove(itemID)
    local store = Store(false)
    if not (store and itemID and store[itemID]) then return false end
    store[itemID] = nil
    Changed(itemID)
    return true
end

function Wishlist:Toggle(itemID, source)
    if self:Has(itemID) then return self:Remove(itemID) end
    return self:Add(itemID, source)
end

function Wishlist:Items()
    local out = {}
    for itemID, entry in pairs(Store(false) or {}) do
        out[#out + 1] = { itemID = itemID, added = entry.added or 0, dungeon = entry.dungeon, boss = entry.boss }
    end
    table.sort(out, function(a, b)
        if a.added ~= b.added then return a.added > b.added end
        return a.itemID < b.itemID
    end)
    return out
end

function Wishlist.SourceText(entry)
    local dungeon, boss = entry.dungeon, entry.boss
    if dungeon and boss then return dungeon .. " · " .. boss end
    return dungeon or boss or ""
end
