import SwiftUI

/// Find-in-document bar.
struct SearchBar: View {
    @ObservedObject var search: SearchModel
    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    private func focusSoon() {
        DispatchQueue.main.async { isFocused = true }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.fgMuted)

            TextField("Find in document", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(theme.fg)
                .focused($isFocused)
                .onSubmit { search.next() }

            if !search.summary.isEmpty {
                Text(search.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.fgMuted)
                    .monospacedDigit()
            }

            Button { search.previous() } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(search.matches.isEmpty)
            .help("Previous match (⇧⌘G)")

            Button { search.next() } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(search.matches.isEmpty)
            .help("Next match (⌘G)")

            Button { search.close() } label: {
                Image(systemName: "xmark")
            }
            .help("Close (esc)")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.canvasSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
        // Focus has to be taken after the field is in the hierarchy; setting
        // it during `onAppear` alone lands before the view is focusable and
        // silently does nothing.
        .onAppear { focusSoon() }
        .onChange(of: search.focusToken) { _, _ in focusSoon() }
        .onExitCommand { search.close() }
    }
}
