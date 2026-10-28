-- ForeverDungeonJournal, "Dungeon Journal - TBC Anniversary" (GB-072): the wishlist
-- shield at the right end of every item row it shows, in a fixed column just left of
-- the journal's own favourite star (15 px at the row's right edge, 8 px in), so the
-- shields line up whether or not the star shows (author, 2026-10-28: beside the item,
-- not on its icon).
--
-- Read from ForeverDungeonJournal 1.5.1 (Core/Journal.lua, Systems/Favourites.lua).
-- Its rows are reused by index on every boss, filter and layout change, and each fill
-- calls the namespace's UpdateFavouriteIndicator(row, itemID): boss loot rows, quest
-- rewards and quest step items. A post-hook on it sees every item the journal shows;
-- loot rows also carry the dungeon and boss names, saved as the wishlist entry's source.
--
-- Nothing here is a documented API: every access is guarded, and a failure only means
-- no shields (RULES.md Rule 5).

local addonName, ns = ...

local JournalBridge = ns:RegisterModule("JournalBridge")

local RIGHT_OFFSET = -(8 + 15 + 6)

local hooked = false

local function OnIndicator(row, itemID)
    if type(row) ~= "table" then return end
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        ns.WishToggle.Hide(row)
        return
    end
    local wishSource
    if type(row.fdjDungeonName) == "string" or type(row.fdjBossName) == "string" then
        wishSource = { dungeon = row.fdjDungeonName, boss = row.fdjBossName }
    end
    ns.WishToggle.Paint(row, "RIGHT", row, "RIGHT", RIGHT_OFFSET, 0, itemID, wishSource)
end

function JournalBridge:Hook()
    if hooked then return true end
    local journal = _G.ForeverDungeonJournal_NS
    if type(journal) ~= "table" or type(journal.UpdateFavouriteIndicator) ~= "function" then return false end
    hooksecurefunc(journal, "UpdateFavouriteIndicator", function(...)
        local ok, err = pcall(OnIndicator, ...)
        if not ok then ns:Debug("Journal shield:", err) end
    end)
    hooked = true
    return true
end

ns.Events:Register("GBIS_INITIALIZED", function() JournalBridge:Hook() end, "JournalBridge")
ns.Events:Register("ADDON_LOADED", function(_, name)
    if name == "ForeverDungeonJournal" then JournalBridge:Hook() end
end, "JournalBridge")
