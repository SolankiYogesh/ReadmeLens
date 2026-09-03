import AppKit
import PDFKit
import SwiftUI

/// Renders the document to PDF, and prints via the system panel.
///
/// The obvious approach — handing an `NSHostingView` to `NSPrintOperation` —
/// produces the right number of blank pages: SwiftUI does not draw into a
/// print context. So the document is rendered with `ImageRenderer` into a PDF
/// context first, sliced into pages, and that PDF is what gets printed.
///
/// Printing goes through the system panel rather than writing a file, so the
/// panel's **PDF ▸ Save as PDF** produces the file and the print system does
/// the writing. ReadmeLens keeps its read-only sandbox and never asks for
/// permission to write anywhere.
@MainActor
enum DocumentPrinter {

    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter
    private static let margin: CGFloat = 40

    static func print(
        blocks: [RenderBlock],
        theme: Theme,
        typography: Typography,
        title: String,
        document: DocumentModel,
        search: SearchModel
    ) {
        guard let data = makePDF(
            blocks: blocks, theme: theme, typography: typography,
            document: document, search: search
        ), let pdf = PDFDocument(data: data) else { return }

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0

        // PDFKit knows how to paginate a PDF for the printer; the layout work
        // is already done by the time it gets here.
        guard let operation = pdf.printOperation(
            for: info, scalingMode: .pageScaleDownToFit, autoRotate: false
        ) else { return }

        operation.jobTitle = title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    /// Renders the document into a paginated PDF.
    ///
    /// Exposed so it can be exercised without a print panel.
    static func makePDF(
        blocks: [RenderBlock],
        theme: Theme,
        typography: Typography,
        document: DocumentModel,
        search: SearchModel
    ) -> Data? {
        guard !blocks.isEmpty else { return nil }

        // Print on a light ground whatever the reading theme: a dark canvas
        // wastes ink and reads poorly on paper.
        let printTheme = theme.appearance == .light ? theme : .githubLight
        let contentWidth = pageSize.width - margin * 2
        let contentHeight = pageSize.height - margin * 2

        let root = PrintableDocument(blocks: blocks)
            .environment(\.theme, printTheme)
            .environment(\.typography, typography)
            .environmentObject(document)
            .environmentObject(search)
            .frame(width: contentWidth)

        let renderer = ImageRenderer(content: root)
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)

        var totalHeight: CGFloat = 0
        renderer.render { size, _ in totalHeight = size.height }
        guard totalHeight > 0 else { return nil }

        let pageCount = max(1, Int(ceil(totalHeight / contentHeight)))
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        for page in 0..<pageCount {
            context.beginPDFPage(nil)
            context.saveGState()

            // White behind every page, so a transparent canvas does not print
            // as whatever the printer assumes.
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))

            // ImageRenderer already flips for a PDF context, so no scaleBy
            // here — adding one renders the document bottom-up.
            //
            // Unflipped, the rendered content spans y = 0 (its bottom) to
            // y = totalHeight (its top). Page 0 must show the topmost band,
            // so the content is shifted down by everything below that band.
            context.clip(to: CGRect(
                x: margin, y: margin, width: contentWidth, height: contentHeight
            ))
            context.translateBy(
                x: margin,
                y: margin - totalHeight + CGFloat(page + 1) * contentHeight
            )

            renderer.render { _, draw in draw(context) }

            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }
}

/// The document laid out for paper: no sidebar, search bar or scroll view.
private struct PrintableDocument: View {
    let blocks: [RenderBlock]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                BlockView(block: block)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.canvas)
    }
}
