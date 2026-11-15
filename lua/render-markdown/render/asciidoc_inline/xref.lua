local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Xref: render.md.Render
---@field private config render.md.link.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.link
    return self.config.enabled
end

---@protected
function Render:run()
    -- Find the reftext child (the displayed text) or fall back to id
    local reftext = self.node:child('reftext')
    local target = reftext or self.node:child('id')

    -- Overlay a link icon before the cross reference
    local icon = { self.config.hyperlink, self.config.highlight } ---@type render.md.mark.Text
    self.marks:over(self.config, 'xref', self.node, {
        priority = 9000,
        hl_mode = 'combine',
        virt_text = { icon },
        virt_text_pos = 'inline',
    })

    -- Conceal the <<...>> wrapper and the id/reftext
    if target then
        self.marks:add(self.config, true, target.start_row, target.start_col, {
            end_row = target.end_row,
            end_col = target.end_col,
            conceal = '',
        })
    end
end

return Render
