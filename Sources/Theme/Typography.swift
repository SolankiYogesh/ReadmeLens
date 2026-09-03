import SwiftUI

/// Type sizes and reading measure for the document.
///
/// An instance rather than constants, so settings and zoom can change it and
/// every view re-renders from the environment.
struct Typography: Equatable {
    var body: CGFloat = 15
    var code: CGFloat = 13
    var contentMaxWidth: CGFloat = 1012   // GitHub's own reading measure

    static let `default` = Typography()

    /// Heading sizes scale with body text so zoom and the size setting move
    /// the whole hierarchy together rather than only paragraphs.
    func headingSize(_ level: Int) -> CGFloat {
        let multiplier: CGFloat
        switch level {
        case 1:  multiplier = 2.0
        case 2:  multiplier = 1.55
        case 3:  multiplier = 1.28
        case 4:  multiplier = 1.07
        case 5:  multiplier = 0.94
        default: multiplier = 0.88
        }
        return (body * multiplier).rounded()
    }

    func scaled(by zoom: CGFloat) -> Typography {
        Typography(
            body: (body * zoom).rounded(),
            code: (code * zoom).rounded(),
            contentMaxWidth: contentMaxWidth
        )
    }
}

private struct TypographyKey: EnvironmentKey {
    static let defaultValue: Typography = .default
}

extension EnvironmentValues {
    var typography: Typography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}
