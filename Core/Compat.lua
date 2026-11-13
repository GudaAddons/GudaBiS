-- Which function or frame to use on this client. Feature code never checks whether a
-- global exists; it uses what this file resolved (RULES.md Rule 3).
--
-- RELOCATED follows GudaBags Compatibility/API.lua: WoW: Forever and Retail removed
-- many legacy globals and keep them only in a namespace, while the Classic flavors
-- ship the globals. Resolved once at load, global preferred, exported on ns so hot
-- paths can cache a file-top local (`local GetItemInfo = ns.GetItemInfo`).
--
-- Only names whose namespaced version takes the same arguments and returns the same
-- values belong in RELOCATED. A function that also changed shape (for example
-- GetLootMethod, whose C_PartyInfo version returns an enum instead of a string) is
-- wrapped by hand where it is first needed, never aliased.

local addonName, ns = ...

local Compat = ns:RegisterModule("Compat")

-- GetSpellTexture: C_Spell's version also returns the original icon as a second value;
-- the first value is the same, so callers read only that one.
-- GetItemStats: both return a table of stat keys to amounts for an item link.
-- In /gbis status order.
local RELOCATED = {
    { "GetItemInfo", C_Item },
    { "GetItemInfoInstant", C_Item },
    { "GetDetailedItemLevelInfo", C_Item },
    { "IsAddOnLoaded", C_AddOns },
    { "GetSpellTexture", C_Spell },
    { "GetItemStats", C_Item },
    { "GetCVarBool", C_CVar },
}

Compat.resolvedNames = {}
Compat.resolvedSource = {}

for _, entry in ipairs(RELOCATED) do
    local name, namespace = entry[1], entry[2]
    local global = _G[name]
    local scoped = namespace and namespace[name]
    ns[name] = global or scoped
    Compat.resolvedNames[#Compat.resolvedNames + 1] = name
    Compat.resolvedSource[name] = global and "global" or scoped and "namespace" or "MISSING"
end

-- True when value is a secret value (12.0 engine: Retail, Forever). Chat text inside an
-- instance can be one; type() still says "string", but indexing or matching it from
-- addon code is an error, so chat handlers ask this before reading the text. Clients
-- without issecretvalue have no secret values.
function Compat.IsSecret(value)
    local check = issecretvalue
    return check ~= nil and check(value) == true
end

-- The classic talent-tab API: (id, name, description, icon, pointsSpent, ...) on current
-- Classic clients, (name, icon, pointsSpent, ...) on older ones. The tab index stands
-- in for the spec ID.
local function TalentTabInfo(tree)
    local get = _G.GetTalentTabInfo
    if not get then return nil end
    local ok, first, second, third, _, fifth = pcall(get, tree)
    if not ok or first == nil then return nil end
    if type(first) == "number" then return tree, second, tonumber(fifth) or 0 end
    return tree, first, tonumber(third) or 0
end

-- WoW: Forever answers C_SpecializationInfo.GetSpecializationInfo without a spec (author,
-- 2026-11-11: list names showed as "BiS, BiS" with no tree name), so the talent-tab API
-- is asked when it gives nothing. Returns the spec ID (the tab index on the
-- classic API), its name and the points spent, or nil.
function Compat.TalentTree(tree)
    local api = C_SpecializationInfo
    if api and api.GetSpecializationInfo then
        local ok, specID, name, _, _, _, _, pointsSpent = pcall(api.GetSpecializationInfo, tree)
        if ok and specID and specID ~= 0 and name then return specID, name, pointsSpent or 0 end
    end
    return TalentTabInfo(tree)
end

-- A character name without the realm when it is the player's realm (Ambiguate);
-- the part before "-" where Ambiguate is missing.
function Compat.ShortName(name)
    if not name then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return (name:match("^([^%-]+)")) or name
end

-- The player's chosen specialization index, or nil. C_SpecializationInfo's version is
-- preferred, the global (MoP Classic) is the fallback; looked up on each call, since
-- only clients with ns.Features.HasSpecChoice ask.
function Compat.GetSpecialization()
    local api = C_SpecializationInfo
    local get = api and api.GetSpecialization or GetSpecialization
    if not get then return nil end
    local ok, index = pcall(get)
    return ok and type(index) == "number" and index > 0 and index or nil
end

-- A spell's name. The global GetSpellInfo returns the name first; C_Spell.GetSpellInfo
-- returns a table instead, so it is read here and never aliased.
function Compat.SpellName(spellID)
    if GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return nil
end

-- The item icon button of Blizzard's group-loot frame `index`, or nil: the IconFrame
-- child (parentKey on Retail, named GroupLootFrameNIconFrame on the Classic flavors).
function Compat.GetGroupLootIcon(index)
    local frame = _G["GroupLootFrame" .. index]
    if not frame then return nil end
    local icon = frame.IconFrame
    if type(icon) == "table" then return icon end
    icon = _G["GroupLootFrame" .. index .. "IconFrame"]
    return type(icon) == "table" and icon or nil
end

-- The Need button of Blizzard's group-loot frame `index` (1-4), or nil.
-- Classic flavors and Retail keep it on the frame (GroupLootFrameN.NeedButton);
-- Forever's MKBGroupLootFrameTemplate nests it one level deeper
-- (GroupLootFrameN.LootButtonContainer.NeedButton). Decided by the frame's shape, not
-- the client, so a template change on any flavor degrades to nil instead of erroring.
function Compat.GetGroupLootNeedButton(index)
    local frame = _G["GroupLootFrame" .. index]
    if not frame then return nil end
    if frame.NeedButton then return frame.NeedButton end
    local container = frame.LootButtonContainer
    return container and container.NeedButton or nil
end
