-- Item helpers shared by every view that shows items.
--
-- WhenLoaded runs fn once the client has an uncached item's data. Each item is
-- requested at most once at a time, so a view that repaints from the callback can never
-- start a loop (developer-guide §3: never retry in a loop).

local addonName, ns = ...

local Items = ns:RegisterModule("Items")

local pending = {}

function Items.WhenLoaded(itemID, fn)
    if pending[itemID] or not (Item and Item.CreateFromItemID) then return end
    pending[itemID] = true
    Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
        pending[itemID] = nil
        fn()
    end)
end

-- The socket colours of an item, from its stats ("EMPTY_SOCKET_RED" = 2 ...), meta
-- first, then red, yellow, blue. The stats give counts, not the order on the item,
-- so this is the order shown, not necessarily the item's own.
local SOCKET_ORDER = { "META", "RED", "YELLOW", "BLUE" }

function Items.Sockets(itemID)
    local out = {}
    local getStats = ns.GetItemStats
    if not getStats or not itemID then return out end
    local ok, stats = pcall(getStats, "item:" .. itemID)
    if not ok or type(stats) ~= "table" then return out end
    for _, color in ipairs(SOCKET_ORDER) do
        for _ = 1, stats["EMPTY_SOCKET_" .. color] or 0 do
            out[#out + 1] = color
        end
    end
    return out
end

local CLASS_GEM = 3

-- Gem subclasses (TBC): 0 red, 1 blue, 2 yellow, 3 purple, 4 green, 5 orange, 6 meta,
-- 7 simple, 8 prismatic; and which socket colours each one counts for.
local GEM_FITS = {
    [0] = { RED = true }, [1] = { BLUE = true }, [2] = { YELLOW = true },
    [3] = { RED = true, BLUE = true }, [4] = { YELLOW = true, BLUE = true },
    [5] = { RED = true, YELLOW = true }, [6] = { META = true },
    [8] = { RED = true, YELLOW = true, BLUE = true },
}

function Items.IsGem(itemID)
    local _, _, _, _, _, classID = ns.GetItemInfoInstant(itemID)
    return classID == CLASS_GEM
end

-- Whether a gem counts for a socket colour (for the socket bonus). Unknown colours
-- or gems answer true: the note is only shown when a mismatch is certain.
function Items.GemMatches(gemID, color)
    if not color then return true end
    local _, _, _, _, _, classID, subclassID = ns.GetItemInfoInstant(gemID)
    if classID ~= CLASS_GEM or not GEM_FITS[subclassID] then return true end
    return GEM_FITS[subclassID][color] == true
end

function Items.QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end
