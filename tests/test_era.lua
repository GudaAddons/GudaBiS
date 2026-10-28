-- M10: the Classic Era client loads GudaBiS_Vanilla.toc and works before its guide lists
-- exist (they come from the author's saved Wowhead Classic pages): the panel, its tabs,
-- custom lists, the wishlist, settings, and AtlasLoot under its Era name.

return function(T, H)
    local function Era()
        return H.Boot({ client = "era" })
    end

    T.case("Era loads its own TOC", function()
        local ns = Era()
        T.eq(H.toc, "GudaBiS_Vanilla.toc", "Vanilla TOC")
        T.eq(ns.Expansion.ClientKey, "Era", "client")
        T.ok(not ns.Features.HasGems, "no gems in Era")
        T.ok(ns.Features.HasRangedSlot, "ranged slot")
        T.ok(not ns.Features.HasRetailFrameArt, "classic art")
        T.noErrors()
    end)

    T.case("Era panel opens with every tab, ranged slot included", function()
        local ns = Era()
        H.Slash("")
        T.ok(ns.Panel:IsShown(), "panel")
        T.eq(#ns.Panel.WeaponSlots(), 3, "main hand, off hand, ranged")
        H.Slash("wishlist")
        T.ok(_G.GudaBiSWishlistView:IsShown(), "wishlist tab")
        H.Slash("history")
        T.ok(_G.GudaBiSHistoryView:IsShown(), "history tab")
        ns.Panel:ShowTab("gear")
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 1, 16921)
        ns.Panel:Refresh()
        T.eq(ns.Lists:Current().id, list.id, "custom list shown")
        H.Slash("status")
        H.Slash("options")
        T.noErrors()
    end)

    T.case("AtlasLoot is hooked under its Era name, AtlasLootClassic", function()
        H.Install({ client = "era" })
        local ns = H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        local itemType = { Refresh = function() end, OnClear = function() end }
        _G.AtlasLoot = { Button = { GetType = function(_, name) return name == "Item" and itemType or nil end } }
        H.Fire("ADDON_LOADED", "AtlasLootClassic")
        local button = CreateFrame("Button")
        button.icon = CreateFrame("Frame")
        button.IsExtraItemFrameButton = false
        button.ItemID = 16921
        itemType.Refresh(button)
        T.ok(button.gudaBiSWish and button.gudaBiSWish:IsShown(), "shield on an Era AtlasLoot item")
        T.ok(ns.AtlasLootBridge:Hook(), "hooked once")
        T.noErrors()
    end)
end
