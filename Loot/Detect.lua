-- Where BiS drops are noticed (GB-060/061/062). Every listener here is group-only
-- (Events:RegisterGroup), so none of this costs anything while solo.
--
-- Blizzard group loot: START_LOOT_ROLL. The Need/Greed popup gets our glowing badge
-- and the proc glow on its item icon (author, 2026-10-28: the item, not the button);
-- no popup of ours.
--
-- Chat, from the raid leader, an assistant or the master looter only (anyone else
-- linking an item is ignored), matched by item ID inside the links, never by the words
-- around them (RULES.md Rule 6: the loot master writes in their own language):
--   - a link in raid, party or raid warning -> "Your BiS dropped!" toast
--   - a link in raid warning                -> also "Rolling now", unless Gargul or
--                                              RCLootCouncil shows its own roll window
--                                              for that item (checked a second later)
-- One item is announced several times while it is handed out: at loot, at the roll call
-- and with the winner (author, 2026-10-29: three "dropped" toasts for one wishlist item).
-- So an item toasts once per ITEM_WINDOW, and a raid warning with it counts as its roll
-- call once per ITEM_WINDOW too, which also keeps auto-roll from rolling again when the
-- winner is announced in raid warning. A second copy of the same item within that time
-- gets no second alert.
--
-- Every matched drop also goes to AutoRoll (GB-070), whether or not alerts are on; a
-- raid-warning item it rolled for gets no "Rolling now" popup.
--
-- On clients where group chat can be a secret value (ns.Features.ChatLockdown), chat is
-- skipped while C_ChatInfo.InChatMessagingLockdown() is true.

local addonName, ns = ...

local Detect = ns:RegisterModule("Detect")

local Match = ns.Match

local ITEM_WINDOW = 300
local OTHER_WINDOW_DELAY = 1
local MIN_SECONDS, MAX_SECONDS = 5, 120

local CHAT_EVENTS = {
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
}

local lastDropped = {}
local lastRollCall = {}

local function Recent(seen, itemID, now)
    return seen[itemID] ~= nil and now - seen[itemID] <= ITEM_WINDOW
end

local function ShortName(name)
    if not name then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return (name:match("^([^%-]+)")) or name
end
Detect.ShortName = ShortName

local function MasterLooterName()
    local api = C_PartyInfo
    if not (api and api.GetLootMethod) then return nil end
    local _, partyID, raidID = api.GetLootMethod()
    if raidID and GetRaidRosterInfo then
        return (GetRaidRosterInfo(raidID))
    end
    if partyID then
        return partyID == 0 and UnitName("player") or UnitName("party" .. partyID)
    end
    return nil
end

local function IsMasterLooter(name)
    local ml = ShortName(MasterLooterName())
    return ml ~= nil and ml == name
end

function Detect.IsLootAuthority(sender)
    local name = ShortName(sender)
    if not name then return false end
    if UnitIsGroupLeader(name) or UnitIsGroupAssistant(name) then return true end
    return IsMasterLooter(name)
end

-- Who may call a roll that auto-roll answers: the leader or the master looter only.
function Detect.IsLootLeader(sender)
    local name = ShortName(sender)
    if not name then return false end
    return UnitIsGroupLeader(name) or IsMasterLooter(name)
end

-- The roll time read from a raid-warning text: the first number from 5 to 120 outside
-- the item links that is not a roll range (99, 100). Nil when there is none.
function Detect.RollSeconds(message)
    local text = message:gsub("|H.-|h.-|h", "")
    for number in text:gmatch("%d+") do
        local n = tonumber(number)
        if n >= MIN_SECONDS and n <= MAX_SECONDS and n ~= 99 and n ~= 100 then
            return n
        end
    end
    return nil
end

local function ChatLocked()
    if not ns.Features.ChatLockdown then return false end
    local api = C_ChatInfo
    if not (api and api.InChatMessagingLockdown) then return false end
    local ok, locked = pcall(api.InChatMessagingLockdown)
    return ok and locked == true
end

local function OtherAddonRolls(itemID)
    return ns.GargulBridge:IsRolling(itemID) or ns.RCLootCouncilBridge:IsShowing(itemID)
end

local function OnChat(event, message, sender)
    local alerts = ns.Alerts:Enabled()
    if not (alerts or ns.AutoRoll:Active()) or type(message) ~= "string" then return end
    if not message:find("|Hitem:", 1, true) or ChatLocked() then return end
    if not Detect.IsLootAuthority(sender) then return end
    local now = GetTime()
    local warning = event == "CHAT_MSG_RAID_WARNING"
    for link in message:gmatch("|c%x+|Hitem:.-|h.-|h|r") do
        local itemID = Match.ItemIDFromLink(link)
        local match = itemID and Match:Item(itemID, nil, link)
        if match then
            if alerts and not Recent(lastDropped, itemID, now) then
                ns.Alerts:Dropped(link, match)
                lastDropped[itemID] = now
            end
            ns.History:Seen(link)
            if warning and not Recent(lastRollCall, itemID, now) then
                lastRollCall[itemID] = now
                local seconds = Detect.RollSeconds(message)
                C_Timer.After(OTHER_WINDOW_DELAY, function()
                    if OtherAddonRolls(itemID) then return end
                    if ns.AutoRoll:RollCall(link, match, sender, message) then return end
                    if ns.Alerts:Enabled() then ns.Alerts:Rolling(link, match, seconds) end
                end)
            end
        end
    end
end

-- Blizzard fills its roll frame in the same event, so the badge waits a frame.
local function FindRollFrame(rollID)
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame:IsShown() and frame.rollID == rollID then return frame, i end
    end
    return nil
end

local function OnStartLootRoll(_, rollID)
    local alerts = ns.Alerts:Enabled()
    if not (alerts or ns.AutoRoll:Active()) then return end
    local link = GetLootRollItemLink(rollID)
    local itemID = Match.ItemIDFromLink(link)
    local match = itemID and Match:Item(itemID, nil, link)
    if not match then return end
    ns.AutoRoll:GroupLoot(rollID, link, match)
    if not alerts then return end
    C_Timer.After(0, function()
        local frame, index = FindRollFrame(rollID)
        if not frame then return end
        ns.Alerts:Badge(frame, match, ns.Compat.GetGroupLootIcon(index))
        ns.Alerts:Sound()
    end)
end

ns.Events:Register("GBIS_INITIALIZED", function()
    ns.Events:RegisterGroup("START_LOOT_ROLL", OnStartLootRoll, "Detect")
    for _, event in ipairs(CHAT_EVENTS) do
        ns.Events:RegisterGroup(event, OnChat, "Detect")
    end
end, "Detect")
