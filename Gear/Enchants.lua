-- Is the equipped item finished the way the list says (GB-050)?
--
-- What can be checked exactly from an item link:
--   - missing enchant: the list has an enchant for the slot and the equipped item has
--     none (enchant field 0). Whether it is the *right* enchant cannot be told yet: the
--     list stores the enchant's spell ID, the link its SpellItemEnchantment ID, and we
--     have no legitimate source for that mapping (architecture.md section 11, GB-051).
--   - wrong enchant, on lists that carry enchantIDs (Retail top-player lists, GB-131):
--     those are SpellItemEnchantment IDs, the same number as in the link, so a different
--     one is told apart from a missing one (GB-051 stays open for the spell-ID lists).
--   - gems: link gem fields are gem item IDs, like the list's. Compared only while the
--     list's own item is worn, because another item has other sockets.
--
-- Pure part, tested offline: Enchants.ParseLink, Enchants.Check.

local addonName, ns = ...

local Enchants = ns:RegisterModule("Enchants")

-- itemID, enchantID, gem1..gem4 from "item:ID:ENCHANT:GEM1:GEM2:GEM3:GEM4:..."; empty
-- fields read as 0. Nil when there is no item link.
function Enchants.ParseLink(link)
    if type(link) ~= "string" then return nil end
    local fields = link:match("item:([%-%d:]+)")
    if not fields then return nil end
    local values = {}
    for value in (fields .. ":"):gmatch("([^:]*):") do
        values[#values + 1] = tonumber(value) or 0
    end
    return values[1], values[2] or 0, values[3] or 0, values[4] or 0, values[5] or 0, values[6] or 0
end

-- The state of one slot against a list, for the equipped item's link:
--   { missingEnchant = bool, wrongEnchant = bool, gems = { [i] = "ok" | "empty" | "wrong" } }
-- Nil when nothing is equipped there or the list has nothing to check.
function Enchants.Check(list, slot, link)
    if not list or not link then return nil end
    local itemID, enchantID, g1, g2, g3, g4 = Enchants.ParseLink(link)
    if not itemID then return nil end
    local wantEnchant = list.enchants and list.enchants[slot]
    local wantEnchantID = list.enchantIDs and list.enchantIDs[slot]
    local wantGems = list.gems and list.gems[slot]
    local result = {
        missingEnchant = (wantEnchant ~= nil or wantEnchantID ~= nil) and enchantID == 0,
        wrongEnchant = wantEnchantID ~= nil and enchantID ~= 0 and enchantID ~= wantEnchantID,
        gems = {},
    }
    if wantGems and itemID == list.items[slot] then
        local have = { g1, g2, g3, g4 }
        for i, gemID in ipairs(wantGems) do
            if have[i] == 0 then
                result.gems[i] = "empty"
            elseif have[i] == gemID then
                result.gems[i] = "ok"
            else
                result.gems[i] = "wrong"
            end
        end
    end
    return result
end

function Enchants:ForSlot(list, slot)
    return Enchants.Check(list, slot, GetInventoryItemLink("player", slot))
end
