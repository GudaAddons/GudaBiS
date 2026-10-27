-- Offline harness: stubs just enough of the WoW API to load the real addon files
-- (in TOC order) under a chosen client, fire events at them and inspect the result.
-- Never loaded by the game (tests/ is in no TOC and is not packaged).

local H = {}

local ROOT = assert(arg and arg[1], "usage: lua5.1 tests/run.lua <addon root>")
H.ROOT = ROOT

-- Each client's interface number, project ID and TOC. A flavor whose TOC does not
-- exist yet loads the TBC one, so the shared code is still tested on that client.
local CLIENTS = {
    era = { iface = 11509, project = 2, toc = "GudaBiS_Vanilla.toc" },
    tbc = { iface = 20506, project = 5, toc = "GudaBiS_TBC.toc" },
    mists = { iface = 50504, project = 19, toc = "GudaBiS_Mists.toc" },
    retail = { iface = 120105, project = 1, toc = "GudaBiS_Mainline.toc" },
    forever = { iface = 16001, project = 1, toc = "GudaBiS_Camelot.toc" },
}
H.CLIENTS = CLIENTS

local function FileExists(path)
    local file = io.open(path, "r")
    if file then file:close() end
    return file ~= nil
end

function H.TocFor(client)
    if client.toc and FileExists(ROOT .. "/" .. client.toc) then return client.toc end
    return "GudaBiS_TBC.toc"
end

-- The .lua paths a TOC lists, in order, with forward slashes.
function H.TocFiles(tocName)
    local files = {}
    local toc = assert(io.open(ROOT .. "/" .. tocName, "r"))
    for line in toc:lines() do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    toc:close()
    return files
end

local frames

local function NoOp() end

local function NewFrame(name)
    local frame = { registered = {}, scripts = {}, shown = false, name = name }
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:UnregisterEvent(event) self.registered[event] = nil end
    function frame:SetScript(script, fn) self.scripts[script] = fn end
    function frame:GetScript(script) return self.scripts[script] end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:CreateFontString() return NewFrame() end
    function frame:CreateTexture() return NewFrame() end
    function frame:SetText(text) self.shownText = text end
    function frame:GetVerticalScrollRange() return 0 end
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return setmetatable(frame, { __index = function() return NoOp end })
end

function H.AllFrames()
    return frames
end

-- Replaces every stubbed global. opts.client is a CLIENTS key (default "tbc") or a
-- custom { iface, project }; opts.locale, opts.saved (GudaBiS_DB before load),
-- opts.playerName, opts.normalizedRealm (false removes GetNormalizedRealmName).
function H.Install(opts)
    opts = opts or {}
    local client = type(opts.client) == "table" and opts.client or CLIENTS[opts.client or "tbc"]
    H.client = client

    frames = {}
    H.printed = {}
    H.errors = {}
    H.timers = {}
    H.clock = 1000
    H.inGroup = false

    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        H.printed[#H.printed + 1] = table.concat(parts, " ")
    end
    _G.geterrorhandler = function()
        return function(err) H.errors[#H.errors + 1] = tostring(err) end
    end

    _G.GetBuildInfo = function() return "0.0.0", "1", "Jan 1 2026", client.iface end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_CLASSIC = 2
    _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
    _G.WOW_PROJECT_MISTS_CLASSIC = 19
    _G.WOW_PROJECT_ID = client.project
    _G.GetLocale = function() return opts.locale or "enUS" end

    local modern = client.iface >= 100000 or (client.iface >= 16000 and client.iface < 20000)
    local itemFns = {
        GetItemInfo = function() end,
        GetItemInfoInstant = function() end,
        GetDetailedItemLevelInfo = function() end,
    }
    _G.C_Item = itemFns
    _G.C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "0.0.0-test" end }
    _G.GetItemInfo = (not modern) and itemFns.GetItemInfo or nil
    _G.GetItemInfoInstant = (not modern) and itemFns.GetItemInfoInstant or nil
    _G.GetDetailedItemLevelInfo = nil
    _G.IsAddOnLoaded = (not modern) and function() return false end or nil
    _G.GetAddOnMetadata = nil

    _G.CreateFrame = function(_, name) return NewFrame(name) end
    _G.UIParent = NewFrame()
    _G.UISpecialFrames = {}
    _G.tinsert = table.insert
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.date = os.date
    _G.YES, _G.NO = "Yes", "No"
    _G.UNKNOWNOBJECT = "Unknown"
    _G.ChatFontNormal = {}
    _G.BackdropTemplateMixin = {}
    _G.C_Timer = {
        After = function(seconds, fn)
            H.timers[#H.timers + 1] = { at = H.clock + seconds, fn = fn }
        end,
    }

    _G.SlashCmdList = {}
    _G.SLASH_GUDABIS1 = nil

    local forever = client.iface >= 16000 and client.iface < 20000
    _G.UnitName = function(unit)
        if unit == "player" then return opts.playerName or (forever and "Vati Guda" or "Vati") end
    end
    _G.GetNormalizedRealmName = function() return "Spineshatter" end
    if opts.normalizedRealm == false then _G.GetNormalizedRealmName = nil end
    _G.GetRealmName = function() return "Thunder Fury" end
    _G.IsInGroup = function() return H.inGroup end

    for i = 1, 4 do _G["GroupLootFrame" .. i] = nil end

    _G.GudaBiS_DB = opts.saved
end

-- Load every file listed in the client's TOC, in order, with a fresh namespace.
function H.Load()
    local ns = {}
    H.toc = H.TocFor(H.client)
    for _, file in ipairs(H.TocFiles(H.toc)) do
        local chunk = assert(loadfile(ROOT .. "/" .. file))
        chunk("GudaBiS", ns)
    end
    H.ns = ns
    return ns
end

function H.Fire(event, ...)
    for _, frame in ipairs(frames) do
        local onEvent = frame.scripts.OnEvent
        if frame.registered[event] and onEvent then
            onEvent(frame, event, ...)
        end
    end
end

-- True when any frame listens to event.
function H.Registered(event)
    for _, frame in ipairs(frames) do
        if frame.registered[event] then return true end
    end
    return false
end

-- Install + load + ADDON_LOADED + PLAYER_LOGIN + PLAYER_ENTERING_WORLD.
function H.Boot(opts)
    H.Install(opts)
    local ns = H.Load()
    H.Fire("ADDON_LOADED", "GudaBiS")
    H.Fire("PLAYER_LOGIN")
    H.Fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
end

-- Runs every C_Timer callback due within the next `seconds`.
function H.Advance(seconds)
    H.clock = H.clock + seconds
    local due, pending = {}, {}
    for _, timer in ipairs(H.timers) do
        if timer.at <= H.clock then due[#due + 1] = timer else pending[#pending + 1] = timer end
    end
    H.timers = pending
    for _, timer in ipairs(due) do timer.fn() end
end

function H.SetGroup(inGroup)
    H.inGroup = inGroup
    H.Fire("GROUP_ROSTER_UPDATE")
end

function H.Slash(input)
    _G.SlashCmdList.GUDABIS(input)
end

function H.Printed(pattern, plain)
    for _, line in ipairs(H.printed) do
        if line:find(pattern, 1, plain) then return true end
    end
    return false
end

return H
