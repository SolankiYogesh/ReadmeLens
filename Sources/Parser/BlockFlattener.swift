import Foundation
import Markdown

/// Turns a parsed document into the flat, identified block list the views render.
struct BlockFlattener {

    private var nextID = 0
    private var usedAnchors: Set<String> = []

    static func blocks(from document: Document) -> [RenderBlock] {
        var flattener = BlockFlattener()
        return flattener.convert(Array(document.children))
    }

    private mutating func claimID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private mutating func convert(_ markups: [Markup], quoteDepth: Int = 0) -> [RenderBlock] {
        markups.compactMap { convert($0, quoteDepth: quoteDepth) }
    }

    private mutating func convert(_ markup: Markup, quoteDepth: Int) -> RenderBlock? {
        switch markup {

        case let node as Heading:
            let text = InlineFlattener.flatten(node)
            return RenderBlock(
                id: claimID(),
                kind: .heading(level: node.level, text: text, anchor: claimAnchor(for: text.plain))
            )

        case let node as Paragraph:
            // A paragraph that is nothing but an image is really a figure.
            if let image = soleImage(in: node) {
                return RenderBlock(id: claimID(), kind: .image(image))
            }
            let text = InlineFlattener.flatten(node)
            return text.isEmpty ? nil : RenderBlock(id: claimID(), kind: .paragraph(text))

        case let node as CodeBlock:
            let language = node.language?.trimmingCharacters(in: .whitespaces).lowercased()
            let source = node.code.trimmingTrailingNewlines()
            if language == "mermaid" {
                return RenderBlock(id: claimID(), kind: .mermaid(source: source))
            }
            return RenderBlock(
                id: claimID(),
                kind: .code(language: (language?.isEmpty == false) ? language : nil, source: source)
            )

        case let node as BlockQuote:
            return convertQuote(node, quoteDepth: quoteDepth)

        case let node as UnorderedList:
            return RenderBlock(id: claimID(), kind: .list(listModel(node, ordered: false, start: 1)))

        case let node as OrderedList:
            return RenderBlock(
                id: claimID(),
                kind: .list(listModel(node, ordered: true, start: Int(node.startIndex)))
            )

        case let node as Markdown.Table:
            return RenderBlock(id: claimID(), kind: .table(tableModel(node)))

        case is ThematicBreak:
            return RenderBlock(id: claimID(), kind: .rule)

        case let node as HTMLBlock:
            // Shown as literal source, never interpreted — see InlineHTML.
            let raw = node.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : RenderBlock(id: claimID(), kind: .htmlBlock(raw))

        default:
            // Unknown container: keep its children rather than dropping content.
            let children = convert(Array(markup.children), quoteDepth: quoteDepth)
            return children.first
        }
    }

    // MARK: Block quotes and GitHub alerts

    private mutating func convertQuote(_ node: BlockQuote, quoteDepth: Int) -> RenderBlock {
        let id = claimID()
        var inner = convert(Array(node.children), quoteDepth: quoteDepth + 1)

        // `> [!NOTE]` — GitHub renders these as callouts rather than quotes.
        // cmark leaves the marker as literal text because the shortcut link
        // reference never resolves, so it is detected here.
        if quoteDepth == 0,
           case let .paragraph(text)? = inner.first?.kind,
           let (kind, remainder) = AlertMarker.split(text) {
            if remainder.isEmpty {
                inner.removeFirst()
            } else {
                inner[0] = RenderBlock(id: inner[0].id, kind: .paragraph(remainder))
            }
            return RenderBlock(id: id, kind: .alert(kind: kind, blocks: inner))
        }

        return RenderBlock(id: id, kind: .quote(blocks: inner, depth: quoteDepth))
    }

    // MARK: Lists

    private mutating func listModel(_ node: Markup, ordered: Bool, start: Int) -> ListModel {
        var items: [ListItemModel] = []
        for case let item as Markdown.ListItem in node.children {
            let checked: Bool? = item.checkbox.map { $0 == .checked }
            items.append(
                ListItemModel(
                    id: claimID(),
                    checked: checked,
                    blocks: convert(Array(item.children))
                )
            )
        }
        // swift-markdown does not surface list tightness, so it is inferred:
        // a list whose every item is a single paragraph renders tight, which
        // matches how CommonMark defines it in practice.
        let tight = items.allSatisfy { item in
            item.blocks.count <= 1 && item.blocks.allSatisfy {
                if case .paragraph = $0.kind { return true }
                return false
            }
        }
        return ListModel(isOrdered: ordered, start: start, isTight: tight, items: items)
    }

    // MARK: Tables

    private func tableModel(_ node: Markdown.Table) -> TableModel {
        let alignments: [ColumnAlignment] = node.columnAlignments.map { alignment in
            switch alignment {
            case .center: return .center
            case .right:  return .trailing
            default:      return .leading
            }
        }

        var header: [InlineText] = []
        for case let cell as Markdown.Table.Cell in node.head.children {
            header.append(InlineFlattener.flatten(cell))
        }

        var rows: [[InlineText]] = []
        for case let row as Markdown.Table.Row in node.body.children {
            var cells: [InlineText] = []
            for case let cell as Markdown.Table.Cell in row.children {
                cells.append(InlineFlattener.flatten(cell))
            }
            rows.append(cells)
        }

        return TableModel(alignments: alignments, header: header, rows: rows)
    }

    // MARK: Helpers

    private func soleImage(in paragraph: Paragraph) -> ImageModel? {
        let meaningful = paragraph.children.filter { !($0 is SoftBreak) }
        guard meaningful.count == 1, let image = meaningful.first as? Markdown.Image,
              let source = image.source
        else { return nil }
        return ImageModel(source: source, alt: image.plainText, title: image.title)
    }

    /// GitHub's heading-anchor slug, with the same `-1`, `-2` suffixing for
    /// repeats so table-of-contents links stay unique.
    private mutating func claimAnchor(for title: String) -> String {
        let base = title.lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_" }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")

        let slug = base.isEmpty ? "section" : base
        guard usedAnchors.contains(slug) else {
            usedAnchors.insert(slug)
            return slug
        }
        var n = 1
        while usedAnchors.contains("\(slug)-\(n)") { n += 1 }
        let unique = "\(slug)-\(n)"
        usedAnchors.insert(unique)
        return unique
    }
}

// MARK: - Alert marker parsing

enum AlertMarker {
    /// Splits a leading `[!NOTE]` marker off a paragraph, returning the alert
    /// kind and whatever text remains.
    static func split(_ text: InlineText) -> (AlertKind, InlineText)? {
        let plain = text.plain
        guard plain.hasPrefix("[!") , let close = plain.firstIndex(of: "]") else { return nil }
        let token = String(plain[plain.index(plain.startIndex, offsetBy: 2)..<close]).lowercased()
        guard let kind = AlertKind(rawValue: token) else { return nil }

        let markerLength = plain.distance(from: plain.startIndex, to: close) + 1
        var remaining = markerLength
        var spans: [InlineSpan] = []

        for span in text.spans {
            if remaining <= 0 {
                spans.append(span)
            } else if span.text.count <= remaining {
                remaining -= span.text.count
            } else {
                var trimmed = span
                trimmed.text = String(span.text.dropFirst(remaining))
                remaining = 0
                spans.append(trimmed)
            }
        }

        // Drop the newline that separates the marker from the body.
        if var first = spans.first {
            first.text = first.text.drop(while: { $0 == "\n" || $0 == " " }).description
            if first.text.isEmpty { spans.removeFirst() } else { spans[0] = first }
        }
        return (kind, InlineText(spans: spans))
    }
}

private extension String {
    func trimmingTrailingNewlines() -> String {
        var s = self
        while s.hasSuffix("\n") || s.hasSuffix("\r") { s.removeLast() }
        return s
    }
}
