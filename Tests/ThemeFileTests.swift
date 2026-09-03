import XCTest
import SwiftUI
@testable import ReadmeLens

final class HexColorTests: XCTestCase {

    /// An array rather than a tuple: tuples are not Equatable, so
    /// XCTAssertEqual cannot compare them.
    private func components(_ color: Color) -> [Int] {
        let resolved = NSColor(color).usingColorSpace(.sRGB)!
        return [
            Int((resolved.redComponent * 255).rounded()),
            Int((resolved.greenComponent * 255).rounded()),
            Int((resolved.blueComponent * 255).rounded()),
            Int((resolved.alphaComponent * 255).rounded()),
        ]
    }

    func testParsesSixDigitHexWithAndWithoutHash() {
        XCTAssertEqual(components(Color(hexString: "#4493F8")!), [0x44, 0x93, 0xF8, 255])
        XCTAssertEqual(components(Color(hexString: "4493F8")!), [0x44, 0x93, 0xF8, 255])
    }

    func testParsesShorthandAndAlpha() {
        XCTAssertEqual(components(Color(hexString: "#F00")!), [255, 0, 0, 255])
        XCTAssertEqual(components(Color(hexString: "#00000080")!), [0, 0, 0, 128])
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(components(Color(hexString: "#aabbcc")!),
                       components(Color(hexString: "#AABBCC")!))
    }

    func testRejectsMalformedValues() {
        for bad in ["", "#", "#12", "#12345", "#GGGGGG", "not a colour", "#1234567"] {
            XCTAssertNil(Color(hexString: bad), "should reject \(bad)")
        }
    }

    func testHexStringRoundTrips() {
        for value in ["#0D1117", "#FFFFFF", "#4493F8", "#282A36"] {
            XCTAssertEqual(Color(hexString: value)!.hexString, value)
        }
    }

    func testHexStringIncludesAlphaOnlyWhenTransparent() {
        XCTAssertEqual(Color(hex: 0x112233).hexString, "#112233")
        XCTAssertEqual(Color(hex: 0x112233, opacity: 0.5).hexString.count, 9)
    }
}

final class ThemeFileTests: XCTestCase {

    private var minimal: ThemeFile {
        ThemeFile(
            id: "test-theme", name: "Test Theme", appearance: "dark",
            canvas: "#101418", foreground: "#E6EDF3", accent: "#4493F8"
        )
    }

    /// A short file must still produce a complete, usable theme.
    func testMinimalFileDerivesEveryToken() throws {
        let theme = try minimal.makeTheme()
        XCTAssertEqual(theme.id, "test-theme")
        XCTAssertEqual(theme.name, "Test Theme")
        XCTAssertEqual(theme.appearance, .dark)
        XCTAssertEqual(theme.canvas.hexString, "#101418")
        XCTAssertEqual(theme.link.hexString, "#4493F8")

        for kind in TokenKind.allCases {
            XCTAssertNotNil(theme.syntax[kind], "missing syntax .\(kind.rawValue)")
        }
        for kind in AlertKind.allCases {
            XCTAssertNotNil(theme.alerts[kind], "missing alert .\(kind.rawValue)")
        }
    }

    func testExplicitTokensOverrideDerivedOnes() throws {
        var file = minimal
        file.syntax = ["keyword": "#FF0000"]
        file.alerts = ["caution": "#00FF00"]
        let theme = try file.makeTheme()
        XCTAssertEqual(theme.syntaxColor(.keyword).hexString, "#FF0000")
        XCTAssertEqual(theme.alertColor(.caution).hexString, "#00FF00")
    }

    /// Errors must name the offending field, or a typo is untraceable.
    func testBadColorIsReportedWithItsField() {
        var file = minimal
        file.canvas = "nope"
        do {
            _ = try file.makeTheme()
            XCTFail("expected a failure")
        } catch let error as ThemeFile.LoadError {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("canvas"), message)
            XCTAssertTrue(message.contains("nope"), message)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testBadAppearanceIsRejected() {
        var file = minimal
        file.appearance = "sepia"
        XCTAssertThrowsError(try file.makeTheme())
    }

    func testNestedBadColorNamesTheKey() {
        var file = minimal
        file.syntax = ["keyword": "zzz"]
        do {
            _ = try file.makeTheme()
            XCTFail("expected a failure")
        } catch let error as ThemeFile.LoadError {
            XCTAssertTrue(error.localizedDescription.contains("syntax.keyword"),
                          error.localizedDescription)
        } catch {
            XCTFail("wrong error type")
        }
    }

    /// Export then re-import must preserve every colour, so a round-trip is a
    /// safe way to fork a bundled theme.
    func testEveryBundledThemeSurvivesAnExportImportRoundTrip() throws {
        for original in Theme.builtins {
            let restored = try ThemeFile(original).makeTheme()
            XCTAssertEqual(restored.id, original.id)
            XCTAssertEqual(restored.appearance, original.appearance)
            XCTAssertEqual(restored.canvas.hexString, original.canvas.hexString)
            XCTAssertEqual(restored.fg.hexString, original.fg.hexString)
            XCTAssertEqual(restored.link.hexString, original.link.hexString)
            XCTAssertEqual(restored.border.hexString, original.border.hexString)
            XCTAssertEqual(restored.codeBg.hexString, original.codeBg.hexString)
            for kind in TokenKind.allCases {
                XCTAssertEqual(restored.syntaxColor(kind).hexString,
                               original.syntaxColor(kind).hexString,
                               "\(original.name) .\(kind.rawValue)")
            }
            for kind in AlertKind.allCases {
                XCTAssertEqual(restored.alertColor(kind).hexString,
                               original.alertColor(kind).hexString,
                               "\(original.name) .\(kind.rawValue)")
            }
        }
    }

    func testFileDecodesFromJSON() throws {
        let json = """
        {
          "id": "midnight", "name": "Midnight", "appearance": "dark",
          "canvas": "#0A0E14", "foreground": "#B3B1AD", "accent": "#39BAE6",
          "syntax": { "keyword": "#FF8F40", "string": "#C2D94C" }
        }
        """
        let file = try JSONDecoder().decode(ThemeFile.self, from: Data(json.utf8))
        let theme = try file.makeTheme()
        XCTAssertEqual(theme.name, "Midnight")
        XCTAssertEqual(theme.syntaxColor(.keyword).hexString, "#FF8F40")
        XCTAssertEqual(theme.syntaxColor(.string).hexString, "#C2D94C")
    }
}

@MainActor
final class TypographyTests: XCTestCase {

    func testHeadingSizesScaleWithBodyText() {
        let small = Typography(body: 12)
        let large = Typography(body: 20)
        XCTAssertLessThan(small.headingSize(1), large.headingSize(1))
        XCTAssertGreaterThan(small.headingSize(1), small.headingSize(2))
        XCTAssertGreaterThan(small.headingSize(2), small.headingSize(3))
    }

    func testZoomScalesTypeButNotTheColumn() {
        let base = Typography(body: 15, code: 13, contentMaxWidth: 1000)
        let zoomed = base.scaled(by: 2)
        XCTAssertEqual(zoomed.body, 30)
        XCTAssertEqual(zoomed.code, 26)
        XCTAssertEqual(zoomed.contentMaxWidth, 1000)
    }

    func testZoomStaysWithinRange() {
        let settings = AppSettings()
        defer { settings.restoreDefaults() }

        for _ in 0..<40 { settings.zoomIn() }
        XCTAssertLessThanOrEqual(settings.zoom, AppSettings.zoomRange.upperBound)
        for _ in 0..<80 { settings.zoomOut() }
        XCTAssertGreaterThanOrEqual(settings.zoom, AppSettings.zoomRange.lowerBound)

        settings.resetZoom()
        XCTAssertEqual(settings.zoom, 1.0)
    }

    func testReadingModeNarrowsTheColumn() {
        let settings = AppSettings()
        defer { settings.restoreDefaults() }

        settings.contentWidth = 1400
        settings.isReadingMode = false
        let wide = settings.typography.contentMaxWidth
        settings.isReadingMode = true
        XCTAssertLessThan(settings.typography.contentMaxWidth, wide)
    }

    func testRestoreDefaultsResetsEverything() {
        let settings = AppSettings()
        settings.bodySize = 22
        settings.zoom = 1.8
        settings.isReadingMode = true
        settings.restoreDefaults()
        XCTAssertEqual(settings.bodySize, 15)
        XCTAssertEqual(settings.zoom, 1.0)
        XCTAssertFalse(settings.isReadingMode)
    }
}
