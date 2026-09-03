import SwiftUI

/// Process-wide image cache, keyed by URL.
///
/// Scrolling a README repeatedly re-creates image views; without this, every
/// pass would refetch the same badges.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private var images: [URL: NSImage] = [:]
    private var failures: Set<URL> = []

    func cached(_ url: URL) -> NSImage? { images[url] }
    func hasFailed(_ url: URL) -> Bool { failures.contains(url) }
    func store(_ image: NSImage, for url: URL) { images[url] = image }
    func markFailed(_ url: URL) { failures.insert(url) }

    /// Called after a folder grant so previously unreadable local images retry.
    func clearFailures() { failures.removeAll() }
}

/// One image from a document, local or remote.
///
/// The bitmap is loaded here rather than by `AsyncImage` because the layout
/// needs the image's true pixel size. `AsyncImage` reports its natural size
/// when asked for an ideal size, so a 1024px logo displayed at 200px would
/// still reserve 1024px of height inside a flow layout.
struct DocumentImage: View {
    let source: String
    var alt: String = ""
    var declaredWidth: CGFloat?

    /// Widest an undeclared image may draw, so full-resolution screenshots
    /// don't overflow the reading column.
    private static let naturalCap: CGFloat = 900

    @EnvironmentObject private var document: DocumentModel
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    @State private var image: NSImage?
    @State private var failed = false

    private var url: URL? { document.resolveImageURL(source) }

    var body: some View {
        Group {
            if let image {
                let size = displaySize(for: image)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)
            } else if failed || url == nil {
                placeholder
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 60, height: 20)
            }
        }
        .task(id: source) { await load() }
    }

    private func displaySize(for image: NSImage) -> CGSize {
        let natural = image.size
        guard natural.width > 0, natural.height > 0 else {
            return CGSize(width: declaredWidth ?? 100, height: 20)
        }
        let ratio = natural.height / natural.width
        let width = min(declaredWidth ?? natural.width, Self.naturalCap)
        return CGSize(width: width, height: (width * ratio).rounded())
    }

    private var placeholder: some View {
        HStack(spacing: 6) {
            Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
            Text(alt.isEmpty ? (source as NSString).lastPathComponent : alt)
                .font(.system(size: typography.body * 0.85))
                .lineLimit(1)
        }
        .foregroundStyle(theme.fgSubtle)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.canvasSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.border, lineWidth: 1))
        .help(source)
    }

    private func load() async {
        guard let url else { failed = true; return }
        if let hit = ImageCache.shared.cached(url) { image = hit; return }
        if ImageCache.shared.hasFailed(url) { failed = true; return }

        if url.isFileURL {
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            apply(loaded, for: url)
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                apply(nil, for: url)
                return
            }
            apply(NSImage(data: data), for: url)
        } catch {
            apply(nil, for: url)
        }
    }

    private func apply(_ loaded: NSImage?, for url: URL) {
        if let loaded, loaded.size.width > 0 {
            ImageCache.shared.store(loaded, for: url)
            image = loaded
        } else {
            ImageCache.shared.markFailed(url)
            failed = true
        }
    }
}
