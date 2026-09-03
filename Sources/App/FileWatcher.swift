import Foundation

/// Watches one file and reports when it changes on disk.
///
/// The awkward part is how editors actually save. Most write to a temporary
/// file and rename it over the original, which replaces the inode — the
/// descriptor we are watching now refers to a file that no longer has a name,
/// and no further events ever arrive. So a rename or delete is treated as a
/// signal to re-arm on the *path*, not as the end of the watch.
///
/// Events are also debounced: a single save can produce several in quick
/// succession, and reparsing once is enough.
final class FileWatcher {

    private let url: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "io.dhruvex.readmelens.filewatcher")

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var debounce: DispatchWorkItem?
    private var rearmAttempts = 0

    /// How long to coalesce events from one save.
    private let debounceInterval: DispatchTimeInterval = .milliseconds(120)
    /// How long to wait for a replaced file to reappear, and how many times.
    private let rearmDelay: DispatchTimeInterval = .milliseconds(80)
    private let maximumRearmAttempts = 25

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit { stopSources() }

    func start() {
        queue.async { [weak self] in self?.arm() }
    }

    func stop() {
        queue.async { [weak self] in
            self?.debounce?.cancel()
            self?.stopSources()
        }
    }

    // MARK: - Internals

    private func arm() {
        stopSources()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            scheduleRearm()
            return
        }
        descriptor = fd
        rearmAttempts = 0

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .attrib, .link, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            let events = source.data

            if events.contains(.rename) || events.contains(.delete) || events.contains(.revoke) {
                // Saved by atomic replace: follow the path to the new inode.
                self.rearmAttempts = 0
                self.scheduleRearm()
                self.scheduleNotify()
                return
            }
            self.scheduleNotify()
        }
        source.setCancelHandler { [fd] in close(fd) }
        self.source = source
        source.resume()
    }

    private func scheduleRearm() {
        guard rearmAttempts < maximumRearmAttempts else { return }
        rearmAttempts += 1
        queue.asyncAfter(deadline: .now() + rearmDelay) { [weak self] in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: self.url.path) {
                self.arm()
            } else {
                self.scheduleRearm()
            }
        }
    }

    private func scheduleNotify() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func stopSources() {
        source?.cancel()          // the cancel handler closes the descriptor
        source = nil
        descriptor = -1
    }
}
