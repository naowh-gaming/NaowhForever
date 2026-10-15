"""Offline checks for the profession threshold data generator."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import skill_thresholds as st  # noqa: E402


def row(spell=10, first=1, yellow=95, grey=130, line=197, category=1):
    return {"Spell": str(spell), "SkillLine": str(line), "MinSkillLineRank": str(first),
            "TrivialSkillLineRankLow": str(yellow), "TrivialSkillLineRankHigh": str(grey),
            "TradeSkillCategoryID": str(category)}


class ThresholdTests(unittest.TestCase):
    def test_bounds_are_read_from_the_client_fields(self):
        self.assertEqual(st.collect([row()]), {10: (1, 95, 130)})

    def test_invalid_noncrafting_and_nonrecipe_rows_are_omitted(self):
        self.assertEqual(st.collect([row(first=100), row(grey=95), row(line=356), row(category=0)]), {})

    def test_conflicting_spell_rows_are_omitted_in_any_order(self):
        rows = [row(), row(grey=135), row()]
        self.assertEqual(st.collect(rows), {})
        self.assertEqual(st.collect(list(reversed(rows))), {})

    def test_identical_duplicates_are_kept_once(self):
        self.assertEqual(st.collect([row(), row()]), {10: (1, 95, 130)})

    def test_unknown_table_layout_fails(self):
        with self.assertRaises(ValueError):
            st.collect([{"Spell": "10"}])

    def test_generated_data_is_lazy_ascii_crlf_and_identifies_build(self):
        output = st.render({10: (1, 95, 130)}, "1.60.1.70374")
        self.assertIn(b"function P.LoadSkillThresholdData()", output)
        self.assertIn(b'build = "1.60.1.70374"', output)
        self.assertIn(b"[10] = { 1, 95, 130 }", output)
        self.assertNotIn(b"\n", output.replace(b"\r\n", b""))
        output.decode("ascii")


if __name__ == "__main__":
    unittest.main()
