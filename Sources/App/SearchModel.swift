import SwiftUI

/// One occurrence of the query in the document.
struct SearchMatch: Hashable {
    /// Top-level block to scroll to. Nested blocks are not rows in the
    /// scrolling list, so they cannot be addressed directly.
    let scrollID: String
    /// The specific block whose text matched, used to place the highlight.
    let blockID: Int
    /// Offsets into that block's plain text.
    let range: Range<Int>
}

/// Find-in-document: matching, navigation and the highlight map.
@MainActor
final class SearchModel: ObservableObject {

    @Published var isActive = false
    @Published var query = "" {
        didSet { if query != oldValue { recompute() } }
    }
    @Published private(set) var matches: [SearchMatch] = []
    @Published private(set) var currentIndex = 0

    /// Set when navigation should move the view; the document view consumes it.
    @Published var pendingScroll: String?

    private var blocks: [RenderBlock] = []

    var currentMatch: SearchMatch? {
        matches.indices.contains(currentIndex) ? matches[currentIndex] : nil
    }

    var summary: String {
        if query.isEmpty { return "" }
        if matches.isEmpty { return "No results" }
        return "\(currentIndex + 1) of \(matches.count)"
    }

    /// Ranges to highlight, keyed by block id.
    private(set) var highlights: [Int: [Range<Int>]] = [:]

    func highlightRanges(for blockID: Int) -> [Range<Int>] {
        highlights[blockID] ?? []
    }

    func isCurrent(blockID: Int, range: Range<Int>) -> Bool {
        guard let current = currentMatch else { return false }
        return current.blockID == blockID && current.range == range
    }

    // MARK: - Lifecycle

    func documentChanged(to blocks: [RenderBlock]) {
        self.blocks = blocks
        recompute()
    }

    /// Bumped whenever the find bar should take focus, including when ⌘F is
    /// pressed while it is already open.
    @Published private(set) var focusToken = 0

    func open() {
        isActive = true
        focusToken += 1
    }

    func close() {
        isActive = false
        query = ""
    }

    func next() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex + 1) % matches.count
        requestScroll()
    }

    func previous() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex - 1 + matches.count) % matches.count
        requestScroll()
    }

    private func requestScroll() {
        pendingScroll = currentMatch?.scrollID
    }

    // MARK: - Matching

    private func recompute() {
        guard query.count >= 1 else {
            matches = []
            highlights = [:]
            currentIndex = 0
            return
        }

        var found: [SearchMatch] = []
        for block in blocks {
            collect(block, scrollID: block.scrollID, into: &found)
        }

        matches = found
        currentIndex = 0
        highlights = Dictionary(grouping: found, by: \.blockID)
            .mapValues { $0.map(\.range) }
        requestScroll()
    }

    private func collect(_ block: RenderBlock, scrollID: String, into found: inout [SearchMatch]) {
        switch block.kind {
        case let .heading(_, text, _):
            append(text.plain, block: block.id, scrollID: scrollID, into: &found)
        case let .paragraph(text):
            append(text.plain, block: block.id, scrollID: scrollID, into: &found)
        case let .code(_, source):
            append(source, block: block.id, scrollID: scrollID, into: &found)
        case let .mermaid(source):
            append(source, block: block.id, scrollID: scrollID, into: &found)

        case let .quote(inner, _), let .alert(_, inner),
             let .container(_, inner), let .disclosure(_, inner):
            for child in inner { collect(child, scrollID: scrollID, into: &found) }
        case let .list(model):
            for item in model.items {
                for child in item.blocks { collect(child, scrollID: scrollID, into: &found) }
            }
        default:
            break
        }
    }

    /// Case- and diacritic-insensitive, matching what a reader expects from a
    /// find bar rather than an exact byte comparison.
    private func append(
        _ haystack: String, block: Int, scrollID: String, into found: inout [SearchMatch]
    ) {
        guard !haystack.isEmpty else { return }
        let characters = Array(haystack)
        var searchStart = haystack.startIndex

        while searchStart < haystack.endIndex,
              let range = haystack.range(
                  of: query,
                  options: [.caseInsensitive, .diacriticInsensitive],
                  range: searchStart..<haystack.endIndex
              ) {
            let start = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            let end = haystack.distance(from: haystack.startIndex, to: range.upperBound)
            if start < end, end <= characters.count {
                found.append(SearchMatch(scrollID: scrollID, blockID: block, range: start..<end))
            }
            searchStart = range.upperBound > searchStart ? range.upperBound
                : haystack.index(after: searchStart)
        }
    }
}

// MARK: - Environment

/// Identifies which block a text view belongs to, so it can find its own
/// highlight ranges without every view being handed the whole map.
private struct BlockIDKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var searchBlockID: Int? {
        get { self[BlockIDKey.self] }
        set { self[BlockIDKey.self] = newValue }
    }
}

// MARK: - Highlight snapshot

/// The highlight state every run of text needs, as a value.
///
/// Text views must not observe `SearchModel` directly: there is one of them per
/// paragraph, list item and table cell, so subscribing them all would mean any
/// publish on the model rebuilds the entire document. This snapshot is
/// `Equatable` and empty while the find bar is closed, so in the common case it
/// never changes and never invalidates anything.
struct SearchHighlight: Equatable {
    var ranges: [Int: [Range<Int>]] = [:]
    var current: SearchMatch?

    static let inactive = SearchHighlight()

    var isEmpty: Bool { ranges.isEmpty }

    func ranges(for blockID: Int?) -> [Range<Int>] {
        guard let blockID else { return [] }
        return ranges[blockID] ?? []
    }

    /// The range being stepped to, if it falls in this block.
    func currentRange(for blockID: Int?) -> Range<Int>? {
        guard let blockID, let current, current.blockID == blockID else { return nil }
        return current.range
    }
}

extension SearchModel {
    /// Snapshot for the environment. Empty unless the find bar is open with
    /// hits, which keeps the value stable — and the document static — the rest
    /// of the time.
    var highlight: SearchHighlight {
        guard isActive, !highlights.isEmpty else { return .inactive }
        return SearchHighlight(ranges: highlights, current: currentMatch)
    }
}

private struct SearchHighlightKey: EnvironmentKey {
    static let defaultValue = SearchHighlight.inactive
}

extension EnvironmentValues {
    var searchHighlight: SearchHighlight {
        get { self[SearchHighlightKey.self] }
        set { self[SearchHighlightKey.self] = newValue }
    }
}
