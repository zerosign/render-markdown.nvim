local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc_inline.AttributeReference: render.md.Render
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
    -- Get the attribute name child (inside {name})
    local attr_name = self.node:child('attribute_name')
    local name = attr_name and attr_name.text or self.node.text

    -- Conceal the braces and show just the attribute name
    self.marks:add(self.config, true, self.node.start_row, self.node.start_col, {
        end_row = self.node.end_row,
        end_col = self.node.end_col,
        conceal = '',
    })

    -- Overlay the attribute reference with icon
    local icon_line = self:line():text('{', self.config.highlight)
        :text(name, self.config.highlight)
        :text('}', self.config.highlight)
    self.marks:over(self.config, 'attribute_reference', self.node, {
        virt_text = icon_line:get(),
        virt_text_pos = 'overlay',
    })
end

return Render
