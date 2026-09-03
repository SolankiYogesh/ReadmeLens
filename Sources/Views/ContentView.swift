import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var document: DocumentModel
    @EnvironmentObject private var search: SearchModel
    @EnvironmentObject private var defaultApp: DefaultAppCoordinator
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            HStack(spacing: 0) {
                if document.isOutlineVisible {
                    OutlineSidebar()
                    Rectangle().fill(theme.border).frame(width: 1)
                }
                documentPane
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        document.isOutlineVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle outline (⌥⌘S)")

                Button { document.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!document.canGoBack)
                    .help("Back")

                Button { document.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!document.canGoForward)
                    .help("Forward")

                if let position = document.trailPosition {
                    Text(position)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.fgMuted)
                        .monospacedDigit()
                        .help("Document \(position) — use the arrows or ⌘[ and ⌘]")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    AppDelegate.printHandler?()
                } label: {
                    Image(systemName: "printer")
                }
                .disabled(document.blocks.isEmpty)
                .help("Print… (⌘P)")

                ThemePickerButton()
            }
        }
        .overlay(alignment: .bottomTrailing) { reloadIndicator }
        .environment(\.openURL, OpenURLAction { url in handle(url) })
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadDrop(providers)
        }
        .task {
            if document.isEmpty { document.loadWelcome() }
        }
        .onChange(of: document.blocks) { _, blocks in
            search.documentChanged(to: blocks)
        }
    }

    private var documentPane: some View {
        ZStack {
            theme.canvas

            VStack(spacing: 0) {
                if search.isActive {
                    SearchBar(search: search)
                }
                if defaultApp.shouldOffer || defaultApp.isRunningFromTemporaryLocation {
                    DefaultAppBanner()
                }
                if document.needsFolderAccess {
                    FolderAccessBanner()
                }

                if let message = document.errorMessage {
                    VStack(spacing: 14) {
                        MessageView(
                            systemImage: document.needsAccessToOpen
                                ? "folder.badge.questionmark" : "exclamationmark.triangle",
                            title: document.needsAccessToOpen
                                ? "Permission needed" : "Couldn’t open file",
                            detail: message
                        )
                        if document.needsAccessToOpen {
                            GrantAccessButton(label: "Grant Access…")
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else if document.isEmpty {
                    MessageView(
                        systemImage: "doc.richtext",
                        title: "Open a Markdown file",
                        detail: "Press ⌘O, or drop a .md file anywhere in this window."
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    DocumentScrollView(blocks: document.blocks)
                }
            }
        }
    }

    /// Brief confirmation that the file changed on disk and was re-read.
    @ViewBuilder
    private var reloadIndicator: some View {
        if document.didJustReload {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text("Updated")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(theme.canvas)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.link, in: Capsule())
            .padding(16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.2), value: document.didJustReload)
        }
    }

    private func handle(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == DocumentModel.anchorScheme {
            let slug = (url.host ?? "").removingPercentEncoding ?? url.host ?? ""
            if !slug.isEmpty { document.pendingAnchor = slug }
            return .handled
        }

        if url.isFileURL {
            let ext = url.pathExtension.lowercased()
            if DocumentModel.markdownExtensions.contains(ext) {
                document.open(url)
                return .handled
            }
            // Anything else is for the system to deal with.
            NSWorkspace.shared.open(url)
            return .handled
        }

        return .systemAction
    }

    /// Dropping several files at once opens them as one trail.
    private func loadDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        // Providers resolve out of order, so results are kept in slots.
        var resolved = [URL?](repeating: nil, count: providers.count)
        let lock = NSLock()

        for (index, provider) in providers.enumerated() {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                lock.lock(); resolved[index] = url; lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let urls = resolved.compactMap { $0 }
            guard !urls.isEmpty else { return }
            Task { @MainActor in document.open(urls) }
        }
        return true
    }
}

/// Offers the one-time folder grant the sandbox requires before local images
/// and sibling documents can be read.
struct FolderAccessBanner: View {
    @EnvironmentObject private var document: DocumentModel
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    private var folderName: String {
        document.baseDirectory?.lastPathComponent ?? "this folder"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(theme.alertColor(.note))

            VStack(alignment: .leading, spacing: 1) {
                Text("This document links to local files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.fg)
                Text("Grant access to “\(folderName)” to show images and follow links.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.fgMuted)
            }

            Spacer(minLength: 8)

            GrantAccessButton(label: "Grant Access…", small: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.canvasSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

}

/// Asks for a one-time folder grant and hands it to the document.
struct GrantAccessButton: View {
    let label: String
    var small = false

    @EnvironmentObject private var document: DocumentModel

    var body: some View {
        Button(label) { grant() }
            .controlSize(small ? .small : .regular)
    }

    private func grant() {
        guard let directory = document.baseDirectory else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.message = "Grant ReadmeLens read access to this folder."
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        if FolderAccessStore.shared.store(chosen) {
            document.folderAccessGranted()
        }
    }
}

/// Reports where each rendered block sits, so the topmost visible one can be
/// restored after the file is re-read.
private struct VisibleBlocksKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { current, _ in current }
    }
}

/// The scrolling document body.
struct DocumentScrollView: View {
    let blocks: [RenderBlock]

    @EnvironmentObject private var document: DocumentModel
    @EnvironmentObject private var search: SearchModel
    @EnvironmentObject private var defaultApp: DefaultAppCoordinator
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    private static let space = "document"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks, id: \.scrollID) { block in
                        BlockView(block: block)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: VisibleBlocksKey.self,
                                        value: [
                                            block.scrollID:
                                                geometry.frame(in: .named(Self.space)).minY
                                        ]
                                    )
                                }
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: typography.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .coordinateSpace(name: Self.space)
            .background(theme.canvas)
            .onPreferenceChange(VisibleBlocksKey.self) { frames in
                // The first block whose top edge has not yet passed above the
                // viewport is what the reader is looking at. It drives both
                // outline highlighting and restoring position after a reload.
                let top = frames
                    .filter { $0.value >= -40 }
                    .min { $0.value < $1.value }?
                    .key
                if top != document.topVisibleBlockID {
                    document.topVisibleBlockID = top
                }
            }
            .onChange(of: search.pendingScroll) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                search.pendingScroll = nil
            }
            .onChange(of: document.pendingAnchor) { _, anchor in
                guard let anchor else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("#\(anchor)", anchor: .top)
                }
                document.pendingAnchor = nil
            }
            .onChange(of: document.reloadToken) { _, _ in
                // The list has just been rebuilt; let it lay out before
                // scrolling, or the target may not exist yet.
                guard let target = document.topVisibleBlockID else { return }
                Task { @MainActor in
                    await Task.yield()
                    proxy.scrollTo(target, anchor: .top)
                }
            }
            .onChange(of: document.url) { _, _ in
                // A freshly opened document starts at the top.
                guard let first = blocks.first else { return }
                proxy.scrollTo(first.scrollID, anchor: .top)
            }
        }
    }
}

struct MessageView: View {
    let systemImage: String
    let title: String
    let detail: String

    @Environment(\.theme) private var theme
    @Environment(\.typography) private var typography

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.fgSubtle)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.fg)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.fgMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
