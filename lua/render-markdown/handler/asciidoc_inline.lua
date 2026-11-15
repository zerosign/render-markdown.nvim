local Context = require('render-markdown.request.context')
local Marks = require('render-markdown.lib.marks')
local ts = require('render-markdown.core.ts')

---@class render.md.handler.AsciidocInline: render.md.Handler
local M = {}

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('asciidoc_inline', [[
        ; Bold
        (emphasis) @bold

        ; Italic
        (italic) @italic

        ; Inline code / monospace
        (monospace) @code

        ; Links
        (link_url) @link
        (email) @link

        ; Cross references
        (xref) @xref

        ; Highlight
        (highlight) @highlight

        ; Superscript / subscript
        (superscript) @superscript
        (subscript) @subscript
    ]])

    ---@type table<string, render.md.Render>
    local renders = {
        bold = require('render-markdown.render.asciidoc_inline.bold'),
        italic = require('render-markdown.render.asciidoc_inline.italic'),
        code = require('render-markdown.render.asciidoc_inline.code'),
        link = require('render-markdown.render.asciidoc_inline.link'),
        xref = require('render-markdown.render.asciidoc_inline.xref'),
        highlight = require('render-markdown.render.asciidoc_inline.highlight'),
        superscript = require('render-markdown.render.asciidoc_inline.superscript'),
        subscript = require('render-markdown.render.asciidoc_inline.subscript'),
    }

    local context = Context.get(ctx.buf)
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        if render then
            render:execute(context, marks, node)
        end
    end)
    return marks:get()
end

return M
