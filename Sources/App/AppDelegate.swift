import AppKit

/// Receives documents opened from Finder, the Dock, or `open -a ReadmeLens`.
///
/// SwiftUI's `WindowGroup` has no hook for this on macOS, so the classic
/// AppKit callback is bridged to the shared document model.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Set by the app at launch.
    @MainActor static var document: DocumentModel?

    /// Files handed over before the model existed.
    @MainActor private static var queued: [URL] = []

    /// Finder may deliver a multi-file selection as several separate open
    /// events rather than one. Without coalescing, each would replace the
    /// trail and only the last file would survive.
    @MainActor private static var batch: [URL] = []
    @MainActor private static var batchTask: Task<Void, Never>?
    /// Finder can be slow to deliver a large selection, so the window is
    /// generous; the cost of waiting is a fraction of a second.
    private static let batchWindow: UInt64 = 700_000_000
    /// A batch arriving soon after the previous one is treated as part of the
    /// same selection and extends the trail rather than replacing it.
    private static let continuationWindow: TimeInterval = 3
    @MainActor private static var lastOpenedAt: Date?

    /// Invoked for File ▸ Print. AppKit sends `print:` down the responder
    /// chain; if nothing implements it, macOS shows its own "does not support
    /// printing" alert, which is what happens if this is left to SwiftUI's
    /// command placements alone.
    @MainActor static var printHandler: (() -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return }
        Task { @MainActor in Self.enqueue(files) }
    }

    /// Gathers everything that arrives within a short window into one trail.
    @MainActor
    private static func enqueue(_ files: [URL]) {
        batch.append(contentsOf: files)
        batchTask?.cancel()
        batchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: batchWindow)
            guard !Task.isCancelled else { return }

            let collected = batch
            batch = []
            guard !collected.isEmpty else { return }

            guard let document else {
                queued.append(contentsOf: collected)
                return
            }

            let isContinuation = lastOpenedAt.map {
                Date().timeIntervalSince($0) < continuationWindow
            } ?? false

            if isContinuation {
                document.append(collected)
            } else {
                document.open(collected)
            }
            lastOpenedAt = Date()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc(print:)
    func printDocument(_ sender: Any?) {
        Task { @MainActor in Self.printHandler?() }
    }



    /// Called once the model is ready, to drain anything Finder sent early.
    @MainActor
    static func attach(_ model: DocumentModel) {
        document = model
        if !queued.isEmpty {
            let pending = queued
            queued.removeAll()
            model.open(pending)
            return
        }
        let arguments = launchArgumentURLs()
        if !arguments.isEmpty {
            model.open(arguments)
        }
    }

    /// Supports `ReadmeLens.app/Contents/MacOS/ReadmeLens a.md b.md`, which is
    /// how the app is driven from a terminal.
    @MainActor
    private static func launchArgumentURLs() -> [URL] {
        CommandLine.arguments.dropFirst().compactMap { argument in
            guard !argument.hasPrefix("-") else { return nil }
            let url = URL(fileURLWithPath: argument).standardizedFileURL
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }
}

/// Keeps File ▸ Print enabled: AppKit validates the item before showing it,
/// and an unvalidated action renders the menu entry grey.
extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard item.action == #selector(printDocument(_:)) else { return true }
        return MainActor.assumeIsolated { Self.printHandler != nil }
    }
}
