import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var document: DocumentModel
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            if let message = document.errorMessage {
                MessageView(systemImage: "exclamationmark.triangle", title: "Couldn’t open file", detail: message)
            } else if document.isEmpty {
                MessageView(
                    systemImage: "doc.richtext",
                    title: "Open a Markdown file",
                    detail: "Press ⌘O, or drop a .md file anywhere in this window."
                )
            } else {
                DocumentScrollView(blocks: document.blocks)
            }
        }
        .navigationTitle(document.title)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadDrop(providers)
        }
        .task {
            if document.isEmpty { document.loadWelcome() }
        }
    }

    private func loadDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in document.open(url) }
        }
        return true
    }
}

/// The scrolling document body.
struct DocumentScrollView: View {
    let blocks: [RenderBlock]
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(blocks) { block in
                    BlockView(block: block)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: Typography.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.canvas)
    }
}

struct MessageView: View {
    let systemImage: String
    let title: String
    let detail: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.fgSubtle)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.fg)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.fgMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
