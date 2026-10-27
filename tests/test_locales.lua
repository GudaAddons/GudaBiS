-- RULES.md Rule 6: every English key has a text in every language, with the same
-- format codes and color codes.

return function(T, H)
    local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

    -- Keys whose text may equal the English in some languages: the addon-name banner,
    -- "API", "Phase %d" (German, French) and "Alternatives" (French).
    local SAME_EVERYWHERE = { HELP_HEADER = true, STATUS_API = true, PHASE = true, TOOLTIP_ALTERNATIVES = true }

    local function EnglishTexts()
        local texts = {}
        local file = assert(io.open(H.ROOT .. "/Locales.lua", "r"))
        for line in file:lines() do
            local key, text = line:match('^L%.([%w_]+) = "(.*)"')
            if key then texts[key] = text end
        end
        file:close()
        return texts
    end

    local function Codes(text, pattern)
        local found = {}
        for code in text:gmatch(pattern) do found[#found + 1] = code end
        return table.concat(found, " ")
    end

    T.case("enUS texts load", function()
        local ns = H.Boot()
        T.eq(ns.L.DEBUG_ON, "Debug mode on.", "text")
        T.eq(ns.L.NO_SUCH_KEY, "NO_SUCH_KEY", "missing key shows the key")
    end)

    for _, locale in ipairs(LOCALES) do
        T.case(locale .. ": every key translated, same format and color codes", function()
            local ns = H.Boot({ locale = locale })
            local english = EnglishTexts()
            local count = 0
            for key, text in pairs(english) do
                count = count + 1
                local translated = rawget(ns.L, key)
                T.ok(translated ~= nil, locale .. " text for " .. key)
                if not SAME_EVERYWHERE[key] then
                    T.ok(translated ~= text, locale .. " " .. key .. " is still English")
                end
                T.eq(Codes(translated, "%%[%-%d%.]*[sdf]"), Codes(text, "%%[%-%d%.]*[sdf]"), "format codes of " .. key)
                T.eq(Codes(translated, "|[cr]"), Codes(text, "|[cr]"), "color codes of " .. key)
            end
            T.ok(count >= 10, "English keys read")
            T.noErrors()
        end)
    end

    T.case("every language file is in every TOC", function()
        for _, locale in ipairs(LOCALES) do
            local listed = false
            for _, file in ipairs(H.TocFiles("GudaBiS_TBC.toc")) do
                if file == "Locales_" .. locale .. ".lua" then listed = true end
            end
            T.ok(listed, locale)
        end
    end)
end
