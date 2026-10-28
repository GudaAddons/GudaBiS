-- GB-080/081: settings paths, the options page, the minimap button.

return function(T, H)
    local function BootWithUI(opts)
        H.Install(opts)
        H.categories, H.opened = {}, {}
        _G.Settings = {
            RegisterCanvasLayoutCategory = function(frame, name)
                local category = { ID = #H.categories + 1, frame = frame, name = name }
                H.categories[#H.categories + 1] = category
                return category
            end,
            RegisterAddOnCategory = function() end,
            OpenToCategory = function(id) H.opened[#H.opened + 1] = id end,
        }
        _G.Minimap = CreateFrame("Frame", "Minimap")
        local ns = H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        H.Fire("PLAYER_LOGIN")
        H.Fire("PLAYER_ENTERING_WORLD", true, false)
        return ns
    end

    T.case("settings by path: read, write, change event, missing paths ignored", function()
        local ns = H.Boot()
        local D = ns.Database
        T.eq(D:GetSetting("alerts.sound"), true, "nested default")
        T.eq(D:GetSetting("minimap.angle"), 200, "minimap default")
        local seen
        ns.Events:Register("GBIS_SETTING_CHANGED", function(_, path, value) seen = path .. "=" .. tostring(value) end, "test")
        D:SetSetting("alerts.sound", false)
        T.eq(ns.db.settings.alerts.sound, false, "written")
        T.eq(seen, "alerts.sound=false", "event")
        D:SetSetting("nothing.here", 1)
        T.eq(D:GetSetting("nothing.here"), nil, "missing path")
        D:SetSetting("debug", true)
        T.eq(D:GetSetting("debug"), true, "flat keys still work")
    end)

    T.case("options: Get/Set, inverted minimap option, auto-roll unavailable with Gargul", function()
        local ns = H.Boot({ addons = { Gargul = true } })
        local S = ns.SettingsPanel
        local minimap = S.Option("minimap")
        T.eq(S.Get(minimap), true, "shown by default")
        S.Set(minimap, false)
        T.eq(ns.db.settings.minimap.hidden, true, "hidden stored inverted")
        local autoRoll = S.Option("autoRoll")
        T.ok(not S.Available(autoRoll), "unavailable while Gargul is loaded")
        T.eq(S.Set(autoRoll, true), false, "cannot be switched on")
        T.eq(ns.db.settings.autoRoll, false, "still off")
        T.eq(S.Get(S.Option("alerts")), true, "alerts on")
    end)

    T.case("options page: registered at login, built on first show, /gbis options opens it", function()
        local ns = BootWithUI()
        T.eq(#H.categories, 1, "one category")
        T.eq(H.categories[1].name, "GudaBiS", "named")
        local page = _G.GudaBiSSettingsPanel
        T.eq(#page.children, 0, "nothing built at login")
        page:Show()
        T.ok(#page.children > 10, "built on show")
        H.Slash("options")
        T.eq(H.opened[1], 1, "opened to our category")
        T.noErrors()
    end)

    T.case("minimap button: shown by default, /gbis minimap hides and shows it", function()
        local ns = BootWithUI()
        local button = _G.GudaBiSMinimapButton
        T.ok(button and button:IsShown(), "shown")
        H.Slash("minimap")
        T.ok(not button:IsShown(), "hidden")
        T.eq(ns.db.settings.minimap.hidden, true, "saved")
        T.ok(H.Printed("Minimap button hidden", true), "message")
        H.Slash("minimap")
        T.ok(button:IsShown(), "back")
        T.noErrors()
    end)

    T.case("minimap button: left-click toggles the panel, right-click opens settings", function()
        local ns = BootWithUI()
        local button = _G.GudaBiSMinimapButton
        button:Script("OnClick", "LeftButton")
        T.ok(ns.Panel:IsShown(), "panel open")
        button:Script("OnClick", "LeftButton")
        T.ok(not ns.Panel:IsShown(), "panel closed")
        button:Script("OnClick", "RightButton")
        T.eq(#H.opened, 1, "settings opened")
        T.noErrors()
    end)

    T.case("minimap button: hidden setting means it is never built", function()
        local saved = { settings = { minimap = { angle = 10, hidden = true } } }
        H.Install({ saved = saved })
        _G.Minimap = CreateFrame("Frame", "Minimap")
        H.Load()
        H.Fire("ADDON_LOADED", "GudaBiS")
        T.eq(_G.GudaBiSMinimapButton, nil, "not built")
    end)

    T.case("Offset: angle to a point on the minimap edge", function()
        local M = H.Boot().MinimapButton
        local x, y = M.Offset(0, 80)
        T.eq(x, 80, "east x")
        T.ok(math.abs(y) < 1e-9, "east y")
        x, y = M.Offset(90, 80)
        T.ok(math.abs(x) < 1e-9 and math.abs(y - 80) < 1e-9, "north")
    end)
end
