import SwiftUI
import UniformTypeIdentifiers

@main
struct ReadmeLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var document = DocumentModel()
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var search = SearchModel()
    @StateObject private var settings = AppSettings()
    @StateObject private var defaultApp = DefaultAppCoordinator()

    var body: some Scene {
        // A single Window, not a WindowGroup. A group creates one window per
        // open request, so opening six files produced six windows — all of
        // them showing the same document, because they share one model, and
        // all changing together when an arrow was clicked.
        Window("ReadmeLens", id: "main") {
            ContentView()
                .environmentObject(document)
                .environmentObject(themeStore)
                .environmentObject(search)
                .environmentObject(settings)
                .environmentObject(defaultApp)
                .environment(\.theme, themeStore.current)
                .environment(\.typography, settings.typography)
                .frame(minWidth: 640, minHeight: 480)
                .background(themeStore.current.canvas)
                .preferredColorScheme(themeStore.current.appearance == .dark ? .dark : .light)
                .onAppear {
                    AppDelegate.attach(document)
                    // File ▸ Print reaches the app delegate, not SwiftUI.
                    AppDelegate.printHandler = { printDocument() }
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Zoom In") { settings.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom In ") { settings.zoomIn() }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { settings.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { settings.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Toggle("Reading Mode", isOn: $settings.isReadingMode)
                    .keyboardShortcut("r", modifiers: [.command, .option])
                Divider()
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") { openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button(defaultApp.isDefault
                       ? "ReadmeLens Opens Markdown Files"
                       : "Open Markdown Files with ReadmeLens…") {
                    Task { await defaultApp.makeDefault() }
                }
                .disabled(defaultApp.isDefault)
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") { search.open() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { search.next() }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(search.matches.isEmpty)
                Button("Find Previous") { search.previous() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(search.matches.isEmpty)
            }
            CommandGroup(after: .toolbar) {
                Button(document.isOutlineVisible ? "Hide Outline" : "Show Outline") {
                    document.isOutlineVisible.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                Toggle("Reload on Save", isOn: $document.isAutoReloadEnabled)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Back") { document.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!document.canGoBack)
                Button("Forward") { document.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!document.canGoForward)
                Divider()
            }
            CommandMenu("Theme") {
                ForEach(themeStore.available) { theme in
                    Button {
                        themeStore.selectedID = theme.id
                    } label: {
                        HStack {
                            Text(theme.name)
                            if themeStore.selectedID == theme.id { Image(systemName: "checkmark") }
                        }
                    }
                }
                Divider()
                Button("Follow System") { themeStore.selectedID = ThemeStore.autoID }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(themeStore)
                .environmentObject(settings)
                .environmentObject(defaultApp)
        }
    }

    private func printDocument() {
        DocumentPrinter.print(
            blocks: document.blocks,
            theme: themeStore.current,
            typography: settings.typography,
            title: document.title,
            document: document,
            search: search
        )
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            document.open(panel.urls)
        }
    }
}