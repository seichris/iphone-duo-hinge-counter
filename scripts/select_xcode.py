#!/usr/bin/env python3
"""Select an installed, non-beta Xcode with iOS SDK >=26; never silently use 18.5."""
import os
from pathlib import Path
import re
import subprocess
import sys


def version_tuple(value):
    if not re.fullmatch(r"\d+(\.\d+)*", value):
        raise ValueError(f"Unrecognized SDK version: {value}")
    values = tuple(int(x) for x in value.split("."))
    return (values + (0, 0))[:3]


def main():
    candidates = []
    for app in Path("/Applications").glob("Xcode*.app"):
        if "beta" in app.name.lower():
            continue
        directory = app / "Contents/Developer"
        environment = dict(os.environ, DEVELOPER_DIR=str(directory))
        try:
            sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                                          env=environment, text=True, stderr=subprocess.DEVNULL).strip()
            version = version_tuple(sdk)
            if version >= (26, 0, 0):
                candidates.append((version, str(directory), sdk))
        except (OSError, ValueError, subprocess.CalledProcessError):
            continue
    if not candidates:
        raise SystemExit("No installed non-beta Xcode with iOS SDK >=26. Update the runner; do not claim old-SDK success is upload readiness.")
    _, directory, sdk = max(candidates)
    print(f"Selected {directory}; iOS simulator SDK {sdk}. This is build validation, not App Store toolchain approval.")
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a") as output:
            output.write(f"DEVELOPER_DIR={directory}\n")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write("duo_available=" + str(version_tuple(sdk) >= (27, 1, 0)).lower() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
