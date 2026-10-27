-- GB-012: the generated data registers once, has a sane shape, and the registry
-- answers by id, spec, phase and faction.

return function(T, H)
    local PAIRS = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

    T.case("TBC data registers with lists, specs and a default phase", function()
        local ns = H.Boot()
        T.eq(ns.Data.flavor, "TBC", "flavor")
        T.eq(ns.Data.source, "Wowhead", "source")
        T.ok(ns.Data:Count() > 0, "lists")
        T.ok(#ns.Data:Specs() > 0, "specs")
        local hasDefault = false
        for _, phase in ipairs(ns.Data:Phases()) do
            if phase == ns.Data.defaultPhase then hasDefault = true end
        end
        T.ok(hasDefault, "default phase has data")
        T.noErrors()
    end)

    T.case("every list is well formed", function()
        local ns = H.Boot()
        local ids = {}
        for _, spec in ipairs(ns.Data:Specs()) do
            for _, phase in ipairs(ns.Data:Phases()) do
                for _, faction in ipairs({ "Alliance", "Horde" }) do
                    for _, list in ipairs(ns.Data:ForSpec(spec, phase, faction)) do
                        ids[list.id] = list
                    end
                end
            end
        end
        local count = 0
        for id, list in pairs(ids) do
            count = count + 1
            T.eq(ns.Data:Get(id), list, "Get " .. id)
            T.ok(id:find("^" .. list.spec .. ":" .. list.phase .. ":%d+$"), "id shape " .. id)
            T.ok(type(list.specID) == "number" and type(list.tree) == "number", "spec ids " .. id)
            T.ok(list.url:find("^https://www%.wowhead%.com/"), "url " .. id)
            T.ok(list.faction == nil or list.faction == "Horde" or list.faction == "Alliance", "faction " .. id)
            local slots = 0
            for slot, item in pairs(list.items) do
                slots = slots + 1
                T.ok(slot >= 1 and slot <= 19 and item > 0, id .. " slot " .. slot)
            end
            T.ok(slots >= 10, id .. " has a full set")
            for slot, gems in pairs(list.gems or {}) do
                T.ok(list.items[slot] ~= nil and #gems >= 1, id .. " gems on an empty slot " .. slot)
            end
            for slot in pairs(list.enchants or {}) do
                T.ok(list.items[slot] ~= nil, id .. " enchant on an empty slot " .. slot)
            end
            for slot, alts in pairs(list.alts or {}) do
                for _, item in ipairs(alts) do
                    T.ok(item ~= list.items[slot], id .. " alt repeats #1 in slot " .. slot)
                    T.ok(PAIRS[slot] == nil or item ~= list.items[PAIRS[slot]], id .. " alt repeats the paired slot " .. slot)
                end
            end
        end
        T.eq(count, ns.Data:Count(), "every list reachable through ForSpec")
    end)

    T.case("ForSpec filters by faction and keeps tab order", function()
        local ns = H.Boot()
        local alliance = ns.Data:ForSpec("PALADIN_PROTECTION", 4, "Alliance")
        local horde = ns.Data:ForSpec("PALADIN_PROTECTION", 4, "Horde")
        T.eq(alliance[1].set, "Balanced set", "first tab first")
        for _, list in ipairs(alliance) do T.ok(list.faction ~= "Horde", "no Horde list for Alliance") end
        for _, list in ipairs(horde) do T.ok(list.faction ~= "Alliance", "no Alliance list for Horde") end
        T.eq(#ns.Data:ForSpec("PALADIN_PROTECTION", 99, "Horde"), 0, "unknown phase")
        T.eq(#ns.Data:ForSpec("NOPE", 4, "Horde"), 0, "unknown spec")
    end)

    T.case("a second flavor cannot register", function()
        local ns = H.Boot()
        local ok = pcall(ns.Data.Register, ns.Data, { flavor = "Era", lists = {} })
        T.ok(not ok, "refused")
    end)

    T.case("/gbis status shows the data line", function()
        H.Boot()
        H.Slash("status")
        T.ok(H.Printed("BiS data: TBC", true), "data line")
    end)
end
