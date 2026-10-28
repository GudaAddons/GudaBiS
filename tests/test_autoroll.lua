-- GB-070: auto-roll (RULES.md Rule 4).

return function(T, H)
    local function Link(itemID)
        return "|cffa335ee|Hitem:" .. itemID .. "::::::::70:::::|h[Item" .. itemID .. "]|h|r"
    end

    local function InRaid(opts)
        local ns = H.Boot(opts)
        H.SetGroup(true)
        H.leaders.Boss = true
        return ns
    end

    local function AutoRollOn(opts)
        local ns = InRaid(opts)
        H.Slash("autoroll on")
        return ns
    end

    local function GroupRoll(rollID, itemID)
        H.lootRolls[rollID] = Link(itemID)
        H.Fire("START_LOOT_ROLL", rollID, 60)
        H.Advance(0)
    end

    local function WithOffSpecItem(ns, itemID)
        local list = ns.Lists:CreateCustom("Heal")
        ns.Lists:SetSlot(list.id, 2, itemID)
        ns.Lists:ToggleRole("os", list.id)
    end

    T.case("Decide: MS needs, OS greeds, never greeds an MS item, nothing without a match", function()
        local A = H.Boot().AutoRoll
        T.eq(A.Decide({ role = "ms" }, true, true), A.NEED, "MS")
        T.eq(A.Decide({ role = "ms" }, false, true), nil, "MS that cannot be needed is left alone")
        T.eq(A.Decide({ role = "os" }, true, true), A.GREED, "OS")
        T.eq(A.Decide({ role = "os" }, true, false), nil, "OS that cannot be greeded")
        T.eq(A.Decide(nil, true, true), nil, "no match")
        T.eq(A.RollRange({ role = "ms" }), 100, "MS range")
        T.eq(A.RollRange({ role = "os" }), 99, "OS range")
    end)

    T.case("off by default: a BiS roll gets the badge, nothing is rolled", function()
        local ns = InRaid()
        T.eq(ns.db.settings.autoRoll, false, "default off")
        GroupRoll(11, 32521)
        T.eq(#H.lootActions, 0, "no roll")
        T.noErrors()
    end)

    T.case("on: Need on an MS item, one chat line, BoP confirmed only for its own roll", function()
        AutoRollOn()
        T.ok(H.Printed("Auto-roll on", true), "toggle message")
        GroupRoll(11, 32521)
        T.eq(H.lootActions[1], "roll:11:1", "Need")
        T.eq(#H.lootActions, 1, "one action")
        T.ok(H.Printed("Auto-roll: Need on " .. Link(32521) .. " (BiS)", true), "chat line")
        H.Fire("CONFIRM_LOOT_ROLL", 11, 1)
        T.eq(H.lootActions[2], "confirm:11:1", "own BoP roll confirmed")
        H.Fire("CONFIRM_LOOT_ROLL", 11, 1)
        H.Fire("CONFIRM_LOOT_ROLL", 12, 1)
        T.eq(#H.lootActions, 2, "never twice, never for a roll it did not make")
        T.noErrors()
    end)

    T.case("on: Greed on an OS item; an MS item that cannot be Needed is not rolled", function()
        local ns = AutoRollOn()
        WithOffSpecItem(ns, 99999)
        GroupRoll(21, 99999)
        T.eq(H.lootActions[1], "roll:21:2", "Greed")
        H.rollOptions[22] = { false, true }
        GroupRoll(22, 32521)
        T.eq(#H.lootActions, 1, "no Greed on an MS item")
        T.noErrors()
    end)

    T.case("on: owned items and items on neither list are never rolled", function()
        local ns = AutoRollOn()
        GroupRoll(31, 1)
        ns.Owned:ToggleManual(32521)
        GroupRoll(32, 32521)
        T.eq(#H.lootActions, 0, "nothing rolled")
    end)

    T.case("Gargul loaded: paused, and the command says why", function()
        AutoRollOn({ addons = { Gargul = true } })
        T.ok(H.Printed("paused while Gargul is loaded", true), "message")
        GroupRoll(41, 32521)
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll for " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(#H.lootActions, 0, "no group-loot roll")
        T.eq(#H.rolled, 0, "no /roll")
    end)

    T.case("raid warning from the leader: one /roll 1-100, no roll popup", function()
        AutoRollOn()
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521) .. " " .. Link(30987), "Boss-Spineshatter")
        H.Advance(1)
        T.eq(H.rolled[1], "1-100", "MS roll")
        T.eq(#H.rolled, 1, "one roll per announcement")
        T.ok(not (_G.GudaBiSRollPopup and _G.GudaBiSRollPopup:IsShown()), "no popup")
        H.Advance(5)
        H.Fire("CHAT_MSG_RAID_WARNING", "Won " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(#H.rolled, 1, "the same item again soon (the winner) does not roll again")
        H.Advance(300)
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(#H.rolled, 2, "after five minutes it is a new roll call")
        T.noErrors()
    end)

    T.case("raid warning from an assistant: no auto /roll, the popup shows instead", function()
        AutoRollOn()
        H.assistants.Helper = true
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521), "Helper")
        H.Advance(1)
        T.eq(#H.rolled, 0, "assistants do not call auto-rolls")
        T.ok(_G.GudaBiSRollPopup:IsShown(), "popup")
    end)

    T.case("alerts off, auto-roll on: still rolls, shows nothing", function()
        local ns = AutoRollOn()
        ns.db.settings.alerts.enabled = false
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(H.rolled[1], "1-100", "rolled")
        T.ok(not _G.GudaBiSDropToast, "no toast")
        GroupRoll(51, 32521)
        T.eq(H.lootActions[1], "roll:51:1", "group loot too")
        T.noErrors()
    end)

    T.case("/gbis autoroll toggles and saves the setting", function()
        local ns = H.Boot()
        H.Slash("autoroll")
        T.eq(ns.db.settings.autoRoll, true, "toggled on")
        H.Slash("autoroll off")
        T.eq(ns.db.settings.autoRoll, false, "off")
        T.ok(H.Printed("Auto-roll off.", true), "message")
    end)
end
