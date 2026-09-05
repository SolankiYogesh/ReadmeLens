import XCTest
import Combine
import SwiftUI
import Markdown
@testable import ReadmeLens

/// Guards the cost of a table-heavy document.
///
/// A real 40 KB reference file scrolled badly despite being small. The cause
/// was not size: it was that every run of text observed `DocumentModel`, so
/// moving the scroll cursor — which happens on every frame — invalidated all of
/// them and rebuilt every `AttributedString` in the document. These tests pin
/// down how much work one such pass is, so it stays clear why it must not run
/// per frame.
@MainActor
final class RenderPerformanceTests: XCTestCase {

    /// Same shape as the file that triggered this: 15 tables, ~1,800 cells,
    /// with long prose in the cells.
    private func tableHeavyMarkdown() -> String {
        var out = ["# Reference\n"]
        for table in 1...15 {
            out.append("## Section \(table)\n")
            out.append("| Company | Role | Notes | Match | Status | Source |")
            out.append("|---|---|---|---|---|---|")
            for row in 1...25 {
                let notes = "A **reasonably** long note about row \(row) of table \(table) "
                    + "that runs well past the width of a single column and would "
                    + "otherwise lay out as one very long unwrapped line."
                out.append(
                    "| Company \(row) | Senior Engineer | \(notes) | \(row * 3) "
                    + "| Live | [link](https://example.com) |"
                )
            }
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    private func parse(_ markdown: String) -> [RenderBlock] {
        BlockFlattener.blocks(from: Document(parsing: markdown))
    }

    /// Every `InlineText` in the document, tables included.
    private func allInlineText(_ blocks: [RenderBlock]) -> [InlineText] {
        var found: [InlineText] = []
        func walk(_ list: [RenderBlock]) {
            for block in list {
                switch block.kind {
                case let .heading(_, text, _):   found.append(text)
                case let .paragraph(text):       found.append(text)
                case let .table(model):
                    found.append(contentsOf: model.header)
                    for row in model.rows { found.append(contentsOf: row) }
                case let .quote(inner, _), let .alert(_, inner),
                     let .container(_, inner), let .disclosure(_, inner):
                    walk(inner)
                case let .list(model):
                    for item in model.items { walk(item.blocks) }
                default: break
                }
            }
        }
        walk(blocks)
        return found
    }

    /// One invalidation pass over the whole document. Before the fix this ran
    /// on every scroll frame; now it runs only when the theme, zoom or search
    /// state actually changes.
    func testCostOfRebuildingEveryRunOfText() {
        let blocks = parse(tableHeavyMarkdown())
        let inlines = allInlineText(blocks)
        XCTAssertGreaterThan(inlines.count, 1500, "expected a table-heavy document")

        let links = LinkResolver(baseDirectory: nil)
        let start = Date()
        for inline in inlines {
            _ = InlineAttributedText.build(
                inline, size: 15, weight: .regular, color: nil,
                theme: .githubDark, links: links
            )
        }
        let elapsed = Date().timeIntervalSince(start)

        print(String(
            format: "[perf] rebuilding %d runs of text: %.1f ms (a 60fps frame is 16.7 ms)",
            inlines.count, elapsed * 1000
        ))
        // Not a tight benchmark — a guard that this stays the kind of work you
        // must not do per frame, and a record of why.
        XCTAssertLessThan(elapsed, 5.0)
    }

    /// The width cap is what stops a paragraph-in-a-cell becoming one long line.
    func testWideTableCellsWrapRatherThanRunOn() {
        let long = String(repeating: "word ", count: 120)
        let blocks = parse("| A | B |\n|---|---|\n| short | \(long) |")

        let table = VStack { ForEach(blocks) { BlockView(block: $0) } }
            .environment(\.theme, .githubDark)
            .environment(\.typography, .default)
            .environment(\.linkResolver, LinkResolver(baseDirectory: nil))
            .environment(\.searchHighlight, .inactive)
            // ImageRenderer cannot draw through the table's horizontal
            // ScrollView, so measure the grid directly.
            .environment(\.isPrinting, true)

        let renderer = ImageRenderer(content: table)
        renderer.scale = 1
        let size = renderer.nsImage?.size ?? .zero

        // Uncapped, 600 words on one line runs to many thousands of points.
        XCTAssertLessThan(size.width, 1400, "table did not wrap; width was \(size.width)")
        XCTAssertGreaterThan(size.height, 40, "table collapsed; height was \(size.height)")
    }

    /// Scrolling must not be able to invalidate the document body. The cursor
    /// lives on its own object precisely so that publishing it reaches only the
    /// outline sidebar.
    func testScrollCursorIsNotOnTheDocumentModel() {
        let viewport = ViewportModel()
        var documentPublishes = 0
        let document = DocumentModel()
        let token = document.objectWillChange.sink { _ in documentPublishes += 1 }
        defer { token.cancel() }

        for index in 0..<200 { viewport.topVisibleBlockID = "block-\(index)" }

        XCTAssertEqual(
            documentPublishes, 0,
            "moving the scroll cursor published on DocumentModel, which every "
            + "run of text in the document would observe"
        )
    }
}
