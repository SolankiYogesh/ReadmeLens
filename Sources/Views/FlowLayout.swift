import SwiftUI

/// Lays subviews left-to-right, wrapping to a new line when the next one no
/// longer fits.
///
/// READMEs open with rows of badge images and short inline runs; a plain HStack
/// would push them off the edge, and a VStack would stack them vertically.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading

    struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(for sizes: [CGSize], maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for (index, size) in sizes.enumerated() {
            let spacing = current.indices.isEmpty ? 0 : horizontalSpacing
            if !current.indices.isEmpty, current.width + spacing + size.width > maxWidth {
                lines.append(current)
                current = Line()
            }
            let lead = current.indices.isEmpty ? 0 : horizontalSpacing
            current.indices.append(index)
            current.width += lead + size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = lines(for: sizes, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } +
                     verticalSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = lines(for: sizes, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center:  x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default:        x = bounds.minX
            }
            for index in row.indices {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }
}
