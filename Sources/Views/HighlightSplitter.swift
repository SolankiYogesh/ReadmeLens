import Foundation

/// Splits a piece of text into highlighted and unhighlighted segments.
///
/// Search matches are expressed as offsets into a block's *plain* text, while
/// rendering happens per styled span or per syntax run. Rather than doing index
/// arithmetic on `AttributedString`, each piece is cut at the highlight
/// boundaries that fall inside it and emitted as separate runs.
enum HighlightSplitter {

    struct Segment {
        let text: String
        let isHighlighted: Bool
        let isCurrent: Bool
    }

    /// - Parameters:
    ///   - text: the piece being rendered
    ///   - offset: where that piece starts in the block's plain text
    ///   - ranges: match ranges, in plain-text offsets
    ///   - current: the match the reader is currently on, if it is in this block
    static func segments(
        text: String,
        offset: Int,
        ranges: [Range<Int>],
        current: Range<Int>?
    ) -> [Segment] {
        guard !ranges.isEmpty, !text.isEmpty else {
            return [Segment(text: text, isHighlighted: false, isCurrent: false)]
        }

        let characters = Array(text)
        let pieceRange = offset..<(offset + characters.count)

        // Only the ranges that actually touch this piece matter.
        let overlapping = ranges
            .compactMap { range -> Range<Int>? in
                let lower = Swift.max(range.lowerBound, pieceRange.lowerBound)
                let upper = Swift.min(range.upperBound, pieceRange.upperBound)
                return lower < upper ? lower..<upper : nil
            }
            .sorted { $0.lowerBound < $1.lowerBound }

        guard !overlapping.isEmpty else {
            return [Segment(text: text, isHighlighted: false, isCurrent: false)]
        }

        var segments: [Segment] = []
        var cursor = pieceRange.lowerBound

        for range in overlapping {
            if range.lowerBound > cursor {
                let slice = characters[(cursor - offset)..<(range.lowerBound - offset)]
                segments.append(
                    Segment(text: String(slice), isHighlighted: false, isCurrent: false)
                )
            }
            let slice = characters[(range.lowerBound - offset)..<(range.upperBound - offset)]
            let isCurrent = current.map { $0.overlaps(range) } ?? false
            segments.append(
                Segment(text: String(slice), isHighlighted: true, isCurrent: isCurrent)
            )
            cursor = Swift.max(cursor, range.upperBound)
        }

        if cursor < pieceRange.upperBound {
            let slice = characters[(cursor - offset)...]
            segments.append(Segment(text: String(slice), isHighlighted: false, isCurrent: false))
        }
        return segments
    }
}
