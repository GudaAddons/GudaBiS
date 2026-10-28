-- Every list a character can look at, and which ones it plays (GB-040/042).
--
-- Guide lists come from Data. Custom lists are the player's own, account-wide in
-- GudaBiS_DB.lists["custom:N"] = { id, custom = true, name, items, enchants, gems },
-- shaped like a guide list so every view treats both the same; they have no phase.
--
-- Per character:
--   char.selection = { phase, list }                  what the panel shows
--   char.roles[talentGroup] = { ms = id, os = id }    main and off spec, per dual-spec
--                                                     group; MS defaults to the guide
--                                                     list of the active talent tree
-- Viewing a list never changes MS or OS; only the MS/OS buttons do.

local addonName, ns = ...

local Lists = ns:RegisterModule("Lists")

local CUSTOM_PREFIX = "custom:"

-- Ring and trinket slots come in pairs that share their candidates.
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

local function Char()
    return ns.Database:Char()
end

local function Selection()
    local char = Char()
    if not char then return nil end
    char.selection = char.selection or {}
    return char.selection
end

local function Customs()
    local db = ns.db
    if not db then return {} end
    db.lists = db.lists or {}
    return db.lists
end

local function HasPhase(phase)
    for _, p in ipairs(ns.Data:Phases()) do
        if p == phase then return true end
    end
    return false
end

function Lists:Phase()
    local selection = Selection()
    local phase = selection and selection.phase
    if phase and HasPhase(phase) then return phase end
    return ns.Data.defaultPhase
end

function Lists:SetPhase(phase)
    local selection = Selection()
    if selection then selection.phase = phase end
end

function Lists:Get(id)
    if not id then return nil end
    if id:sub(1, #CUSTOM_PREFIX) == CUSTOM_PREFIX then
        return Customs()[id]
    end
    return ns.Data:Get(id)
end

function Lists.IsCustom(list)
    return list ~= nil and list.custom == true
end

local function SortedCustoms()
    local out = {}
    for _, list in pairs(Customs()) do out[#out + 1] = list end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- The guide lists of the selected phase for the player's class and faction, then the
-- account's custom lists by name.
function Lists:Choices()
    local Spec = ns.Spec
    local out = ns.Data:ForClass(Spec:PlayerClass(), self:Phase(), Spec:PlayerFaction())
    for _, list in ipairs(SortedCustoms()) do out[#out + 1] = list end
    return out
end

local function DefaultGuideList(choices)
    local tree = ns.Spec:ActiveTree()
    for _, list in ipairs(choices) do
        if not list.custom and list.tree == tree then return list end
    end
    for _, list in ipairs(choices) do
        if not list.custom then return list end
    end
    return choices[1]
end

-- The list the panel shows: the saved one when still offered, else the MS list, else
-- the guide list of the active talent tree. Nil when there is nothing to show.
function Lists:Current()
    local choices = self:Choices()
    if #choices == 0 then return nil end
    local selection = Selection()
    local saved = selection and selection.list
    for _, list in ipairs(choices) do
        if list.id == saved then return list end
    end
    local ms = self:MainSpec()
    if ms then
        for _, list in ipairs(choices) do
            if list.id == ms.id then return list end
        end
    end
    return DefaultGuideList(choices)
end

function Lists:Select(id)
    local selection = Selection()
    if selection then selection.list = id end
end

function Lists:CreateCustom(name, copyFrom)
    local db = ns.db
    if not db then return nil end
    db.nextListId = (db.nextListId or 0) + 1
    local id = CUSTOM_PREFIX .. db.nextListId
    local list = { id = id, custom = true, name = name, items = {}, enchants = {}, gems = {} }
    if copyFrom then
        for slot, itemID in pairs(copyFrom.items) do list.items[slot] = itemID end
        for slot, spellID in pairs(copyFrom.enchants or {}) do list.enchants[slot] = spellID end
        for slot, gems in pairs(copyFrom.gems or {}) do
            local copy = {}
            for i, gemID in ipairs(gems) do copy[i] = gemID end
            list.gems[slot] = copy
        end
    end
    Customs()[id] = list
    self:Select(id)
    return list
end

-- Shirt and tabard: guides never list them and the panel has no place for them.
local UNLISTED_SLOTS = { [4] = true, [19] = true }

-- A custom list filled from decoded gear-planner slots (GB-043): item, enchant and gems
-- per slot, as Wowhead's planner chose them. Returns the list and how many items it got.
function Lists:CreateImported(name, slots)
    local list = self:CreateCustom(name)
    if not list then return nil, 0 end
    local count = 0
    for slot, entry in pairs(slots) do
        if not UNLISTED_SLOTS[slot] and entry.item and entry.item > 0 then
            list.items[slot] = entry.item
            list.enchants[slot] = entry.enchant
            if entry.gems and #entry.gems > 0 then
                local gems = {}
                for i, gemID in ipairs(entry.gems) do gems[i] = gemID end
                list.gems[slot] = gems
            end
            count = count + 1
        end
    end
    return list, count
end

function Lists:Rename(id, name)
    local list = Customs()[id]
    if list then list.name = name end
end

-- Deleting a custom list also clears it wherever a character uses it as MS or OS.
function Lists:Delete(id)
    Customs()[id] = nil
    for _, char in pairs(ns.db and ns.db.chars or {}) do
        if char.selection and char.selection.list == id then char.selection.list = nil end
        for _, roles in pairs(char.roles or {}) do
            if roles.ms == id then roles.ms = nil end
            if roles.os == id then roles.os = nil end
        end
    end
end

-- The gems a guide puts in this exact item in this slot, copied; nil when no guide
-- list has the item there with gems.
local function GuideGemsFor(slot, itemID)
    for _, list in ipairs(ns.Data:All()) do
        if list.items[slot] == itemID and list.gems and list.gems[slot] then
            local copy = {}
            for i, gemID in ipairs(list.gems[slot]) do copy[i] = gemID end
            return copy
        end
    end
    return nil
end

-- A new item keeps the slot's enchant (enchants belong to the slot) and takes the
-- gems a guide gives that same item; otherwise its sockets start empty (author,
-- 2026-10-28). Setting nil clears the slot, enchant and gems too.
function Lists:SetSlot(id, slot, itemID)
    local list = Customs()[id]
    if not list then return end
    list.items[slot] = itemID
    if not itemID then
        list.enchants[slot] = nil
        list.gems[slot] = nil
        return
    end
    list.gems[slot] = GuideGemsFor(slot, itemID)
end

function Lists:SetEnchant(id, slot, spellID)
    local list = Customs()[id]
    if list then list.enchants[slot] = spellID end
end

-- index: the socket, 1-based. A nil gem empties that socket.
function Lists:SetGem(id, slot, index, gemID)
    local list = Customs()[id]
    if not list then return end
    local gems = list.gems[slot] or {}
    for i = #gems + 1, index - 1 do gems[i] = 0 end
    gems[index] = gemID or 0
    while #gems > 0 and gems[#gems] == 0 do gems[#gems] = nil end
    list.gems[slot] = #gems > 0 and gems or nil
end

local function ClassListsNewestFirst()
    local Spec = ns.Spec
    local phases = ns.Data:Phases()
    local out = {}
    for i = #phases, 1, -1 do
        for _, list in ipairs(ns.Data:ForClass(Spec:PlayerClass(), phases[i], Spec:PlayerFaction())) do
            out[#out + 1] = list
        end
    end
    return out
end

-- Every enchant the class's guide lists use for a slot (and its pair), newest phase
-- first, without repeats: what the enchant picker offers.
function Lists:GuideEnchantsForSlot(slot)
    local out, seen = {}, {}
    for _, list in ipairs(ClassListsNewestFirst()) do
        for _, s in ipairs({ slot, PAIR[slot] }) do
            local spellID = list.enchants and list.enchants[s]
            if spellID and not seen[spellID] then
                seen[spellID] = true
                out[#out + 1] = spellID
            end
        end
    end
    return out
end

-- Every gem the class's guide lists use, in any slot: what the gem picker offers.
function Lists:GuideGems()
    local out, seen = {}, {}
    for _, list in ipairs(ClassListsNewestFirst()) do
        for _, gems in pairs(list.gems or {}) do
            for _, gemID in ipairs(gems) do
                if gemID ~= 0 and not seen[gemID] then
                    seen[gemID] = true
                    out[#out + 1] = gemID
                end
            end
        end
    end
    return out
end

local function TalentGroup()
    local api = C_SpecializationInfo
    if api and api.GetActiveSpecGroup then
        local ok, group = pcall(api.GetActiveSpecGroup)
        if ok and group then return group end
    end
    return 1
end

local function Roles()
    local char = Char()
    if not char then return nil end
    char.roles = char.roles or {}
    local group = TalentGroup()
    char.roles[group] = char.roles[group] or {}
    return char.roles[group]
end

-- roles.ms: a list ID (chosen), false (the player cleared MS), or nil (default: the
-- guide list of the active talent tree, skipping the OS list). roles.os: a list ID or
-- nil. A list is never both: OS wins over the default MS, so moving the default list
-- to OS really moves it (in game, 2026-10-28: it stuck on MS).
function Lists:MainSpec()
    local roles = Roles()
    if roles and roles.ms == false then return nil end
    local list = roles and self:Get(roles.ms)
    if list then return list end
    local Spec = ns.Spec
    local candidates = ns.Data:ForClass(Spec:PlayerClass(), self:Phase(), Spec:PlayerFaction())
    local os = roles and roles.os
    if os then
        local kept = {}
        for _, guide in ipairs(candidates) do
            if guide.id ~= os then kept[#kept + 1] = guide end
        end
        candidates = kept
    end
    return DefaultGuideList(candidates)
end

function Lists:OffSpec()
    local roles = Roles()
    return roles and self:Get(roles.os) or nil
end

-- "ms", "os" or nil for a list, as the panel labels it.
function Lists:RoleOf(id)
    local os = self:OffSpec()
    if os and os.id == id then return "os" end
    local ms = self:MainSpec()
    if ms and ms.id == id then return "ms" end
    return nil
end

-- role: "ms" or "os". Clicking the role a list already has clears it (MS then stays
-- empty until another list is chosen); otherwise the list takes the role and loses
-- the other one.
function Lists:ToggleRole(role, id)
    local roles = Roles()
    if not roles then return end
    if self:RoleOf(id) == role then
        if role == "ms" then roles.ms = false else roles.os = nil end
        return
    end
    if role == "ms" then
        roles.ms = id
        if roles.os == id then roles.os = nil end
    else
        roles.os = id
        if roles.ms == id then roles.ms = nil end
    end
end

-- Every guide item of the player's class for a slot (and its ring/trinket pair), from
-- the newest phase down, in guide order without repeats: what the picker offers.
function Lists:GuideItemsForSlot(slot)
    local Spec = ns.Spec
    local phases = ns.Data:Phases()
    local out, seen = {}, {}
    local function Add(itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            out[#out + 1] = itemID
        end
    end
    for i = #phases, 1, -1 do
        for _, list in ipairs(ns.Data:ForClass(Spec:PlayerClass(), phases[i], Spec:PlayerFaction())) do
            for _, s in ipairs({ slot, PAIR[slot] }) do
                Add(list.items[s])
                for _, itemID in ipairs(list.alts and list.alts[s] or {}) do Add(itemID) end
            end
        end
    end
    return out
end

-- Which equip locations fit each INVSLOT.
local FITS = {
    [1] = { INVTYPE_HEAD = true }, [2] = { INVTYPE_NECK = true }, [3] = { INVTYPE_SHOULDER = true },
    [15] = { INVTYPE_CLOAK = true }, [5] = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    [9] = { INVTYPE_WRIST = true }, [10] = { INVTYPE_HAND = true }, [6] = { INVTYPE_WAIST = true },
    [7] = { INVTYPE_LEGS = true }, [8] = { INVTYPE_FEET = true },
    [11] = { INVTYPE_FINGER = true }, [12] = { INVTYPE_FINGER = true },
    [13] = { INVTYPE_TRINKET = true }, [14] = { INVTYPE_TRINKET = true },
    [16] = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true },
    [17] = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true },
    [18] = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true },
}

function Lists.FitsSlot(equipLoc, slot)
    local fits = FITS[slot]
    return fits ~= nil and fits[equipLoc] == true
end

-- An item ID from what the player typed: a number, an item link, or a Wowhead URL
-- ("...item=12345...").
function Lists.ParseItemID(text)
    if type(text) ~= "string" then return nil end
    local id = text:match("item[=:](%d+)") or text:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end

-- A spell ID the same way: a number, a spell link, or a Wowhead URL ("spell=27957").
function Lists.ParseSpellID(text)
    if type(text) ~= "string" then return nil end
    local id = text:match("spell[=:](%d+)") or text:match("enchant:(%d+)") or text:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end
