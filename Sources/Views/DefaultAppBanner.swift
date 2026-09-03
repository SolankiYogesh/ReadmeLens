import SwiftUI

/// Offers to make ReadmeLens the default Markdown viewer.
struct DefaultAppBanner: View {
    @EnvironmentObject private var coordinator: DefaultAppCoordinator
    @Environment(\.theme) private var theme

    @State private var isWorking = false

    var body: some View {
        if coordinator.isRunningFromTemporaryLocation {
            temporaryLocationWarning
        } else {
            offer
        }
    }

    /// Setting the default from a build folder works, but points Finder at a
    /// path that disappears when that folder is cleaned.
    private var temporaryLocationWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(theme.alertColor(.warning))
            VStack(alignment: .leading, spacing: 1) {
                Text("ReadmeLens opens Markdown files, but from a temporary location")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.fg)
                Text("Move the app to your Applications folder and set it again, "
                     + "or the association breaks when this build is cleaned.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.fgMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Don’t Ask Again") { coordinator.neverAsk() }
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.canvasSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    private var offer: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.gearshape")
                .foregroundStyle(theme.alertColor(.note))

            VStack(alignment: .leading, spacing: 1) {
                Text("Open Markdown files with ReadmeLens?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.fg)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.fgMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isWorking {
                ProgressView().controlSize(.small)
            } else {
                Button("Not Now") { coordinator.dismissForNow() }
                    .controlSize(.small)
                Button("Don’t Ask Again") { coordinator.neverAsk() }
                    .controlSize(.small)
                Button("Make Default") { makeDefault() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.canvasSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    private var detail: String {
        coordinator.lastError
            ?? "Double-clicking a .md file in Finder will open it here."
    }

    private func makeDefault() {
        isWorking = true
        Task {
            await coordinator.makeDefault()
            isWorking = false
        }
    }
}
