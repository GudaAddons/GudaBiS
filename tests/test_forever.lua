-- M12: the WoW: Forever client loads its own TOC with wowtbc.gg's lists, whose phases
-- are level caps (GB-150-153): the bracket follows the character's level, a pick by
-- hand holds until the next bracket, chosen lists and roles carry across brackets, and
-- each faction gets its own lists. GudaBiS is a tab at the end of the Character
-- frame's mode tabs.

return function(T, H)
    local function Forever(opts)
        opts = opts or {}
        opts.client = "forever"
        return H.Boot(opts)
    end

    local function LevelUp(level)
        H.level = level
        H.Fire("PLAYER_LEVEL_UP", level)
    end

    T.case("Forever loads its own TOC and data, phases on", function()
        local ns = Forever()
        T.eq(H.toc, "GudaBiS_Camelot.toc", "Forever TOC")
        T.eq(ns.Expansion.ClientKey, "Forever", "client")
        T.eq(ns.Data.flavor, "Forever", "data")
        T.ok(ns.Features.HasPhases, "phases on")
        T.eq(table.concat(ns.Data:Phases(), ","), "20,30,40,50,60", "level caps")
        T.noErrors()
    end)

    T.case("the bracket follows the level and is labelled as a level", function()
        local ns = Forever({ level = 34 })
        T.eq(ns.Lists:Phase(), 40, "level 34 -> Level 40")
        T.eq(ns.Panel.PhaseLabel(40), "Level 40", "label")
        T.eq(ns.Lists:Current().id, "PALADIN_PROTECTION:40:Alliance", "Protection, Alliance")
        LevelUp(40)
        T.eq(ns.Lists:Phase(), 40, "a cap is its own bracket")
        LevelUp(70)
        T.eq(ns.Lists:Phase(), 60, "past the last cap")
        T.noErrors()
    end)

    T.case("the bracket is kept between level-ups: UnitLevel is not asked per loot line", function()
        local ns = Forever({ level = 34 })
        T.eq(ns.Lists:Phase(), 40, "worked out once")
        H.level = 55
        T.eq(ns.Lists:Phase(), 40, "kept until PLAYER_LEVEL_UP")
        H.Fire("PLAYER_LEVEL_UP", 55)
        T.eq(ns.Lists:Phase(), 60, "the event's level")
        T.noErrors()
    end)

    T.case("a pick by hand holds until the character levels into another bracket", function()
        local ns = Forever({ level = 34 })
        ns.Lists:SetPhase(20)
        T.eq(ns.Lists:Phase(), 20, "picked")
        LevelUp(39)
        T.eq(ns.Lists:Phase(), 20, "same bracket: still the pick")
        LevelUp(41)
        T.eq(ns.Lists:Phase(), 50, "next bracket: follows the level again")
        T.noErrors()
    end)

    T.case("the chosen list and MS/OS carry to the same lists in the next bracket", function()
        local ns = Forever({ level = 18, class = "DRUID", talentPoints = { 0, 31, 0 } })
        ns.Lists:Select("DRUID_FERAL_TANK:20:Alliance")
        ns.Lists:ToggleRole("ms", "DRUID_FERAL_TANK:20:Alliance")
        ns.Lists:ToggleRole("os", "DRUID_RESTORATION:20:Alliance")
        LevelUp(55)
        T.eq(ns.Lists:Current().id, "DRUID_FERAL_TANK:60:Alliance", "still Feral Tank")
        T.eq(ns.Lists:MainSpec().id, "DRUID_FERAL_TANK:60:Alliance", "MS in the new bracket")
        T.eq(ns.Lists:OffSpec().id, "DRUID_RESTORATION:60:Alliance", "OS in the new bracket")
        T.eq(ns.Lists:RoleOf("DRUID_FERAL_TANK:60:Alliance"), "ms", "labelled MS")
        T.noErrors()
    end)

    T.case("each faction sees its own lists only", function()
        local ns = Forever({ level = 60, faction = "Horde" })
        T.eq(ns.Lists:Current().id, "PALADIN_PROTECTION:60:Horde", "Horde list")
        for _, list in ipairs(ns.Data:ForClass("PALADIN", 60, "Horde")) do
            T.ok(list.faction == nil or list.faction == "Horde", "no Alliance list: " .. list.id)
        end
        T.noErrors()
    end)

    T.case("ring and trinket alternatives are written once and shared by the pair", function()
        local ns = Forever()
        local shared = 0
        for _, list in ipairs(ns.Data:All()) do
            if list.alts[11] and list.items[12] then
                T.ok(list.alts[12] == list.alts[11], "same table: " .. list.id)
                shared = shared + 1
            end
        end
        T.ok(shared > 0, "pairs with alternatives exist")
        T.noErrors()
    end)

    T.case("without C_SpecializationInfo answers, the talent tabs name the tree and pick the spec", function()
        local ns = Forever({ level = 60 })
        _G.C_SpecializationInfo.GetSpecializationInfo = function() return nil end
        local tabs = { { "Holy", 0 }, { "Protection", 31 }, { "Retribution", 5 } }
        _G.GetTalentTabInfo = function(i)
            local tab = tabs[i]
            if tab then return 800 + i, tab[1], "", 0, tab[2] end
        end
        T.eq(ns.Spec:TreeName(2), "Protection", "tree name from the talent tab")
        T.eq(ns.Spec:ActiveTree(), 2, "most points")
        _G.GetTalentTabInfo = function(i)
            local tab = tabs[i]
            if tab then return tab[1], 0, tab[2] end
        end
        T.eq(ns.Spec:ActiveTree(), 2, "older return order")
        T.noErrors()
    end)

    T.case("with no tree name from the client, the list is labelled with the data's tree name", function()
        local ns = Forever({ level = 60 })
        _G.C_SpecializationInfo.GetSpecializationInfo = function() return nil end
        _G.GetTalentTabInfo = nil
        local list = ns.Data:Get("PALADIN_PROTECTION:60:Alliance")
        T.eq(ns.Spec:TreeName(2), nil, "client gives none")
        T.eq(ns.Panel.ListLabel(list, ns.Spec:TreeName(2) or list.treeName), "Protection · BiS", "label")
        H.Slash("")
        T.noErrors()
    end)

    T.case("Holy comes before Shockadin on the first tab", function()
        local ns = Forever({ level = 60, talentPoints = { 31, 0, 20 } })
        T.eq(ns.Lists:Current().spec, "PALADIN_HOLY", "Holy first")
        local shockadin = false
        for _, list in ipairs(ns.Data:ForClass("PALADIN", 60, "Alliance")) do
            if list.spec == "PALADIN_SHOCKADIN" then shockadin = true end
        end
        T.ok(shockadin, "Shockadin offered")
        T.noErrors()
    end)

    -- Forever's Character frame: a column of mode tabs (CharacterFrame.ModeTabs.Tabs, also
    -- among its children, as in the client). AddTab adds another addon's tab anchored
    -- under `under`, as Overlord does.
    local function WithModeTabs(blizzardCount, right)
        local base = _G.CreateFrame
        _G.CreateFrame = function(kind, name, parent, template)
            local made = base(kind, name, parent, template)
            if template == "LargeSideTabButtonTemplate" then
                made.Icon = base("Frame")
                made.SetFillToInterior = function() end
                made.SetChecked = function(self, checked) self.checked = checked end
                made.SetCustomOnMouseUpHandler = function(self, fn) self.onMouseUp = fn end
                if parent and parent.children then parent.children[#parent.children + 1] = made end
            end
            return made
        end
        local host = base("Frame")
        host.Tabs, host.children = {}, {}
        for i = 1, blizzardCount do
            local blizzard = base("Frame")
            blizzard.shown = true
            blizzard.SetCustomOnMouseUpHandler = function() end
            if i > 1 then blizzard:SetPoint("TOPLEFT", host.Tabs[i - 1], "BOTTOMLEFT", 0, -2) end
            host.Tabs[i] = blizzard
            host.children[#host.children + 1] = blizzard
        end
        function host.AddTab(under)
            local other = base("Frame")
            other.shown = true
            other.SetCustomOnMouseUpHandler = function() end
            other:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -2)
            host.children[#host.children + 1] = other
            return other
        end
        host.GetChildren = function() return unpack(host.children) end
        host.GetRight = function() return right end
        _G.CharacterFrame.GetRight = function() return 384 end
        _G.CharacterFrame.ModeTabs = host
        return host
    end

    T.case("the GudaBiS tab is the last of the Character frame's mode tabs", function()
        local ns = Forever({ level = 60 })
        local host = WithModeTabs(3, 384)
        _G.CharacterFrame:Show()
        local tab = ns.Panel.tab
        T.ok(ns.Panel.tabIsMode, "a mode tab")
        T.eq(tab.tooltipText, ns.L.TOOLTIP_TOGGLE, "tooltip")
        T.eq(tab.point[2], host.Tabs[3], "under Blizzard's last tab")
        T.eq(tab.point[3], "BOTTOMLEFT", "below it")
        T.ok(not tab.checked, "closed")
        tab.onMouseUp(tab, "LeftButton", true)
        T.ok(ns.Panel:IsShown(), "click opens the panel")
        T.ok(tab.checked, "checked while open")
        T.eq(_G.GudaBiSPanel.point[2], _G.CharacterFrame, "docked")
        tab.onMouseUp(tab, "LeftButton", true)
        T.ok(not ns.Panel:IsShown(), "click closes it")
        T.ok(not tab.checked, "unchecked")
        T.noErrors()
    end)

    T.case("the GudaBiS tab goes under another addon's tab, placed again after OnShow", function()
        local ns = Forever({ level = 60 })
        local host = WithModeTabs(2, 420)
        ns.Database:SetSetting("panelOpen", true)
        _G.CharacterFrame:Show()
        local overlord = host.AddTab(host.Tabs[2])
        H.Advance(0.1)
        T.eq(ns.Panel.tab.point[2], overlord, "under Overlord's tab, added after our OnShow")
        T.eq(_G.GudaBiSPanel.point[4], 36, "panel placed again after the column (420 - 384)")
        T.noErrors()
    end)

    T.case("a tab another addon hung under ours is never followed: no anchor loop", function()
        local ns = Forever({ level = 60 })
        local host = WithModeTabs(2, 384)
        _G.CharacterFrame:Show()
        host.AddTab(ns.Panel.tab)
        H.Advance(0.1)
        T.eq(ns.Panel.tab.point[2], host.Tabs[2], "still under Blizzard's last tab")
        T.noErrors()
    end)

    T.case("without mode tabs the side tab stays", function()
        local ns = Forever({ level = 60 })
        _G.CharacterFrame:Show()
        T.ok(not ns.Panel.tabIsMode, "side tab")
        T.eq(ns.Panel.tab.point[3], "TOPRIGHT", "on the Character frame's edge")
        T.noErrors()
    end)

    T.case("the panel opens with a level dropdown and repaints on a level up", function()
        local ns = Forever({ level = 29 })
        H.Slash("")
        T.ok(ns.Panel:IsShown(), "panel")
        LevelUp(31)
        T.eq(ns.Lists:Phase(), 40, "next bracket")
        T.noErrors()
    end)

    T.case("other flavors do not listen for level-ups", function()
        H.Boot({ client = "tbc" })
        T.ok(not H.Registered("PLAYER_LEVEL_UP"), "TBC: no PLAYER_LEVEL_UP")
        Forever()
        T.ok(H.Registered("PLAYER_LEVEL_UP"), "Forever listens")
    end)
end
