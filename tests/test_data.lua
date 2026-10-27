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
            local phaseKey = list.anyPhase and "res" or tostring(list.phase)
            T.ok(list.anyPhase == nil or list.phase == nil, "anyPhase has no phase " .. id)
            T.ok(id:find("^" .. list.spec .. ":" .. phaseKey .. ":%d+$"), "id shape " .. id)
            T.ok(list.specID == nil or type(list.specID) == "number", "spec id " .. id)
            T.ok(type(list.tree) == "number" and type(list.class) == "string", "tree " .. id)
            T.ok(list.url == nil or list.url:find("^https://www%.wowhead%.com/"), "url " .. id)
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

    T.case("resistance lists join every phase, after the phase's own lists", function()
        local ns = H.Boot()
        local res = ns.Data:Get("WARRIOR_PROTECTION:res:1")
        T.ok(res and res.anyPhase and res.phase == nil, "resistance list registered")
        for _, phase in ipairs(ns.Data:Phases()) do
            T.ok(phase ~= nil, "no nil phase")
            local lists = ns.Data:ForSpec("WARRIOR_PROTECTION", phase, "Horde")
            T.eq(lists[#lists].anyPhase, true, "resistance last in phase " .. phase)
            for i = 2, #lists do
                T.ok(lists[i].anyPhase or not lists[i - 1].anyPhase, "phase lists first in phase " .. phase)
            end
            local found = false
            for _, list in ipairs(ns.Data:ForClass("WARRIOR", phase, "Horde")) do
                if list == res then found = true end
            end
            T.ok(found, "ForClass offers it in phase " .. phase)
        end
        T.eq(#ns.Data:ForClass("WARRIOR", 99, "Horde"), 0, "unknown phase stays empty")
    end)

    T.case("set names carry no parentheses", function()
        local ns = H.Boot()
        for _, list in ipairs(ns.Data:All()) do
            T.ok(not list.set:find("[()]"), "set name " .. list.id .. ": " .. list.set)
        end
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
