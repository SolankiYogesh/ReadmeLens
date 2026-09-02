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

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
    }

    private var attributed: AttributedString {
        var out = AttributedString()
        for span in inline.spans {
            out.append(render(span))
        }
        return out
    }

    private func render(_ span: InlineSpan) -> AttributedString {
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
        // Only absolute destinations become live links. Relative and anchor
        // targets need a document base URL to resolve against, which arrives
        // with remote loading and in-document navigation.
        if let destination = span.link,
           let url = URL(string: destination),
           url.scheme != nil {
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
