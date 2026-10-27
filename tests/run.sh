#!/usr/bin/env bash
# GudaBiS offline tests. Needs Lua 5.1 (apt install lua5.1).
# From Windows: wsl -d Ubuntu-22.04 -- bash "/mnt/g/Games/Battle.net/World of Warcraft/_anniversary_/Interface/AddOns/GudaBiS/tests/run.sh"
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
checked=0

while IFS= read -r -d '' file; do
    checked=$((checked + 1))
    if ! luac5.1 -p "$file"; then
        failures=$((failures + 1))
    fi
done < <(find "$ROOT" -name '*.lua' -not -path "$ROOT/tests/*" -not -path "$ROOT/tools/*" -print0)
echo "syntax: $checked file(s) checked, $failures failed"

lua5.1 "$ROOT/tests/run.lua" "$ROOT" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
    echo "FAILED"
    exit 1
fi
echo "OK"
