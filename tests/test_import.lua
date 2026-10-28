-- GB-043: custom lists from Wowhead gear-planner links. The decoder vectors are the
-- pipeline's own (tools/pipeline/test_pipeline.py), so the Lua and Python readers agree.

return function(T, H)
    local BALANCED = "A0YT8FMFEwUAABIlIQXwUgUBEwAwH4FAfwmKdwBlKCB9xAIAfmqDQHkWcygAfcggfciFYHkPbTUAfcQgfcRAfd0GQH5W"
        .. "AH3IIH3IhyB5E3qMAH3IiEB99W0uAH3IIH3IiQB96G0KiiB5CWHwAH3EiwB-BW0UjABx9G0UDQCEJQ4AfHKPAIM5Yf6Q"
        .. "AHi-bUeRAH53hNkSAILg"
    local LINK = "https://www.wowhead.com/tbc/gear-planner/paladin/human/" .. BALANCED

    local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    -- URL-safe base64 without padding, the way Wowhead writes it.
    local function Encode(bytes)
        local out, buffer, bits = {}, 0, 0
        for _, byte in ipairs(bytes) do
            buffer = buffer * 256 + byte
            bits = bits + 8
            while bits >= 6 do
                bits = bits - 6
                local divisor = 2 ^ bits
                local index = math.floor(buffer / divisor)
                buffer = buffer % divisor
                out[#out + 1] = ALPHABET:sub(index + 1, index + 1)
            end
        end
        if bits > 0 then
            local index = buffer * 2 ^ (6 - bits)
            out[#out + 1] = ALPHABET:sub(index + 1, index + 1)
        end
        return table.concat(out)
    end

    local function NewListDialog()
        H.Slash("")
        for _, frame in ipairs(H.AllFrames()) do
            if rawget(frame, "tooltip") == "New list" then frame:Click() end
        end
        return _G.GudaBiSNameDialog
    end

    T.case("Decode: the Balanced set, as the pipeline reads it", function()
        local G = H.Boot().GearPlanner
        local decoded = G.Decode(BALANCED)
        local slots = decoded.slots
        T.eq(slots[1].item, 32521, "head")
        T.eq(slots[1].enchant, 35447, "head enchant")
        T.eq(slots[1].gems[1], 25896, "meta gem")
        T.eq(slots[1].gems[2], 32196, "second gem")
        T.eq(slots[2].item, 32362, "neck")
        T.eq(slots[2].enchant, nil, "neck has no enchant")
        T.eq(#slots[2].gems, 0, "no gems")
        T.eq(slots[5].item, 30991, "chest")
        T.eq(slots[5].enchant, 27957, "chest enchant")
        T.eq(#slots[5].gems, 3, "chest gems")
        T.eq(slots[6].gems[1], 32200, "belt gem 1")
        T.eq(slots[6].gems[2], 32200, "belt gem 2")
        T.eq(slots[11].item, 32261, "ring 1")
        T.eq(slots[12].item, 29172, "ring 2")
        T.eq(slots[15].item, 33593, "back")
        T.eq(slots[17].enchant, 34009, "shield enchant")
        local count = 0
        for slot in pairs(slots) do
            count = count + 1
            T.ok(slot ~= 4 and slot ~= 19, "no shirt or tabard in this set")
        end
        T.eq(count, 17, "17 slots")
    end)

    T.case("Decode: item IDs above 65535, signed random suffix, hunter pet block", function()
        local G = H.Boot().GearPlanner
        local code = Encode({ 3, 70, 1, 0xAA,
            0x00, 2, 0x11, 0x22, 0x01, 0x02,
            0x0D, 0x04, 0x4C, 0x8B,
            0x46, 0x00, 0x77, 0xD4, 0xFF, 0xDE })
        local slots = G.Decode(code).slots
        T.eq(slots[13].item, 281739, "high item bits")
        T.eq(slots[6].item, 30676, "suffix item")
        T.eq(slots[6].suffix, -34, "signed suffix")
        T.eq(slots[6].enchant, nil, "no enchant")
    end)

    T.case("Decode: unknown version, damaged codes and non-base64 refused", function()
        local G = H.Boot().GearPlanner
        T.eq(G.Decode("BEYA"), nil, "version 4")
        T.eq(G.Decode(BALANCED:sub(1, -5)), nil, "truncated")
        T.eq(G.Decode("not base64!"), nil, "not base64")
        T.eq(G.Decode("A"), nil, "one character")
    end)

    T.case("ParseLink: TBC links and bare codes; other flavors and other text refused", function()
        local G = H.Boot().GearPlanner
        local code, class = G.ParseLink(LINK, "tbc")
        T.eq(code, BALANCED, "code")
        T.eq(class, "PALADIN", "class")
        code, class = G.ParseLink("wowhead.com/tbc/gear-planner/death-knight/orc/" .. BALANCED, "tbc")
        T.eq(class, "DEATHKNIGHT", "two-word class")
        code, class = G.ParseLink("  " .. BALANCED .. " ", "tbc")
        T.eq(code, BALANCED, "bare code")
        T.eq(class, nil, "no class")
        local _, problem = G.ParseLink("https://www.wowhead.com/classic/gear-planner/paladin/human/" .. BALANCED, "tbc")
        T.eq(problem, "IMPORT_WRONG_FLAVOR", "classic link")
        _, problem = G.ParseLink("https://www.wowhead.com/gear-planner/paladin/human/" .. BALANCED, "tbc")
        T.eq(problem, "IMPORT_WRONG_FLAVOR", "retail link")
        _, problem = G.ParseLink("https://www.wowhead.com/tbc/item=32521", "tbc")
        T.eq(problem, "IMPORT_NOT_LINK", "an item link")
        _, problem = G.ParseLink(LINK, nil)
        T.eq(problem, "IMPORT_WRONG_FLAVOR", "a client without a Wowhead path")
    end)

    T.case("New list with a link: items, enchants and gems imported, selected, chat line", function()
        local ns = H.Boot()
        local dialog = NewListDialog()
        T.ok(dialog.link:IsShown(), "link box")
        dialog.edit:SetText("Prot from Wowhead")
        dialog.link:SetText(LINK)
        dialog.edit:Script("OnEnterPressed")
        T.ok(not dialog:IsShown(), "closed")
        local list = ns.Lists:Current()
        T.ok(list.custom, "custom list selected")
        T.eq(list.name, "Prot from Wowhead", "name")
        T.eq(list.items[1], 32521, "head")
        T.eq(list.enchants[1], 35447, "enchant")
        T.eq(list.gems[1][2], 32196, "gems")
        T.eq(list.gems[2], nil, "no empty gem table")
        T.ok(H.Printed("Imported 17 items into Prot from Wowhead.", true), "chat line")
        T.ok(not H.Printed("imported anyway", true), "same class: no note")
        T.noErrors()
    end)

    T.case("New list with a bad link: red line, dialog stays, nothing created", function()
        local ns = H.Boot()
        local dialog = NewListDialog()
        dialog.link:SetText("https://www.wowhead.com/classic/gear-planner/paladin/human/" .. BALANCED)
        dialog.edit:Script("OnEnterPressed")
        T.ok(dialog:IsShown(), "still open")
        T.ok(dialog.problem:IsShown(), "red line")
        T.eq(dialog.problem.shownText, "That gear-planner link is for another version of the game.", "says why")
        T.eq(next(ns.db.lists or {}), nil, "nothing created")
        dialog.link:SetText("A0Y")
        dialog.link:Script("OnTextChanged")
        T.ok(not dialog.problem:IsShown(), "cleared while typing")
        dialog.edit:Script("OnEnterPressed")
        T.eq(dialog.problem.shownText, "That link is damaged or in a format GudaBiS does not know.", "damaged")
        dialog.link:SetText("")
        dialog.edit:Script("OnEnterPressed")
        T.ok(not dialog:IsShown(), "an empty link box makes an empty list as before")
        T.eq(next(ns.Lists:Current().items), nil, "empty list")
        T.noErrors()
    end)

    T.case("a set for another class imports with a note", function()
        local ns = H.Boot()
        local dialog = NewListDialog()
        dialog.link:SetText("https://www.wowhead.com/tbc/gear-planner/warrior/orc/" .. BALANCED)
        dialog.edit:Script("OnEnterPressed")
        T.ok(ns.Lists:Current().custom, "imported")
        T.ok(H.Printed("imported anyway", true), "note")
    end)
end
