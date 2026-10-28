-- Blizzard's Adventure Guide (GB-073): the wishlist shield on every item of a boss's Loot
-- tab (Dungeons or Raids -> boss -> Loot). Turned on by the guide being there, not by the
-- client: Retail has it, and a client that gains it later (WoW: Forever) gets the
-- shields without a change here (author, 2026-10-28).
--
-- The guide (Blizzard_EncounterJournal) loads on demand, so the hook waits for it. Its
-- loot list is a ScrollBox: ScrollUtil.AddInitializedFrameCallback tells us each time a
-- row is filled. The row's item comes from row.itemID, else from the row's loot index
-- through C_EncounterJournal.GetLootInfoByIndex; rows without an item (headers) get no
-- shield. Wishing an item here saves the instance and boss names as its source.
--
-- Written from Blizzard's published UI patterns, not yet seen in game (RULES.md: prove
-- in game); every access is guarded, and a failure only means no shields.

local addonName, ns = ...

local AdventureGuideBridge = ns:RegisterModule("AdventureGuideBridge")

local GUIDE_ADDON = "Blizzard_EncounterJournal"
local CORNER_X, CORNER_Y = -6, -6

local hooked = false

local function LootScrollBox()
    local journal = _G.EncounterJournal
    local encounter = type(journal) == "table" and journal.encounter
    local info = type(encounter) == "table" and encounter.info
    local container = type(info) == "table" and info.LootContainer
    local scrollBox = type(container) == "table" and container.ScrollBox
    return type(scrollBox) == "table" and scrollBox or nil
end

local function ItemIDOf(row, elementData)
    local itemID = tonumber(row.itemID)
    if itemID and itemID > 0 then return itemID end
    local index = type(elementData) == "table" and tonumber(elementData.index)
    local api = C_EncounterJournal
    if not (index and api and api.GetLootInfoByIndex) then return nil end
    local ok, lootInfo = pcall(api.GetLootInfoByIndex, index)
    itemID = ok and type(lootInfo) == "table" and tonumber(lootInfo.itemID)
    return itemID and itemID > 0 and itemID or nil
end

-- The instance and boss on show, for the wishlist entry's source.
local function Source()
    local journal = _G.EncounterJournal
    local dungeon, boss
    if EJ_GetInstanceInfo then
        local ok, name = pcall(EJ_GetInstanceInfo)
        dungeon = ok and type(name) == "string" and name or nil
    end
    local encounterID = type(journal) == "table" and journal.encounterID
    if encounterID and EJ_GetEncounterInfo then
        local ok, name = pcall(EJ_GetEncounterInfo, encounterID)
        boss = ok and type(name) == "string" and name or nil
    end
    if not (dungeon or boss) then return nil end
    return { dungeon = dungeon, boss = boss }
end

local function OnRowInitialized(row, elementData)
    if type(row) ~= "table" then return end
    local itemID = ItemIDOf(row, elementData)
    if not itemID then
        ns.WishToggle.Hide(row)
        return
    end
    ns.WishToggle.Paint(row, "TOPRIGHT", row, "TOPRIGHT", CORNER_X, CORNER_Y, itemID, Source())
end

function AdventureGuideBridge:Hook()
    if hooked then return true end
    local scrollBox = LootScrollBox()
    local utils = ScrollUtil
    if not (scrollBox and utils and type(utils.AddInitializedFrameCallback) == "function") then return false end
    local ok, err = pcall(utils.AddInitializedFrameCallback, scrollBox, function(row, elementData)
        local fine, failure = pcall(OnRowInitialized, row, elementData)
        if not fine then ns:Debug("Adventure Guide shield:", failure) end
    end, AdventureGuideBridge, true)
    if not ok then
        ns:Debug("Adventure Guide hook failed:", err)
        return false
    end
    hooked = true
    return true
end

ns.Events:Register("GBIS_INITIALIZED", function()
    local loaded = ns.IsAddOnLoaded
    if loaded and loaded(GUIDE_ADDON) then AdventureGuideBridge:Hook() end
end, "AdventureGuideBridge")
ns.Events:Register("ADDON_LOADED", function(_, name)
    if name == GUIDE_ADDON then AdventureGuideBridge:Hook() end
end, "AdventureGuideBridge")
