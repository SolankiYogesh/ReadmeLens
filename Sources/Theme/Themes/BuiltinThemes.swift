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


    // MARK: Nord

    static let nord = Theme(
        id: "nord",
        name: "Nord",
        appearance: .dark,

        canvas:       Color(hex: 0x2E3440),
        canvasSubtle: Color(hex: 0x3B4252),
        canvasInset:  Color(hex: 0x272C36),

        fg:       Color(hex: 0xECEFF4),
        fgMuted:  Color(hex: 0xD8DEE9),
        fgSubtle: Color(hex: 0x7B88A1),
        link:     Color(hex: 0x88C0D0),

        border:        Color(hex: 0x434C5E),
        borderMuted:   Color(hex: 0x3B4252),
        blockquoteBar: Color(hex: 0x4C566A),

        codeBg:       Color(hex: 0x3B4252),
        codeFg:       Color(hex: 0xECEFF4),
        inlineCodeBg: Color(hex: 0x4C566A, opacity: 0.45),
        syntax: [
            .plain: Color(hex: 0xECEFF4),   .keyword:     Color(hex: 0x81A1C1),
            .string: Color(hex: 0xA3BE8C),  .number:      Color(hex: 0xB48EAD),
            .comment: Color(hex: 0x616E88), .function:    Color(hex: 0x88C0D0),
            .type: Color(hex: 0x8FBCBB),    .variable:    Color(hex: 0xD8DEE9),
            .operator: Color(hex: 0x81A1C1),.punctuation: Color(hex: 0xECEFF4),
            .attribute: Color(hex: 0x8FBCBB),
        ],
        alerts: [
            .note: Color(hex: 0x88C0D0),      .tip:     Color(hex: 0xA3BE8C),
            .important: Color(hex: 0xB48EAD), .warning: Color(hex: 0xEBCB8B),
            .caution: Color(hex: 0xBF616A),
        ],
        tableHeaderBg:   Color(hex: 0x3B4252),
        tableStripe:     Color(hex: 0x3B4252, opacity: 0.5),
        searchHit:       Color(hex: 0xEBCB8B, opacity: 0.35),
        searchHitActive: Color(hex: 0xEBCB8B, opacity: 0.75)
    )

    // MARK: Gruvbox Dark

    static let gruvboxDark = Theme(
        id: "gruvbox-dark",
        name: "Gruvbox Dark",
        appearance: .dark,

        canvas:       Color(hex: 0x282828),
        canvasSubtle: Color(hex: 0x32302F),
        canvasInset:  Color(hex: 0x1D2021),

        fg:       Color(hex: 0xEBDBB2),
        fgMuted:  Color(hex: 0xA89984),
        fgSubtle: Color(hex: 0x928374),
        link:     Color(hex: 0x83A598),

        border:        Color(hex: 0x504945),
        borderMuted:   Color(hex: 0x3C3836),
        blockquoteBar: Color(hex: 0x665C54),

        codeBg:       Color(hex: 0x32302F),
        codeFg:       Color(hex: 0xEBDBB2),
        inlineCodeBg: Color(hex: 0x928374, opacity: 0.28),
        syntax: [
            .plain: Color(hex: 0xEBDBB2),   .keyword:     Color(hex: 0xFB4934),
            .string: Color(hex: 0xB8BB26),  .number:      Color(hex: 0xD3869B),
            .comment: Color(hex: 0x928374), .function:    Color(hex: 0xFABD2F),
            .type: Color(hex: 0x8EC07C),    .variable:    Color(hex: 0x83A598),
            .operator: Color(hex: 0xFE8019),.punctuation: Color(hex: 0xEBDBB2),
            .attribute: Color(hex: 0x8EC07C),
        ],
        alerts: [
            .note: Color(hex: 0x83A598),      .tip:     Color(hex: 0xB8BB26),
            .important: Color(hex: 0xD3869B), .warning: Color(hex: 0xFABD2F),
            .caution: Color(hex: 0xFB4934),
        ],
        tableHeaderBg:   Color(hex: 0x32302F),
        tableStripe:     Color(hex: 0x32302F, opacity: 0.5),
        searchHit:       Color(hex: 0xFABD2F, opacity: 0.3),
        searchHitActive: Color(hex: 0xFABD2F, opacity: 0.7)
    )

    // MARK: Solarized Dark

    static let solarizedDark = Theme(
        id: "solarized-dark",
        name: "Solarized Dark",
        appearance: .dark,

        canvas:       Color(hex: 0x002B36),
        canvasSubtle: Color(hex: 0x073642),
        canvasInset:  Color(hex: 0x00212B),

        fg:       Color(hex: 0x93A1A1),
        fgMuted:  Color(hex: 0x839496),
        fgSubtle: Color(hex: 0x657B83),
        link:     Color(hex: 0x268BD2),

        border:        Color(hex: 0x0F4B5A),
        borderMuted:   Color(hex: 0x073642),
        blockquoteBar: Color(hex: 0x586E75),

        codeBg:       Color(hex: 0x073642),
        codeFg:       Color(hex: 0x93A1A1),
        inlineCodeBg: Color(hex: 0x586E75, opacity: 0.35),
        syntax: [
            .plain: Color(hex: 0x93A1A1),   .keyword:     Color(hex: 0x859900),
            .string: Color(hex: 0x2AA198),  .number:      Color(hex: 0xD33682),
            .comment: Color(hex: 0x586E75), .function:    Color(hex: 0x268BD2),
            .type: Color(hex: 0xB58900),    .variable:    Color(hex: 0xCB4B16),
            .operator: Color(hex: 0x859900),.punctuation: Color(hex: 0x93A1A1),
            .attribute: Color(hex: 0x6C71C4),
        ],
        alerts: [
            .note: Color(hex: 0x268BD2),      .tip:     Color(hex: 0x859900),
            .important: Color(hex: 0x6C71C4), .warning: Color(hex: 0xB58900),
            .caution: Color(hex: 0xDC322F),
        ],
        tableHeaderBg:   Color(hex: 0x073642),
        tableStripe:     Color(hex: 0x073642, opacity: 0.5),
        searchHit:       Color(hex: 0xB58900, opacity: 0.3),
        searchHitActive: Color(hex: 0xB58900, opacity: 0.7)
    )

    // MARK: Solarized Light

    static let solarizedLight = Theme(
        id: "solarized-light",
        name: "Solarized Light",
        appearance: .light,

        canvas:       Color(hex: 0xFDF6E3),
        canvasSubtle: Color(hex: 0xEEE8D5),
        canvasInset:  Color(hex: 0xEEE8D5),

        fg:       Color(hex: 0x586E75),
        fgMuted:  Color(hex: 0x657B83),
        fgSubtle: Color(hex: 0x93A1A1),
        link:     Color(hex: 0x268BD2),

        border:        Color(hex: 0xD9D2C0),
        borderMuted:   Color(hex: 0xEEE8D5),
        blockquoteBar: Color(hex: 0x93A1A1),

        codeBg:       Color(hex: 0xEEE8D5),
        codeFg:       Color(hex: 0x586E75),
        inlineCodeBg: Color(hex: 0x93A1A1, opacity: 0.28),
        syntax: [
            .plain: Color(hex: 0x586E75),   .keyword:     Color(hex: 0x859900),
            .string: Color(hex: 0x2AA198),  .number:      Color(hex: 0xD33682),
            .comment: Color(hex: 0x93A1A1), .function:    Color(hex: 0x268BD2),
            .type: Color(hex: 0xB58900),    .variable:    Color(hex: 0xCB4B16),
            .operator: Color(hex: 0x859900),.punctuation: Color(hex: 0x586E75),
            .attribute: Color(hex: 0x6C71C4),
        ],
        alerts: [
            .note: Color(hex: 0x268BD2),      .tip:     Color(hex: 0x859900),
            .important: Color(hex: 0x6C71C4), .warning: Color(hex: 0xB58900),
            .caution: Color(hex: 0xDC322F),
        ],
        tableHeaderBg:   Color(hex: 0xEEE8D5),
        tableStripe:     Color(hex: 0xEEE8D5, opacity: 0.6),
        searchHit:       Color(hex: 0xB58900, opacity: 0.25),
        searchHitActive: Color(hex: 0xB58900, opacity: 0.55)
    )

    // MARK: Tokyo Night

    static let tokyoNight = Theme(
        id: "tokyo-night",
        name: "Tokyo Night",
        appearance: .dark,

        canvas:       Color(hex: 0x1A1B26),
        canvasSubtle: Color(hex: 0x1F2335),
        canvasInset:  Color(hex: 0x16161E),

        fg:       Color(hex: 0xC0CAF5),
        fgMuted:  Color(hex: 0xA9B1D6),
        fgSubtle: Color(hex: 0x565F89),
        link:     Color(hex: 0x7AA2F7),

        border:        Color(hex: 0x292E42),
        borderMuted:   Color(hex: 0x222436),
        blockquoteBar: Color(hex: 0x3B4261),

        codeBg:       Color(hex: 0x1F2335),
        codeFg:       Color(hex: 0xC0CAF5),
        inlineCodeBg: Color(hex: 0x565F89, opacity: 0.35),
        syntax: [
            .plain: Color(hex: 0xC0CAF5),   .keyword:     Color(hex: 0xBB9AF7),
            .string: Color(hex: 0x9ECE6A),  .number:      Color(hex: 0xFF9E64),
            .comment: Color(hex: 0x565F89), .function:    Color(hex: 0x7AA2F7),
            .type: Color(hex: 0x2AC3DE),    .variable:    Color(hex: 0xC0CAF5),
            .operator: Color(hex: 0x89DDFF),.punctuation: Color(hex: 0xA9B1D6),
            .attribute: Color(hex: 0x7DCFFF),
        ],
        alerts: [
            .note: Color(hex: 0x7AA2F7),      .tip:     Color(hex: 0x9ECE6A),
            .important: Color(hex: 0xBB9AF7), .warning: Color(hex: 0xE0AF68),
            .caution: Color(hex: 0xF7768E),
        ],
        tableHeaderBg:   Color(hex: 0x1F2335),
        tableStripe:     Color(hex: 0x1F2335, opacity: 0.5),
        searchHit:       Color(hex: 0xE0AF68, opacity: 0.3),
        searchHitActive: Color(hex: 0xE0AF68, opacity: 0.7)
    )

    // MARK: Catppuccin Mocha

    static let catppuccinMocha = Theme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        appearance: .dark,

        canvas:       Color(hex: 0x1E1E2E),
        canvasSubtle: Color(hex: 0x181825),
        canvasInset:  Color(hex: 0x11111B),

        fg:       Color(hex: 0xCDD6F4),
        fgMuted:  Color(hex: 0xA6ADC8),
        fgSubtle: Color(hex: 0x6C7086),
        link:     Color(hex: 0x89B4FA),

        border:        Color(hex: 0x313244),
        borderMuted:   Color(hex: 0x252537),
        blockquoteBar: Color(hex: 0x45475A),

        codeBg:       Color(hex: 0x181825),
        codeFg:       Color(hex: 0xCDD6F4),
        inlineCodeBg: Color(hex: 0x6C7086, opacity: 0.32),
        syntax: [
            .plain: Color(hex: 0xCDD6F4),   .keyword:     Color(hex: 0xCBA6F7),
            .string: Color(hex: 0xA6E3A1),  .number:      Color(hex: 0xFAB387),
            .comment: Color(hex: 0x6C7086), .function:    Color(hex: 0x89B4FA),
            .type: Color(hex: 0xF9E2AF),    .variable:    Color(hex: 0xF38BA8),
            .operator: Color(hex: 0x94E2D5),.punctuation: Color(hex: 0xBAC2DE),
            .attribute: Color(hex: 0x74C7EC),
        ],
        alerts: [
            .note: Color(hex: 0x89B4FA),      .tip:     Color(hex: 0xA6E3A1),
            .important: Color(hex: 0xCBA6F7), .warning: Color(hex: 0xF9E2AF),
            .caution: Color(hex: 0xF38BA8),
        ],
        tableHeaderBg:   Color(hex: 0x181825),
        tableStripe:     Color(hex: 0x181825, opacity: 0.5),
        searchHit:       Color(hex: 0xF9E2AF, opacity: 0.3),
        searchHitActive: Color(hex: 0xF9E2AF, opacity: 0.7)
    )

    /// Every bundled theme. Phase 8's picker reads this; adding a theme means
    /// appending one instance here and nothing else.
    static let builtins: [Theme] = [
        .githubDark, .githubLight, .dracula, .nord,
        .gruvboxDark, .solarizedDark, .solarizedLight,
        .tokyoNight, .catppuccinMocha,
    ]

    static func builtin(id: String) -> Theme? { builtins.first { $0.id == id } }
}
