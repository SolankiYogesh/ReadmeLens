import XCTest
@testable import ReadmeLens

final class HTMLParserTests: XCTestCase {

    private func firstElement(_ html: String) -> HTMLElement? {
        for node in HTMLParser.parse(html) {
            if case let .element(element) = node { return element }
        }
        return nil
    }

    func testSimpleElementWithText() {
        let element = firstElement("<p>hello</p>")
        XCTAssertEqual(element?.tag, "p")
        XCTAssertEqual(element?.children.plainText, "hello")
    }

    func testAttributeQuotingVariants() {
        let element = firstElement("<img src=\"a.png\" alt='logo' width=120>")
        XCTAssertEqual(element?.attribute("src"), "a.png")
        XCTAssertEqual(element?.attribute("alt"), "logo")
        XCTAssertEqual(element?.attribute("width"), "120")
    }

    func testTagAndAttributeNamesAreLowercased() {
        let element = firstElement("<DIV ALIGN=\"CENTER\">x</DIV>")
        XCTAssertEqual(element?.tag, "div")
        XCTAssertEqual(element?.attribute("align"), "CENTER")
        XCTAssertEqual(element?.alignment, .center)
    }

    func testVoidElementsDoNotSwallowSiblings() {
        let nodes = HTMLParser.parse("<br>after")
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.plainText, "after")
    }

    func testSelfClosingTag() {
        let element = firstElement("<img src='a.png' />")
        XCTAssertEqual(element?.tag, "img")
        XCTAssertEqual(element?.attribute("src"), "a.png")
    }

    func testNesting() {
        let element = firstElement("<div><a href='u'><img src='i'></a></div>")
        XCTAssertEqual(element?.tag, "div")
        guard case let .element(anchor)? = element?.children.first else {
            return XCTFail("expected nested <a>")
        }
        XCTAssertEqual(anchor.tag, "a")
        XCTAssertEqual(anchor.attribute("href"), "u")
        guard case let .element(image)? = anchor.children.first else {
            return XCTFail("expected nested <img>")
        }
        XCTAssertEqual(image.tag, "img")
    }

    /// README HTML is routinely malformed; none of it may throw or lose text.
    func testUnclosedTagIsClosedImplicitly() {
        let element = firstElement("<p>dangling")
        XCTAssertEqual(element?.tag, "p")
        XCTAssertEqual(element?.children.plainText, "dangling")
    }

    func testStrayClosingTagIsIgnored() {
        let nodes = HTMLParser.parse("hello</div> world")
        XCTAssertEqual(nodes.plainText, "hello world")
    }

    func testCommentsAreDropped() {
        XCTAssertEqual(HTMLParser.parse("a<!-- hidden -->b").plainText, "ab")
    }

    /// A viewer must never surface script or style content.
    func testScriptAndStyleAreDiscardedWithContents() {
        XCTAssertEqual(HTMLParser.parse("<script>alert(1)</script>ok").plainText, "ok")
        XCTAssertEqual(HTMLParser.parse("<style>.a{}</style>ok").plainText, "ok")
        XCTAssertEqual(HTMLParser.parse("<iframe src='x'></iframe>ok").plainText, "ok")
    }

    func testLoneLessThanIsTreatedAsText() {
        XCTAssertEqual(HTMLParser.parse("5 < 7").plainText, "5 < 7")
    }

    func testNamedAndNumericEntities() {
        XCTAssertEqual(HTMLEntities.decode("a &amp; b"), "a & b")
        XCTAssertEqual(HTMLEntities.decode("&lt;tag&gt;"), "<tag>")
        XCTAssertEqual(HTMLEntities.decode("&#65;&#x42;"), "AB")
        XCTAssertEqual(HTMLEntities.decode("&nbsp;"), "\u{00A0}")
        XCTAssertEqual(HTMLEntities.decode("caf&eacute;"), "caf&eacute;")  // unknown, left alone
    }

    func testUnknownTagKeepsItsChildren() {
        let nodes = HTMLParser.parse("<custom-tag>inner</custom-tag>")
        XCTAssertEqual(nodes.plainText, "inner")
    }

    /// The exact shape that opens ollama's README.
    func testCentredLogoBlockFromRealReadme() {
        let html = """
        <p align="center">
          <a href="https://ollama.com">
            <img src="https://example.com/logo.png" alt="ollama" width="200">
          </a>
        </p>
        """
        let element = firstElement(html)
        XCTAssertEqual(element?.tag, "p")
        XCTAssertEqual(element?.alignment, .center)

        var foundImage: HTMLElement?
        func walk(_ nodes: [HTMLNode]) {
            for node in nodes {
                if case let .element(e) = node {
                    if e.tag == "img" { foundImage = e }
                    walk(e.children)
                }
            }
        }
        walk(element.map { [.element($0)] } ?? [])
        XCTAssertEqual(foundImage?.attribute("src"), "https://example.com/logo.png")
        XCTAssertEqual(foundImage?.attribute("width"), "200")
    }

    func testDetailsSummaryStructure() {
        let element = firstElement("<details><summary>More</summary><p>body</p></details>")
        XCTAssertEqual(element?.tag, "details")
        guard case let .element(summary)? = element?.children.first else {
            return XCTFail("expected <summary>")
        }
        XCTAssertEqual(summary.tag, "summary")
        XCTAssertEqual(summary.children.plainText, "More")
    }
}
