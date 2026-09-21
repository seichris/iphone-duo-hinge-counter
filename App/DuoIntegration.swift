import SwiftUI

/// Matches Apple's iOS 27.1 reference, checked 2026-09-20. The SDK build,
/// angle endpoints and runtime behavior remain explicit gates (docs/VALIDATION.md).
struct DuoHingeObserver: ViewModifier {
    @Environment(CounterModel.self) private var model
    let scene: UUID

    @ViewBuilder func body(content: Content) -> some View {
        #if DUO_HINGE_API
        if #available(iOS 27.1, *) {
            let observationID = model.subscription(for: scene)
            content.onHingeChange(isEnabled: observationID != nil) { _, context in
                guard let observationID else { return }
                // Deliberately do not replay the previous context on resume.
                // The talk identifies hinge.angle as SwiftUI.Angle.
                model.receive(degrees: context.hinge?.angle.degrees, scene: scene,
                              observationID: observationID)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

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
        #if DUO_HINGE_API
        if #available(iOS 27.1, *) {
            // ArrangementView is outside scrollable content and inside navigation.
            ArrangementView {
                ScrollView { primary.padding() }
            } secondary: {
                ScrollView { secondary.padding() }
            }
            .arrangementViewStyle(.split)
        } else {
            standardLayout
        }
        #else
        standardLayout
        #endif
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
