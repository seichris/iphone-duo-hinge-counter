#!/usr/bin/env python3
"""Validate the release pack. --strict additionally requires current-commit evidence.
--archive checks only prerequisites to create a TestFlight candidate, avoiding a
TestFlight-before-archive cycle. Neither mode signs, uploads, or submits an app.
"""
from __future__ import annotations
import argparse
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000}
GATES = {"name_and_rights", "sdk_and_hardware", "testflight_and_accessibility", "screenshots",
         "privacy_and_compliance", "signing_and_app_record", "pricing_and_storefronts",
         "support_and_privacy_urls"}

ARCHIVE_GATES = {"name_and_rights", "signing_and_app_record"}

def read_json(path: Path) -> dict:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def validate_metadata(metadata: dict) -> list[str]:
    errors = []
    for field, limit in LIMITS.items():
        value = metadata.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"Missing {field}")
        elif len(value) > limit:
            errors.append(f"{field}: {len(value)} characters exceeds {limit}")
        elif re.search(r"\b(TODO|TBD|UNKNOWN|PLACEHOLDER)\b|\[.*?TO CONFIRM.*?\]", value):
            errors.append(f"Unresolved placeholder in {field}")
    keywords = str(metadata.get("keywords", "")).lower().split(",")
    title_words = set(re.findall(r"[a-z]+", str(metadata.get("name", "")).lower()
                                + " " + str(metadata.get("subtitle", "")).lower()))
    normalized = lambda word: word.rstrip("s")  # Conservative English plural warning.
    seen = set()
    for word in keywords:
        key = normalized(word)
        if not word or word != word.strip():
            errors.append("Empty keyword or padding around keyword")
        if key in seen or key in {normalized(w) for w in title_words}:
            errors.append(f"Repeated keyword: {word}")
        if word in {"apple", "iphone", "ipad", "duo", "samsung", "galaxy", "pixel", "app", "free", "utilities"}:
            errors.append(f"Excluded keyword: {word}")
        seen.add(key)
    for field in ("support_url", "privacy_url", "marketing_url"):
        value = metadata.get(field, "")
        if not isinstance(value, str) or not value.startswith("https://") or "example.com" in value:
            errors.append(f"{field} must be the intended HTTPS endpoint")
    if "not a 24/7 counter" not in str(metadata.get("description", "")).lower():
        errors.append("Missing explicit foreground-only coverage disclosure")
    return errors


def validate_pack(root: Path) -> list[str]:
    metadata = read_json(root / "appstore/metadata/en-US.json")
    release = read_json(root / "appstore/release.json")
    help_content = read_json(root / "Resources/HelpContent.json")
    errors = validate_metadata(metadata)
    if set(release.get("required_approvals", [])) != GATES:
        errors.append("Release gates must not be dropped or renamed without updating the validator")
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(release.get("marketing_version", ""))):
        errors.append("Invalid marketing version")
    if not re.fullmatch(r"[1-9]\d*", str(release.get("build_number", ""))):
        errors.append("Invalid positive build number")
    if release.get("primary_category") != "UTILITIES" or release.get("release_mode") != "manual":
        errors.append("Review category/release-mode changes explicitly")
    for field in ("privacy_url", "support_url"):
        if help_content.get(field) != metadata[field]:
            errors.append(f"App and store {field} differ")
    for page in ("privacy", "support"):
        if not help_content.get(page):
            errors.append(f"Missing bundled {page} text")
        html = (root / f"site/{page}.html").read_text()
        if metadata[page + "_url"] not in html:
            errors.append(f"Wrong canonical URL in {page} page")
    guard = (root / "App/ReleaseGuard.swift").read_text()
    if "#if !DEBUG && !DUO_HINGE_API" not in guard or "#error" not in guard:
        errors.append("Missing compatibility-build distribution guard")
    return errors


def evidence_issues(evidence: dict, expected_commit: str, *, archive: bool = False) -> list[str]:
    errors = []
    if not re.fullmatch(r"[0-9a-f]{40}", expected_commit) or evidence.get("source_commit") != expected_commit:
        errors.append("Evidence must name the exact current source commit")
    approvals = evidence.get("approvals", {})
    if not isinstance(approvals, dict):
        return errors + ["Evidence approvals must be an object"]
    for key in sorted(ARCHIVE_GATES if archive else GATES):
        item = approvals.get(key, {})
        if not isinstance(item, dict) or item.get("passed") is not True:
            errors.append(f"BLOCKED: {key}")
        elif not isinstance(item.get("evidence"), str) or len(item["evidence"].strip()) < 12:
            errors.append(f"BLOCKED: {key} needs a meaningful evidence reference")
    return errors


def check_urls(metadata: dict) -> list[str]:
    errors = []
    for field in ("marketing_url", "privacy_url", "support_url"):
        try:
            request = urllib.request.Request(metadata[field], headers={"User-Agent": "FoldCounter-Release-Preflight/1.0"})
            with urllib.request.urlopen(request, timeout=20) as response:
                text = response.read(1_000_000).decode("utf-8")
                if response.status != 200 or "Fold Counter" not in text:
                    errors.append(f"Unexpected public page: {field}")
                marker = {"privacy_url": "Your counter stays on your device",
                          "support_url": "Why does the count miss openings?"}.get(field)
                if marker and marker not in text:
                    errors.append(f"Expected document content missing: {field}")
        except (OSError, UnicodeError, ValueError) as error:
            errors.append(f"Public URL failed: {field}: {error}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--strict", action="store_true", help="Require all submission evidence and live HTTPS pages")
    mode.add_argument("--archive", action="store_true", help="Require only signed-candidate prerequisites, not finished TestFlight tests")
    parser.add_argument("--evidence", type=Path, default=ROOT / ".release/evidence.json")
    args = parser.parse_args()
    try:
        errors = validate_pack(ROOT)
        metadata = read_json(ROOT / "appstore/metadata/en-US.json")
        for field, limit in LIMITS.items():
            print(f"{field}: {len(metadata.get(field, ''))}/{limit}")
        if args.strict or args.archive:
            commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
            dirty = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT, text=True)
            if dirty.strip():
                errors.append("Commit tracked source changes before collecting release evidence")
            evidence = read_json(args.evidence) if args.evidence.exists() else {}
            errors += evidence_issues(evidence, commit, archive=args.archive)
            if args.strict:
                from check_screenshots import inspect
                errors += inspect(ROOT / ".release/screenshots", read_json(ROOT / "appstore/screenshots.json"))
                # Do not make external requests while known evidence gates are blocked.
                if not errors:
                    errors += check_urls(metadata)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 2
        if args.strict:
            print("Release-pack evidence and URLs passed. Apple validation and review are separate.")
        elif args.archive:
            print("Candidate prerequisites passed. SDK/signing are checked by archive_release.sh. NOT submission approval.")
        else:
            print("PASS: draft pack is consistent. NOT publication approval; run --strict with actual evidence.")
            print("Outstanding external gates: " + ", ".join(sorted(GATES)))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"Preflight failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
