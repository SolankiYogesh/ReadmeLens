# ReadmeLens

A fast, native macOS viewer for Markdown — built for reading READMEs.

## Why

Open a `.md` file and read it the way GitHub renders it, without a browser and
without a running dev server. **Read-only by design**: nothing here can modify
your files.

> [!NOTE]
> This document is the built-in welcome page. Press ⌘O to open a file of your own.

> [!TIP]
> Click the coloured dot in the toolbar to switch themes. Nine ship today, and
> the dot always wears the current theme's accent colour.

> [!WARNING]
> Diagrams and syntax highlighting are not wired up yet — see the roadmap below.

## Formatting

Text can be **bold**, *italic*, ***both at once***, ~~struck through~~, or
`inline code`. Links look [like this](https://github.com) and open in your
browser.

Nested emphasis such as **bold with _italic_ inside** inherits correctly, which
is the sort of thing that quietly breaks in naive renderers.

## Lists

- Plain bullets
- With nesting
  - One level down
  - And another
- Back to the top level

1. Ordered lists
2. Count properly
3. Even when long

### Task lists

- [x] Parse Markdown into blocks
- [x] Theme token system
- [x] GitHub Dark and eight more themes
- [ ] Syntax highlighting
- [ ] Mermaid diagrams

## Tables

| Feature | Status | Phase |
|:--------|:------:|------:|
| Block parsing | Done | 1 |
| Themes (9) | Done | 2 |
| Highlighting | Pending | 3 |
| Diagrams | Pending | 4 |
| Search & TOC | Pending | 5 |

## Code

Fenced blocks keep their language tag and reveal a copy button on hover.

```swift
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let appearance: ThemeAppearance
}
```

```bash
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens build
```

```json
{ "theme": "github-dark", "fontSize": 15 }
```

## Quotes

> A block quote renders with a left rule and muted text.
>
> It can span several paragraphs.

## Roadmap

Phase 3 adds a theme-aware syntax highlighter. Phase 4 bundles Mermaid so
diagrams render offline. Phase 5 brings the table-of-contents sidebar and
in-document search. Phase 6 adds file watching, so saving in your editor
refreshes this view automatically.

---

MIT licensed. Theme palettes follow the published GitHub Primer and Dracula
colour schemes, both MIT licensed.
