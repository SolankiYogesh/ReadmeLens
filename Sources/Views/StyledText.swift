import SwiftUI

/// Builds the `AttributedString` for a run of inline text.
///
/// Extracted from the view so its cost can be measured directly: this is the
/// work that a document's every paragraph, list item and table cell performs
/// when it is invalidated, and a table-heavy file has thousands of them.
enum InlineAttributedText {

    static func build(
        _ inline: InlineText,
        size: CGFloat,
        weight: Font.Weight,
        color: Color?,
        theme: Theme,
        links: LinkResolver,
        ranges: [Range<Int>] = [],
        current: Range<Int>? = nil
    ) -> AttributedString {
        // The overwhelmingly common case: no find bar, so no per-span
        // splitting and no offset bookkeeping.
        guard !ranges.isEmpty else {
            var out = AttributedString()
            for span in inline.spans {
                out.append(render(span, size: size, weight: weight, color: color,
                                  theme: theme, links: links))
            }
            return out
        }

        var out = AttributedString()
        var offset = 0
        for span in inline.spans {
            for segment in HighlightSplitter.segments(
                text: span.text, offset: offset, ranges: ranges, current: current
            ) {
                var piece = span
                piece.text = segment.text
                out.append(render(piece, size: size, weight: weight, color: color,
                                  theme: theme, links: links, highlight: segment))
            }
            offset += span.text.count
        }
        return out
    }

    private static func render(
        _ span: InlineSpan,
        size: CGFloat,
        weight: Font.Weight,
        color: Color?,
        theme: Theme,
        links: LinkResolver,
        highlight: HighlightSplitter.Segment? = nil
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
        // Anchors and relative paths resolve through the document folder, which
        // turns them into targets the open-URL handler understands.
        if let destination = span.link, let url = links.resolveLinkURL(destination) {
            piece.link = url
        }
        return piece
    }
}

/// Renders an `InlineText` using the active theme.
///
/// Colours are resolved here rather than baked into the model, so a theme
/// change is a cheap re-render.
///
/// Everything this view needs arrives as an `Equatable` environment *value*,
/// never as an `@EnvironmentObject`. There is one of these per paragraph, list
/// item and table cell — a document with large tables has thousands — so
/// subscribing them to `DocumentModel` or `SearchModel` would mean any publish
/// on either (the scroll cursor moving, most of all) rebuilt every attributed
/// string on screen.
struct StyledText: View {
    let inline: InlineText
    var size: CGFloat?
    var weight: Font.Weight = .regular
    var color: Color?

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography
    @Environment(\.searchHighlight) private var highlight
    @Environment(\.searchBlockID) private var blockID
    @Environment(\.linkResolver) private var links

    // Selection is enabled once at the document root, not per run of text:
    // a document with large tables has thousands of these.
    var body: some View {
        Text(
            InlineAttributedText.build(
                inline,
                size: size ?? typography.body,
                weight: weight,
                color: color,
                theme: theme,
                links: links,
                ranges: highlight.ranges(for: blockID),
                current: highlight.currentRange(for: blockID)
            )
        )
    }
}
