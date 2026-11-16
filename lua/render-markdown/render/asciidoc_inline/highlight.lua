local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Highlight: render.md.Render
---@field private config render.md.inline.highlight.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.inline_highlight
    return self.config.enabled
end

---@protected
function Render:run()
    -- Conceal the '##' delimiter markers of ##highlight##
    for _, range in ipairs(self.node:find('#+')) do
        local text = vim.api.nvim_buf_get_text(
            self.context.buf,
            range[1],
            range[2],
            range[3],
            range[4],
            {}
        )[1] or ''
        if text:match('#') then
            self.marks:add(self.config, true, range[1], range[2], {
                end_row = range[3],
                end_col = range[4],
                conceal = '',
            })
        end
    end

    -- Highlight the content
    self.marks:add(
        self.config,
        false,
        self.node.start_row,
        self.node.start_col,
        {
            end_row = self.node.end_row,
            end_col = self.node.end_col,
            hl_group = self.config.highlight,
        }
    )
end

return Render
