import XCTest
@testable import ReadmeLens

final class FileWatcherTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("watcher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ contents: String = "one") throws -> URL {
        let url = root.appendingPathComponent("doc.md")
        try contents.write(to: url, atomically: false, encoding: .utf8)
        return url
    }

    /// Writing in place is the simple case.
    func testFiresOnInPlaceWrite() throws {
        let url = try makeFile()
        let fired = expectation(description: "watcher fired")
        fired.assertForOverFulfill = false

        let watcher = FileWatcher(url: url) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            try? "two".write(to: url, atomically: false, encoding: .utf8)
        }
        wait(for: [fired], timeout: 5)
    }

    /// The case that matters: most editors save by writing a temporary file and
    /// renaming it over the original, which replaces the inode. A watcher that
    /// only holds the original descriptor goes deaf after the first save.
    func testFiresOnAtomicReplace() throws {
        let url = try makeFile()
        let fired = expectation(description: "watcher fired on replace")
        fired.assertForOverFulfill = false

        let watcher = FileWatcher(url: url) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            // `atomically: true` is exactly the temp-write-then-rename dance.
            try? "replaced".write(to: url, atomically: true, encoding: .utf8)
        }
        wait(for: [fired], timeout: 5)
    }

    /// And it must keep working for the *second* atomic save, which is what
    /// breaks when the watch is not re-armed on the path.
    func testKeepsFiringAfterRepeatedAtomicReplaces() throws {
        let url = try makeFile()
        let fired = expectation(description: "fired twice")
        fired.expectedFulfillmentCount = 2
        fired.assertForOverFulfill = false

        let watcher = FileWatcher(url: url) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            try? "first".write(to: url, atomically: true, encoding: .utf8)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
            try? "second".write(to: url, atomically: true, encoding: .utf8)
        }
        wait(for: [fired], timeout: 8)
    }

    /// A burst of writes from one save should collapse into a single reparse.
    func testRapidWritesAreDebounced() throws {
        let url = try makeFile()
        let counter = Counter()
        let watcher = FileWatcher(url: url) { counter.increment() }
        watcher.start()
        defer { watcher.stop() }

        let settled = expectation(description: "settled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            for i in 0..<10 {
                try? "burst \(i)".write(to: url, atomically: false, encoding: .utf8)
                usleep(5_000)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { settled.fulfill() }
        }
        wait(for: [settled], timeout: 8)

        let count = counter.value
        XCTAssertGreaterThan(count, 0, "watcher never fired")
        XCTAssertLessThan(count, 10, "ten writes should not mean ten reloads")
    }

    func testStopSilencesTheWatcher() throws {
        let url = try makeFile()
        let counter = Counter()
        let watcher = FileWatcher(url: url) { counter.increment() }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        watcher.stop()
        Thread.sleep(forTimeInterval: 0.2)

        let before = counter.value
        try "after stop".write(to: url, atomically: false, encoding: .utf8)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(counter.value, before)
    }

    func testMissingFileDoesNotCrash() {
        let watcher = FileWatcher(url: root.appendingPathComponent("nope.md")) { }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        watcher.stop()
    }
}

/// Small thread-safe counter for callbacks arriving off the main queue.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock(); count += 1; lock.unlock()
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
}
