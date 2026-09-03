import SwiftUI

/// Table of contents for the open document.
struct OutlineSidebar: View {
    @EnvironmentObject private var document: DocumentModel
    @Environment(\.theme) private var theme

    private var depths: [String: Int] { document.outline.indentationDepths }
    private var activeID: String? { document.activeOutlineID }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.fgMuted)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if document.outline.isEmpty {
                Text("No headings")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.fgSubtle)
                    .padding(.horizontal, 14)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(document.outline) { entry in
                            OutlineRow(
                                entry: entry,
                                depth: depths[entry.id] ?? 0,
                                isActive: entry.id == activeID
                            ) {
                                document.pendingAnchor = entry.anchor
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 240)
        .background(theme.canvasSubtle)
    }
}

private struct OutlineRow: View {
    let entry: OutlineEntry
    let depth: Int
    let isActive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // A marker rather than indentation alone, so the active
                // section is findable without reading the text.
                Rectangle()
                    .fill(isActive ? theme.link : .clear)
                    .frame(width: 2)
                    .padding(.vertical, 1)

                Text(entry.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? theme.fg : theme.fgMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, CGFloat(depth) * 12 + 8)
                    .padding(.vertical, 4)

                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? theme.fg.opacity(0.07) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(entry.title)
    }
}
