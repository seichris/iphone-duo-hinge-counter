import SwiftUI
import UniformTypeIdentifiers

struct CounterDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CounterDataError.invalid("The selected file has no readable content.")
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(CounterModel.self) private var model
    @State private var confirmErase = false
    @State private var importing = false
    @State private var replacement: CounterArchive?
    @State private var confirmRestore = false
    @State private var exporting = false
    @State private var document: CounterDocument?
    @State private var exportType = UTType.json
    @State private var exportName = "FoldCounter-backup"
    @State private var demo = false

    var body: some View {
        Form {
            Section("Help & Privacy") {
                NavigationLink("Privacy Policy") { HelpView(page: .privacy) }
                    .accessibilityIdentifier("privacyPolicy")
                NavigationLink("Help & Support") { HelpView(page: .support) }
                    .accessibilityIdentifier("helpSupport")
                LabeledContent("Version", value: appVersion)
            }
            Section {
                Toggle("Automatic foreground tracking", isOn: Binding(
                    get: { model.archive?.automaticTrackingEnabled ?? false },
                    set: { model.setAutomaticTracking($0) }
                )).disabled(!model.canEdit)
                LabeledContent("Status", value: model.trackingTitle)
            } header: { Text("Tracking") } footer: {
                Text(model.trackingDetail + " Counting requires observing ≤10°, then ≥170°, at least 0.35 seconds apart. "
                     + "These are this app’s counting thresholds, not a hinge-health measurement.")
            }
            if let error = model.storageError {
                Section("Storage") {
                    Text(error)
                    Button("Retry save or load") { model.retrySaveOrLoad() }
                    ShareLink("Export original file for recovery", item: model.rawArchiveURL)
                }
            }
            Section {
                Text(model.widgetStatus)
                Text("Home and Lock Screen widgets show saved totals only. They do not monitor the hinge or keep the app alive.")
            } header: { Text("Widgets") }
            Section {
                Button("Export daily history (CSV)") { prepareExport(csv: true) }.disabled(!model.canEdit)
                Button("Export backup (JSON)") { prepareExport(csv: false) }.disabled(!model.canEdit)
                Button("Restore a JSON backup") { importing = true }.disabled(model.pendingSave)
                Button("Erase all counts", role: .destructive) { confirmErase = true }
            } header: { Text("Your data") } footer: {
                Text("Everything is stored on this device. No account, ads or analytics. Counting works offline. "
                     + "Your OS/device backup settings can include app data. Exports leave the app only when you share them. "
                     + "Restoring replaces the current history; it does not merge two counters.")
            }
            Section {
                Button("Try the unsaved demo") { demo = true }
                Text("Days use your local date at recording time and are not rewritten when you travel. "
                     + "The daily average includes every calendar day since tracking began, including zero days and today. "
                     + "All-time means recorded by this app, not lifetime hardware usage.")
                #if DEBUG
                Text("iPhone Duo integration: announced API, pending SDK and hardware validation. "
                     + "The standard build supports manual counting and demo mode. The Duo scheme enables the new API.")
                #endif
                Text("Independent app. Not affiliated with or endorsed by Apple. No hinge durability rating is assumed.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("About Fold Counter") }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Erase all saved counts?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase all counts", role: .destructive) { model.erase() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone. Export a backup first to keep your history.") }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType,
                      defaultFilename: exportName) { result in
            if case .failure(let error) = result { model.actionError = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                // Bound allocation before decoding an untrusted backup.
                let data = try handle.read(upToCount: ArchiveFile.maximumBytes + 1) ?? Data()
                replacement = try ArchiveFile.decode(data)
                confirmRestore = true
            } catch { model.actionError = error.localizedDescription }
        }
        .confirmationDialog("Replace the current history?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Replace with backup", role: .destructive) {
                if let replacement { model.restore(replacement) }
                replacement = nil
            }
            Button("Cancel", role: .cancel) { replacement = nil }
        } message: {
            Text("The backup contains \(replacement?.days.reduce(0, { $0 + $1.total }) ?? 0) recorded opens. "
                 + "Existing history will be replaced, not added to it.")
        }
        .sheet(isPresented: $demo) { DemoView() }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private func prepareExport(csv: Bool) {
        guard let archive = model.archive else { return }
        do {
            document = CounterDocument(data: csv ? Data(archive.csv().utf8) : try ArchiveFile.encode(archive))
            exportType = csv ? .commaSeparatedText : .json
            exportName = csv ? "FoldCounter-history" : "FoldCounter-backup"
            exporting = true
        } catch { model.actionError = error.localizedDescription }
    }
}
