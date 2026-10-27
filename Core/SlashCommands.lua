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

SlashCommands:Register("debug", function(args)
    local mode = args[1] and args[1]:lower()
    if mode == "on" then
        ns.debugMode = true
    elseif mode == "off" then
        ns.debugMode = false
    else
        ns.debugMode = not ns.debugMode
    end
    ns:Print(ns.debugMode and L.DEBUG_ON or L.DEBUG_OFF)
end, L.HELP_DEBUG)

SLASH_GUDABIS1 = "/gbis"
SlashCmdList.GUDABIS = function(input)
    SlashCommands:Run(input)
end
