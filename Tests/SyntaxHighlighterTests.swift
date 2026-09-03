import XCTest
@testable import ReadmeLens

final class SyntaxHighlighterTests: XCTestCase {

    private func runs(_ source: String, _ language: String?) -> [SyntaxRun] {
        SyntaxHighlighter.runs(for: source, language: language)
    }

    private func kind(of needle: String, in source: String, _ language: String?) -> TokenKind? {
        runs(source, language).first { $0.text.contains(needle) }?.kind
    }

    /// The single most important property: colouring must never alter, drop or
    /// reorder a character of the user's code.
    func testRunsReconstructTheSourceExactly() {
        let samples: [(String, String)] = [
            ("swift", "let x = \"hi\" // note\nfunc f(a: Int) -> Bool { return a > 1 }"),
            ("python", "def f(x):\n    # comment\n    return {'a': 1.5e3}"),
            ("bash", "#!/bin/bash\necho \"hello\" | grep -o 'x' # done"),
            ("json", "{\"a\": [1, 2, true], \"b\": null}"),
            ("html", "<div class=\"a\"><!-- c --><img src='x'/></div>"),
            ("sql", "SELECT * FROM t WHERE a = 'b' -- note"),
            ("css", ".a { color: #fff; /* c */ }"),
            ("rust", "fn main() { let v: Vec<u8> = vec![0x1F, 0b1010]; }"),
            ("yaml", "key: value # comment\nlist:\n  - 1"),
        ]
        for (language, source) in samples {
            let joined = runs(source, language).map(\.text).joined()
            XCTAssertEqual(joined, source, "round-trip failed for \(language)")
        }
    }

    func testRunsAreNeverEmpty() {
        for run in runs("let a = 1", "swift") {
            XCTAssertFalse(run.text.isEmpty)
        }
    }

    // MARK: Kinds

    func testSwiftKeywordsStringsAndComments() {
        let source = "func greet() { let name = \"world\" } // done"
        XCTAssertEqual(kind(of: "func", in: source, "swift"), .keyword)
        XCTAssertEqual(kind(of: "\"world\"", in: source, "swift"), .string)
        XCTAssertEqual(kind(of: "// done", in: source, "swift"), .comment)
        XCTAssertEqual(kind(of: "greet", in: source, "swift"), .function)
    }

    func testNumbersIncludingHexAndFloat() {
        XCTAssertEqual(kind(of: "0xFF", in: "let a = 0xFF", "swift"), .number)
        XCTAssertEqual(kind(of: "1.5", in: "let a = 1.5", "swift"), .number)
        XCTAssertEqual(kind(of: "1e10", in: "let a = 1e10", "swift"), .number)
    }

    func testBlockCommentsSpanLines() {
        let source = "/* one\ntwo */ let a = 1"
        XCTAssertEqual(kind(of: "two", in: source, "swift"), .comment)
    }

    func testHashCommentsInPythonAndShell() {
        XCTAssertEqual(kind(of: "# note", in: "x = 1 # note", "python"), .comment)
        XCTAssertEqual(kind(of: "# note", in: "ls # note", "bash"), .comment)
    }

    func testSQLKeywordsAreCaseInsensitive() {
        XCTAssertEqual(kind(of: "select", in: "select 1", "sql"), .keyword)
        XCTAssertEqual(kind(of: "SELECT", in: "SELECT 1", "sql"), .keyword)
    }

    func testJSONKeysAreAttributes() {
        XCTAssertEqual(kind(of: "\"name\"", in: "{\"name\": 1}", "json"), .attribute)
    }

    func testMarkupTagsAndAttributes() {
        let source = "<img src=\"a.png\" alt='b'>"
        XCTAssertEqual(kind(of: "img", in: source, "html"), .keyword)
        XCTAssertEqual(kind(of: "src", in: source, "html"), .attribute)
        XCTAssertEqual(kind(of: "\"a.png\"", in: source, "html"), .string)
    }

    func testHTMLCommentsAreComments() {
        XCTAssertEqual(kind(of: "hidden", in: "<!-- hidden --><p>x</p>", "html"), .comment)
    }

    // MARK: Robustness

    /// An unterminated string must not colour the rest of the block.
    func testUnterminatedSingleLineStringStopsAtTheNewline() {
        let source = "let a = \"oops\nlet b = 1"
        let result = runs(source, "swift")
        XCTAssertEqual(result.map(\.text).joined(), source)

        // The string run must end at the newline rather than running on.
        let stringRun = result.first { $0.kind == .string }
        XCTAssertNotNil(stringRun)
        XCTAssertFalse(stringRun?.text.contains("\n") ?? true)
        XCTAssertFalse(stringRun?.text.contains("let b") ?? true)
    }

    func testUnterminatedBlockCommentDoesNotCrash() {
        let source = "/* never closed\nstill going"
        XCTAssertEqual(runs(source, "swift").map(\.text).joined(), source)
    }

    func testUnknownLanguageYieldsOnePlainRun() {
        let result = runs("whatever this is", "brainfuck")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .plain)
    }

    func testNoLanguageYieldsOnePlainRun() {
        XCTAssertEqual(runs("plain text", nil).first?.kind, .plain)
    }

    func testEmptySourceIsHandled() {
        XCTAssertEqual(runs("", "swift").map(\.text).joined(), "")
    }

    func testCanHighlightReportsSupport() {
        XCTAssertTrue(SyntaxHighlighter.canHighlight("swift"))
        XCTAssertTrue(SyntaxHighlighter.canHighlight("TypeScript"))
        XCTAssertFalse(SyntaxHighlighter.canHighlight("mermaid"))
        XCTAssertFalse(SyntaxHighlighter.canHighlight(nil))
    }

    /// Every kind the highlighter can emit must have a colour in every theme,
    /// or some token would render invisible.
    func testEveryEmittedKindIsThemeable() {
        let source = """
        // comment
        func demo(value: Int) -> String {
            let text = "x"
            return text
        }
        """
        let kinds = Set(runs(source, "swift").map(\.kind))
        for theme in Theme.builtins {
            for kind in kinds {
                XCTAssertNotNil(theme.syntax[kind], "\(theme.name) missing .\(kind.rawValue)")
            }
        }
    }
}
