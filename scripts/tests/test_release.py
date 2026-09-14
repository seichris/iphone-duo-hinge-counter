import copy
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from release_preflight import validate_metadata, validate_pack, evidence_issues, GATES, ARCHIVE_GATES
from build_site import render_pages
from check_screenshots import inspect, png_size
from select_xcode import version_tuple


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.metadata = json.loads((ROOT / 'appstore/metadata/en-US.json').read_text())

    def test_metadata_is_valid(self):
        self.assertEqual(validate_metadata(self.metadata), [])

    def test_pack_is_consistent(self):
        self.assertEqual(validate_pack(ROOT), [])

    def test_long_name_rejected(self):
        self.metadata['name'] = 'x' * 31
        self.assertTrue(any('name:' in e for e in validate_metadata(self.metadata)))

    def test_long_keywords_rejected(self):
        self.metadata['keywords'] = 'x' * 101
        self.assertTrue(any('keywords:' in e for e in validate_metadata(self.metadata)))

    def test_duplicate_and_title_words_rejected(self):
        self.metadata['keywords'] = 'fold,folds,fold'
        self.assertTrue(any('Repeated keyword' in e for e in validate_metadata(self.metadata)))

    def test_trademark_stuffing_rejected(self):
        self.metadata['keywords'] = 'iphone,duo,samsung'
        self.assertEqual(len([e for e in validate_metadata(self.metadata) if 'Excluded' in e]), 3)

    def test_placeholder_and_insecure_url_rejected(self):
        self.metadata['subtitle'] = 'TODO'
        self.metadata['privacy_url'] = 'http://example.com'
        errors = validate_metadata(self.metadata)
        self.assertTrue(any('placeholder' in e for e in errors))
        self.assertTrue(any('privacy_url' in e for e in errors))

    def test_missing_disclosure_rejected(self):
        self.metadata['description'] = 'Counts all openings.'
        self.assertTrue(any('coverage' in e for e in validate_metadata(self.metadata)))

    def test_example_evidence_is_blocked(self):
        evidence = json.loads((ROOT / 'appstore/release-evidence.example.json').read_text())
        self.assertEqual(len(evidence_issues(evidence, 'a' * 40)), len(GATES) + 1)

    def test_current_commit_evidence_required(self):
        evidence = {'source_commit': 'b' * 40, 'approvals': {
            key: {'passed': True, 'evidence': 'Test fixture reference, not real approval'} for key in GATES}}
        self.assertEqual(evidence_issues(evidence, 'b' * 40), [])
        self.assertEqual(len(evidence_issues(evidence, 'c' * 40)), 1)

    def test_candidate_archive_does_not_require_completed_testflight(self):
        evidence = {'source_commit': 'a' * 40, 'approvals': {
            key: {'passed': True, 'evidence': 'Test fixture reference, not real approval'} for key in ARCHIVE_GATES}}
        self.assertEqual(evidence_issues(evidence, 'a' * 40, archive=True), [])
        self.assertEqual(len(evidence_issues(evidence, 'a' * 40)), len(GATES - ARCHIVE_GATES))

    def test_candidate_archive_still_requires_signing_evidence(self):
        self.assertIn('BLOCKED: signing_and_app_record',
                      evidence_issues({'source_commit': 'a' * 40}, 'a' * 40, archive=True))

    def test_truthy_strings_cannot_approve_release(self):
        evidence = {'source_commit': 'a' * 40, 'approvals': {
            key: {'passed': 'true', 'evidence': 'Unverified placeholder'} for key in GATES}}
        self.assertEqual(len(evidence_issues(evidence, 'a' * 40)), len(GATES))

    def test_site_is_generated_from_bundled_policy(self):
        for name, text in render_pages(ROOT).items():
            self.assertEqual((ROOT / 'site' / name).read_text(), text)
        self.assertNotIn('apps.apple.com', (ROOT / 'site/index.html').read_text())

    def test_missing_screenshots_are_not_success(self):
        with tempfile.TemporaryDirectory() as directory:
            errors = inspect(Path(directory), json.loads((ROOT / 'appstore/screenshots.json').read_text()))
            self.assertEqual(len(errors), 4)

    def test_png_size_and_invalid_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.png'
            path.write_bytes(b'not a png')
            with self.assertRaises(ValueError):
                png_size(path)
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR'
                             + struct.pack('>II', 1320, 2868) + bytes(9))
            self.assertEqual(png_size(path), (1320, 2868))

    def test_sdk_versions_are_numeric(self):
        self.assertLess(version_tuple('26.9'), version_tuple('27.1'))
        self.assertEqual(version_tuple('27'), (27, 0, 0))
        with self.assertRaises(ValueError):
            version_tuple('unknown')

    def test_new_resource_is_in_app_build_phase(self):
        spec = importlib.util.spec_from_file_location('generator_test', ROOT / 'scripts/generate_project.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        # Generate in memory/project output; no network or SDK is involved.
        module.main()
        target = module.objects[module.ident('target:FoldCounter')]
        resource_phases = [module.objects[k] for k in target['buildPhases']
                           if module.objects[k]['isa'] == 'PBXResourcesBuildPhase']
        paths = [module.objects[module.objects[k]['fileRef']].get('path')
                 for phase in resource_phases for k in phase['files']]
        self.assertIn('Resources/HelpContent.json', paths)


if __name__ == '__main__':
    unittest.main()
