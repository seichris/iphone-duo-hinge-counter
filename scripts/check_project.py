#!/usr/bin/env python3
"""Check project structure/resources, not SDK compilation or physical hardware."""
import importlib.util
import json
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("project_generator", ROOT / "scripts/generate_project.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
generator.main()
objects = generator.objects
reference_keys = {"fileRef", "productReference", "buildConfigurationList", "mainGroup", "productRefGroup",
                  "target", "targetProxy", "containerPortal", "remoteGlobalIDString"}
list_keys = {"files", "children", "buildPhases", "dependencies", "buildConfigurations", "targets"}
for key, obj in objects.items():
    for field, value in obj.items():
        if field in reference_keys:
            assert value in objects, (key, field, value)
        if field in list_keys:
            assert all(ref in objects for ref in value), (key, field)
    if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") == "SOURCE_ROOT":
        assert (ROOT / obj["path"]).exists(), obj["path"]
assert len([o for o in objects.values() if o["isa"] == "PBXNativeTarget"]) == 3
for path in (ROOT / "Resources").glob("*.plist"):
    plistlib.loads(path.read_bytes())
privacy = plistlib.loads((ROOT / "Resources/PrivacyInfo.xcprivacy").read_bytes())
assert privacy["NSPrivacyTracking"] is False
entitlements = plistlib.loads((ROOT / "Resources/AppGroups.entitlements").read_bytes())
assert entitlements["com.apple.security.application-groups"] == ["$(APP_GROUP_IDENTIFIER)"]
for path in (ROOT / "Resources/Assets.xcassets").rglob("Contents.json"):
    contents = json.loads(path.read_text())
    for image in contents.get("images", []):
        assert (path.parent / image["filename"]).exists()
for scheme in (ROOT / "FoldCounter.xcodeproj/xcshareddata/xcschemes").glob("*.xcscheme"):
    root = ET.parse(scheme).getroot()
    for ref in root.iter("BuildableReference"):
        assert ref.attrib["BlueprintIdentifier"] in objects
    assert root.find("TestAction/Testables/TestableReference") is not None
app_info = plistlib.loads((ROOT / "Resources/App-Info.plist").read_bytes())
assert "UIBackgroundModes" not in app_info
assert app_info["UIApplicationSceneManifest"]["UIApplicationSupportsMultipleScenes"]
print("PASS: project graph, 3 targets, schemes, assets, privacy and entitlements. SDK build not checked.")
