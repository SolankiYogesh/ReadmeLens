import SwiftUI

/// User-adjustable presentation: type sizes, reading measure, zoom.
@MainActor
final class AppSettings: ObservableObject {

    @Published var bodySize: Double { didSet { persist(bodySize, "bodySize") } }
    @Published var codeSize: Double { didSet { persist(codeSize, "codeSize") } }
    @Published var contentWidth: Double { didSet { persist(contentWidth, "contentWidth") } }
    @Published var zoom: Double { didSet { persist(zoom, "zoom") } }
    @Published var isReadingMode: Bool { didSet { persist(isReadingMode, "readingMode") } }

    static let bodyRange: ClosedRange<Double> = 11...24
    static let codeRange: ClosedRange<Double> = 9...20
    static let widthRange: ClosedRange<Double> = 560...1600
    static let zoomRange: ClosedRange<Double> = 0.6...2.0

    /// Narrower measure for reading mode — long lines are the main thing that
    /// makes a wide window tiring to read.
    private static let readingWidth: Double = 720

    private static let defaults: [String: Double] = [
        "bodySize": 15, "codeSize": 13, "contentWidth": 1012, "zoom": 1.0,
    ]

    init() {
        let store = UserDefaults.standard
        for (key, value) in Self.defaults where store.object(forKey: Self.key(key)) == nil {
            store.set(value, forKey: Self.key(key))
        }
        bodySize = store.double(forKey: Self.key("bodySize"))
        codeSize = store.double(forKey: Self.key("codeSize"))
        contentWidth = store.double(forKey: Self.key("contentWidth"))
        zoom = store.double(forKey: Self.key("zoom"))
        isReadingMode = store.bool(forKey: Self.key("readingMode"))
    }

    var typography: Typography {
        Typography(
            body: CGFloat(bodySize),
            code: CGFloat(codeSize),
            contentMaxWidth: CGFloat(isReadingMode ? Self.readingWidth : contentWidth)
        )
        .scaled(by: CGFloat(zoom))
    }

    // MARK: Zoom

    func zoomIn()  { zoom = min(Self.zoomRange.upperBound, (zoom + 0.1).rounded(to: 0.05)) }
    func zoomOut() { zoom = max(Self.zoomRange.lowerBound, (zoom - 0.1).rounded(to: 0.05)) }
    func resetZoom() { zoom = 1.0 }

    var zoomLabel: String { "\(Int((zoom * 100).rounded()))%" }

    func restoreDefaults() {
        bodySize = Self.defaults["bodySize"]!
        codeSize = Self.defaults["codeSize"]!
        contentWidth = Self.defaults["contentWidth"]!
        zoom = 1.0
        isReadingMode = false
    }

    // MARK: Storage

    private static func key(_ name: String) -> String { "settings.\(name)" }

    private func persist(_ value: Double, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }

    private func persist(_ value: Bool, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }
}

private extension Double {
    /// Keeps zoom on tidy steps so repeated presses don't accumulate drift.
    func rounded(to step: Double) -> Double {
        (self / step).rounded() * step
    }
}
