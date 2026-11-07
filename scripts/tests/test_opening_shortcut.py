import copy
import json
import plistlib
import sys
import unittest
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from opening_shortcut import SOURCE, check_workflow


class OpeningShortcutTests(unittest.TestCase):
    def setUp(self):
        self.template = plistlib.loads(SOURCE.read_bytes())

    def test_one_opening_trigger_and_one_app_action(self):
        triggers = self.template["WFWorkflowTriggers"]
        self.assertEqual(len(triggers), 1)
        trigger = triggers[0].copy()
        UUID(trigger.pop("WFTriggerUUID"))
        self.assertEqual(trigger, {"WFTriggerIdentifier": "WFMultiTaskingArrangementTrigger",
                                   "WFTriggerSerializedParameters": {}})
        bundle = json.loads((ROOT / "appstore/release.json").read_text())["bundle_identifier"]
        self.assertEqual(self.template["WFWorkflowActions"], [{
            "WFWorkflowActionIdentifier": bundle + ".RecordOpeningIntent",
            "WFWorkflowActionParameters": {"AppIntentDescriptor": {
                "AppIntentIdentifier": "RecordOpeningIntent", "BundleIdentifier": bundle,
                "Name": "Hinge Counter", "TeamIdentifier": "4H5PK8686H"}},
        }])

    def test_lossy_signer_and_wrong_trigger_are_rejected(self):
        for replacement in (None, "ModeB", "Any"):
            with self.subTest(replacement=replacement):
                signed = copy.deepcopy(self.template)
                if replacement is None:
                    del signed["WFWorkflowTriggers"]
                else:
                    signed["WFWorkflowTriggers"][0]["WFTriggerSerializedParameters"]["WFArrangementMode"] = replacement
                with self.assertRaisesRegex(ValueError, "opening trigger"):
                    check_workflow(self.template, signed)

    def test_signer_may_stamp_its_version_but_cannot_add_an_action(self):
        signed = copy.deepcopy(self.template)
        signed["WFWorkflowClientVersion"] = "newer"
        check_workflow(self.template, signed)
        signed["WFWorkflowActions"].append(signed["WFWorkflowActions"][0])
        with self.assertRaisesRegex(ValueError, "differs"):
            check_workflow(self.template, signed)
