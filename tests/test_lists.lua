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

    local function ClickRole(role)
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "role") == role then frame:Click() end
        end
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
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "tooltip") == "New list" then frame:Click() end
        end
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
        local rename, delete
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "tooltip") == "Rename this list" then rename = frame end
            if rawget(frame, "tooltip") == "Delete this list" then delete = frame end
        end
        T.ok(not rename:IsShown() and not delete:IsShown(), "hidden on a guide list")
        ns.Lists:CreateCustom("Mine")
        ns.Panel:Refresh()
        T.ok(rename:IsShown() and delete:IsShown(), "shown on a custom list")
        delete:Click()
        T.ok(not Dialog().edit:IsShown(), "confirm has no name box")
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
        T.ok(#rows >= 1 + #guide.alts[1], "guide items offered")
        T.eq(rows[#rows].clear, true, "Clear row last")
        T.eq(rows[1].rank.shownText, "", "no ranks in the picker")
        rows[1]:Click()
        T.eq(ns.Lists:Current().items[1], rows[1].item, "slot filled")
        T.eq(head.item, rows[1].item, "panel repainted")
        head:Click()
        rows = FlyoutRows()
        rows[#rows]:Click()
        T.eq(ns.Lists:Current().items[1], nil, "cleared")
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
        local edit = _G.GudaBiSRankFlyout.footer.edit
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

    T.case("MS defaults to the active tree's guide list; MS/OS buttons set and clear", function()
        local ns = H.Boot({ talentPoints = { 0, 40, 21 } })
        T.eq(ns.Lists:MainSpec().id, GUIDE, "default MS")
        T.eq(ns.Lists:OffSpec(), nil, "no OS")
        local custom = ns.Lists:CreateCustom("Heal gear")
        H.Slash("")
        ClickRole("ms")
        T.eq(ns.Lists:MainSpec().id, custom.id, "custom list is MS")
        ClickRole("os")
        T.eq(ns.Lists:OffSpec().id, custom.id, "now OS")
        T.eq(ns.Lists:MainSpec().id, GUIDE, "MS back to the default, a list cannot be both")
        ClickRole("os")
        T.eq(ns.Lists:OffSpec(), nil, "second click clears")
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
