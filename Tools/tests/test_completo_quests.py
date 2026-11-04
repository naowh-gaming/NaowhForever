"""Tests for Tools/build/completo_quests.py's hand-kept corrections (Tools/data/completo_fixes.json):
a quest's add joins the quests before it, its drop leaves them and its explicit groups, and a fix
for a quest the data lacks stops the build. Offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import completo_quests  # noqa: E402


class Corrected(unittest.TestCase):
    def setUp(self):
        self.known = {i: (40, {"name": str(i)}) for i in (19, 20, 98386, 98387, 92744, 92742, 94013, 94979, 94007)}

    def test_add_and_drop(self):
        before = {19: [20, 98386, 98387]}
        fixes = {"19": {"drop": [98386]}, "92744": {"add": [92742]}}
        after, _ = completo_quests.corrected(before, {}, fixes, self.known)
        self.assertEqual(after, {19: [20, 98387], 92744: [92742]})
        self.assertEqual(before, {19: [20, 98386, 98387]})

    def test_drop_leaves_explicit_groups(self):
        before = {94013: [94007, 94979]}
        requires = {"94013": {"quests": [94979], "groups": [94979, [94007, 94978]]}}
        after, fixed = completo_quests.corrected(before, requires, {"94013": {"drop": [94979, 94978]}}, self.known)
        self.assertEqual(after, {94013: [94007]})
        self.assertEqual(fixed["94013"]["groups"], [94007])
        self.assertEqual(requires["94013"]["groups"], [94979, [94007, 94978]])
        self.assertEqual(completo_quests.requirements(after, self.known, fixed)[94013], [94007])

    def test_a_quest_left_with_nothing_has_no_requirement(self):
        after, _ = completo_quests.corrected({19: [98386]}, {}, {"19": {"drop": [98386]}}, self.known)
        self.assertEqual(after, {})

    def test_unknown_quest_stops_the_build(self):
        with self.assertRaises(SystemExit):
            completo_quests.corrected({}, {}, {"1": {"add": [2]}}, self.known)


class FixesFile(unittest.TestCase):
    def test_every_fix_says_why(self):
        fixes = json.loads((paths.DATA / "completo_fixes.json").read_text(encoding="utf-8"))
        for qid, fix in fixes["requires"].items():
            self.assertTrue(fix.get("why"), qid)
            self.assertTrue(fix.get("add") or fix.get("drop"), qid)


if __name__ == "__main__":
    unittest.main()
