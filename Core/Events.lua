-- Central event dispatcher. One hidden frame owns every WoW event; handlers are keyed
-- by an owner name so a module can remove only its own. Custom events (GBIS_*) never
-- touch the frame and are dispatched directly by Fire. A handler is called as
-- fn(event, ...) inside pcall, and its errors go to ns:Error.

local addonName, ns = ...

local Events = ns:RegisterModule("Events")

local pcall = pcall
local pairs = pairs

local frame = CreateFrame("Frame")
local handlers = {}

local function IsCustom(event)
    return event:sub(1, 5) == "GBIS_"
end

function Events:Register(event, fn, owner)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not IsCustom(event) then frame:RegisterEvent(event) end
    end
    list[owner] = fn
end

function Events:Unregister(event, owner)
    local list = handlers[event]
    if not list then return end
    list[owner] = nil
    if next(list) == nil then
        handlers[event] = nil
        if not IsCustom(event) then frame:UnregisterEvent(event) end
    end
end

local function Dispatch(event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in pairs(list) do
        local ok, err = pcall(fn, event, ...)
        if not ok then ns:Error(err) end
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    Dispatch(event, ...)
end)

function Events:Fire(event, ...)
    Dispatch(event, ...)
end

-- Runs fn once, when this addon's own ADDON_LOADED arrives (SavedVariables are ready).
function Events:OnAddonLoaded(fn, owner)
    self:Register("ADDON_LOADED", function(_, name)
        if name ~= addonName then return end
        self:Unregister("ADDON_LOADED", owner)
        fn()
    end, owner)
end
