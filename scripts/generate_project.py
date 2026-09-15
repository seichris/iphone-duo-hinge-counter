#!/usr/bin/env python3
"""Generate the Xcode project without XcodeGen, CocoaPods, or third-party packages.
Source folders are discovered explicitly; no downloaded code is executed.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "FoldCounter.xcodeproj"
CONFIGS = ("Debug", "Release", "Duo Debug", "Duo Release")
objects: dict[str, dict] = {}


def ident(name: str) -> str:
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(object_name: str, isa: str, **values) -> str:
    key = ident(object_name)
    if key in objects:
        raise ValueError(f"Duplicate project object: {object_name}")
    objects[key] = {"isa": isa, **values}
    return key


def dump(value, indent=0) -> str:
    if isinstance(value, dict):
        items = [f'{"  " * (indent + 1)}{json.dumps(str(k))} = {dump(v, indent + 1)};'
                 for k, v in value.items()]
        return "{\n" + "\n".join(items) + "\n" + "  " * indent + "}"
    if isinstance(value, list):
        return "(" + ", ".join(dump(v, indent) for v in value) + ")"
    return json.dumps(value)


def file_ref(path: str) -> str:
    name = "file:" + path
    key = ident(name)
    if key not in objects:
        kind = "sourcecode.swift" if path.endswith(".swift") else (
            "folder.assetcatalog" if path.endswith(".xcassets") else "text.xml")
        add(name, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="SOURCE_ROOT")
    return key


def phase(target: str, label: str, isa: str, refs: list[str], **extra) -> str:
    files = [add(f"build:{target}:{label}:{ref}", "PBXBuildFile", fileRef=ref,
                 **({"settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]}} if label == "Embed" else {}))
             for ref in refs]
    return add(f"phase:{target}:{label}", isa, buildActionMask=2147483647,
               files=files, runOnlyForDeploymentPostprocessing=0, **extra)


def configuration_list(owner: str, settings: dict, project=False) -> str:
    configs = []
    for config in CONFIGS:
        debug = config.endswith("Debug")
        flags = (["DEBUG"] if debug else []) + (["DUO_HINGE_API"] if config.startswith("Duo") else [])
        values = dict(settings)
        values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if debug else "-O",
                       "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) " + " ".join(flags),
                       "DEBUG_INFORMATION_FORMAT": "dwarf" if debug else "dwarf-with-dsym"})
        if debug:
            values["ENABLE_TESTABILITY"] = "YES"
        configs.append(add(f"config:{owner}:{config}", "XCBuildConfiguration", name=config, buildSettings=values))
    return add("config-list:" + owner, "XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def dependency(owner: str, other: str) -> str:
    proxy = add(f"proxy:{owner}:{other}", "PBXContainerItemProxy",
                containerPortal=ident("project"), proxyType=1,
                remoteGlobalIDString=ident("target:" + other), remoteInfo=other)
    return add(f"dependency:{owner}:{other}", "PBXTargetDependency",
               target=ident("target:" + other), targetProxy=proxy)


def target(name: str, files: list[str], product_type: str, extension: str,
           bundle_id: str, info: str | None, dependencies: list[str] = ()) -> str:
    product = add("product:" + name, "PBXFileReference", explicitFileType=product_type,
                  includeInIndex=0, path=f"{name}.{extension}", sourceTree="BUILT_PRODUCTS_DIR")
    phases = [phase(name, "Sources", "PBXSourcesBuildPhase", [file_ref(p) for p in files]),
              phase(name, "Frameworks", "PBXFrameworksBuildPhase", [])]
    resources = [] if name.endswith("UITests") else [file_ref("Resources/PrivacyInfo.xcprivacy")]
    if name == "FoldCounter":
        resources.append(file_ref("Resources/Assets.xcassets"))
        resources.append(file_ref("Resources/HelpContent.json"))
    phases.append(phase(name, "Resources", "PBXResourcesBuildPhase", resources))
    settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
                "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "$(inherited)",
                "TARGETED_DEVICE_FAMILY": "1,2", "SUPPORTS_MACCATALYST": "NO",
                "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"}
    if info:
        settings.update({"INFOPLIST_FILE": info, "GENERATE_INFOPLIST_FILE": "NO",
                         "CODE_SIGN_ENTITLEMENTS": "Resources/AppGroups.entitlements"})
    else:
        settings.update({"GENERATE_INFOPLIST_FILE": "YES", "TEST_TARGET_NAME": "FoldCounter"})
    if extension == "appex":
        settings.update({"APPLICATION_EXTENSION_API_ONLY": "YES", "SKIP_INSTALL": "YES",
                         "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"})
    if name == "FoldCounter":
        settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
        phases.append(phase(name, "Embed", "PBXCopyFilesBuildPhase", [ident("product:FoldCounterWidget")],
                            dstPath="", dstSubfolderSpec=13, name="Embed App Extensions"))
    kind = "application" if extension == "app" else (
        "app-extension" if extension == "appex" else "bundle.ui-testing")
    return add("target:" + name, "PBXNativeTarget", name=name, productName=name,
               productReference=product, productType="com.apple.product-type." + kind,
               buildConfigurationList=configuration_list(name, settings), buildPhases=phases,
               buildRules=[], dependencies=[dependency(name, other) for other in dependencies])


def scheme(name: str, configuration: str, release: str) -> None:
    def reference(target_name: str, suffix: str) -> str:
        return (f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:" + target_name)}" '
                f'BuildableName="{target_name}.{suffix}" BlueprintName="{target_name}" '
                'ReferencedContainer="container:FoldCounter.xcodeproj"/>')
    app = reference("FoldCounter", "app")
    tests = reference("FoldCounterUITests", "xctest")
    contents = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="{configuration}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
    <TestableReference skipped="NO">{tests}</TestableReference>
  </Testables></TestAction>
  <LaunchAction buildConfiguration="{configuration}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="{release}" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="{configuration}"/>
  <ArchiveAction buildConfiguration="{release}" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    output = PROJECT / "xcshareddata/xcschemes" / (name + ".xcscheme")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(contents)


def generate_icon() -> None:
    """Original two-panel icon, rendered as an opaque PNG using the standard library."""
    size = 1024
    background = (20, 27, 30)
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # PNG scanline filter: none
        for x in range(size):
            color = background
            for left, foreground in ((228, (107, 231, 198)), (532, (205, 247, 235))):
                if left - 1 <= x <= left + 265 and 251 <= y <= 773:
                    qx = abs(x - left - 132) - 88
                    qy = abs(y - 512) - 216
                    distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - 44
                    coverage = max(0, min(1, 0.5 - distance))
                    color = tuple(round(a * (1 - coverage) + b * coverage)
                                  for a, b in zip(background, foreground))
                    break
            raw.extend(color)
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    (ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").write_bytes(png)


def main() -> None:
    generate_icon()
    release = json.loads((ROOT / "appstore/release.json").read_text())
    core = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Sources/FoldCounterCore").glob("*.swift"))
    app = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "App").glob("*.swift"))
    widget = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Widget").glob("*.swift"))
    tests = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "UITests").glob("*.swift"))
    if not all((core, app, widget, tests)):
        raise SystemExit("Missing source files. Run this script from a complete repository checkout.")
    targets = [target("FoldCounterWidget", core + widget, "wrapper.app-extension", "appex",
                      "$(APP_BUNDLE_IDENTIFIER).widget", "Resources/Widget-Info.plist"),
               target("FoldCounter", core + app, "wrapper.application", "app",
                      "$(APP_BUNDLE_IDENTIFIER)", "Resources/App-Info.plist", ["FoldCounterWidget"]),
               target("FoldCounterUITests", tests, "wrapper.cfbundle", "xctest",
                      "$(APP_BUNDLE_IDENTIFIER).uitests", None, ["FoldCounter"])]
    products = add("products", "PBXGroup", name="Products", sourceTree="<group>",
                   children=[ident("product:" + name) for name in ("FoldCounter", "FoldCounterWidget", "FoldCounterUITests")])
    root = add("root", "PBXGroup", sourceTree="<group>",
               children=[key for key, value in objects.items() if value["isa"] == "PBXFileReference" and value.get("sourceTree") == "SOURCE_ROOT"] + [products])
    configs = configuration_list("project", {
        "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "18.0", "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "CURRENT_PROJECT_VERSION": release["build_number"], "MARKETING_VERSION": release["marketing_version"],
        "APP_BUNDLE_IDENTIFIER": release["bundle_identifier"],
        "APP_GROUP_IDENTIFIER": release["app_group_identifier"], "ENABLE_USER_SCRIPT_SANDBOXING": "YES"
    })
    project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "1600"},
                  buildConfigurationList=configs, compatibilityVersion="Xcode 14.0", developmentRegion="en",
                  hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=root,
                  productRefGroup=products, projectDirPath="", projectRoot="", targets=targets)
    PROJECT.mkdir(exist_ok=True)
    text = "// !$*UTF8*$!\n" + dump({"archiveVersion": 1, "classes": {}, "objectVersion": 56,
                                      "objects": objects, "rootObject": project}) + "\n"
    (PROJECT / "project.pbxproj").write_text(text)
    scheme("FoldCounter", "Debug", "Release")
    scheme("FoldCounter Duo", "Duo Debug", "Duo Release")
    print(f"Generated {PROJECT.name} ({len(objects)} objects). Open it in Xcode.")


if __name__ == "__main__":
    main()
