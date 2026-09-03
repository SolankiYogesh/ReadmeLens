import SwiftUI

/// Renders a parsed HTML node tree.
///
/// Only a passive subset is honoured — layout, emphasis, images, links,
/// headings, lists and disclosure. Anything unrecognised falls through to its
/// children so text is never lost, and nothing is ever executed.
struct HTMLNodesView: View {
    let nodes: [HTMLNode]
    var alignment: HTMLAlignment?

    @Environment(\.theme) private var theme

    private static let inlineTags: Set<String> = [
        "a", "b", "strong", "i", "em", "code", "kbd", "sub", "sup", "span",
        "small", "img", "br", "s", "del", "u", "mark", "abbr", "cite", "q",
        "tt", "big", "font", "samp", "var", "time", "picture",
    ]

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .center:  return .center
        case .right:   return .trailing
        default:       return .leading
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center:  return .center
        case .right:   return .trailing
        default:       return .leading
        }
    }

    /// Consecutive inline nodes render together so they can flow and wrap;
    /// block elements each get their own row.
    private enum Chunk: Identifiable {
        case inline(Int, [HTMLNode])
        case block(Int, HTMLElement)

        var id: Int {
            switch self {
            case let .inline(index, _): return index
            case let .block(index, _):  return index
            }
        }
    }

    private var chunks: [Chunk] {
        var out: [Chunk] = []
        var pending: [HTMLNode] = []
        var counter = 0

        func flush() {
            guard !pending.isEmpty else { return }
            if !pending.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || pending.containsRenderableElement {
                out.append(.inline(counter, pending))
                counter += 1
            }
            pending = []
        }

        for node in nodes {
            switch node {
            case .text:
                pending.append(node)
            case let .element(element):
                if Self.inlineTags.contains(element.tag) {
                    pending.append(node)
                } else {
                    flush()
                    out.append(.block(counter, element))
                    counter += 1
                }
            }
        }
        flush()
        return out
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 10) {
            ForEach(chunks) { chunk in
                switch chunk {
                case let .inline(_, run):
                    HTMLInlineRun(nodes: run, alignment: alignment)
                case let .block(_, element):
                    blockView(element)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func blockView(_ element: HTMLElement) -> some View {
        let inherited = element.alignment ?? alignment

        switch element.tag {
        case "div", "section", "article", "main", "header", "footer",
             "aside", "nav", "figure", "figcaption", "p", "center", "dl", "dd":
            HTMLNodesView(nodes: element.children, alignment: inherited)

        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(element.tag.dropFirst()) ?? 1
            VStack(alignment: .leading, spacing: 6) {
                HTMLInlineRun(
                    nodes: element.children,
                    alignment: inherited,
                    size: Typography.headingSize(level),
                    weight: .semibold
                )
                if level <= 2 {
                    Rectangle().fill(theme.borderMuted).frame(height: 1)
                }
            }
            .padding(.top, 6)

        case "hr":
            Rectangle().fill(theme.border).frame(height: 1).padding(.vertical, 6)

        case "blockquote":
            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(theme.blockquoteBar).frame(width: 3)
                HTMLNodesView(nodes: element.children, alignment: inherited)
                    .padding(.leading, 14)
            }
            .foregroundStyle(theme.fgMuted)

        case "ul", "ol":
            HTMLListView(element: element, alignment: inherited)

        case "li":
            HTMLNodesView(nodes: element.children, alignment: inherited)

        case "details":
            HTMLDetailsView(element: element, alignment: inherited)

        case "summary":
            HTMLInlineRun(nodes: element.children, alignment: inherited, weight: .semibold)

        case "pre":
            CodeBlockView(language: nil, source: element.children.plainText)

        case "table":
            HTMLTableView(element: element)

        default:
            // Unknown container: keep the content, drop the wrapper.
            HTMLNodesView(nodes: element.children, alignment: inherited)
        }
    }
}

private extension Array where Element == HTMLNode {
    /// True when a run holds something visible even though it has no text,
    /// such as a row of badge images.
    var containsRenderableElement: Bool {
        contains { node in
            if case let .element(element) = node {
                if element.tag == "img" || element.tag == "picture" { return true }
                return element.children.containsRenderableElement
            }
            return false
        }
    }
}
