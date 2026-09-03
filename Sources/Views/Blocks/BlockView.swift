import SwiftUI

/// Dispatches a `RenderBlock` to the view that draws it.
struct BlockView: View {
    let block: RenderBlock
    @Environment(\.theme) private var theme
    @Environment(\.blockAlignment) private var alignment

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

    var body: some View {
        switch block.kind {
        case let .heading(level, text, anchor):
            HeadingView(level: level, text: text, anchor: anchor)

        case let .paragraph(text):
            StyledText(inline: text)
                .lineSpacing(5)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

        case let .code(language, source):
            CodeBlockView(language: language, source: source)

        case let .mermaid(source):
            // Rendered as source until the diagram engine lands; showing the
            // definition beats showing nothing.
            CodeBlockView(language: "mermaid", source: source)

        case let .quote(blocks, depth):
            QuoteView(blocks: blocks, depth: depth)

        case let .alert(kind, blocks):
            AlertView(kind: kind, blocks: blocks)

        case let .list(model):
            ListView(model: model)

        case let .table(model):
            MarkdownTableView(model: model)

        case .rule:
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
                .padding(.vertical, 8)

        case let .image(model):
            MarkdownImageView(model: model)

        case let .html(nodes):
            HTMLNodesView(nodes: nodes, alignment: alignment)

        case let .disclosure(summary, blocks):
            DisclosureBlockView(summary: summary, blocks: blocks)

        case let .container(alignment, blocks):
            VStack(alignment: alignment == .center ? .center
                            : alignment == .right ? .trailing : .leading,
                   spacing: 14) {
                ForEach(blocks) { BlockView(block: $0) }
            }
            .frame(maxWidth: .infinity,
                   alignment: alignment == .center ? .center
                            : alignment == .right ? .trailing : .leading)
            .environment(\.blockAlignment, alignment)

        // Folded into `.container` by the flattener; never reaches a view.
        case .htmlOpen, .htmlClose:
            EmptyView()
        }
    }
}

// MARK: - Heading

struct HeadingView: View {
    let level: Int
    let text: InlineText
    let anchor: String

    @Environment(\.theme) private var theme
    @Environment(\.blockAlignment) private var alignment

    var body: some View {
        VStack(alignment: alignment == .center ? .center
                        : alignment == .right ? .trailing : .leading,
               spacing: 6) {
            StyledText(
                inline: text,
                size: Typography.headingSize(level),
                weight: .semibold,
                color: level >= 6 ? theme.fgMuted : theme.fg
            )
            .multilineTextAlignment(alignment == .center ? .center
                                  : alignment == .right ? .trailing : .leading)
            .frame(maxWidth: .infinity,
                   alignment: alignment == .center ? .center
                            : alignment == .right ? .trailing : .leading)
            // GitHub underlines only its top two heading levels.
            if level <= 2 {
                Rectangle().fill(theme.borderMuted).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, level <= 2 ? 12 : 8)
        .id(anchor)
    }
}

// MARK: - Quote

struct QuoteView: View {
    let blocks: [RenderBlock]
    let depth: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(theme.blockquoteBar)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { BlockView(block: $0) }
            }
            .padding(.leading, 14)
            .padding(.vertical, 2)
        }
        .foregroundStyle(theme.fgMuted)
    }
}

// MARK: - Alert

struct AlertView: View {
    let kind: AlertKind
    let blocks: [RenderBlock]

    @Environment(\.theme) private var theme

    private var accent: Color { theme.alertColor(kind) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(kind.title)
                        .font(.system(size: Typography.body, weight: .semibold))
                } icon: {
                    Image(systemName: kind.systemImage)
                }
                .foregroundStyle(accent)

                ForEach(blocks) { BlockView(block: $0) }
            }
            .padding(.leading, 14)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - List

struct ListView: View {
    let model: ListModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: model.isTight ? 4 : 12) {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    marker(for: item, at: index)
                        .frame(minWidth: 20, alignment: .trailing)
                    VStack(alignment: .leading, spacing: model.isTight ? 4 : 10) {
                        ForEach(item.blocks) { BlockView(block: $0) }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func marker(for item: ListItemModel, at index: Int) -> some View {
        if let checked = item.checked {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundStyle(checked ? theme.link : theme.fgMuted)
                .font(.system(size: Typography.body * 0.95))
        } else if model.isOrdered {
            Text("\(model.start + index).")
                .font(.system(size: Typography.body))
                .foregroundStyle(theme.fgMuted)
                .monospacedDigit()
        } else {
            Text("•")
                .font(.system(size: Typography.body))
                .foregroundStyle(theme.fgMuted)
        }
    }
}

// MARK: - Image

struct MarkdownImageView: View {
    let model: ImageModel
    @Environment(\.blockAlignment) private var alignment

    var body: some View {
        DocumentImage(source: model.source, alt: model.alt)
            .frame(maxWidth: .infinity,
                   alignment: alignment == .center ? .center
                            : alignment == .right ? .trailing : .leading)
    }
}

/// `<details>` wrapping Markdown blocks.
struct DisclosureBlockView: View {
    let summary: [HTMLNode]
    let blocks: [RenderBlock]

    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { BlockView(block: $0) }
                }
                .padding(.leading, 18)
            }
        }
    }
}

/// Alignment inherited from an enclosing HTML container, so a Markdown image
/// inside `<div align="center">` centres with everything around it.
private struct BlockAlignmentKey: EnvironmentKey {
    static let defaultValue: HTMLAlignment? = nil
}

extension EnvironmentValues {
    var blockAlignment: HTMLAlignment? {
        get { self[BlockAlignmentKey.self] }
        set { self[BlockAlignmentKey.self] = newValue }
    }
}
