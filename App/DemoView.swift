import SwiftUI

/// Entirely local fixture: no CounterModel, ArchiveFile, App Group, or WidgetCenter.
struct DemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detector = FoldDetector()
    @State private var angle = 180.0
    @State private var time = 0.0
    @State private var count = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Label("DEMO · NEVER SAVED", systemImage: "testtube.2")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    FoldGlyph(degrees: angle).frame(width: 200, height: 130).accessibilityHidden(true)
                    Text(count.formatted())
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("demoCount")
                    Text("simulated opens").foregroundStyle(.secondary)
                    // An explicit closure avoids a Swift 6.1 x86_64 IRGen crash
                    // when converting the actor-isolated method reference to a setter.
                    Slider(value: Binding(get: { angle }, set: { sample($0) }), in: 0...180)
                        .accessibilityLabel("Simulated hinge angle")
                    Text("\(Int(angle))°").monospacedDigit()
                    HStack {
                        Button("Close") { sample(0) }.buttonStyle(.bordered)
                        Button("Open fully") { sample(180) }.buttonStyle(.bordered)
                    }
                    Button("Simulate one fold") {
                        for degrees in [0.0, 60, 120, 180] { sample(degrees) }
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("simulateFold")
                    Text("Close, then open fully. Partial movements do not add another count. "
                         + "This uses synthetic one-second steps, not a real hinge. Your saved totals stay unchanged.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Reset demo") { detector.reset(); count = 0; angle = 180; time = 0 }
                }.padding(24).frame(maxWidth: 600)
            }
            .navigationTitle("Try a fold")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.accessibilityIdentifier("closeDemo")
            } }
        }
    }

    private func sample(_ degrees: Double) {
        angle = degrees
        time += 1
        if detector.observe(degrees: degrees, timestamp: time) { count += 1 }
    }
}
