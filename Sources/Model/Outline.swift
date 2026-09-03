import Foundation

/// One heading in the table of contents.
struct OutlineEntry: Identifiable, Hashable {
    /// Matches the heading block's `scrollID`, so selecting an entry can
    /// address it directly.
    let id: String
    let anchor: String
    let title: String
    let level: Int
}

extension Array where Element == RenderBlock {

    /// Every heading in document order, including headings nested inside HTML
    /// containers and disclosure sections — a centred `<div>` header is still
    /// part of the outline.
    var outline: [OutlineEntry] {
        var entries: [OutlineEntry] = []
        collectHeadings(into: &entries)
        return entries
    }

    private func collectHeadings(into entries: inout [OutlineEntry]) {
        for block in self {
            switch block.kind {
            case let .heading(level, text, anchor):
                let title = text.plain.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    entries.append(
                        OutlineEntry(id: block.scrollID, anchor: anchor, title: title, level: level)
                    )
                }
            case let .container(_, inner), let .disclosure(_, inner):
                inner.collectHeadings(into: &entries)
            case let .quote(inner, _), let .alert(_, inner):
                inner.collectHeadings(into: &entries)
            case let .list(model):
                for item in model.items { item.blocks.collectHeadings(into: &entries) }
            default:
                break
            }
        }
    }
}

/// Normalises heading levels so the sidebar indents sensibly.
///
/// Many READMEs start at `##`, or skip from `#` straight to `###`. Indenting by
/// raw level would leave the whole outline pushed to the right, or full of
/// gaps, so levels are compacted to the ones actually used.
extension Array where Element == OutlineEntry {
    var indentationDepths: [String: Int] {
        let levels = Set(map(\.level)).sorted()
        let rank = Dictionary(uniqueKeysWithValues: levels.enumerated().map { ($1, $0) })
        return Dictionary(uniqueKeysWithValues: map { ($0.id, rank[$0.level] ?? 0) })
    }
}
