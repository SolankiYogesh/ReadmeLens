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
        var html = HTMLContext()
        for child in container.children {
            if let node = child as? InlineHTML {
                html.consume(node.rawHTML, into: &spans)
                continue
            }
            append(child, style: html.style, link: html.link, into: &spans)
        }
        return InlineText(spans: merge(spans))
    }

    /// Tracks inline HTML tags as they open and close across a paragraph.
    ///
    /// swift-markdown hands back `<sub>`, its text, and `</sub>` as three
    /// separate siblings, so the effect of a tag has to be carried between
    /// them rather than nested. Tags that carry no inline meaning are dropped
    /// rather than printed — showing raw markup is worse than showing nothing.
    private struct HTMLContext {
        private var stack: [String] = []
        private var links: [String] = []

        var style: InlineStyle {
            var result: InlineStyle = []
            for tag in stack {
                switch tag {
                case "b", "strong":               result.insert(.bold)
                case "i", "em", "cite":           result.insert(.italic)
                case "code", "kbd", "samp", "tt": result.insert(.code)
                case "s", "del", "strike":        result.insert(.strike)
                default:                          break
                }
            }
            return result
        }

        var link: String? { links.last }

        mutating func consume(_ rawHTML: String, into spans: inout [InlineSpan]) {
            let nodes = HTMLParser.parse(rawHTML)
            guard case let .element(element)? = nodes.first else {
                // A closing tag parses to nothing; unwind the matching open.
                let name = closingTagName(rawHTML)
                if let name {
                    if let index = stack.lastIndex(of: name) { stack.remove(at: index) }
                    if name == "a", !links.isEmpty { links.removeLast() }
                }
                return
            }

            switch element.tag {
            case "br":
                spans.append(InlineSpan(text: "\n", style: style, link: link))
            case "img":
                // An inline image degrades to its alt text; a standalone image
                // is promoted to a block before it reaches here.
                let alt = element.attribute("alt") ?? ""
                if !alt.isEmpty {
                    spans.append(InlineSpan(text: alt, style: style.union(.italic), link: link))
                }
            case "wbr", "hr":
                break
            default:
                if !HTMLParser.voidElements.contains(element.tag) {
                    stack.append(element.tag)
                    if element.tag == "a", let href = element.attribute("href") {
                        links.append(href)
                    }
                }
            }
        }

        private func closingTagName(_ raw: String) -> String? {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("</"), trimmed.hasSuffix(">") else { return nil }
            return trimmed.dropFirst(2).dropLast()
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
        }
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
