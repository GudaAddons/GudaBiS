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

function Items.QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end
