import Foundation

/// A parsed HTML element.
struct HTMLElement: Hashable {
    var tag: String                       // always lowercased
    var attributes: [String: String]      // keys lowercased
    var children: [HTMLNode]

    func attribute(_ name: String) -> String? { attributes[name] }

    /// `align="center"` on the element, or an implicit centre from `<center>`.
    var alignment: HTMLAlignment? {
        if tag == "center" { return .center }
        guard let raw = attributes["align"]?.lowercased() else { return nil }
        return HTMLAlignment(rawValue: raw)
    }
}

enum HTMLAlignment: String, Hashable {
    case left, center, right
}

indirect enum HTMLNode: Hashable {
    case text(String)
    case element(HTMLElement)

    /// Text content with all markup stripped — used for fallbacks and alt text.
    var plainText: String {
        switch self {
        case let .text(value):
            return value
        case let .element(element):
            return element.children.map(\.plainText).joined()
        }
    }
}

extension Array where Element == HTMLNode {
    var plainText: String { map(\.plainText).joined() }
}
