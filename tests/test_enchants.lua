-- GB-050: missing enchant and gem checks on the equipped item.

return function(T, H)
    local GUIDE = "PALADIN_PROTECTION:4:1"

    local function Link(itemID, enchant, g1, g2, g3)
        return string.format("|cffa335ee|Hitem:%d:%s:%s:%s:%s::::70|h[x]|h|r",
            itemID, enchant or "", g1 or "", g2 or "", g3 or "")
    end

    local function SlotButton(slot)
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "slot") == slot and rawget(frame, "enchant") then return frame end
        end
    end

    T.case("ParseLink: item, enchant and gems; empty fields are 0", function()
        local ns = H.Boot()
        local item, enchant, g1, g2, g3, g4 = ns.Enchants.ParseLink(Link(32521, 3002, 25896, 32196))
        T.eq(item, 32521, "item")
        T.eq(enchant, 3002, "enchant")
        T.eq(g1, 25896, "gem 1")
        T.eq(g2, 32196, "gem 2")
        T.eq(g3, 0, "empty gem")
        T.eq(g4, 0, "missing field")
        T.eq(ns.Enchants.ParseLink("no link"), nil, "not a link")
        T.eq(ns.Enchants.ParseLink(nil), nil, "nil")
    end)

    T.case("Check: missing enchant, gems ok / empty / wrong, other items skip gems", function()
        local ns = H.Boot()
        local list = ns.Data:Get(GUIDE)
        local state = ns.Enchants.Check(list, 1, Link(32521, nil, 25896, 32200))
        T.eq(state.missingEnchant, true, "no enchant")
        T.eq(state.gems[1], "ok", "meta right")
        T.eq(state.gems[2], "wrong", "second gem different")
        state = ns.Enchants.Check(list, 1, Link(32521, 3002, 25896))
        T.eq(state.missingEnchant, false, "enchanted")
        T.eq(state.gems[2], "empty", "empty socket")
        state = ns.Enchants.Check(list, 1, Link(30987, nil))
        T.eq(state.missingEnchant, true, "another helm without enchant still warns")
        T.eq(next(state.gems), nil, "another helm: gems not compared")
        state = ns.Enchants.Check(list, 2, Link(32362))
        T.eq(state.missingEnchant, false, "neck has no enchant in the list")
        T.eq(ns.Enchants.Check(list, 1, nil), nil, "nothing equipped")
    end)

    T.case("panel: red enchant and gem icons with tooltip lines", function()
        H.Boot({ equipped = { [1] = 32521 }, links = { [1] = Link(32521, nil, 25896) } })
        H.Slash("")
        local head = SlotButton(1)
        T.ok(head.enchant.warn:IsShown(), "enchant warned")
        T.ok(not head.gems[1].warn:IsShown(), "right gem fine")
        T.ok(head.gems[2].warn:IsShown(), "empty socket warned")
        head.enchant:Enter()
        local found = false
        for _, line in ipairs(_G.GameTooltip.lines) do
            if line == "Your equipped item here has no enchant" then found = true end
        end
        T.ok(found, "enchant tooltip says so")
        head.gems[2]:Enter()
        T.eq(_G.GameTooltip.lines[#_G.GameTooltip.lines], "This socket is empty on your equipped item", "gem tooltip")
        T.noErrors()
    end)

    T.case("enchanting the worn item clears the warning without reopening", function()
        local ns = H.Boot({ equipped = { [1] = 32521 }, links = { [1] = Link(32521, nil, 25896, 32196) } })
        H.Slash("")
        local head = SlotButton(1)
        T.ok(head.enchant.warn:IsShown(), "before")
        H.links[1] = Link(32521, 3002, 25896, 32196)
        H.Fire("UNIT_INVENTORY_CHANGED", "target")
        T.ok(head.enchant.warn:IsShown(), "another unit's change is ignored")
        H.Fire("UNIT_INVENTORY_CHANGED", "player")
        T.ok(not head.enchant.warn:IsShown(), "after")
        T.ok(ns.Panel:IsShown(), "still open")
    end)

    T.case("nothing equipped: no warnings", function()
        H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        T.ok(not head.enchant.warn:IsShown(), "no enchant warning")
        T.ok(not head.gems[1].warn:IsShown(), "no gem warning")
    end)
end
