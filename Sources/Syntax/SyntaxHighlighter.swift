import Foundation

/// A contiguous run of source text sharing one token kind.
struct SyntaxRun: Hashable {
    let text: String
    let kind: TokenKind
}

/// Tokenises source into runs the theme can colour.
///
/// The highlighter never chooses a colour — it reports what each run *is*, and
/// the active `Theme` maps kinds to colours. That is what lets nine themes
/// share one highlighter.
enum SyntaxHighlighter {

    /// Source longer than this is left unhighlighted; the cost stops being
    /// worth it and READMEs never contain blocks this large.
    private static let maximumLength = 100_000

    static func runs(for source: String, language: String?) -> [SyntaxRun] {
        guard source.count <= maximumLength,
              let grammar = Grammars.grammar(for: language)
        else { return [SyntaxRun(text: source, kind: .plain)] }

        if let cached = Cache.shared.runs(source: source, language: language) { return cached }

        let scanner = Scanner(source: Array(source), grammar: grammar)
        let result = grammar.isMarkup ? scanner.scanMarkup() : scanner.scanCode()
        Cache.shared.store(result, source: source, language: language)
        return result
    }

    /// Whether a fence tag is one we can colour, so callers can skip the work.
    static func canHighlight(_ language: String?) -> Bool {
        Grammars.grammar(for: language) != nil
    }

    // MARK: - Cache

    private final class Cache: @unchecked Sendable {
        static let shared = Cache()
        private let lock = NSLock()
        private var storage: [String: [SyntaxRun]] = [:]
        private var order: [String] = []
        private let limit = 200

        private func key(_ source: String, _ language: String?) -> String {
            "\(language ?? "")\u{1}\(source.hashValue)\u{1}\(source.count)"
        }

        func runs(source: String, language: String?) -> [SyntaxRun]? {
            lock.lock(); defer { lock.unlock() }
            return storage[key(source, language)]
        }

        func store(_ runs: [SyntaxRun], source: String, language: String?) {
            lock.lock(); defer { lock.unlock() }
            let k = key(source, language)
            if storage[k] == nil {
                order.append(k)
                if order.count > limit, let oldest = order.first {
                    order.removeFirst()
                    storage.removeValue(forKey: oldest)
                }
            }
            storage[k] = runs
        }
    }

    // MARK: - Scanner

    private struct Scanner {
        let source: [Character]
        let grammar: LanguageGrammar

        private static let operatorCharacters: Set<Character> = [
            "+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?",
        ]
        private static let punctuation: Set<Character> = [
            "(", ")", "[", "]", "{", "}", ",", ";", ":", ".", "@", "#", "$",
        ]

        func scanCode() -> [SyntaxRun] {
            var out = RunBuilder()
            var i = 0

            while i < source.count {
                let c = source[i]

                if c.isWhitespace {
                    out.append(String(c), .plain); i += 1; continue
                }

                if let length = matchLineComment(at: i) {
                    var end = i + length
                    while end < source.count, source[end] != "\n" { end += 1 }
                    out.append(String(source[i..<end]), .comment); i = end; continue
                }

                if let (length, close) = matchBlockComment(at: i) {
                    let end = findClose(close, from: i + length)
                    out.append(String(source[i..<end]), .comment); i = end; continue
                }

                if grammar.stringDelimiters.contains(c)
                    || grammar.multilineStringDelimiters.contains(c) {
                    let multiline = grammar.multilineStringDelimiters.contains(c)
                    let end = scanString(from: i, delimiter: c, multiline: multiline)
                    // A quoted JSON/YAML key is a key, not a value.
                    let kind: TokenKind = isAssignmentKey(endingAt: end) ? .attribute : .string
                    out.append(String(source[i..<end]), kind); i = end; continue
                }

                if c.isNumber {
                    let end = scanNumber(from: i)
                    out.append(String(source[i..<end]), .number); i = end; continue
                }

                if isIdentifierStart(c) {
                    var end = i + 1
                    while end < source.count, isIdentifierPart(source[end]) { end += 1 }
                    let word = String(source[i..<end])
                    out.append(word, kind(for: word, endingAt: end)); i = end; continue
                }

                if Self.operatorCharacters.contains(c) {
                    out.append(String(c), .operator); i += 1; continue
                }

                if Self.punctuation.contains(c) {
                    out.append(String(c), .punctuation); i += 1; continue
                }

                out.append(String(c), .plain); i += 1
            }
            return out.finish()
        }

        /// Tag-structured markup: element names, attributes and values.
        func scanMarkup() -> [SyntaxRun] {
            var out = RunBuilder()
            var i = 0

            while i < source.count {
                if source[i] == "<" {
                    if matches("<!--", at: i) {
                        let end = findClose("-->", from: i + 4)
                        out.append(String(source[i..<end]), .comment); i = end; continue
                    }
                    let end = scanTag(from: i, into: &out)
                    i = end
                    continue
                }
                var end = i
                while end < source.count, source[end] != "<" { end += 1 }
                out.append(String(source[i..<end]), .plain)
                i = end
            }
            return out.finish()
        }

        private func scanTag(from start: Int, into out: inout RunBuilder) -> Int {
            var i = start
            out.append("<", .punctuation); i += 1
            if i < source.count, source[i] == "/" { out.append("/", .punctuation); i += 1 }

            var nameEnd = i
            while nameEnd < source.count, isIdentifierPart(source[nameEnd]) || source[nameEnd] == ":" {
                nameEnd += 1
            }
            if nameEnd > i { out.append(String(source[i..<nameEnd]), .keyword); i = nameEnd }

            while i < source.count, source[i] != ">" {
                let c = source[i]
                if c.isWhitespace { out.append(String(c), .plain); i += 1; continue }
                if c == "\"" || c == "'" {
                    let end = scanString(from: i, delimiter: c, multiline: true)
                    out.append(String(source[i..<end]), .string); i = end; continue
                }
                if c == "=" || c == "/" {
                    out.append(String(c), .operator); i += 1; continue
                }
                if isIdentifierStart(c) {
                    var end = i + 1
                    while end < source.count, isIdentifierPart(source[end]) || source[end] == "-" {
                        end += 1
                    }
                    out.append(String(source[i..<end]), .attribute); i = end; continue
                }
                out.append(String(c), .plain); i += 1
            }
            if i < source.count { out.append(">", .punctuation); i += 1 }
            return i
        }

        // MARK: helpers

        /// True when the token ending here is immediately followed by `:` or
        /// `=`, in a grammar where that marks a key.
        private func isAssignmentKey(endingAt end: Int) -> Bool {
            guard grammar.highlightsAssignmentKeys else { return false }
            var next = end
            while next < source.count, source[next] == " " || source[next] == "\t" { next += 1 }
            guard next < source.count else { return false }
            return source[next] == ":" || source[next] == "="
        }

        private func kind(for word: String, endingAt end: Int) -> TokenKind {
            if grammar.isKeyword(word) { return .keyword }
            if grammar.isType(word) { return .type }

            var next = end
            while next < source.count, source[next] == " " || source[next] == "\t" { next += 1 }

            if next < source.count, source[next] == "(" { return .function }
            if isAssignmentKey(endingAt: end) { return .attribute }
            // A capitalised identifier is a type often enough to be worth it.
            if let first = word.first, first.isUppercase { return .type }
            return .plain
        }

        private func isIdentifierStart(_ c: Character) -> Bool {
            c.isLetter || c == "_" || c == "$"
        }

        private func isIdentifierPart(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "$"
        }

        private func matches(_ text: String, at index: Int) -> Bool {
            let chars = Array(text)
            guard index + chars.count <= source.count else { return false }
            return Array(source[index..<(index + chars.count)]) == chars
        }

        private func matchLineComment(at index: Int) -> Int? {
            for marker in grammar.lineComments where matches(marker, at: index) {
                return marker.count
            }
            return nil
        }

        private func matchBlockComment(at index: Int) -> (Int, String)? {
            for pair in grammar.blockComments where matches(pair.open, at: index) {
                return (pair.open.count, pair.close)
            }
            return nil
        }

        private func findClose(_ close: String, from index: Int) -> Int {
            var i = index
            while i < source.count {
                if matches(close, at: i) { return i + close.count }
                i += 1
            }
            return source.count
        }

        private func scanString(from start: Int, delimiter: Character, multiline: Bool) -> Int {
            var i = start + 1
            while i < source.count {
                let c = source[i]
                if let escape = grammar.escapeCharacter, c == escape {
                    i += 2; continue
                }
                if c == delimiter { return i + 1 }
                // An unterminated string must not swallow the rest of the file.
                if c == "\n", !multiline { return i }
                i += 1
            }
            return source.count
        }

        private func scanNumber(from start: Int) -> Int {
            var i = start
            if source[i] == "0", i + 1 < source.count,
               "xXbBoO".contains(source[i + 1]) {
                i += 2
                while i < source.count, source[i].isHexDigit || source[i] == "_" { i += 1 }
                return i
            }
            var seenDot = false
            while i < source.count {
                let c = source[i]
                if c.isNumber || c == "_" { i += 1; continue }
                if c == ".", !seenDot, i + 1 < source.count, source[i + 1].isNumber {
                    seenDot = true; i += 1; continue
                }
                if c == "e" || c == "E", i + 1 < source.count,
                   source[i + 1].isNumber || source[i + 1] == "-" || source[i + 1] == "+" {
                    i += 2; continue
                }
                break
            }
            // Numeric suffixes such as 10f, 5L, 3u.
            while i < source.count, source[i].isLetter { i += 1 }
            return i
        }
    }

    /// Accumulates runs, merging neighbours that share a kind so the view
    /// builds one attributed run per colour change rather than per character.
    private struct RunBuilder {
        private var runs: [SyntaxRun] = []
        private var pending = ""
        private var pendingKind: TokenKind = .plain

        mutating func append(_ text: String, _ kind: TokenKind) {
            guard !text.isEmpty else { return }
            if kind == pendingKind {
                pending += text
            } else {
                flush()
                pending = text
                pendingKind = kind
            }
        }

        private mutating func flush() {
            guard !pending.isEmpty else { return }
            runs.append(SyntaxRun(text: pending, kind: pendingKind))
            pending = ""
        }

        mutating func finish() -> [SyntaxRun] {
            flush()
            return runs
        }
    }
}
