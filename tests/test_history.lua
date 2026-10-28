-- GB-071: loot history sessions and the History tab.

return function(T, H)
    local EPIC, RARE = "a335ee", "0070dd"

    local function Link(itemID, color)
        return "|cff" .. (color or EPIC) .. "|Hitem:" .. itemID .. "::::::::70:::::|h[Item" .. itemID .. "]|h|r"
    end

    local function Enter(name, kind, id, difficulty)
        H.instance = { name, kind, difficulty or "", id }
        H.Fire("PLAYER_ENTERING_WORLD", false, false)
    end

    local function InRaid(opts)
        local ns = H.Boot(opts)
        H.SetGroup(true)
        H.leaders.Boss = true
        Enter("Karazhan", "raid", 532, "10 Player")
        return ns
    end

    local function Received(who, link)
        if who then
            H.Fire("CHAT_MSG_LOOT", who .. " receives loot: " .. link .. ".")
        else
            H.Fire("CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
        end
    end

    T.case("ParseLoot: others, the player, stacks, positional templates, other text", function()
        local ns = H.Boot()
        local Hi = ns.History
        local link, winner = Hi.ParseLoot("Boss-Spineshatter receives loot: " .. Link(1) .. ".")
        T.eq(link, Link(1), "link")
        T.eq(winner, "Boss-Spineshatter", "winner")
        link, winner = Hi.ParseLoot("You receive loot: " .. Link(2) .. ".")
        T.eq(link, Link(2), "own link")
        T.eq(winner, "", "the player")
        link = Hi.ParseLoot("Boss receives loot: " .. Link(3) .. "x2.")
        T.eq(link, Link(3), "stack")
        T.eq(Hi.ParseLoot("Boss says: " .. Link(4)), nil, "not a loot line")
        T.eq(Hi.ParseLoot("no link"), nil, "no link")
        local pattern, order = Hi.Pattern("Beute: %2$s für %1$s.")
        local item, name = ("Beute: " .. Link(5) .. " für Boss."):match(pattern)
        T.eq(item, Link(5), "positional capture 1")
        T.eq(name, "Boss", "positional capture 2")
        T.eq(order[1], 2, "item is argument 2")
        T.eq(order[2], 1, "name is argument 1")
    end)

    T.case("Quality and Keep: epic+ in raids, rare+ in dungeons, list items always", function()
        local Hi = H.Boot().History
        T.eq(Hi.Quality(Link(1)), 4, "epic")
        T.eq(Hi.Quality(Link(1, RARE)), 3, "rare")
        T.eq(Hi.Quality("nonsense"), nil, "no color")
        T.ok(Hi.Keep("raids", 4, false), "raid epic")
        T.ok(not Hi.Keep("raids", 3, false), "raid rare dropped")
        T.ok(Hi.Keep("raids", 2, true), "list item always")
        T.ok(Hi.Keep("dungeons", 3, false), "dungeon rare")
        T.ok(not Hi.Keep("dungeons", 2, false), "dungeon green dropped")
    end)

    T.case("raid: who received what, filtered by quality, list items labelled", function()
        local ns = InRaid()
        Received("Boss-Spineshatter", Link(28000))
        Received("Boss", Link(28001, RARE))
        Received(nil, Link(32521, RARE))
        local sessions = ns.History:Sessions("raids")
        T.eq(#sessions, 1, "one session")
        local s = sessions[1]
        T.eq(s.name, "Karazhan", "name")
        T.eq(s.char, "Vati-Spineshatter", "character")
        T.eq(#s.drops, 2, "the rare non-list item is not kept")
        T.eq(s.drops[1].winner, "Boss", "short winner name")
        T.eq(s.drops[2].winner, "Vati", "the player")
        T.eq(s.drops[2].role, "ms", "list item role")
        T.eq(s.drops[2].rank, 1, "BiS even though it is owned now")
        T.noErrors()
    end)

    T.case("seen then received: one entry, winner filled in; seen twice counts once", function()
        local ns = InRaid()
        H.lootRolls[7] = Link(28010)
        H.Fire("START_LOOT_ROLL", 7, 60)
        H.Fire("CHAT_MSG_RAID", Link(28010), "Boss")
        local drops = ns.History:Sessions("raids")[1].drops
        T.eq(#drops, 1, "one seen drop")
        T.eq(drops[1].winner, nil, "nobody yet")
        Received("Healer", Link(28010))
        T.eq(#drops, 1, "same entry")
        T.eq(drops[1].winner, "Healer", "winner")
    end)

    T.case("raid session: survives relogs within the lockout, new one after it resets", function()
        local ns = InRaid()
        H.saved = { { "Karazhan", 3 * 86400 } }
        Received("Boss", Link(28020))
        H.Advance(2 * 86400)
        H.saved = { { "Karazhan", 86400 } }
        Enter("Karazhan", "raid", 532)
        Received("Boss", Link(28021))
        T.eq(#ns.History:Sessions("raids"), 1, "same lockout")
        H.Advance(2 * 86400)
        H.saved = {}
        Enter("Karazhan", "raid", 532)
        Received("Boss", Link(28022))
        T.eq(#ns.History:Sessions("raids"), 2, "after the reset")
    end)

    T.case("only the last 5 raid sessions are kept", function()
        local ns = InRaid()
        for i = 1, 7 do
            Enter("Raid" .. i, "raid", 500 + i)
            Received("Boss", Link(28100 + i))
        end
        local sessions = ns.History:Sessions("raids")
        T.eq(#sessions, 5, "five")
        T.eq(sessions[1].name, "Raid7", "newest first")
        T.eq(sessions[5].name, "Raid3", "oldest kept")
    end)

    T.case("dungeon: same run until another instance or a reset", function()
        local ns = InRaid()
        Enter("Shadow Labyrinth", "party", 555)
        Received("Boss", Link(28200, RARE))
        Enter("", "none", 0)
        Enter("Shadow Labyrinth", "party", 555)
        Received("Boss", Link(28201, RARE))
        T.eq(#ns.History:Sessions("dungeons"), 1, "zoning out and back in")
        H.Fire("CHAT_MSG_SYSTEM", "Shadow Labyrinth has been reset.")
        Received("Boss", Link(28202, RARE))
        T.eq(#ns.History:Sessions("dungeons"), 2, "reset")
        Enter("Arcatraz", "party", 552)
        Enter("Shadow Labyrinth", "party", 555)
        Received("Boss", Link(28203, RARE))
        T.eq(#ns.History:Sessions("dungeons"), 3, "another instance in between")
    end)

    T.case("nothing is recorded outside instances or while solo", function()
        local ns = H.Boot()
        H.SetGroup(true)
        Received("Boss", Link(28300))
        H.SetGroup(false)
        Enter("Karazhan", "raid", 532)
        Received("Boss", Link(28301))
        T.eq(#ns.History:Sessions("raids"), 0, "nothing")
        T.ok(not H.Registered("CHAT_MSG_LOOT"), "no loot listener while solo")
    end)

    T.case("History tab: /gbis history opens it with the newest session", function()
        local ns = InRaid()
        Received("Boss", Link(28400))
        Received(nil, Link(32521))
        H.Slash("history")
        T.ok(ns.Panel:IsShown(), "panel open")
        T.eq(ns.Panel:ActiveTab(), "history", "history tab")
        local view = _G.GudaBiSHistoryView
        T.ok(view:IsShown(), "history view")
        T.ok(not view.emptyNote:IsShown(), "no empty note")
        local session = ns.History:Sessions("raids")[1]
        T.eq(ns.HistoryTab.SessionLabel(session):match("^Karazhan %(10 Player%) · "), "Karazhan (10 Player) · ", "label")
        T.ok(ns.HistoryTab.SessionLabel(session):find("· 2 drops", 1, true) ~= nil, "drop count")
        T.eq(ns.HistoryTab.Tag(session.drops[2]), "|cff40ff40BiS|r", "BiS tag")
        T.eq(ns.HistoryTab.Tag(session.drops[1]), "", "no tag")
        T.eq(ns.HistoryTab.Winner({}), "seen", "seen")
        ns.Panel:ShowTab("gear")
        T.ok(not view:IsShown(), "gear tab hides it")
        T.noErrors()
    end)

    T.case("History tab: empty note before any loot", function()
        local ns = H.Boot()
        H.Slash("history")
        T.ok(_G.GudaBiSHistoryView.emptyNote:IsShown(), "empty note")
        T.eq(#ns.HistoryTab.SessionsOf("Vati-Spineshatter"), 0, "no sessions")
        T.noErrors()
    end)
end
