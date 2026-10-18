# Resubmission validation — October 18, 2026

This record separates SDK compilation, simulator behavior, signing, App Store Connect checks and physical evidence. A simulator callback is not a physical hinge qualification.

## Current source and toolchain

Work began in a fresh isolated worktree from `origin/main` at `95577b0`. The primary checkout was preserved. The shipping Duo scheme retains `DUO_HINGE_API` and now directly uses SDK-typed public UIKit `UIHingeInteraction`, with a separate interaction for each observation subscription. The Objective-C allocation/KVC bridge is removed. Degrees are converted from the radians documented in the installed SDK headers.

Executed toolchain: **Xcode 27.1 RC, build 27A9275**, with **iOS 27.1 device and simulator SDKs**. Duo simulator runtime: **27.1 (24A94401)**, UDID `FC975829-19FA-4FA1-9606-1BFAA4524F10`. No Xcode 26.6/iOS 26.5 build was executed during this resubmission run.

## Executed checks

- `swift test --scratch-path .release/core`: **39 tests passed**. Includes detector timing, observation discontinuities, delayed callback rejection, scene leadership, persistence and synthetic 100-cycle input. Synthetic cycles do not qualify a device sensor.
- `python3 -m unittest discover -s scripts/tests`: **22 tests passed**.
- Project generation and `scripts/check_project.py`: **passed**, including all three targets, resources, schemes, privacy manifest and entitlements.
- `scripts/select_xcode.py --duo`: **passed**, now probing the typed UIKit interaction as well as the SwiftUI surface.
- `scripts/build_site.py --check`: **7 files passed**.
- Draft release preflight and `git diff --check`: **passed**. Draft consistency is not submission approval.
- Duo Release generic iOS device build, signing disabled: **BUILD SUCCEEDED**, including the widget. Logs: `.release/duo-device-final-build.log`.
- Duo Debug simulator app and UI test bundles: **compiled successfully** with the 27.1 SDK. A runtime screenshot showed `Live hinge · 0°`, `Observing while active`, zero observed openings and zero manual entries. This demonstrates a simulator callback, not a verified physical endpoint or complete opening cycle.
- Screenshot capture, accessibility-size coverage/demo isolation, History/Settings navigation and manual persistence/demo isolation ran in the Duo simulator. Final subscription regression results are recorded in the local test logs; do not infer an all-green UI suite from compilation or screenshots.

## App Store Connect checks

The existing version 1.0.0 remains **REJECTED**, with build **3** attached. The September 23 rejection cites pre-release hardware references and functionality. Apple's [October 5 announcement](https://developer.apple.com/news/?id=kkphp5qo) subsequently explicitly opened Duo optimized app submissions.

Read-only `asc validate` returned **0 errors, 0 warnings**, for the existing attached build, not candidate build 4. Four existing screenshot sets contain five COMPLETE images each: iPhone 6.7, 6.5, 6.1 and iPad 12.9. These are existing assets, not new Duo captures. Brave verification of the current App Privacy page confirmed **Published** and **Data Not Collected**. Marketing, support and privacy URLs returned the expected live content.

The local candidate is **1.0.0 (4)**. Metadata now explicitly requires iOS 27.1 or later for automatic Duo counting. Updated review notes remain a draft until device evidence is supplied. Archive/export logs and any candidate distribution evidence are kept in ignored `.release/`; no upload or submission should be inferred from the source version number.

## Remaining release gates

No physical iPhone Duo was available during the checks recorded above. Physical angle endpoints, the ability to observe complete openings across display handoff, multiwindow/lifecycle behavior, the 100-opening qualification, device accessibility and final widget behavior remain unverified. The release evidence must retain these as blocked.

The new SDK test-product automation initially failed to resolve the Duo destination; direct project-based `xcodebuild test` did launch the app. The RC logs `invalidDigitCount` for five-digit runtime build suffixes and duplicate accessibility loader classes. Failed test attempts and incomplete result bundles are retained separately; they are not passing evidence.

Before submission, finish physical qualification, TestFlight/accessibility checks, review real Duo screenshots, validate the signed candidate with Apple, select the processed candidate build, apply the final accurate metadata/review notes and reconcile the unresolved review item. Manual release remains selected. Do not send a reply claiming completed physical validation or submit solely because the metadata validator passes.
