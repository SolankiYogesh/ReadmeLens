import Foundation
import Markdown

/// Owns one open document: its source, parsed blocks, navigation history and
/// the folder grant that lets local images and links resolve.
@MainActor
final class DocumentModel: ObservableObject {

    @Published private(set) var blocks: [RenderBlock] = []
    @Published private(set) var url: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    /// Set when the document references local files we have no grant for.
    @Published private(set) var needsFolderAccess = false

    /// Set when the document itself could not be read, which under the sandbox
    /// usually means the folder was never granted.
    @Published private(set) var needsAccessToOpen = false

    /// Anchor the view should scroll to, consumed once handled.
    @Published var pendingAnchor: String?

    /// Bumped each time the file is re-read from disk, so the view can restore
    /// the reading position and acknowledge the change.
    @Published private(set) var reloadToken = 0

    /// Set briefly after a reload, to acknowledge it in the UI.
    @Published private(set) var didJustReload = false

    /// Topmost block currently on screen. Drives outline highlighting and
    /// restoring the reading position after a reload.
    @Published var topVisibleBlockID: String?

    /// Headings of the open document, recomputed whenever it is parsed.
    @Published private(set) var outline: [OutlineEntry] = []

    @Published var isOutlineVisible: Bool {
        didSet { UserDefaults.standard.set(isOutlineVisible, forKey: Self.outlineKey) }
    }

    @Published var isAutoReloadEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoReloadEnabled, forKey: Self.autoReloadKey)
            isAutoReloadEnabled ? startWatching() : stopWatching()
        }
    }

    private static let autoReloadKey = "autoReloadEnabled"
    private static let outlineKey = "outlineVisible"
    private var watcher: FileWatcher?
    private var acknowledgeTask: Task<Void, Never>?

    /// Everything reachable with the back and forward arrows, in order.
    ///
    /// One trail covers both cases: opening several files at once seeds it
    /// with all of them, and following a link appends to it. That way the
    /// arrows always mean the same thing rather than being link-only history
    /// that stays disabled until you happen to click a link.
    @Published private(set) var trail: [URL] = []
    @Published private(set) var position: Int = 0
    /// Folder whose security scope this document currently holds.
    private var heldFolder: URL?

    private let access = FolderAccessStore.shared

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.autoReloadKey) == nil {
            defaults.set(true, forKey: Self.autoReloadKey)
        }
        if defaults.object(forKey: Self.outlineKey) == nil {
            defaults.set(true, forKey: Self.outlineKey)
        }
        isAutoReloadEnabled = defaults.bool(forKey: Self.autoReloadKey)
        isOutlineVisible = defaults.bool(forKey: Self.outlineKey)
    }

    /// The heading the reader is currently under — the last one at or above the
    /// topmost visible block, so the outline tracks position rather than only
    /// highlighting exact heading hits.
    var activeOutlineID: String? {
        guard !outline.isEmpty else { return nil }
        guard let top = topVisibleBlockID,
              let index = blocks.firstIndex(where: { $0.scrollID == top })
        else { return outline.first?.id }

        for candidate in stride(from: index, through: 0, by: -1) {
            if case .heading = blocks[candidate].kind {
                return blocks[candidate].scrollID
            }
        }
        return outline.first?.id
    }

    var title: String { url?.lastPathComponent ?? "ReadmeLens" }
    var isEmpty: Bool { blocks.isEmpty && errorMessage == nil }
    var canGoBack: Bool { position > 0 }
    var canGoForward: Bool { position + 1 < trail.count }

    /// "2 of 5" when several documents are open, otherwise nil.
    var trailPosition: String? {
        trail.count > 1 ? "\(position + 1) of \(trail.count)" : nil
    }

    /// Folder the open document lives in — the base for relative references.
    private(set) var baseDirectory: URL?

    deinit {
        watcher?.stop()
        acknowledgeTask?.cancel()
        if let heldFolder {
            let store = access
            Task { @MainActor in store.endAccess(to: heldFolder) }
        }
    }

    // MARK: - Opening

    func open(_ url: URL, recordHistory: Bool = true) {
        guard recordHistory else {
            load(url)
            return
        }
        // Re-opening what is already showing should not grow the trail.
        if trail.indices.contains(position), trail[position] == url {
            load(url)
            return
        }
        if trail.isEmpty {
            trail = [url]
            position = 0
        } else {
            // Anything ahead of here is replaced, as in a browser.
            trail.removeSubrange((position + 1)...)
            trail.append(url)
            position = trail.count - 1
        }
        load(url)
    }

    /// Adds documents to the end of the current trail, keeping the reader
    /// where they are.
    ///
    /// Used when a multi-file selection reaches the app as several separate
    /// open events: the later ones must extend the set rather than replace it.
    func append(_ urls: [URL]) {
        let files = urls.filter {
            Self.markdownExtensions.contains($0.pathExtension.lowercased())
        }
        let additions = files.filter { !trail.contains($0) }
        guard !additions.isEmpty else { return }

        guard !trail.isEmpty else {
            open(files)
            return
        }
        trail.append(contentsOf: additions)
    }

    /// Opens several documents as one trail — selecting a folder of notes in
    /// Finder and hitting Return lands here.
    func open(_ urls: [URL]) {
        let files = urls.filter {
            Self.markdownExtensions.contains($0.pathExtension.lowercased())
        }
        guard let first = files.first else {
            if let single = urls.first { open(single) }
            return
        }
        trail = files
        position = 0
        load(first)
    }

    func goBack() {
        guard canGoBack else { return }
        position -= 1
        load(trail[position])
    }

    func goForward() {
        guard canGoForward else { return }
        position += 1
        load(trail[position])
    }

    private func load(_ url: URL) {
        isLoading = true
        errorMessage = nil

        let folder = url.deletingLastPathComponent()
        releaseFolder()
        // A stored grant covering this folder is claimed for as long as the
        // document stays open, so images can be read lazily while scrolling.
        if access.beginAccess(to: folder) != nil { heldFolder = folder }

        // The URL from an open panel carries its own short-lived scope.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            self.url = url
            self.baseDirectory = folder
            render(text)
            needsFolderAccess = hasLocalReferences && !canRead(folder)
            needsAccessToOpen = false
            startWatching()
        } catch {
            self.url = url
            self.baseDirectory = folder
            blocks = []
            needsFolderAccess = false
            // A permission failure is recoverable — the user can grant the
            // folder — so it is reported differently from a missing file.
            let denied = (error as NSError).code == NSFileReadNoPermissionError
                || !FileManager.default.isReadableFile(atPath: url.path)
            needsAccessToOpen = denied && FileManager.default.fileExists(atPath: url.path)
            errorMessage = needsAccessToOpen
                ? "ReadmeLens does not have permission to read “\(url.lastPathComponent)”."
                : "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Whether the folder is genuinely readable right now.
    ///
    /// A stored grant is not the only way in — the app's own container is
    /// always readable — so this asks the filesystem rather than assuming.
    private func canRead(_ folder: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) != nil
    }

    // MARK: - Auto-reload

    private func startWatching() {
        stopWatching()
        guard isAutoReloadEnabled, let url, url.isFileURL else { return }

        let watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }
        self.watcher = watcher
        watcher.start()
    }

    private func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    /// Re-reads the open file after it changed on disk.
    ///
    /// A failed read leaves the current content in place rather than replacing
    /// the document with an error — an editor mid-save can briefly make the
    /// file unreadable, and blanking the window for that would be worse than
    /// showing slightly stale text.
    func reloadFromDisk() {
        guard let url else { return }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }

        render(text)
        if let baseDirectory {
            needsFolderAccess = hasLocalReferences && !canRead(baseDirectory)
        }
        reloadToken += 1
        acknowledge()
    }

    private func acknowledge() {
        didJustReload = true
        acknowledgeTask?.cancel()
        acknowledgeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            self?.didJustReload = false
        }
    }

    private func releaseFolder() {
        if let heldFolder { access.endAccess(to: heldFolder) }
        heldFolder = nil
    }

    /// Called once the user grants access to the document's folder.
    func folderAccessGranted() {
        guard let baseDirectory, let url else { return }
        releaseFolder()
        if access.beginAccess(to: baseDirectory) != nil { heldFolder = baseDirectory }
        ImageCache.shared.clearFailures()

        if needsAccessToOpen {
            // The document itself was unreadable; retry it outright.
            load(url)
            return
        }
        needsFolderAccess = false
        if let text = try? String(contentsOf: url, encoding: .utf8) { render(text) }
    }

    /// Shows the bundled welcome document.
    ///
    /// Nothing is watched here: the file lives inside the app bundle.
    func loadWelcome() {
        stopWatching()
        guard let url = Bundle.main.url(forResource: "Welcome", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        render(text)
    }

    func render(_ markdown: String) {
        let document = Document(parsing: normalize(markdown))
        blocks = BlockFlattener.blocks(from: document)
        outline = blocks.outline
        errorMessage = nil
    }

    private func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - Reference resolution

    /// Internal scheme used to carry in-document anchors through SwiftUI's
    /// link handling, which only accepts a `URL`.
    static let anchorScheme = "readmelens-anchor"

    static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mdtext", "text", "txt",
    ]

    func resolveImageURL(_ source: String) -> URL? {
        resolveResource(source)
    }

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

    /// Resolves a relative path against the document folder, refusing anything
    /// that would escape it.
    private func resolveResource(_ source: String) -> URL? {
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

    // MARK: - Local reference detection

    private var hasLocalReferences: Bool {
        func scan(_ list: [RenderBlock]) -> Bool {
            for block in list {
                switch block.kind {
                case let .image(model):
                    if isRelative(model.source) { return true }
                case let .paragraph(text), let .heading(_, text, _):
                    if text.spans.contains(where: { isRelative($0.link) }) { return true }
                case let .quote(inner, _), let .alert(_, inner),
                     let .container(_, inner), let .disclosure(_, inner):
                    if scan(inner) { return true }
                case let .list(model):
                    if model.items.contains(where: { scan($0.blocks) }) { return true }
                case let .html(nodes):
                    if nodes.containsRelativeReference { return true }
                default:
                    break
                }
            }
            return false
        }
        return scan(blocks)
    }

    private func isRelative(_ value: String?) -> Bool {
        guard let value, !value.isEmpty, !value.hasPrefix("#") else { return false }
        if let url = URL(string: value), url.scheme != nil { return false }
        return true
    }
}

private extension Array where Element == HTMLNode {
    var containsRelativeReference: Bool {
        contains { node in
            guard case let .element(element) = node else { return false }
            for key in ["src", "href"] {
                if let value = element.attribute(key),
                   !value.isEmpty, !value.hasPrefix("#"),
                   URL(string: value)?.scheme == nil {
                    return true
                }
            }
            return element.children.containsRelativeReference
        }
    }
}
