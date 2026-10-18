import SwiftUI

#if DUO_HINGE_API
import UIKit
#endif

/// The shipping scheme requires the iOS 27.1 SDK. The compatibility scheme
/// excludes the hinge API and remains useful for ordinary-device Debug testing.
struct DuoHingeObserver: ViewModifier {
    @Environment(CounterModel.self) private var model
    let scene: UUID

    @ViewBuilder func body(content: Content) -> some View {
        content.background {
            #if DUO_HINGE_API
            if #available(iOS 27.1, *), let observationID = model.subscription(for: scene) {
                HingeInteractionBridge { degrees in
                    model.receive(degrees: degrees, scene: scene, observationID: observationID)
                }
                // A new subscription gets a new interaction and initial update.
                // Old callbacks retain their original ID and are rejected by the model.
                .id(observationID)
                .frame(width: 0, height: 0)
            }
            #endif
        }
    }
}

#if DUO_HINGE_API
@available(iOS 27.1, *)
@MainActor
private struct HingeInteractionBridge: UIViewRepresentable {
    let onAngle: (Double?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let interaction = UIHingeInteraction { _, update in
            // UIKit documents radians; absence breaks observation continuity.
            onAngle(update.hinge.map { Double($0.angle) * 180 / .pi })
        }
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        for interaction in uiView.interactions {
            if let hinge = interaction as? UIHingeInteraction {
                hinge.isEnabled = false
            }
            uiView.removeInteraction(interaction)
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
        // Available space drives layout on ordinary devices and Duo alike.
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
