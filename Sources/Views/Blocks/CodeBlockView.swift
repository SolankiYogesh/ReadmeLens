import SwiftUI

/// A fenced code block: language tag, syntax colouring, and a copy button.
///
/// Tokenising runs off the main thread and the result is cached, so scrolling
/// past a long block does not re-tokenise it.
struct CodeBlockView: View {
    let language: String?
    let source: String

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    @EnvironmentObject private var search: SearchModel
    @Environment(\.searchBlockID) private var blockID
    @Environment(\.isPrinting) private var isPrinting
    @State private var runs: [SyntaxRun]?
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.fgMuted)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(theme.canvasInset)
                Rectangle().fill(theme.border).frame(height: 1)
            }

            if isPrinting {
                // Paper cannot scroll, so long lines wrap instead.
                Text(attributed)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(theme.codeBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
        .overlay(alignment: .topTrailing) { copyButton }
        .onHover { isHovering = $0 }
        .task(id: TaskKey(source: source, language: language)) { await highlight() }
    }

    /// Re-tokenise only when the source or language actually changes; a theme
    /// change just recolours the runs already computed.
    private struct TaskKey: Equatable {
        let source: String
        let language: String?
    }

    private var attributed: AttributedString {
        let font = Font.system(size: typography.code, design: .monospaced)
        let ranges = highlightRanges
        let current = currentRange
        // `.task` never runs during a render pass, so when printing the
        // tokens are produced inline. They are cached, so this is cheap.
        let resolved = runs ?? (isPrinting
            ? SyntaxHighlighter.runs(for: source, language: language)
            : nil)
        let pieces = resolved ?? [SyntaxRun(text: source, kind: .plain)]

        var out = AttributedString()
        var offset = 0

        for run in pieces {
            let colour = resolved == nil ? theme.codeFg : theme.syntaxColor(run.kind)

            if ranges.isEmpty {
                var piece = AttributedString(run.text)
                piece.font = font
                piece.foregroundColor = colour
                out.append(piece)
            } else {
                for segment in HighlightSplitter.segments(
                    text: run.text, offset: offset, ranges: ranges, current: current
                ) {
                    var piece = AttributedString(segment.text)
                    piece.font = font
                    piece.foregroundColor = colour
                    if segment.isHighlighted {
                        piece.backgroundColor = segment.isCurrent
                            ? theme.searchHitActive : theme.searchHit
                    }
                    out.append(piece)
                }
            }
            offset += run.text.count
        }
        return out
    }

    private var highlightRanges: [Range<Int>] {
        guard search.isActive, let blockID else { return [] }
        return search.highlightRanges(for: blockID)
    }

    private var currentRange: Range<Int>? {
        guard let blockID, let match = search.currentMatch,
              match.blockID == blockID
        else { return nil }
        return match.range
    }

    private func highlight() async {
        guard SyntaxHighlighter.canHighlight(language) else {
            runs = nil
            return
        }
        let source = self.source
        let language = self.language
        let computed = await Task.detached(priority: .userInitiated) {
            SyntaxHighlighter.runs(for: source, language: language)
        }.value
        runs = computed
    }

    @ViewBuilder
    private var copyButton: some View {
        if isHovering {
            Button {
                copy()
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(didCopy ? theme.alertColor(.tip) : theme.fgMuted)
                    .padding(6)
                    .background(theme.canvasSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(8)
            .help(didCopy ? "Copied" : "Copy code")
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { didCopy = false }
    }
}
