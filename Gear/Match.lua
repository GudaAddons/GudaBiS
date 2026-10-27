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
--   Match:Item(itemID) -> nil | { role = "ms"|"os", rank = n, slot = INVSLOT }
--   Match.Label(match) -> "BiS", "Alt #2", "OS", "OS alt #3"

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

function Match:Item(itemID)
    if not itemID or ns.Owned:Has(itemID) then return nil end
    local settings = ns.db and ns.db.settings.alerts
    local allowAlts = not settings or settings.alts ~= false
    for _, role in ipairs({ "ms", "os" }) do
        local list = role == "ms" and ns.Lists:MainSpec() or ns.Lists:OffSpec()
        local rank, slot = RankIn(list, itemID)
        if rank and (rank == 1 or allowAlts) then
            return { role = role, rank = rank, slot = slot }
        end
    end
    return nil
end

function Match.Label(match)
    if match.role == "ms" then
        if match.rank == 1 then return L.LABEL_BIS end
        return string.format(L.LABEL_ALT, match.rank - 1)
    end
    if match.rank == 1 then return L.LABEL_OS end
    return string.format(L.LABEL_OS_ALT, match.rank - 1)
end

-- The item ID of an item link, or nil.
function Match.ItemIDFromLink(link)
    local id = type(link) == "string" and link:match("|Hitem:(%d+)")
    return id and tonumber(id) or nil
end
