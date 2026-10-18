# Physical Duo qualification

This is an execution checklist, not a passing result. Use candidate 1.0.0 (6) after processing, or record a replacement build explicitly. Store device identifiers, recordings, sample logs and signed-artifact hashes privately in `.release/`. Do not infer hardware results from Simulator, the unsaved demo or synthetic core tests.

## Record the test identity

Record the exact device model, OS version/build, app version/build, TestFlight build ID, source/application-input identity and test date. Confirm the installed app is the distribution candidate, not a Debug UI-test app. Use a throwaway counter record for destructive tests.

## Qualify observation

1. Record actual hinge samples when closed, partially open and flat. Verify that UIKit radians convert to the intended degree endpoints. The current adapter assumes 0° closed and 180° flat; these endpoints remain unqualified. Record nil updates and scene activity alongside angles.
2. Exercise outer-to-inner and inner-to-outer handoff, all orientations, partial folds, side-by-side apps and two app windows. Establish whether any active scene observes a complete closed-to-open cycle. One app-wide model and one active sensor leader must prevent duplicates. A leader change or observation gap must break continuity, even when that intentionally misses an opening.
3. In a demonstrably continuous session, count 100 slow full openings against a recording/manual tally. Require 100 observed events. Separately try partial adjustments, parked-open use, window resizing, jitter and rapid cycles. Do not tune the 10°/170°/0.35-second policy without recorded evidence and regression tests.
4. Test pause/resume, inactive/active transitions, lock/unlock, background/foreground, force-quit/relaunch, leader changes and midnight. Initial poses and changed poses after a gap must never count retroactively. Confirm the foreground-only disclosure describes the measured behavior.

## Qualify the distribution app and widgets

5. Exercise Today, History, manual attribution, offline help/privacy, CSV export, JSON backup/restore and confirmed reset in the actual TestFlight app. Check share-sheet cancellation and restore cancellation. Manual entries must stay distinct from sensor observations.
6. Add Home Screen and Lock Screen widgets. Verify matching App Group entitlements, saved snapshot contents, ordinary refresh behavior and the next local-midnight entry. Widgets never observe the hinge or write authoritative history. Installation and WidgetKit scheduling need real-device evidence.
7. Check VoiceOver navigation and spoken values, accessibility text sizes, Reduce Motion, light/dark appearance, compact/regular windows, fold poses and asymmetric safe areas. Simulator layout checks do not establish physical handoff behavior or the distribution app's device accessibility.

## Close the gate

Record expected/actual outcomes and links to private evidence for each item. If observation cannot deliver useful complete cycles under the stated foreground-only contract, resolve the product behavior and copy before submission; do not loosen continuity safeguards to make a tally pass.

After a passing qualification, replace the measured-device placeholders in `appstore/review-notes.txt`, attach a real-device recording in App Store Connect and refresh exact-commit evidence for `sdk_and_hardware` and `testflight_and_accessibility`. Re-run the strict local preflight and App Store validation. Reconcile the rejected review item and submit only when separately authorized. Keep manual release selected.
