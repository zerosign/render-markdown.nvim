local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc_inline.Passthrough: render.md.Render
---@field private config render.md.code.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.code
    if not self.config.enabled or not self.config.inline then
        return false
    end
    return true
end

---@protected
function Render:run()
    -- Conceal the passthrough delimiters (+ or +++)
    for _, range in ipairs(self.node:find('^\\++|\\++$')) do
        self.marks:add(self.config, true, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            conceal = '',
        })
    end

    -- Highlight the passthrough content as inline code
    self.marks:over(self.config, 'code_background', self.node, {
        priority = self.config.priority,
        hl_group = self.config.highlight_inline,
    })

    -- Left/right padding icons
    self:padding(self.config.inline_left, self.config.highlight_inline_left, true)
    self:padding(self.config.inline_right, self.config.highlight_inline_right, false)
end

---@param text string
---@param highlight? string
---@param left boolean
function Render:padding(text, highlight, left)
    if #text == 0 then
        return
    end
    local line = self:line():text(text, highlight)
    local row = left and self.node.start_row or self.node.end_row
    local col = left and self.node.start_col or self.node.end_col
    self.marks:add(self.config, true, row, col, {
        priority = 0,
        virt_text = line:get(),
        virt_text_pos = 'inline',
    })
end

return Render
