local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Superscript: render.md.Render
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
    -- Conceal the '^' delimiter markers of ^superscript^
    for _, range in ipairs(self.node:find('%^')) do
        self.marks:add(self.config, true, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            conceal = '',
        })
    end
end

return Render
