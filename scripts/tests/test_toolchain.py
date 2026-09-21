from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from select_xcode import select_candidate, version_tuple


def candidate(app, sdk):
    return version_tuple(sdk), f"/Applications/{app}/Contents/Developer", sdk


class ToolchainTests(unittest.TestCase):
    def test_duo_accepts_beta_even_with_newer_non_duo_sdk_installed(self):
        candidates = [candidate("Xcode-27.2-beta.app", "27.2"),
                      candidate("Xcode-27.1-beta.app", "27.1"), candidate("Xcode.app", "27.0")]
        checked = []
        def probe(directory):
            checked.append(directory)
            return "27.1" in directory
        result = select_candidate(candidates, duo=True, probe=probe)
        self.assertEqual(result[1], "27.1")
        self.assertEqual(len(checked), 2)

    def test_newer_version_without_symbols_is_not_duo(self):
        self.assertIsNone(select_candidate([candidate("Xcode.app", "27.2")],
                                           duo=True, probe=lambda _: False))

    def test_old_sdk_is_not_probed(self):
        def probe(_):
            self.fail("An SDK below 27.1 must not be probed")
        self.assertIsNone(select_candidate([candidate("Xcode.app", "27.0")], duo=True, probe=probe))

    def test_regular_selection_remains_separate_from_beta_validation(self):
        result = select_candidate([candidate("Xcode-27.1-beta.app", "27.1"),
                                   candidate("Xcode-27.app", "27.0"), candidate("Xcode.app", "26.5")])
        self.assertEqual(result[1], "27.0")
