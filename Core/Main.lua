-- Bootstrap, loaded last: every module file has run by now. On this addon's
-- ADDON_LOADED the database is ready, then GBIS_INITIALIZED tells each module to
-- wire itself.

local addonName, ns = ...

local Events = ns.Events

Events:OnAddonLoaded(function()
    ns.Database:Initialize()
    Events:Fire("GBIS_INITIALIZED")
end, "Main")
