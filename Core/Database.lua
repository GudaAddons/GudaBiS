-- GudaBiS_DB: one account-wide SavedVariable (architecture.md §4). Settings and
-- custom lists are account-wide; each character's choices live under its key in
-- chars, created on first use.
--
-- Defaults are filled in on every load and never assumed to exist: WoW: Forever has
-- lost SavedVariables before, so every module must work from an empty database.
-- Tables are added to DEFAULTS by the ticket that first uses them, not ahead of time.

local addonName, ns = ...

local Database = ns:RegisterModule("Database")

Database.SCHEMA_VERSION = 1

local DEFAULTS = {
    meta = {
        loadCount = 0,
    },
    settings = {
        debug = false,
        panelOpen = false,
        autoRoll = false,
        alerts = {
            enabled = true,
            sound = true,
            alts = true,
        },
    },
    chars = {},
    history = {
        raids = {},
        dungeons = {},
    },
}

-- MIGRATIONS[n] upgrades a database from schema n-1 to n.
local MIGRATIONS = {}

-- Fill every key missing from target with a copy of the default; never overwrite.
local function FillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            FillDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function Migrate(db)
    local from = tonumber(db.schema) or Database.SCHEMA_VERSION
    for version = from + 1, Database.SCHEMA_VERSION do
        local step = MIGRATIONS[version]
        if step then step(db) end
    end
    db.schema = Database.SCHEMA_VERSION
end

function Database:Initialize()
    local restored = type(GudaBiS_DB) == "table"
    if not restored then GudaBiS_DB = {} end
    local db = GudaBiS_DB
    Migrate(db)
    FillDefaults(db, DEFAULTS)
    db.meta.loadCount = db.meta.loadCount + 1
    self.restoredFromDisk = restored
    ns.db = db
    ns.debugMode = db.settings.debug and true or false
end

function Database:GetSetting(key)
    return ns.db and ns.db.settings[key]
end

function Database:SetSetting(key, value)
    if ns.db then ns.db.settings[key] = value end
end

-- The player's character key. Forever names are two words with no realm
-- ("Given Family"); every other client uses "Name-Realm" with the realm's spaces
-- removed, so the key is the same whichever API produced it.
local playerKey

function Database:PlayerKey()
    if playerKey then return playerKey end
    local name = UnitName("player")
    if not name or name == "" or name == UNKNOWNOBJECT then return nil end
    if ns.Features.RealmlessNames then
        playerKey = name
    else
        local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName() or ""):gsub("%s", "")
        if realm == "" then return nil end
        playerKey = name .. "-" .. realm
    end
    return playerKey
end

-- This character's table in chars, created on first use. Nil until the player's
-- name and realm are known.
function Database:Char()
    local db, key = ns.db, self:PlayerKey()
    if not db or not key then return nil end
    local char = db.chars[key]
    if not char then
        char = {}
        db.chars[key] = char
    end
    return char
end

function Database:CountCharacters()
    local n = 0
    if ns.db then
        for _ in pairs(ns.db.chars) do n = n + 1 end
    end
    return n
end
