<div align="center">

<img src="docs/icon.png" width="128" alt="ReadmeLens icon">

# ReadmeLens

**A fast, native macOS viewer for Markdown — built for reading READMEs.**

Open a `.md` file and read it the way GitHub renders it. No browser, no dev
server, no Electron.

[![CI](https://github.com/SolankiYogesh/ReadmeLens/actions/workflows/ci.yml/badge.svg)](https://github.com/SolankiYogesh/ReadmeLens/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/SolankiYogesh/ReadmeLens?color=4493f8)](https://github.com/SolankiYogesh/ReadmeLens/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/SolankiYogesh/ReadmeLens/total?color=3fb950)](https://github.com/SolankiYogesh/ReadmeLens/releases)
[![Platform](https://img.shields.io/badge/macOS-14%2B-informational)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-fa7343)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

<img src="docs/screenshot-github-dark.png" width="880" alt="ReadmeLens rendering a document in the GitHub Dark theme">

</div>

---

## Why

Most Markdown previewers either ship a whole browser engine or render something
that looks nothing like GitHub. ReadmeLens is a small native app that does one
job properly.

> **Read-only by design.** ReadmeLens opens and renders files. It has no editor,
> no save path, and no write entitlement — it *cannot* modify your files.

- **Native and small.** SwiftUI + AppKit, a ~5 MB app, instant cold start.
- **GitHub-accurate.** Alerts, task lists, table alignment, heading rules — and
  the raw HTML that four out of five real READMEs depend on.
- **Nine themes**, switchable from a single dot in the toolbar.
- **Private.** No network calls, no analytics, no telemetry.

## Themes

Click the coloured dot in the toolbar to open the palette. The dot always wears
the current theme's accent colour, so you can tell your theme at a glance.

| | |
|:--:|:--:|
| **Tokyo Night** | **Dracula** |
| <img src="docs/screenshot-tokyo-night.png" alt="Tokyo Night theme"> | <img src="docs/screenshot-dracula.png" alt="Dracula theme"> |
| **Solarized Light** | **GitHub Dark** |
| <img src="docs/screenshot-solarized-light.png" alt="Solarized Light theme"> | <img src="docs/screenshot-github-dark.png" alt="GitHub Dark theme"> |

Also bundled: **GitHub Light**, **Nord**, **Gruvbox Dark**, **Solarized Dark**
and **Catppuccin Mocha** — plus **Follow System**, which swaps between your
chosen light and dark pairing as macOS changes appearance.

## Install

### Download

Grab the latest `.zip` from the
[**Releases**](https://github.com/SolankiYogesh/ReadmeLens/releases/latest)
page, unarchive it, and drag **ReadmeLens.app** into `/Applications`.

Builds are unsigned, so macOS blocks them on first launch. Right-click the app
and choose **Open**, then confirm — or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/ReadmeLens.app
```

### Build from source

Requires **Xcode 15+** and **macOS 14+**.

```bash
git clone https://github.com/SolankiYogesh/ReadmeLens.git
cd ReadmeLens

brew install xcodegen     # once
xcodegen generate
open ReadmeLens.xcodeproj # then press ⌘R
```

Or straight from the command line:

```bash
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens build
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens \
  -destination 'platform=macOS' test
```

The app icon is generated rather than committed as opaque bitmaps — edit
`Tools/GenerateAppIcon.swift` and re-run it to change the artwork:

```bash
swift Tools/GenerateAppIcon.swift Resources/Assets.xcassets/AppIcon.appiconset
```

## Usage

| Action | How |
|:--|:--|
| Open a file | `⌘O`, drop a `.md` on the window, or double-click one in Finder |
| Open from a terminal | `open -a ReadmeLens README.md` |
| Follow a link to another file | Click it — it opens in place |
| Go back / forward | `⌘[` / `⌘]`, or the toolbar arrows |
| Jump to a heading | Click any `#anchor` link |
| Switch theme | Click the dot in the toolbar |
| Copy a code block | Hover it, then click the copy button |

### Local files and the sandbox

ReadmeLens is sandboxed, so opening a file grants access to *that file only* —
not the folder around it. The first time a document references a local image or
links to a sibling file, a banner offers a one-time **Grant Access** for the
folder. The grant is remembered, and covers everything beneath it, so opening a
repo root once is enough for the whole project.

Relative paths are confined to the document's folder; a link that would escape
it is refused.

## Supported Markdown

CommonMark plus GitHub-Flavored Markdown, parsed with
[apple/swift-markdown](https://github.com/apple/swift-markdown).

- Headings, with GitHub's rules under `h1`/`h2`, and stable anchors
- **Bold**, *italic*, ***both***, ~~strikethrough~~, `inline code`, links
- Bullet, ordered, nested and task lists
- Tables with per-column alignment
- Block quotes, and `> [!NOTE]` alerts as native callouts
- Fenced code blocks with a language tag and copy button
- Images — remote, and local ones resolved against the document's folder
- Links — external, in-page anchors, and relative paths to other documents
- Autolinks, CRLF and legacy line endings

### HTML

READMEs lean on raw HTML far more than people expect. Measured across 18 popular
projects (React, Next.js, ollama, VS Code, Supabase, HuggingFace, uv, Vite and
others): `<img>` appeared in **83%**, block-level `<div>`/`<p align>` in **77%**,
and `<a>` in **66%**. Rendering those as literal source makes most READMEs open
with a wall of markup, so ReadmeLens renders a safe subset instead:

- `<div>` / `<p align="center">` / `<center>` wrappers, **including when they
  wrap Markdown** and CommonMark splits them across blocks
- `<img>` with `width`, `<picture>`, and `<a>` around them — badge rows flow and
  wrap like a browser line-box
- `<details>` / `<summary>` as a real disclosure triangle
- `<b>`, `<i>`, `<code>`, `<kbd>`, `<sub>`, `<sup>`, `<br>`, `<h1>`–`<h6>`,
  `<ul>`/`<ol>`, `<blockquote>`, `<table>`
- HTML entities, and malformed markup — unclosed tags, stray closers, unquoted
  attributes all degrade to something readable

**Nothing is executed.** There is no web view. `<script>`, `<style>`,
`<iframe>`, `<object>` and `<embed>` are discarded along with their contents.

Known gap: `<sub>`/`<sup>` inside a Markdown paragraph render at normal
baseline; inside an HTML block they shift correctly.

## Roadmap

| Phase | Scope | Status |
|:--|:--|:--|
| 0 | Project scaffold, sandbox, document types | ✅ Done |
| 1 | Markdown parse pipeline → identified render blocks | ✅ Done |
| 2 | Theme token engine, nine themes, toolbar switcher | ✅ Done |
| 3 | Safe HTML subset, image loading | ✅ Done |
| 4 | Local images, relative links, anchors, Finder open | ✅ Done |
| 5 | Theme-aware syntax highlighting | ⏳ Next |
| 6 | Auto-reload on save | ⏳ Planned |
| 7 | Table-of-contents sidebar, in-document search | ⏳ Planned |
| 8 | Quick Look extension — preview `.md` from Finder | ⏳ Planned |
| 9 | Settings window, custom themes from disk | ⏳ Planned |
| 10 | Export to PDF, zoom, reading mode | ⏳ Planned |

Mermaid and LaTeX were originally scheduled early; measuring the corpus showed
**neither appears in any of the 18 READMEs sampled**, so they were demoted below
work that affects most documents.

## Architecture

```
file / URL
  → swift-markdown        parse to an AST
  → BlockFlattener        AST → [RenderBlock], each with a stable id
  → SwiftUI LazyVStack    one view per block kind
  → Theme                 every colour resolved here, never in a view
```

Two rules hold the design together:

**1. No view names a colour.** Every view reads tokens from
`@Environment(\.theme)`. Adding a theme is one more `Theme` instance in
`BuiltinThemes.swift` and no code change anywhere else — which is exactly how
the nine bundled themes were added.

**2. The model is theme-free.** Inline text is stored as styled spans rather
than a pre-coloured `AttributedString`, so switching theme is a re-render, never
a re-parse.

Block ids are assigned once at flatten time, and are what the table of contents,
search highlighting and scroll-preserving reload all address.

```
Sources/
├── App/         entry point, document model, theme store
├── Model/       RenderBlock, InlineText
├── Parser/      AST → blocks, inline flattening
├── Theme/       token contract + the nine bundled themes
└── Views/       one renderer per block kind
```

## Releasing

Releases are cut by pushing a tag. The
[workflow](.github/workflows/release.yml) builds a universal Release binary,
zips the `.app`, writes a checksum, and publishes it with generated notes.

```bash
git tag v0.2.0
git push origin v0.2.0
```

## Credits

Inspired by [QuickMD](https://github.com/b451c/quickmd). ReadmeLens is an
independent implementation, not a fork.

Theme palettes follow the published colour schemes of
[GitHub Primer](https://primer.style/),
[Dracula](https://draculatheme.com/),
[Nord](https://www.nordtheme.com/),
[Gruvbox](https://github.com/morhetz/gruvbox),
[Solarized](https://ethanschoonover.com/solarized/),
[Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) and
[Catppuccin](https://catppuccin.com/) — all MIT licensed.

## License

[MIT](LICENSE) © Yogesh Solanki
