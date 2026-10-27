-- Bootstrap, loaded last: every module file has run by now. On this addon's
-- ADDON_LOADED, GBIS_INITIALIZED tells each module to wire itself.

local addonName, ns = ...

local Events = ns.Events

Events:OnAddonLoaded(function()
    Events:Fire("GBIS_INITIALIZED")
end, "Main")
