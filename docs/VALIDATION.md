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
- Four existing Duo UI flows passed in the first direct run: screenshot capture, accessibility-size coverage/demo isolation, History/Settings navigation and manual persistence/demo isolation. The new subscription test initially failed due to combined accessibility labels and the labeled row being mistaken for its nested switch. After fixing those test selectors, the focused final regression **passed: 1 test, 0 failures** in 34 seconds (`.release/duo-final-resume-tests.log`). It actually pauses/resumes twice, receives fresh status updates and retains zero counts on an initial pose. These are results across separate runs; the earlier failed suite is not relabeled green.

## App Store Connect checks

The existing version 1.0.0 remains **REJECTED**, with build **3** attached. The September 23 rejection cites pre-release hardware references and functionality. Apple's [October 5 announcement](https://developer.apple.com/news/?id=kkphp5qo) subsequently explicitly opened Duo optimized app submissions.

Read-only `asc validate` returned **0 errors, 0 warnings**, for the existing attached build, not candidate build 4. Four existing screenshot sets contain five COMPLETE images each: iPhone 6.7, 6.5, 6.1 and iPad 12.9. These are existing assets, not new Duo captures. Brave verification of the current App Privacy page confirmed **Published** and **Data Not Collected**. Marketing, support and privacy URLs returned the expected live content.

The local candidate is **1.0.0 (4)**. Metadata now explicitly requires iOS 27.1 or later for automatic Duo counting. Updated review notes remain a draft until device evidence is supplied. The signed archive and exported IPA **succeeded** using Xcode 27A9275 and iphoneos27.1. App/widget versions, deep signatures, team and App Group entitlements match. The artifact was built from `feb69ab`; subsequent changes only correct the UI test and update this report. A local manifest records build and verification commits separately and verifies that application inputs are unchanged. Archive/export logs and any candidate distribution evidence are kept in ignored `.release/`; no upload or submission should be inferred from the source version number.

## Remaining release gates

No physical iPhone Duo was available during the checks recorded above. Physical angle endpoints, the ability to observe complete openings across display handoff, multiwindow/lifecycle behavior, the 100-opening qualification, device accessibility and final widget behavior remain unverified. The release evidence must retain these as blocked.

The new SDK test-product automation initially failed to resolve the Duo destination; direct project-based `xcodebuild test` did launch the app. The RC logs `invalidDigitCount` for five-digit runtime build suffixes and duplicate accessibility loader classes. Failed test attempts and incomplete result bundles are retained separately; they are not passing evidence.

Before submission, finish physical qualification, apply measured metadata/review notes and reconcile the unresolved review item. Manual release remains selected. Do not send a reply claiming completed physical validation or submit solely because the metadata validator passes.

## Build 5 follow-up

Screenshot review exposed a visual defect at a closed pose: the decorative glyph's perspective projection enlarged it outside its fixed layout. Build **1.0.0 (5)** uses orthographic rotation for that artwork; sensor observation and count policy are unchanged. Application source: `e7eeec4`. This replaces build 4 as the candidate for hardware qualification.

Build 5 was archived and exported with **Xcode 27.1 RC (27A9275), iphoneos27.1**. Both distribution signatures, bundle versions and App Group entitlements were checked. Apple processed build `531a4f37-9edd-485e-b6bb-3bb485cd35fe`; it is attached to the draft version. App Store and TestFlight metadata validation each report **zero errors and zero warnings**. This does not submit the version or exercise the distribution app on hardware.

The follow-up reran **39 core tests** and **24 release-script tests**, plus project, site and SDK declaration checks. An initial extra core build failed for lack of disk space; the rerun using the existing scratch directory passed. That failure is preserved, not counted as a test pass. Both hosted CI jobs for `e7eeec4` passed.

The 27.1 RC's XCTest application/screen captures can select inactive display data or round the inner framebuffer to **2006 × 2852**, even while UI assertions pass. These captures were rejected. The inner listing set uses five actual **2853 × 2007** native landscape captures from `devicectl device capture screenshot --display-unique-id`, with the simulator/display identity recorded privately. No screenshot is resized to impersonate a Duo display. Screenshot validation now rejects alpha channels and enforces the shared ten-image maximum for the combined Duo upload set. Full capture selection, final software UI results, remote asset processing and exact candidate hashes are recorded in ignored `.release/resubmission-readiness.md` and its evidence files.

The remaining physical qualification procedure is [HARDWARE-QUALIFICATION.md](HARDWARE-QUALIFICATION.md). It includes the actual TestFlight package, hinge endpoints and counting accuracy, display handoff and continuity, multiple windows, device accessibility and widgets. Local release evidence must keep the two combined hardware/TestFlight gates blocked until those results exist.

## Build 7 follow-up

Build **1.0.0 (7)** incorporates the user-supplied October 18 icon and the accessibility header correction introduced for build 6. The original supplied artwork is preserved in `design/AppIcon-source.png`; the app asset is a 1024 × 1024 opaque PNG derived without changing the composition. The privacy badge stacks below the Today heading at accessibility text sizes. The largest-text screenshot from build 6 confirms that the badge stays readable; default-size app content is unchanged except for the candidate version label.

Build 6 was signed, archived and exported with Xcode 27.1 RC (27A9275), iphoneos27.1; app/widget identities and entitlements passed. It was not uploaded. Build 7 replaces it because the icon is an application input. Actual build 7 archive, processing and attachment status must be read from the private candidate manifest, rather than inferred from this source version number.

Ten native Duo captures and five refreshed ordinary iPhone captures from build 5 were uploaded and processed COMPLETE in App Store Connect. The iPad refresh and final candidate screenshot reconciliation remain software work until their private evidence says they passed. The new document-cancellation UI check initially needed scrolling to materialize a lazy Settings row, then reached Apple's export browser inside On My iPhone. The root-browser cancellation flow is under validation. Do not treat the earlier failed runs as passes.

The latest local Duo restart reported Data Migration Failed before tests ran. Separate attempts then failed to enumerate simulator destinations. These are environment failures, not successful app validation. Hosted CI at `dea3d22` failed while initializing its UI runner (AXDisableAccessibilityOnTermination), before executing app tests. CI now waits for simulator boot and runs UI tests serially. Final exact-commit CI outcomes and all remaining software results belong in `.release/resubmission-readiness.md`. Physical qualification remains explicitly unpassed.
