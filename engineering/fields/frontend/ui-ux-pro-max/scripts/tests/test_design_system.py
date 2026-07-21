#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Characterization / regression tests for design_system.py.

These tests pin what the code ACTUALLY does today so a future edit (or a
re-vendor of the upstream skill) can't silently change behavior. They are
deliberately NOT a specification: where the current behavior looks like a bug,
the test says so in its docstring and pins the buggy behavior anyway. Changing
one of those is a decision, not an accident.

Three such bugs were fixed in v0.25.0 (path traversal in persist_design_system,
the over-loose _find_reasoning_rule keyword pass, and the bidirectional
_select_best_match name compare). Their tests now assert the CORRECT behavior and
are marked "FIXED" with the old test name in the docstring. Those fixes are local
overrides of vendored upstream code — see ../../SOURCE.md. If one of them goes red
after a re-vendor, the override was dropped and the bug is back; restore the fix,
do not relax the test.

Run:
    python3 -m unittest discover -s engineering/fields/frontend/ui-ux-pro-max/scripts/tests -v

Standard library only. No network. Nothing is written outside a TemporaryDirectory.
"""

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

# design_system.py does `from core import search`, so the scripts/ dir itself
# must be importable, not just its parent.
SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import design_system as ds  # noqa: E402


# ============================================================
# Design dials — pure logic, no CSV coupling
# ============================================================
class TestResolveDial(unittest.TestCase):
    """Pins _resolve_dial: the 1-10 dial -> tier bucketing and its clamping."""

    def test_none_returns_none_for_every_dial(self):
        for dial in ("variance", "motion", "density"):
            self.assertIsNone(ds._resolve_dial(dial, None), dial)

    def test_boundary_and_out_of_range_values_clamp_into_1_10(self):
        """0 and negatives clamp UP to 1; 11+ clamps DOWN to 10. Tier edges are 3|4 and 7|8."""
        cases = [
            (-99, 1, "Centered / Minimal"),
            (-1, 1, "Centered / Minimal"),
            (0, 1, "Centered / Minimal"),
            (1, 1, "Centered / Minimal"),
            (3, 3, "Centered / Minimal"),
            (4, 4, "Balanced / Modern"),
            (7, 7, "Balanced / Modern"),
            (8, 8, "Bold / Asymmetric"),
            (10, 10, "Bold / Asymmetric"),
            (11, 10, "Bold / Asymmetric"),
            (9999, 10, "Bold / Asymmetric"),
        ]
        for given, expected_value, expected_label in cases:
            with self.subTest(given=given):
                got = ds._resolve_dial("variance", given)
                # The clamped value is what is reported back to the user, not the raw input.
                self.assertEqual(got["value"], expected_value)
                self.assertEqual(got["label"], expected_label)

    def test_motion_and_density_share_the_same_tier_edges(self):
        self.assertEqual(ds._resolve_dial("motion", 3)["tier"], "Subtle")
        self.assertEqual(ds._resolve_dial("motion", 4)["tier"], "Standard")
        self.assertEqual(ds._resolve_dial("motion", 7)["tier"], "Standard")
        self.assertEqual(ds._resolve_dial("motion", 8)["tier"], "Complex")
        self.assertEqual(ds._resolve_dial("density", 3)["label"], "Spacious")
        self.assertEqual(ds._resolve_dial("density", 4)["label"], "Standard")
        self.assertEqual(ds._resolve_dial("density", 8)["label"], "Dense / Dashboard")

    def test_non_integer_inputs(self):
        """Numeric strings are accepted, floats truncate, junk raises. argparse
        normally guards this, but generate_design_system() is also a library call."""
        self.assertEqual(ds._resolve_dial("variance", "7")["value"], 7)
        self.assertEqual(ds._resolve_dial("density", 5.9)["value"], 5)   # int() truncates, no rounding
        self.assertEqual(ds._resolve_dial("density", -0.5)["value"], 1)
        with self.assertRaises(ValueError):
            ds._resolve_dial("variance", "abc")
        with self.assertRaises(KeyError):
            ds._resolve_dial("not-a-dial", 5)

    def test_false_is_treated_as_a_value_not_as_unset(self):
        """Only None means 'dial unset'. bool False survives the None check and
        clamps to 1 — worth pinning so nobody 'simplifies' the guard to `if not value`."""
        self.assertEqual(ds._resolve_dial("variance", False)["value"], 1)

    def test_density_spacing_scales_are_exact(self):
        self.assertEqual(ds._resolve_dial("density", 1)["spacing"]["md"], "24px")
        self.assertEqual(ds._resolve_dial("density", 5)["spacing"]["md"], "16px")
        self.assertEqual(ds._resolve_dial("density", 10)["spacing"]["md"], "8px")
        # The mid tier is what format_master_md falls back to when no dial is set.
        self.assertEqual(
            ds.DIAL_TIERS["density"][1][2]["spacing"],
            {"xs": "4px", "sm": "8px", "md": "16px", "lg": "24px",
             "xl": "32px", "2xl": "48px", "3xl": "64px"},
        )


# ============================================================
# Determinism
# ============================================================
class TestDeterminism(unittest.TestCase):
    """The generator must be a pure function of (query, name, dials) — no
    randomness, no ordering drift, no dependence on generator instance state."""

    QUERY = "fintech dashboard"

    def test_same_instance_and_fresh_instance_agree(self):
        gen = ds.DesignSystemGenerator()
        first = gen.generate(self.QUERY, "Test")
        second = gen.generate(self.QUERY, "Test")
        third = ds.DesignSystemGenerator().generate(self.QUERY, "Test")
        self.assertEqual(first, second)
        self.assertEqual(first, third)

    def test_dialled_generation_is_deterministic(self):
        gen = ds.DesignSystemGenerator()
        kwargs = dict(variance=9, motion=2, density=10)
        self.assertEqual(
            gen.generate(self.QUERY, "Test", **kwargs),
            gen.generate(self.QUERY, "Test", **kwargs),
        )

    def test_markdown_output_is_byte_identical_across_runs(self):
        gen = ds.DesignSystemGenerator()
        design = gen.generate(self.QUERY, "Test")
        self.assertEqual(ds.format_markdown(design), ds.format_markdown(design))
        self.assertEqual(ds.format_ascii_box(design), ds.format_ascii_box(design))

    def test_master_md_is_deterministic_apart_from_its_timestamp(self):
        gen = ds.DesignSystemGenerator()
        design = gen.generate(self.QUERY, "Test")

        def strip_timestamp(text):
            return [ln for ln in text.splitlines() if not ln.startswith("**Generated:**")]

        self.assertEqual(
            strip_timestamp(ds.format_master_md(design)),
            strip_timestamp(ds.format_master_md(design)),
        )


# ============================================================
# Selection and reasoning-rule lookup
# ============================================================
class TestSelectBestMatch(unittest.TestCase):

    def setUp(self):
        self.gen = ds.DesignSystemGenerator()

    def test_empty_results_returns_empty_dict(self):
        self.assertEqual(self.gen._select_best_match([], ["Minimalism"]), {})

    def test_no_priority_keywords_returns_first_result(self):
        results = [{"Style Category": "Alpha"}, {"Style Category": "Beta"}]
        self.assertEqual(self.gen._select_best_match(results, [])["Style Category"], "Alpha")
        self.assertEqual(self.gen._select_best_match(results, None)["Style Category"], "Alpha")

    def test_exact_style_name_in_priority_wins_over_rank_order(self):
        results = [{"Style Category": "Glassmorphism"}, {"Style Category": "Brutalism"}]
        self.assertEqual(
            self.gen._select_best_match(results, ["Brutalism"])["Style Category"], "Brutalism"
        )

    def test_substring_match_is_directional(self):
        """FIXED (was test_substring_match_is_bidirectional_BUG). Upstream matched
        `priority in name OR name in priority`, so a style whose name is a substring
        of the priority string won over the style the priority actually names: 'A' is
        inside 'Brutalism', so 'A' was selected. The match is now directional, so the
        intended target wins. See SOURCE.md -> local overrides."""
        results = [{"Style Category": "A"}, {"Style Category": "Brutalism"}]
        self.assertEqual(
            self.gen._select_best_match(results, ["Brutalism"])["Style Category"], "Brutalism"
        )

    def test_priority_still_matches_a_longer_real_style_name(self):
        """The intended feature survives the directional fix: a priority string
        matches a real style name that CONTAINS it."""
        results = [{"Style Category": "Neubrutalism"}, {"Style Category": "Glassmorphism 2.0"}]
        self.assertEqual(
            self.gen._select_best_match(results, ["Glassmorphism"])["Style Category"],
            "Glassmorphism 2.0",
        )

    def test_empty_priority_string_matches_everything_and_yields_first_result(self):
        """Style_Priority="" splits to [""], and "" is a substring of every name."""
        results = [{"Style Category": "Alpha"}, {"Style Category": "Beta"}]
        self.assertEqual(self.gen._select_best_match(results, [""])["Style Category"], "Alpha")


class TestReasoningLookup(unittest.TestCase):

    def setUp(self):
        self.gen = ds.DesignSystemGenerator()

    def test_reasoning_csv_loads(self):
        self.assertGreater(len(self.gen.reasoning_data), 0)

    def test_exact_and_partial_category_match(self):
        self.assertEqual(
            self.gen._find_reasoning_rule("Fintech/Crypto").get("UI_Category"), "Fintech/Crypto"
        )
        # "General" is not a row, but it is a substring of "SaaS (General)".
        self.assertEqual(
            self.gen._find_reasoning_rule("General").get("UI_Category"), "SaaS (General)"
        )

    def test_unrecognized_category_reaches_the_neutral_defaults_branch(self):
        """FIXED (was test_single_letter_token_makes_unrelated_categories_match_ecommerce_BUG).
        Upstream's keyword pass split "E-commerce" into ["e", "commerce"] and accepted a
        substring hit, so ANY unmatched category containing the letter "e" resolved to the
        E-commerce rule. Whole-token matching with a minimum token length makes the
        documented "no rule -> neutral defaults" branch reachable again.
        See SOURCE.md -> local overrides."""
        for category in ("zzzz-no-such-category-qq", "qqq-eee-no-such-thing", "xyzzy"):
            with self.subTest(category=category):
                self.assertEqual(self.gen._find_reasoning_rule(category), {})

    def test_real_categories_still_resolve_through_the_keyword_pass(self):
        """The keyword pass must still do its job for freeform categories that miss
        the exact and partial passes."""
        cases = [
            ("Fitness App", "Fitness/Gym App"),
            ("Dental", "Dental Practice"),
            ("crypto wallet", "Fintech/Crypto"),
            ("pet grooming", "Pet Tech App"),
            ("online course", "Online Course/E-learning"),
        ]
        for category, expected in cases:
            with self.subTest(category=category):
                self.assertEqual(
                    self.gen._find_reasoning_rule(category).get("UI_Category"), expected
                )

    def test_every_real_ui_category_resolves_to_itself(self):
        """Guards the fix against over-tightening: all 161 rows in ui-reasoning.csv
        (which is also the Product Type vocabulary the generator feeds in) must still
        resolve to their own rule."""
        for rule in self.gen.reasoning_data:
            category = rule.get("UI_Category", "")
            with self.subTest(category=category):
                self.assertEqual(
                    self.gen._find_reasoning_rule(category).get("UI_Category"), category
                )

    def test_truly_unmatched_category_falls_back_to_hardcoded_defaults(self):
        """A category with no matching token at all ('zzz') reaches the fallback."""
        self.assertEqual(self.gen._find_reasoning_rule("zzz"), {})
        reasoning = self.gen._apply_reasoning("zzz", {})
        self.assertEqual(reasoning["pattern"], "Hero + Features + CTA")
        self.assertEqual(reasoning["style_priority"], ["Minimalism", "Flat Design"])
        self.assertEqual(reasoning["severity"], "MEDIUM")
        self.assertEqual(reasoning["decision_rules"], {})

    def test_malformed_decision_rules_json_is_swallowed(self):
        with mock.patch.object(
            self.gen, "reasoning_data",
            [{"UI_Category": "widget", "Decision_Rules": "{not json", "Severity": "LOW"}],
        ):
            self.assertEqual(self.gen._apply_reasoning("widget", {})["decision_rules"], {})


# ============================================================
# No-match / empty-input paths
# ============================================================
class TestNoMatchAndEmptyInput(unittest.TestCase):

    def setUp(self):
        self.gen = ds.DesignSystemGenerator()

    def test_gibberish_query_still_returns_a_complete_design_system(self):
        design = self.gen.generate("zzzzqqqq nonexistent gibberish xkcdplugh")
        self.assertEqual(design["category"], "General")
        # Color and typography searches find nothing, so the hardcoded defaults show.
        self.assertEqual(design["colors"]["primary"], "#2563EB")
        self.assertEqual(design["colors"]["accent"], "#F97316")
        self.assertEqual(design["colors"]["cta"], design["colors"]["accent"])
        self.assertEqual(design["colors"]["text"], design["colors"]["foreground"])
        self.assertEqual(design["typography"]["heading"], "Inter")
        self.assertEqual(design["typography"]["body"], "Inter")
        # A style IS still returned: the reasoning rule's Style_Priority keywords are
        # appended to the style query, so the style search never comes back empty.
        self.assertTrue(design["style"]["name"])
        # No dials set -> every dial field is None and no motion/spacing extras.
        self.assertEqual(set(design["dials"].values()), {None})
        self.assertIsNone(design["spacing_scale"])
        self.assertEqual(design["motion_snippet"], {})

    def test_empty_query_does_not_crash_and_yields_empty_project_name(self):
        design = self.gen.generate("")
        self.assertEqual(design["project_name"], "")   # "" or "".upper() == ""
        self.assertEqual(design["category"], "General")
        for key in ("pattern", "style", "colors", "typography", "dials"):
            self.assertIn(key, design)
        # Formatters must survive it too.
        self.assertIn("## Design System:", ds.format_markdown(design))
        self.assertTrue(ds.format_ascii_box(design).startswith("╔"))

    def test_project_name_defaults_to_uppercased_query(self):
        self.assertEqual(self.gen.generate("saas dashboard")["project_name"], "SAAS DASHBOARD")


# ============================================================
# Dial effect on the generated system
# ============================================================
class TestDialsAffectGeneration(unittest.TestCase):

    QUERY = "saas landing page"

    def setUp(self):
        self.gen = ds.DesignSystemGenerator()

    def test_variance_dial_changes_style_selection(self):
        low = self.gen.generate(self.QUERY, "P", variance=1)
        high = self.gen.generate(self.QUERY, "P", variance=10)
        self.assertEqual(low["dials"]["variance_label"], "Centered / Minimal")
        self.assertEqual(high["dials"]["variance_label"], "Bold / Asymmetric")
        # The dial must actually bias retrieval, not just relabel the output.
        self.assertNotEqual(low["style"]["name"], high["style"]["name"])

    def test_density_dial_overrides_the_spacing_scale_in_master_md(self):
        dense = self.gen.generate(self.QUERY, "P", density=10)
        self.assertEqual(dense["spacing_scale"]["md"], "8px")
        master = ds.format_master_md(dense)
        self.assertIn("| `--space-md` | `8px` / `0.5rem` | Standard padding |", master)
        self.assertIn("*Density: 10/10 — Dense / Dashboard*", master)

    def test_unset_density_uses_the_mid_tier_defaults_in_master_md(self):
        plain = self.gen.generate(self.QUERY, "P")
        self.assertIsNone(plain["spacing_scale"])
        master = ds.format_master_md(plain)
        self.assertIn("| `--space-md` | `16px` / `1rem` | Standard padding |", master)
        self.assertNotIn("*Density:", master)

    def test_motion_dial_attaches_a_snippet_of_the_requested_tier(self):
        """Data-coupled on motion.csv's Intensity Tier column; skipped if a tier
        has no rows so a data refresh degrades to a skip, not a false failure."""
        from core import search as core_search
        for dial_value, tier in ((2, "Subtle"), (5, "Standard"), (9, "Complex")):
            with self.subTest(tier=tier):
                available = core_search(tier, "gsap", 50).get("results", [])
                if not any(r.get("Intensity Tier") == tier for r in available):
                    self.skipTest(f"motion.csv has no rows for tier {tier}")
                design = self.gen.generate(self.QUERY, "P", motion=dial_value)
                self.assertTrue(design["motion_snippet"], "expected a motion snippet")
                self.assertEqual(design["motion_snippet"].get("Intensity Tier"), tier)

    def test_dials_render_only_when_set(self):
        plain = ds.format_markdown(self.gen.generate(self.QUERY, "P"))
        self.assertNotIn("### Design Dials", plain)
        dialled = ds.format_markdown(self.gen.generate(self.QUERY, "P", variance=8))
        self.assertIn("- **Variance:** 8/10 — Bold / Asymmetric", dialled)


# ============================================================
# Persistence — everything here writes to a TemporaryDirectory only
# ============================================================
class TestPersistence(unittest.TestCase):

    def setUp(self):
        self.gen = ds.DesignSystemGenerator()
        self.design = self.gen.generate("saas dashboard", "My Project")
        self.tmp = Path(self._mkdtemp())

    def _mkdtemp(self):
        import tempfile
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return tmp.name

    def test_master_only_when_no_page_given(self):
        result = ds.persist_design_system(self.design, output_dir=str(self.tmp))
        self.assertEqual(result["status"], "success")
        master = self.tmp / "design-system" / "my-project" / "MASTER.md"
        self.assertTrue(master.exists())
        self.assertEqual(result["created_files"], [str(master)])
        # The pages/ dir is created eagerly but left empty.
        self.assertEqual(list((self.tmp / "design-system" / "my-project" / "pages").iterdir()), [])
        text = master.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("# Design System Master File"))
        self.assertIn("**Project:** My Project", text)

    def test_page_override_file_is_slugged_and_titled(self):
        result = ds.persist_design_system(
            self.design, page="Sign Up", output_dir=str(self.tmp), page_query="saas dashboard"
        )
        page_file = self.tmp / "design-system" / "my-project" / "pages" / "sign-up.md"
        self.assertTrue(page_file.exists())
        self.assertEqual(len(result["created_files"]), 2)
        text = page_file.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("# Sign Up Page Overrides"))
        self.assertIn("> **PROJECT:** My Project", text)
        self.assertIn("## Page-Specific Rules", text)

    def test_missing_or_empty_project_name_slugs_to_default(self):
        for name in (None, "", "   "):
            with self.subTest(name=name):
                tmp = Path(self._mkdtemp())
                design = dict(self.design, project_name=name)
                ds.persist_design_system(design, output_dir=str(tmp))
                expected = "default" if not name else name.lower().replace(" ", "-")
                self.assertTrue((tmp / "design-system" / expected / "MASTER.md").exists())

    def test_project_name_and_page_cannot_traverse_out_of_the_output_dir(self):
        """FIXED (was test_project_name_and_page_are_not_sanitised_path_traversal_BUG).
        Upstream only lowercased and space-hyphenated project_name and page before
        joining them onto the output path, so `../` escaped the design-system/ tree
        entirely: the master landed two levels up and the page two levels above that.
        Both are now sanitised to a single path segment. See SOURCE.md -> local
        overrides."""
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir).resolve()
            nested = root / "a" / "b"
            nested.mkdir(parents=True)
            design = dict(self.design, project_name="../../escaped")
            result = ds.persist_design_system(
                design, page="../../pwned", output_dir=str(nested)
            )

            # Nothing escaped: every written file resolves inside nested/design-system/.
            tree_root = (nested / "design-system").resolve()
            self.assertTrue(result["created_files"])
            for written in result["created_files"]:
                resolved = Path(written).resolve()
                self.assertTrue(
                    str(resolved).startswith(str(tree_root) + os.sep),
                    f"{resolved} escaped {tree_root}",
                )
                self.assertTrue(resolved.exists())

            # The specific escape targets the old code produced are absent...
            self.assertFalse((root / "a" / "escaped").exists())
            self.assertFalse((root / "a" / "pwned.md").exists())
            # ...and nothing at all was created outside nested/.
            self.assertEqual(sorted(p.name for p in (root / "a").iterdir()), ["b"])
            self.assertEqual(sorted(p.name for p in root.iterdir()), ["a"])

    def test_traversal_attempts_still_produce_a_usable_slug(self):
        """Sanitising must degrade to a safe single segment, not crash: the writes
        succeed, just inside the tree."""
        design = dict(self.design, project_name="../../escaped")
        result = ds.persist_design_system(design, page="/etc/passwd", output_dir=str(self.tmp))
        self.assertEqual(result["status"], "success")
        self.assertEqual(len(result["created_files"]), 2)
        for written in result["created_files"]:
            self.assertIn("design-system", Path(written).parts)

    def test_a_name_that_sanitises_to_nothing_falls_back_to_default(self):
        """Consistent with the empty-name case above — a fallback, not an exception."""
        tmp = Path(self._mkdtemp())
        design = dict(self.design, project_name="..")
        ds.persist_design_system(design, output_dir=str(tmp))
        self.assertTrue((tmp / "design-system" / "default" / "MASTER.md").exists())

    def test_generate_without_persist_writes_nothing(self):
        before = sorted(p.name for p in self.tmp.iterdir())
        ds.generate_design_system("saas dashboard", "My Project", output_dir=str(self.tmp))
        self.assertEqual(sorted(p.name for p in self.tmp.iterdir()), before)

    def test_generate_with_persist_writes_only_under_output_dir(self):
        out = ds.generate_design_system(
            "saas dashboard", "My Project", "markdown",
            persist=True, page="dashboard", output_dir=str(self.tmp),
        )
        self.assertIn("## Design System: My Project", out)
        self.assertTrue((self.tmp / "design-system" / "my-project" / "MASTER.md").exists())
        self.assertTrue(
            (self.tmp / "design-system" / "my-project" / "pages" / "dashboard.md").exists()
        )
        # Nothing leaked into the working directory. Asserted narrowly rather than by
        # snapshotting all of cwd — a concurrent writer there would fail that spuriously.
        self.assertFalse((Path(os.getcwd()) / "design-system").exists())


# ============================================================
# Page-type detection
# ============================================================
class TestDetectPageType(unittest.TestCase):

    def test_known_page_keywords(self):
        cases = [
            ("checkout", "Checkout / Payment"),
            ("settings", "Settings / Profile"),
            ("login", "Authentication"),
            ("pricing", "Pricing / Plans"),
            ("blog", "Blog / Article"),
            ("404", "Empty State"),
        ]
        for context, expected in cases:
            with self.subTest(context=context):
                self.assertEqual(ds._detect_page_type(context, []), expected)

    def test_first_matching_pattern_wins_not_the_most_specific(self):
        """Pattern list order is the tiebreak: 'dashboard' is checked before
        'checkout', so a context naming both resolves to Dashboard."""
        self.assertEqual(ds._detect_page_type("checkout dashboard", []), "Dashboard / Data View")

    def test_unknown_context_falls_back_to_style_best_for_then_general(self):
        self.assertEqual(ds._detect_page_type("wibble", []), "General")
        self.assertEqual(
            ds._detect_page_type("wibble", [{"Style Category": "X", "Best For": "dashboard apps"}]),
            "Dashboard / Data View",
        )


# ============================================================
# Output helpers
# ============================================================
class TestHexToAnsi(unittest.TestCase):

    def test_emits_a_swatch_only_on_truecolor_terminals(self):
        with mock.patch.dict(os.environ, {"COLORTERM": "truecolor"}):
            self.assertEqual(ds.hex_to_ansi("#FF0000"), "\033[38;2;255;0;0m██\033[0m ")
        with mock.patch.dict(os.environ, {"COLORTERM": "256color"}):
            self.assertEqual(ds.hex_to_ansi("#FF0000"), "")

    def test_malformed_values_return_empty_string(self):
        with mock.patch.dict(os.environ, {"COLORTERM": "truecolor"}):
            for bad in ("", "nope", "#FFF", "FF0000"):
                with self.subTest(bad=bad):
                    self.assertEqual(ds.hex_to_ansi(bad), "")

    def test_BUG_non_hex_digits_raise_instead_of_returning_empty(self):
        # A 7-char string starting with "#" passes the length/prefix guard, then int(...,16)
        # blows up on the non-hex digits. Pinning the CURRENT behavior, not endorsing it:
        # every other malformed value above degrades to "". design_system.py:343.
        with mock.patch.dict(os.environ, {"COLORTERM": "truecolor"}):
            with self.assertRaises(ValueError):
                ds.hex_to_ansi("#GGGGGG")

    def test_ansi_ljust_ignores_escape_sequences_when_padding(self):
        padded = ds.ansi_ljust("\033[38;2;1;2;3m██\033[0m", 10)
        self.assertTrue(padded.endswith(" " * 8))


if __name__ == "__main__":
    unittest.main()
