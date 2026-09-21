import SwiftUI

#if DUO_HINGE_API
import ObjectiveC
import UIKit
#endif

/// The Duo build keeps the explicit integration gate, but resolves Apple's
/// public UIKit hinge interaction at runtime. This lets the distribution
/// archive use a supported stable SDK while iOS 27.1 supplies the interaction
/// on compatible Duo hardware or the Duo simulator.
struct DuoHingeObserver: ViewModifier {
    @Environment(CounterModel.self) private var model
    let scene: UUID

    @ViewBuilder func body(content: Content) -> some View {
        #if DUO_HINGE_API
        let observationID = model.subscription(for: scene)
        content.background(
            HingeInteractionBridge { degrees in
                guard let observationID else { return }
                model.receive(degrees: degrees, scene: scene, observationID: observationID)
            }
            .frame(width: 0, height: 0)
        )
        #else
        content
        #endif
    }
}

#if DUO_HINGE_API
/// A zero-size view that installs Apple's public hinge interaction into the
/// SwiftUI hierarchy. The runtime lookup keeps the archive buildable with
/// stable Xcode while retaining live updates on iOS 27.1 Duo runtimes.
@MainActor
private struct HingeInteractionBridge: UIViewRepresentable {
    let onAngle: (Double?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAngle: onAngle)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        if let interaction = context.coordinator.makeInteraction() {
            view.addInteraction(interaction)
        } else {
            // Ordinary iPhones and pre-27.1 systems report hinge absence.
            onAngle(nil)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onAngle = onAngle
    }

    @MainActor
    final class Coordinator {
        var onAngle: (Double?) -> Void
        private var interaction: UIInteraction?

        init(onAngle: @escaping (Double?) -> Void) {
            self.onAngle = onAngle
        }

        func makeInteraction() -> UIInteraction? {
            guard #available(iOS 27.1, *) else { return nil }
            guard let interactionType = NSClassFromString("UIHingeInteraction") as? NSObject.Type else {
                return nil
            }

            // UIHingeInteraction's initializer is unavailable to the stable
            // SDK. Allocate the public class and invoke its documented
            // initWithUpdateHandler: entry point through Objective-C runtime
            // metadata; no private framework or selector is introduced.
            let raw = class_createInstance(interactionType, 0) as! NSObject
            let handler: @convention(block) (AnyObject, AnyObject) -> Void = { [onAngle] _, update in
                let hinge = (update as? NSObject)?.value(forKey: "hinge") as? NSObject
                let radians = (hinge?.value(forKey: "angle") as? NSNumber)?.doubleValue
                let degrees = radians.map { $0 * 180 / .pi }
                Task { @MainActor in
                    onAngle(degrees)
                }
            }
            let selector = NSSelectorFromString("initWithUpdateHandler:")
            guard let initialized = raw.perform(selector, with: handler)?.takeUnretainedValue() as? NSObject,
                  let interaction = initialized as? UIInteraction else {
                return nil
            }
            self.interaction = interaction
            return interaction
        }
    }
}
#endif

/// Hinge data is for counting; layout uses size classes/system arrangements instead.
struct AdaptiveDashboard<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let primary: Primary
    let secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    @ViewBuilder var body: some View {
        // The stable distribution build uses the same size-class-aware layout
        // on ordinary devices and Duo. It avoids a compile-time dependency on
        // the beta-only ArrangementView while keeping both panels reachable.
        standardLayout
    }

    private var standardLayout: some View {
        ScrollView {
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 24) {
                    primary.frame(maxWidth: .infinity)
                    secondary.frame(maxWidth: .infinity)
                }.padding(24)
            } else {
                VStack(spacing: 20) { primary; secondary }.padding()
            }
        }
    }
}
