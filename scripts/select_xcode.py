#!/usr/bin/env python3
"""Select the regular toolchain, or explicitly probe installed Duo SDKs (including betas)."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def version_tuple(value):
    if not re.fullmatch(r"\d+(\.\d+)*", value):
        raise ValueError(f"Unrecognized SDK version: {value}")
    values = tuple(int(x) for x in value.split("."))
    return (values + (0, 0))[:3]


# Compile the documented surface we use, including Swift 6 callback isolation.
# A version comparison alone is insufficient: 27.2 beta preceded the Duo SDK.
DUO_PROBE = '''import SwiftUI
@available(iOS 27.1, *)
@MainActor struct DuoSDKProbe: View {
    @State private var degrees: Double?
    var body: some View {
        ArrangementView {
            Text("Counter")
        } secondary: {
            Text("History")
        }
        .arrangementViewStyle(.split)
        .onHingeChange(isEnabled: true) { _, context in
            degrees = context.hinge?.angle.degrees
        }
    }
}
'''


def supports_duo(directory):
    environment = dict(os.environ, DEVELOPER_DIR=str(directory))
    try:
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"],
                                      env=environment, text=True, stderr=subprocess.DEVNULL).strip()
        with tempfile.TemporaryDirectory(prefix="duo-sdk-probe-") as temporary:
            source = Path(temporary) / "DuoSDKProbe.swift"
            source.write_text(DUO_PROBE)
            result = subprocess.run([
                "xcrun", "swiftc", "-typecheck", "-swift-version", "6", "-sdk", sdk,
                "-target", "arm64-apple-ios27.1-simulator", str(source)
            ], env=environment, text=True, capture_output=True, timeout=120)
        if result.returncode:
            print(f"Duo API probe failed for {directory}:\n{result.stderr}", file=sys.stderr)
        return result.returncode == 0
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Duo API probe unavailable for {directory}: {error}", file=sys.stderr)
        return False


def select_candidate(candidates, *, duo=False, probe=supports_duo):
    for version, directory, sdk in sorted(candidates, reverse=True):
        if duo:
            if version >= (27, 1, 0) and probe(directory):
                return directory, sdk
        elif version >= (26, 0, 0) and "beta" not in Path(directory).parts[-3].lower():
            return directory, sdk
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duo", action="store_true", help="Require real Duo API declarations; allow beta Xcode.")
    parser.add_argument("--optional", action="store_true", help="Report a missing Duo SDK as a CI skip.")
    args = parser.parse_args()
    if args.optional and not args.duo:
        parser.error("--optional is only valid with --duo")
    candidates = []
    for app in Path("/Applications").glob("Xcode*.app"):
        directory = app / "Contents/Developer"
        environment = dict(os.environ, DEVELOPER_DIR=str(directory))
        try:
            sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                                          env=environment, text=True, stderr=subprocess.DEVNULL).strip()
            candidates.append((version_tuple(sdk), str(directory), sdk))
        except (OSError, ValueError, subprocess.CalledProcessError):
            continue
    selected = select_candidate(candidates, duo=args.duo)
    if args.duo and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write(f"duo_available={str(selected is not None).lower()}\n")
    if selected is None:
        message = ("Duo SDK unavailable: no installed Xcode passed the iOS 27.1 hinge/arrangement API probe. "
                   "Duo compilation and runtime validation remain blocked." if args.duo else
                   "No installed non-beta-named Xcode with iOS SDK >=26. Update the runner.")
        print(message, file=sys.stderr)
        return 0 if args.optional else 1
    directory, sdk = selected
    print(f"Selected {directory}; iOS simulator SDK {sdk}. This is build validation, not App Store toolchain approval.")
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a") as output:
            output.write(f"DEVELOPER_DIR={directory}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
