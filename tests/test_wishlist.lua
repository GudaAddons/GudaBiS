-- GB-072: the wishlist, its alerts, the Wishlist tab, the AtlasLoot and Dungeon Journal
-- shields, and the tooltip line.

return function(T, H)
    local WISHED = 28000

    local function Link(itemID)
        return "|cffa335ee|Hitem:" .. itemID .. "::::::::70:::::|h[Item" .. itemID .. "]|h|r"
    end

    local function InRaid(opts)
        local ns = H.Boot(opts)
        H.SetGroup(true)
        H.leaders.Boss = true
        return ns
    end

    -- Boot with stand-ins for AtlasLoot's Item button type and the journal's namespace,
    -- present before GudaBiS initializes, as OptionalDeps makes them in game.
    local function BootWithAddons()
        H.Install()
        local itemType = { Refresh = function() end, OnClear = function() end }
        _G.AtlasLoot = { Button = { GetType = function(_, name) return name == "Item" and itemType or nil end } }
        _G.ForeverDungeonJournal_NS = { UpdateFavouriteIndicator = function() end }
        local ns = H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        H.Fire("PLAYER_LOGIN")
        H.Fire("PLAYER_ENTERING_WORLD", true, false)
        return ns, itemType
    end

    -- The harness answers any capitalised field with a function; real AtlasLoot buttons
    -- have no such field unless they belong to its set popup.
    local function ItemButton()
        local button = CreateFrame("Button")
        button.icon = CreateFrame("Frame")
        button.IsExtraItemFrameButton = false
        return button
    end

    T.case("add, remove, toggle; newest first; per character", function()
        local ns = H.Boot()
        local W = ns.Wishlist
        T.ok(W:Add(WISHED, { dungeon = "Karazhan", boss = "Prince Malchezaar" }), "added")
        T.ok(not W:Add(WISHED), "not twice")
        H.Advance(5)
        W:Add(30000)
        local items = W:Items()
        T.eq(items[1].itemID, 30000, "newest first")
        T.eq(W.SourceText(items[2]), "Karazhan · Prince Malchezaar", "source")
        T.eq(W.SourceText(items[1]), "", "no source")
        W:Toggle(30000)
        T.ok(not W:Has(30000), "toggled off")
        T.ok(not W:Add(0) and not W:Add(nil), "no empty IDs")
        local saved = _G.GudaBiS_DB
        local other = H.Boot({ saved = saved, playerName = "Alt" })
        T.ok(not other.Wishlist:Has(WISHED), "another character's wishlist is its own")
        T.ok(H.Boot({ saved = saved }).Wishlist:Has(WISHED), "kept for this character")
    end)

    T.case("Match: wished items match as \"wishlist item\"; a list wins; owned never", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        ns.Wishlist:Add(WISHED)
        local m = ns.Match:Item(WISHED)
        T.eq(m.role, "wish", "role")
        T.eq(ns.Match.Label(m), "wishlist item", "label")
        ns.Wishlist:Add(32521)
        T.eq(ns.Match:Item(32521).role, "ms", "the BiS label wins")
        ns.Owned:ToggleManual(WISHED)
        T.eq(ns.Match:Item(WISHED), nil, "owned: no alert")
    end)

    T.case("alerts: a wished drop toasts and pops up; auto-roll never rolls for it", function()
        local ns = InRaid()
        ns.Wishlist:Add(WISHED)
        H.Slash("autoroll on")
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(WISHED), "Boss")
        T.eq(_G.GudaBiSDropToast.title.shownText, "Your wishlist item dropped!", "toast")
        H.Advance(1)
        T.eq(#H.rolled, 0, "no /roll")
        T.ok(_G.GudaBiSRollPopup:IsShown(), "the player rolls from the popup")
        H.lootRolls[5] = Link(WISHED)
        H.Fire("START_LOOT_ROLL", 5, 60)
        H.Advance(0)
        T.eq(#H.lootActions, 0, "no Need or Greed")
        T.eq(ns.AutoRoll.Decide({ role = "wish" }, true, true), nil, "decision")
        T.noErrors()
    end)

    T.case("History tags a wished drop", function()
        local ns = H.Boot()
        ns.Wishlist:Add(WISHED)
        T.eq(ns.HistoryTab.Tag({ role = "wish", rank = 1 }), "|cffff80ffwishlist item|r", "tag")
    end)

    T.case("Wishlist tab: empty note, add by ID and shift-click, ✕ removes, search filters", function()
        local ns = H.Boot()
        H.Slash("wishlist")
        T.eq(ns.Panel:ActiveTab(), "wishlist", "tab")
        local view = _G.GudaBiSWishlistView
        T.ok(view.emptyNote:IsShown(), "empty note")
        T.eq(view.emptyNote.shownText, ns.L.WISHLIST_EMPTY, "explains how to add")
        view.search:SetText(tostring(WISHED))
        view.search:Script("OnEnterPressed")
        T.ok(ns.Wishlist:Has(WISHED), "added by ID")
        _G.HandleModifiedItemClick(Link(30000))
        T.ok(ns.Wishlist:Has(30000), "added by shift-click while the tab is open")
        H.cursor = 31000
        view:Script("OnReceiveDrag")
        T.ok(ns.Wishlist:Has(31000), "dropped on the tab")
        T.ok(not view.emptyNote:IsShown(), "rows now")
        H.cached[WISHED], H.cached[30000], H.cached[31000] = true, true, true
        local rows = ns.WishlistTab.Rows("item28", function(id) return "Item" .. id end)
        T.eq(#rows, 1, "search")
        T.eq(rows[1].itemID, WISHED, "the match")
        local first
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "remove") and frame:IsShown() and not first then first = frame end
        end
        local removed = first.itemID
        first.remove:Click()
        T.ok(not ns.Wishlist:Has(removed), "✕ removes")
        ns.Panel:ShowTab("gear")
        _G.HandleModifiedItemClick(Link(32000))
        T.ok(not ns.Wishlist:Has(32000), "no adding while the tab is closed")
        T.noErrors()
    end)

    T.case("AtlasLoot: shield on item buttons, click wishes, cleared buttons hide it", function()
        local ns, itemType = BootWithAddons()
        local button = ItemButton()
        button.ItemID = WISHED
        itemType.Refresh(button)
        local shield = button.gudaBiSWish
        T.ok(shield and shield:IsShown(), "shield shown")
        T.eq(shield.point[1], "RIGHT", "at the row's right end")
        T.eq(shield.point[2], button, "against the row")
        T.eq(shield.width, 18, "bigger than before")
        T.eq(shield.icon.desaturated, true, "grey while not wished")
        local second = CreateFrame("Button")
        second.type = "secButton"
        second:Show()
        button.secButton = second
        itemType.Refresh(button)
        T.eq(shield.point[2], second, "left of the second item icon when the row has one")
        T.eq(shield.point[3], "LEFT", "its left side")
        second.ItemID = 30000
        itemType.Refresh(second)
        T.eq(second.gudaBiSWish, nil, "the second icon gets no shield of its own")
        button.secButton = nil
        shield:Click()
        T.ok(ns.Wishlist:Has(WISHED), "wished")
        T.eq(shield.icon.desaturated, false, "in colour")
        itemType.OnClear(button)
        T.ok(not shield:IsShown(), "hidden on clear")
        local popup = ItemButton()
        popup.ItemID = 30000
        popup.IsExtraItemFrameButton = true
        itemType.Refresh(popup)
        T.eq(popup.gudaBiSWish, nil, "the set popup is left alone")
        ns.Wishlist:Remove(WISHED)
        itemType.Refresh(button)
        T.eq(shield.icon.desaturated, true, "repainted when removed elsewhere")
        T.noErrors()
    end)

    T.case("Dungeon Journal: shield on rows, wishing saves the dungeon and boss", function()
        local ns = BootWithAddons()
        local row = ItemButton()
        row:SetSize(388, 52)
        row.fdjDungeonName, row.fdjBossName = "Karazhan", "Attumen the Huntsman"
        _G.ForeverDungeonJournal_NS.UpdateFavouriteIndicator(row, WISHED)
        local shield = row.gudaBiSWish
        T.eq(shield.point[1], "BOTTOMRIGHT", "bottom-right corner")
        T.eq(shield.point[4], -6, "near the right edge")
        T.eq(shield.point[5], 4, "a little up from the bottom")
        local compact = ItemButton()
        compact:SetSize(388, 28)
        _G.ForeverDungeonJournal_NS.UpdateFavouriteIndicator(compact, 30000)
        T.eq(compact.gudaBiSWish.point[1], "RIGHT", "compact rows: beside the star")
        T.eq(compact.gudaBiSWish.point[4], -25, "just left of it")
        shield:Click()
        T.eq(ns.Wishlist.SourceText(ns.Wishlist:Items()[1]), "Karazhan · Attumen the Huntsman", "source saved")
        _G.ForeverDungeonJournal_NS.UpdateFavouriteIndicator(row, 0)
        T.ok(not shield:IsShown(), "no item, no shield")
        T.noErrors()
    end)

    T.case("item tooltips say when an item is on the wishlist", function()
        local ns = H.Boot()
        ns.Wishlist:Add(WISHED)
        local tooltip = _G.GameTooltip
        local wishedLink = Link(WISHED)
        function tooltip:GetItem() return "Item", wishedLink end
        tooltip:SetOwner(UIParent)
        tooltip:Script("OnTooltipSetItem")
        T.eq(tooltip.lines[#tooltip.lines], "On your GudaBiS wishlist", "line added")
        wishedLink = Link(1)
        tooltip:SetOwner(UIParent)
        tooltip:Script("OnTooltipSetItem")
        T.eq(#tooltip.lines, 0, "nothing for other items")
    end)
end
