-- M13: the Retail client loads GudaBiS_Mainline.toc with its generated top-player lists
-- (Data/Mainline, GB-131): the panel, its tabs, custom lists, the wishlist, settings and
-- the minimap button.

return function(T, H)
    local TOP_ID = "PALADIN_PROTECTION:mplus"

    -- The harness player is a paladin; Protection is the picked spec.
    local function Retail()
        local ns = H.Boot({ client = "retail" })
        _G.C_SpecializationInfo.GetSpecialization = function() return 2 end
        return ns
    end

    T.case("Retail loads its own TOC and one top-player list per spec", function()
        local ns = Retail()
        T.eq(H.toc, "GudaBiS_Mainline.toc", "Mainline TOC")
        T.eq(ns.Expansion.ClientKey, "Retail", "client")
        T.eq(ns.Data.flavor, "Retail", "Retail data")
        T.eq(ns.Data:Count(), 40, "40 specs")
        T.eq(#ns.Data:Phases(), 0, "no phases")
        T.ok(not ns.Features.HasPhases, "no phase feature")
        for _, list in ipairs(ns.Data:All()) do
            T.eq(list.players, 50, list.id .. " from 50 players")
            T.ok(list.usage and list.usage[1], list.id .. " has usage")
        end
        T.noErrors()
    end)

    T.case("Retail panel: no phase dropdown, the spec's list, every tab opens", function()
        local ns = Retail()
        H.Slash("")
        T.ok(ns.Panel:IsShown(), "panel")
        T.ok(not ns.Panel.phaseDropdown.button:IsShown(), "no phase dropdown")
        T.eq(ns.Lists:Current().id, TOP_ID, "Protection's list")
        T.ok(not _G.GudaBiSPanel.emptyNote:IsShown(), "no empty note")
        H.Slash("wishlist")
        T.ok(_G.GudaBiSWishlistView:IsShown(), "wishlist tab")
        H.Slash("history")
        T.ok(_G.GudaBiSHistoryView:IsShown(), "history tab")
        ns.Panel:ShowTab("gear")
        T.noErrors()
    end)

    T.case("Retail custom lists, wishlist alerts and settings", function()
        local ns = Retail()
        H.Slash("")
        local list = ns.Lists:CreateCustom("Mine")
        ns.Lists:SetSlot(list.id, 1, 32521)
        ns.Panel:Refresh()
        T.eq(ns.Lists:Current().id, list.id, "custom list shown")
        ns.Lists:ToggleRole("ms", list.id)
        T.eq(ns.Match:Item(32521).role, "ms", "matches")
        ns.Wishlist:Add(28000)
        T.eq(ns.Match:Item(28000).role, "wish", "wishlist")
        H.Slash("options")
        H.Slash("status")
        T.noErrors()
    end)

    T.case("Adventure Guide: shields on loot rows once the guide loads, source saved", function()
        local ns = Retail()
        local callback
        _G.ScrollUtil = { AddInitializedFrameCallback = function(_, fn) callback = fn end }
        _G.EncounterJournal = { encounterID = 7, encounter = { info = { LootContainer = { ScrollBox = {} } } } }
        _G.EJ_GetInstanceInfo = function() return "Windrunner Spire" end
        _G.EJ_GetEncounterInfo = function(id) return id == 7 and "Emberdawn" or nil end
        _G.C_EncounterJournal = { GetLootInfoByIndex = function(i) return { itemID = 250000 + i } end }
        T.eq(callback, nil, "nothing before the guide loads")
        H.Fire("ADDON_LOADED", "Blizzard_EncounterJournal")
        T.ok(callback ~= nil, "hooked when it loads")
        local row = CreateFrame("Button")
        row.itemID = false
        callback(row, { index = 3 })
        local shield = row.gudaBiSWish
        T.ok(shield and shield:IsShown(), "shield on the row")
        T.eq(shield.itemID, 250003, "item from the loot index")
        shield:Click()
        T.eq(ns.Wishlist.SourceText(ns.Wishlist:Items()[1]), "Windrunner Spire · Emberdawn", "source")
        local header = CreateFrame("Button")
        header.itemID = false
        _G.C_EncounterJournal.GetLootInfoByIndex = function() return nil end
        callback(header, { index = 9 })
        T.eq(header.gudaBiSWish, nil, "no shield without an item")
        _G.ScrollUtil, _G.EncounterJournal, _G.C_EncounterJournal = nil, nil, nil
        _G.EJ_GetInstanceInfo, _G.EJ_GetEncounterInfo = nil, nil
        T.noErrors()
    end)

    -- A top-player list the way tools/topplayers writes it.
    local TOP_LIST = {
        id = "PALADIN_PROTECTION:mplus", spec = "PALADIN_PROTECTION", class = "PALADIN", specID = 66, tree = 2,
        anyPhase = true, set = "Top 50 M+", season = "Midnight Season 2", players = 50,
        items = { [1] = 271483, [5] = 271480 }, alts = { [1] = { 271500, 271501 } },
        usage = { [1] = { 38, 7, 5 }, [5] = { 41 } },
        enchantIDs = { [5] = 8017 }, enchantNames = { [5] = "Enchant Chest - Crystalline Radiance" },
    }

    T.case("top-player lists: the picked spec's list, season label, usage", function()
        local ns = Retail()
        T.eq(ns.Spec:ActiveTree(), 2, "the picked spec, not the most points")
        local list = ns.Lists:Current()
        T.eq(list and list.id, TOP_ID, "shown with no phase")
        T.eq(ns.Panel.ListLabel(list, "Protection"),
            "Protection · Top 50 M+  |cff808080" .. list.season .. "|r", "label with the season")
        local count = list.usage[1][1]
        T.eq(ns.Panel.UsageText(list, 1, 1), "Worn by " .. count .. " of the top 50 players", "#1")
        T.eq(ns.Panel.UsageText(list, 4, 1), nil, "nothing for the shirt slot")
        local slot, alts = next(list.alts)
        T.eq(ns.Match:Item(alts[1]).rank, 2, "alternatives match")
        T.ok(ns.Panel.UsageText(list, slot, 2) ~= nil, "alternatives have a count")
        T.noErrors()
    end)

    T.case("generated enchant names carry no colour codes", function()
        local ns = Retail()
        for _, list in ipairs(ns.Data:All()) do
            for slot, name in pairs(list.enchantNames or {}) do
                T.ok(not name:find("|c", 1, true), list.id .. " slot " .. slot)
                T.ok(list.enchantIDs[slot] ~= nil, list.id .. " named enchant has an ID")
            end
        end
    end)

    T.case("top-player lists: enchants by ID, missing and wrong told apart", function()
        local ns = Retail()
        local E = ns.Enchants
        local function Link(enchant) return "|cffa335ee|Hitem:271480:" .. enchant .. ":::::::80|h[x]|h|r" end
        local state = E.Check(TOP_LIST, 5, Link(8017))
        T.ok(not state.missingEnchant and not state.wrongEnchant, "the right enchant")
        state = E.Check(TOP_LIST, 5, Link(0))
        T.ok(state.missingEnchant and not state.wrongEnchant, "missing")
        state = E.Check(TOP_LIST, 5, Link(7999))
        T.ok(state.wrongEnchant and not state.missingEnchant, "a different enchant")
        T.ok(not E.Check(TOP_LIST, 1, Link(0)).missingEnchant, "no enchant wanted on the head")
    end)

    -- Item links carry their item level as "lvlNNN" in the name here; the stub reads it.
    local function LevelLink(itemID, level)
        return "|cffa335ee|Hitem:" .. itemID .. "::::::::80|h[lvl" .. level .. "]|h|r"
    end

    local function WithLevels(ns)
        ns.GetDetailedItemLevelInfo = function(link)
            return tonumber(type(link) == "string" and link:match("lvl(%d+)"))
        end
    end

    local function SlotButton(slot)
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "slot") == slot and rawget(frame, "icon") and rawget(frame, "enchant") then return frame end
        end
    end

    T.case("item levels: yellow check below the top players' level, green at it", function()
        local ns = Retail()
        WithLevels(ns)
        local list = ns.Data:Get(TOP_ID)
        local head, target = list.items[1], list.itemLevels[list.items[1]]
        T.ok(target ~= nil, "the list knows the head's top level")
        H.equipped[1] = head
        H.links[1] = LevelLink(head, target - 14)
        H.Fire("PLAYER_EQUIPMENT_CHANGED")
        H.Slash("")
        local button = SlotButton(1)
        T.ok(button.check:IsShown(), "checked")
        T.eq(button.check.vertexColor[2], 0.82, "yellow")
        button:Enter()
        local found
        for _, line in ipairs(_G.GameTooltip.lines) do
            if line == string.format("Item level %d, top players %d", target - 14, target) then found = true end
        end
        T.ok(found, "tooltip compares the levels")
        H.links[1] = LevelLink(head, target)
        ns.Panel:Refresh()
        T.eq(button.check.vertexColor[2], 1, "white-green at the top level")
        T.eq(ns.Owned.LevelStatus(330, 334), "lower", "pure: lower")
        T.eq(ns.Owned.LevelStatus(334, 334), "full", "pure: full")
        T.eq(ns.Owned.LevelStatus(nil, 334), nil, "pure: unknown")
        T.noErrors()
    end)

    T.case("item levels: a bag copy is read where it sits; the ranked list turns yellow too", function()
        local ns = Retail()
        local list = ns.Data:Get(TOP_ID)
        local head, target = list.items[1], list.itemLevels[list.items[1]]
        ns.GetDetailedItemLevelInfo = function() return nil end
        _G.ItemLocation = {
            CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end,
            CreateFromEquipmentSlot = function(_, slot) return { equip = slot } end,
        }
        _G.C_Item.GetCurrentItemLevel = function(location)
            return location.bag == 0 and location.slot == 2 and 259 or nil
        end
        H.containers[0] = { false, head }
        H.Fire("BAG_UPDATE_DELAYED")
        T.eq(ns.Owned:BestLevel(head), 259, "read from the bag slot, no cached link needed")
        T.eq(ns.Owned:LevelState(list, head), "lower", "259 under " .. target)
        H.Slash("")
        local button = SlotButton(1)
        T.eq(button.check.vertexColor[2], 0.82, "yellow in the panel")
        button:Click()
        local row
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "rank") and frame:IsShown() and rawget(frame, "id") == head then row = frame end
        end
        T.ok(row ~= nil, "the item in the ranked list")
        T.eq(row.check.vertexColor[2], 0.82, "yellow there too")
        _G.ItemLocation = nil
        _G.C_Item.GetCurrentItemLevel = nil
        T.noErrors()
    end)

    T.case("item levels: an owned item alerts again only as an upgrade; auto-roll stays out", function()
        local ns = Retail()
        WithLevels(ns)
        local head = ns.Data:Get(TOP_ID).items[1]
        H.equipped[1] = head
        H.links[1] = LevelLink(head, 320)
        H.Fire("PLAYER_EQUIPMENT_CHANGED")
        T.eq(ns.Match:Item(head), nil, "no link, no alert for an owned item")
        T.eq(ns.Match:Item(head, nil, LevelLink(head, 320)), nil, "same level: silent")
        T.eq(ns.Match:Item(head, nil, LevelLink(head, 310)), nil, "lower: silent")
        local match = ns.Match:Item(head, nil, LevelLink(head, 334))
        T.ok(match and match.upgrade, "higher: an upgrade")
        T.eq(ns.Match.Label(match), "BiS upgrade 320→334", "label")
        H.Slash("autoroll on")
        T.eq(ns.AutoRoll:GroupLoot(1, LevelLink(head, 334), match), false, "never auto-rolled")
        T.noErrors()
    end)

    T.case("no ranged slot on Retail; TBC keeps it", function()
        local ns = Retail()
        H.Slash("")
        T.eq(#ns.Panel.WeaponSlots(), 2, "main and off hand")
        T.eq(SlotButton(18), nil, "no ranged slot button")
        local tbc = H.Boot()
        H.Slash("")
        T.eq(#tbc.Panel.WeaponSlots(), 3, "TBC has the ranged slot")
        T.ok(SlotButton(18) ~= nil, "and its button")
    end)

    -- Stand-ins for Retail's art APIs: what was applied is recorded on the frames.
    local function RetailArtStubs()
        _G.NineSliceUtil = { ApplyLayoutByName = function(frame, layout) frame.layout = layout end }
        _G.C_Texture = { GetAtlasInfo = function(name) return name == "common-dropdown-a-button" and {} or nil end }
        _G.ButtonFrameTemplate_HidePortrait = function(frame) frame.portraitHidden = true end
        _G.ButtonFrameTemplate_HideButtonBar = function(frame) frame.buttonBarHidden = true end
    end

    T.case("Retail art: the panel, dropdowns, dialogs and popups use Retail's look", function()
        local ns = Retail()
        RetailArtStubs()
        T.ok(ns.Features.HasRetailFrameArt, "flag")
        H.Slash("")
        local panel = _G.GudaBiSPanel
        T.ok(panel.portraitHidden and panel.buttonBarHidden, "ButtonFrameTemplate, portrait and button bar hidden")
        T.ok(ns.Panel.listDropdown.native ~= nil, "dropdowns are Retail's own widget")
        local flyout = ns.Theme.Popup("Frame", nil, UIParent)
        T.eq(flyout.retailBorder.layout, "TooltipDefaultLayout", "popups: tooltip border")
        local dialog = ns.Theme.Dialog(nil, UIParent)
        T.eq(dialog.retailBorder.layout, "Dialog", "dialogs: dialog border")
        T.noErrors()
    end)

    T.case("Retail art stays off on TBC, and without the APIs on Retail", function()
        local tbc = H.Boot()
        RetailArtStubs()
        H.Slash("")
        T.ok(not tbc.Features.HasRetailFrameArt, "TBC has classic art")
        T.ok(not _G.GudaBiSPanel.portraitHidden, "classic panel")
        T.eq(tbc.Theme.Popup("Frame", nil, UIParent).retailBorder, nil, "classic popup")
        local ns = Retail()
        H.Slash("")
        T.eq(ns.Theme.Dialog(nil, UIParent).retailBorder, nil, "no NineSliceUtil: classic dialog")
        T.noErrors()
    end)

    T.case("Retail Character frame: the side tab and the panel sit on its real right edge", function()
        local ns = Retail()
        _G.CharacterFrame.width = 540
        _G.CharacterFrame:Show()
        local tab = ns.Panel.tab
        T.eq(tab.point[2], _G.CharacterFrame, "tab on the Character frame")
        T.eq(tab.point[3], "TOPRIGHT", "its right edge")
        T.eq(tab.point[4], 0, "not moved in: Retail art has no margin")
        tab:Click()
        T.eq(_G.GudaBiSPanel.point[4], 0, "docked panel not moved in either")
        _G.CharacterFrame:Hide()
        local tbc = H.Boot()
        _G.CharacterFrame:Show()
        T.eq(tbc.Panel.tab.point[4], -32, "Classic art keeps its margin")
        _G.CharacterFrame:Hide()
        T.noErrors()
    end)

    T.case("Retail dropdowns: Blizzard's widget, radio entries, actions after a divider", function()
        local ns = Retail()
        H.Slash("")
        T.ok(ns.Panel.listDropdown.native ~= nil, "native dropdown")
        local generator
        local built = {}
        local root = {}
        function root:CreateRadio(text, isSelected, select) built[#built + 1] = { kind = "radio", text = text, isSelected = isSelected, select = select } end
        function root:CreateButton(text, action) built[#built + 1] = { kind = "button", text = text, action = action } end
        function root:CreateDivider() built[#built + 1] = { kind = "divider" } end
        -- A dropdown built against a stand-in widget, to read the menu it describes.
        local holder = CreateFrame("Button")
        local native = CreateFrame("Button")
        function native:SetupMenu(fn) generator = fn end
        _G.CreateFrame = (function(original)
            return function(frameType, ...)
                if frameType == "DropdownButton" then return native end
                return original(frameType, ...)
            end
        end)(_G.CreateFrame)
        local fresh = ns.Dropdown.Create(holder, 200, function() end)
        fresh:SetOptions({
            { value = "a", text = "List A" }, { value = "b", text = "List B" },
            { action = function() end, text = "New list", separator = true },
        }, "b")
        generator(native, root)
        T.eq(built[1].kind, "radio", "lists are radio entries")
        T.ok(built[2].isSelected(), "the chosen one is selected")
        T.ok(not built[1].isSelected(), "the other is not")
        T.eq(built[3].kind, "divider", "divider before the actions")
        T.eq(built[4].kind, "button", "actions are buttons")
        built[1].select()
        T.eq(fresh.value, "a", "choosing a radio entry chooses it")
        T.noErrors()
    end)

    T.case("items show as the top players wear them: links built from bonus IDs", function()
        local ns = Retail()
        _G.UnitLevel = function() return 90 end
        local list = { itemBonuses = { [100] = { 13440, 6652 } } }
        T.eq(ns.Items.ListLink(list, 100), "item:100::::::::90::::2:13440:6652", "item string with bonus IDs")
        T.eq(ns.Items.ListLink(list, 101), nil, "no bonus IDs, no link")
        T.eq(ns.Items.ListLink(nil, 100), nil, "no list")
        local real = ns.Data:Get(TOP_ID)
        local head = real.items[1]
        T.ok(real.itemBonuses[head] and #real.itemBonuses[head] > 0, "generated data carries bonus IDs")
        local shown
        function _G.GameTooltip:SetHyperlink(link) shown = link end
        H.Slash("")
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "slot") == 1 and rawget(frame, "enchant") then frame:Enter() end
        end
        T.eq(shown, ns.Items.ListLink(real, head), "the slot tooltip shows the top players' copy")
        T.noErrors()
    end)

    T.case("Retail refuses Wowhead gear-planner links until their format is checked", function()
        local ns = Retail()
        local result, problem = ns.GearPlanner:Read("https://www.wowhead.com/gear-planner/paladin/human/AAAA")
        T.eq(result, nil, "refused")
        T.eq(problem, ns.L.IMPORT_WRONG_FLAVOR, "says why")
    end)
end
