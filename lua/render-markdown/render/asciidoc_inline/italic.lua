local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Italic: render.md.Render
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
    -- Conceal the '_' or '__' delimiter markers of _italic_
    for _, range in ipairs(self.node:find('_+')) do
        self.marks:add(self.config, true, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            conceal = '',
        })
    end

    self.marks:add(
        self.config,
        false,
        self.node.start_row,
        self.node.start_col,
        {
            end_row = self.node.end_row,
            end_col = self.node.end_col,
            hl_group = '@markup.italic',
        }
    )
end

return Render
