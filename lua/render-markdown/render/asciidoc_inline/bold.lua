local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Bold: render.md.Render
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
    -- Conceal the '**' delimiter markers of **bold**
    for _, range in ipairs(self.node:find('%*%*')) do
        self.marks:add(self.config, true, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            conceal = '',
        })
    end

    -- Overlay a bold icon at the start of the emphasized text
    self.marks:over(self.config, 'bold', self.node, {
        virt_text = { { '󰲣 ', self.config.highlight } },
        virt_text_pos = 'overlay',
    })
end

return Render
