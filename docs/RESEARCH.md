# iPhone Duo feasibility research

Checked September 14, 2026. Primary sources only for platform/API decisions.

## Platform and toolchain

Apple has a dedicated [iPhone Duo developer hub](https://developer.apple.com/iphone-duo/). Its tools section explicitly labels **Xcode 27.1 beta** as **coming later this month**. This is why the repo has a working compatibility scheme and a separately gated new-SDK scheme instead of unconditionally referencing SDK symbols that cannot yet be validated here.

The [Prepare your app talk](https://developer.apple.com/videos/play/tech-talks/111461/) describes Xcode 27.1/Device Hub testing, scene-relative geometry, asymmetric safe areas, resizing, and size classes. The talk's instruction to use/download 27.1 does not override the hub's explicit availability notice. We could verify the announced APIs through the talks, but did not retrieve complete reference declarations or SDK headers for the hinge types.

## What can be detected?

[Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/), 0:49–2:35, documents SwiftUI `onHingeChange`, UIKit `UIHingeInteraction`, optional `context.hinge`, high-level hinge status, and live angle updates. Its sample identifies `hinge.angle` as `SwiftUI.Angle`. A nil hinge indicates a device without one. The talk also explains multiple app windows on the inner display.

Implementation: one app-wide model elects a single active scene as sensor leader. The adapter forwards the current angle; it never derives a fold from window width, orientation, size class, or screen identity. It does not replay the callback's previous context across activation. Runtime availability is conservatively gated to iOS 27.1; the exact SDK availability annotations must still be checked.

**Unverified hardware detail:** the adapter currently assumes 0° means closed and 180° means flat. Those endpoints were not established by the accessible sample. Confirm/normalize them in the adapter before enabling production tracking. The 10°/170°/0.35-second detector policy is our initial design, not Apple's specifications.

## Background counting is a separate capability

The hinge talk describes **live** observations. We found no documented event-history query, lifetime fold total, replay guarantee, or entitlement for continuous background hinge monitoring.

Apple DTS's [iOS Background Execution Limits](https://developer.apple.com/forums/thread/685525), updated January 9, 2026, explains suspension, discretionary background refresh, and force-quit semantics. It does not establish a sensor-history API. A timer, Background App Refresh, a Live Activity, or unrelated audio/location modes would not legitimately solve the missing observation problem.

Conclusion: implement foreground observation conservatively and label its coverage, rather than promising Android-equivalent always-on counting. Reassess only when primary documentation establishes a legitimate background/history capability. Inactive/leader-change gaps reset the detector; missed openings are possible, including during display handoff, and must be tested.

## Layout and widgets

[Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) recommends flexible compact/regular layouts, reachable system controls, safe areas, and avoiding interactions across a partial fold. [Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/), 8:39–16:34, explains arrangement containers and keeping them outside scrollable content and inside navigation. The Duo scheme uses `ArrangementView`; the regular scheme uses size classes. Neither layout path manufactures sensor data.

[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) describes budgeted reloads. Our widget is a read-only snapshot consumer. It precomputes the next local-midnight entry to avoid labeling yesterday's count as today's, without claiming immediate reloads or background sensor execution.

## Reference Android app

The [Google Play listing](https://play.google.com/store/apps/details?hl=en_US&id=com.themobilecoder.foldcounter), updated August 24, 2026, describes automatic opening counts, daily totals/average, all-time totals, offline operation, and Android background/battery troubleshooting. Those are product requirements, not proof of equivalent iOS privileges. We implement the local statistics experience while explicitly withholding an always-on claim. No original app assets or implementation were extracted.
