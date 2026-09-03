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

    // MARK: Several documents at once

    func testOpeningSeveralFilesMakesThemOneTrail() throws {
        let a = try write("# A", to: "a.md")
        let b = try write("# B", to: "b.md")
        let c = try write("# C", to: "c.md")

        let model = DocumentModel()
        model.open([a, b, c])

        XCTAssertEqual(model.url?.lastPathComponent, "a.md")
        XCTAssertEqual(model.trailPosition, "1 of 3")
        XCTAssertFalse(model.canGoBack)
        XCTAssertTrue(model.canGoForward)

        model.goForward()
        XCTAssertEqual(model.url?.lastPathComponent, "b.md")
        XCTAssertEqual(model.trailPosition, "2 of 3")
        XCTAssertTrue(model.canGoBack)

        model.goForward()
        XCTAssertEqual(model.url?.lastPathComponent, "c.md")
        XCTAssertFalse(model.canGoForward)

        model.goBack()
        model.goBack()
        XCTAssertEqual(model.url?.lastPathComponent, "a.md")
        XCTAssertFalse(model.canGoBack)
    }

    /// A Finder selection can include anything; only Markdown belongs in the
    /// trail.
    func testNonMarkdownFilesAreFilteredOut() throws {
        let a = try write("# A", to: "a.md")
        let image = try write("not markdown", to: "picture.png")
        let b = try write("# B", to: "b.markdown")

        let model = DocumentModel()
        model.open([a, image, b])
        XCTAssertEqual(model.trail.map(\.lastPathComponent), ["a.md", "b.markdown"])
        XCTAssertEqual(model.trailPosition, "1 of 2")
        XCTAssertEqual(model.url?.lastPathComponent, "a.md")
    }

    func testSingleDocumentShowsNoPositionIndicator() throws {
        let a = try write("# A", to: "a.md")
        let model = DocumentModel()
        model.open([a])
        XCTAssertNil(model.trailPosition)
    }

    /// Following a link partway through a set replaces what was ahead, the way
    /// a browser does.
    func testFollowingALinkMidTrailReplacesWhatIsAhead() throws {
        let a = try write("# A", to: "a.md")
        let b = try write("# B", to: "b.md")
        let c = try write("# C", to: "c.md")
        let linked = try write("# Linked", to: "linked.md")

        let model = DocumentModel()
        model.open([a, b, c])
        model.goForward()                     // now on b
        model.open(linked)                    // follow a link

        XCTAssertEqual(model.url?.lastPathComponent, "linked.md")
        XCTAssertFalse(model.canGoForward)
        XCTAssertEqual(model.trail.map(\.lastPathComponent), ["a.md", "b.md", "linked.md"])

        model.goBack()
        XCTAssertEqual(model.url?.lastPathComponent, "b.md")
    }

    func testEmptySelectionIsIgnored() {
        let model = DocumentModel()
        model.open([URL]())
        XCTAssertNil(model.url)
        XCTAssertNil(model.trailPosition)
    }

    func testReopeningTheSameDocumentDoesNotGrowHistory() throws {
        let model = try openedDocument()
        let same = model.url!
        model.open(same)
        XCTAssertFalse(model.canGoBack)
    }
}
