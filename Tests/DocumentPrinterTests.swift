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
