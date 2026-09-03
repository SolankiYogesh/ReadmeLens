import Foundation

/// A small, deliberately forgiving HTML parser for the markup that shows up
/// inside READMEs.
///
/// This is **not** a browser. It builds a passive node tree that the view layer
/// maps onto SwiftUI. Nothing is ever executed, no web view is involved, and
/// `script`, `style`, `iframe`, `object` and `embed` are dropped along with
/// their contents rather than rendered.
///
/// Real-world README HTML is frequently malformed — unclosed `<p>`, stray
/// `</div>`, attributes without quotes. Every one of those has to degrade to
/// something readable rather than throwing, so the parser never fails: worst
/// case it returns the text it saw.
enum HTMLParser {

    /// Elements that never have a closing tag.
    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ]

    /// Dropped entirely, contents included. A viewer has no business rendering
    /// these, and showing their source would be noise.
    static let discardedElements: Set<String> = [
        "script", "style", "iframe", "object", "embed", "noscript", "template",
    ]

    static func parse(_ html: String) -> [HTMLNode] {
        var scanner = Scanner(html)
        var stack: [HTMLElement] = []
        var roots: [HTMLNode] = []

        func append(_ node: HTMLNode) {
            if stack.isEmpty {
                roots.append(node)
            } else {
                stack[stack.count - 1].children.append(node)
            }
        }

        while let token = scanner.nextToken() {
            switch token {
            case let .text(value):
                let cleaned = HTMLEntities.decode(value)
                if !cleaned.isEmpty { append(.text(cleaned)) }

            case let .open(tag, attributes, selfClosing):
                if discardedElements.contains(tag) {
                    if !selfClosing { scanner.skipToClosingTag(tag) }
                    continue
                }
                let element = HTMLElement(tag: tag, attributes: attributes, children: [])
                if selfClosing || voidElements.contains(tag) {
                    append(.element(element))
                } else {
                    stack.append(element)
                }

            case let .close(tag):
                // Unwind to the matching open tag. A stray `</div>` with no
                // partner is ignored rather than corrupting the tree.
                guard let index = stack.lastIndex(where: { $0.tag == tag }) else { continue }
                while stack.count > index {
                    let finished = stack.removeLast()
                    if stack.isEmpty {
                        roots.append(.element(finished))
                    } else {
                        stack[stack.count - 1].children.append(.element(finished))
                    }
                }

            case .comment:
                continue
            }
        }

        // Anything still open at EOF is closed implicitly, innermost first.
        while let finished = stack.popLast() {
            if stack.isEmpty {
                roots.append(.element(finished))
            } else {
                stack[stack.count - 1].children.append(.element(finished))
            }
        }
        return roots
    }

    // MARK: - Tokenizer

    private enum Token {
        case text(String)
        case open(tag: String, attributes: [String: String], selfClosing: Bool)
        case close(tag: String)
        case comment
    }

    private struct Scanner {
        private let chars: [Character]
        private var index: Int = 0

        init(_ string: String) { chars = Array(string) }

        var isAtEnd: Bool { index >= chars.count }

        mutating func nextToken() -> Token? {
            guard !isAtEnd else { return nil }

            if chars[index] == "<" {
                if matches("<!--") { skipComment(); return .comment }
                // A `<` that isn't followed by a tag name is literal text.
                if let token = readTag() { return token }
                index += 1
                return .text("<")
            }

            var text = ""
            while !isAtEnd, chars[index] != "<" {
                text.append(chars[index])
                index += 1
            }
            return .text(text)
        }

        private func matches(_ prefix: String) -> Bool {
            let p = Array(prefix)
            guard index + p.count <= chars.count else { return false }
            return Array(chars[index..<(index + p.count)]) == p
        }

        private mutating func skipComment() {
            index += 4
            while !isAtEnd, !matches("-->") { index += 1 }
            if !isAtEnd { index += 3 }
        }

        private mutating func readTag() -> Token? {
            let start = index
            index += 1                                  // consume '<'

            var isClosing = false
            if !isAtEnd, chars[index] == "/" { isClosing = true; index += 1 }

            var name = ""
            while !isAtEnd, chars[index].isLetter || chars[index].isNumber
                          || chars[index] == "-" || chars[index] == "_" {
                name.append(chars[index])
                index += 1
            }
            guard !name.isEmpty else { index = start; return nil }
            let tag = name.lowercased()

            if isClosing {
                while !isAtEnd, chars[index] != ">" { index += 1 }
                if !isAtEnd { index += 1 }
                return .close(tag: tag)
            }

            var attributes: [String: String] = [:]
            var selfClosing = false

            while !isAtEnd {
                skipWhitespace()
                if isAtEnd { break }
                if chars[index] == ">" { index += 1; break }
                if chars[index] == "/" {
                    selfClosing = true
                    index += 1
                    continue
                }

                var key = ""
                while !isAtEnd, !chars[index].isWhitespace,
                      chars[index] != "=", chars[index] != ">", chars[index] != "/" {
                    key.append(chars[index])
                    index += 1
                }
                if key.isEmpty { index += 1; continue }

                skipWhitespace()
                var value = ""
                if !isAtEnd, chars[index] == "=" {
                    index += 1
                    skipWhitespace()
                    if !isAtEnd, chars[index] == "\"" || chars[index] == "'" {
                        let quote = chars[index]
                        index += 1
                        while !isAtEnd, chars[index] != quote {
                            value.append(chars[index])
                            index += 1
                        }
                        if !isAtEnd { index += 1 }
                    } else {
                        // Unquoted attribute value.
                        while !isAtEnd, !chars[index].isWhitespace, chars[index] != ">" {
                            value.append(chars[index])
                            index += 1
                        }
                    }
                }
                attributes[key.lowercased()] = HTMLEntities.decode(value)
            }
            return .open(tag: tag, attributes: attributes, selfClosing: selfClosing)
        }

        private mutating func skipWhitespace() {
            while !isAtEnd, chars[index].isWhitespace { index += 1 }
        }

        mutating func skipToClosingTag(_ tag: String) {
            while !isAtEnd {
                if chars[index] == "<", matches("</\(tag)") {
                    while !isAtEnd, chars[index] != ">" { index += 1 }
                    if !isAtEnd { index += 1 }
                    return
                }
                index += 1
            }
        }
    }
}

/// The handful of entities that actually appear in README HTML.
enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "copy": "©", "reg": "®", "trade": "™",
        "mdash": "—", "ndash": "–", "hellip": "…", "middot": "·",
        "laquo": "«", "raquo": "»", "times": "×", "rarr": "→", "larr": "←",
        "check": "✓", "star": "★", "bull": "•",
    ]

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var out = ""
        var rest = Substring(text)

        while let start = rest.firstIndex(of: "&") {
            out += rest[rest.startIndex..<start]
            let after = rest.index(after: start)
            guard let end = rest[after...].firstIndex(of: ";"),
                  rest.distance(from: after, to: end) <= 10
            else {
                out.append("&")
                rest = rest[after...]
                continue
            }

            let body = String(rest[after..<end])
            if body.hasPrefix("#") {
                let digits = body.dropFirst()
                let scalar: UInt32? = digits.hasPrefix("x") || digits.hasPrefix("X")
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits)
                if let scalar, let unicode = Unicode.Scalar(scalar) {
                    out.unicodeScalars.append(unicode)
                } else {
                    out += "&\(body);"
                }
            } else if let replacement = named[body.lowercased()] {
                out += replacement
            } else {
                out += "&\(body);"
            }
            rest = rest[rest.index(after: end)...]
        }
        out += rest
        return out
    }
}
