import SwiftUI

/// A GFM table.
///
/// Laid out as a Grid so columns size to their content, and wrapped in a
/// horizontal ScrollView so a wide table scrolls itself instead of forcing the
/// whole document to scroll sideways.
struct MarkdownTableView: View {
    let model: TableModel
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    private var columnCount: Int {
        max(model.header.count, model.rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                if model.hasHeader {
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            cell(text(model.header, column), column: column, isHeader: true)
                        }
                    }
                    .background(theme.tableHeaderBg)
                }

                ForEach(Array(model.rows.enumerated()), id: \.offset) { index, row in
                    Divider().overlay(theme.border).gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            cell(text(row, column), column: column, isHeader: false)
                        }
                    }
                    .background(index.isMultiple(of: 2) ? Color.clear : theme.tableStripe)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func text(_ cells: [InlineText], _ column: Int) -> InlineText {
        column < cells.count ? cells[column] : .empty
    }

    private func alignment(_ column: Int) -> Alignment {
        guard column < model.alignments.count else { return .leading }
        switch model.alignments[column] {
        case .center:   return .center
        case .trailing: return .trailing
        case .leading:  return .leading
        }
    }

    private func cell(_ inline: InlineText, column: Int, isHeader: Bool) -> some View {
        StyledText(
            inline: inline,
            size: typography.body * 0.95,
            weight: isHeader ? .semibold : .regular
        )
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: alignment(column))
    }
}
