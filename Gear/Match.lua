-- Is a dropped item one this character wants (GB-060)?
--
-- The MS list is asked first, then the OS list. Rank 1 is the list's own item for a
-- slot, rank n+1 its n-th guide alternative (custom lists have none). Items this
-- character already has (Owned:Has, which includes "marked not needed") never match,
-- and alternatives match only while settings.alerts.alts is on.
--
-- Drops are rare events, so this walks the two lists on each call instead of keeping
-- an index that would need rebuilding on every list, phase or talent change.
--
-- After the lists, the character's wishlist (GB-072): role "wish", no slot. A list
-- match wins over the wishlist, so an item on both keeps its BiS / alt / OS label.
--
--   Match:Item(itemID[, includeOwned]) -> nil | { role = "ms"|"os"|"wish", rank = n, slot = INVSLOT }
--     includeOwned: History labels an item the player just won, already in the bags
--   Match:Item(itemID, nil, link): link lets an owned item come back as an upgrade:
--     match.upgrade = { from = 320, to = 334 }
--   Match.Label(match) -> "BiS", "Alt #2", "OS", "OS alt #3", "wishlist item", "BiS upgrade 320→334"

local addonName, ns = ...
local L = ns.L

local Match = ns:RegisterModule("Match")

local function RankIn(list, itemID)
    if not list then return nil end
    for slot, id in pairs(list.items) do
        if id == itemID then return 1, slot end
    end
    for slot, alts in pairs(list.alts or {}) do
        for i, id in ipairs(alts) do
            if id == itemID then return i + 1, slot end
        end
    end
    return nil
end

-- An item the player already has matches again only as an upgrade: where item levels
-- matter (Retail), when the drop's link shows a higher level than the player's best
-- equipped or bagged copy. Manual "not needed" marks and copies only in the bank or on
-- another character have no level to beat, so they stay silent.
local function Upgrade(itemID, link)
    if not (link and ns.Features.ItemLevelMatters) then return nil end
    local levelOf = ns.GetDetailedItemLevelInfo
    local dropped = levelOf and levelOf(link)
    local have = ns.Owned:BestLevel(itemID)
    if dropped and have and dropped > have then return { from = have, to = dropped } end
    return nil
end

function Match:Item(itemID, includeOwned, link)
    if not itemID then return nil end
    local upgrade
    if not includeOwned and ns.Owned:Has(itemID) then
        upgrade = Upgrade(itemID, link)
        if not upgrade then return nil end
    end
    local settings = ns.db and ns.db.settings.alerts
    local allowAlts = not settings or settings.alts ~= false
    for _, role in ipairs({ "ms", "os" }) do
        local list = role == "ms" and ns.Lists:MainSpec() or ns.Lists:OffSpec()
        local rank, slot = RankIn(list, itemID)
        if rank and (rank == 1 or allowAlts) then
            return { role = role, rank = rank, slot = slot, upgrade = upgrade }
        end
    end
    if ns.Wishlist:Has(itemID) then return { role = "wish", rank = 1, upgrade = upgrade } end
    return nil
end

local function BaseLabel(match)
    if match.role == "wish" then return L.LABEL_WISH end
    if match.role == "ms" then
        if match.rank == 1 then return L.LABEL_BIS end
        return string.format(L.LABEL_ALT, match.rank - 1)
    end
    if match.rank == 1 then return L.LABEL_OS end
    return string.format(L.LABEL_OS_ALT, match.rank - 1)
end

function Match.Label(match)
    local label = BaseLabel(match)
    local upgrade = match.upgrade
    if upgrade then return string.format(L.LABEL_UPGRADE, label, upgrade.from, upgrade.to) end
    return label
end

-- The item ID of an item link, or nil.
function Match.ItemIDFromLink(link)
    local id = type(link) == "string" and link:match("|Hitem:(%d+)")
    return id and tonumber(id) or nil
end
