import XCTest
import Markdown
@testable import ReadmeLens

final class OutlineTests: XCTestCase {

    private func outline(_ source: String) -> [OutlineEntry] {
        BlockFlattener.blocks(from: Document(parsing: source)).outline
    }

    func testHeadingsAreCollectedInOrder() {
        let entries = outline("# One\n\ntext\n\n## Two\n\n### Three")
        XCTAssertEqual(entries.map(\.title), ["One", "Two", "Three"])
        XCTAssertEqual(entries.map(\.level), [1, 2, 3])
    }

    func testEntryIDMatchesTheHeadingScrollID() {
        let source = "## Getting Started"
        let blocks = BlockFlattener.blocks(from: Document(parsing: source))
        XCTAssertEqual(blocks.outline.first?.id, blocks.first?.scrollID)
        XCTAssertEqual(blocks.outline.first?.anchor, "getting-started")
    }

    /// A centred header block is still part of the document's structure.
    func testHeadingsInsideHTMLContainersAreIncluded() {
        let source = """
        <div align="center">

        # Centred Title

        </div>

        ## After
        """
        XCTAssertEqual(outline(source).map(\.title), ["Centred Title", "After"])
    }

    func testHeadingsInsideDisclosureAreIncluded() {
        let source = """
        <details>
        <summary>More</summary>

        ### Hidden Heading

        </details>
        """
        XCTAssertEqual(outline(source).map(\.title), ["Hidden Heading"])
    }

    func testDocumentWithoutHeadingsYieldsEmptyOutline() {
        XCTAssertTrue(outline("just a paragraph").isEmpty)
    }

    /// READMEs often start at `##` or skip levels; indentation should reflect
    /// the levels actually used rather than raw heading depth.
    func testIndentationCompactsUnusedLevels() {
        let entries = outline("## A\n\n#### B\n\n## C")
        let depths = entries.indentationDepths
        XCTAssertEqual(depths[entries[0].id], 0)
        XCTAssertEqual(depths[entries[1].id], 1)
        XCTAssertEqual(depths[entries[2].id], 0)
    }
}

@MainActor
final class SearchModelTests: XCTestCase {

    private func model(_ source: String, query: String) -> SearchModel {
        let search = SearchModel()
        search.isActive = true
        search.documentChanged(to: BlockFlattener.blocks(from: Document(parsing: source)))
        search.query = query
        return search
    }

    func testFindsEveryOccurrence() {
        let search = model("alpha beta alpha\n\nalpha again", query: "alpha")
        XCTAssertEqual(search.matches.count, 3)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(model("Alpha ALPHA alpha", query: "alpha").matches.count, 3)
    }

    func testEmptyQueryClearsMatches() {
        let search = model("alpha", query: "alpha")
        XCTAssertFalse(search.matches.isEmpty)
        search.query = ""
        XCTAssertTrue(search.matches.isEmpty)
        XCTAssertEqual(search.summary, "")
    }

    func testSummaryCountsPosition() {
        let search = model("a a a", query: "a")
        XCTAssertEqual(search.summary, "1 of 3")
        search.next()
        XCTAssertEqual(search.summary, "2 of 3")
    }

    func testNoResultsSummary() {
        XCTAssertEqual(model("hello", query: "zzz").summary, "No results")
    }

    func testNavigationWrapsBothWays() {
        let search = model("a a a", query: "a")
        search.previous()
        XCTAssertEqual(search.summary, "3 of 3")
        search.next()
        XCTAssertEqual(search.summary, "1 of 3")
    }

    func testCodeBlocksAreSearched() {
        let search = model("```swift\nlet needle = 1\n```", query: "needle")
        XCTAssertEqual(search.matches.count, 1)
    }

    func testHighlightRangesAreExposedPerBlock() {
        let search = model("needle here", query: "needle")
        guard let match = search.currentMatch else { return XCTFail("no match") }
        XCTAssertEqual(search.highlightRanges(for: match.blockID), [0..<6])
        XCTAssertTrue(search.isCurrent(blockID: match.blockID, range: 0..<6))
    }

    /// Nested blocks are not rows in the scrolling list, so a match inside one
    /// must scroll to its top-level ancestor.
    func testNestedMatchScrollsToTopLevelAncestor() {
        let source = "> quoted needle"
        let blocks = BlockFlattener.blocks(from: Document(parsing: source))
        let search = SearchModel()
        search.isActive = true
        search.documentChanged(to: blocks)
        search.query = "needle"

        guard let match = search.matches.first else { return XCTFail("no match") }
        XCTAssertEqual(match.scrollID, blocks.first?.scrollID)
        XCTAssertNotEqual(match.blockID, blocks.first?.id)
    }

    func testOverlappingQueryDoesNotLoop() {
        // "aa" in "aaaa" must terminate rather than spin.
        XCTAssertEqual(model("aaaa", query: "aa").matches.count, 2)
    }
}

final class HighlightSplitterTests: XCTestCase {

    private func texts(_ segments: [HighlightSplitter.Segment]) -> [String] {
        segments.map(\.text)
    }

    func testNoRangesYieldsTheWholePiece() {
        let segments = HighlightSplitter.segments(
            text: "hello", offset: 0, ranges: [], current: nil
        )
        XCTAssertEqual(texts(segments), ["hello"])
        XCTAssertFalse(segments[0].isHighlighted)
    }

    func testSplitsAroundAMatch() {
        let segments = HighlightSplitter.segments(
            text: "a needle b", offset: 0, ranges: [2..<8], current: nil
        )
        XCTAssertEqual(texts(segments), ["a ", "needle", " b"])
        XCTAssertEqual(segments.map(\.isHighlighted), [false, true, false])
    }

    /// Pieces start partway through the block, so offsets must be respected.
    func testHonoursThePieceOffset() {
        let segments = HighlightSplitter.segments(
            text: "needle", offset: 10, ranges: [10..<16], current: nil
        )
        XCTAssertEqual(texts(segments), ["needle"])
        XCTAssertTrue(segments[0].isHighlighted)
    }

    func testIgnoresRangesOutsideThePiece() {
        let segments = HighlightSplitter.segments(
            text: "abc", offset: 0, ranges: [50..<60], current: nil
        )
        XCTAssertEqual(texts(segments), ["abc"])
        XCTAssertFalse(segments[0].isHighlighted)
    }

    /// A match spanning two styled spans must highlight the part in each.
    func testClipsAMatchThatStraddlesPieces() {
        let first = HighlightSplitter.segments(
            text: "nee", offset: 0, ranges: [0..<6], current: nil
        )
        let second = HighlightSplitter.segments(
            text: "dle", offset: 3, ranges: [0..<6], current: nil
        )
        XCTAssertEqual(texts(first), ["nee"])
        XCTAssertTrue(first[0].isHighlighted)
        XCTAssertEqual(texts(second), ["dle"])
        XCTAssertTrue(second[0].isHighlighted)
    }

    func testMarksTheCurrentMatch() {
        let segments = HighlightSplitter.segments(
            text: "a b a", offset: 0, ranges: [0..<1, 4..<5], current: 4..<5
        )
        let highlighted = segments.filter(\.isHighlighted)
        XCTAssertEqual(highlighted.count, 2)
        XCTAssertEqual(highlighted.map(\.isCurrent), [false, true])
    }

    /// Every split must preserve the original text exactly.
    func testSegmentsAlwaysReconstructTheInput() {
        let text = "the needle in the haystack needle"
        for ranges in [[4..<10], [4..<10, 27..<33], [0..<3], [30..<33]] {
            let joined = HighlightSplitter
                .segments(text: text, offset: 0, ranges: ranges, current: nil)
                .map(\.text).joined()
            XCTAssertEqual(joined, text)
        }
    }
}
