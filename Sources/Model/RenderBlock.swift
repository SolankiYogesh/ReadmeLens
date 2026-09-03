import Foundation

struct ListItemModel: Identifiable, Hashable {
    let id: Int
    /// `nil` for a plain bullet; set for GFM task-list checkboxes.
    var checked: Bool?
    var blocks: [RenderBlock]
}

struct ListModel: Hashable {
    var isOrdered: Bool
    var start: Int
    var isTight: Bool
    var items: [ListItemModel]
}

enum ColumnAlignment: Hashable { case leading, center, trailing }

struct TableModel: Hashable {
    var alignments: [ColumnAlignment]
    var header: [InlineText]
    var rows: [[InlineText]]
    var hasHeader: Bool { !header.isEmpty && !header.allSatisfy(\.isEmpty) }
}

struct ImageModel: Hashable {
    var source: String
    var alt: String
    var title: String?
}

indirect enum BlockKind: Hashable {
    case heading(level: Int, text: InlineText, anchor: String)
    case paragraph(InlineText)
    case code(language: String?, source: String)
    case mermaid(source: String)
    case quote(blocks: [RenderBlock], depth: Int)
    case alert(kind: AlertKind, blocks: [RenderBlock])
    case list(ListModel)
    case table(TableModel)
    case rule
    case image(ImageModel)
    case html([HTMLNode])

    /// A run of blocks wrapped by an HTML element that spans them, such as the
    /// `<div align="center">` header most READMEs open with.
    case container(alignment: HTMLAlignment?, blocks: [RenderBlock])

    /// `<details>` wrapping Markdown, collapsed behind its `<summary>`.
    case disclosure(summary: [HTMLNode], blocks: [RenderBlock])

    // Markers emitted when an HTML element opens in one CommonMark block and
    // closes in a later one. `BlockFlattener` folds them into `.container`
    // before the views ever run.
    case htmlOpen(HTMLElement)
    case htmlClose(String)
}

/// One renderable unit of the document.
///
/// `id` is a stable ordinal assigned at flatten time. Table-of-contents
/// scroll-to, search hit addressing and scroll-position-preserving reload all
/// key off it, which is why it lives on the model rather than being derived in
/// the view layer.
struct RenderBlock: Identifiable, Hashable {
    let id: Int
    let kind: BlockKind

    /// Identity used by the scrolling list.
    ///
    /// Headings key off their anchor so `[jump](#install)` can address them;
    /// everything else uses its ordinal. The `#` prefix keeps the two spaces
    /// from ever colliding.
    var scrollID: String {
        if case let .heading(_, _, anchor) = kind { return "#\(anchor)" }
        return "b\(id)"
    }
}
