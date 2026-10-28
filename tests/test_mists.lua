-- GB-140/141: MoP Classic loads GudaBiS_Mists.toc with WoWSims' Pre-Raid and BiS sets
-- (and, once built, the top raiders of each phase): the chosen specialization picks the
-- list, reforges show in the tooltip, item levels give yellow checks and upgrade
-- alerts, no ranged slot, Classic art with Blizzard's own dropdowns.

return function(T, H)
    local function Mists()
        local ns = H.Boot({ client = "mists" })
        _G.C_SpecializationInfo.GetSpecialization = function() return 3 end
        return ns
    end

    local function LevelLink(itemID, level)
        return "|cffa335ee|Hitem:" .. itemID .. "::::::::90|h[lvl" .. level .. "]|h|r"
    end

    T.case("MoP loads its own TOC and data, Pre-Raid first", function()
        local ns = Mists()
        T.eq(H.toc, "GudaBiS_Mists.toc", "Mists TOC")
        T.eq(ns.Expansion.ClientKey, "Mists", "client")
        T.eq(table.concat(ns.Data:Phases(), ","), "1,2,3,4,5", "phases")
        T.eq(ns.Lists:Phase(), 5, "Phase 5 by default")
        T.eq(ns.Panel.PhaseLabel(1), "Pre-Raid", "Pre-Raid")
        T.eq(ns.Panel.PhaseLabel(2), "Phase 1-2", "label from the data")
        T.noErrors()
    end)

    T.case("the chosen specialization picks WoWSims' BiS", function()
        local ns = Mists()
        local list = ns.Lists:Current()
        T.eq(list.spec, "PALADIN_RETRIBUTION", "spec 3: Retribution")
        T.eq(list.set, "BiS", "the plain BiS set first")
        T.eq(list.author, "WoWSims", "credited")
        T.ok(ns.Panel.ListLabel(list, "Retribution"):find("WoWSims", 1, true), "label names WoWSims")
        T.eq(list.items[18], nil, "no ranged slot")
        T.ok(next(list.gems) ~= nil, "gems")
        _G.C_SpecializationInfo.GetSpecialization = function() return 2 end
        T.eq(ns.Lists:Current().spec, "PALADIN_PROTECTION", "spec 2: Protection")
        T.noErrors()
    end)

    T.case("reforges read with the client's stat names", function()
        local ns = Mists()
        local list = { reforges = { [1] = { "SPIRIT", "HIT_RATING" } } }
        _G.ITEM_MOD_SPIRIT_SHORT, _G.ITEM_MOD_HIT_RATING_SHORT = "Spirit", "Hit"
        T.eq(ns.Panel.ReforgeText(list, 1), "Reforge: Spirit → Hit", "named")
        _G.ITEM_MOD_HIT_RATING_SHORT = nil
        T.eq(ns.Panel.ReforgeText(list, 1), "Reforge: Spirit → HIT_RATING", "raw name when the client has none")
        T.eq(ns.Panel.ReforgeText(list, 2), nil, "no reforge")
        local reforged = 0
        for _, data in ipairs(ns.Data:All()) do
            if data.reforges and next(data.reforges) then reforged = reforged + 1 end
        end
        T.ok(reforged > 0, "WoWSims lists carry reforges")
        _G.ITEM_MOD_SPIRIT_SHORT = nil
        T.noErrors()
    end)

    T.case("item levels: lower copy is yellow, a higher drop is an upgrade", function()
        local ns = Mists()
        ns.GetDetailedItemLevelInfo = function(link)
            return tonumber(type(link) == "string" and link:match("lvl(%d+)"))
        end
        local head = ns.Lists:Current().items[1]
        local list = { items = { [1] = head }, itemLevels = { [head] = 580 } }
        H.equipped[1] = head
        H.links[1] = LevelLink(head, 572)
        H.Fire("PLAYER_EQUIPMENT_CHANGED")
        T.eq(ns.Owned:LevelState(list, head), "lower", "yellow")
        local match = ns.Match:Item(head, nil, LevelLink(head, 580))
        T.ok(match and match.upgrade, "an upgrade alert")
        T.noErrors()
    end)

    T.case("Classic art with Blizzard's own dropdowns", function()
        local ns = Mists()
        H.Slash("")
        T.ok(not ns.Features.HasRetailFrameArt, "Classic art")
        T.ok(ns.Panel.listDropdown.native ~= nil, "native dropdown")
        T.eq(#ns.Panel.WeaponSlots(), 2, "main hand and off hand only")
        T.noErrors()
    end)
end
