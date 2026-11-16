local Context = require('render-markdown.request.context')
local Marks = require('render-markdown.lib.marks')
local ts = require('render-markdown.core.ts')

---@class render.md.handler.Asciidoc: render.md.Handler
local M = {}

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('asciidoc', [[
        ; Headings
        (document_title) @heading
        (title1) @heading
        (title2) @heading
        (title3) @heading
        (title4) @heading
        (title5) @heading

        ; Paragraphs
        (paragraph) @paragraph

        ; Lists
        (unordered_list) @list
        (ordered_list) @list
        (checked_list) @list

        ; Code blocks
        (listing_block) @code
        (literal_block) @code

        ; Mathematical blocks ([stem], [latexmath], etc.)
        (section_block
          (element_attr
            (positional_attr
              (block_style) @_style))
          [(passthrough_block) (listing_block) (open_block)] @math
          (#any-of? @_style "stem" "latexmath" "asciimath" "latex"))

        ; Quotes
        (quoted_block) @quote

        ; Callouts / admonitions
        (admonition) @callout
        (delimited_block) @callout

        ; Tables
        (table_block) @table
        (csv_table_block) @table
        (dsv_table_block) @table
        (ntable_block) @table

        ; Thematic breaks / horizontal rules
        (breaks) @dash

        ; Document attributes (frontmatter-ish)
        (document_attr) @yaml

        ; Sections (for indent levels)
        (section) @section

        ; Description lists: `term:: definition`
        (description_list) @description_list

        ; Sidebar blocks (==== or ****)
        (sidebar_block) @sidebar

        ; Passthrough blocks (++++)
        (passthrough_block) @code

        ; Markdown quoted blocks
        (quoted_md_block) @quote

        ; Open blocks (--) — treated as quote for MVP
        (open_block) @quote

        ; Indented blocks — treated as literal block for MVP
        (ident_block) @code

        ; Block-level macros: image::[], link:[] etc. at start of line
        (block_macro) @block_macro
    ]])

    ---@type table<string, render.md.Render>
    local renders = {
        heading = require('render-markdown.render.asciidoc.heading'),
        paragraph = require('render-markdown.render.asciidoc.paragraph'),
        list = require('render-markdown.render.asciidoc.list'),
        code = require('render-markdown.render.asciidoc.code'),
        quote = require('render-markdown.render.asciidoc.quote'),
        callout = require('render-markdown.render.asciidoc.callout'),
        table = require('render-markdown.render.asciidoc.table'),
        dash = require('render-markdown.render.asciidoc.dash'),
        yaml = require('render-markdown.render.asciidoc.document_attr'),
        section = require('render-markdown.render.asciidoc.section'),
        description_list = require(
            'render-markdown.render.asciidoc.description_list'
        ),
        sidebar = require('render-markdown.render.asciidoc.sidebar'),
        block_macro = require('render-markdown.render.asciidoc.block_macro'),
        math = require('render-markdown.render.asciidoc.math'),
    }

    local context = Context.get(ctx.buf)
    local marks = Marks.new(context, false)
    context.view:nodes(ctx.root, query, function(capture, node)
        if capture:sub(1, 1) == '_' then
            return
        end
        local render = renders[capture]
        assert(render, ('unhandled asciidoc capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
