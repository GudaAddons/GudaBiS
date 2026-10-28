-- ForeverDungeonJournal, "Dungeon Journal - TBC Anniversary" (GB-072): the wishlist
-- shield in the bottom-right corner of every item row it shows, under the journal's own
-- favourite star (15 px, centred at the row's right edge, 8 px in) (author, 2026-10-28).
-- Compact rows (28 px) have no room under the star, so there it sits just left of it.
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

local CORNER_X, CORNER_Y = -6, 4
local COMPACT_HEIGHT = 40
local BESIDE_STAR_X = -(8 + 15 + 2)

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
    local height = type(row.GetHeight) == "function" and row:GetHeight() or 0
    if height >= COMPACT_HEIGHT then
        ns.WishToggle.Paint(row, "BOTTOMRIGHT", row, "BOTTOMRIGHT", CORNER_X, CORNER_Y, itemID, wishSource)
    else
        ns.WishToggle.Paint(row, "RIGHT", row, "RIGHT", BESIDE_STAR_X, 0, itemID, wishSource)
    end
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
