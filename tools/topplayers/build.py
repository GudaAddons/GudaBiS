"""Build Data/Mainline/Lists.lua (the Retail TOC's data) from the gear of the top Mythic+ players (GB-131).

Usage (WSL; the key file is described in api.py):
  python3 tools/topplayers/build.py --check     # the key works: season, week, dungeons
  python3 tools/topplayers/build.py             # all regions, top 50 per spec

How the top players are found (Blizzard has no per-spec ranking of its own):
  1. every connected realm's keystone leaderboard for each of the season's dungeons,
     this week and last week, in each region (US, EU, KR, TW): every run lists its
     players with their spec;
  2. per spec, the CANDIDATES best of them by the rating of their best run;
  3. their real Mythic+ rating from their keystone profile; the TOP best by rating;
  4. their equipment, aggregated per slot (aggregate.py).
A character that cannot be read (renamed, moved, private) is skipped. Finished weeks
are cached for good; this week's leaderboards for 6 hours; ratings and gear for 2 days,
so a rerun the same day costs almost nothing.

The output is sorted, so an unchanged result gives no diff. Never edit it by hand
(RULES.md Rule 7): change the tool and rerun it.
"""

import argparse
import datetime
import importlib.util
import os
import re
import sys
import urllib.parse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import aggregate  # noqa: E402
import api  # noqa: E402


def _pipeline_build():
    """tools/pipeline/build.py, loaded by path: this file has the same name."""
    path = os.path.join(HERE, "..", "pipeline", "build.py")
    spec = importlib.util.spec_from_file_location("pipeline_build", path)
    module = importlib.util.module_from_spec(spec)
    sys.path.insert(0, os.path.dirname(path))
    spec.loader.exec_module(module)
    return module


lua_value = _pipeline_build().lua_value

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = "/mnt/g/addon-data/GudaBis"
REGIONS = ("us", "eu", "kr", "tw")
TOP = 50
CANDIDATES = 150
GEAR_SPARE = 15
WORKERS = 16
HOUR = 3600
DAY = 24 * HOUR

FIELD_ORDER = ["id", "spec", "class", "specID", "tree", "anyPhase", "set", "season", "players", "updated",
               "items", "enchantIDs", "enchantNames", "gems", "alts", "usage", "itemLevels", "itemBonuses"]


def current_season(client, region, cache=True):
    seasons = client.get(region, "/data/wow/mythic-keystone/season/index", "dynamic", cache=cache, max_age=6 * HOUR)
    periods = client.get(region, "/data/wow/mythic-keystone/period/index", "dynamic", cache=cache, max_age=6 * HOUR)
    dungeons = client.get(region, "/data/wow/mythic-keystone/dungeon/index", "dynamic", cache=cache, max_age=DAY)
    season_id = seasons["current_season"]["id"]
    season = client.get(region, f"/data/wow/mythic-keystone/season/{season_id}", "dynamic", cache=cache, max_age=DAY)
    return {
        "season": season_id,
        "name": season_label(season.get("season_name") or ""),
        "period": periods["current_period"]["id"],
        "dungeons": [{"id": d["id"], "name": d["name"]} for d in dungeons["dungeons"]],
    }


def season_label(name):
    """ "Mythic+ Dungeons (Midnight Season 2)" -> "Midnight Season 2" """
    match = re.search(r"\(([^)]+)\)", name)
    return match.group(1) if match else name


def check(client, region):
    info = current_season(client, region, cache=False)
    print(f"key works ({region}): {info['name']} (season {info['season']}), week {info['period']}")


def specs(client):
    """Every playable spec: key, class token, spec ID, tree (index in the class), name."""
    out = {}
    classes = client.get("us", "/data/wow/playable-class/index", "static", max_age=7 * DAY)
    for entry in classes["classes"]:
        detail = client.get("us", f"/data/wow/playable-class/{entry['id']}", "static", max_age=7 * DAY)
        token = re.sub(r"[^A-Z]", "", detail["name"].upper())
        for tree, spec in enumerate(detail["specializations"], start=1):
            name = re.sub(r"[^A-Z]", "", spec["name"].upper())
            out[spec["id"]] = {"key": f"{token}_{name}", "class": token, "specID": spec["id"],
                               "tree": tree, "name": spec["name"]}
    return out


def realm_ids(client, region):
    index = client.get(region, "/data/wow/connected-realm/index", "dynamic", max_age=7 * DAY)
    return [int(re.search(r"/connected-realm/(\d+)", r["href"]).group(1)) for r in index["connected_realms"]]


def candidates(client, region, period, report):
    """{specID: {(region, realm, name): best run rating}} from this week and last week."""
    found = defaultdict(dict)
    realms = realm_ids(client, region)
    boards = client.get(region, f"/data/wow/connected-realm/{realms[0]}/mythic-leaderboard/index", "dynamic",
                        max_age=DAY)
    dungeon_ids = [b["id"] for b in boards.get("current_leaderboards", [])]
    jobs = [(realm, dungeon, week, max_age) for realm in realms for dungeon in dungeon_ids
            for week, max_age in ((period, 6 * HOUR), (period - 1, None))]

    def board(job):
        realm, dungeon, week, max_age = job
        return client.get(region, f"/data/wow/connected-realm/{realm}/mythic-leaderboard/{dungeon}/period/{week}",
                          "dynamic", max_age=max_age)

    with ThreadPoolExecutor(WORKERS) as workers:
        boards_read = list(workers.map(board, jobs))
    for board_data in boards_read:
        for group in (board_data or {}).get("leading_groups") or []:
            rating = (group.get("mythic_rating") or {}).get("rating") or 0
            for member in group.get("members") or []:
                profile = member.get("profile") or {}
                spec_id = (member.get("specialization") or {}).get("id")
                realm_slug = (profile.get("realm") or {}).get("slug")
                if not (spec_id and realm_slug and profile.get("name")):
                    continue
                key = (region, realm_slug, profile["name"].lower())
                if rating > found[spec_id].get(key, 0):
                    found[spec_id][key] = rating
    report.append(f"{region}: {len(realms)} realm groups, {len(dungeon_ids)} dungeons")
    return found


def character_path(key, what):
    """Realm slugs and names can hold any letter (KR, TW, accented EU realms): encoded."""
    region, realm, name = key
    return region, f"/profile/wow/character/{urllib.parse.quote(realm)}/{urllib.parse.quote(name)}/{what}"


# One character that cannot be read (network trouble after the client's retries) is
# skipped like a missing one; it never stops the build.
def rating_of(client, key):
    region, path = character_path(key, "mythic-keystone-profile")
    try:
        profile = client.get(region, path, "profile", max_age=2 * DAY)
    except api.ApiError:
        return 0
    return ((profile or {}).get("current_mythic_rating") or {}).get("rating") or 0


def gear_of(client, key):
    region, path = character_path(key, "equipment")
    try:
        equipment = client.get(region, path, "profile", max_age=2 * DAY)
    except api.ApiError:
        return None
    return aggregate.equipped(equipment) if equipment else None


def render(lists, season, updated):
    out = [
        "-- Generated by tools/topplayers/build.py from the Blizzard Battle.net API: the gear of",
        f"-- the top {TOP} Mythic+ players of each spec ({season}, {updated}). Do not edit by hand:",
        "-- change the tool and rerun it (RULES.md Rule 7).",
        "-- Slots are INVSLOT numbers; enchantIDs are SpellItemEnchantment IDs (the number in an",
        "-- item link) with their names; gems are item IDs in socket order; usage[slot] counts the",
        "-- players wearing the #1 item and each alternative, in that order.",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Data:Register({",
        '    flavor = "Retail",',
        f'    source = "Top {TOP} Mythic+ players (Blizzard API)",',
        "    lists = {",
    ]
    for entry in sorted(lists, key=lambda e: e["id"]):
        out.append("        {")
        for field in FIELD_ORDER:
            value = entry.get(field)
            if value is None or value == {}:
                continue
            out.append(f"            {field} = {lua_value(value, 3)},")
        out.append("        },")
    out += ["    },", "})", ""]
    return "\n".join(out)


def build(client, regions, report):
    info = current_season(client, regions[0])
    spec_table = specs(client)
    pool = defaultdict(dict)
    for region in regions:
        region_info = current_season(client, region)
        for spec_id, found in candidates(client, region, region_info["period"], report).items():
            for key, rating in found.items():
                pool[spec_id][key] = max(rating, pool[spec_id].get(key, 0))
    lists = []
    updated = datetime.date.today().isoformat()
    for spec_id, spec in sorted(spec_table.items()):
        found = pool.get(spec_id, {})
        shortlist = sorted(found, key=lambda k: -found[k])[:CANDIDATES]
        with ThreadPoolExecutor(WORKERS) as workers:
            ratings = list(workers.map(lambda k: rating_of(client, k), shortlist))
            rated = [k for r, k in sorted(zip(ratings, shortlist), key=lambda rk: -rk[0]) if r]
            gears = list(workers.map(lambda k: gear_of(client, k), rated[:TOP + GEAR_SPARE]))
        players = [gear for gear in gears if gear][:TOP]
        if not players:
            report.append(f"SKIPPED {spec['key']}: no players found")
            continue
        lists.append(aggregate.build_list(spec, players, info["name"], updated))
        report.append(f"ok {spec['key']}: {len(players)} players")
    return lists, info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", default=os.path.join(DATA_DIR, "blizzard.env"))
    parser.add_argument("--cache", default=os.path.join(DATA_DIR, "Retail", "cache"))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--region", action="append", choices=REGIONS)
    args = parser.parse_args()
    client = api.Client(args.key, args.cache)
    regions = tuple(args.region or REGIONS)
    try:
        if args.check:
            check(client, regions[0])
            return
        report = []
        lists, info = build(client, regions, report)
    except api.ApiError as error:
        sys.exit(f"error: {error}")
    for line in report:
        print(line, file=sys.stderr)
    if not lists:
        sys.exit("no lists built")
    out_dir = os.path.join(ROOT, "Data", "Mainline")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "Lists.lua")
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render(lists, info["name"], datetime.date.today().isoformat()))
    print(f"wrote {out_path}: {len(lists)} list(s); {client.requests} requests, {client.cache_hits} from cache")


if __name__ == "__main__":
    main()
