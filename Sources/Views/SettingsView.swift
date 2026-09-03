import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            TypographySettings()
                .tabItem { Label("Typography", systemImage: "textformat.size") }
            CustomThemeSettings()
                .tabItem { Label("Themes", systemImage: "folder") }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $themeStore.selectedID) {
                    Text("Follow System").tag(ThemeStore.autoID)
                    Divider()
                    ForEach(themeStore.builtinThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                    if !themeStore.customThemes.isEmpty {
                        Divider()
                        ForEach(themeStore.customThemes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                }
            }

            if themeStore.selectedID == ThemeStore.autoID {
                Section {
                    Picker("When light", selection: $themeStore.autoLightID) {
                        ForEach(themeStore.available.filter { $0.appearance == .light }) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    Picker("When dark", selection: $themeStore.autoDarkID) {
                        ForEach(themeStore.available.filter { $0.appearance == .dark }) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                } header: {
                    Text("Follow System pairing")
                } footer: {
                    Text("macOS is currently \(themeStore.systemIsDark ? "dark" : "light").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Reading mode", isOn: $settings.isReadingMode)
            } footer: {
                Text("Narrows the text column to a comfortable line length.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Typography

private struct TypographySettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        Form {
            Section {
                slider("Body text", value: $settings.bodySize,
                       range: AppSettings.bodyRange, unit: "pt")
                slider("Code", value: $settings.codeSize,
                       range: AppSettings.codeRange, unit: "pt")
                slider("Column width", value: $settings.contentWidth,
                       range: AppSettings.widthRange, unit: "pt")
                    .disabled(settings.isReadingMode)
                slider("Zoom", value: $settings.zoom,
                       range: AppSettings.zoomRange, unit: "×", decimals: 2)
            } footer: {
                if settings.isReadingMode {
                    Text("Column width is fixed while reading mode is on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preview") {
                TypographyPreview()
                    .environment(\.theme, themeStore.current)
                    .environment(\.typography, settings.typography)
            }

            Section {
                Button("Restore Defaults") { settings.restoreDefaults() }
            }
        }
        .formStyle(.grouped)
    }

    private func slider(
        _ label: String, value: Binding<Double>,
        range: ClosedRange<Double>, unit: String, decimals: Int = 0
    ) -> some View {
        HStack {
            Text(label).frame(width: 96, alignment: .leading)
            Slider(value: value, in: range)
            Text(decimals == 0
                 ? "\(Int(value.wrappedValue.rounded()))\(unit)"
                 : String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

/// A live sample so size changes can be judged without leaving Settings.
private struct TypographyPreview: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heading")
                .font(.system(size: typography.headingSize(2), weight: .semibold))
                .foregroundStyle(theme.fg)
            Text("Body text at \(Int(typography.body))pt, the size paragraphs render at.")
                .font(.system(size: typography.body))
                .foregroundStyle(theme.fg)
            Text("let code = \"sample\"")
                .font(.system(size: typography.code, design: .monospaced))
                .foregroundStyle(theme.syntaxColor(.string))
                .padding(6)
                .background(theme.codeBg, in: RoundedRectangle(cornerRadius: 4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Custom themes

private struct CustomThemeSettings: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        // Observed directly: watching only the parent store would miss
        // reloads triggered by the folder watcher.
        CustomThemeList(store: themeStore.custom, themeStore: themeStore)
    }
}

private struct CustomThemeList: View {
    @ObservedObject var store: CustomThemeStore
    @ObservedObject var themeStore: ThemeStore
    @State private var exportMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Themes folder")
                    Spacer()
                    Button("Reveal in Finder") { store.revealInFinder() }
                }
                Text(store.directory.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } footer: {
                Text("Drop a .json theme in here and it loads immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Loaded") {
                if store.themes.isEmpty {
                    Text("No custom themes yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.themes) { theme in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.canvas)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().fill(theme.link).frame(width: 7, height: 7))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .stroke(.secondary.opacity(0.4), lineWidth: 1))
                            Text(theme.name)
                            Spacer()
                            Text(theme.id)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Silent failures would be baffling; a bad hex value is named.
            if !store.failures.isEmpty {
                Section("Problems") {
                    ForEach(store.failures) { failure in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(failure.file)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text(failure.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Export Current Theme as JSON") { export() }
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                }
                Button("Reload Themes") { store.reload() }
            } footer: {
                Text("Exporting gives you a complete file to edit as a starting point.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func export() {
        do {
            let url = try store.export(themeStore.current)
            exportMessage = "Wrote \(url.lastPathComponent)"
        } catch {
            exportMessage = "Could not export: \(error.localizedDescription)"
        }
    }
}
