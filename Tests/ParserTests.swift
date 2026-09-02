import XCTest
import Markdown
@testable import ReadmeLens

final class ParserTests: XCTestCase {

    private func blocks(_ source: String) -> [RenderBlock] {
        BlockFlattener.blocks(from: Document(parsing: source))
    }

    func testHeadingLevelAndAnchor() {
        guard case let .heading(level, text, anchor)? = blocks("## Getting Started").first?.kind else {
            return XCTFail("expected a heading")
        }
        XCTAssertEqual(level, 2)
        XCTAssertEqual(text.plain, "Getting Started")
        XCTAssertEqual(anchor, "getting-started")
    }

    func testDuplicateHeadingsGetUniqueAnchors() {
        let anchors = blocks("# Setup\n\n# Setup").compactMap { block -> String? in
            if case let .heading(_, _, anchor) = block.kind { return anchor }
            return nil
        }
        XCTAssertEqual(anchors, ["setup", "setup-1"])
    }

    func testInlineStylesAreInherited() {
        guard case let .paragraph(text)? = blocks("**bold _both_**").first?.kind else {
            return XCTFail("expected a paragraph")
        }
        let both = text.spans.first { $0.text == "both" }
        XCTAssertEqual(both?.style, [.bold, .italic])
    }

    func testAlertIsLiftedOutOfBlockQuote() {
        guard case let .alert(kind, inner)? = blocks("> [!WARNING]\n> Be careful.").first?.kind else {
            return XCTFail("expected an alert")
        }
        XCTAssertEqual(kind, .warning)
        guard case let .paragraph(text)? = inner.first?.kind else {
            return XCTFail("expected alert body")
        }
        XCTAssertEqual(text.plain, "Be careful.")
    }

    func testPlainQuoteStaysAQuote() {
        guard case .quote? = blocks("> just a quote").first?.kind else {
            return XCTFail("expected a quote")
        }
    }

    func testMermaidFenceIsItsOwnBlock() {
        guard case let .mermaid(source)? = blocks("```mermaid\ngraph TD;\nA-->B;\n```").first?.kind else {
            return XCTFail("expected a mermaid block")
        }
        XCTAssertTrue(source.contains("graph TD"))
    }

    func testTaskListCheckboxes() {
        guard case let .list(model)? = blocks("- [x] done\n- [ ] todo").first?.kind else {
            return XCTFail("expected a list")
        }
        XCTAssertEqual(model.items.map(\.checked), [true, false])
    }

    func testTableAlignmentsAndCells() {
        let source = """
        | A | B |
        |:--|--:|
        | 1 | 2 |
        """
        guard case let .table(model)? = blocks(source).first?.kind else {
            return XCTFail("expected a table")
        }
        XCTAssertEqual(model.alignments, [.leading, .trailing])
        XCTAssertEqual(model.header.map(\.plain), ["A", "B"])
        XCTAssertEqual(model.rows.first?.map(\.plain), ["1", "2"])
    }

    func testStandaloneImageBecomesImageBlock() {
        guard case let .image(model)? = blocks("![logo](https://example.com/a.png)").first?.kind else {
            return XCTFail("expected an image block")
        }
        XCTAssertEqual(model.alt, "logo")
    }

    func testBlockIDsAreUnique() {
        let ids = blocks("# A\n\ntext\n\n- one\n- two\n\n> quote").map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
