import Foundation

/// Remembers folders the user has granted access to.
///
/// Under the sandbox, opening a file grants access to *that file only* — not to
/// its folder. A README referencing `docs/shot.png` or linking to
/// `./CONTRIBUTING.md` therefore cannot be followed without a separate grant.
///
/// The user picks the folder once; the resulting security-scoped bookmark is
/// persisted, so reopening the same project later just works.
@MainActor
final class FolderAccessStore: ObservableObject {

    static let shared = FolderAccessStore()

    private let defaultsKey = "folderBookmarks"
    /// path → bookmark data
    private var bookmarks: [String: Data]
    /// Scopes currently held open, and how many documents need each.
    private var open: [String: (url: URL, count: Int)] = [:]

    init() {
        bookmarks = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
    }

    /// The stored grant covering `folder` — an exact match, or an ancestor,
    /// since granting a repo root should cover everything beneath it.
    private func grant(covering folder: URL) -> (key: String, data: Data)? {
        let path = folder.standardizedFileURL.path
        if let data = bookmarks[path] { return (path, data) }
        return bookmarks
            .filter { path == $0.key || path.hasPrefix($0.key + "/") }
            .max { $0.key.count < $1.key.count }
            .map { ($0.key, $0.value) }
    }

    func hasAccess(to folder: URL) -> Bool { grant(covering: folder) != nil }

    /// Resolves and starts the scope covering `folder`, if one is stored.
    /// Returns the granted root so the caller can release it later.
    @discardableResult
    func beginAccess(to folder: URL) -> URL? {
        guard let (key, data) = grant(covering: folder) else { return nil }

        if var existing = open[key] {
            existing.count += 1
            open[key] = existing
            return existing.url
        }

        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            bookmarks.removeValue(forKey: key)
            persist()
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            bookmarks.removeValue(forKey: key)
            persist()
            return nil
        }

        if stale, let refreshed = Self.makeBookmark(for: url) {
            bookmarks[key] = refreshed
            persist()
        }
        open[key] = (url, 1)
        return url
    }

    func endAccess(to folder: URL) {
        guard let (key, _) = grant(covering: folder), var entry = open[key] else { return }
        entry.count -= 1
        if entry.count <= 0 {
            entry.url.stopAccessingSecurityScopedResource()
            open.removeValue(forKey: key)
        } else {
            open[key] = entry
        }
    }

    /// Records a folder the user chose in an open panel.
    @discardableResult
    func store(_ folder: URL) -> Bool {
        guard let data = Self.makeBookmark(for: folder) else { return false }
        bookmarks[folder.standardizedFileURL.path] = data
        persist()
        objectWillChange.send()
        return true
    }

    private static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func persist() {
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }
}
