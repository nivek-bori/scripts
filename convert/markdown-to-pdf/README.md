# Markdown to PDF

Print-focused conversion of academic Markdown notes using Pandoc's parser and
Typst's PDF engine.

## Requirements

- Pandoc 3.x: `brew install pandoc`
- Typst: `brew install typst`

## Command

```sh
convert/markdown-to-pdf/md-to-pdf notes.md
convert/markdown-to-pdf/md-to-pdf notes.md handout.pdf
convert/markdown-to-pdf/md-to-pdf --force --output handout.pdf notes.md
convert/markdown-to-pdf/md-to-pdf --font-size 11pt notes.md
```

Defaults:

- output: `~/Downloads/<input-basename>.pdf`;
- format: the single `style.typ` file (10 pt Charter by default);
- page numbers: centered footer;
- paper: US Letter.

The script resolves its template and filter relative to itself, so it works
from any current directory and can be called directly from Raycast. On success,
stdout contains only the absolute output PDF path; errors use stderr and a
nonzero exit status. Use `--force` when a Raycast command should replace an
existing PDF without prompting.

## Single format

Edit `style.typ` to change the font, margins, line spacing, list spacing,
headings, tables, or code blocks. Every conversion uses this file; there is
no style selector or default-style configuration.

The Raycast command accepts a Markdown file path and a font-size dropdown
(default, 8, 9, 10, or 11 pt). It replaces an existing output PDF. The CLI
accepts the same four explicit sizes through `--font-size` and requires
`--force` to replace an existing PDF.

A document's Pandoc metadata can still override `mainfont`, `mathfont`,
`codefont`, `fontsize`, or `margin` when a one-off exception is needed.

## Page breaks

The converter maps any of these standalone Markdown forms to a Typst page
break:

```markdown
\newpage
```

```markdown
<!-- pagebreak -->
```

```markdown
::: {.pagebreak}
:::
```

Headings are also kept with the content that follows them, preventing a heading
from being stranded at the foot of a page. No automatic break is inserted
before every top-level heading, which avoids partially empty pages in short
notes.

## Markdown metadata

Standard Pandoc YAML metadata remains supported. The template defaults can be
overridden per document when needed:

```yaml
---
title: Linear Algebra Review
author: Student Name
date: 2026-10-12
toc: true
section-numbering: 1.1
---
```

Relative image paths resolve from the Markdown file's directory. The source
Markdown and referenced assets are read-only inputs and are never rewritten.
Pandoc warnings fail the conversion, so unsupported constructs or missing
resources cannot silently disappear from a seemingly successful PDF.

