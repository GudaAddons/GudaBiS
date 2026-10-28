-- Offline test runner (Lua 5.1, the WoW Lua version).
-- Usage: tests/run.sh   (or: lua5.1 tests/run.lua <addon root>)

local print = print

local ROOT = assert(arg[1], "usage: lua5.1 tests/run.lua <addon root>")
package.path = ROOT .. "/tests/?.lua;" .. package.path

local H = require("harness")

local T = { passed = 0, failed = 0, current = "" }

local function Fail(message)
    error({ gbisFailure = true, message = message }, 0)
end

function T.eq(actual, expected, label)
    if actual ~= expected then
        Fail(string.format("%s: got %s, want %s", label or "value", tostring(actual), tostring(expected)))
    end
end

function T.ok(condition, label)
    if not condition then Fail(label or "expected true") end
end

function T.noErrors()
    if #H.errors > 0 then
        Fail("addon raised errors:\n      " .. table.concat(H.errors, "\n      "))
    end
end

function T.case(name, fn)
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        local message = type(err) == "table" and err.message or tostring(err)
        print(string.format("  FAIL %s > %s\n      %s", T.current, name, message))
    end
end

local SUITES = {
    "test_toc", "test_expansion", "test_events", "test_commands", "test_database", "test_log",
    "test_probe", "test_data", "test_panel", "test_owned", "test_lists", "test_enchants", "test_loot", "test_autoroll", "test_history", "test_settings", "test_locales",
}

for _, suite in ipairs(SUITES) do
    T.current = suite
    local before = T.failed
    require(suite)(T, H)
    print(string.format("%s %s", T.failed == before and "ok  " or "FAIL", suite))
end

print(string.format("\ntests: %d passed, %d failed", T.passed, T.failed))
os.exit(T.failed == 0 and 0 or 1)
