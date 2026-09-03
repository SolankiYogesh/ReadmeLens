import XCTest
@testable import ReadmeLens

@MainActor
final class NavigationTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("readmelens-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ contents: String, to name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func openedDocument(_ markdown: String = "# Test") throws -> DocumentModel {
        let url = try write(markdown, to: "README.md")
        let model = DocumentModel()
        model.open(url)
        return model
    }

    // MARK: Anchors

    func testAnchorBecomesTheInternalScheme() throws {
        let model = try openedDocument()
        let url = model.resolveLinkURL("#the-last-section")
        XCTAssertEqual(url?.scheme, DocumentModel.anchorScheme)
        XCTAssertEqual(url?.host, "the-last-section")
    }

    func testEmptyAnchorIsRejected() throws {
        XCTAssertNil(try openedDocument().resolveLinkURL("#"))
    }

    func testAnchorFragmentIsExtractedFromAPath() throws {
        let model = try openedDocument()
        XCTAssertEqual(model.anchorFragment(of: "docs/api.md#usage"), "usage")
        XCTAssertNil(model.anchorFragment(of: "docs/api.md"))
    }

    func testHeadingScrollIDUsesItsAnchor() {
        let heading = RenderBlock(
            id: 3, kind: .heading(level: 2, text: .empty, anchor: "install")
        )
        XCTAssertEqual(heading.scrollID, "#install")
        XCTAssertEqual(RenderBlock(id: 3, kind: .rule).scrollID, "b3")
    }

    // MARK: Link resolution

    func testAbsoluteLinksPassThrough() throws {
        let model = try openedDocument()
        XCTAssertEqual(model.resolveLinkURL("https://example.com")?.host, "example.com")
        XCTAssertEqual(model.resolveLinkURL("mailto:a@b.com")?.scheme, "mailto")
    }

    func testDangerousSchemesAreRefused() throws {
        let model = try openedDocument()
        XCTAssertNil(model.resolveLinkURL("javascript:alert(1)"))
        XCTAssertNil(model.resolveLinkURL("data:text/html,<script>"))
    }

    func testRelativeLinkResolvesAgainstTheDocumentFolder() throws {
        _ = try write("# Guide", to: "GUIDE.md")
        let model = try openedDocument()
        let resolved = model.resolveLinkURL("GUIDE.md")
        XCTAssertEqual(resolved?.lastPathComponent, "GUIDE.md")
        XCTAssertTrue(resolved?.isFileURL ?? false)
    }

    func testRelativeLinkWithFragmentDropsTheFragmentFromThePath() throws {
        _ = try write("# Guide", to: "GUIDE.md")
        let model = try openedDocument()
        XCTAssertEqual(model.resolveLinkURL("GUIDE.md#usage")?.lastPathComponent, "GUIDE.md")
    }

    /// A document must not be able to reach outside its own folder.
    func testPathTraversalIsRefused() throws {
        let model = try openedDocument()
        XCTAssertNil(model.resolveLinkURL("../../../etc/passwd"))
        XCTAssertNil(model.resolveImageURL("../secrets.png"))
    }

    func testRelativeImageResolvesAgainstTheDocumentFolder() throws {
        let model = try openedDocument()
        XCTAssertEqual(model.resolveImageURL("assets/logo.png")?.lastPathComponent, "logo.png")
    }

    // MARK: History

    func testHistoryTracksBackAndForward() throws {
        let guide = try write("# Guide", to: "GUIDE.md")
        let model = try openedDocument()
        XCTAssertFalse(model.canGoBack)
        XCTAssertFalse(model.canGoForward)

        model.open(guide)
        XCTAssertEqual(model.url?.lastPathComponent, "GUIDE.md")
        XCTAssertTrue(model.canGoBack)
        XCTAssertFalse(model.canGoForward)

        model.goBack()
        XCTAssertEqual(model.url?.lastPathComponent, "README.md")
        XCTAssertFalse(model.canGoBack)
        XCTAssertTrue(model.canGoForward)

        model.goForward()
        XCTAssertEqual(model.url?.lastPathComponent, "GUIDE.md")
        XCTAssertTrue(model.canGoBack)
        XCTAssertFalse(model.canGoForward)
    }

    func testOpeningANewDocumentClearsTheForwardStack() throws {
        let guide = try write("# Guide", to: "GUIDE.md")
        let notes = try write("# Notes", to: "NOTES.md")
        let model = try openedDocument()

        model.open(guide)
        model.goBack()
        XCTAssertTrue(model.canGoForward)

        model.open(notes)
        XCTAssertFalse(model.canGoForward)
    }

    func testReopeningTheSameDocumentDoesNotGrowHistory() throws {
        let model = try openedDocument()
        let same = model.url!
        model.open(same)
        XCTAssertFalse(model.canGoBack)
    }
}
