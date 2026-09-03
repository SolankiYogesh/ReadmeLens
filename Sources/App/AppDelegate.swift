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

    /// Invoked for File ▸ Print. AppKit sends `print:` down the responder
    /// chain; if nothing implements it, macOS shows its own "does not support
    /// printing" alert, which is what happens if this is left to SwiftUI's
    /// command placements alone.
    @MainActor static var printHandler: (() -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        // Selecting several files in Finder and pressing Return delivers them
        // all at once; they become one trail rather than only the first
        // being opened and the rest discarded.
        let files = urls.filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return }
        Task { @MainActor in
            if let document = Self.document {
                document.open(files)
            } else {
                Self.queued.append(contentsOf: files)
            }
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
