import SwiftUI

/// Formatting carried down through nested inline HTML.
private struct HTMLInlineStyle {
    var bold = false
    var italic = false
    var code = false
    var strike = false
    var underline = false
    var scale: CGFloat = 1
    var baselineOffset: CGFloat = 0
    var link: String?
}

/// Renders a run of inline HTML — text, emphasis, links, images, `<br>`.
///
/// A run with no images renders as a single `Text` so it wraps properly. Once
/// images are involved (badge rows, inline icons) it switches to `FlowLayout`,
/// which wraps a mixed sequence the way a browser line-box would.
struct HTMLInlineRun: View {
    let nodes: [HTMLNode]
    var alignment: HTMLAlignment?
    var size: CGFloat?
    var weight: Font.Weight = .regular

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var document: DocumentModel

    private enum Item: Identifiable {
        case word(Int, AttributedString)
        case image(Int, source: String, alt: String, width: CGFloat?, link: String?)
        var id: Int {
            switch self {
            case let .word(i, _): return i
            case let .image(i, _, _, _, _): return i
            }
        }
    }

    /// `<br>` splits the run into stacked lines.
    private var lines: [[HTMLNode]] {
        var out: [[HTMLNode]] = [[]]
        for node in nodes {
            if case let .element(element) = node, element.tag == "br" {
                out.append([])
            } else {
                out[out.count - 1].append(node)
            }
        }
        return out.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func lineView(_ line: [HTMLNode]) -> some View {
        if line.hasImages {
            FlowLayout(horizontalSpacing: 5, verticalSpacing: 5, alignment: stackAlignment) {
                ForEach(items(for: line)) { item in
                    switch item {
                    case let .word(_, text):
                        Text(text)
                    case let .image(_, source, alt, width, link):
                        imageView(source: source, alt: alt, width: width, link: link)
                    }
                }
            }
        } else {
            Text(attributed(line))
                .lineSpacing(5)
                .multilineTextAlignment(textAlignment)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }

    @ViewBuilder
    private func imageView(source: String, alt: String, width: CGFloat?, link: String?) -> some View {
        let image = DocumentImage(source: source, alt: alt, declaredWidth: width)
        if let link, let url = document.resolveLinkURL(link) {
            Button { openURL(url) } label: { image }
                .buttonStyle(.plain)
                .help(link)
        } else {
            image
        }
    }

    // MARK: - Building

    private func attributed(_ line: [HTMLNode]) -> AttributedString {
        var out = AttributedString()
        appendAttributed(line, style: HTMLInlineStyle(), into: &out)
        return out
    }

    private func appendAttributed(
        _ nodes: [HTMLNode], style: HTMLInlineStyle, into out: inout AttributedString
    ) {
        for node in nodes {
            switch node {
            case let .text(value):
                out.append(run(value, style: style))
            case let .element(element):
                appendAttributed(
                    element.children, style: style.applying(element), into: &out
                )
            }
        }
    }

    private func run(_ text: String, style: HTMLInlineStyle) -> AttributedString {
        var piece = AttributedString(text)
        let pointSize = (size ?? typography.body) * style.scale
        var font: Font = style.code
            ? .system(size: pointSize * 0.9, weight: weight, design: .monospaced)
            : .system(size: pointSize, weight: weight)
        if style.bold   { font = font.bold() }
        if style.italic { font = font.italic() }
        piece.font = font
        piece.foregroundColor = style.link != nil ? theme.link : theme.fg
        if style.code { piece.backgroundColor = theme.inlineCodeBg }
        if style.strike { piece.strikethroughStyle = .single }
        if style.underline { piece.underlineStyle = .single }
        if style.baselineOffset != 0 { piece.baselineOffset = style.baselineOffset }
        if let link = style.link, let url = document.resolveLinkURL(link) {
            piece.link = url
        }
        return piece
    }

    private func items(for line: [HTMLNode]) -> [Item] {
        var out: [Item] = []
        var counter = 0
        collect(line, style: HTMLInlineStyle(), into: &out, counter: &counter)
        return out
    }

    private func collect(
        _ nodes: [HTMLNode], style: HTMLInlineStyle, into out: inout [Item], counter: inout Int
    ) {
        for node in nodes {
            switch node {
            case let .text(value):
                for word in value.split(whereSeparator: { $0.isWhitespace }) {
                    out.append(.word(counter, run(String(word), style: style)))
                    counter += 1
                }
            case let .element(element):
                if element.tag == "img" {
                    guard let source = element.attribute("src") else { continue }
                    out.append(.image(
                        counter,
                        source: source,
                        alt: element.attribute("alt") ?? "",
                        width: element.attribute("width").flatMap { CGFloat(Double($0) ?? 0) }
                            .flatMap { $0 > 0 ? $0 : nil },
                        link: style.link
                    ))
                    counter += 1
                } else {
                    collect(element.children, style: style.applying(element),
                            into: &out, counter: &counter)
                }
            }
        }
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .center: return .center
        case .right:  return .trailing
        default:      return .leading
        }
    }
    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .right:  return .trailing
        default:      return .leading
        }
    }
    private var textAlignment: TextAlignment {
        switch alignment {
        case .center: return .center
        case .right:  return .trailing
        default:      return .leading
        }
    }
}

private extension HTMLInlineStyle {
    func applying(_ element: HTMLElement) -> HTMLInlineStyle {
        var s = self
        switch element.tag {
        case "b", "strong":       s.bold = true
        case "i", "em", "cite", "var": s.italic = true
        case "code", "kbd", "samp", "tt": s.code = true
        case "s", "del", "strike": s.strike = true
        case "u", "ins":          s.underline = true
        case "small":             s.scale *= 0.85
        case "big":               s.scale *= 1.15
        case "sub":               s.scale *= 0.75; s.baselineOffset = -3
        case "sup":               s.scale *= 0.75; s.baselineOffset = 4
        case "mark":              s.underline = true
        case "a":                 s.link = element.attribute("href") ?? s.link
        default:                  break
        }
        return s
    }
}

private extension Array where Element == HTMLNode {
    var hasImages: Bool {
        contains { node in
            if case let .element(element) = node {
                if element.tag == "img" { return true }
                return element.children.hasImages
            }
            return false
        }
    }
}

// MARK: - Lists, disclosure and tables

struct HTMLListView: View {
    let element: HTMLElement
    var alignment: HTMLAlignment?

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    private var items: [HTMLElement] {
        element.children.compactMap {
            if case let .element(child) = $0, child.tag == "li" { return child }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(element.tag == "ol" ? "\(index + 1)." : "•")
                        .font(.system(size: typography.body))
                        .foregroundStyle(theme.fgMuted)
                        .frame(minWidth: 18, alignment: .trailing)
                    HTMLNodesView(nodes: item.children, alignment: alignment)
                }
            }
        }
    }
}

/// `<details>` becomes a real disclosure triangle rather than printed source —
/// collapsed sections are how large READMEs stay navigable.
struct HTMLDetailsView: View {
    let element: HTMLElement
    var alignment: HTMLAlignment?

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography
    @State private var isExpanded: Bool = false

    private var summary: [HTMLNode] {
        for case let .element(child) in element.children where child.tag == "summary" {
            return child.children
        }
        return [.text("Details")]
    }

    private var content: [HTMLNode] {
        element.children.filter {
            if case let .element(child) = $0, child.tag == "summary" { return false }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(theme.fgMuted)
                    HTMLInlineRun(nodes: summary, weight: .semibold)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HTMLNodesView(nodes: content, alignment: alignment)
                    .padding(.leading, 18)
            }
        }
        .padding(.vertical, 2)
        .onAppear { isExpanded = element.attributes["open"] != nil }
    }
}

struct HTMLTableView: View {
    let element: HTMLElement
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    private var rows: [[HTMLElement]] {
        var out: [[HTMLElement]] = []
        func walk(_ nodes: [HTMLNode]) {
            for case let .element(child) in nodes {
                if child.tag == "tr" {
                    let cells = child.children.compactMap { node -> HTMLElement? in
                        if case let .element(cell) = node, cell.tag == "td" || cell.tag == "th" {
                            return cell
                        }
                        return nil
                    }
                    if !cells.isEmpty { out.append(cells) }
                } else {
                    walk(child.children)
                }
            }
        }
        walk(element.children)
        return out
    }

    var body: some View {
        let rows = rows
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    if index > 0 { Divider().overlay(theme.border) }
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            HTMLNodesView(nodes: cell.children, alignment: cell.alignment)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(minWidth: 80, alignment: .leading)
                        }
                    }
                    .background(cells.first?.tag == "th" ? theme.tableHeaderBg : .clear)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
