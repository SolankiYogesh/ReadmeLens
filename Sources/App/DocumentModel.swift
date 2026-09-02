import Foundation
import Markdown

/// Owns one open document: its source text, parsed blocks and load state.
@MainActor
final class DocumentModel: ObservableObject {

    @Published private(set) var blocks: [RenderBlock] = []
    @Published private(set) var url: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    var title: String { url?.lastPathComponent ?? "ReadmeLens" }
    var isEmpty: Bool { blocks.isEmpty && errorMessage == nil }

    /// Shows the bundled welcome document so a fresh launch has something to
    /// render rather than an empty window.
    func loadWelcome() {
        guard let url = Bundle.main.url(forResource: "Welcome", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        render(text)
    }

    func open(_ url: URL) {
        isLoading = true
        errorMessage = nil

        // The panel hands back a security-scoped URL under the sandbox; the
        // scope has to be held for the duration of the read.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            self.url = url
            render(text)
        } catch {
            self.url = url
            self.blocks = []
            self.errorMessage = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
        isLoading = false
    }

    func render(_ markdown: String) {
        let document = Document(parsing: normalize(markdown))
        blocks = BlockFlattener.blocks(from: document)
        errorMessage = nil
    }

    /// Normalises legacy line endings so CRLF and classic-Mac CR files parse
    /// the same as LF ones.
    private func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
