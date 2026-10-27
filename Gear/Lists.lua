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

-- Setting nil clears the slot, with its enchant and gems.
function Lists:SetSlot(id, slot, itemID)
    local list = Customs()[id]
    if not list then return end
    list.items[slot] = itemID
    list.enchants[slot] = nil
    list.gems[slot] = nil
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

function Lists:MainSpec()
    local roles = Roles()
    local list = roles and self:Get(roles.ms)
    if list then return list end
    local Spec = ns.Spec
    return DefaultGuideList(ns.Data:ForClass(Spec:PlayerClass(), self:Phase(), Spec:PlayerFaction()))
end

function Lists:OffSpec()
    local roles = Roles()
    return roles and self:Get(roles.os) or nil
end

-- role: "ms" or "os". Setting the list that already has the role clears it, and a
-- list cannot be MS and OS at once.
function Lists:ToggleRole(role, id)
    local roles = Roles()
    if not roles then return end
    local other = role == "ms" and "os" or "ms"
    if roles[role] == id then
        roles[role] = nil
        return
    end
    roles[role] = id
    if roles[other] == id then roles[other] = nil end
end

-- "ms", "os" or nil for a list, as the panel labels it.
function Lists:RoleOf(id)
    local ms, os = self:MainSpec(), self:OffSpec()
    if ms and ms.id == id then return "ms" end
    if os and os.id == id then return "os" end
    return nil
end

local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

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
