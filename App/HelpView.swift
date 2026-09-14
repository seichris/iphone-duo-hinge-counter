import SwiftUI

private struct HelpSection: Decodable, Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

private struct HelpContent: Decodable {
    let updated: String
    let privacy: [HelpSection]
    let support: [HelpSection]
    let privacy_url: URL
    let support_url: URL
    let issue_url: URL

    static func load() throws -> HelpContent {
        guard let url = Bundle.main.url(forResource: "HelpContent", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(HelpContent.self, from: Data(contentsOf: url))
    }
}

/// Bundled content is readable offline; web links open only after an explicit tap.
struct HelpView: View {
    enum Page: Equatable { case privacy, support }
    let page: Page
    private let content = Result { try HelpContent.load() }

    var body: some View {
        Group {
            switch content {
            case .success(let document):
                List {
                    ForEach(page == .privacy ? document.privacy : document.support) { section in
                        Section(section.title) {
                            Text(section.body).textSelection(.enabled)
                        }
                    }
                    Section("On the web") {
                        Link(page == .privacy ? "Online privacy policy" : "Support website",
                             destination: page == .privacy ? document.privacy_url : document.support_url)
                        Link("Contact via public GitHub issue", destination: document.issue_url)
                        Text("Opens your browser. GitHub issues are public; never include private data.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Updated \(document.updated)").font(.footnote).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier(page == .privacy ? "privacyContent" : "supportContent")
            case .failure:
                ContentUnavailableView("Help content could not be loaded", systemImage: "doc.text",
                    description: Text("Reinstall the app or contact the repository maintainer. Your saved counts are not changed."))
            }
        }
        .navigationTitle(page == .privacy ? "Privacy Policy" : "Help & Support")
    }
}
