-- GB-005: /gbis probe writes a report to the log and never errors, whatever the
-- client lacks.

return function(T, H)
    local function LogHas(ns, pattern)
        for _, line in ipairs(ns.Log:Lines()) do
            if line:find(pattern, 1, true) then return true end
        end
        return false
    end

    for _, client in ipairs({ "era", "tbc", "mists", "retail", "forever" }) do
        T.case(client .. ": probe on a bare client writes every section without errors", function()
            local ns = H.Boot({ client = client })
            H.Slash("probe")
            T.ok(H.Printed("Probe written to the debug log", true), "done message")
            T.ok(ns.Log.frame and ns.Log.frame:IsShown(), "log window opened")
            T.ok(LogHas(ns, "client " .. ns.Expansion.ClientKey), "client line")
            T.ok(LogHas(ns, "global functions missing:"), "globals line")
            T.ok(LogHas(ns, "events: C_EventUtils.IsEventValid MISSING"), "events line")
            T.ok(LogHas(ns, "GetLootMethod() = MISSING"), "loot line")
            T.ok(LogHas(ns, "GroupLootFrame4: no"), "loot frames")
            T.ok(LogHas(ns, "GetTalentTabInfo(3) = MISSING"), "spec lines")
            T.ok(LogHas(ns, "addons: GudaBags=no"), "addons line")
            T.noErrors()
        end)
    end

    T.case("probe reports values, errors and invalid events", function()
        local ns = H.Boot()
        _G.GetLootMethod = function() return "master", 1, nil end
        _G.IsMasterLooter = function() error("nope") end
        _G.C_EventUtils = { IsEventValid = function(event) return event ~= "OPEN_MASTER_LOOT_LIST" end }
        _G.C_SpecializationInfo = { GetSpecializationInfo = function(i) return 100 + i, "Tree" .. i, "", 1, "DAMAGER", 1, 31 end }
        _G.GroupLootFrame1 = { LootButtonContainer = { NeedButton = {} } }
        H.Slash("probe")
        T.ok(LogHas(ns, "GetLootMethod() = master, 1, nil"), "values")
        T.ok(LogHas(ns, "IsMasterLooter() = error:"), "error caught")
        T.ok(LogHas(ns, "events not valid: OPEN_MASTER_LOOT_LIST"), "invalid event")
        T.ok(LogHas(ns, "GetSpecializationInfo(1) = 101, Tree1, , 1, DAMAGER, 1, 31"), "spec info")
        T.ok(LogHas(ns, "GroupLootFrame1: yes · .NeedButton no · .LootButtonContainer.NeedButton yes · resolved yes"), "nested button")
        _G.GetLootMethod, _G.IsMasterLooter, _G.C_EventUtils, _G.C_SpecializationInfo = nil, nil, nil, nil
        T.noErrors()
    end)

    T.case("running probe twice does not reopen-close the log", function()
        local ns = H.Boot()
        H.Slash("probe")
        H.Slash("probe")
        T.ok(ns.Log.frame:IsShown(), "still shown")
    end)
end
