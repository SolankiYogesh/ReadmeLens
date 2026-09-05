import SwiftUI

/// Where the reader currently is in the document.
///
/// Deliberately its own object rather than a field on `DocumentModel`. This
/// value changes continuously while scrolling, and anything observing the
/// object that holds it is rebuilt just as often. Kept here, a scroll only
/// invalidates the outline sidebar — a few dozen rows — instead of the whole
/// document body.
@MainActor
final class ViewportModel: ObservableObject {
    /// `scrollID` of the topmost block still in view.
    @Published var topVisibleBlockID: String?
}

// MARK: - Environment

/// Lets the scrolling document *write* the cursor without subscribing to it.
/// Readers use `@EnvironmentObject` and re-render; the writer uses this and
/// does not.
private struct ViewportKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ViewportModel()
}

extension EnvironmentValues {
    var viewport: ViewportModel {
        get { self[ViewportKey.self] }
        set { self[ViewportKey.self] = newValue }
    }
}
