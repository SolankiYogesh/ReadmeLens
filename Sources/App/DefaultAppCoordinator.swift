import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Offers to make ReadmeLens the default app for Markdown files.
///
/// macOS lets an app request this through LaunchServices, but the request is
/// only honoured for an app the system considers installed — one registered
/// from `/Applications`. Running from a build folder it will usually silently
/// fail to stick, which is why the result is verified rather than assumed.
@MainActor
final class DefaultAppCoordinator: ObservableObject {

    /// Extensions worth claiming. Plain `.txt` is deliberately absent: taking
    /// over every text file is not what someone asking for a Markdown viewer
    /// has in mind.
    private static let extensions = ["md", "markdown", "mdown", "mkd", "mdtext"]

    private static let dismissedKey = "defaultAppPromptDismissed"

    @Published private(set) var isDefault = false
    /// True when the banner should be offered.
    @Published private(set) var shouldOffer = false
    @Published private(set) var lastError: String?
    /// Set when the association points at a build folder rather than an
    /// installed app, which will break the moment that folder is cleaned.
    @Published private(set) var isRunningFromTemporaryLocation = false

    private var dismissedThisLaunch = false

    init() {
        refresh()
    }

    /// The Markdown content types this app can claim.
    private var contentTypes: [UTType] {
        var seen = Set<String>()
        return Self.extensions.compactMap { ext in
            guard let type = UTType(filenameExtension: ext),
                  type.isDeclared,
                  seen.insert(type.identifier).inserted
            else { return nil }
            return type
        }
    }

    private var isInstalled: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    func refresh() {
        isDefault = computeIsDefault()
        isRunningFromTemporaryLocation = isDefault && !isInstalled
        let permanentlyDismissed = UserDefaults.standard.bool(forKey: Self.dismissedKey)
        shouldOffer = !isDefault && !permanentlyDismissed && !dismissedThisLaunch
    }

    private func computeIsDefault() -> Bool {
        guard let primary = contentTypes.first,
              let handler = NSWorkspace.shared.urlForApplication(toOpen: primary)
        else { return false }
        return handler.standardizedFileURL.resolvingSymlinksInPath()
            == Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// Asks LaunchServices to hand over every Markdown type.
    ///
    /// macOS may show its own confirmation. The outcome is re-checked
    /// afterwards rather than trusted, since the request can be refused
    /// without reporting an error.
    func makeDefault() async {
        lastError = nil
        let app = Bundle.main.bundleURL
        let types = contentTypes

        guard !types.isEmpty else {
            lastError = "No Markdown file type is registered on this Mac yet."
            return
        }

        for type in types {
            await withCheckedContinuation { continuation in
                NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { error in
                    if let error {
                        Task { @MainActor in self.lastError = error.localizedDescription }
                    }
                    continuation.resume()
                }
            }
        }

        // LaunchServices updates asynchronously; give it a moment before
        // reporting success or failure.
        try? await Task.sleep(nanoseconds: 400_000_000)
        refresh()

        if !isDefault, lastError == nil {
            lastError = isInstalled
                ? "macOS did not apply the change. Try setting it from Finder’s Get Info panel."
                : "Move ReadmeLens to your Applications folder and try again."
        }
    }

    func dismissForNow() {
        dismissedThisLaunch = true
        shouldOffer = false
    }

    func neverAsk() {
        UserDefaults.standard.set(true, forKey: Self.dismissedKey)
        dismissedThisLaunch = true
        shouldOffer = false
    }

    /// Re-enables the offer, for the menu command.
    func resetPrompt() {
        UserDefaults.standard.set(false, forKey: Self.dismissedKey)
        dismissedThisLaunch = false
        refresh()
    }
}
