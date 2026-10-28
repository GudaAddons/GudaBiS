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

local function TreeInfo(tree)
    local api = C_SpecializationInfo
    if not (api and api.GetSpecializationInfo) then return nil end
    local ok, specID, name, _, icon, _, _, pointsSpent = pcall(api.GetSpecializationInfo, tree)
    if not ok or not specID or specID == 0 then return nil end
    return specID, name, icon, pointsSpent or 0
end

-- Where the player picks a spec (ns.Features.HasSpecChoice: Retail, MoP), that pick is the
-- tree; elsewhere the tree with the most points.
function Spec:ActiveTree()
    if ns.Features.HasSpecChoice then
        local api = C_SpecializationInfo
        local get = api and api.GetSpecialization or GetSpecialization
        if not get then return nil end
        local ok, index = pcall(get)
        return ok and type(index) == "number" and index > 0 and index or nil
    end
    local points = {}
    for tree = 1, MAX_TREES do
        local specID, _, _, spent = TreeInfo(tree)
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

function Spec:TreeIcon(tree)
    local _, _, icon = TreeInfo(tree)
    return icon
end

function Spec:PlayerClass()
    local _, class = UnitClass("player")
    return class
end

function Spec:PlayerFaction()
    return (UnitFactionGroup("player"))
end
