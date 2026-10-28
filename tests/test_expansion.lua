-- GB-002: client detection, feature flags and API resolution on every client.

return function(T, H)
    local EXPECTED = {
        era = { key = "Era", HasGems = false, HasMasterLoot = true, HasPhases = true, HasSpecChoice = false, ChatLockdown = false, ItemLevelMatters = false, HasWarbandBank = false, RealmlessNames = false, HasRangedSlot = true },
        tbc = { key = "TBC", HasGems = true, HasMasterLoot = true, HasPhases = true, HasSpecChoice = false, ChatLockdown = false, ItemLevelMatters = false, HasWarbandBank = false, RealmlessNames = false, HasRangedSlot = true },
        mists = { key = "Mists", HasGems = true, HasMasterLoot = true, HasPhases = true, HasSpecChoice = true, ChatLockdown = false, ItemLevelMatters = false, HasWarbandBank = false, RealmlessNames = false, HasRangedSlot = false },
        retail = { key = "Retail", HasGems = true, HasMasterLoot = false, HasPhases = false, HasSpecChoice = true, ChatLockdown = true, ItemLevelMatters = true, HasWarbandBank = true, RealmlessNames = false, HasRangedSlot = false },
        forever = { key = "Forever", HasGems = false, HasMasterLoot = false, HasPhases = false, HasSpecChoice = false, ChatLockdown = true, ItemLevelMatters = false, HasWarbandBank = true, RealmlessNames = true, HasRangedSlot = true },
    }

    for client, want in pairs(EXPECTED) do
        T.case(client .. ": client key and every feature flag", function()
            local ns = H.Boot({ client = client })
            T.eq(ns.Expansion.ClientKey, want.key, "ClientKey")
            for _, name in ipairs(ns.Expansion.FeatureNames) do
                T.ok(want[name] ~= nil, "test covers " .. name)
                T.eq(ns.Features[name], want[name], client .. " " .. name)
            end
            T.noErrors()
        end)
    end

    T.case("Forever reporting the Classic project ID is still Forever", function()
        local ns = H.Boot({ client = { iface = 16001, project = 2 } })
        T.eq(ns.Expansion.ClientKey, "Forever", "ClientKey")
        T.ok(not ns.Expansion.IsEra, "not Era")
    end)

    T.case("unknown project ID falls back to the interface range", function()
        local ns = H.Boot({ client = { iface = 20506, project = 999 } })
        T.eq(ns.Expansion.ClientKey, "TBC", "ClientKey")
    end)

    T.case("Classic flavors resolve the globals, modern clients the namespace", function()
        local ns = H.Boot({ client = "tbc" })
        T.eq(ns.Compat.resolvedSource.GetItemInfo, "global", "tbc GetItemInfo")
        T.eq(ns.Compat.resolvedSource.GetDetailedItemLevelInfo, "namespace", "tbc ilvl")
        ns = H.Boot({ client = "forever" })
        for _, name in ipairs(ns.Compat.resolvedNames) do
            T.eq(ns.Compat.resolvedSource[name], "namespace", "forever " .. name)
            T.ok(ns[name] ~= nil, "exported " .. name)
        end
    end)

    T.case("Need button: flat on Classic/Retail, nested on Forever, nil when absent", function()
        local ns = H.Boot({ client = "tbc" })
        local flat, nested = {}, {}
        _G.GroupLootFrame1 = { NeedButton = flat }
        _G.GroupLootFrame2 = { LootButtonContainer = { NeedButton = nested } }
        _G.GroupLootFrame3 = {}
        T.eq(ns.Compat.GetGroupLootNeedButton(1), flat, "flat")
        T.eq(ns.Compat.GetGroupLootNeedButton(2), nested, "nested")
        T.eq(ns.Compat.GetGroupLootNeedButton(3), nil, "no button")
        T.eq(ns.Compat.GetGroupLootNeedButton(4), nil, "no frame")
    end)

    T.case("/gbis status prints client, flags, API and database", function()
        H.Boot({ client = "tbc" })
        H.Slash("status")
        T.ok(H.Printed("Client: TBC (interface 20506)", true), "client line")
        T.ok(H.Printed("HasGems=Yes", true), "flags line")
        T.ok(H.Printed("GetItemInfo=global", true), "api line")
        T.ok(H.Printed("Database: schema 1", true), "db line")
        T.noErrors()
    end)
end
