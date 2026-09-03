import Cocoa
import QuickLookUI
import SwiftUI

/// Renders a Markdown file inside Finder's Quick Look panel.
///
/// The extension shares the app's parser, theme system and block views, but
/// none of its chrome: no outline, no search, no navigation. Quick Look is for
/// a glance, and it is torn down as soon as the panel closes.
@MainActor
final class PreviewViewController: NSViewController, QLPreviewingController {

    private let document = DocumentModel()
    private let search = SearchModel()

    override func loadView() {
        view = NSView()
        view.setFrameSize(NSSize(width: 800, height: 600))
    }

    func preparePreviewOfFile(at url: URL) async throws {
        // Quick Look hands over a URL already covered by a sandbox extension,
        // so the file can be read without a folder grant. Sibling images still
        // need one, and fall back to their placeholders.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let text = try String(contentsOf: url, encoding: .utf8)
        document.open(url)
        if document.blocks.isEmpty { document.render(text) }

        let theme = Self.preferredTheme()
        let host = NSHostingView(
            rootView: QuickLookPreview(theme: theme)
                .environmentObject(document)
                .environmentObject(search)
        )
        host.translatesAutoresizingMaskIntoConstraints = false

        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.appearance = theme.appearance.nsAppearance
    }

    /// The extension runs in its own container and cannot read the app's
    /// selected theme, so it follows the system appearance instead.
    private static func preferredTheme() -> Theme {
        let isDark = NSApp?.effectiveAppearance.isDark
            ?? (NSAppearance.currentDrawing().isDark)
        return isDark ? .githubDark : .githubLight
    }
}

/// The preview body: the document, and nothing else.
struct QuickLookPreview: View {
    let theme: Theme

    @EnvironmentObject private var document: DocumentModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(document.blocks) { block in
                    BlockView(block: block)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: Typography.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.canvas)
        .environment(\.theme, theme)
    }
}
