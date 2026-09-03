import SwiftUI
import UniformTypeIdentifiers

@main
struct ReadmeLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var document = DocumentModel()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .environmentObject(themeStore)
                .environment(\.theme, themeStore.current)
                .frame(minWidth: 640, minHeight: 480)
                .background(themeStore.current.canvas)
                .preferredColorScheme(themeStore.current.appearance == .dark ? .dark : .light)
                .onAppear { AppDelegate.attach(document) }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
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
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]
        if panel.runModal() == .OK, let url = panel.url {
            document.open(url)
        }
    }
}
