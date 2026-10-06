"""Build NaowhForever_Completo/Data/NaowhForever_CompletoQuests.lua: every quest of every zone, with its chain.

A zone page (/forever/zone=<areaID>) lists the quests tied to the zone in its "quests"
listview; the ones whose category is the zone itself are the zone's own quests (the rest are
class, profession and holiday quests that merely start there). Each quest page
(/forever/quest=<id>) then gives its chain, the "Series" box parsed the same way as
Tools/build_quest_chains.py does, and where its quest giver stands.

Answers are cached, so a run that dies on Wowhead's rate limit resumes where it stopped:
completo_zones.json (each zone's quest rows) and completo_quests.json (each quest's
{ chain, start }). Delete an entry to fetch it again. --offline writes from the caches only.

Usage: python Tools/build_completo_quests.py [--offline]
"""
import html
import json
import re
import sys
import time
import unicodedata
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wowhead  # noqa: E402
from build_quest_chains import ZONE_MAP, parse, parse_start  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "NaowhForever_Completo" / "Data" / "NaowhForever_CompletoQuests.lua"
ZONES = Path(__file__).resolve().parent / "completo_zones.json"
QUESTS = Path(__file__).resolve().parent / "completo_quests.json"
# Wowhead answers 403 after ~125 pages at 1.5s apart; 5s ran clean.
GAP = 4


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")


def zone_name(page):
    info = re.search(r"g_pageInfo = (\{.*?\});", page)
    if info:
        name = json.loads(info.group(1)).get("name")
        if name:
            return name
    title = re.search(r"<title>([^<]*?) - Zone", page)
    return html.unescape(title.group(1)) if title else None


def fetch_zone(area):
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/zone={area}")
    rows = []
    for q in wowhead.listview(page, "quests"):
        if q.get("category") != area:
            continue
        rows.append({k: q[k] for k in ("id", "name", "level", "reqlevel", "side", "reqrace",
                                         "reqclass", "category2") if k in q})
    return {"name": zone_name(page), "quests": rows}


# A Series row Wowhead fills with "<UNUSED>" (quests 810, 3515) is a step that no longer
# exists: left out of the page before it is read.
UNUSED = re.compile(r"<tr><th>\d+\.</th><td><div><b>&lt;UNUSED&gt;</b></div></td></tr>|"
                    r"<tr><th>\d+\.</th><td><div><b><UNUSED></b></div></td></tr>")


def fetch_quest(quest_id):
    page = UNUSED.sub("", wowhead.fetch(f"{wowhead.WOWHEAD}/quest={quest_id}"))
    return {"chain": parse(quest_id, page), "start": parse_start(page)}


# The maps Forever redrew, and Wowhead still gives classic positions on: each map's world
# bounds (minX, minY, maxX, maxY, from the game's UiMapAssignment on wago.tools) in Classic
# Era 1.15.9.70003 and in Forever 1.60.1.70205. The world did not move, only the maps, so a
# classic position goes to the world and back onto Forever's map.
REDRAWN_BOUNDS = {
    1453: ((-9175.205, 36.701, -8278.851, 1380.971), (-9154.170, -14.584, -7995.830, 1722.920)),
    1412: ((-3697.917, -3089.583, -272.917, 2047.917), (-3835.416, -3675.0, 266.666, 2479.167)),
    1433: ((-10022.916, -3741.667, -8575.0, -1570.833), (-10022.916, -3852.084, -8575.0, -1681.25)),
    1423: ((1218.75, -6056.25, 3800.0, -2185.417), (825.0, -6558.334, 3691.667, -2256.25)),
}


def forever_spot(map_id, x, y):
    """A Wowhead position (percent) on Forever's map: the same on maps Forever left alone."""
    if map_id not in REDRAWN_BOUNDS:
        return x, y
    (cx0, cy0, cx1, cy1), (fx0, fy0, fx1, fy1) = REDRAWN_BOUNDS[map_id]
    # A map's x runs along the world's Y axis from its max down, its y along X from its max down.
    world_y = cy1 - x / 100 * (cy1 - cy0)
    world_x = cx1 - y / 100 * (cx1 - cx0)
    return (fy1 - world_y) / (fy1 - fy0) * 100, (fx1 - world_x) / (fx1 - fx0) * 100


def lua_string(s):
    # ASCII only, as the addon files must be: an accented letter keeps its base letter.
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def chains_of(quests, known):
    """Each chain once: Wowhead's Series, cut to the quests the data knows, largest first.
    A Series that is wholly inside a bigger one is the same chain seen from a later step."""
    seen = {}
    for entry in quests.values():
        chain = entry and entry.get("chain")
        if not chain:
            continue
        steps = [[i for i in step if i in known] for step in chain["chain"]]
        steps = [s for s in steps if s]
        if len(steps) < 2:
            continue
        key = frozenset(i for s in steps for i in s)
        seen.setdefault(key, steps)
    out = []
    for key, steps in sorted(seen.items(), key=lambda kv: -len(kv[0])):
        if any(key < other for other in seen if other is not key):
            continue
        if any(key & frozenset(i for s in o for i in s) for o in out):
            # Overlaps a bigger chain already kept: the quests stay in that one.
            continue
        out.append(steps)
    return out


def main():
    offline = "--offline" in sys.argv
    zones, quests, failed = load(ZONES), load(QUESTS), []

    for area in ZONE_MAP:
        if str(area) in zones or offline:
            continue
        try:
            zones[str(area)] = fetch_zone(area)
        except urllib.error.HTTPError as e:
            failed.append(f"zone {area}: {e}")
            continue
        save(ZONES, zones)
        print(f"zone {area} {zones[str(area)]['name']}: {len(zones[str(area)]['quests'])} quests")
        time.sleep(GAP)

    wanted = [q["id"] for z in zones.values() for q in z["quests"]]
    todo = [i for i in wanted if str(i) not in quests]
    print(f"{len(wanted)} quests, {len(todo)} quest pages to fetch")
    if not offline:
        for n, quest_id in enumerate(todo, 1):
            try:
                quests[str(quest_id)] = fetch_quest(quest_id)
            except (urllib.error.HTTPError, ValueError) as e:
                failed.append(f"quest {quest_id}: {e}")
                continue
            save(QUESTS, quests)
            if n % 50 == 0:
                print(f"  {n}/{len(todo)}")
            time.sleep(GAP)

    write(zones, quests)
    for line in failed:
        print("FAILED", line, file=sys.stderr)


def write(zones, quests):
    rows = {q["id"]: (int(area), q) for area, z in zones.items() for q in z["quests"]}
    chains = chains_of(quests, rows)
    lines = [
        "-- Generated by Tools/build_completo_quests.py from Wowhead's Forever zone and quest",
        "-- pages. Do not edit by hand: change the tool and run it again.",
        "local D = {}",
        "_G.NaowhForever.CompletoQuestData = D",
        "",
        "-- Each zone: its uiMapID, name, continent (0 Eastern Kingdoms, 1 Kalimdor) and quests.",
        "D.Zones = {",
    ]
    order = sorted(zones.items(), key=lambda kv: (kv[1]["name"] or ""))
    for area, z in order:
        ids = sorted(q["id"] for q in z["quests"])
        if not ids:
            continue
        conts = [q.get("category2", 0) for q in z["quests"]]
        cont = max(set(conts), key=conts.count)
        lines.append(f"    {{ map = {ZONE_MAP[int(area)]}, name = {lua_string(z['name'])}, "
                     f"continent = {cont}, quests = {{ {', '.join(map(str, ids))} }} }},")
    lines += [
        "}",
        "",
        "-- questID = { name, level, required level, side (1 Alliance, 2 Horde, 3 both),",
        "-- race mask, class mask, start uiMapID, x, y (percent), quest giver }. Positions on the maps Forever",
        "-- redrew are moved from Wowhead's classic ones onto Forever's maps (forever_spot).",
        "D.Quests = {",
    ]
    for qid in sorted(rows):
        area, q = rows[qid]
        start = (quests.get(str(qid)) or {}).get("start")
        spot = "nil, nil, nil, nil"
        if start and start.get("coord") and start["zone"] in ZONE_MAP:
            m = ZONE_MAP[start["zone"]]
            x, y = forever_spot(m, *start["coord"])
            giver = lua_string(start["npc"]) if start.get("npc") else "nil"
            spot = f"{m}, {x:.1f}, {y:.1f}, {giver}"
        lines.append(f"    [{qid}] = {{ {lua_string(q['name'])}, {q.get('level') or 0}, "
                     f"{q.get('reqlevel') or 0}, {q.get('side') or 3}, {q.get('reqrace') or 0}, "
                     f"{q.get('reqclass') or 0}, {spot} }},")
    lines += [
        "}",
        "",
        "-- Each chain's steps in order; a step with more than one quest has faction or class",
        "-- versions of it.",
        "D.Chains = {",
    ]
    for steps in chains:
        lines.append("    { " + ", ".join("{ " + ", ".join(map(str, s)) + " }" for s in steps) + " },")
    lines.append("}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii", "replace"))
    print(f"wrote {OUT.relative_to(ROOT)}: {len(rows)} quests, {len(chains)} chains")


if __name__ == "__main__":
    main()
