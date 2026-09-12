import SwiftUI
import WebKit

/// Renders a fenced ` ```mermaid ` block as a diagram instead of raw source.
///
/// Mermaid has no native Swift renderer, so the vendored, offline copy at
/// `Resources/Mermaid/mermaid.min.js` runs inside a small `WKWebView`. The
/// diagram's own themeVariables are derived from the active `Theme` so it
/// blends with whichever theme is selected, light or dark.
struct MermaidView: View {
    let source: String

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography
    @Environment(\.isPrinting) private var isPrinting

    @State private var size: CGSize?
    @State private var errorMessage: String?

    private static let minHeight: CGFloat = 60

    var body: some View {
        Group {
            if isPrinting {
                printedContent
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                live
            }
        }
    }

    /// A render pass runs no async work and cannot draw a `WKWebView`, so
    /// printing reuses whatever was snapshotted while last shown on screen —
    /// the same trick `DocumentImage` plays for its own async loads.
    @ViewBuilder
    private var printedContent: some View {
        if let cached = MermaidCache.shared.cached(source: source, themeID: theme.id), cached.size.width > 0 {
            let scale = min(1, typography.contentMaxWidth / cached.size.width)
            Image(nsImage: cached)
                .resizable()
                .frame(width: cached.size.width * scale, height: cached.size.height * scale)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            CodeBlockView(language: "mermaid", source: source)
        }
    }

    private var live: some View {
        let natural = size ?? CGSize(width: typography.contentMaxWidth, height: Self.minHeight)
        let scale = min(1, typography.contentMaxWidth / max(natural.width, 1))

        return MermaidWebView(source: source, theme: theme, onSize: { size = $0 }, onError: { errorMessage = $0 })
            .frame(width: natural.width, height: natural.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: natural.width * scale, height: natural.height * scale, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if size == nil { ProgressView().controlSize(.small).padding(8) }
            }
            .background(theme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Couldn't render this diagram", systemImage: "exclamationmark.triangle")
                .font(.system(size: typography.body * 0.85, weight: .medium))
                .foregroundStyle(theme.alertColor(.warning))
                .help(message)
            CodeBlockView(language: "mermaid", source: source)
        }
    }
}

/// Process-wide cache of rendered diagram snapshots, keyed by source and
/// theme so a colour change re-renders instead of reusing a stale bitmap.
@MainActor
final class MermaidCache {
    static let shared = MermaidCache()

    private struct Key: Hashable { let source: String; let themeID: String }
    private var images: [Key: NSImage] = [:]

    func cached(source: String, themeID: String) -> NSImage? {
        images[Key(source: source, themeID: themeID)]
    }

    func store(_ image: NSImage, source: String, themeID: String) {
        images[Key(source: source, themeID: themeID)] = image
    }
}

/// Hosts the offline Mermaid HTML page and reports back the diagram's
/// natural size (or a render error) via a script message handler.
private struct MermaidWebView: NSViewRepresentable {
    let source: String
    let theme: Theme
    let onSize: (CGSize) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "mermaid")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSize = onSize
        coordinator.onError = onError
        coordinator.source = source
        coordinator.themeID = theme.id

        guard coordinator.loadedSource != source || coordinator.loadedThemeID != theme.id else { return }
        coordinator.loadedSource = source
        coordinator.loadedThemeID = theme.id

        guard let base = Bundle.main.url(forResource: "Mermaid", withExtension: nil) else {
            onError("Mermaid is missing from the app bundle.")
            return
        }
        webView.loadHTMLString(MermaidHTMLBuilder.document(source: source, theme: theme), baseURL: base)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onSize: (CGSize) -> Void = { _ in }
        var onError: (String) -> Void = { _ in }
        var source = ""
        var themeID = ""
        var loadedSource: String?
        var loadedThemeID: String?

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }

            switch type {
            case "size":
                guard let width = body["width"] as? Double, let height = body["height"] as? Double,
                      width > 0, height > 0
                else { return }
                let size = CGSize(width: width, height: height)
                onSize(size)
                snapshot(fitting: size)

            case "error":
                onError(body["message"] as? String ?? "Failed to render diagram.")

            default:
                break
            }
        }

        /// Rasterises the freshly-rendered diagram so printing (which cannot
        /// draw a live web view) has something to show.
        private func snapshot(fitting size: CGSize) {
            guard let webView else { return }
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(origin: .zero, size: size)
            let capturedSource = source
            let capturedThemeID = themeID
            webView.takeSnapshot(with: config) { image, _ in
                guard let image else { return }
                MermaidCache.shared.store(image, source: capturedSource, themeID: capturedThemeID)
            }
        }
    }
}

/// Builds the standalone HTML page that loads the vendored Mermaid bundle
/// and renders one diagram, reporting size or failure back to Swift.
enum MermaidHTMLBuilder {
    static func document(source: String, theme: Theme) -> String {
        let variables: [String: String] = [
            "background": theme.canvas.hexString,
            "primaryColor": theme.canvasInset.hexString,
            "primaryTextColor": theme.fg.hexString,
            "primaryBorderColor": theme.border.hexString,
            "secondaryColor": theme.canvasSubtle.hexString,
            "secondaryBorderColor": theme.border.hexString,
            "tertiaryColor": theme.canvasSubtle.hexString,
            "tertiaryBorderColor": theme.border.hexString,
            "lineColor": theme.fgMuted.hexString,
            "textColor": theme.fg.hexString,
            "nodeTextColor": theme.fg.hexString,
            "mainBkg": theme.canvasInset.hexString,
            "nodeBorder": theme.border.hexString,
            "clusterBkg": theme.canvasSubtle.hexString,
            "clusterBorder": theme.border.hexString,
            "edgeLabelBackground": theme.canvas.hexString,
            "titleColor": theme.fg.hexString,
            "errorBkgColor": theme.canvasInset.hexString,
            "errorTextColor": theme.alertColor(.caution).hexString,
        ]

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; background: \(theme.canvas.hexString); }
          #container svg { display: block; }
        </style>
        <script src="mermaid.min.js"></script>
        </head>
        <body>
        <div id="container"></div>
        <script>
          (async () => {
            try {
              mermaid.initialize({
                startOnLoad: false,
                securityLevel: "strict",
                theme: "base",
                themeVariables: \(jsObject(variables))
              });
              const { svg } = await mermaid.render("generated-diagram", \(jsString(source)));
              const container = document.getElementById("container");
              container.innerHTML = svg;
              const rect = container.getBoundingClientRect();
              window.webkit.messageHandlers.mermaid.postMessage({
                type: "size", width: rect.width, height: rect.height
              });
            } catch (error) {
              window.webkit.messageHandlers.mermaid.postMessage({
                type: "error", message: String((error && error.message) || error)
              });
            }
          })();
        </script>
        </body>
        </html>
        """
    }

    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return json
    }

    private static func jsObject(_ value: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value), let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }
}
