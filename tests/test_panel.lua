-- GB-020/021/022 and the M2 parts of Spec and Lists: talent tree detection, phase and
-- list selection, the docked panel, slot buttons and their tooltips.

return function(T, H)
    local GUIDE = "PALADIN_PROTECTION:4:1"

    local function SlotButton(slot)
        local panel = _G.GudaBiSPanel
        for _, frame in ipairs(H.AllFrames()) do
            if frame.slot == slot and frame.icon then return frame end
        end
        return nil, panel
    end

    T.case("MostPoints: largest tree, first wins a tie, nil without points", function()
        local ns = H.Boot()
        T.eq(ns.Spec.MostPoints({ 0, 40, 21 }), 2, "protection")
        T.eq(ns.Spec.MostPoints({ 20, 20, 21 }), 3, "largest")
        T.eq(ns.Spec.MostPoints({ 30, 30, 0 }), 1, "tie")
        T.eq(ns.Spec.MostPoints({ 0, 0, 0 }), nil, "none")
        T.eq(ns.Spec.MostPoints({}), nil, "no trees")
    end)

    T.case("ActiveTree reads points spent, the 7th return", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        T.eq(ns.Spec:ActiveTree(), 2, "tree")
        T.eq(ns.Spec:TreeName(2), "Tree2", "client name")
    end)

    T.case("default phase and list; choices follow class and faction", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        T.eq(ns.Lists:Phase(), ns.Data.defaultPhase, "default phase")
        T.eq(ns.Lists:Current().id, GUIDE, "first list of the active tree")
        for _, list in ipairs(ns.Lists:Choices()) do
            T.ok(list.class == "PALADIN" and list.faction ~= "Horde", "choice " .. list.id)
        end
        ns = H.Boot({ class = "MAGE" })
        T.eq(ns.Lists:Current(), nil, "no data for the class")
    end)

    T.case("selection is saved per character and validated", function()
        local ns = H.Boot()
        ns.Lists:Select("PALADIN_PROTECTION:4:3")
        T.eq(ns.Lists:Current().id, "PALADIN_PROTECTION:4:3", "saved list")
        T.eq(ns.Database:Char().selection.list, "PALADIN_PROTECTION:4:3", "stored")
        ns.Lists:Select("PALADIN_PROTECTION:4:2")
        T.eq(ns.Lists:Current().id, GUIDE, "a Horde list falls back for Alliance")
        ns.Lists:SetPhase(99)
        T.eq(ns.Lists:Phase(), ns.Data.defaultPhase, "unknown phase falls back")
    end)

    T.case("SlotView and labels", function()
        local ns = H.Boot()
        local list = ns.Data:Get(GUIDE)
        local view = ns.Panel.SlotView(list, 1)
        T.eq(view.item, 32521, "item")
        T.eq(view.alts[1], 30987, "alts")
        T.eq(ns.Panel.SlotView(nil, 1).item, nil, "no list")
        T.eq(#ns.Panel.SlotView(list, 4).alts, 0, "shirt has no alts")
        T.eq(ns.Panel.ListLabel(list, "Protection"), "Protection · Balanced set", "label")
        T.eq(ns.Panel.ListLabel(list, nil), "Balanced set", "label without tree name")
        T.eq(ns.Panel.PhaseLabel(4), "Phase 4", "phase")
        T.eq(ns.Panel.PhaseLabel(0), "Pre-raid", "pre-raid")
    end)

    T.case("Wowhead layout: 7 left, 7 right, 3 weapons, no shirt or tabard", function()
        local ns = H.Boot()
        T.eq(#ns.Panel.LEFT_SLOTS, 7, "left")
        T.eq(#ns.Panel.RIGHT_SLOTS, 7, "right")
        T.eq(#ns.Panel.BOTTOM_SLOTS, 3, "weapons")
        local seen = {}
        for _, group in ipairs({ ns.Panel.LEFT_SLOTS, ns.Panel.RIGHT_SLOTS, ns.Panel.BOTTOM_SLOTS }) do
            for _, slot in ipairs(group) do
                T.ok(not seen[slot], "slot once " .. slot)
                seen[slot] = true
            end
        end
        T.ok(not seen[4] and not seen[19], "no shirt, no tabard")
        H.Slash("")
        T.eq(SlotButton(10).point[1], "TOPLEFT", "hands in the left column")
        T.eq(SlotButton(6).point[1], "TOPRIGHT", "waist in the right column")
        T.eq(SlotButton(6).name.point[1], "TOPRIGHT", "right column name before the icon")
        T.eq(SlotButton(16).point[1], "TOP", "weapons along the bottom")
    end)

    T.case("enchant and gem icons beside each slot, with their tooltips", function()
        H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        T.ok(head.enchant:IsShown(), "enchant shown")
        T.eq(head.enchant.spell, 35447, "enchant spell")
        T.eq(head.enchant.icon.texture, "spellicon35447", "spell icon")
        T.ok(head.gems[1]:IsShown() and head.gems[2]:IsShown(), "two gems")
        T.ok(not head.gems[3]:IsShown(), "no third socket")
        T.eq(head.gems[1].item, 25896, "meta gem first")
        head.gems[1]:Enter()
        T.eq(_G.GameTooltip.item, 25896, "gem tooltip")
        local neck = SlotButton(2)
        T.ok(not neck.enchant:IsShown(), "no neck enchant")
        T.ok(not neck.gems[1]:IsShown(), "no neck gems")
        T.noErrors()
    end)

    T.case("nothing is built before the Character frame or /gbis", function()
        local ns = H.Boot()
        T.eq(_G.GudaBiSPanel, nil, "no panel at login")
        T.ok(not ns.Panel:IsShown(), "closed")
    end)

    T.case("/gbis opens the panel standalone and paints the list", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        H.cached[32521] = true
        H.Slash("")
        T.ok(ns.Panel:IsShown(), "open")
        local head = SlotButton(1)
        T.eq(head.item, 32521, "head item")
        T.eq(head.icon.texture, "icon32521", "icon from GetItemInfoInstant")
        T.eq(head.name.shownText, "Item32521", "name")
        T.eq(_G.GudaBiSPanel.point[1], "CENTER", "not docked")
        H.Slash("")
        T.ok(not ns.Panel:IsShown(), "toggled closed")
        T.noErrors()
    end)

    T.case("uncached names load later, once", function()
        local ns = H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        T.eq(head.name.shownText, "", "blank while loading")
        local loads = #H.itemLoads
        ns.Panel:Refresh()
        T.eq(#H.itemLoads, loads, "no second request for the same item")
        H.LoadItems()
        T.eq(head.name.shownText, "Item32521", "painted after load")
    end)

    T.case("the side tab sits outside the Character frame, docks the panel and remembers it", function()
        local ns = H.Boot()
        T.eq(ns.Panel.tab, nil, "no tab before the Character frame shows")
        _G.CharacterFrame:Show()
        T.ok(not ns.Panel:IsShown(), "closed by default")
        local tab = ns.Panel.tab
        T.ok(tab ~= nil, "tab made on first show")
        T.eq(tab.point[2], _G.CharacterFrame, "tab on the Character frame's right edge")
        T.eq(tab.point[3], "TOPRIGHT", "outside, right")
        T.eq(tab:GetCheckedTexture().blendMode, "ADD", "checked glow is additive, never a dark square")
        T.eq(tab:GetHighlightTexture().blendMode, "ADD", "hover glow is additive")
        tab:Click()
        T.ok(ns.Panel:IsShown(), "opened")
        T.eq(_G.GudaBiSPanel.point[2], _G.CharacterFrame, "docked to the Character frame")
        T.eq(_G.GudaBiSPanel.point[4], -32, "classic art offset")
        T.eq(tab.point[2], _G.GudaBiSPanel, "tab moved to the panel's edge")
        T.eq(ns.db.settings.panelOpen, true, "remembered")
        tab:Click()
        T.ok(not ns.Panel:IsShown(), "tab closes it again")
        T.eq(tab.point[2], _G.CharacterFrame, "tab back on the Character frame")
        tab:Click()
        _G.CharacterFrame:Hide()
        T.ok(not ns.Panel:IsShown(), "closes with the Character frame")
        _G.CharacterFrame:Show()
        T.ok(ns.Panel:IsShown(), "comes back with it")
        T.eq(tab.point[2], _G.GudaBiSPanel, "tab on the panel again")
        T.noErrors()
    end)

    T.case("dropdown: no frame over the options; an outside click closes, only while open", function()
        local ns = H.Boot()
        _G.C_EventUtils = { IsEventValid = function(event) return event == "GLOBAL_MOUSE_DOWN" end }
        H.Slash("")
        local listButton
        for _, frame in ipairs(H.AllFrames()) do
            local text = rawget(frame, "text")
            if type(text) == "table" and text.shownText and text.shownText:find("Balanced set", 1, true) then
                listButton = frame
            end
        end
        T.ok(not H.Registered("GLOBAL_MOUSE_DOWN"), "nothing listens while closed")
        listButton:Click()
        T.ok(H.Registered("GLOBAL_MOUSE_DOWN"), "listens while open")
        local menu
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "rows") and frame:IsShown() then menu = frame end
        end
        T.ok(menu ~= nil, "menu open")
        menu.mouseOver = true
        H.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        T.ok(menu:IsShown(), "a click on the menu keeps it open")
        menu.mouseOver = false
        H.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        T.ok(not menu:IsShown(), "a click elsewhere closes it")
        T.ok(not H.Registered("GLOBAL_MOUSE_DOWN"), "stops listening")
        _G.C_EventUtils = nil
        T.noErrors()
    end)

    T.case("choosing a phase or list repaints and saves", function()
        local ns = H.Boot()
        H.Slash("")
        local listButton
        for _, frame in ipairs(H.AllFrames()) do
            local text = rawget(frame, "text")
            if type(text) == "table" and text.shownText and text.shownText:find("Balanced set", 1, true) then
                listButton = frame
            end
        end
        T.ok(listButton ~= nil, "list dropdown shows the list")
        listButton:Click()
        local threat
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "value") == "PALADIN_PROTECTION:4:3" then threat = frame end
        end
        T.ok(threat ~= nil and threat:IsShown(), "menu row for the Alliance threat set")
        threat:Click()
        T.eq(ns.Lists:Current().id, "PALADIN_PROTECTION:4:3", "selected")
        T.ok(listButton.text.shownText:find("Threat", 1, true), "button text")
        T.noErrors()
    end)

    local function FlyoutRows()
        local out = {}
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "rank") and frame:IsShown() then out[#out + 1] = frame end
        end
        table.sort(out, function(a, b) return a.rank.shownText < b.rank.shownText end)
        return out
    end

    T.case("RankedItems: the BiS item first, then the guide's alternatives", function()
        local ns = H.Boot()
        local list = ns.Data:Get(GUIDE)
        local ranked = ns.Panel.RankedItems(list, 1)
        T.eq(ranked[1], 32521, "#1")
        T.eq(ranked[2], 30987, "#2")
        T.eq(#ranked, 1 + #list.alts[1], "all alternatives")
        T.eq(#ns.Panel.RankedItems(list, 4), 0, "empty slot")
        T.eq(#ns.Panel.RankedItems(nil, 1), 0, "no list")
    end)

    T.case("slot tooltip: no alternatives in it, just the hints", function()
        H.Boot()
        H.Slash("")
        SlotButton(1):Enter()
        local tip = _G.GameTooltip
        T.eq(tip.item, 32521, "item tooltip")
        local hasRanked, hasAlternatives = false, false
        for _, line in ipairs(tip.lines) do
            if line == "Click: show the ranked items for this slot" then hasRanked = true end
            if line:find("^%d+%. ") then hasAlternatives = true end
        end
        T.ok(hasRanked, "click hint")
        T.ok(not hasAlternatives, "no numbered list in the tooltip")
    end)

    T.case("click opens the ranked list 1. BiS 2. 3. ..., click again closes", function()
        local ns = H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        H.cached[32521] = true
        head:Click()
        T.ok(ns.RankFlyout:IsOpenFor(head), "open for the head")
        local rows = FlyoutRows()
        local list = ns.Data:Get(GUIDE)
        T.eq(#rows, 1 + #list.alts[1], "one row per ranked item")
        T.eq(rows[1].rank.shownText, "1.", "rank 1")
        T.eq(rows[1].id, 32521, "BiS first")
        T.eq(rows[1].name.shownText, "Item32521", "name")
        T.eq(rows[2].id, 30987, "first alternative second")
        T.eq(rows[2].name.shownText, "Item 30987 (loading...)", "loading")
        H.LoadItems()
        T.eq(rows[2].name.shownText, "Item30987", "painted after load")
        head:Click()
        T.ok(not ns.RankFlyout:IsOpenFor(head), "closed by a second click")
        T.noErrors()
    end)

    T.case("another slot moves the list; changing list or closing the panel closes it", function()
        local ns = H.Boot()
        H.Slash("")
        local head, chest = SlotButton(1), SlotButton(5)
        head:Click()
        chest:Click()
        T.ok(ns.RankFlyout:IsOpenFor(chest), "moved to the chest")
        T.eq(FlyoutRows()[1].id, 30991, "chest items")
        ns.Lists:Select("PALADIN_PROTECTION:4:3")
        ns.Panel:Refresh()
        T.ok(not ns.RankFlyout:IsOpenFor(chest), "closed on list change")
        chest:Click()
        ns.Panel:Close()
        T.ok(not ns.RankFlyout:IsOpenFor(chest), "closed with the panel")
    end)

    T.case("ranked rows: owned items get a check, right-click marks a row", function()
        local ns = H.Boot({ containers = { [0] = { 30987 } } })
        H.Slash("")
        local head = SlotButton(1)
        T.ok(not head.check:IsShown(), "no check on the slot for an owned alternative")
        head:Click()
        local rows = FlyoutRows()
        T.ok(not rows[1].check:IsShown(), "BiS not owned")
        T.ok(rows[2].check:IsShown(), "the alternative in your bags is checked")
        rows[3].scripts.OnClick(rows[3], "RightButton")
        T.eq(ns.Owned:State(rows[3].id), "manual", "row marked")
        T.ok(rows[3].check:IsShown(), "check appears")
        T.noErrors()
    end)

    T.case("shift-click links the item", function()
        H.Boot()
        H.Slash("")
        H.cached[32521] = true
        local head = SlotButton(1)
        head:Click()
        T.eq(#H.linked, 0, "plain click does nothing")
        H.modified = true
        head:Click()
        T.ok(H.linked[1] and H.linked[1]:find("item:32521", 1, true), "linked")
    end)
end
