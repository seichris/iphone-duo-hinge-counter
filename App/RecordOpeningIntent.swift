#if DUO_HINGE_API
import AppIntents

// The recording action can run on the Duo's original OS. Apple's opening
// automation requires iOS 27.2, which is where Settings offers new setup.
@available(iOS 27.1, *)
struct RecordOpeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Opening"
    static let description = IntentDescription("Save one Shortcuts entry. Select Shortcuts in Hinge Counter settings before using this action.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult {
        try CounterModel.shared.recordShortcutOpening()
        return .result()
    }
}

@available(iOS 27.1, *)
struct HingeCounterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordOpeningIntent(), phrases: ["Record an opening in \(.applicationName)"],
                    shortTitle: "Record Opening", systemImageName: "rectangle.split.2x1")
    }
}
#endif
