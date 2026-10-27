-- GB-003: GudaBiS_DB defaults, reload, character keys.

return function(T, H)
    T.case("fresh install gets every default", function()
        local ns = H.Boot()
        local db = _G.GudaBiS_DB
        T.eq(ns.db, db, "ns.db is the SavedVariable")
        T.eq(db.schema, 1, "schema")
        T.eq(db.meta.loadCount, 1, "loads")
        T.eq(db.settings.debug, false, "debug default")
        T.eq(type(db.chars), "table", "chars")
        T.eq(ns.Database.restoredFromDisk, false, "not from disk")
        T.noErrors()
    end)

    T.case("reload keeps saved values and fills what is missing", function()
        local saved = { schema = 1, meta = { loadCount = 4 }, settings = { debug = true }, chars = { ["Old-Realm"] = { y = 2 } } }
        local ns = H.Boot({ saved = saved })
        T.eq(ns.db.meta.loadCount, 5, "load count")
        T.eq(ns.debugMode, true, "debug restored")
        T.eq(ns.db.chars["Old-Realm"].y, 2, "character kept")
        T.eq(ns.Database.restoredFromDisk, true, "from disk")
    end)

    T.case("a corrupt table is replaced by its default", function()
        local ns = H.Boot({ saved = { meta = "broken", settings = 5 } })
        T.eq(type(ns.db.meta), "table", "meta")
        T.eq(ns.db.meta.loadCount, 1, "load count restarts")
        T.eq(ns.db.settings.debug, false, "settings")
        T.noErrors()
    end)

    T.case("a database without schema gets the current one", function()
        local ns = H.Boot({ saved = { settings = {} } })
        T.eq(ns.db.schema, ns.Database.SCHEMA_VERSION, "schema")
    end)

    T.case("character key: Name-Realm without spaces", function()
        local ns = H.Boot()
        T.eq(ns.Database:PlayerKey(), "Vati-Spineshatter", "normalized realm")
        ns = H.Boot({ normalizedRealm = false })
        T.eq(ns.Database:PlayerKey(), "Vati-ThunderFury", "realm name without spaces")
    end)

    T.case("character key on Forever: realmless Given Family", function()
        local ns = H.Boot({ client = "forever" })
        T.eq(ns.Database:PlayerKey(), "Vati Guda", "key")
    end)

    T.case("Char() creates this character's table once", function()
        local ns = H.Boot()
        local char = ns.Database:Char()
        char.x = 1
        T.eq(ns.Database:Char(), char, "same table")
        T.eq(_G.GudaBiS_DB.chars["Vati-Spineshatter"].x, 1, "stored under the key")
        T.eq(ns.Database:CountCharacters(), 1, "count")
    end)

    T.case("no player name yet: no key, no character table", function()
        local ns = H.Boot({ playerName = "Unknown" })
        T.eq(ns.Database:PlayerKey(), nil, "key")
        T.eq(ns.Database:Char(), nil, "char")
        T.eq(ns.Database:CountCharacters(), 0, "nothing created")
    end)
end
