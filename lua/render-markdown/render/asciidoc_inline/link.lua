local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Link: render.md.Render
---@field private config render.md.link.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.link
    return self.config.enabled
end

---@protected
function Render:run()
    -- Overlay a link icon before the URL
    local icon = { self.config.hyperlink, self.config.highlight } ---@type render.md.mark.Text
    self.marks:over(self.config, 'link', self.node, {
        priority = 9000,
        hl_mode = 'combine',
        virt_text = { icon },
        virt_text_pos = 'inline',
    })

    -- Conceal the URL text itself
    self.marks:add(self.config, true, self.node.start_row, self.node.start_col, {
        end_row = self.node.end_row,
        end_col = self.node.end_col,
        conceal = '',
    })
end

return Render
