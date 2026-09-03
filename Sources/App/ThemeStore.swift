import Combine
import SwiftUI

/// Holds the selected theme and keeps it across launches.
///
/// `.auto` follows the system appearance, resolving through the user's chosen
/// light/dark pairing so switching at dusk lands somewhere they picked.
@MainActor
final class ThemeStore: ObservableObject {

    static let autoID = "auto"

    @AppStorage("selectedThemeID") var selectedID: String = Theme.githubDark.id {
        didSet { objectWillChange.send() }
    }
    @AppStorage("autoDarkThemeID")  var autoDarkID: String  = Theme.githubDark.id
    @AppStorage("autoLightThemeID") var autoLightID: String = Theme.githubLight.id

    @Published var systemIsDark: Bool = NSApp?.effectiveAppearance.isDark ?? true

    init() {
        customChanges = custom.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// Themes loaded from the user's themes folder, appended to the builtins.
    let custom = CustomThemeStore()

    /// SwiftUI does not propagate a nested ObservableObject's changes through
    /// its parent, so views watching this store would never learn that custom
    /// themes finished loading. Re-publish them here.
    private var customChanges: AnyCancellable?

    var current: Theme {
        if selectedID == Self.autoID {
            let id = systemIsDark ? autoDarkID : autoLightID
            return theme(id: id) ?? .githubDark
        }
        return theme(id: selectedID) ?? .githubDark
    }

    /// Bundled themes first, then anything the user has added.
    var available: [Theme] { Theme.builtins + custom.themes }

    var builtinThemes: [Theme] { Theme.builtins }
    var customThemes: [Theme] { custom.themes }

    private func theme(id: String) -> Theme? {
        Theme.builtin(id: id) ?? custom.themes.first { $0.id == id }
    }

    /// Label for the toolbar tooltip; names the resolved theme when following
    /// the system so the dot's colour is always explained.
    var displayName: String {
        selectedID == Self.autoID ? "Follow System (\(current.name))" : current.name
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
