-- The player's class and talent tree.
--
-- On Era and TBC the tree is the one with the most talent points: /gbis probe showed
-- C_SpecializationInfo.GetSpecialization() returning 1 (Holy) for a 0/40/21
-- Protection paladin on TBC, so it is never used there (architecture.md section 10).
-- Points spent are the 7th return of C_SpecializationInfo.GetSpecializationInfo.
-- Clients where the player picks a spec (ns.Features.HasSpecChoice: Retail, MoP) read
-- that pick (GB-131).

local addonName, ns = ...

local Spec = ns:RegisterModule("Spec")

local MAX_TREES = 4

-- The index of the largest value; the first one wins a tie. Nil when all are zero.
function Spec.MostPoints(points)
    local best, bestPoints = nil, 0
    for tree = 1, #points do
        if points[tree] > bestPoints then
            best, bestPoints = tree, points[tree]
        end
    end
    return best
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
-- is asked when it gives nothing.
local function TreeInfo(tree)
    local api = C_SpecializationInfo
    if api and api.GetSpecializationInfo then
        local ok, specID, name, _, _, _, _, pointsSpent = pcall(api.GetSpecializationInfo, tree)
        if ok and specID and specID ~= 0 and name then return specID, name, pointsSpent or 0 end
    end
    return TalentTabInfo(tree)
end

-- Where the player picks a spec (ns.Features.HasSpecChoice: Retail, MoP), that pick is the
-- tree; elsewhere the tree with the most points.
function Spec:ActiveTree()
    if ns.Features.HasSpecChoice then return ns.Compat.GetSpecialization() end
    local points = {}
    for tree = 1, MAX_TREES do
        local specID, _, spent = TreeInfo(tree)
        if not specID then break end
        points[tree] = spent
    end
    return Spec.MostPoints(points)
end

-- The client's own (localized) name of one of the player's talent trees.
function Spec:TreeName(tree)
    local _, name = TreeInfo(tree)
    return name
end

function Spec:PlayerClass()
    local _, class = UnitClass("player")
    return class
end

function Spec:PlayerFaction()
    return (UnitFactionGroup("player"))
end
