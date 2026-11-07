#if DUO_HINGE_API
import AppIntents
import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The shipped automation names the distribution app's bundle and team.
/// A development app with a different identifier must offer its own App Shortcut instead.
struct OpeningAutomationSetup: View {
    @Environment(CounterModel.self) private var model
    @State private var savingCopy = false
    private let file: URL? = Bundle.main.bundleIdentifier == "com.seichris.foldcounter"
        ? Bundle.main.url(forResource: "Count iPhone Duo Openings", withExtension: "shortcut") : nil

    var body: some View {
        Section {
            if let file {
                OpenShortcutDocument(file: file) { savingCopy = true }
                    .frame(minHeight: 44)
                    .fileExporter(isPresented: $savingCopy, item: ShortcutCopy(url: file),
                                  contentTypes: [ShortcutCopy.contentType],
                                  defaultFilename: file.lastPathComponent) { result in
                        if case .failure(let error) = result { model.actionError = error.localizedDescription }
                    }
                DisclosureGroup("Set up manually") { manualSetup }
                    .accessibilityIdentifier("manualOpeningSetup")
            } else {
                manualSetup
            }
        } header: { Text("Opening automation") } footer: {
            if file != nil {
                Text("Choose Shortcuts to add Count iPhone Duo Openings. If Files opens, save the file and tap it there. In Shortcuts, enable its opening trigger and allow it to run immediately. Keep one opening automation enabled per phone.")
            }
        }
    }

    @ViewBuilder private var manualSetup: some View {
        ShortcutsLink()
            .accessibilityLabel("Hinge Counter shortcuts")
            .accessibilityHint("Opens Hinge Counter’s page in Shortcuts.")
            .accessibilityIdentifier("openHingeCounterShortcuts")
        Text("Touch and hold Record Opening, then choose New Shortcut. In the editor, tap Search if the action library is hidden. Choose Automation, then “When my iPhone is opened or closed.” Select Opened only and allow immediate runs.")
            .font(.footnote).foregroundStyle(.secondary)
    }
}

private struct ShortcutCopy: Transferable {
    static let contentType = UTType(filenameExtension: "shortcut") ?? .data
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: contentType) { SentTransferredFile($0.url) }
    }
}

/// Use the button's own window for the Open In menu, including in a second Duo scene.
private struct OpenShortcutDocument: UIViewRepresentable {
    let file: URL
    let saveCopy: () -> Void

    func makeCoordinator() -> UIDocumentInteractionController { UIDocumentInteractionController(url: file) }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(String(localized: "Add opening automation"), for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "installOpeningAutomation"
        let document = context.coordinator
        button.addAction(UIAction { [weak button] _ in
            guard let button else { return }
            if !document.presentOpenInMenu(from: button.bounds, in: button, animated: true) {
                saveCopy()
            }
        }, for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
#endif
