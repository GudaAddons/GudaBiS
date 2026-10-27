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

-- Group-only handlers (RULES.md Rule 1): loot, chat and loot-addon listeners cost
-- nothing while solo. They are registered with the frame only while IsInGroup() is
-- true, and GBIS_GROUP_JOINED / GBIS_GROUP_LEFT fire when that changes. The roster
-- watch itself starts with the first RegisterGroup call.
local groupHandlers = {}
local inGroup = false
local watching = false

local function SetGroupHandlers(on)
    for event, owners in pairs(groupHandlers) do
        for owner, fn in pairs(owners) do
            if on then
                Events:Register(event, fn, owner)
            else
                Events:Unregister(event, owner)
            end
        end
    end
end

local function UpdateGroupState()
    local now = IsInGroup() and true or false
    if now == inGroup then return end
    inGroup = now
    SetGroupHandlers(now)
    Events:Fire(now and "GBIS_GROUP_JOINED" or "GBIS_GROUP_LEFT")
end

function Events:RegisterGroup(event, fn, owner)
    local owners = groupHandlers[event]
    if not owners then
        owners = {}
        groupHandlers[event] = owners
    end
    owners[owner] = fn
    if inGroup then
        self:Register(event, fn, owner)
    end
    if not watching then
        watching = true
        self:Register("GROUP_ROSTER_UPDATE", UpdateGroupState, "Events")
        self:Register("PLAYER_ENTERING_WORLD", UpdateGroupState, "Events")
        UpdateGroupState()
    end
end

function Events:UnregisterGroup(event, owner)
    local owners = groupHandlers[event]
    if not owners then return end
    owners[owner] = nil
    if next(owners) == nil then groupHandlers[event] = nil end
    self:Unregister(event, owner)
end

function Events:IsInGroup()
    return inGroup
end

-- Runs fn once, when this addon's own ADDON_LOADED arrives (SavedVariables are ready).
function Events:OnAddonLoaded(fn, owner)
    self:Register("ADDON_LOADED", function(_, name)
        if name ~= addonName then return end
        self:Unregister("ADDON_LOADED", owner)
        fn()
    end, owner)
end
