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

    T.case("tooltip: the item, then numbered alternatives; loading ones refresh", function()
        local ns = H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        H.cached[30987] = true
        head:Enter()
        local tip = _G.GameTooltip
        T.eq(tip.item, 32521, "item tooltip")
        T.eq(tip.lines[2], "Alternatives", "header")
        T.eq(tip.lines[3], "1. Item30987", "cached alternative")
        T.eq(tip.lines[4], "Item 33421 (loading...)", "loading alternative")
        H.LoadItems()
        T.eq(tip.lines[4], "2. Item33421", "redrawn after load")
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
