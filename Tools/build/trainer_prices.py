"""The prices class trainers ask, read from the trainer window: Tools/data/trainer_prices.json.

The Training Planner keeps what a class trainer asked each character for every spell it lists, at the
trainer window (NaowhForeverDB.trainingCharPrices, written at /reload or logout). A trainer lists all
of its class's spells, the ones above your level too, so one visit with the Training module on gives a
whole class. This reads those prices from a Forever client's SavedVariables and keeps each class's
under its slug, for Tools/build/training.py, which prefers them to Wowhead's.

The class is the one whose spells (NaowhForever_Training/Data/TrainingData.lua) the character's
prices are for. A newer read of a class replaces its older one. Read from a character below Honored
with the trainer's city: Honored and above pay 10% less.

Usage: python Tools/build/trainer_prices.py [--saved NaowhForever.lua]
Without --saved, the live Forever client's SavedVariables are read.
"""
import datetime
import glob
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
from items_in_game import lua_block  # noqa: E402
from training_builds import CLASSES  # noqa: E402

OUT = paths.DATA / "trainer_prices.json"
DATA = paths.ROOT / "NaowhForever_Training" / "Data" / "TrainingData.lua"
SAVED = str(Path(r"C:\Program Files (x86)\World of Warcraft\_forever_") / "WTF" / "Account" / "*"
            / "SavedVariables" / "NaowhForever.lua")


def class_spells(text):
    """Class ID -> the spell IDs TrainingData.lua lists for it."""
    out, class_id = {}, None
    for line in text.splitlines():
        found = re.match(r"\s*\[(\d+)\] = \{$", line)
        if found:
            class_id = int(found.group(1))
            continue
        found = re.match(r"\s*\{ \d+, (\d+), ", line)
        if found and class_id:
            out.setdefault(class_id, set()).add(int(found.group(1)))
    return out


def read_saved(text):
    """Character GUID -> {spell ID: copper} from a SavedVariables file's trainingCharPrices."""
    block = lua_block(text, "trainingCharPrices")
    if block is None:
        return {}
    out = {}
    for guid, inner in re.findall(r'\["(Player-[^"]+)"\]\s*=\s*(\{[^{}]*\})', block):
        out[guid] = {int(s): int(c) for s, c in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", inner)}
    return out


def by_class(characters, spells):
    """Class slug -> {spell ID: copper}: each character's prices under the class they are for. Two
    characters of a class that were asked different prices stop the read."""
    out = {}
    for guid, prices in characters.items():
        owners = [c for c, listed in spells.items() if prices and set(prices) <= listed]
        if len(owners) != 1:
            print(f"  {guid}: its {len(prices)} prices are not one class's, skipped")
            continue
        slug = CLASSES[owners[0]]
        known = out.setdefault(slug, {})
        differ = {s: (known[s], c) for s, c in prices.items() if s in known and known[s] != c}
        if differ:
            sys.exit(f"{slug}: two characters were asked different prices (a reputation discount?): {differ}")
        known.update(prices)
    return out


def write(found, day):
    old = json.loads(OUT.read_text(encoding="ascii")) if OUT.exists() else {}
    for slug, prices in found.items():
        old[slug] = {"read": day, "prices": {str(s): prices[s] for s in sorted(prices)}}
    OUT.write_text(json.dumps({slug: old[slug] for slug in sorted(old)}, indent=1) + "\n",
                   encoding="ascii", newline="\n")


def main(args):
    files = [Path(args[args.index("--saved") + 1])] if "--saved" in args else [Path(p) for p in glob.glob(SAVED)]
    if not files:
        sys.exit("No SavedVariables found: pass --saved")
    characters = {}
    for path in files:
        characters.update(read_saved(path.read_text(encoding="utf-8", errors="replace")))
    found = by_class(characters, class_spells(DATA.read_text(encoding="utf-8")))
    if not found:
        sys.exit("No trainer prices in the SavedVariables: open a class trainer with the Training module on")
    write(found, datetime.date.today().isoformat())
    print(f"Wrote {OUT.relative_to(paths.ROOT)}: " + ", ".join(f"{s} {len(p)}" for s, p in sorted(found.items())))


if __name__ == "__main__":
    main(sys.argv[1:])
