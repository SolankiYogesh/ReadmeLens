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

## HTML in READMEs

Four out of five real-world READMEs use raw HTML — centred logos, badge rows,
`<details>` sections, `<kbd>` keys. ReadmeLens renders a safe subset of it
rather than printing the source.

<div align="center">

**This block is centred by a `<div align="center">` wrapper.**

</div>

Inline tags work too: press <kbd>⌘O</kbd> to open a file, H<sub>2</sub>O for
subscripts, and <b>bold</b> or <i>italic</i> via tags.

<details>
<summary>A collapsible section</summary>

`<details>` becomes a real disclosure triangle, so long READMEs stay navigable.
Click the heading above to fold this away again.

</details>

Nothing here is executed. `<script>`, `<style>` and `<iframe>` are discarded
outright, and no web view is involved.

## Navigation

Links to other files open in place — press <kbd>⌘[</kbd> to go back and
<kbd>⌘]</kbd> to go forward, or use the toolbar arrows. Links to a heading
scroll there without leaving the document.

Local images resolve against the folder the document lives in. Because the app
is sandboxed, the first document that needs it will offer a one-time folder
grant.

## Live preview

Keep this window beside your editor. Saving the file refreshes the view in
place, keeping your position in the document — a brief **Updated** badge
confirms it happened.

Editors that save by writing a temporary file and renaming it over the original
are handled too, which is most of them. Toggle the behaviour with
<kbd>⇧⌘R</kbd>.

## Finding your way

Long READMEs get an **outline** down the left: click a heading to jump, and the
current section stays marked as you scroll. Toggle it with <kbd>⌥⌘S</kbd>.

Press <kbd>⌘F</kbd> to search the document. Matches are highlighted in place —
including inside code blocks — with the current one picked out more brightly.
<kbd>⌘G</kbd> and <kbd>⇧⌘G</kbd> step through them.

## Quick Look

Select any `.md` file in Finder and press <kbd>Space</kbd> — it renders there,
without launching this app. The extension ships inside the app bundle and
shares the same parser, themes and renderers.

It follows your system appearance rather than the theme chosen here: an
extension runs in its own sandbox container and cannot read the app's
preferences.

## Making it yours

<kbd>⌘,</kbd> opens Settings: pick a theme, set body and code sizes, choose the
column width, and turn on reading mode for a narrower measure.

<kbd>⌘+</kbd> and <kbd>⌘−</kbd> zoom, <kbd>⌘0</kbd> returns to actual size.

Drop a `.json` file into the themes folder — Settings ▸ Themes shows where —
and it appears in the picker straight away. **Export Current Theme as JSON**
gives you a complete file to edit. A theme that fails to load is reported by
name, field and value rather than being ignored.

<kbd>⌘P</kbd> — or the printer button in the toolbar — prints, and the print
panel's **PDF ▸ Save as PDF** is how you get a PDF. The print system does the writing, so this app still never needs
permission to write anything.

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
- [x] Inline and block HTML
- [x] Local images, relative links, anchors
- [x] Syntax highlighting
- [x] Auto-reload on save
- [x] Table of contents & search
- [x] Quick Look preview
- [x] Settings window & custom themes
- [x] Printing and PDF
- [ ] Mermaid diagrams

## Tables

| Feature | Status | Phase |
|:--------|:------:|------:|
| Block parsing | Done | 1 |
| Themes (9) | Done | 2 |
| HTML rendering | Done | 3 |
| Links & local images | Done | 4 |
| Syntax highlighting | Done | 5 |
| Auto-reload | Done | 6 |
| Outline & search | Done | 7 |
| Quick Look | Done | 8 |
| Settings & custom themes | Done | 9 |
| Printing & PDF | Done | 10 |
| Search & TOC | Pending | 7 |

## Code

Fenced blocks keep their language tag, colour themselves from the active theme,
and reveal a copy button on hover.

```swift
/// Resolves a token kind to a colour from the active theme.
func syntaxColor(_ kind: TokenKind) -> Color {
    let fallback = 0xE6EDF3
    return syntax[kind] ?? Color(hex: fallback)
}
```

```python
def summarise(counts: dict[str, int], limit: float = 0.5) -> list[str]:
    # keep only the entries worth reporting
    return [name for name, n in counts.items() if n > limit]
```

```typescript
export async function load(url: string): Promise<Theme[]> {
  const response = await fetch(url);   // network
  if (!response.ok) throw new Error(`failed: ${response.status}`);
  return response.json();
}
```

```bash
# build and run the tests
xcodebuild -project ReadmeLens.xcodeproj -scheme ReadmeLens test
```

```json
{ "theme": "github-dark", "fontSize": 15, "followSystem": false }
```

```sql
SELECT name, count(*) AS uses FROM themes WHERE active = true GROUP BY name;
```

Around twenty languages are recognised. An unknown tag renders plain rather
than guessing.

## Quotes

> A block quote renders with a left rule and muted text.
>
> It can span several paragraphs.

## Roadmap

Every planned phase is done. What is left is the deliberately deferred: Mermaid
diagrams, which appeared in none of the 18 real READMEs measured, and LaTeX
maths.

---

MIT licensed. Theme palettes follow the published GitHub Primer and Dracula
colour schemes, both MIT licensed.
