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

    local function PackageName()
        local handle = assert(io.open(H.ROOT .. "/.pkgmeta", "r"))
        local name
        for line in handle:lines() do
            name = name or line:match("^package%-as:%s*(%S+)")
        end
        handle:close()
        return name
    end

    local function Metadata(toc)
        local fields = {}
        local handle = assert(io.open(H.ROOT .. "/" .. toc, "r"))
        for line in handle:lines() do
            local key, value = line:gsub("\r", ""):match("^##%s*([^:]+):%s*(.-)%s*$")
            if key then fields[key] = value end
        end
        handle:close()
        return fields
    end

    local packageName = PackageName()

    T.case(".pkgmeta names the package GudaBiS", function()
        T.eq(packageName, "GudaBiS", "package-as")
    end)

    -- The addon folder (package-as) must match every TOC's base name, or the
    -- client and CurseForge reject it. Flavor TOCs only: no plain GudaBiS.toc.
    for _, toc in ipairs(tocs) do
        T.case(toc .. " is named <package-as>_<Flavor>.toc", function()
            T.ok(toc:match("^" .. packageName .. "_%a+%.toc$") ~= nil, toc)
        end)

        T.case(toc .. " ships the release metadata", function()
            local fields = Metadata(toc)
            T.eq(fields["Version"], "@project-version@", "Version")
            T.eq(fields["IconTexture"], "Interface\\AddOns\\" .. packageName .."\\Assets\\logo.png", "IconTexture")
            T.eq(fields["X-Wago-ID"], "kGr98MKy", "X-Wago-ID")
            T.eq(fields["SavedVariables"], "GudaBiS_DB", "SavedVariables")
            T.eq(fields["Category"], "Guda", "grouped with the other Guda addons")
        end)
    end

    T.case("the two Forever TOCs (_Forever and _Camelot) are the same file", function()
        local function Read(name)
            local handle = assert(io.open(H.ROOT .. "/" .. name, "rb"))
            local text = handle:read("*a")
            handle:close()
            return text
        end
        T.ok(Read("GudaBiS_Forever.toc") == Read("GudaBiS_Camelot.toc"), "GudaBiS_Forever.toc and GudaBiS_Camelot.toc differ")
    end)

    T.case("the TOC icon file exists", function()
        local handle = io.open(H.ROOT .. "/Assets/logo.png", "rb")
        T.ok(handle ~= nil, "Assets/logo.png")
        if handle then handle:close() end
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

        -- Forever ships under both suffixes its client may read (M12, GB-150), so
        -- GudaBiS_Camelot.toc loads Data/Forever.
        T.case(toc .. " loads only its own flavor's data", function()
            local flavor = toc:match("^GudaBiS_(.+)%.toc$")
            if flavor == "Camelot" then flavor = "Forever" end
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
