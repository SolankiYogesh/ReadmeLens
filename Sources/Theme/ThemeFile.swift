import SwiftUI

/// On-disk representation of a theme.
///
/// Deliberately flat and hex-based so it can be hand-edited. Every colour is
/// optional except the few a theme cannot work without; anything omitted is
/// derived or falls back, so a short file is still a valid theme.
struct ThemeFile: Codable {
    var id: String
    var name: String
    var appearance: String          // "dark" or "light"

    var canvas: String
    var foreground: String
    var accent: String

    var canvasSubtle: String?
    var canvasInset: String?
    var foregroundMuted: String?
    var foregroundSubtle: String?
    var border: String?
    var borderMuted: String?
    var blockquoteBar: String?
    var codeBackground: String?
    var codeForeground: String?
    var inlineCodeBackground: String?
    var tableHeaderBackground: String?
    var searchHighlight: String?
    var searchHighlightActive: String?

    /// Keys are `TokenKind` raw values: keyword, string, comment, …
    var syntax: [String: String]?
    /// Keys are `AlertKind` raw values: note, tip, important, warning, caution.
    var alerts: [String: String]?

    enum LoadError: LocalizedError {
        case badColor(String, String)
        case badAppearance(String)

        var errorDescription: String? {
            switch self {
            case let .badColor(field, value):
                return "\(field): “\(value)” is not a hex colour like #1F2328."
            case let .badAppearance(value):
                return "appearance: “\(value)” must be \"dark\" or \"light\"."
            }
        }
    }
}

extension ThemeFile {

    func makeTheme() throws -> Theme {
        guard let appearanceValue = ThemeAppearance(rawValue: appearance.lowercased()) else {
            throw LoadError.badAppearance(appearance)
        }

        func colour(_ value: String, _ field: String) throws -> Color {
            guard let parsed = Color(hexString: value) else {
                throw LoadError.badColor(field, value)
            }
            return parsed
        }
        func optional(_ value: String?, _ field: String, default fallback: Color) throws -> Color {
            guard let value else { return fallback }
            return try colour(value, field)
        }

        let base = try colour(canvas, "canvas")
        let text = try colour(foreground, "foreground")
        let link = try colour(accent, "accent")
        let isDark = appearanceValue == .dark

        // Sensible derivations, so a minimal file still looks deliberate.
        let subtle = try optional(canvasSubtle, "canvasSubtle",
                                  default: base.mixed(with: isDark ? .white : .black, by: 0.04))
        let inset = try optional(canvasInset, "canvasInset",
                                 default: base.mixed(with: isDark ? .black : .black, by: 0.25))
        let muted = try optional(foregroundMuted, "foregroundMuted",
                                 default: text.mixed(with: base, by: 0.35))
        let faint = try optional(foregroundSubtle, "foregroundSubtle",
                                 default: text.mixed(with: base, by: 0.55))
        let line = try optional(border, "border",
                                default: base.mixed(with: text, by: 0.18))

        var syntaxColours: [TokenKind: Color] = [:]
        for kind in TokenKind.allCases {
            if let raw = syntax?[kind.rawValue] {
                syntaxColours[kind] = try colour(raw, "syntax.\(kind.rawValue)")
            } else {
                syntaxColours[kind] = kind == .comment ? muted : text
            }
        }

        var alertColours: [AlertKind: Color] = [:]
        for kind in AlertKind.allCases {
            if let raw = alerts?[kind.rawValue] {
                alertColours[kind] = try colour(raw, "alerts.\(kind.rawValue)")
            } else {
                alertColours[kind] = link
            }
        }

        return Theme(
            id: id,
            name: name,
            appearance: appearanceValue,
            canvas: base,
            canvasSubtle: subtle,
            canvasInset: inset,
            fg: text,
            fgMuted: muted,
            fgSubtle: faint,
            link: link,
            border: line,
            borderMuted: try optional(borderMuted, "borderMuted", default: line),
            blockquoteBar: try optional(blockquoteBar, "blockquoteBar", default: line),
            codeBg: try optional(codeBackground, "codeBackground", default: subtle),
            codeFg: try optional(codeForeground, "codeForeground", default: text),
            inlineCodeBg: try optional(inlineCodeBackground, "inlineCodeBackground",
                                       default: line.opacity(0.5)),
            syntax: syntaxColours,
            alerts: alertColours,
            tableHeaderBg: try optional(tableHeaderBackground, "tableHeaderBackground",
                                        default: subtle),
            tableStripe: subtle.opacity(0.5),
            searchHit: try optional(searchHighlight, "searchHighlight",
                                    default: Color(hex: 0xBB8009, opacity: 0.45)),
            searchHitActive: try optional(searchHighlightActive, "searchHighlightActive",
                                          default: Color(hex: 0xE3B341, opacity: 0.85))
        )
    }

    /// Serialises a theme so the current one can be exported as a starting
    /// point for editing.
    init(_ theme: Theme) {
        id = theme.id
        name = theme.name
        appearance = theme.appearance.rawValue
        canvas = theme.canvas.hexString
        foreground = theme.fg.hexString
        accent = theme.link.hexString
        canvasSubtle = theme.canvasSubtle.hexString
        canvasInset = theme.canvasInset.hexString
        foregroundMuted = theme.fgMuted.hexString
        foregroundSubtle = theme.fgSubtle.hexString
        border = theme.border.hexString
        borderMuted = theme.borderMuted.hexString
        blockquoteBar = theme.blockquoteBar.hexString
        codeBackground = theme.codeBg.hexString
        codeForeground = theme.codeFg.hexString
        inlineCodeBackground = theme.inlineCodeBg.hexString
        tableHeaderBackground = theme.tableHeaderBg.hexString
        searchHighlight = theme.searchHit.hexString
        searchHighlightActive = theme.searchHitActive.hexString
        syntax = Dictionary(
            uniqueKeysWithValues: theme.syntax.map { ($0.key.rawValue, $0.value.hexString) }
        )
        alerts = Dictionary(
            uniqueKeysWithValues: theme.alerts.map { ($0.key.rawValue, $0.value.hexString) }
        )
    }
}

// MARK: - Hex conversion

extension Color {
    /// Parses `#RRGGBB`, `RRGGBB`, `#RGB` or `#RRGGBBAA`.
    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.allSatisfy(\.isHexDigit) else { return nil }

        switch text.count {
        case 3:
            let expanded = text.map { "\($0)\($0)" }.joined()
            guard let value = UInt32(expanded, radix: 16) else { return nil }
            self.init(hex: value)
        case 6:
            guard let value = UInt32(text, radix: 16) else { return nil }
            self.init(hex: value)
        case 8:
            guard let value = UInt32(text, radix: 16) else { return nil }
            self.init(hex: value >> 8, opacity: Double(value & 0xFF) / 255)
        default:
            return nil
        }
    }

    /// `#RRGGBB`, or `#RRGGBBAA` when not fully opaque.
    var hexString: String {
        guard let resolved = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((resolved.redComponent * 255).rounded())
        let g = Int((resolved.greenComponent * 255).rounded())
        let b = Int((resolved.blueComponent * 255).rounded())
        let a = Int((resolved.alphaComponent * 255).rounded())
        return a >= 255
            ? String(format: "#%02X%02X%02X", r, g, b)
            : String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    /// Blends towards another colour — used to derive tokens a minimal theme
    /// file leaves out.
    func mixed(with other: Color, by fraction: Double) -> Color {
        guard let a = NSColor(self).usingColorSpace(.sRGB),
              let b = NSColor(other).usingColorSpace(.sRGB)
        else { return self }
        let t = max(0, min(1, fraction))
        return Color(
            .sRGB,
            red: Double(a.redComponent) * (1 - t) + Double(b.redComponent) * t,
            green: Double(a.greenComponent) * (1 - t) + Double(b.greenComponent) * t,
            blue: Double(a.blueComponent) * (1 - t) + Double(b.blueComponent) * t,
            opacity: Double(a.alphaComponent)
        )
    }
}

