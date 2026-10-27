-- Which BiS list this character is looking at: the phase and the list, remembered per
-- character in char.selection. M2 knows only the guide lists (Data); custom lists and
-- the MS/OS choice join here in M4.

local addonName, ns = ...

local Lists = ns:RegisterModule("Lists")

local function Selection()
    local char = ns.Database:Char()
    if not char then return nil end
    char.selection = char.selection or {}
    return char.selection
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

-- The guide lists the player can pick for the selected phase.
function Lists:Choices()
    local Spec = ns.Spec
    return ns.Data:ForClass(Spec:PlayerClass(), self:Phase(), Spec:PlayerFaction())
end

-- The chosen list: the saved one when it is still offered, else the first list of the
-- player's active talent tree, else the first list of the class. Nil when the class
-- has no data for this phase.
function Lists:Current()
    local choices = self:Choices()
    if #choices == 0 then return nil end
    local selection = Selection()
    local saved = selection and selection.list
    for _, list in ipairs(choices) do
        if list.id == saved then return list end
    end
    local tree = ns.Spec:ActiveTree()
    for _, list in ipairs(choices) do
        if list.tree == tree then return list end
    end
    return choices[1]
end

function Lists:Select(id)
    local selection = Selection()
    if selection then selection.list = id end
end
