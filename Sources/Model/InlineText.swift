import Foundation

struct InlineStyle: OptionSet, Hashable {
    let rawValue: Int
    static let bold      = InlineStyle(rawValue: 1 << 0)
    static let italic    = InlineStyle(rawValue: 1 << 1)
    static let strike    = InlineStyle(rawValue: 1 << 2)
    static let code      = InlineStyle(rawValue: 1 << 3)
}

/// One run of inline text carrying its formatting.
struct InlineSpan: Hashable {
    var text: String
    var style: InlineStyle = []
    var link: String?
}

/// A styled inline sequence, stored structurally rather than as a rendered
/// `AttributedString`.
///
/// This is deliberate: colours belong to the active `Theme`, so keeping the
/// model theme-free means switching theme is a re-render, never a re-parse.
/// It also gives search a clean place to inject highlight ranges later.
struct InlineText: Hashable {
    var spans: [InlineSpan]

    static let empty = InlineText(spans: [])
    var isEmpty: Bool { spans.allSatisfy { $0.text.isEmpty } }

    /// Undecorated text — used for headings' TOC entries, anchors and search.
    var plain: String { spans.map(\.text).joined() }
}
