import SwiftUI

/// Renders an `InlineText` using the active theme.
///
/// Colours are resolved here rather than baked into the model, so a theme
/// change is a cheap re-render.
struct StyledText: View {
    let inline: InlineText
    var size: CGFloat = Typography.body
    var weight: Font.Weight = .regular
    var color: Color?

    @Environment(\.theme) private var theme
    @EnvironmentObject private var search: SearchModel
    @Environment(\.searchBlockID) private var blockID
    @EnvironmentObject private var document: DocumentModel

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
    }

    private var attributed: AttributedString {
        let ranges = highlightRanges
        var out = AttributedString()
        var offset = 0

        for span in inline.spans {
            if ranges.isEmpty {
                out.append(render(span))
            } else {
                for segment in HighlightSplitter.segments(
                    text: span.text, offset: offset, ranges: ranges, current: currentRange
                ) {
                    var piece = span
                    piece.text = segment.text
                    out.append(render(piece, highlight: segment))
                }
            }
            offset += span.text.count
        }
        return out
    }

    private var highlightRanges: [Range<Int>] {
        guard search.isActive, let blockID else { return [] }
        return search.highlightRanges(for: blockID)
    }

    private var currentRange: Range<Int>? {
        guard let blockID, let match = search.currentMatch,
              match.blockID == blockID
        else { return nil }
        return match.range
    }

    private func render(
        _ span: InlineSpan, highlight: HighlightSplitter.Segment? = nil
    ) -> AttributedString {
        var piece = AttributedString(span.text)
        let isCode = span.style.contains(.code)

        var font: Font = isCode
            ? .system(size: size * 0.9, weight: weight, design: .monospaced)
            : .system(size: size, weight: weight)
        if span.style.contains(.bold)   { font = font.bold() }
        if span.style.contains(.italic) { font = font.italic() }
        piece.font = font

        if span.link != nil {
            piece.foregroundColor = theme.link
        } else {
            piece.foregroundColor = color ?? theme.fg
        }
        if isCode {
            piece.backgroundColor = theme.inlineCodeBg
            if span.link == nil { piece.foregroundColor = color ?? theme.fg }
        }
        if span.style.contains(.strike) {
            piece.strikethroughStyle = .single
        }
        if let highlight, highlight.isHighlighted {
            piece.backgroundColor = highlight.isCurrent ? theme.searchHitActive : theme.searchHit
        }
        // Anchors and relative paths resolve through the document, which
        // turns them into targets the open-URL handler understands.
        if let destination = span.link, let url = document.resolveLinkURL(destination) {
            piece.link = url
        }
        return piece
    }
}

enum Typography {
    static let body: CGFloat = 15
    static let code: CGFloat = 13
    static let contentMaxWidth: CGFloat = 1012   // GitHub's own reading measure

    static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1:  return 30
        case 2:  return 23
        case 3:  return 19
        case 4:  return 16
        case 5:  return 14
        default: return 13
        }
    }
}
