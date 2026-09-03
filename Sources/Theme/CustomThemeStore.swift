import SwiftUI

/// Loads user themes from disk and reloads them when the folder changes.
///
/// The folder lives inside the app's own container, so no grant is needed to
/// read or write it, and editing a file there updates the app immediately.
@MainActor
final class CustomThemeStore: ObservableObject {

    struct LoadFailure: Identifiable {
        let id = UUID()
        let file: String
        let reason: String
    }

    @Published private(set) var themes: [Theme] = []
    @Published private(set) var failures: [LoadFailure] = []

    private var watcher: FileWatcher?

    /// `…/Application Support/ReadmeLens/Themes`
    let directory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("ReadmeLens", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }()

    init() {
        ensureDirectory()
        reload()
        startWatching()
    }

    deinit { watcher?.stop() }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private func startWatching() {
        // A directory descriptor reports writes when entries are added,
        // removed or replaced, which is all this needs.
        let watcher = FileWatcher(url: directory) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        self.watcher = watcher
        watcher.start()
    }

    func reload() {
        ensureDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []

        var loaded: [Theme] = []
        var problems: [LoadFailure] = []
        let decoder = JSONDecoder()

        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where file.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: file)
                let parsed = try decoder.decode(ThemeFile.self, from: data)
                let theme = try parsed.makeTheme()
                // A custom theme must not shadow a bundled one, or the picker
                // would show two entries resolving to the same id.
                guard Theme.builtin(id: theme.id) == nil else {
                    problems.append(LoadFailure(
                        file: file.lastPathComponent,
                        reason: "id “\(theme.id)” is already used by a built-in theme."
                    ))
                    continue
                }
                guard !loaded.contains(where: { $0.id == theme.id }) else {
                    problems.append(LoadFailure(
                        file: file.lastPathComponent,
                        reason: "duplicate id “\(theme.id)”."
                    ))
                    continue
                }
                loaded.append(theme)
            } catch let error as ThemeFile.LoadError {
                problems.append(LoadFailure(
                    file: file.lastPathComponent,
                    reason: error.localizedDescription ?? "invalid theme."
                ))
            } catch {
                problems.append(LoadFailure(
                    file: file.lastPathComponent, reason: error.localizedDescription
                ))
            }
        }

        themes = loaded
        failures = problems
    }

    /// Writes a theme out as an editable starting point.
    @discardableResult
    func export(_ theme: Theme) throws -> URL {
        ensureDirectory()
        var file = ThemeFile(theme)
        file.id = "\(theme.id)-copy"
        file.name = "\(theme.name) Copy"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)

        let destination = directory.appendingPathComponent("\(file.id).json")
        try data.write(to: destination, options: .atomic)
        reload()
        return destination
    }

    func revealInFinder() {
        ensureDirectory()
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}
