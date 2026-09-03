import XCTest
import Markdown
@testable import ReadmeLens

/// Covers the constructs the README corpus showed were most common: centred
/// wrapper divs, badge rows, inline formatting tags and disclosure blocks.
final class HTMLIntegrationTests: XCTestCase {

    private func blocks(_ source: String) -> [RenderBlock] {
        BlockFlattener.blocks(from: Document(parsing: source))
    }

    private func firstInline(_ source: String) -> InlineText? {
        for block in blocks(source) {
            if case let .paragraph(text) = block.kind { return text }
        }
        return nil
    }

    // MARK: Wrapper containers

    func testCentredDivWrappingMarkdownBecomesAContainer() {
        let source = """
        <div align="center">

        # Title

        Some text.

        </div>
        """
        guard case let .container(alignment, inner)? = blocks(source).first?.kind else {
            return XCTFail("expected a container")
        }
        XCTAssertEqual(alignment, .center)
        XCTAssertEqual(inner.count, 2)
        guard case .heading = inner.first?.kind else { return XCTFail("expected heading inside") }
    }

    func testNestedSameTagContainersPairCorrectly() {
        let source = """
        <div align="center">

        <div align="right">

        inner

        </div>

        outer

        </div>
        """
        guard case let .container(outerAlign, inner)? = blocks(source).first?.kind else {
            return XCTFail("expected outer container")
        }
        XCTAssertEqual(outerAlign, .center)
        guard case let .container(innerAlign, _)? = inner.first?.kind else {
            return XCTFail("expected nested container")
        }
        XCTAssertEqual(innerAlign, .right)
    }

    func testUnclosedWrapperStillRendersItsContent() {
        // A wrapper that never closes must not swallow the document.
        let source = """
        <div align="center">

        # Title
        """
        let result = blocks(source)
        XCTAssertTrue(result.contains { if case .heading = $0.kind { return true }; return false })
        XCTAssertFalse(result.contains { if case .htmlOpen = $0.kind { return true }; return false })
    }

    func testNoMarkerLeaksToTheViewLayer() {
        let source = "<div>\n\n# A\n\n</div>\n\n</span>\n\n# B"
        func assertClean(_ list: [RenderBlock]) {
            for block in list {
                switch block.kind {
                case .htmlOpen, .htmlClose:
                    XCTFail("marker leaked: \(block.kind)")
                case let .container(_, inner):
                    assertClean(inner)
                default:
                    break
                }
            }
        }
        assertClean(blocks(source))
    }

    // MARK: Disclosure

    func testDetailsWrappingMarkdownBecomesADisclosure() {
        let source = """
        <details>
        <summary>Show more</summary>

        Hidden paragraph.

        </details>
        """
        guard case let .disclosure(summary, inner)? = blocks(source).first?.kind else {
            return XCTFail("expected a disclosure")
        }
        XCTAssertEqual(summary.plainText, "Show more")
        guard case let .paragraph(text)? = inner.first?.kind else {
            return XCTFail("expected the hidden paragraph inside")
        }
        XCTAssertEqual(text.plain, "Hidden paragraph.")
    }

    /// The content must not escape the disclosure and render unconditionally.
    func testDisclosureContentDoesNotLeakToTopLevel() {
        let source = """
        <details>
        <summary>S</summary>

        secret

        </details>

        after
        """
        let top = blocks(source)
        XCTAssertEqual(top.count, 2)
        let plains = top.compactMap { block -> String? in
            if case let .paragraph(text) = block.kind { return text.plain }
            return nil
        }
        XCTAssertEqual(plains, ["after"])
    }

    func testSelfContainedDetailsStaysAnHTMLBlock() {
        guard case .html? = blocks("<details><summary>S</summary>body</details>").first?.kind else {
            return XCTFail("expected an html block")
        }
    }

    // MARK: HTML blocks

    func testLogoBlockBecomesHTMLNotACodeBlock() {
        let source = """
        <p align="center">
          <a href="https://example.com"><img src="logo.png" alt="logo" width="200"></a>
        </p>
        """
        guard case let .html(nodes)? = blocks(source).first?.kind else {
            return XCTFail("expected an html block")
        }
        guard case let .element(paragraph) = nodes[0] else { return XCTFail("expected <p>") }
        XCTAssertEqual(paragraph.tag, "p")
        XCTAssertEqual(paragraph.alignment, .center)
    }

    // MARK: Inline HTML

    func testLineBreakTagBecomesANewline() {
        XCTAssertEqual(firstInline("one<br>two")?.plain, "one\ntwo")
    }

    func testBoldTagAppliesAcrossSiblingNodes() {
        guard let text = firstInline("plain <b>bold</b> plain") else {
            return XCTFail("no paragraph")
        }
        let bold = text.spans.first { $0.text.contains("bold") }
        XCTAssertEqual(bold?.style, .bold)
        let tail = text.spans.last
        XCTAssertEqual(tail?.style, [])
    }

    func testKbdAndSubRenderWithoutShowingMarkup() {
        let text = firstInline("press <kbd>K</kbd> for H<sub>2</sub>O")?.plain ?? ""
        XCTAssertEqual(text, "press K for H2O")
        XCTAssertFalse(text.contains("<"))
    }

    func testAnchorTagBecomesALink() {
        guard let text = firstInline("see <a href=\"https://example.com\">docs</a>") else {
            return XCTFail("no paragraph")
        }
        XCTAssertEqual(text.spans.first { $0.text == "docs" }?.link, "https://example.com")
    }

    func testInlineImageFallsBackToAltText() {
        XCTAssertEqual(firstInline("badge <img src=\"b.svg\" alt=\"build\">")?.plain,
                       "badge build")
    }

    func testUnknownInlineTagIsDroppedNotPrinted() {
        let text = firstInline("hello <span class=\"x\">world</span>")?.plain ?? ""
        XCTAssertEqual(text, "hello world")
    }

    // MARK: Image URL resolution

    @MainActor
    func testRemoteImageURLPassesThrough() {
        let model = DocumentModel()
        XCTAssertEqual(
            model.resolveImageURL("https://example.com/a.png")?.absoluteString,
            "https://example.com/a.png"
        )
    }

    @MainActor
    func testUnsupportedSchemesAreRejected() {
        let model = DocumentModel()
        XCTAssertNil(model.resolveImageURL("javascript:alert(1)"))
        XCTAssertNil(model.resolveImageURL("data:image/png;base64,AAAA"))
    }

    @MainActor
    func testRelativeImageWithoutADocumentFolderIsNil() {
        let model = DocumentModel()
        XCTAssertNil(model.resolveImageURL("docs/a.png"))
    }
}
