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

local RELOCATED = {
    GetItemInfo = C_Item,
    GetItemInfoInstant = C_Item,
    GetDetailedItemLevelInfo = C_Item,
    IsAddOnLoaded = C_AddOns,
}

Compat.resolvedNames = { "GetItemInfo", "GetItemInfoInstant", "GetDetailedItemLevelInfo", "IsAddOnLoaded" }
Compat.resolvedSource = {}

for name, namespace in pairs(RELOCATED) do
    local global = _G[name]
    local scoped = namespace and namespace[name]
    ns[name] = global or scoped
    Compat.resolvedSource[name] = global and "global" or scoped and "namespace" or "MISSING"
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
