# Implementation validation — 2026-09-21

This record separates source/API checks, local builds, simulator behavior, and physical/release evidence. A passing simulator test is not a physical hinge qualification or App Store approval.

## Source and SDK verification

- Branch `duo-sdk-readiness` was based on freshly fetched `origin/main` at `dca94bd`; the primary checkout was not used for edits.
- Host: macOS 26.6.2 (25G83).
- Regular toolchain: Xcode 26.6 (17F113), iOS simulator SDK 26.5.
- Duo toolchain: Xcode 27.1 (27A9269), iOS simulator SDK 27.1, iOS 27.1 runtime 24A94401.
- `python3 scripts/select_xcode.py --duo` passed a Swift 6 declaration probe for `ArrangementView`, `.arrangementViewStyle(.split)`, `onHingeChange(isEnabled:_:)`, optional `context.hinge`, and `context.hinge?.angle.degrees`.
- The adapter is gated by `DUO_HINGE_API` and `#available(iOS 27.1, *)`; the regular scheme remains free of Duo-only symbols.

## Executed locally

- `swift test --scratch-path .release/build/core`: **39 tests passed**, including lifecycle invalidation, one-leader subscriptions, delayed-callback rejection, persistence boundaries, and 100 synthetic close/open cycles.
- `python3 -m unittest discover -s scripts/tests -v`: **22 tests passed**.
- `python3 scripts/generate_project.py`: generated the project successfully (82 objects).
- `python3 scripts/check_project.py`: project graph, resources, schemes, entitlements, and privacy checks passed.
- `python3 scripts/build_site.py --check`: **7 files passed**.
- `python3 scripts/release_preflight.py`: draft pack is internally consistent; external release gates remain open.
- Regular build with Xcode 26.6/iOS 26.5: **BUILD SUCCEEDED** (`.release/ios26-build.log`).
- Duo build with Xcode 27.1/iOS 27.1 simulator SDK: **BUILD SUCCEEDED** (`.release/duo27-build.log`).
- Regular UI suite on an iOS 27.0 iPhone 18 Pro simulator: **4 tests, 0 failures** (`.release/ios27-regular-ui.log`, `.release/ios27-regular-ui.xcresult`).
- Duo UI suite on the iPhone Duo iOS 27.1 simulator (`FC975829-19FA-4FA1-9606-1BFAA4524F10`): **4 tests, 0 failures** (`.release/duo27-ui-tests3.log`, `.release/duo27-ui-tests3.xcresult`). It covers screenshot attachments, Dynamic Type accessibility reachability, History/Settings navigation, manual persistence, and unsaved demo isolation.

Xcode 27.1 emitted `invalidDigitCount(94401/94403)` and debugger-path lookup warnings while running simulator tests. They did not affect build or test results and appear to be toolchain logging noise for the new runtime build identifiers.

## Not executed and remaining gates

- No physical iPhone Duo or Device Hub session was available. Physical hinge callbacks, sensor identity, angle endpoint convention, inner/outer display handoff, multiwindow leader behavior, and warm/cold lifecycle behavior remain unverified.
- The 100-cycle check is synthetic core input only; it is not a physical durability or sensor qualification test.
- No signed archive, TestFlight/App Store submission, hosted CI result, or production publication is claimed. CI now probes installed SDK declarations and, when available, compiles both simulator and generic-device Duo targets.
- The current adapter still assumes near-closed `0°` and near-flat `180°`; confirm and normalize those endpoints from real Duo samples before enabling production automatic tracking.
- Simulator UI validation cannot prove background coverage, sensor history, Device Hub controls, or physical display geometry. The documented foreground-only and no-replay limitations remain product behavior.
