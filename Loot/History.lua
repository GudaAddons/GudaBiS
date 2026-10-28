-- Loot history (GB-071): the drops of the last 5 raids and the last 5 dungeons, kept
-- account-wide in GudaBiS_DB.history with the character each session was played on.
--
-- A raid session is one lockout: the same character in the same raid until its lockout
-- resets (GetSavedInstanceInfo), or, before a boss is down and there is no lockout yet,
-- until STALE_SECONDS without a drop. A dungeon session lasts until the character
-- enters a different instance or the instance is reset.
--
-- Recorded, only inside a raid or dungeon and only while in a group (RULES.md Rule 1):
--   - who received what, from CHAT_MSG_LOOT read with Blizzard's own LOOT_ITEM*
--     templates in the client's language, never with words of ours (Rule 6)
--   - drops seen before anyone has them: Blizzard group-loot rolls, and the items Detect
--     matched in the loot master's links; they show as "seen" until someone receives them
-- Epic and better in raids, rare and better in dungeons; an item on the character's
-- lists is always kept. Each entry remembers how it matched at the time (BiS, alt, OS).
--
--   History.Quality(link) -> 0..7 from the link's color, or nil
--   History.Keep(kind, quality, matched) -> boolean
--   History.ParseLoot(message) -> link, winner ("" = the player) or nil
--   History:Sessions(kind[, char]) -> newest first
--   History:Characters() -> character keys with a session, sorted

local addonName, ns = ...

local History = ns:RegisterModule("History")

local MAX_SESSIONS = 5
local MAX_DROPS = 300
local STALE_SECONDS = 6 * 60 * 60
local SEEN_WINDOW = 120

local KINDS = { raid = "raids", party = "dungeons" }
local MIN_QUALITY = { raids = 4, dungeons = 3 }

local QUALITY_COLORS = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}

local current

function History.Quality(link)
    local color = type(link) == "string" and link:match("^|c%x%x(%x%x%x%x%x%x)")
    return color and QUALITY_COLORS[color:lower()] or nil
end

function History.Keep(kind, quality, matched)
    if matched then return true end
    return quality ~= nil and quality >= (MIN_QUALITY[kind] or 99)
end

-- A Blizzard template ("%s receives loot: %s.", or "%2$s ... %1$s" in some languages)
-- as an anchored Lua pattern, plus which format argument each capture holds. %s
-- arguments are captured; %d ones (stack counts) are matched and skipped.
function History.Pattern(template)
    if type(template) ~= "string" then return nil end
    local pattern, order, nextArg, pos = { "^" }, {}, 1, 1
    while pos <= #template do
        local s, e, index, kind = template:find("%%(%d*)%$?([sd])", pos)
        local literal = template:sub(pos, (s or #template + 1) - 1)
        pattern[#pattern + 1] = (literal:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
        if not s then break end
        local arg = tonumber(index) or nextArg
        nextArg = arg + 1
        if kind == "s" then
            pattern[#pattern + 1] = "(.+)"
            order[#order + 1] = arg
        else
            pattern[#pattern + 1] = "%d+"
        end
        pos = e + 1
    end
    pattern[#pattern + 1] = "$"
    return table.concat(pattern), order
end

local lootPatterns

local function AddPatterns(templates, self)
    for _, template in ipairs(templates) do
        local pattern, order = History.Pattern(template)
        if pattern then
            lootPatterns[#lootPatterns + 1] = { pattern = pattern, order = order, self = self }
        end
    end
end

local function LootPatterns()
    if lootPatterns then return lootPatterns end
    lootPatterns = {}
    AddPatterns({ LOOT_ITEM_MULTIPLE, LOOT_ITEM }, false)
    AddPatterns({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF }, true)
    return lootPatterns
end

local captured = {}

function History.ParseLoot(message)
    if type(message) ~= "string" or not message:find("|Hitem:", 1, true) then return nil end
    for _, entry in ipairs(LootPatterns()) do
        local a, b = message:match(entry.pattern)
        if a then
            wipe(captured)
            captured[entry.order[1]] = a
            if entry.order[2] then captured[entry.order[2]] = b end
            if entry.self then return captured[1], "" end
            return captured[2], captured[1]
        end
    end
    return nil
end

local function Store()
    return ns.db and ns.db.history
end

local function LockoutReset(name)
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    for i = 1, GetNumSavedInstances() do
        local savedName, _, reset, _, locked, _, _, isRaid = GetSavedInstanceInfo(i)
        if savedName == name and locked and isRaid and reset and reset > 0 then
            return time() + reset
        end
    end
    return nil
end

local function Continues(session, char)
    if not session or session.char ~= char or session.id ~= current.id then return false end
    if current.kind == "dungeons" then return not session.closed end
    local now = time()
    if session.reset then return now < session.reset end
    return now - session.last < STALE_SECONDS
end

local function CurrentSession()
    local store, char = Store(), ns.Database:PlayerKey()
    if not (store and current and char) then return nil end
    local list = store[current.kind]
    local session = list[1]
    if not Continues(session, char) then
        session = {
            id = current.id, name = current.name, difficulty = current.difficulty,
            char = char, started = time(), drops = {},
        }
        table.insert(list, 1, session)
        for i = #list, MAX_SESSIONS + 1, -1 do list[i] = nil end
    end
    session.last = time()
    if current.kind == "raids" then session.reset = LockoutReset(session.name) or session.reset end
    return session
end

local function Changed()
    ns.Events:Fire("GBIS_HISTORY_CHANGED")
end

local function Unawarded(session, itemID)
    for _, drop in ipairs(session.drops) do
        if drop.itemID == itemID and drop.winner == nil then return drop end
    end
    return nil
end

local function Add(link, winner)
    if not current then return end
    local itemID = ns.Match.ItemIDFromLink(link)
    if not itemID then return end
    local match = ns.Match:Item(itemID, true)
    if not History.Keep(current.kind, History.Quality(link), match ~= nil) then return end
    local session = CurrentSession()
    if not session then return end
    local drop = Unawarded(session, itemID)
    if drop and not winner and time() - drop.at < SEEN_WINDOW then return end
    if drop and winner then
        drop.winner = winner
    elseif #session.drops < MAX_DROPS then
        session.drops[#session.drops + 1] = {
            itemID = itemID, link = link, winner = winner, at = time(),
            role = match and match.role, rank = match and match.rank,
        }
    end
    Changed()
end

-- A drop someone may still receive: shows as "seen" until CHAT_MSG_LOOT names a winner.
-- The same item seen again within SEEN_WINDOW (a group-loot roll and the leader linking
-- it) is one drop.
function History:Seen(link)
    Add(link, nil)
end

local function OnLoot(_, message)
    if not current then return end
    local link, winner = History.ParseLoot(message)
    if not link then return end
    if winner == "" then winner = UnitName("player") end
    Add(link, ns.Detect.ShortName(winner))
end

local function OnLootRoll(_, rollID)
    if current then History:Seen(GetLootRollItemLink(rollID)) end
end

local function CloseDungeon()
    local store = Store()
    local session = store and store.dungeons[1]
    if session then session.closed = true end
end

local resetPattern

local function OnSystem(_, message)
    if not current or current.kind ~= "dungeons" then return end
    resetPattern = resetPattern or History.Pattern(INSTANCE_RESET_SUCCESS)
    if resetPattern and type(message) == "string" and message:match(resetPattern) then CloseDungeon() end
end

local function OnEnteringWorld()
    local name, instanceType, _, difficulty, _, _, _, instanceID = GetInstanceInfo()
    local kind = KINDS[instanceType]
    local store = Store()
    local last = store and store.dungeons[1]
    if kind and last and not last.closed and (kind ~= "dungeons" or last.id ~= instanceID) then
        last.closed = true
    end
    if kind then
        current = { kind = kind, id = instanceID, name = name, difficulty = difficulty }
        if kind == "raids" and RequestRaidInfo then RequestRaidInfo() end
    else
        current = nil
    end
end

function History:Sessions(kind, char)
    local store = Store()
    local out = {}
    if not store then return out end
    for _, session in ipairs(store[kind] or {}) do
        if not char or session.char == char then out[#out + 1] = session end
    end
    return out
end

function History:Characters()
    local seen, out = {}, {}
    local store = Store()
    for _, kind in ipairs({ "raids", "dungeons" }) do
        for _, session in ipairs(store and store[kind] or {}) do
            if not seen[session.char] then
                seen[session.char] = true
                out[#out + 1] = session.char
            end
        end
    end
    table.sort(out)
    return out
end

function History:InInstance()
    return current ~= nil
end

ns.Events:Register("GBIS_INITIALIZED", function()
    ns.Events:Register("PLAYER_ENTERING_WORLD", OnEnteringWorld, "History")
    OnEnteringWorld()
    ns.Events:RegisterGroup("CHAT_MSG_LOOT", OnLoot, "History")
    ns.Events:RegisterGroup("START_LOOT_ROLL", OnLootRoll, "History")
    ns.Events:RegisterGroup("CHAT_MSG_SYSTEM", OnSystem, "History")
end, "History")
