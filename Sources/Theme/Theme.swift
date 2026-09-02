import SwiftUI

/// Kinds of syntax token the highlighter can emit.
///
/// The highlighter classifies text into these cases and never chooses a colour
/// itself — the active `Theme` owns that mapping. This is what lets a new theme
/// be a pure data file with no code change.
enum TokenKind: String, CaseIterable, Hashable {
    case plain, keyword, string, number, comment
    case function, type, variable, `operator`, punctuation, attribute
}

/// GitHub-flavored alert callouts (`> [!NOTE]` and friends).
enum AlertKind: String, CaseIterable, Hashable {
    case note, tip, important, warning, caution

    var title: String {
        switch self {
        case .note:      return "Note"
        case .tip:       return "Tip"
        case .important: return "Important"
        case .warning:   return "Warning"
        case .caution:   return "Caution"
        }
    }

    var systemImage: String {
        switch self {
        case .note:      return "info.circle.fill"
        case .tip:       return "lightbulb.fill"
        case .important: return "exclamationmark.message.fill"
        case .warning:   return "exclamationmark.triangle.fill"
        case .caution:   return "exclamationmark.octagon.fill"
        }
    }
}

enum ThemeAppearance: String, Codable {
    case dark, light

    var nsAppearance: NSAppearance? {
        NSAppearance(named: self == .dark ? .darkAqua : .aqua)
    }
}

/// The complete visual contract every view renders against.
///
/// No view in this app may name a colour directly; it reads from here. Adding a
/// theme means adding one more instance, never touching a view.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let appearance: ThemeAppearance

    // Surfaces
    let canvas: Color
    let canvasSubtle: Color
    let canvasInset: Color

    // Text
    let fg: Color
    let fgMuted: Color
    let fgSubtle: Color
    let link: Color

    // Structure
    let border: Color
    let borderMuted: Color
    let blockquoteBar: Color

    // Code
    let codeBg: Color
    let codeFg: Color
    let inlineCodeBg: Color
    let syntax: [TokenKind: Color]

    // Alerts
    let alerts: [AlertKind: Color]

    // Tables & search
    let tableHeaderBg: Color
    let tableStripe: Color
    let searchHit: Color
    let searchHitActive: Color

    func syntaxColor(_ kind: TokenKind) -> Color { syntax[kind] ?? codeFg }
    func alertColor(_ kind: AlertKind) -> Color { alerts[kind] ?? link }

    static func == (a: Theme, b: Theme) -> Bool { a.id == b.id }
}

// MARK: - Hex convenience

extension Color {
    /// Builds a colour from a 0xRRGGBB literal. Keeps theme files readable as
    /// palettes rather than as walls of floating point.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .githubDark
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
