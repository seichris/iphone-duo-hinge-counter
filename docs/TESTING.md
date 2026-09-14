# Testing and release gates

## Executable checks

`swift test` runs the real Swift detector, scene coordinator, statistics, serialization, and file persistence. The app and widget compile these same core source files; there is no second implementation. `python3 scripts/check_project.py` checks the generated project graph, resources, schemes, entitlements, and privacy manifest. Neither command replaces an iOS build.

The macOS workflow builds the regular app/widget, runs UI smoke tests, and attempts the Duo scheme only if the selected SDK version is at least 27.1. An explicit CI notice records when that SDK check is skipped. Test artifacts are retained for inspection. A compatibility-scheme pass never proves the new SDK adapter compiles.

## Required before claiming real Duo support

1. Compile **FoldCounter Duo** using the released matching SDK. Confirm `onHingeChange` closure isolation/signature, optional hinge semantics, angle units/endpoints, API availability, and arrangement API names against headers. Update only the adapter when normalization is needed.
2. In Device Hub and then physical hardware, log actual samples while switching outer/inner screens, closing completely, opening fully, rotating, and using side-by-side apps. Determine whether an active scene can observe a complete closed-to-open cycle. Our conservative scene reset may intentionally miss a cycle at a display handoff; do not loosen it without evidence.
3. Verify 100 slow full openings produce 100 observed counts in a genuinely continuous observation session. Partial adjustments, parked-open use, window resizing, and callback jitter must not add counts. Validate thresholds and the minimum cycle interval; they are currently engineering assumptions.
4. Test two simultaneous app windows. Only one scene may count. Opening/dismissing a second window must not duplicate an event. Inactivating all windows or changing leaders must reset continuity.
5. Lock/unlock, background/foreground, pause/resume, force-quit/relaunch, and cross midnight. No retroactive fold should be inferred from a changed pose. Explicitly check that the app's foreground-only explanation remains accurate.
6. Test VoiceOver, accessibility text sizes, Reduce Motion, light/dark mode, compact/regular sizes, all poses, and asymmetric safe areas. Visually inspect both widgets and all tabs; syntax parsing is not visual validation.
7. Confirm the registered App Group and both signing entitlements. Widget setup failures must leave app counts intact. Widget midnight transitions must show zero recorded for the new day unless that bucket has saved data. WidgetKit scheduling remains system-controlled.
8. Exercise write errors, damaged JSON, oversized/unknown-version backups, export cancellation, restore cancellation, restore replacement, and confirmed reset. Never publish a new UI total before its authoritative save succeeds. On a pending-save failure, retry persists the same candidate; additional sensor events are not accepted.

## Current product boundaries

Not a lifetime device counter, background activity monitor, diagnostic test, hinge wear estimate, or durability guarantee. The app does not know about openings before installation or during observation gaps. A manual opening stays labeled manual. The demo never writes production data.

## Privacy and distribution

Review the final archived privacy report and App Store text with the actual shipping SDK. The source uses no UserDefaults, direct boot-time API, analytics, advertising, networking, or unjustified background capability. Its timebase is Swift `ContinuousClock`. Reevaluate required-reason declarations if a later SDK or dependency introduces covered APIs. Do not ship a speculative background-mode workaround or unsupported hardware claims.
