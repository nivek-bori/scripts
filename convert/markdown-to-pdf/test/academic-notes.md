---
title: Academic Notes Print Test
subtitle: Typography, hierarchy, and pagination
author: Test Author
date: 2026-10-12
toc: true
---

# Core Concepts

This fixture tests readable body text, **strong emphasis**, *italics*, links,
inline code such as `f(x)`, and a footnote.[^source] The paragraph is long enough
to reveal line spacing, justification, and margin behavior on US Letter paper.

## Nested Lists

- **First-level item** → a compact explanation that may wrap onto another line
  without colliding with its marker.
  - **Second-level item** → nested indentation remains visible but economical.
    - **Third-level item** → deep nesting does not consume excessive width.
      1. An ordered list may be nested inside an unordered list.
      2. Wrapped ordered items align with their text, not their numeral.
- **Sibling item** → spacing distinguishes items without creating large gaps.

### Definitions

Term
: A definition-list entry with enough detail to test hanging indentation and
  the separation between the term and its explanation.

## Mathematics

Inline mathematics should remain aligned with text: $e^{i\pi}+1=0$. Displayed
mathematics should have clear operators, delimiters, superscripts, and spacing:

$$
\hat{\beta}=(X^{\mathsf T}X)^{-1}X^{\mathsf T}y,
\qquad
\operatorname{Var}(\hat{\beta})=\sigma^2(X^{\mathsf T}X)^{-1}.
$$

For a convergent geometric series,

$$
\sum_{k=0}^{\infty} ar^k=\frac{a}{1-r}, \qquad |r|<1.
$$

## Table and Code

| Element | Print requirement | Expected behavior |
|:--|:--|:--|
| Body | Readable density | 10 pt serif text |
| Lists | Compact hierarchy | Small, consistent indentation |
| Headings | Clear levels | Distinct size and weight |
| Math | Proper notation | Dedicated math font |

```python
def ordinary_least_squares(x, y):
    """Return the formal normal-equation estimator."""
    return inverse(transpose(x) @ x) @ transpose(x) @ y
```

## Pagination Stress Test

The following numbered observations create enough material to exercise page
flow. A heading near a page boundary must stay with at least some following
content instead of appearing alone at the bottom.

1. Compact formatting is not the same as cramped formatting. The page should
   retain enough leading for the reader to track a line across the measure.
2. A consistent vertical rhythm makes hierarchy visible without relying on
   decorative rules or large blank regions.
3. Tables need restrained cell padding and visible structure. Their smaller
   type remains above the threshold expected for printed reference material.
4. Code blocks need a light background and modest inset. Long blocks may split
   across pages rather than forcing a large blank area.

<!-- pagebreak -->

# Explicit Page Break

This heading must begin on a new page. The HTML comment that requested the
break should not appear as printed text.

## Final Check

The last section confirms that content after an explicit break is retained and
that the PDF ends cleanly without an unnecessary blank page.

[^source]: Footnotes are part of the original document content and must survive conversion.
