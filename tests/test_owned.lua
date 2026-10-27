-- GB-030/031: owned detection (equipped, bags, bank, other characters, manual marks)
-- and the panel's checks and tooltip lines.

return function(T, H)
    local GUIDE = "PALADIN_PROTECTION:4:1"

    local function SlotButton(slot)
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "slot") == slot and rawget(frame, "icon") then return frame end
        end
    end

    T.case("login scans equipped and bags; only armor and weapons are kept", function()
        H.itemClass = {}
        local ns = H.Boot({ equipped = { [1] = 32521 }, containers = { [0] = { 30987, false, 22829 } } })
        H.itemClass[22829] = 0
        H.Fire("BAG_UPDATE_DELAYED")
        local char = ns.Database:Char()
        T.eq(char.equipped[32521], true, "equipped")
        T.eq(char.bags[30987], true, "in bags")
        T.eq(char.bags[22829], nil, "a potion is not kept")
        T.eq(ns.Owned:State(32521), "equipped", "state equipped")
        T.eq(ns.Owned:State(30987), "bags", "state bags")
        T.eq(ns.Owned:State(1), nil, "not owned")
        T.noErrors()
    end)

    T.case("bank is read only while open, and kept after closing", function()
        local ns = H.Boot({ containers = { [-1] = { 30125 }, [5] = { 33421 } } })
        T.eq(ns.Database:Char().bank, nil, "not read at login")
        H.Fire("PLAYERBANKSLOTS_CHANGED")
        T.eq(ns.Database:Char().bank, nil, "not read while closed")
        H.Fire("BANKFRAME_OPENED")
        T.eq(ns.Owned:State(30125), "bank", "main bank")
        T.eq(ns.Owned:State(33421), "bank", "bank bag")
        H.Fire("BANKFRAME_CLOSED")
        H.containers[-1] = {}
        H.Fire("BAG_UPDATE_DELAYED")
        T.eq(ns.Owned:State(30125), "bank", "kept from the last visit")
    end)

    T.case("equipment changes rescan and fire GBIS_OWNED_CHANGED", function()
        local ns = H.Boot()
        local fired = 0
        ns.Events:Register("GBIS_OWNED_CHANGED", function() fired = fired + 1 end, "t")
        H.equipped[1] = 32521
        H.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
        T.eq(ns.Owned:State(32521), "equipped", "picked up")
        T.eq(fired, 1, "one event")
    end)

    T.case("another character's items show as alt with its name", function()
        local saved = { chars = { ["Bankie-Spineshatter"] = { bags = { [32521] = true } } } }
        local ns = H.Boot({ saved = saved })
        local state, name = ns.Owned:State(32521)
        T.eq(state, "alt", "state")
        T.eq(name, "Bankie", "short name")
        T.eq(ns.Owned:Has(32521), false, "not done until moved")
    end)

    T.case("manual marks: owned, not needed, cleared", function()
        local ns = H.Boot({ equipped = { [1] = 32521 } })
        ns.Owned:ToggleManual(30987)
        T.eq(ns.Owned:State(30987), "manual", "marked owned")
        T.eq(ns.Owned:Has(30987), true, "counts")
        ns.Owned:ToggleManual(30987)
        T.eq(ns.Owned:State(30987), nil, "cleared")
        ns.Owned:ToggleManual(32521)
        T.eq(ns.Owned:State(32521), "skip", "an owned item becomes not needed")
        T.eq(ns.Owned:Has(32521), true, "a skipped slot is done")
    end)

    T.case("SlotStatus: only the item shown decides; alternatives never mark the slot", function()
        local ns = H.Boot()
        local list = ns.Data:Get(GUIDE)
        local owned = {}
        local states = {}
        local function has(id) return owned[id] == true end
        local function state(id) return states[id] end
        T.eq(ns.Owned.SlotStatus(list, 1, has, state), nil, "missing: no mark")
        owned[33421] = true
        states[33421] = "equipped"
        T.eq(ns.Owned.SlotStatus(list, 1, has, state), nil, "wearing an alternative: no mark")
        states[32521] = "alt"
        T.eq(ns.Owned.SlotStatus(list, 1, has, state), "elsewhere", "on an alt")
        owned[32521] = true
        T.eq(ns.Owned.SlotStatus(list, 1, has, state), "best", "best owned")
        T.eq(ns.Owned.SlotStatus(list, 4, has, state), nil, "empty slot")
        T.eq(ns.Owned.SlotStatus(nil, 1, has, state), nil, "no list")
    end)

    T.case("panel: wearing an alternative gives no slot mark, only the tooltip line", function()
        H.Boot({ equipped = { [1] = 33421 } })
        H.Slash("")
        local head = SlotButton(1)
        T.ok(not head.check:IsShown(), "no check")
        head:Enter()
        local found = false
        for _, line in ipairs(_G.GameTooltip.lines) do
            if line:find("^You are wearing an alternative") then found = true end
        end
        T.ok(found, "tooltip says so")
    end)

    T.case("panel: check on the slot, tooltip says where, right-click marks", function()
        local ns = H.Boot({ equipped = { [1] = 32521 } })
        H.Slash("")
        local head = SlotButton(1)
        T.ok(head.check:IsShown(), "check shown for an equipped #1")
        local shoulder = SlotButton(3)
        T.ok(not shoulder.check:IsShown(), "no check for a missing item")
        head:Enter()
        local tip = _G.GameTooltip
        local found = false
        for _, line in ipairs(tip.lines) do
            if line == "You have it equipped" then found = true end
        end
        T.ok(found, "tooltip says equipped")
        shoulder.scripts.OnClick(shoulder, "RightButton")
        T.eq(ns.Owned:State(30998), "manual", "right-click marks owned")
        T.ok(shoulder.check:IsShown(), "check appears at once")
        shoulder.scripts.OnClick(shoulder, "RightButton")
        T.ok(not shoulder.check:IsShown(), "second right-click clears")
        T.noErrors()
    end)

    T.case("bag changes repaint an open panel", function()
        local ns = H.Boot()
        H.Slash("")
        local shoulder = SlotButton(3)
        T.ok(not shoulder.check:IsShown(), "not yet")
        H.containers[0] = { 30998 }
        H.Fire("BAG_UPDATE_DELAYED")
        T.ok(shoulder.check:IsShown(), "after looting it")
        T.ok(ns.Panel:IsShown(), "panel still open")
    end)
end
