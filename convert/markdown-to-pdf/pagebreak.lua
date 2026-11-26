-- Normalize common Markdown page-break conventions for the Typst writer.
-- All other document nodes pass through unchanged.

local function typst_pagebreak()
  return pandoc.RawBlock("typst", "#pagebreak()")
end

function RawBlock(element)
  if element.format == "tex" or element.format == "latex" then
    local text = element.text:match("^%s*(.-)%s*$")
    if text == "\\newpage" or text == "\\newpage{}"
      or text == "\\pagebreak" or text == "\\pagebreak{}"
      or text == "\\clearpage" or text == "\\clearpage{}" then
      return typst_pagebreak()
    end
  end

  if element.format == "html"
    and element.text:match("^%s*<!%-%-%s*pagebreak%s*%-%->%s*$") then
    return typst_pagebreak()
  end
end

function Div(element)
  for _, class in ipairs(element.classes) do
    if class == "pagebreak" or class == "page-break" then
      return typst_pagebreak()
    end
  end
end

