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

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { !$0.hasDirectoryPath }) ?? urls.first else { return }
        Task { @MainActor in
            if let document = Self.document {
                document.open(url)
            } else {
                Self.queued.append(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Called once the model is ready, to drain anything Finder sent early.
    @MainActor
    static func attach(_ model: DocumentModel) {
        document = model
        if let pending = queued.first {
            queued.removeAll()
            model.open(pending)
            return
        }
        if let argument = launchArgumentURL() {
            model.open(argument)
        }
    }

    /// Supports `ReadmeLens.app/Contents/MacOS/ReadmeLens path/to/README.md`,
    /// which is how the app is driven from a terminal.
    @MainActor
    private static func launchArgumentURL() -> URL? {
        for argument in CommandLine.arguments.dropFirst() {
            guard !argument.hasPrefix("-") else { continue }
            let url = URL(fileURLWithPath: argument).standardizedFileURL
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
