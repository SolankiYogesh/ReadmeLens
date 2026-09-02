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
    case htmlBlock(String)
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
}
