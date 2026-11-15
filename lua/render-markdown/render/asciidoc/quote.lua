local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')

---@class render.md.render.asciidoc.Quote: render.md.Render
---@field private config render.md.quote.Config
---@field private data render.md.quote.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.quote
    if not self.config.enabled then
        return false
    end
    local level = self.node:level_in('quoted_block')
    self.data = {
        level = level,
        icon = list.cycle(self.config.icon, level),
        highlight = list.cycle(self.config.highlight, level),
    }
    return true
end

---@protected
function Render:run()
    self:icon()
end

---@private
function Render:icon()
    local icon = self.data.icon
    local highlight = self.data.highlight
    if not icon or not highlight then
        return
    end
    self.marks:start(self.config, 'quote', self.node, {
        virt_text = { { icon, highlight } },
        virt_text_pos = 'overlay',
    })
end

return Render
