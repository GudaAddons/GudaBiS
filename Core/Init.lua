-- Namespace, module registry and the chat helpers every module uses.
-- Modules register with ns:RegisterModule and are also reachable as ns.<Name>.

local addonName, ns = ...

ns.addonName = addonName

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
ns.version = (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or "0.0.0"

ns.Modules = {}
ns.debugMode = false

function ns:RegisterModule(name, module)
    assert(self[name] == nil, "module name collides with a namespace field: " .. name)
    module = module or {}
    self.Modules[name] = module
    self[name] = module
    return module
end

function ns:GetModule(name)
    return self.Modules[name]
end

-- tostring every argument, nils included, and join with spaces.
local function Join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end
ns.Join = Join

local PREFIX = "|cff33ccff[GudaBiS]|r "

function ns:Print(...)
    print(PREFIX .. Join(...))
end

-- Debug lines go to the in-memory log once Core/Log.lua exists, and reach chat
-- only while debug mode is on, so normal players never see them.
function ns:Debug(...)
    if not self.debugMode and not self.Modules.Log then return end
    local msg = Join(...)
    local log = self.Modules.Log
    if log then log:Add("debug", msg) end
    if self.debugMode then
        print("|cff888888[GBiS]|r " .. msg)
    end
end

-- Errors go to the client's error handler so BugGrabber/BugSack collect them.
-- Only the first copy of an error is shown: a handler failing on every BAG_UPDATE
-- would otherwise flood the screen. Repeats are only counted.
local errorCounts = {}

function ns:Error(err)
    local text = tostring(err)
    local count = (errorCounts[text] or 0) + 1
    errorCounts[text] = count
    local log = self.Modules.Log
    if log then log:Add("error", count > 1 and (text .. " (x" .. count .. ")") or text) end
    if count > 1 then return end
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(err)
    else
        print(PREFIX .. text)
    end
end
