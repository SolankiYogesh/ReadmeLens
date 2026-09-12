import XCTest
@testable import ReadmeLens

final class MermaidHTMLBuilderTests: XCTestCase {

    func testSourceIsEmbeddedAsAnEscapedJSONString() {
        let html = MermaidHTMLBuilder.document(source: "graph TD;\nA-->B;", theme: .githubDark)
        XCTAssertTrue(html.contains(#"mermaid.render("generated-diagram", "graph TD;\nA-->B;")"#))
    }

    func testQuotesAndBackslashesInSourceAreEscaped() {
        let html = MermaidHTMLBuilder.document(source: #"A["quoted \ label"]"#, theme: .githubDark)
        XCTAssertTrue(html.contains(#"A[\"quoted \\ label\"]"#))
    }

    func testThemeColoursFlowIntoThemeVariables() {
        let html = MermaidHTMLBuilder.document(source: "graph TD;", theme: .githubDark)
        XCTAssertTrue(html.contains(Theme.githubDark.canvas.hexString))
        XCTAssertTrue(html.contains(Theme.githubDark.fg.hexString))
    }

    func testLoadsTheVendoredMermaidBundleRatherThanACDN() {
        let html = MermaidHTMLBuilder.document(source: "graph TD;", theme: .githubDark)
        XCTAssertTrue(html.contains(#"<script src="mermaid.min.js"></script>"#))
        XCTAssertFalse(html.contains("http://"))
        XCTAssertFalse(html.contains("https://"))
    }

    func testReportsSizeAndErrorsBackThroughTheMermaidMessageHandler() {
        let html = MermaidHTMLBuilder.document(source: "graph TD;", theme: .githubDark)
        XCTAssertTrue(html.contains("window.webkit.messageHandlers.mermaid.postMessage"))
        XCTAssertTrue(html.contains(#"type: "size""#))
        XCTAssertTrue(html.contains(#"type: "error""#))
    }
}
