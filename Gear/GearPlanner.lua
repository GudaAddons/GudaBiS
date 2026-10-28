-- Wowhead gear-planner links (GB-043): a custom list can start from a set built on
-- wowhead.com/<flavor>/gear-planner/<class>/<race>/<CODE>. Everything is in CODE, so
-- nothing is fetched: the player pastes the link and it is decoded here.
--
-- CODE is the format tools/pipeline/gearplanner.py reads (see that file for the byte
-- layout and how it was worked out): URL-safe base64 of version 3 · level · talents ·
-- hunter pet block · one entry per slot with item (21 bits), enchant spell, random
-- suffix and gems in socket order. Plain arithmetic, no bit library, so the offline
-- tests run the pipeline's own vectors against it.
--
-- Only this flavor's links are read (author, 2026-10-28): item IDs and the format may
-- differ between Wowhead's flavors, so each flavor adds its path when it ships.
--
--   GearPlanner.Decode(code) -> { level, slots = { [INVSLOT] = { item, enchant, suffix, gems } } }
--                               or nil, reason
--   GearPlanner.ParseLink(text, path) -> code, classToken (nil for a bare code) | nil, error key
--   GearPlanner:Read(text) -> { slots, class } | nil, localized error

local addonName, ns = ...
local L = ns.L

local GearPlanner = ns:RegisterModule("GearPlanner")

local SUPPORTED_VERSION = 3
local MAX_SLOT = 19

-- Wowhead's path for each client this addon has data for.
local PATHS = { TBC = "tbc" }

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VALUES = { [("+"):byte()] = 62, [("/"):byte()] = 63 }
for i = 1, #ALPHABET do VALUES[ALPHABET:byte(i)] = i - 1 end

local floor = math.floor

-- URL-safe base64 (padding optional) to a byte array, or nil.
function GearPlanner.Bytes(code)
    code = code:gsub("=+$", "")
    if #code % 4 == 1 then return nil end
    local bytes, buffer, bits = {}, 0, 0
    for i = 1, #code do
        local value = VALUES[code:byte(i)]
        if not value then return nil end
        buffer = buffer * 64 + value
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local divisor = 2 ^ bits
            bytes[#bytes + 1] = floor(buffer / divisor)
            buffer = buffer % divisor
        end
    end
    return bytes
end

function GearPlanner.Decode(code)
    local raw = type(code) == "string" and GearPlanner.Bytes(code)
    if not raw then return nil, "not base64" end
    if #raw < 3 then return nil, "too short" end
    if raw[1] ~= SUPPORTED_VERSION then return nil, "unsupported version " .. raw[1] end
    local function U16(pos)
        if pos + 1 > #raw then return nil end
        return raw[pos] * 256 + raw[pos + 1]
    end
    local pos = 4 + raw[3]
    if pos <= #raw and raw[pos] == 0 then
        if pos + 1 > #raw then return nil, "truncated pet block" end
        pos = pos + 2 + raw[pos + 1] + 2
    end
    local slots = {}
    while pos <= #raw do
        if pos + 1 > #raw then return nil, "truncated entry" end
        local slotByte, flags = raw[pos], raw[pos + 1]
        pos = pos + 2
        local slot = slotByte % 64
        if slot < 1 or slot > MAX_SLOT then return nil, "slot out of range" end
        if slots[slot] then return nil, "slot twice" end
        local low = U16(pos)
        if not low then return nil, "truncated item" end
        local entry = { item = (flags % 32) * 65536 + low, gems = {} }
        pos = pos + 2
        if slotByte >= 128 then
            entry.enchant = U16(pos)
            if not entry.enchant then return nil, "truncated enchant" end
            pos = pos + 2
        end
        if floor(slotByte / 64) % 2 == 1 then
            local suffix = U16(pos)
            if not suffix then return nil, "truncated suffix" end
            entry.suffix = suffix >= 32768 and suffix - 65536 or suffix
            pos = pos + 2
        end
        local sockets = {}
        for _ = 1, floor(flags / 32) do
            local socket, gemLow = raw[pos], U16(pos + 1)
            if not (socket and gemLow) then return nil, "truncated gem" end
            sockets[#sockets + 1] = { index = floor(socket / 32), id = (socket % 32) * 65536 + gemLow }
            pos = pos + 3
        end
        table.sort(sockets, function(a, b) return a.index < b.index end)
        for i, socket in ipairs(sockets) do entry.gems[i] = socket.id end
        slots[slot] = entry
    end
    return { level = raw[2], slots = slots }
end

-- A gear-planner link for path ("tbc"), or a bare code. The class token comes from the
-- link ("death-knight" -> "DEATHKNIGHT").
function GearPlanner.ParseLink(text, path)
    text = strtrim(text or "")
    local bare = text:match("^([%w%-_]+=*)$")
    if bare then return bare end
    if not text:find("gear-planner/", 1, true) then return nil, "IMPORT_NOT_LINK" end
    local prefix = text:match("wowhead%.com/([%w%-]+)/gear%-planner/")
    if not path or prefix ~= path then return nil, "IMPORT_WRONG_FLAVOR" end
    local class, code = text:match("gear%-planner/([%a%-]+)/[%a%-]+/([%w%-_]+=*)")
    if not code then return nil, "IMPORT_DAMAGED" end
    return code, (class:gsub("%-", "")):upper()
end

function GearPlanner:Read(text)
    local code, classOrError = GearPlanner.ParseLink(text, PATHS[ns.Expansion.ClientKey])
    if not code then return nil, L[classOrError] end
    local decoded = GearPlanner.Decode(code)
    if not decoded or next(decoded.slots) == nil then return nil, L.IMPORT_DAMAGED end
    return { slots = decoded.slots, class = classOrError }
end
