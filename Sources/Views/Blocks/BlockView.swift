import SwiftUI

/// Dispatches a `RenderBlock` to the view that draws it.
struct BlockView: View {
    let block: RenderBlock
    @Environment(\.theme) private var theme

    var body: some View {
        switch block.kind {
        case let .heading(level, text, anchor):
            HeadingView(level: level, text: text, anchor: anchor)

        case let .paragraph(text):
            StyledText(inline: text)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)

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

        case let .htmlBlock(raw):
            CodeBlockView(language: "html", source: raw)
        }
    }
}

// MARK: - Heading

struct HeadingView: View {
    let level: Int
    let text: InlineText
    let anchor: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StyledText(
                inline: text,
                size: Typography.headingSize(level),
                weight: .semibold,
                color: level >= 6 ? theme.fgMuted : theme.fg
            )
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
    @Environment(\.theme) private var theme

    private var remoteURL: URL? {
        guard let url = URL(string: model.source),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    var body: some View {
        Group {
            if let url = remoteURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFit()
                    case .failure:
                        placeholder(systemImage: "photo.badge.exclamationmark", label: model.alt)
                    case .empty:
                        ProgressView().controlSize(.small)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Local images need a security-scoped bookmark to read under
                // the sandbox; that arrives with file handling.
                placeholder(systemImage: "photo", label: model.alt.isEmpty ? model.source : model.alt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholder(systemImage: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(label).font(.system(size: Typography.body * 0.9))
        }
        .foregroundStyle(theme.fgSubtle)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.canvasSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
    }
}
