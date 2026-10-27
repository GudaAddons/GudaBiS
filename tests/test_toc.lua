-- RULES.md Rule 2: every TOC lists every shared file, and only its own flavor's data.

return function(T, H)
    local function ListDir(cmd)
        local out = {}
        local pipe = io.popen(cmd)
        for line in pipe:lines() do out[#out + 1] = line end
        pipe:close()
        return out
    end

    local tocs = ListDir('cd "' .. H.ROOT .. '" && ls *.toc')

    local shared = {}
    for _, path in ipairs(ListDir('cd "' .. H.ROOT .. '" && find . -name "*.lua" -not -path "./tests/*" -not -path "./tools/*" -not -path "./Data/*/*" | sed "s#^./##" | sort')) do
        shared[#shared + 1] = path
    end

    T.case("at least the TBC TOC exists", function()
        local found = false
        for _, toc in ipairs(tocs) do
            if toc == "GudaBiS_TBC.toc" then found = true end
        end
        T.ok(found, "GudaBiS_TBC.toc")
    end)

    for _, toc in ipairs(tocs) do
        T.case(toc .. " lists every shared file exactly once, and they exist", function()
            local listed = {}
            for _, file in ipairs(H.TocFiles(toc)) do
                T.ok(not listed[file], "listed twice: " .. file)
                listed[file] = true
                local handle = io.open(H.ROOT .. "/" .. file, "r")
                T.ok(handle ~= nil, "missing file: " .. file)
                if handle then handle:close() end
            end
            for _, file in ipairs(shared) do
                T.ok(listed[file], toc .. " does not list " .. file)
            end
        end)

        T.case(toc .. " loads only its own flavor's data", function()
            local flavor = toc:match("^GudaBiS_(.+)%.toc$")
            for _, file in ipairs(H.TocFiles(toc)) do
                local dataFlavor = file:match("^Data/([^/]+)/")
                if dataFlavor then
                    T.eq(dataFlavor, flavor, "data folder in " .. toc)
                end
            end
        end)

        T.case(toc .. " ends with Core/Main.lua", function()
            local files = H.TocFiles(toc)
            T.eq(files[#files], "Core/Main.lua", "last file")
        end)
    end
end
