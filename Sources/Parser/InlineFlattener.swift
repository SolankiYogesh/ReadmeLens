import Foundation
import Markdown

/// Collapses swift-markdown's inline tree into a flat run of styled spans.
///
/// Style and link context are inherited down the recursion, so nesting like
/// `**[bold _italic_ link](url)**` arrives as spans already carrying every
/// attribute that applies to them.
enum InlineFlattener {

    static func flatten(_ container: Markup) -> InlineText {
        var spans: [InlineSpan] = []
        for child in container.children {
            append(child, style: [], link: nil, into: &spans)
        }
        return InlineText(spans: merge(spans))
    }

    private static func append(
        _ markup: Markup,
        style: InlineStyle,
        link: String?,
        into spans: inout [InlineSpan]
    ) {
        switch markup {
        case let node as Markdown.Text:
            spans.append(InlineSpan(text: node.string, style: style, link: link))

        case let node as InlineCode:
            spans.append(InlineSpan(text: node.code, style: style.union(.code), link: link))

        case is SoftBreak:
            // CommonMark: a soft break renders as a space, not a newline.
            spans.append(InlineSpan(text: " ", style: style, link: link))

        case is LineBreak:
            spans.append(InlineSpan(text: "\n", style: style, link: link))

        case let node as Markdown.Image:
            // An image sitting inside a run of text degrades to its alt text;
            // an image that is the whole paragraph is promoted to an image
            // block by BlockFlattener before it ever reaches here.
            let alt = node.plainText.isEmpty ? (node.source ?? "image") : node.plainText
            spans.append(InlineSpan(text: alt, style: style.union(.italic), link: link))

        case let node as InlineHTML:
            // Inline HTML is shown literally rather than interpreted; a viewer
            // that silently executed embedded markup would be a security
            // problem, and READMEs use very little of it.
            spans.append(InlineSpan(text: node.rawHTML, style: style.union(.code), link: link))

        case let node as Markdown.Link:
            for child in node.children {
                append(child, style: style, link: node.destination ?? link, into: &spans)
            }

        case is Strong:
            for child in markup.children {
                append(child, style: style.union(.bold), link: link, into: &spans)
            }

        case is Emphasis:
            for child in markup.children {
                append(child, style: style.union(.italic), link: link, into: &spans)
            }

        case is Strikethrough:
            for child in markup.children {
                append(child, style: style.union(.strike), link: link, into: &spans)
            }

        default:
            for child in markup.children {
                append(child, style: style, link: link, into: &spans)
            }
        }
    }

    /// Coalesces neighbouring spans that share formatting, so the view builds
    /// one attributed run instead of one per word.
    private static func merge(_ spans: [InlineSpan]) -> [InlineSpan] {
        var out: [InlineSpan] = []
        for span in spans where !span.text.isEmpty {
            if var last = out.last, last.style == span.style, last.link == span.link {
                last.text += span.text
                out[out.count - 1] = last
            } else {
                out.append(span)
            }
        }
        return out
    }
}
