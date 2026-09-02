# ReadmeLens

A fast, native macOS viewer for Markdown — built for reading READMEs, with a
GitHub-accurate dark theme.

**Read-only by design.** ReadmeLens opens and renders files; it can never write
to them.

## Status

Phases 0–2 are complete and building.

| Phase | Scope | Status |
|:--|:--|:--|
| 0 | Project scaffold, sandbox entitlements, document types | Done |
| 1 | Markdown parse pipeline → identified render blocks | Done |
| 2 | Theme token engine + GitHub Dark / Light / Dracula | Done |
| 3 | Theme-aware syntax highlighting | Planned |
| 4 | Mermaid diagrams (bundled, offline) | Planned |
| 5 | Table-of-contents sidebar + in-document search | Planned |
| 6 | File open, drag-drop, auto-reload on save | Planned |
| 7 | Load a README straight from a GitHub URL | Planned |
| 8 | Settings window + full theme gallery | Planned |
| 9 | Zoom, reading mode, app icon, release build | Planned |

## What works today

- CommonMark + GitHub-Flavored Markdown via Apple's `swift-markdown`
- Headings with GitHub's top-two-level rules, and stable anchors
- Bold, italic, strikethrough, inline code, links, nested emphasis
- Bullet, ordered, nested and task lists
- Tables with per-column alignment
- Block quotes, and `> [!NOTE]`-style alerts as native callouts
- Fenced code blocks with language tag and copy button
- Three themes, switchable from the **Theme** menu

## Build

Requires Xcode 15+ and macOS 14+.

```bash
brew install xcodegen        # once
xcodegen generate
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens build
```

Or open `ReadmeLens.xcodeproj` and press ⌘R.

Run the tests with:

```bash
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens \
  -destination 'platform=macOS' test
```

## Architecture

```
file / URL
  → swift-markdown        parse to AST
  → BlockFlattener        AST to [RenderBlock] with stable ids
  → SwiftUI LazyVStack    one view per block kind
  → Theme                 all colour resolved here, never in a view
```

Two rules hold the design together:

1. **No view names a colour.** Every view reads tokens from
   `@Environment(\.theme)`. Adding a theme is one more `Theme` instance and no
   code change.
2. **The model is theme-free.** Inline text is stored as styled spans, not a
   pre-coloured `AttributedString`, so switching theme is a re-render rather
   than a re-parse.

Block ids are assigned at flatten time and are what the table of contents,
search, and scroll-preserving reload will all address.

## Credits

Inspired by [QuickMD](https://github.com/b451c/quickmd). This is an independent
implementation, not a fork.

Theme palettes follow the published [GitHub Primer](https://primer.style/) and
[Dracula](https://draculatheme.com/) colour schemes, both MIT licensed.

## License

MIT — see [LICENSE](LICENSE).
