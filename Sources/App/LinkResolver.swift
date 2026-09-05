import SwiftUI

/// Turns Markdown link and image destinations into URLs the app can open.
///
/// This is a value type on purpose. Every piece of inline text in a document
/// needs to resolve links, and if those views reached into `DocumentModel` for
/// it they would each subscribe to its `objectWillChange` — so an unrelated
/// publish (the scroll cursor moving, say) would invalidate every run of text
/// on screen. A large document turns that into thousands of rebuilt
/// `AttributedString`s per scroll frame. Handing views an `Equatable` value
/// through the environment instead means they only rebuild when the thing they
/// actually depend on — the document's folder — changes.
struct LinkResolver: Equatable {
    /// The folder the open document lives in. Relative paths resolve against
    /// it; without it, only absolute URLs resolve.
    var baseDirectory: URL?

    static let anchorScheme = "readmelens-anchor"

    /// Turns a link destination into something clickable. Anchors become a
    /// private scheme the view intercepts; relative paths become file URLs.
    func resolveLinkURL(_ destination: String) -> URL? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("#") {
            let slug = String(trimmed.dropFirst())
            guard !slug.isEmpty,
                  let escaped = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            else { return nil }
            return URL(string: "\(Self.anchorScheme)://\(escaped)")
        }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            switch scheme {
            case "http", "https", "mailto", "file": return url
            default: return nil          // javascript:, data:, …
            }
        }
        return resolveResource(trimmed)
    }

    func resolveImageURL(_ source: String) -> URL? {
        resolveResource(source)
    }

    /// Resolves a relative path against the document folder, refusing anything
    /// that would escape it.
    func resolveResource(_ source: String) -> URL? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" || scheme == "file" { return url }
            return nil
        }
        guard let baseDirectory else { return nil }

        // Strip any fragment before touching the filesystem.
        var path = trimmed
        if let hash = path.firstIndex(of: "#") { path = String(path[path.startIndex..<hash]) }
        guard !path.isEmpty else { return nil }
        let decoded = path.removingPercentEncoding ?? path

        let candidate = URL(fileURLWithPath: decoded, relativeTo: baseDirectory).standardizedFileURL
        let root = baseDirectory.standardizedFileURL.path
        guard candidate.path == root || candidate.path.hasPrefix(root + "/") else { return nil }
        return candidate
    }

    /// Fragment on a relative link, e.g. `docs/api.md#usage`.
    func anchorFragment(of destination: String) -> String? {
        guard let hash = destination.firstIndex(of: "#") else { return nil }
        let slug = String(destination[destination.index(after: hash)...])
        return slug.isEmpty ? nil : slug
    }
}

// MARK: - Environment

private struct LinkResolverKey: EnvironmentKey {
    static let defaultValue = LinkResolver(baseDirectory: nil)
}

extension EnvironmentValues {
    var linkResolver: LinkResolver {
        get { self[LinkResolverKey.self] }
        set { self[LinkResolverKey.self] = newValue }
    }
}
