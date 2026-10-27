-- Registry for the generated BiS data of the loaded flavor (RULES.md Rules 2 and 7).
-- Exactly one flavor's Data/<Flavor>/Lists.lua registers here per client. Shared code
-- reads guide lists only through this module, never the generated table.
--
-- A list: id ("SPEC:phase:set"), spec, class, specID, tree, phase, set (the guide's tab
-- name), faction (nil = both), url, updated, items/enchants/gems/alts keyed by INVSLOT.

local addonName, ns = ...

local Data = ns:RegisterModule("Data")

local lists = {}
local byId = {}
local bySpec = {}
local phaseSet = {}

function Data:Register(def)
    assert(self.flavor == nil, "a second flavor registered data: " .. tostring(def.flavor))
    self.flavor = def.flavor
    self.defaultPhase = def.defaultPhase
    self.source = def.source
    for _, list in ipairs(def.lists) do
        lists[#lists + 1] = list
        byId[list.id] = list
        local phases = bySpec[list.spec]
        if not phases then
            phases = {}
            bySpec[list.spec] = phases
        end
        local forPhase = phases[list.phase]
        if not forPhase then
            forPhase = {}
            phases[list.phase] = forPhase
        end
        forPhase[#forPhase + 1] = list
        phaseSet[list.phase] = true
    end
end

function Data:Get(id)
    return byId[id]
end

function Data:Count()
    return #lists
end

-- Every guide list of the loaded flavor, in registration order. Read only.
function Data:All()
    return lists
end

-- The guide lists for a spec and phase that a character of `faction` may use, in
-- the guide's tab order. A list without a faction is for both.
function Data:ForSpec(spec, phase, faction)
    local out = {}
    local phases = bySpec[spec]
    local forPhase = phases and phases[phase]
    if not forPhase then return out end
    for _, list in ipairs(forPhase) do
        if list.faction == nil or list.faction == faction then
            out[#out + 1] = list
        end
    end
    return out
end

-- Every guide list of a class for a phase that `faction` may use, ordered by talent
-- tree, then by the guide's tab order.
function Data:ForClass(class, phase, faction)
    local out = {}
    for _, list in ipairs(lists) do
        if list.class == class and list.phase == phase
            and (list.faction == nil or list.faction == faction) then
            out[#out + 1] = list
        end
    end
    table.sort(out, function(a, b)
        if a.tree ~= b.tree then return a.tree < b.tree end
        return a.id < b.id
    end)
    return out
end

function Data:Phases()
    local out = {}
    for phase in pairs(phaseSet) do out[#out + 1] = phase end
    table.sort(out)
    return out
end

function Data:Specs()
    local out = {}
    for spec in pairs(bySpec) do out[#out + 1] = spec end
    table.sort(out)
    return out
end
