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

    var current: Theme {
        if selectedID == Self.autoID {
            let id = systemIsDark ? autoDarkID : autoLightID
            return Theme.builtin(id: id) ?? .githubDark
        }
        return Theme.builtin(id: selectedID) ?? .githubDark
    }

    var available: [Theme] { Theme.builtins }

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
