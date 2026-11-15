local Base = require('render-markdown.render.base')
local Bullet = require('render-markdown.render.asciidoc.bullet')
local Checkbox = require('render-markdown.render.asciidoc.checkbox')

---@class render.md.render.asciidoc.List: render.md.Render
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    return true
end

---@protected
function Render:run()
    local is_checkbox = self.node.type == 'checked_list'
    self.node:for_each_child(function(item)
        if is_checkbox then
            Checkbox:execute(self.context, self.marks, item)
        else
            Bullet:execute(self.context, self.marks, item)
        end
    end)
end

return Render
