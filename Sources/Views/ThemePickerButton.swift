import SwiftUI

/// The theme switcher: a single dot in the window toolbar that wears the
/// current theme's accent colour, and opens a palette popover when clicked.
struct ThemePickerButton: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.theme) private var theme

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(theme.link)
                .frame(width: 13, height: 13)
                .overlay(
                    Circle().stroke(theme.fg.opacity(0.25), lineWidth: 0.5)
                )
                // A hit area larger than the dot, so it stays easy to click.
                .padding(5)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Theme — \(themeStore.displayName)")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ThemePalettePopover(isPresented: $isPresented)
                .environmentObject(themeStore)
                .environment(\.theme, theme)
        }
    }
}

/// The popover listing every bundled theme plus the follow-system option.
struct ThemePalettePopover: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.theme) private var theme
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Theme")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.fgMuted)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(themeStore.available) { candidate in
                ThemeRow(
                    swatchCanvas: candidate.canvas,
                    swatchAccent: candidate.link,
                    swatchBorder: candidate.border,
                    title: candidate.name,
                    isSelected: themeStore.selectedID == candidate.id
                ) {
                    themeStore.selectedID = candidate.id
                    isPresented = false
                }
            }

            Divider()
                .overlay(theme.border)
                .padding(.vertical, 4)

            ThemeRow(
                swatchCanvas: themeStore.current.canvas,
                swatchAccent: themeStore.current.link,
                swatchBorder: themeStore.current.border,
                title: "Follow System",
                subtitle: themeStore.systemIsDark ? "Dark now" : "Light now",
                isSelected: themeStore.selectedID == ThemeStore.autoID
            ) {
                themeStore.selectedID = ThemeStore.autoID
                isPresented = false
            }
            .padding(.bottom, 8)
        }
        .frame(width: 232)
        .background(theme.canvas)
    }
}

private struct ThemeRow: View {
    let swatchCanvas: Color
    let swatchAccent: Color
    let swatchBorder: Color
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // A miniature of the theme itself — its canvas with its accent
                // sitting on top — reads far faster than a plain colour chip.
                RoundedRectangle(cornerRadius: 4)
                    .fill(swatchCanvas)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(swatchAccent)
                            .frame(width: 8, height: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(swatchBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.fg)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.fgSubtle)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.link)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? theme.fg.opacity(0.08) : .clear)
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
