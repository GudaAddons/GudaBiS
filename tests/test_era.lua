-- M10: the Classic Era client loads GudaBiS_Vanilla.toc with its lists from the top
-- raiders of each phase (GB-101): the panel, its tabs, custom lists, the wishlist,
-- settings, and AtlasLoot under its Era name.

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

    T.case("Era data: four phases by name, Phase 6 first, the active tree's list", function()
        local ns = Era()
        T.eq(table.concat(ns.Data:Phases(), ","), "2,4,5,6", "phases")
        T.eq(ns.Lists:Phase(), 6, "Phase 6 by default")
        T.eq(ns.Panel.PhaseLabel(4), "Phase 3-4", "label from the data")
        local current = ns.Lists:Current()
        T.eq(current.id, "PALADIN_PROTECTION:top:6", "the Protection list")
        T.eq(current.set, "Top 50 raiders", "set name")
        T.ok(current.items[1], "a helm")
        T.noErrors()
    end)

    T.case("Era: a spec Warcraft Logs does not rank gets its class's first list", function()
        local ns = H.Boot({ client = "era", class = "PRIEST", talentPoints = { 31, 20, 0 } })
        T.eq(ns.Lists:Current().id, "PRIEST_HOLY:top:6", "Discipline falls back to Holy")
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
