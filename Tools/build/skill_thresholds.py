"""Generate the profession difficulty ranges from the Forever client's SkillLineAbility table.

Uses the project's wago reader, with the selected build's hotfixes. The low trivial rank
is yellow, the high trivial rank is grey. The display derives green from their midpoint.
Conflicting duplicate spell rows and contradictory ranges are omitted rather than guessed.
Run: python Tools/build/skill_thresholds.py [--build VERSION] [--csv FILE]
"""
import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402

CRAFTING_LINES = {129, 164, 165, 171, 185, 186, 197, 202, 333}
OUTPUT = paths.ROOT / "NaowhForever_Professions" / "Data" / "SkillThresholds.lua"
FIELDS = {"Spell", "SkillLine", "MinSkillLineRank", "TrivialSkillLineRankLow",
          "TrivialSkillLineRankHigh", "TradeSkillCategoryID"}


def collect(rows):
    values, conflicts = {}, set()
    for row in rows:
        if not FIELDS.issubset(row):
            raise ValueError("SkillLineAbility is missing required columns")
        if int(row["SkillLine"]) not in CRAFTING_LINES or int(row["TradeSkillCategoryID"]) <= 0:
            continue
        spell = int(row["Spell"])
        first, yellow, grey = (int(row[field]) for field in (
            "MinSkillLineRank", "TrivialSkillLineRankLow", "TrivialSkillLineRankHigh"))
        if spell <= 0 or not 0 <= first <= yellow < grey:
            continue
        bounds = (first, yellow, grey)
        if spell in values and values[spell] != bounds:
            conflicts.add(spell)
        values[spell] = bounds
    return {spell: bounds for spell, bounds in sorted(values.items()) if spell not in conflicts}


def render(values, build):
    lines = ["-- SkillThresholds.lua: recipe difficulty ranges generated from Forever SkillLineAbility by Tools/build/skill_thresholds.py.",
             "local P = _G.NaowhForever.Professions", "", "function P.LoadSkillThresholdData()",
             '    return { build = "' + build + '", values = {']
    for spell, (first, yellow, grey) in values.items():
        lines.append(f"        [{spell}] = {{ {first}, {yellow}, {grey} }},")
    lines.extend(["    } }", "end", ""])
    return "\r\n".join(lines).encode("ascii")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default=wago.BUILD)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if args.csv:
        with args.csv.open(encoding="utf-8-sig", newline="") as source:
            values = collect(csv.DictReader(source))
    else:
        values = collect(wago.table("SkillLineAbility", args.build))
    if not values:
        raise ValueError("No valid crafting ranges; existing data left intact")
    args.output.write_bytes(render(values, args.build))
    print(f"Generated {len(values)} recipe ranges for {args.build}: {args.output}")


if __name__ == "__main__":
    main()
