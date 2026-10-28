-- /gbis. Modules register their own subcommands:
--   ns.SlashCommands:Register("probe", handler, L.HELP_PROBE)
-- handler(args) receives the whitespace-separated words after the command.
-- /gbis alone runs "show" once the panel registers it, and "help" until then.

local addonName, ns = ...
local L = ns.L

local SlashCommands = ns:RegisterModule("SlashCommands")

local handlers = {}
local order = {}

function SlashCommands:Register(name, handler, help)
    if not handlers[name] then
        order[#order + 1] = name
    end
    handlers[name] = { run = handler, help = help }
end

function SlashCommands:PrintHelp()
    print(L.HELP_HEADER)
    for _, name in ipairs(order) do
        local help = handlers[name].help
        if help then print(help) end
    end
end

local function Tokenize(input)
    local args = {}
    for word in (input or ""):gmatch("%S+") do
        args[#args + 1] = word
    end
    return args
end

function SlashCommands:Run(input)
    local args = Tokenize(input)
    local command = table.remove(args, 1)
    command = command and command:lower() or (handlers.show and "show" or "help")
    local entry = handlers[command]
    if not entry then
        ns:Print(string.format(L.UNKNOWN_COMMAND, command))
        return
    end
    local ok, err = pcall(entry.run, args)
    if not ok then ns:Error(err) end
end

SlashCommands:Register("help", function()
    SlashCommands:PrintHelp()
end)

local function YesNo(value)
    return value and (YES or "yes") or (NO or "no")
end

-- Feature flags and resolved API sources as one line each, so a bug report from an
-- untested client carries everything needed to see which branch it took.
SlashCommands:Register("status", function()
    local E = ns.Expansion
    ns:Print(string.format(L.STATUS_CLIENT, E.ClientKey, E.InterfaceVersion))
    local parts = {}
    for i, name in ipairs(E.FeatureNames) do
        parts[i] = name .. "=" .. YesNo(ns.Features[name])
    end
    ns:Print(string.format(L.STATUS_FEATURES, table.concat(parts, ", ")))
    local Compat = ns.Compat
    wipe(parts)
    for i, name in ipairs(Compat.resolvedNames) do
        parts[i] = name .. "=" .. Compat.resolvedSource[name]
    end
    ns:Print(string.format(L.STATUS_API, table.concat(parts, ", ")))
    local Data = ns.Data
    if Data and Data.flavor and Data.defaultPhase then
        ns:Print(string.format(L.STATUS_DATA, Data.flavor, Data:Count(), #Data:Specs(), Data.defaultPhase))
    elseif Data and Data.flavor then
        ns:Print(string.format(L.STATUS_DATA_NO_PHASES, Data.flavor, Data:Count(), #Data:Specs()))
    end
    local db = ns.db
    if db then
        ns:Print(string.format(L.STATUS_DB, db.schema, YesNo(ns.Database.restoredFromDisk),
            db.meta.loadCount, ns.Database:CountCharacters()))
    end
end, L.HELP_STATUS)

SlashCommands:Register("debug", function(args)
    local mode = args[1] and args[1]:lower()
    if mode == "on" then
        ns.debugMode = true
    elseif mode == "off" then
        ns.debugMode = false
    else
        ns.debugMode = not ns.debugMode
    end
    ns.Database:SetSetting("debug", ns.debugMode)
    ns:Print(ns.debugMode and L.DEBUG_ON or L.DEBUG_OFF)
end, L.HELP_DEBUG)

SLASH_GUDABIS1 = "/gbis"
SlashCmdList.GUDABIS = function(input)
    SlashCommands:Run(input)
end
