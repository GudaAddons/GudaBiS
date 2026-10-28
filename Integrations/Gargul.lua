-- Gargul (GB-063). When the master looter starts a Gargul roll-off, every raider with
-- Gargul gets GL.ROLLOFF_STARTED and Gargul's own roll window (GargulUI_RollerUI_Window).
-- We put our badge on that window instead of opening a popup of ours, and keep quiet
-- when Gargul already flagged the item for the player (soft-reserve, prio, wishlist:
-- GL:isItemOfInterest).
--
-- Read from Gargul v8 source (Classes/RollOff.lua, RollerUI.lua, Utils/Items.lua,
-- Classes/Events.lua). None of it is a documented API, so every access is guarded and
-- a failure only drops back to the chat path (RULES.md Rule 5).

local addonName, ns = ...

local GargulBridge = ns:RegisterModule("GargulBridge")

local LISTENER = "GudaBiS_RollStart"
local WINDOW = "GargulUI_RollerUI_Window"

local function Gargul()
    local gl = _G.Gargul
    return type(gl) == "table" and gl or nil
end

local function CurrentRollOff()
    local gl = Gargul()
    local rollOff = gl and gl.RollOff
    return type(rollOff) == "table" and rollOff or nil
end

-- Whether a Gargul roll-off for this item is running now.
function GargulBridge:IsRolling(itemID)
    local rollOff = CurrentRollOff()
    local current = rollOff and rollOff.CurrentRollOff
    return rollOff ~= nil and rollOff.inProgress == true and type(current) == "table"
        and current.itemID == itemID
end

local function GargulFlagged(link)
    local gl = Gargul()
    if not (gl and type(gl.isItemOfInterest) == "function") then return false end
    local ok, interesting = pcall(gl.isItemOfInterest, gl, link)
    return ok and interesting == true
end

local function OnRollOffStarted()
    if not ns.Alerts:Enabled() then return end
    local rollOff = CurrentRollOff()
    local current = rollOff and rollOff.CurrentRollOff
    if type(current) ~= "table" then return end
    local itemID = current.itemID
    local match = itemID and ns.Match:Item(itemID, nil, current.itemLink)
    if not match then return end
    local link = current.itemLink
    C_Timer.After(0, function()
        local window = _G[WINDOW]
        if window and window:IsShown() then ns.Alerts:Badge(window, match) end
        if not GargulFlagged(link) then ns.Alerts:Sound() end
    end)
end

local hooked = false

local function Hook()
    if hooked then return end
    local gl = Gargul()
    local events = gl and gl.Events
    if type(events) ~= "table" or type(events.register) ~= "function" then return end
    local ok, err = pcall(events.register, events, LISTENER, "GL.ROLLOFF_STARTED", function()
        local fine, failure = pcall(OnRollOffStarted)
        if not fine then ns:Debug("Gargul roll-off:", failure) end
    end)
    if ok then
        hooked = true
    else
        ns:Debug("Gargul hook failed:", err)
    end
end

ns.Events:Register("GBIS_INITIALIZED", Hook, "GargulBridge")
ns.Events:Register("ADDON_LOADED", function(_, name)
    if name == "Gargul" then Hook() end
end, "GargulBridge")
