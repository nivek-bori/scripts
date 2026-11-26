// The single style.typ file is inserted here by md-to-pdf.
$style-definition$

#set terms(hanging-indent: 1.2em)

#let horizontalRule = line(length: 50%, stroke: 0.5pt + luma(55%))
#let divider = if "divider" in std { divider } else { horizontalRule }

#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)

#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let conf(
  title: none,
  subtitle: none,
  authors: (),
  keywords: (),
  date: none,
  abstract-title: [Abstract],
  abstract: none,
  thanks: none,
  cols: 1,
  margin: style.margin,
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: style.font,
  fontsize: style.fontsize,
  mathfont: style.mathfont,
  codefont: style.codefont,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  pagenumbering: "1",
  doc,
) = {
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()

  set page(
    paper: paper,
    fill: white,
    margin: margin,
    numbering: pagenumbering,
    number-align: center + bottom,
    columns: cols,
  )
  set text(
    lang: lang,
    region: region,
    font: font,
    size: fontsize,
    hyphenate: true,
  )
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set par(
    justify: style.paragraph.justify,
    leading: linestretch * style.paragraph.leading,
    spacing: style.paragraph.spacing,
    linebreaks: style.paragraph.linebreaks,
  )
  set heading(numbering: sectionnumbering)
  set list(
    marker: style.bullet_list.marker,
    indent: style.bullet_list.indent,
    body-indent: style.bullet_list.body_indent,
    spacing: style.bullet_list.spacing,
  )
  set enum(
    indent: style.enum_list.indent,
    body-indent: style.enum_list.body_indent,
    spacing: style.enum_list.spacing,
  )
  set terms(indent: style.terms.indent, spacing: style.terms.spacing)
  set table(inset: style.table.inset, stroke: style.table.stroke)
  set quote(block: style.quote.block, quotes: style.quote.quotes)

  show heading: set block(sticky: true)
  show heading.where(level: 1): set text(
    size: style.heading1.size,
    weight: style.heading1.weight,
    style: style.heading1.style,
  )
  show heading.where(level: 1): set block(above: style.heading1.above, below: style.heading1.below)
  show heading.where(level: 2): set text(
    size: style.heading2.size,
    weight: style.heading2.weight,
    style: style.heading2.style,
  )
  show heading.where(level: 2): set block(above: style.heading2.above, below: style.heading2.below)
  show heading.where(level: 3): set text(
    size: style.heading3.size,
    weight: style.heading3.weight,
    style: style.heading3.style,
  )
  show heading.where(level: 3): set block(above: style.heading3.above, below: style.heading3.below)
  show heading.where(level: 4): set text(
    size: style.heading4.size,
    weight: style.heading4.weight,
    style: style.heading4.style,
  )
  show heading.where(level: 4): set block(above: style.heading4.above, below: style.heading4.below)
  show raw.where(block: true): set block(
    fill: style.codeblock.fill,
    inset: style.codeblock.inset,
    radius: style.codeblock.radius,
    above: style.codeblock.above,
    below: style.codeblock.below,
    breakable: true,
  )
  show quote.where(block: true): set block(above: 0.5em, below: 0.5em)
  show table: set text(size: style.table.fontsize)
  show footnote.entry: set text(size: style.footnote_size)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
  }

  if title != none {
    block(breakable: false, below: style.title.below, width: 100%)[
      #align(center)[
        #text(weight: "bold", size: style.title.size, hyphenate: false)[
          #title#if thanks != none { footnote(thanks, numbering: "*") }
        ]
        #if subtitle != none {
          parbreak()
          text(weight: "semibold", size: style.title.subtitle_size, hyphenate: false)[#subtitle]
        }
        #if authors != none and authors != () {
          parbreak()
          v(0.3em)
          text(size: style.title.author_size)[
            #authors.map(author => author.name).join([; ])
          ]
        }
        #if date != none {
          parbreak()
          text(size: style.title.date_size)[#date]
        }
      ]
      #if abstract != none {
        block(inset: (x: 1.5em, y: 0.55em))[
          #strong[#abstract-title.] #abstract
        ]
      }
    ]
  }

  doc
}

#show: doc => conf(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(author)$
  authors: (
$for(author)$
$if(author.name)$
    (name: [$author.name$], affiliation: [$author.affiliation$], email: [$author.email$]),
$else$
    (name: [$author$], affiliation: "", email: ""),
$endif$
$endfor$
  ),
$endif$
$if(keywords)$
  keywords: ($for(keywords)$"$keywords/nowrap$"$sep$,$endfor$),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
$if(abstract-title)$
  abstract-title: [$abstract-title$],
$endif$
$if(abstract)$
  abstract: [$abstract$],
$endif$
$if(thanks)$
  thanks: [$thanks$],
$endif$
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$endif$
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(mainfont)$
  font: ("$mainfont$",),
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(mathfont)$
  mathfont: ($for(mathfont)$"$mathfont$",$endfor$),
$endif$
$if(codefont)$
  codefont: ($for(codefont)$"$codefont$",$endfor$),
$endif$
$if(linestretch)$
  linestretch: $linestretch$,
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
  pagenumbering: $if(page-numbering)$"$page-numbering$"$else$"1"$endif$,
$if(linkcolor)$
  linkcolor: [$linkcolor$],
$endif$
$if(citecolor)$
  citecolor: [$citecolor$],
$endif$
$if(filecolor)$
  filecolor: [$filecolor$],
$endif$
  cols: $if(columns)$$columns$$else$1$endif$,
  doc,
)

$for(include-before)$
$include-before$
$endfor$

$if(toc)$
#outline(title: auto, depth: $toc-depth$)
$endif$

$body$

$if(citations)$
$for(nocite-ids)$
#cite(label("${it}"), form: none)
$endfor$
$if(csl)$
#set bibliography(style: "$csl$")
$elseif(bibliographystyle)$
#set bibliography(style: "$bibliographystyle$")
$endif$
$if(bibliography)$
#bibliography(($for(bibliography)$"$bibliography$"$sep$,$endfor$)$if(full-bibliography)$, full: true$endif$)
$endif$
$endif$

$for(include-after)$
$include-after$
$endfor$

