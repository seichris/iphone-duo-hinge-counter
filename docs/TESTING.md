# Testing and release gates

## Executable checks

`swift test` runs the real Swift detector, scene coordinator, statistics, serialization, and file persistence. The app and widget compile these same core source files; there is no second implementation. `python3 scripts/check_project.py` checks the generated project graph, resources, schemes, entitlements, and privacy manifest. Neither command replaces an iOS build.

The macOS workflow builds the regular app/widget, runs UI smoke tests, and probes installed SDK declarations with `scripts/select_xcode.py --duo --optional`. When the probe succeeds, CI compiles **FoldCounter Duo** for both a simulator and a generic iOS device; otherwise an explicit notice records that the Duo branch was skipped. Test artifacts are retained for inspection. A compatibility-scheme pass never proves the new SDK adapter compiles.

To verify Shortcuts action dispatch, use an iOS 27.2 or later simulator runtime matching Xcode. Run the Duo UI test with the flags below alongside the usual project, scheme and destination arguments. Apple's AppIntentsTesting framework ships with Xcode and can fail to load against an older simulator runtime, so ordinary UI tests omit this dependency.

```sh
xcodebuild test -project FoldCounter.xcodeproj -scheme 'FoldCounter Duo' \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -only-testing:FoldCounterUITests/FoldCounterUITests/testRecordOpeningActionWhileAnotherAppIsFrontmost \
  OTHER_SWIFT_FLAGS='$(inherited) -D TEST_SHORTCUT_DISPATCH'
```

On November 6, 2026, Xcode 27.2 (27B52) built the Debug compatibility and Duo Debug simulator targets with the iOS 27.2 SDKs, and Duo Release for a generic iOS device with signing disabled. All 56 Swift tests passed. On the 27.1 Duo simulator, directly invoking the action with no foreground scene saved one Shortcuts entry. A fresh process read it back and a paused invocation left it intact. The system-dispatch test compiled. Xcode's 27.2 AppIntentsTesting framework could not load on the 27.1 runtime, so physical trigger delivery and app focus during system dispatch still need verification.

### iOS 27.2 Duo simulator

On Apple silicon, Xcode 27.2 offers two iOS 27.2 images. Install the Duo-specific build and select its runtime identifier when creating a simulator.

```sh
xcodebuild -downloadPlatform iOS -buildVersion 24B91016s -architectureVariant arm64
xcrun simctl create 'Hinge Counter 27.2 Duo' com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
  com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
```

On November 7, 2026, with Hinge Counter visible, Device Hub’s Closed pose produced a 0° live reading. Selecting Open produced a 180° reading and one saved observed opening. The Shortcuts and manual subtotals stayed at zero.

On the same simulator, `testRecordOpeningActionWhileAnotherAppIsFrontmost` passed with Xcode 27.2 (27B52). The test selected Shortcuts counting, put iOS Settings in the foreground and waited for Hinge Counter to enter the background. System dispatch of `RecordOpeningIntent` kept Settings in front and saved exactly one Shortcuts entry, which survived an app relaunch. This test invokes the action directly. Device Hub’s pose controls exercise the opening trigger separately.

In the manual test, Hinge Counter’s Shortcuts button opened its page. Touching and holding **Record Opening** and choosing **New Shortcut** created a shortcut with that one action. Opening the **Automation** category in the editor showed other triggers. Searching the category for “iPhone” returned an empty list. Shortcuts also labeled the opening trigger in a signed reference shortcut **Unsupported Automation** in the read-only preview. Opening our unsigned template in Files produced the system’s unsigned-file rejection. [Signed opening-only reference](https://www.icloud.com/shortcuts/1fd3278bedd543a79181d5f3f99a287f).

With Shortcuts counting enabled and iOS Settings in front, the saved Shortcuts subtotal was 1 before selecting **Closed**, 1 after closing, and 1 after selecting **Open**. Settings remained frontmost and the observed and manual subtotals were zero throughout. The single entry came from the earlier direct action test. The simulator could exercise the hinge and the background action separately. End-to-end delivery of the personal opening automation still needs a physical iPhone Duo on iOS 27.2 or later.

### Building the shared opening automation

The reviewed source is `shortcuts/Count iPhone Duo Openings.plist`. On a Mac with a Shortcuts version that preserves Duo automations, run:

```sh
python3 scripts/opening_shortcut.py sign
python3 scripts/opening_shortcut.py verify
python3 scripts/generate_project.py
```

The signer stages the file, verifies its certificate chain and archive signature, and compares the enclosed workflow with the source before installing it under `Resources`. Apple's signing command on macOS 26.7.2 returned success but stripped `WFWorkflowTriggers`. The verification step rejected that file. The project includes the installer only when a signed template is available. The existing App Shortcuts setup remains available for other builds.

On November 7, 2026, Apple's signer on GitHub's macOS 27.0.1 runner required an iCloud login and exited before creating a file. The temporary signing branch was removed. A shareable template still needs a successful sign and verification on an iCloud-signed-in Mac whose Shortcuts exporter preserves the opening trigger. [Signing run](https://github.com/seichris/iphone-duo-hinge-counter/actions/runs/42310749091).

On iPhone Duo with iOS 27.2 or later, choose Shortcuts counting and tap **Add opening automation**. In Shortcuts, confirm the import shows one opening trigger and one **Record Opening** action. Enable that single automation and allow immediate runs. Adding the file should leave the total unchanged. With another app frontmost, a close alone should add zero and a subsequent open should add one Shortcuts entry. Also check cancelling the import, reopening Settings, and saving the file to Files when no registered app can take it directly.

## Required before claiming real Duo support

1. Build **FoldCounter Duo** with Xcode 27.1 and the iOS 27.1 SDK for distribution, then run it on the iOS 27.1 Duo simulator. Confirm that the SDK-typed public `UIHingeInteraction` delivers optional angles, and verify angle units/endpoints and API availability against Apple's current declarations. Update only the adapter when normalization is needed.
2. In Device Hub and then physical hardware, log actual samples while switching outer/inner screens, closing completely, opening fully, rotating, and using side-by-side apps. Determine whether an active scene can observe a complete closed-to-open cycle. Our conservative scene reset may intentionally miss a cycle at a display handoff; do not loosen it without evidence.
3. Verify 100 slow full openings produce 100 observed counts in a genuinely continuous observation session. Partial adjustments, parked-open use, window resizing, and callback jitter must not add counts. Validate thresholds and the minimum cycle interval; they are currently engineering assumptions.
4. Test two simultaneous app windows. Only one scene may count. Opening/dismissing a second window must not duplicate an event. Inactivating all windows or changing leaders must reset continuity.
5. Lock/unlock, background/foreground, pause/resume, force-quit/relaunch, and cross midnight. No retroactive fold should be inferred from a changed pose. Explicitly check that the app's foreground-only explanation remains accurate.
6. Test VoiceOver, accessibility text sizes, Reduce Motion, light/dark mode, compact/regular sizes, all poses, and asymmetric safe areas. Visually inspect both widgets and all tabs; syntax parsing is not visual validation.
7. Confirm the registered App Group and both signing entitlements. Widget setup failures must leave app counts intact. Widget midnight transitions must show zero recorded for the new day unless that bucket has saved data. WidgetKit scheduling remains system-controlled.
8. Exercise write errors, damaged JSON, oversized/unknown-version backups, export cancellation, restore cancellation, restore replacement, and confirmed reset. Never publish a new UI total before its authoritative save succeeds. On a pending-save failure, retry persists the same candidate; additional sensor events are not accepted.
9. On a physical Duo running iOS 27.2 or later, select Shortcuts in Settings. Tap the Shortcuts button and verify Hinge Counter’s page offers Record Opening. Return to Hinge Counter and check that opening the page left the total unchanged. Reopen the page, touch and hold Record Opening, choose New Shortcut, and use the editor’s Automation category to configure one opening-only automation to run immediately. With another app frontmost, close and open the phone ten times. The other app should stay on screen and the Shortcuts subtotal should increase by ten. Repeat with Hinge Counter visible and verify the observed subtotal stays fixed. Check paused counting, return to the foreground sensor, and verify a close by itself adds nothing. Record locked, post-restart and force-quit behavior separately before claiming coverage for those states.

## Current product boundaries

The app knows only the openings a foreground session observed and the entries explicitly recorded by Shortcuts or manual input. A Shortcuts action can be run by hand. There is no history backfill. The demo never writes production data.

## Privacy and distribution

Review the final archived privacy report and App Store text with the actual shipping SDK. The source uses no UserDefaults, direct boot-time API, analytics, advertising, networking, or unjustified background capability. Its timebase is Swift `ContinuousClock`. Reevaluate required-reason declarations if a later SDK or dependency introduces covered APIs. Do not ship a speculative background-mode workaround or unsupported hardware claims.
