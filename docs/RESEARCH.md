# iPhone Duo feasibility research

Hinge SDK checked October 18, 2026. Shortcuts update checked November 7, 2026. Primary sources only for platform/API decisions.

## Platform and toolchain

Apple's [October 5 submission announcement](https://developer.apple.com/news/?id=kkphp5qo) explicitly permits submitting Duo optimized apps ahead of the October 23 hardware launch. This supersedes the earlier SDK availability note; it does not establish this app's physical sensor behavior.

The October SDK qualification used Xcode 27.1 RC (27A9275), with iOS 27.1 device/simulator SDKs and simulator runtime 24A94401. `scripts/select_xcode.py --duo` type-checks both the UIKit hinge adapter surface and the announced SwiftUI APIs. The Duo scheme now requires this SDK and directly constructs public `UIHingeInteraction`; it no longer uses Objective-C allocation, selectors or KVC to bridge an older SDK.

The installed public UIKit headers specify that `UIHinge.angle` is in radians, the update handler is main-actor isolated, nil hinge updates break hierarchy continuity, and enabling an interaction delivers the current state when available. Conversion to degrees occurs only in the adapter. Each observation subscription creates a fresh interaction; its closure keeps the original subscription identity so callbacks from an older session remain rejectable.

## What can be detected?

[Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/), 0:49–2:35, documents SwiftUI `onHingeChange`, UIKit `UIHingeInteraction`, optional `context.hinge`, high-level hinge status, and live angle updates. Its sample identifies `hinge.angle` as `SwiftUI.Angle`. A nil hinge indicates a device without one. The talk also explains multiple app windows on the inner display.

Implementation: one app-wide model elects a single active scene as sensor leader. The `DUO_HINGE_API` adapter installs the SDK-typed `UIHingeInteraction` and forwards the current angle; it never derives a fold from window width, orientation, size class, or screen identity. Subscription identities reject delayed callbacks after lifecycle, scene-leader, storage, or settings discontinuities. It does not replay the callback's previous context across activation. Runtime availability is gated to iOS 27.1.

Device Hub on iOS 27.2 Duo build `24B91016s` delivered 0° in the Closed pose and 180° in the Open pose. Hinge Counter recorded one foreground opening on that transition. Physical-device endpoint and continuity checks remain open. The 10°/170° thresholds and 0.35-second timing are the app’s own detector settings.

## Background counting is a separate capability

The hinge talk describes **live** observations. We found no documented event-history query, lifetime fold total, replay guarantee, or entitlement for continuous background hinge monitoring.

Apple DTS's [iOS Background Execution Limits](https://developer.apple.com/forums/thread/685525), updated January 9, 2026, explains suspension, discretionary background refresh, and force-quit semantics. It does not establish a sensor-history API. A timer, Background App Refresh, a Live Activity, or unrelated audio/location modes would not legitimately solve the missing observation problem.

The live sensor still requires an active scene. Inactive periods and leader changes reset the detector. The public iOS 27.2 UIKit headers expose the current state for a view's hinge interaction. Re-enabling a disabled interaction delivers its current state, with no queue of missed updates.

### Counting from a Shortcuts automation

Apple added a personal automation for opening or closing an iPhone Duo in iOS 27.2. The user can select opening only and run the app's Record Opening action while using another app. Shortcuts owns the trigger. The action runs in the app process and shares the same serial archive writer as the UI. [Apple's Shortcuts release notes](https://support.apple.com/en-us/149045) and [App Intent execution modes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes).

The user selects one counting method at a time. Each successful action invocation creates a Shortcuts entry, including when someone runs it by hand. The action receives no verified hinge angle, hardware event identifier or replay of earlier openings. Configure one automation with one action. Delivery with another app in front, during lock, and after force-quit requires physical qualification.

Settings uses Apple's native `ShortcutsLink` to open Hinge Counter’s App Shortcuts page. Touching and holding Record Opening and choosing New Shortcut starts the editor with that action. The action library contains the Automation category. On Duo simulator build `24B91016s`, the opening trigger was missing from that category and Shortcuts labeled the same trigger in an existing signed workflow “Unsupported Automation.” Shortcuts owns the trigger and its on-device enablement. [ShortcutsLink](https://developer.apple.com/documentation/appintents/shortcutslink) · [Using an app shortcut](https://support.apple.com/guide/shortcuts/apd43295406d/10.0/ios/27) · [Adding an automation](https://support.apple.com/guide/shortcuts/apdfbdbd7123/10.0/ios/27).

The preconfigured template uses one `WFMultiTaskingArrangementTrigger`. The Apple-hosted opening-only export has an empty `WFTriggerSerializedParameters` dictionary. The closed-only and either-direction exports set `WFArrangementMode` to `ModeB` and `Any`, respectively. These are serialized fields in a shared Shortcuts document. The app opens that document using public UIKit file handling. Its single action identifies `com.seichris.foldcounter.RecordOpeningIntent` and the distribution team from the 1.1.1 (9) archive. The template has its own trigger UUID and contains only Hinge Counter’s action. [Opening-only export](https://www.icloud.com/shortcuts/1fd3278bedd543a79181d5f3f99a287f) · [Closed-only export](https://www.icloud.com/shortcuts/ed6201da899b41058095c1f725780da2) · [Either-direction export](https://www.icloud.com/shortcuts/7310427e7efe43828dff9014a129761e).

## Layout and widgets

[Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) recommends flexible compact/regular layouts, reachable system controls, safe areas, and avoiding interactions across a partial fold. [Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/), 8:39–16:34, explains arrangement containers and keeping them outside scrollable content and inside navigation. The shipping scheme uses size-class-aware native layout based on available space. Neither layout path manufactures sensor data.

[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) describes budgeted reloads. Our widget is a read-only snapshot consumer. It precomputes the next local-midnight entry to avoid labeling yesterday's count as today's, without claiming immediate reloads or background sensor execution.

## Reference Android app

The [Google Play listing](https://play.google.com/store/apps/details?hl=en_US&id=com.themobilecoder.foldcounter), updated August 24, 2026, describes automatic opening counts, daily totals/average, all-time totals, offline operation, and Android background/battery troubleshooting. Those are product requirements, not proof of equivalent iOS privileges. We implement the local statistics experience while explicitly withholding an always-on claim. No original app assets or implementation were extracted.
