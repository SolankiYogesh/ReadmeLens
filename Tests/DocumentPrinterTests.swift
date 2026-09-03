import XCTest
import PDFKit
import Markdown
@testable import ReadmeLens

@MainActor
final class DocumentPrinterTests: XCTestCase {

    private func pdf(for markdown: String) -> PDFDocument? {
        let blocks = BlockFlattener.blocks(from: Document(parsing: markdown))
        guard let data = DocumentPrinter.makePDF(
            blocks: blocks,
            theme: .githubDark,
            typography: .default,
            document: DocumentModel(),
            search: SearchModel()
        ) else { return nil }
        return PDFDocument(data: data)
    }

    func testEmptyDocumentProducesNoPDF() {
        XCTAssertNil(DocumentPrinter.makePDF(
            blocks: [], theme: .githubDark, typography: .default,
            document: DocumentModel(), search: SearchModel()
        ))
    }

    func testProducesAPDFWithContent() throws {
        let document = try XCTUnwrap(pdf(for: "# Title\n\nA paragraph of body text."))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)

        // Blank pages were the original failure mode: NSHostingView paginates
        // but draws nothing, so page count alone proves nothing.
        let text = document.page(at: 0)?.string ?? ""
        XCTAssertTrue(text.contains("Title"), "page 1 text was: \(text)")
        XCTAssertTrue(text.contains("paragraph"), "page 1 text was: \(text)")
    }

    func testLongDocumentPaginatesAcrossPages() throws {
        let body = (1...60).map { "## Section \($0)\n\nBody text for section \($0)." }
            .joined(separator: "\n\n")
        let document = try XCTUnwrap(pdf(for: body))
        XCTAssertGreaterThan(document.pageCount, 1)
    }

    /// Page order is easy to invert when flipping coordinates; the first page
    /// must be the start of the document.
    func testFirstPageIsTheStartOfTheDocument() throws {
        let body = (1...60).map { "## Section \($0)\n\nBody for section \($0)." }
            .joined(separator: "\n\n")
        let document = try XCTUnwrap(pdf(for: body))

        let first = document.page(at: 0)?.string ?? ""
        let last = document.page(at: document.pageCount - 1)?.string ?? ""
        XCTAssertTrue(first.contains("Section 1"), "first page was: \(first.prefix(120))")
        XCTAssertFalse(first.contains("Section 60"))
        XCTAssertTrue(last.contains("Section 60"), "last page was: \(last.prefix(120))")
    }

    func testPagesAreLetterSized() throws {
        let document = try XCTUnwrap(pdf(for: "# Title"))
        let bounds = try XCTUnwrap(document.page(at: 0)?.bounds(for: .mediaBox))
        XCTAssertEqual(bounds.width, 612, accuracy: 1)
        XCTAssertEqual(bounds.height, 792, accuracy: 1)
    }

    /// Views that scroll on screen — code blocks and tables — render empty
    /// under ImageRenderer unless the print path lays them out plainly. A
    /// document made mostly of code printed as blank pages because of it.
    func testCodeBlockContentActuallyPrints() throws {
        let code = (1...80).map { "let value\($0) = compute(\($0))  // step \($0)" }
            .joined(separator: "\n")
        let document = try XCTUnwrap(pdf(for: "```swift\n\(code)\n```"))

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined()
        XCTAssertTrue(text.contains("value1"), "code block body missing from the PDF")
        XCTAssertTrue(text.contains("value80"), "later code lines missing from the PDF")
    }

    /// The failing document was a single enormous fenced block, so the very
    /// first page carrying only the language tag was the visible symptom.
    func testFirstPageOfACodeOnlyDocumentIsNotJustTheLanguageTag() throws {
        let code = (1...80).map { "line\($0)()" }.joined(separator: "\n")
        let document = try XCTUnwrap(pdf(for: "```ts\n\(code)\n```"))
        let first = (document.page(at: 0)?.string ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertGreaterThan(first.count, 20, "page 1 held only: \(first)")
        XCTAssertTrue(first.contains("line1"), "page 1 held only: \(first)")
    }

    func testTableContentActuallyPrints() throws {
        let source = """
        | Feature | Status |
        |:--------|:------:|
        | Alpha   | Done   |
        | Bravo   | Ready  |
        """
        let document = try XCTUnwrap(pdf(for: source))
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined()
        XCTAssertTrue(text.contains("Alpha"), "table body missing from the PDF")
        XCTAssertTrue(text.contains("Bravo"), "table body missing from the PDF")
    }

    /// A dark reading theme must not print as a dark page.
    func testDarkThemesPrintOnALightGround() throws {
        let blocks = BlockFlattener.blocks(from: Document(parsing: "# Title"))
        for theme in [Theme.githubDark, .dracula, .tokyoNight] {
            let data = DocumentPrinter.makePDF(
                blocks: blocks, theme: theme, typography: .default,
                document: DocumentModel(), search: SearchModel()
            )
            XCTAssertNotNil(data, "\(theme.name) produced no PDF")
        }
    }
}
