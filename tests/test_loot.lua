-- GB-060..064: matching drops to MS/OS lists, Blizzard group-loot badges, chat alerts,
-- the roll popup, Gargul and RCLootCouncil.

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

    local function Toast()
        return _G.GudaBiSDropToast
    end

    local function Popup()
        return _G.GudaBiSRollPopup
    end

    T.case("Match: MS BiS, MS alternative, OS list, owned and alternatives setting", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        local m = ns.Match:Item(32521)
        T.eq(m.role, "ms", "ms")
        T.eq(m.rank, 1, "BiS")
        T.eq(m.slot, 1, "slot")
        T.eq(ns.Match.Label(m), "BiS", "label")
        m = ns.Match:Item(30987)
        T.eq(m.rank, 2, "first alternative")
        T.eq(ns.Match.Label(m), "alt #1", "alt label")
        T.eq(ns.Match:Item(1), nil, "not on a list")
        local os = ns.Lists:CreateCustom("Heal")
        ns.Lists:SetSlot(os.id, 2, 99999)
        ns.Lists:ToggleRole("os", os.id)
        m = ns.Match:Item(99999)
        T.eq(m.role, "os", "os")
        T.eq(ns.Match.Label(m), "OS", "os label")
        ns.db.settings.alerts.alts = false
        T.eq(ns.Match:Item(30987), nil, "alternatives off")
        T.ok(ns.Match:Item(32521) ~= nil, "BiS still on")
        ns.db.settings.alerts.alts = true
        ns.Owned:ToggleManual(32521)
        T.eq(ns.Match:Item(32521), nil, "owned items never match")
    end)

    T.case("RollSeconds: the number in the announcement, not roll ranges or the link", function()
        local ns = H.Boot()
        local D = ns.Detect
        T.eq(D.RollSeconds("You have 15 seconds to roll on " .. Link(32521)), 15, "english")
        T.eq(D.RollSeconds(Link(30000) .. " 20 сек"), 20, "other language, link digits ignored")
        T.eq(D.RollSeconds("/roll 100 for MS, 99 for OS " .. Link(32521)), nil, "ranges are not seconds")
        T.eq(D.RollSeconds(Link(32521)), nil, "no number")
    end)

    T.case("loot authority: leader, assistant, master looter; nobody else", function()
        local ns = H.Boot()
        H.leaders.Boss = true
        H.assistants.Helper = true
        T.ok(ns.Detect.IsLootAuthority("Boss-Spineshatter"), "leader")
        T.ok(ns.Detect.IsLootAuthority("Helper"), "assistant")
        T.ok(not ns.Detect.IsLootAuthority("Random"), "raider")
        H.lootMethod = { 2, nil, 7 }
        H.raidRoster[7] = "Looter"
        T.ok(ns.Detect.IsLootAuthority("Looter"), "master looter")
    end)

    T.case("listeners are registered only in a group", function()
        H.Boot()
        T.ok(not H.Registered("START_LOOT_ROLL"), "solo: no loot listener")
        T.ok(not H.Registered("CHAT_MSG_RAID_WARNING"), "solo: no chat listener")
        H.SetGroup(true)
        T.ok(H.Registered("START_LOOT_ROLL") and H.Registered("CHAT_MSG_RAID_WARNING"), "in a group")
    end)

    T.case("Blizzard roll: glowing badge, proc glow on the item icon, with a sound", function()
        InRaid()
        local f1 = CreateFrame("Frame", "GroupLootFrame1")
        local icon = CreateFrame("Button", "GroupLootFrame1IconFrame")
        icon.width, icon.height = 34, 34
        f1.rollID = 11
        f1:Show()
        H.lootRolls[11] = Link(32521)
        H.Fire("START_LOOT_ROLL", 11, 60)
        H.Advance(0)
        local overlay = f1.gudaBiSBadge
        T.ok(overlay ~= nil, "badge made")
        T.eq(overlay.label.shownText, "Your BiS", "text")
        T.eq(overlay.label.textColor[2], 1, "bright text, not green on its own")
        local ns = H.ns
        T.ok(ns.Glow.IsShown(overlay.plate), "the label is wrapped in the proc glow")
        T.ok(ns.Glow.IsShown(icon), "the item icon has the proc glow")
        local glow = icon.gudaBiSGlow
        T.eq(glow.ants.texture, "Interface\\SpellActivationOverlay\\IconAlertAnts", "marching ants")
        T.eq(glow.outer.texture, "Interface\\SpellActivationOverlay\\IconAlert", "golden glow")
        T.ok(glow.loop.playing and glow.burst.playing, "ants run, burst plays")
        T.eq(glow.width, 34 * 1.4, "sized around the icon")
        T.eq(#H.sounds, 1, "sound")
        f1:Hide()
        T.ok(not ns.Glow.IsShown(icon), "icon glow cleared when the frame hides")
        T.ok(not overlay.plate:IsShown(), "label cleared too")
        H.lootRolls[12] = Link(1)
        f1.rollID = 12
        f1:Show()
        H.Fire("START_LOOT_ROLL", 12, 60)
        H.Advance(0)
        T.ok(not overlay.plate:IsShown(), "no badge for an item not on a list")
        T.noErrors()
    end)

    T.case("Compat finds the roll frame's item icon by parentKey or by name", function()
        local ns = H.Boot()
        local keyed = CreateFrame("Frame", "GroupLootFrame3")
        keyed.IconFrame = CreateFrame("Button")
        T.eq(ns.Compat.GetGroupLootIcon(3), keyed.IconFrame, "parentKey")
        CreateFrame("Frame", "GroupLootFrame4")
        local named = CreateFrame("Button", "GroupLootFrame4IconFrame")
        T.eq(ns.Compat.GetGroupLootIcon(4), named, "named child")
        T.eq(ns.Compat.GetGroupLootIcon(2), nil, "no frame")
    end)

    T.case("chat: leader's raid-warning link -> dropped toast, then the roll popup", function()
        InRaid()
        H.Fire("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. Link(32521), "Boss-Spineshatter")
        T.ok(Toast():IsShown(), "toast")
        T.eq(Toast().title.shownText, "Your BiS dropped!", "toast text")
        T.ok(not (Popup() and Popup():IsShown()), "popup waits a second for other addons")
        H.Advance(1)
        T.ok(Popup():IsShown(), "roll popup")
        T.eq(Popup().title.shownText, "Rolling now for your BiS", "popup text")
        T.eq(Popup().countdown.shownText, "20 s", "countdown from the announcement")
        H.Advance(1)
        T.eq(Popup().countdown.shownText, "19 s", "ticks")
        Popup().ms:Click()
        T.eq(H.rolled[1], "1-100", "MS roll")
        T.ok(not Popup():IsShown(), "closed after rolling")
        T.noErrors()
    end)

    T.case("chat: raid link only toasts; strangers and non-BiS are ignored; no double toast", function()
        InRaid()
        H.Fire("CHAT_MSG_RAID", Link(32521), "Random")
        T.ok(not Toast(), "a raider linking an item does nothing")
        H.Fire("CHAT_MSG_RAID", Link(1), "Boss")
        T.ok(not Toast(), "not on a list")
        H.Fire("CHAT_MSG_RAID", Link(32521), "Boss")
        T.ok(Toast():IsShown(), "toast from the leader")
        H.Advance(1)
        T.ok(not (Popup() and Popup():IsShown()), "raid chat is not a roll call")
        local sounds = #H.sounds
        H.Fire("CHAT_MSG_RAID_WARNING", Link(32521), "Boss")
        T.eq(#H.sounds, sounds, "same item on another channel at once: no second toast")
        H.Advance(5)
        T.ok(Popup():IsShown(), "but raid warning still opens the roll")
        T.ok(Popup().countdown.shownText ~= nil, "default countdown")
    end)

    T.case("chat: one item linked at loot, at the roll call and with the winner alerts once", function()
        local ns = InRaid()
        H.Fire("CHAT_MSG_RAID", "Loot: " .. Link(32521), "Boss")
        T.ok(Toast():IsShown(), "toast at loot")
        local sounds = #H.sounds
        H.Advance(90)
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521) .. " 20", "Boss")
        T.eq(#H.sounds, sounds, "no second toast at the roll call")
        H.Advance(1)
        T.ok(Popup():IsShown(), "the roll call still opens the roll")
        Popup().ms:Click()
        H.rolled = {}
        sounds = #H.sounds
        H.Advance(30)
        H.Fire("CHAT_MSG_RAID_WARNING", "Winner " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(#H.sounds, sounds, "no toast with the winner")
        T.ok(not Popup():IsShown(), "and no second roll")
        H.Slash("autoroll on")
        H.Fire("CHAT_MSG_RAID_WARNING", "Winner " .. Link(32521), "Boss")
        H.Advance(1)
        T.eq(#H.rolled, 0, "auto-roll does not roll again")
        H.Advance(300)
        H.Fire("CHAT_MSG_RAID", Link(32521), "Boss")
        T.ok(#H.sounds > sounds, "the same item alerts again after five minutes")
        T.noErrors()
    end)

    T.case("chat: loot listed in raid warning does not use up the real roll call", function()
        InRaid()
        H.Fire("CHAT_MSG_RAID_WARNING", "Loot: " .. Link(32521) .. " " .. Link(30987), "Boss")
        H.Advance(1)
        T.ok(Popup():IsShown(), "a card for the listing")
        Popup().close:Click()
        H.Advance(60)
        H.Fire("CHAT_MSG_RAID_WARNING", "Roll " .. Link(32521), "Boss")
        H.Advance(1)
        T.ok(Popup():IsShown(), "the real roll call opens it again")
        T.eq(#H.rolled, 0, "nothing rolled by itself")
        T.noErrors()
    end)

    T.case("chat: OS item opens the popup with OS highlighted; OS button rolls 1-99", function()
        local ns = InRaid()
        local os = ns.Lists:CreateCustom("Heal")
        ns.Lists:SetSlot(os.id, 2, 99999)
        ns.Lists:ToggleRole("os", os.id)
        H.Fire("CHAT_MSG_RAID_WARNING", Link(99999), "Boss")
        H.Advance(1)
        T.eq(Popup().title.shownText, "Rolling now for your OS", "os title")
        Popup().os:Click()
        T.eq(H.rolled[1], "1-99", "OS roll")
    end)

    T.case("alerts off: nothing at all", function()
        local ns = InRaid()
        ns.db.settings.alerts.enabled = false
        H.Fire("CHAT_MSG_RAID_WARNING", Link(32521), "Boss")
        H.Advance(1)
        T.ok(not Toast() and not Popup(), "silent")
    end)

    T.case("Retail chat lockdown: chat is skipped", function()
        InRaid({ client = "retail" })
        _G.C_ChatInfo = { InChatMessagingLockdown = function() return true end }
        H.Fire("CHAT_MSG_RAID_WARNING", Link(32521), "Boss")
        T.ok(not Toast(), "no toast while chat is secret")
        _G.C_ChatInfo = nil
    end)

    T.case("Gargul: badge on its roll window, no popup of ours, quiet when Gargul flagged it", function()
        local registered
        H.Install()
        _G.Gargul = {
            Events = { register = function(_, id, event, fn) registered = { id = id, event = event, fn = fn } end },
            RollOff = { inProgress = true, CurrentRollOff = { itemID = 32521, itemLink = Link(32521) } },
            isItemOfInterest = function() return true end,
        }
        local ns = H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        H.SetGroup(true)
        H.leaders.Boss = true
        T.eq(registered.event, "GL.ROLLOFF_STARTED", "hooked Gargul's event")
        local window = CreateFrame("Frame", "GargulUI_RollerUI_Window")
        window:Show()
        registered.fn()
        H.Advance(0)
        T.eq(window.gudaBiSBadge.label.shownText, "Your BiS", "badge on Gargul's window")
        T.eq(#H.sounds, 0, "Gargul already flagged it: no sound from us")
        H.Fire("CHAT_MSG_RAID_WARNING", "You have 10 seconds to roll on " .. Link(32521), "Boss")
        H.Advance(1)
        T.ok(not (Popup() and Popup():IsShown()), "Gargul is rolling it: no popup of ours")
        T.ok(ns.GargulBridge:IsRolling(32521), "bridge sees the roll")
        T.noErrors()
    end)

    T.case("/gbis test: toast, roll popup and a glowing dummy roll frame; nothing rolls", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test")
        T.ok(Toast():IsShown(), "toast")
        T.ok(Toast().title.shownText == "Your BiS dropped!", "toast text")
        T.ok(Popup():IsShown(), "roll popup")
        T.eq(Popup().countdown.shownText, "15 s", "15 s")
        local dummy = _G.GudaBiSTestRoll
        T.ok(dummy:IsShown(), "dummy roll frame")
        T.ok(ns.Glow.IsShown(dummy.IconFrame), "proc glow on its item icon")
        T.ok(not ns.Glow.IsShown(dummy.NeedButton), "not on Need")
        T.eq(dummy.gudaBiSBadge.label.shownText, "Your BiS", "badge")
        T.ok(ns.Glow.IsShown(dummy.gudaBiSBadge.plate), "glowing badge")
        Popup().ms:Click()
        T.eq(#H.rolled, 0, "test popup never rolls")
        dummy.greed:Click()
        T.ok(not dummy:IsShown(), "any dummy button closes it")
        T.ok(not ns.Glow.IsShown(dummy.IconFrame), "glow cleared")
        T.noErrors()
    end)

    T.case("cards: slot name, close button, entrance, burst, draining bar, role glow", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        _G.HEADSLOT = "Head"
        H.Slash("test drop")
        local toast = Toast()
        T.eq(toast.slot.shownText, "Head", "the game's slot name")
        T.ok(toast.entrance.playing and toast.burst.playing, "animated in")
        T.ok(toast.drain.playing, "timer bar drains")
        toast.close:Click()
        T.ok(not toast:IsShown(), "the drop card has a close button")
        H.Slash("test roll")
        T.ok(not ns.Glow.IsShown(Popup().ms) and not ns.Glow.IsShown(Popup().os), "roll buttons stay plain")
        T.ok(ns.Glow.IsShown(Popup().item), "the item still glows")
        Popup().close:Click()
        T.ok(not Popup():IsShown(), "roll card closes")
        _G.HEADSLOT = nil
        T.noErrors()
    end)

    T.case("the toast and the roll popup glow on their item icon until they close", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test drop")
        T.ok(ns.Glow.IsShown(Toast().item), "toast icon glows")
        H.Advance(15)
        T.ok(not Toast():IsShown(), "toast gone")
        T.ok(not ns.Glow.IsShown(Toast().item), "its glow too")
        H.Slash("test roll")
        T.ok(ns.Glow.IsShown(Popup().item), "popup icon glows")
        Popup().os:Click()
        T.ok(not ns.Glow.IsShown(Popup().item), "glow gone with the popup")
        T.noErrors()
    end)

    T.case("/gbis test drop|roll|group shows only that one", function()
        H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test drop")
        T.ok(Toast():IsShown(), "drop: toast")
        T.ok(not Popup() and not _G.GudaBiSTestRoll, "drop: nothing else")
        H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test ROLL")
        T.ok(Popup():IsShown(), "roll: popup (any case)")
        T.ok(not Toast() and not _G.GudaBiSTestRoll, "roll: nothing else")
        H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test group")
        T.ok(_G.GudaBiSTestRoll:IsShown(), "group: dummy roll frame")
        T.ok(not Toast() and not Popup(), "group: nothing else")
        H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("test nope")
        T.ok(H.Printed("/gbis test [drop|roll|group]", true), "unknown word: usage")
        T.ok(not Toast() and not Popup() and not _G.GudaBiSTestRoll, "nothing shown")
        T.noErrors()
    end)

    T.case("/gbis test without an MS list says so", function()
        H.Boot({ class = "DEATHKNIGHT" })
        H.Slash("test")
        T.ok(H.Printed("No item on your main-spec list", true), "message")
        T.ok(not Toast(), "no toast")
    end)

    T.case("RCLootCouncil: badges its entries after each update, never answers", function()
        local entryFrame
        local module = { EntryManager = { entries = {} } }
        function module:Update() end
        _G.LibStub = function()
            return { GetAddon = function() return { GetModule = function() return module end } end }
        end
        local libStub = _G.LibStub
        H.Install()
        _G.LibStub = libStub
        local ns = H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        entryFrame = CreateFrame("Frame")
        entryFrame:Show()
        module.EntryManager.entries[1] = { item = { link = Link(32521) }, frame = entryFrame }
        module:Update()
        T.eq(entryFrame.gudaBiSBadge.label.shownText, "Your BiS", "entry badged")
        T.ok(ns.RCLootCouncilBridge:IsShowing(32521), "bridge sees it")
        T.eq(#H.rolled, 0, "never rolls")
        T.noErrors()
    end)
end
