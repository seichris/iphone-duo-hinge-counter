# Hinge Counter for iPhone Duo

A native, offline SwiftUI hinge-opening counter. The app uses the supplied Duo Counter logo; no Android code or assets are copied.

**Status — September 14, 2026:** Hinge Counter, history, backup tools, demo, and the WidgetKit extension are implemented. The announced iPhone Duo hinge integration is isolated behind the **FoldCounter Duo** scheme. It has not been type-checked against the forthcoming SDK or tested on physical hardware. Apple's [developer hub](https://developer.apple.com/iphone-duo/) currently lists Xcode 27.1 beta as coming later this month. The regular scheme does **not** claim to detect a hinge.

**This is not a 24/7 background hinge counter.** No documented background hinge-event history API was found. The live adapter observes only while the app has an active scene; counts across suspension, lock, termination, or switching apps are not reconstructed. Opening this app on an already-open device does not add a count. Read [the research and capability boundaries](docs/RESEARCH.md) before changing product claims.

## Included

- Today, all-time recorded totals, and daily average; observed and manual counts kept separate.
- Seven-, 30-, and 90-day history charts and accessible daily breakdowns.
- Adaptive compact/regular layouts, native navigation, dark mode, Dynamic Type, and Reduce Motion support. The Duo scheme adopts the announced system arrangement container.
- A one-leader, multiwindow-safe hinge state machine with wide angle hysteresis, duplicate rejection, and lifecycle invalidation.
- Local atomic JSON persistence; corrupted files are not silently replaced. Failed writes pause counting and preserve one pending change for retry.
- CSV export, versioned JSON backup/restore with validation and replacement confirmation, and explicit erase confirmation.
- Small/medium Home Screen and rectangular Lock Screen widgets. Widgets display snapshots, not live sensor monitoring.
- An isolated, interactive demo that never changes real totals.
- Swift Package core tests, UI smoke tests, reproducible Xcode-project/icon generation, and macOS CI.

## Open and run

On a Mac with Xcode, an iOS 18+ SDK, Swift 6, and Python 3:

```sh
git clone https://github.com/seichris/iphone-duo-hinge-counter.git
cd iphone-duo-hinge-counter
python3 scripts/generate_project.py
open FoldCounter.xcodeproj
```

Select **FoldCounter**, choose an iPhone simulator, and Run. Manual entries and the unsaved demo work without foldable hardware. The project is generated using Python's standard library and the supplied opaque 1024px App Store icon is checked in; no XcodeGen, CocoaPods, or external Swift packages are needed.

For a physical device, select your signing team for the app and widget targets. Register/use a matching App Group; the project-level `APP_GROUP_IDENTIFIER` defaults to `group.com.seichris.foldcounter`. Change the bundle identifiers and App Group together when using a different developer account. The counter stores its authoritative data in the app sandbox and remains functional if widget sharing is unavailable.

### The Duo scheme

Once Apple's Xcode 27.1 SDK is actually available, select **FoldCounter Duo** and a compatible runtime. This enables `DUO_HINGE_API`, including the announced `onHingeChange` and `ArrangementView` calls. Do not treat a passing regular-scheme build as validation of those calls. Verify SDK signatures, angle convention, callback/lifecycle behavior during inner/outer display handoff, and device measurements first. See [release gates](docs/TESTING.md).

Our initial policy is an observed angle of at most 10°, then at least 170°, separated by at least 0.35 seconds. These are app thresholds, not Apple sensor specifications. The adapter's assumption of 0° closed / 180° flat still needs verification against the SDK and hardware. No durability rating or device-lifetime count is assumed.

## Test

```sh
swift test
python3 scripts/generate_project.py
python3 scripts/check_project.py
# macOS / Xcode only:
xcodebuild -project FoldCounter.xcodeproj -scheme FoldCounter \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For UI tests choose a concrete simulator with `xcodebuild -showdestinations`, then run `xcodebuild test` using its destination ID. CI selects an available iPhone simulator automatically. UI tests write to a separate test subdirectory and never publish to the real widget App Group.

[Validation performed during implementation](docs/VALIDATION.md) distinguishes executed checks from unexecuted SDK/hardware tests.

## Data and privacy

No backend, sign-in, network requests, advertising, analytics, third-party SDKs, or special background modes. App data may be included in the user's OS/device backups. Files leave the app only through user-initiated export/sharing or those OS backup settings.

Days are Gregorian local dates at recording time and do not shift when traveling. Daily averages divide all recorded opens, including manual entries, by inclusive calendar days since tracking began, including zero days and the current partial day. Time-zone travel across the date line can temporarily make the current date earlier than a recorded bucket; all-time counts are preserved. A zero bucket means nothing was recorded, not that the phone was never opened.

The app is independent of Apple and TMC Apps. Distribution licensing has not been selected; this repository does not import a third-party app's license or grant a new one implicitly.


## App Store preparation

The release-preparation pack is in [docs/APP_STORE_RELEASE.md](docs/APP_STORE_RELEASE.md), with [ASO and web SEO research](docs/ASO_RESEARCH.md) and candidate English metadata in `appstore/metadata/en-US.json`.

```sh
python3 -m unittest discover -s scripts/tests -v
python3 scripts/build_site.py --check
python3 scripts/release_preflight.py
```

A passing draft check is not permission to publish. The strict preflight requires current-commit evidence, real screenshots and live support/privacy pages. The standard scheme is now **Debug-only**; non-Duo distribution builds are intentionally rejected. Use `FoldCounter Duo` for the final archive only after its SDK and physical-device gates pass. Signing, App Store Connect account setup and actual submission are not performed by this repository.
