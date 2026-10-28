-- GB-040/041/042: custom lists, the item picker, and the MS/OS roles.

return function(T, H)
    local GUIDE = "PALADIN_PROTECTION:4:1"

    local function SlotButton(slot)
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "slot") == slot and rawget(frame, "icon") and rawget(frame, "enchant") then return frame end
        end
    end

    local function Dialog()
        return _G.GudaBiSNameDialog
    end

    local function DialogOK(name, copy)
        local dialog = Dialog()
        dialog.edit:SetText(name)
        dialog.copy:SetChecked(copy)
        dialog.edit:Script("OnEnterPressed")
    end

    local function FlyoutRows()
        local out = {}
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "rank") and frame:IsShown() then out[#out + 1] = frame end
        end
        return out
    end

    -- Opens a panel dropdown and returns its visible menu rows.
    local function MenuRows(dd)
        if not dd.menu:IsShown() then dd.button:Click() end
        local rows = {}
        for _, row in ipairs(dd.menu.rows) do
            if row:IsShown() then rows[#rows + 1] = row end
        end
        return rows
    end

    local function ChooseRole(value)
        for _, row in ipairs(MenuRows(H.ns.Panel.roleDropdown)) do
            if row.value == value then return row:Click() end
        end
        error("no role row " .. tostring(value))
    end

    -- The list menu's action row whose text contains `text`, or nil (menu closed again).
    local function ListAction(text)
        local dd = H.ns.Panel.listDropdown
        for _, row in ipairs(MenuRows(dd)) do
            if row.action and row.text.shownText:find(text, 1, true) then return row end
        end
        dd:Close()
        return nil
    end

    T.case("ParseItemID: numbers, item links and Wowhead URLs", function()
        local ns = H.Boot()
        T.eq(ns.Lists.ParseItemID(" 32521 "), 32521, "number")
        T.eq(ns.Lists.ParseItemID("|cffa335ee|Hitem:32521:0:0|h[Faceplate]|h|r"), 32521, "link")
        T.eq(ns.Lists.ParseItemID("https://www.wowhead.com/tbc/item=32521/faceplate"), 32521, "url")
        T.eq(ns.Lists.ParseItemID("faceplate"), nil, "text")
        T.eq(ns.Lists.ParseItemID(nil), nil, "nil")
    end)

    T.case("FitsSlot follows equip locations", function()
        local ns = H.Boot()
        T.ok(ns.Lists.FitsSlot("INVTYPE_ROBE", 5), "robe in chest")
        T.ok(ns.Lists.FitsSlot("INVTYPE_FINGER", 12), "ring in ring 2")
        T.ok(ns.Lists.FitsSlot("INVTYPE_SHIELD", 17), "shield in off hand")
        T.ok(not ns.Lists.FitsSlot("INVTYPE_HEAD", 3), "head not in shoulder")
        T.ok(not ns.Lists.FitsSlot(nil, 1), "unknown")
    end)

    T.case("+ makes an empty named list, selected and shown", function()
        local ns = H.Boot()
        H.Slash("")
        ns.Panel:Refresh()
        ListAction("New list"):Click()
        T.ok(ns.NameDialog:IsShown(), "dialog")
        T.eq(Dialog().edit:GetText(), "My list 1", "default name")
        DialogOK("Raid tank", false)
        local current = ns.Lists:Current()
        T.ok(current.custom, "custom selected")
        T.eq(current.name, "Raid tank", "name")
        T.eq(next(current.items), nil, "empty")
        T.eq(SlotButton(1).item, nil, "head empty in the panel")
        T.ok(_G.GudaBiS_DB.lists[current.id] ~= nil, "account-wide")
        T.noErrors()
    end)

    T.case("copy the current list; rename; delete clears roles", function()
        local ns = H.Boot()
        local guide = ns.Data:Get(GUIDE)
        local list = ns.Lists:CreateCustom("Copy", guide)
        T.eq(list.items[1], 32521, "items copied")
        T.eq(list.enchants[1], 35447, "enchants copied")
        T.eq(list.gems[1][2], 32196, "gems copied")
        list.gems[1][2] = 1
        T.eq(guide.gems[1][2], 32196, "a real copy, the guide is untouched")
        ns.Lists:Rename(list.id, "Renamed")
        T.eq(ns.Lists:Get(list.id).name, "Renamed", "renamed")
        ns.Lists:ToggleRole("os", list.id)
        T.eq(ns.Lists:OffSpec().id, list.id, "OS set")
        ns.Lists:Delete(list.id)
        T.eq(ns.Lists:Get(list.id), nil, "gone")
        T.eq(ns.Lists:OffSpec(), nil, "OS cleared")
        T.eq(ns.Lists:Current().id, GUIDE, "back to a guide list")
    end)

    T.case("panel rename and delete only for custom lists, delete asks first", function()
        local ns = H.Boot()
        H.Slash("")
        T.ok(ListAction("New list") ~= nil, "New list in the list menu")
        T.ok(not ListAction("Rename this list") and not ListAction("Delete this list"), "not on a guide list")
        ns.Lists:CreateCustom("Mine")
        ns.Panel:Refresh()
        ListAction("Rename this list"):Click()
        local renameHeight = Dialog():GetHeight()
        Dialog():Hide()
        ListAction("New list"):Click()
        local newHeight = Dialog():GetHeight()
        Dialog():Hide()
        T.ok(renameHeight < newHeight, "rename has no copy or link box space")
        local delete = ListAction("Delete this list")
        T.ok(delete ~= nil, "delete on a custom list")
        T.eq(H.ns.Panel.listDropdown.button.text.shownText:find("Delete", 1, true), nil, "an action never shows as the choice")
        delete:Click()
        T.ok(not Dialog().edit:IsShown(), "confirm has no name box")
        T.ok(Dialog():GetHeight() < renameHeight, "the question is shorter still")
        Dialog().edit:Script("OnEnterPressed")
        T.ok(not ns.Lists:Current().custom, "deleted")
    end)

    T.case("picker: every guide item for the slot, then Clear; a click fills the slot", function()
        local ns = H.Boot()
        ns.Lists:CreateCustom("Mine")
        H.Slash("")
        local head = SlotButton(1)
        head:Click()
        local rows = FlyoutRows()
        local guide = ns.Data:Get(GUIDE)
        T.ok(#ns.Lists:GuideItemsForSlot(1) > 4, "more guide items than fit")
        T.eq(#rows, 5, "four items, then Clear")
        T.eq(rows[1].id, ns.Lists:GuideItemsForSlot(1)[1], "in the picker's order")
        T.ok(guide.items[1] ~= nil, "guide head item")
        T.eq(rows[#rows].clear, true, "Clear row last")
        T.eq(rows[1].rank.shownText, "", "no ranks in the picker")
        local picked = rows[1].id
        rows[1]:Click()
        T.eq(ns.Lists:Current().items[1], picked, "slot filled")
        T.eq(head.item, picked, "panel repainted")
        head:Click()
        rows = FlyoutRows()
        rows[#rows]:Click()
        T.eq(ns.Lists:Current().items[1], nil, "cleared")
        T.noErrors()
    end)

    T.case("picker: mouse wheel scrolls four at a time, the range says where you are", function()
        local ns = H.Boot()
        ns.Lists:CreateCustom("Mine")
        H.Slash("")
        SlotButton(1):Click()
        local all = ns.Lists:GuideItemsForSlot(1)
        local flyout = _G.GudaBiSRankFlyout
        T.ok(flyout.range:IsShown(), "range shown")
        T.eq(flyout.range.shownText, "1-4 / " .. #all, "range")
        flyout:Script("OnMouseWheel", -1)
        T.eq(FlyoutRows()[1].id, all[2], "scrolled one down")
        flyout:Script("OnMouseWheel", -100)
        local rows = FlyoutRows()
        T.eq(rows[4].id, all[#all], "stops at the last item")
        flyout:Script("OnMouseWheel", 100)
        T.eq(FlyoutRows()[1].id, all[1], "back at the top")
        T.noErrors()
    end)

    T.case("picker search: filters by name, Enter picks the first match, nothing matches", function()
        local ns = H.Boot()
        ns.Lists:CreateCustom("Mine")
        H.Slash("")
        local all = ns.Lists:GuideItemsForSlot(1)
        for _, id in ipairs(all) do H.cached[id] = true end
        local target = all[#all]
        SlotButton(1):Click()
        local flyout = _G.GudaBiSRankFlyout
        local edit = flyout.search.edit
        edit:SetText("item" .. target)
        edit:Script("OnTextChanged")
        local rows = FlyoutRows()
        T.eq(rows[1].id, target, "only the match")
        T.eq(rows[2].clear, true, "then Clear")
        T.eq(ns.RankFlyout.Filter({ 1, 2 }, "b", function(id) return id == 2 and "Bracers" or "Helm" end)[1], 2, "pure filter")
        edit:SetText("zzz")
        edit:Script("OnTextChanged")
        T.ok(flyout.empty:IsShown(), "nothing matches")
        T.eq(#FlyoutRows(), 1, "only Clear")
        edit:SetText("item" .. target)
        edit:Script("OnTextChanged")
        edit:Script("OnEnterPressed")
        T.eq(ns.Lists:Current().items[1], target, "Enter picks the first match")
        T.noErrors()
    end)

    T.case("picker marks the slot being filled until it closes; the note is on top", function()
        local ns = H.Boot()
        ns.Lists:CreateCustom("Mine")
        H.Slash("")
        local head = SlotButton(1)
        head:Click()
        T.ok(head.gudaBiSPicking:IsShown(), "slot highlighted")
        T.ok(_G.GudaBiSRankFlyout.search.note:IsShown(), "shift-click note")
        T.eq(_G.GudaBiSRankFlyout.search.note.shownText, ns.L.PICK_HINT, "note text")
        local neck = SlotButton(2)
        neck:Click()
        T.ok(not head.gudaBiSPicking:IsShown(), "moved off the head")
        T.ok(neck.gudaBiSPicking:IsShown(), "onto the neck")
        neck:Click()
        T.ok(not neck.gudaBiSPicking:IsShown(), "cleared on close")
        T.noErrors()
    end)

    T.case("picker ID box, shift-click from anywhere, and drag; wrong slots refused", function()
        local ns = H.Boot()
        ns.Lists:CreateCustom("Mine")
        H.Slash("")
        local shoulder = SlotButton(3)
        H.equipLoc[30998] = "INVTYPE_SHOULDER"
        H.equipLoc[29070] = "INVTYPE_SHOULDER"
        H.equipLoc[12345] = "INVTYPE_SHOULDER"
        shoulder:Click()
        local edit = _G.GudaBiSRankFlyout.search.edit
        edit:SetText("https://www.wowhead.com/tbc/item=32521")
        edit:Script("OnEnterPressed")
        T.eq(ns.Lists:Current().items[3], nil, "a helm does not go in the shoulder")
        T.ok(H.Printed("does not fit this slot", true), "said why")
        edit:SetText("30998")
        edit:Script("OnEnterPressed")
        T.eq(ns.Lists:Current().items[3], 30998, "ID box")
        shoulder:Click()
        _G.HandleModifiedItemClick("|Hitem:29070:0|h[x]|h")
        T.eq(ns.Lists:Current().items[3], 29070, "shift-click while the picker is open")
        _G.HandleModifiedItemClick("|Hitem:12345:0|h[x]|h")
        T.eq(ns.Lists:Current().items[3], 29070, "no picking once it closed")
        H.cursor = 12345
        shoulder:Script("OnReceiveDrag")
        T.eq(ns.Lists:Current().items[3], 12345, "dragged in")
        T.eq(H.cursor, nil, "cursor cleared")
        T.noErrors()
    end)

    T.case("a guide list is never edited: click shows the ranked list, drag is ignored", function()
        local ns = H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        H.cursor = 30987
        head:Script("OnReceiveDrag")
        T.eq(ns.Data:Get(GUIDE).items[1], 32521, "guide unchanged")
        H.cursor = nil
        head:Click()
        T.eq(FlyoutRows()[1].rank.shownText, "1.", "ranked, not a picker")
    end)

    T.case("SetSlot keeps the slot's enchant and takes a guide's gems for the same item", function()
        local ns = H.Boot()
        local list = ns.Lists:CreateCustom("Mine", ns.Data:Get(GUIDE))
        ns.Lists:SetSlot(list.id, 1, 30987)
        T.eq(list.enchants[1], 35447, "enchant kept")
        T.eq(list.gems[1], nil, "no guide gems for this helm: empty sockets")
        ns.Lists:SetSlot(list.id, 1, 32521)
        T.eq(list.gems[1][1], 25896, "guide gems for the guide's helm")
        list.gems[1][1] = 1
        T.eq(ns.Data:Get(GUIDE).gems[1][1], 25896, "a copy")
        ns.Lists:SetSlot(list.id, 1, nil)
        T.eq(list.enchants[1], nil, "clearing the slot clears its enchant")
    end)

    T.case("SetGem fills and empties sockets by index", function()
        local ns = H.Boot()
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 5, 12345)
        ns.Lists:SetGem(list.id, 5, 2, 32196)
        T.eq(list.gems[5][1], 0, "socket 1 still empty")
        T.eq(list.gems[5][2], 32196, "socket 2")
        ns.Lists:SetGem(list.id, 5, 2, nil)
        T.eq(list.gems[5], nil, "all empty: no gem table")
        ns.Lists:SetEnchant(list.id, 5, 27957)
        T.eq(list.enchants[5], 27957, "enchant")
    end)

    T.case("ParseSpellID, sockets from item stats, gem colours", function()
        local ns = H.Boot()
        T.eq(ns.Lists.ParseSpellID("https://www.wowhead.com/tbc/spell=27957"), 27957, "url")
        T.eq(ns.Lists.ParseSpellID("27957"), 27957, "number")
        T.eq(ns.Lists.ParseSpellID("|Henchant:27957|h[x]|h"), 27957, "enchant link")
        H.itemStats[30991] = { EMPTY_SOCKET_BLUE = 1, EMPTY_SOCKET_RED = 2 }
        local sockets = ns.Items.Sockets(30991)
        T.eq(table.concat(sockets, ","), "RED,RED,BLUE", "meta, red, yellow, blue order")
        T.eq(#ns.Items.Sockets(1), 0, "no sockets")
        H.itemClass[32196], H.itemSubclass[32196] = 3, 3
        T.ok(ns.Items.IsGem(32196), "a gem")
        T.ok(not ns.Items.IsGem(30991), "armor is not")
        T.ok(ns.Items.GemMatches(32196, "RED"), "purple fits red")
        T.ok(ns.Items.GemMatches(32196, "BLUE"), "purple fits blue")
        T.ok(not ns.Items.GemMatches(32196, "YELLOW"), "purple misses yellow")
        T.ok(ns.Items.GemMatches(32196, nil), "unknown socket: no note")
    end)

    T.case("custom list: empty sockets shown; enchant picker offers the guide's enchants", function()
        local ns = H.Boot()
        H.itemStats[12345] = { EMPTY_SOCKET_RED = 1, EMPTY_SOCKET_YELLOW = 1 }
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 5, 12345)
        H.Slash("")
        local chest = SlotButton(5)
        T.ok(chest.gems[1]:IsShown() and chest.gems[2]:IsShown(), "two sockets")
        T.ok(chest.gems[1].icon.texture:find("UI%-EmptySocket%-Red"), "red empty socket art")
        T.ok(chest.enchant:IsShown(), "enchant placeholder")
        chest.enchant:Click()
        local rows = FlyoutRows()
        T.eq(rows[1].id, 27957, "guide chest enchant offered")
        T.eq(rows[1].name.shownText, "Spell27957", "spell name")
        rows[1]:Click()
        T.eq(list.enchants[5], 27957, "picked")
        chest.enchant:Click()
        local edit = _G.GudaBiSRankFlyout.search.edit
        edit:SetText("https://www.wowhead.com/tbc/spell=33992")
        edit:Script("OnEnterPressed")
        T.eq(list.enchants[5], 33992, "typed spell link")
        T.noErrors()
    end)

    T.case("gem picker: gems only, colour note, drag a gem onto a socket", function()
        local ns = H.Boot()
        H.itemStats[12345] = { EMPTY_SOCKET_YELLOW = 1 }
        H.itemClass[32196], H.itemSubclass[32196] = 3, 3
        H.itemClass[32200], H.itemSubclass[32200] = 3, 1
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 5, 12345)
        H.Slash("")
        local chest = SlotButton(5)
        chest.gems[1]:Click()
        local edit = _G.GudaBiSRankFlyout.search.edit
        edit:SetText("12345")
        edit:Script("OnEnterPressed")
        T.ok(H.Printed("is not a gem", true), "armor refused")
        edit:SetText("32196")
        edit:Script("OnEnterPressed")
        T.eq(list.gems[5][1], 32196, "gem set")
        chest = SlotButton(5)
        chest.gems[1]:Enter()
        local note = false
        for _, line in ipairs(_G.GameTooltip.lines) do
            if line:find("socket colour", 1, true) then note = true end
        end
        T.ok(note, "purple in a yellow socket gets the note")
        H.cursor = 32200
        chest.gems[1]:Script("OnReceiveDrag")
        T.eq(list.gems[5][1], 32200, "dragged gem")
        T.noErrors()
    end)

    T.case("guide lists: enchant and gem icons are not editable", function()
        local ns = H.Boot()
        H.Slash("")
        local head = SlotButton(1)
        head.enchant:Click()
        T.ok(not ns.RankFlyout:IsOpenFor(head.enchant), "no enchant picker on a guide list")
        H.cursor = 32200
        head.gems[1]:Script("OnReceiveDrag")
        T.eq(ns.Data:Get(GUIDE).gems[1][1], 25896, "guide gem unchanged")
    end)

    T.case("MS defaults to the active tree's guide list; the role dropdown sets and clears", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        T.eq(ns.Lists:MainSpec().id, GUIDE, "default MS")
        T.eq(ns.Lists:OffSpec(), nil, "no OS")
        local custom = ns.Lists:CreateCustom("Heal gear")
        H.Slash("")
        ChooseRole("ms")
        T.eq(ns.Lists:MainSpec().id, custom.id, "custom list is MS")
        ChooseRole("os")
        T.eq(ns.Lists:OffSpec().id, custom.id, "now OS")
        T.eq(ns.Lists:MainSpec().id, GUIDE, "MS back to the default, a list cannot be both")
        ChooseRole("os")
        T.eq(ns.Lists:OffSpec().id, custom.id, "choosing the same role keeps it")
        ChooseRole("none")
        T.eq(ns.Lists:OffSpec(), nil, "none clears")
        T.noErrors()
    end)

    T.case("the default MS guide list can be moved to OS and back, and MS cleared", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("")
        T.eq(ns.Lists:RoleOf(GUIDE), "ms", "Balanced is MS by default")
        ChooseRole("os")
        T.eq(ns.Lists:RoleOf(GUIDE), "os", "now OS, not stuck on MS")
        T.eq(ns.Lists:OffSpec().id, GUIDE, "OS list")
        T.ok(ns.Lists:MainSpec() == nil or ns.Lists:MainSpec().id ~= GUIDE, "MS is something else")
        ChooseRole("ms")
        T.eq(ns.Lists:RoleOf(GUIDE), "ms", "back to MS")
        T.eq(ns.Lists:OffSpec(), nil, "OS cleared")
        ChooseRole("none")
        T.eq(ns.Lists:MainSpec(), nil, "none clears MS, even the default")
        T.eq(ns.Lists:RoleOf(GUIDE), nil, "no role")
        ChooseRole("ms")
        T.eq(ns.Lists:MainSpec().id, GUIDE, "and sets it again")
        T.noErrors()
    end)

    T.case("the role dropdown shows the list's role in colour, and only with a list", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        H.Slash("")
        local role = ns.Panel.roleDropdown
        T.ok(role.button:IsShown(), "shown")
        T.eq(role.button.text.shownText, "|cff40ff40MS|r", "MS in green")
        ChooseRole("os")
        T.eq(role.button.text.shownText, "|cff40c0ffOS|r", "OS in blue")
        ChooseRole("none")
        T.eq(role.button.text.shownText, "|cff808080—|r", "none in grey")
        T.eq(role.button.tooltip, ns.L.TOOLTIP_ROLE, "explains MS and OS")
        T.noErrors()
    end)

    T.case("roles are per talent group (dual spec) and labelled in the list dropdown", function()
        local ns = H.Boot()
        local group = 1
        _G.C_SpecializationInfo.GetActiveSpecGroup = function() return group end
        local custom = ns.Lists:CreateCustom("Heal gear")
        ns.Lists:ToggleRole("ms", custom.id)
        group = 2
        T.eq(ns.Lists:MainSpec().id, GUIDE, "second group has its own MS")
        group = 1
        T.eq(ns.Lists:MainSpec().id, custom.id, "first group kept")
        T.eq(ns.Lists:RoleOf(custom.id), "ms", "role")
        local label = ns.Panel.ListLabel(custom, nil, "ms")
        T.ok(label:find("MS", 1, true) and label:find("Heal gear", 1, true), "tagged label")
    end)
end
