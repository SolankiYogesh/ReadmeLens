import XCTest
import SwiftUI
@testable import ReadmeLens

final class ThemeTests: XCTestCase {

    func testAllThemesHaveUniqueIDs() {
        let ids = Theme.builtins.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate theme id: \(ids)")
    }

    func testAllThemesHaveUniqueNames() {
        let names = Theme.builtins.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }

    /// The picker resolves themes by id; an id that does not round-trip would
    /// silently fall back to the default.
    func testEveryThemeIsResolvableByID() {
        for theme in Theme.builtins {
            XCTAssertEqual(Theme.builtin(id: theme.id)?.id, theme.id)
        }
    }

    func testUnknownIDResolvesToNil() {
        XCTAssertNil(Theme.builtin(id: "no-such-theme"))
    }

    /// A theme missing a syntax colour would render that token invisible
    /// against some backgrounds, so every theme must define all of them.
    func testEveryThemeCoversEverySyntaxToken() {
        for theme in Theme.builtins {
            for kind in TokenKind.allCases {
                XCTAssertNotNil(
                    theme.syntax[kind],
                    "\(theme.name) is missing a colour for .\(kind.rawValue)"
                )
            }
        }
    }

    func testEveryThemeCoversEveryAlertKind() {
        for theme in Theme.builtins {
            for kind in AlertKind.allCases {
                XCTAssertNotNil(
                    theme.alerts[kind],
                    "\(theme.name) is missing a colour for .\(kind.rawValue)"
                )
            }
        }
    }

    func testBothAppearancesAreRepresented() {
        let appearances = Set(Theme.builtins.map(\.appearance))
        XCTAssertTrue(appearances.contains(.dark))
        XCTAssertTrue(appearances.contains(.light))
    }

    func testGitHubDarkIsTheDefault() {
        XCTAssertEqual(Theme.githubDark.id, "github-dark")
        XCTAssertEqual(Theme.builtins.first?.id, "github-dark")
    }

    func testAutoIDDoesNotCollideWithARealTheme() {
        XCTAssertNil(Theme.builtin(id: ThemeStore.autoID))
    }

    func testHexInitialiserMapsChannelsCorrectly() {
        let resolved = NSColor(Color(hex: 0x4493F8)).usingColorSpace(.sRGB)!
        XCTAssertEqual(Double(resolved.redComponent),   0x44 / 255.0, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.greenComponent), 0x93 / 255.0, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.blueComponent),  0xF8 / 255.0, accuracy: 0.01)
    }
}
