"""Build the town map's zone exit arrows from the game's own map art (Tools/wago.py).

Forever has no map link data (C_Map.GetMapLinksForMap returns nothing), so the exits are found
on the map art: a zone's explorable areas (WorldMapOverlay and its tiles) cover the zone itself,
and their edge is the zone's border on its map. Where a road crosses that border was read off
the art by eye, and is written here by hand (EXITS), as a map percentage near the crossing.

The build does the rest from game data: it snaps each crossing onto the border, faces the arrow
out of the zone, places it a step inside, and finds the zone it leads to by stepping across the
border in world yards (UiMapAssignment) into the neighbour whose area is there. A city gate is
written with its city and the arrow's bearing (degrees, 0 north, anticlockwise), and is not
snapped. Where three zones meet, an exit names its neighbour to settle which.

The map tiles are fetched from wago.tools once and kept in Tools/map_art/ (not committed).

Writes QoL/NaowhForever_ZoneExits.lua.

Usage: python Tools/build_zone_exits.py [--build 1.60.1.70205]
"""
import argparse
import math
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

import wago
from build_journal import ROOT, TOOLS, header, write

OUT = ROOT / "QoL" / "NaowhForever_ZoneExits.lua"
ART = TOOLS / "map_art"
W, H = 1002, 668        # a zone map's art in pixels
TILE = 256
COVERED = 100           # overlay alpha above which a pixel is the zone's own
SNAP = 60               # pixels: how far a crossing may be from the border
INSET = 10              # pixels: the arrow sits this far inside the border
STEPS = (40, 80, 150, 250, 400)   # yards across the border to look for the neighbour
SAME = 6                # map percent: two arrows to one zone closer than this are one exit
CITIES = (1453, 1454, 1455, 1456, 1457, 1458)

# uiMapID -> [ (x, y) | (x, y, neighbour) | (x, y, city, bearing) ], in map percent. A road needs
# writing from one side only: the other side's arrow is found from it, unless that side lists
# its own roads to this zone.
EXITS = {
    1411: [(34.5, 42.5), (45.5, 9.5, 1454, 0)],                                       # Durotar
    1412: [(71, 62)],                                                                  # Mulgore
    1413: [(62.7, 19), (34.5, 28.5, 1442), (48.5, 1.5), (40, 59), (44.5, 91), (51.5, 79)],   # The Barrens
    1416: [(80, 21), (49, 96), (23, 93, 1424)],                                         # Alterac Mountains
    1417: [(14, 46, 1424), (45, 90), (77, 22, 1425)],                                    # Arathi Highlands
    1418: [(48, 5, 1432)],                                                               # Badlands
    1419: [(53, 7, 1435)],                                                               # Blasted Lands
    1420: [(85, 70, 1422), (54, 79, 1421), (61, 71, 1458, 180)],                          # Tirisfal Glades
    1421: [(57, 7, 1420), (68, 79, 1424)],                                               # Silverpine Forest
    1422: [(17, 57, 1420), (77, 52, 1423), (44, 96)],                                     # Western Plaguelands
    1423: [(6, 61, 1422)],                                                               # Eastern Plaguelands
    1424: [(5, 45, 1421), (86, 49, 1417), (88, 31, 1425)],                                # Hillsbrad Foothills
    1425: [(6, 61, 1424), (24, 28, 1422)],                                               # The Hinterlands
    1426: [(86, 48, 1432), (53.5, 35, 1455, 0)],                                          # Dun Morogh
    1427: [(45, 93, 1428)],                                                              # Searing Gorge
    1428: [(78, 80, 1433)],                                                              # Burning Steppes
    1429: [(17, 80, 1436), (64, 92, 1431), (95, 72, 1433), (32, 50, 1453, 45)],            # Elwynn Forest
    1430: [(29, 35, 1431), (60, 40, 1435)],                                              # Deadwind Pass
    1431: [(73, 10, 1429), (8, 63, 1436), (45, 90, 1434), (88, 46, 1430)],                 # Duskwood
    1432: [(20, 61, 1426), (25, 5, 1437), (46, 93, 1418)],                                # Loch Modan
    1433: [(5, 89, 1429), (42, 4, 1428)],                                                # Redridge Mountains
    1435: [(3, 57, 1430), (33, 78, 1419)],                                               # Swamp of Sorrows
    1436: [(63, 22, 1429), (67, 62, 1431)],                                              # Westfall
    1437: [(51, 9, 1417)],                                                               # Wetlands
    1438: [(31, 53, 1457, 90)],                                                          # Teldrassil
    1439: [(43, 96, 1440)],                                                              # Darkshore
    1440: [(56, 27, 1448), (42, 73, 1442), (68, 86, 1413), (94, 47, 1447)],                # Ashenvale
    1441: [(8, 26, 1444), (76, 94, 1446)],                                               # Thousand Needles
    1442: [(29, 80, 1443), (86, 94, 1413)],                                              # Stonetalon Mountains
    1443: [(61, 4, 1442), (46, 96, 1444)],                                               # Desolace
    1444: [(45, 4, 1443), (90, 50, 1441)],                                               # Feralas
    1445: [(28, 47, 1413)],                                                              # Dustwallow Marsh
    1446: [(51, 17, 1441), (25, 56, 1449)],                                              # Tanaris
    1447: [(7, 73, 1440)],                                                               # Azshara
    1448: [(67, 8, 1452)],                                                               # Felwood
    1449: [(22, 20, 1451)],                                                              # Un'Goro Crater
}


def tile(file_id):
    path = ART / f"{file_id}.blp"
    if not path.exists():
        ART.mkdir(exist_ok=True)
        req = urllib.request.Request(f"{wago.SITE}/api/casc/{file_id}?download",
                                     headers={"User-Agent": wago.AGENT})
        with urllib.request.urlopen(req, timeout=120) as r:
            path.write_bytes(r.read())
    return Image.open(path).convert("RGBA")


def zone_mask(art_id, overlays, overlay_tiles):
    """The zone's own pixels on its map: its explorable areas, with the holes between them
    filled."""
    cover = Image.new("RGBA", (W + TILE, H + TILE), (0, 0, 0, 0))
    for overlay in overlays:
        if overlay["UiMapArtID"] != art_id:
            continue
        for t in overlay_tiles.get(overlay["ID"], []):
            cover.alpha_composite(tile(t["FileDataID"]), (int(overlay["OffsetX"]) + int(t["ColIndex"]) * TILE,
                                                          int(overlay["OffsetY"]) + int(t["RowIndex"]) * TILE))
    alpha = cover.getchannel("A").crop((0, 0, W, H)).point(lambda v: 255 if v > COVERED else 0)
    padded = Image.new("L", (W + 2, H + 2), 0)
    padded.paste(alpha, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    return padded.crop((1, 1, W + 1, H + 1)).point(lambda v: 0 if v == 128 else 255).load()


class Maps:
    def __init__(self, build):
        self.bounds = {}
        for row in wago.table("UiMapAssignment", build):
            if row["OrderIndex"] == "0":
                self.bounds[int(row["UiMapID"])] = (int(row["MapID"]),) + tuple(
                    float(row[f"Region_{i}"]) for i in (0, 1, 3, 4))
        arts = {int(r["UiMapID"]): r["UiMapArtID"] for r in wago.table("UiMapXMapArt", build) if r["PhaseID"] == "0"}
        overlays = wago.table("WorldMapOverlay", build)
        overlay_tiles = {}
        for t in wago.table("WorldMapOverlayTile", build):
            if t["LayerIndex"] == "0":
                overlay_tiles.setdefault(t["WorldMapOverlayID"], []).append(t)
        with_overlays = {o["UiMapArtID"] for o in overlays if o["ID"] in overlay_tiles}
        self.zones = sorted(m for m, a in arts.items() if a in with_overlays and m not in CITIES)
        self.masks = {}
        for map_id in self.zones:
            self.masks[map_id] = zone_mask(arts[map_id], overlays, overlay_tiles)

    def to_world(self, map_id, x, y):
        _, min_x, min_y, max_x, max_y = self.bounds[map_id]
        return max_x - y * (max_x - min_x), max_y - x * (max_y - min_y)

    def to_map(self, map_id, wx, wy):
        _, min_x, min_y, max_x, max_y = self.bounds[map_id]
        return (max_y - wy) / (max_y - min_y), (max_x - wx) / (max_x - min_x)

    def at(self, continent, wx, wy, leaving):
        """The city, else the zone, whose own ground the world spot is on."""
        for city in CITIES:
            if city in self.bounds and self.bounds[city][0] == continent:
                x, y = self.to_map(city, wx, wy)
                if 0.05 < x < 0.95 and 0.05 < y < 0.95:
                    return city
        for map_id in self.zones:
            if map_id == leaving or self.bounds[map_id][0] != continent:
                continue
            x, y = self.to_map(map_id, wx, wy)
            if 0 <= x < 1 and 0 <= y < 1 and self.masks[map_id][int(x * W), int(y * H)]:
                return map_id
        return None

    def exit(self, map_id, x, y):
        """A crossing near (x, y) percent: (x, y, rotation, the zone across)."""
        m = self.masks[map_id]
        px, py = x * W / 100, y * H / 100
        best = None
        for yy in range(int(max(py - SNAP, 1)), int(min(py + SNAP, H - 2))):
            for xx in range(int(max(px - SNAP, 1)), int(min(px + SNAP, W - 2))):
                if m[xx, yy] and not (m[xx, yy - 1] and m[xx, yy + 1] and m[xx - 1, yy] and m[xx + 1, yy]):
                    d = (xx - px) ** 2 + (yy - py) ** 2
                    if best is None or d < best[0]:
                        best = (d, xx, yy)
        ex, ey = (best[1], best[2]) if best else (px, py)
        vx = vy = 0
        for yy in range(int(max(ey - 20, 0)), int(min(ey + 21, H))):
            for xx in range(int(max(ex - 20, 0)), int(min(ex + 21, W))):
                if not m[xx, yy]:
                    vx += xx - ex
                    vy += yy - ey
        n = math.hypot(vx, vy) or 1
        vx, vy = vx / n, vy / n
        continent, min_x, min_y, max_x, max_y = self.bounds[map_id]
        wx, wy = self.to_world(map_id, ex / W, ey / H)
        dwx, dwy = -vy / H * (max_x - min_x), -vx / W * (max_y - min_y)
        length = math.hypot(dwx, dwy) or 1
        across = None
        for step in STEPS:
            across = self.at(continent, wx + dwx / length * step, wy + dwy / length * step, map_id)
            if across:
                break
        # The arrow points up; SetRotation turns it anticlockwise.
        return (ex - vx * INSET) / W * 100, (ey - vy * INSET) / H * 100, math.atan2(-vx, -vy), across, (wx, wy)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", default=wago.BUILD)
    build = parser.parse_args().build
    maps = Maps(build)
    names = {int(r["ID"]): r["Name_lang"] for r in wago.table("UiMap", build)}

    lines = header(
        "NaowhForever_ZoneExits.lua -- the roads out of each zone, as clickable arrows on the town",
        f"map, from the game's map art for build {build}. Generated by Tools/build_zone_exits.py;",
        "do not edit by hand.",
        "",
        "[uiMapID] = { { x, y, rotation, the uiMapID it leads to }, ... }. x and y are map",
        "percentages, rotation is in radians, anticlockwise from pointing up.",
    )
    exits = {}   # uiMapID -> [ (x, y, rotation, across) ]

    def add(map_id, x, y, rotation, across):
        for other in exits.setdefault(map_id, []):
            if other[3] == across and math.hypot(other[0] - x, other[1] - y) < SAME:
                return
        exits[map_id].append((x, y, rotation, across))

    crossings = []
    for map_id, picks in EXITS.items():
        for pick in picks:
            if len(pick) == 4:
                add(map_id, pick[0], pick[1], math.radians(pick[3]), pick[2])
                continue
            x, y, rotation, found, spot = maps.exit(map_id, pick[0], pick[1])
            across = pick[2] if len(pick) == 3 else found
            if not across:
                sys.exit(f"map {map_id}: nothing across the border at {pick[0]}, {pick[1]}")
            add(map_id, x, y, rotation, across)
            crossings.append((map_id, across, spot))
    picked = {(map_id, across) for map_id, exits_there in exits.items() for _, _, _, across in exits_there}
    for map_id, across, (wx, wy) in crossings:
        if across in maps.masks and (across, map_id) not in picked:
            x, y = maps.to_map(across, wx, wy)
            bx, by, rotation, _, _ = maps.exit(across, x * 100, y * 100)
            add(across, bx, by, rotation, map_id)

    lines.append("ns.ZoneExits = {")
    total = 0
    for map_id in sorted(exits):
        lines.append(f"    [{map_id}] = {{")
        for x, y, rotation, across in sorted(exits[map_id]):
            lines.append(f"        {{ {x:.1f}, {y:.1f}, {rotation:.2f}, {across} }},   -- {names[across]}")
            total += 1
        lines.append("    },")
    lines.append("}")
    write(OUT, lines)
    print(f"{total} exits on {len(exits)} maps -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
