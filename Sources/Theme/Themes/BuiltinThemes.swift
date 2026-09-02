import SwiftUI

// Palette values below are the published UI colours of each scheme.
// GitHub Dark/Light follow GitHub's Primer palette; Dracula follows the
// Dracula spec. Both schemes are MIT licensed and credited in the README.

extension Theme {

    // MARK: GitHub Dark — the app default

    static let githubDark = Theme(
        id: "github-dark",
        name: "GitHub Dark",
        appearance: .dark,

        canvas:       Color(hex: 0x0D1117),
        canvasSubtle: Color(hex: 0x161B22),
        canvasInset:  Color(hex: 0x010409),

        fg:       Color(hex: 0xE6EDF3),
        fgMuted:  Color(hex: 0x8B949E),
        fgSubtle: Color(hex: 0x6E7681),
        link:     Color(hex: 0x4493F8),

        border:        Color(hex: 0x30363D),
        borderMuted:   Color(hex: 0x21262D),
        blockquoteBar: Color(hex: 0x3D444D),

        codeBg:       Color(hex: 0x161B22),
        codeFg:       Color(hex: 0xE6EDF3),
        inlineCodeBg: Color(hex: 0x6E7681, opacity: 0.25),
        syntax: [
            .plain:       Color(hex: 0xE6EDF3),
            .keyword:     Color(hex: 0xFF7B72),
            .string:      Color(hex: 0xA5D6FF),
            .number:      Color(hex: 0x79C0FF),
            .comment:     Color(hex: 0x8B949E),
            .function:    Color(hex: 0xD2A8FF),
            .type:        Color(hex: 0xFFA657),
            .variable:    Color(hex: 0x79C0FF),
            .operator:    Color(hex: 0xFF7B72),
            .punctuation: Color(hex: 0xC9D1D9),
            .attribute:   Color(hex: 0x7EE787),
        ],

        alerts: [
            .note:      Color(hex: 0x4493F8),
            .tip:       Color(hex: 0x3FB950),
            .important: Color(hex: 0xAB7DF8),
            .warning:   Color(hex: 0xD29922),
            .caution:   Color(hex: 0xF85149),
        ],

        tableHeaderBg:   Color(hex: 0x161B22),
        tableStripe:     Color(hex: 0x161B22, opacity: 0.5),
        searchHit:       Color(hex: 0xBB8009, opacity: 0.45),
        searchHitActive: Color(hex: 0xE3B341, opacity: 0.85)
    )

    // MARK: GitHub Light

    static let githubLight = Theme(
        id: "github-light",
        name: "GitHub Light",
        appearance: .light,

        canvas:       Color(hex: 0xFFFFFF),
        canvasSubtle: Color(hex: 0xF6F8FA),
        canvasInset:  Color(hex: 0xF6F8FA),

        fg:       Color(hex: 0x1F2328),
        fgMuted:  Color(hex: 0x59636E),
        fgSubtle: Color(hex: 0x818B98),
        link:     Color(hex: 0x0969DA),

        border:        Color(hex: 0xD1D9E0),
        borderMuted:   Color(hex: 0xD1D9E0),
        blockquoteBar: Color(hex: 0xD1D9E0),

        codeBg:       Color(hex: 0xF6F8FA),
        codeFg:       Color(hex: 0x1F2328),
        inlineCodeBg: Color(hex: 0x818B98, opacity: 0.2),
        syntax: [
            .plain:       Color(hex: 0x1F2328),
            .keyword:     Color(hex: 0xCF222E),
            .string:      Color(hex: 0x0A3069),
            .number:      Color(hex: 0x0550AE),
            .comment:     Color(hex: 0x59636E),
            .function:    Color(hex: 0x8250DF),
            .type:        Color(hex: 0x953800),
            .variable:    Color(hex: 0x0550AE),
            .operator:    Color(hex: 0xCF222E),
            .punctuation: Color(hex: 0x1F2328),
            .attribute:   Color(hex: 0x116329),
        ],

        alerts: [
            .note:      Color(hex: 0x0969DA),
            .tip:       Color(hex: 0x1A7F37),
            .important: Color(hex: 0x8250DF),
            .warning:   Color(hex: 0x9A6700),
            .caution:   Color(hex: 0xCF222E),
        ],

        tableHeaderBg:   Color(hex: 0xF6F8FA),
        tableStripe:     Color(hex: 0xF6F8FA, opacity: 0.6),
        searchHit:       Color(hex: 0xFFF8C5),
        searchHitActive: Color(hex: 0xFAE17D)
    )

    // MARK: Dracula

    static let dracula = Theme(
        id: "dracula",
        name: "Dracula",
        appearance: .dark,

        canvas:       Color(hex: 0x282A36),
        canvasSubtle: Color(hex: 0x21222C),
        canvasInset:  Color(hex: 0x191A21),

        fg:       Color(hex: 0xF8F8F2),
        fgMuted:  Color(hex: 0x9BA0B0),
        fgSubtle: Color(hex: 0x6272A4),
        link:     Color(hex: 0x8BE9FD),

        border:        Color(hex: 0x44475A),
        borderMuted:   Color(hex: 0x343746),
        blockquoteBar: Color(hex: 0x6272A4),

        codeBg:       Color(hex: 0x21222C),
        codeFg:       Color(hex: 0xF8F8F2),
        inlineCodeBg: Color(hex: 0x6272A4, opacity: 0.3),
        syntax: [
            .plain:       Color(hex: 0xF8F8F2),
            .keyword:     Color(hex: 0xFF79C6),
            .string:      Color(hex: 0xF1FA8C),
            .number:      Color(hex: 0xBD93F9),
            .comment:     Color(hex: 0x6272A4),
            .function:    Color(hex: 0x50FA7B),
            .type:        Color(hex: 0x8BE9FD),
            .variable:    Color(hex: 0xFFB86C),
            .operator:    Color(hex: 0xFF79C6),
            .punctuation: Color(hex: 0xF8F8F2),
            .attribute:   Color(hex: 0x50FA7B),
        ],

        alerts: [
            .note:      Color(hex: 0x8BE9FD),
            .tip:       Color(hex: 0x50FA7B),
            .important: Color(hex: 0xBD93F9),
            .warning:   Color(hex: 0xFFB86C),
            .caution:   Color(hex: 0xFF5555),
        ],

        tableHeaderBg:   Color(hex: 0x21222C),
        tableStripe:     Color(hex: 0x21222C, opacity: 0.5),
        searchHit:       Color(hex: 0xFFB86C, opacity: 0.35),
        searchHitActive: Color(hex: 0xF1FA8C, opacity: 0.8)
    )

    /// Every bundled theme. Phase 8's picker reads this; adding a theme means
    /// appending one instance here and nothing else.
    static let builtins: [Theme] = [.githubDark, .githubLight, .dracula]

    static func builtin(id: String) -> Theme? { builtins.first { $0.id == id } }
}
