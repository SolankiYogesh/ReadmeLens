import SwiftUI

/// A fenced code block with a language tag and a hover-revealed copy button.
///
/// Text is drawn unhighlighted for now; the highlighter will supply token kinds
/// that the theme maps to colours, so this view will not need to change shape.
struct CodeBlockView: View {
    let language: String?
    let source: String

    @Environment(\.theme) private var theme
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

            ScrollView(.horizontal, showsIndicators: false) {
                Text(source)
                    .font(.system(size: Typography.code, design: .monospaced))
                    .foregroundStyle(theme.codeFg)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.codeBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
        .overlay(alignment: .topTrailing) { copyButton }
        .onHover { isHovering = $0 }
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
