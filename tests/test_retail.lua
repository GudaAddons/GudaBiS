-- M13: the Retail client loads GudaBiS_Mainline.toc and works with no built-in lists yet:
-- the panel, its tabs, custom lists, the wishlist, settings and the minimap button.

return function(T, H)
    local function Retail()
        return H.Boot({ client = "retail" })
    end

    T.case("Retail loads its own TOC, with no guide data", function()
        local ns = Retail()
        T.eq(H.toc, "GudaBiS_Mainline.toc", "Mainline TOC")
        T.eq(ns.Expansion.ClientKey, "Retail", "client")
        T.eq(ns.Data:Count(), 0, "no guide lists yet")
        T.ok(not ns.Features.HasPhases, "no phases")
        T.noErrors()
    end)

    T.case("Retail panel: no phase dropdown, the empty note, every tab opens", function()
        local ns = Retail()
        H.Slash("")
        T.ok(ns.Panel:IsShown(), "panel")
        T.ok(not ns.Panel.phaseDropdown.button:IsShown(), "no phase dropdown")
        T.ok(_G.GudaBiSPanel.emptyNote:IsShown(), "explains there is no list")
        H.Slash("wishlist")
        T.ok(_G.GudaBiSWishlistView:IsShown(), "wishlist tab")
        H.Slash("history")
        T.ok(_G.GudaBiSHistoryView:IsShown(), "history tab")
        ns.Panel:ShowTab("gear")
        T.noErrors()
    end)

    T.case("Retail custom lists, wishlist alerts and settings work without data", function()
        local ns = Retail()
        H.Slash("")
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 1, 32521)
        ns.Panel:Refresh()
        T.eq(ns.Lists:Current().id, list.id, "custom list shown")
        ns.Lists:ToggleRole("ms", list.id)
        T.eq(ns.Match:Item(32521).role, "ms", "matches")
        ns.Wishlist:Add(28000)
        T.eq(ns.Match:Item(28000).role, "wish", "wishlist")
        H.Slash("options")
        H.Slash("status")
        T.noErrors()
    end)

    T.case("Adventure Guide: shields on loot rows once the guide loads, source saved", function()
        local ns = Retail()
        local callback
        _G.ScrollUtil = { AddInitializedFrameCallback = function(_, fn) callback = fn end }
        _G.EncounterJournal = { encounterID = 7, encounter = { info = { LootContainer = { ScrollBox = {} } } } }
        _G.EJ_GetInstanceInfo = function() return "Windrunner Spire" end
        _G.EJ_GetEncounterInfo = function(id) return id == 7 and "Emberdawn" or nil end
        _G.C_EncounterJournal = { GetLootInfoByIndex = function(i) return { itemID = 250000 + i } end }
        T.eq(callback, nil, "nothing before the guide loads")
        H.Fire("ADDON_LOADED", "Blizzard_EncounterJournal")
        T.ok(callback ~= nil, "hooked when it loads")
        local row = CreateFrame("Button")
        row.itemID = false
        callback(row, { index = 3 })
        local shield = row.gudaBiSWish
        T.ok(shield and shield:IsShown(), "shield on the row")
        T.eq(shield.itemID, 250003, "item from the loot index")
        shield:Click()
        T.eq(ns.Wishlist.SourceText(ns.Wishlist:Items()[1]), "Windrunner Spire · Emberdawn", "source")
        local header = CreateFrame("Button")
        header.itemID = false
        _G.C_EncounterJournal.GetLootInfoByIndex = function() return nil end
        callback(header, { index = 9 })
        T.eq(header.gudaBiSWish, nil, "no shield without an item")
        _G.ScrollUtil, _G.EncounterJournal, _G.C_EncounterJournal = nil, nil, nil
        _G.EJ_GetInstanceInfo, _G.EJ_GetEncounterInfo = nil, nil
        T.noErrors()
    end)

    T.case("Retail refuses Wowhead gear-planner links until their format is checked", function()
        local ns = Retail()
        local result, problem = ns.GearPlanner:Read("https://www.wowhead.com/gear-planner/paladin/human/AAAA")
        T.eq(result, nil, "refused")
        T.eq(problem, ns.L.IMPORT_WRONG_FLAVOR, "says why")
    end)
end
