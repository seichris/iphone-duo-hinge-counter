import SwiftUI

@main
struct FoldCounterApp: App {
    // One app-wide model is shared by every window. Never create a counter per scene.
    @State private var model = CounterModel()

    var body: some Scene {
        WindowGroup {
            CounterRootView()
                .environment(model)
                .tint(.mint)
        }
    }
}
