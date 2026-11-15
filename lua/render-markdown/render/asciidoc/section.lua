local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---@class render.md.asciidoc.section.Data
---@field level integer
---@field level_change integer

---@class render.md.render.asciidoc.Section: render.md.Render
---@field private config render.md.indent.Config
---@field private data render.md.asciidoc.section.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---Return the heading level of a section: 1-5 for title1..title5; 0 for a
---section with no title child.
---@param node render.md.Node
---@return integer
local function section_level(node)
    local title = node:child('title1')
        or node:child('title2')
        or node:child('title3')
        or node:child('title4')
        or node:child('title5')
    if not title then
        return 0
    end
    return tonumber(title.type:match('%d+$')) or 0
end

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.indent
        or self.context.config.indent
    if not self.config.enabled then
        return false
    end
    local current_level = section_level(self.node)
    local parent_section = self.node:parent('section')
    local parent_level = math.max(
        parent_section and section_level(parent_section) or 0,
        self.config.skip_level
    )
    local level_change = current_level - parent_level
    if level_change <= 0 then
        return false
    end
    self.data = { level = current_level, level_change = level_change }
    return true
end

---@protected
function Render:run()
    local start_row = math.max(self.node.start_row + self:start_below(), 0)
    local end_row = self.node.end_row - 1 - self:end_above()
    local line = self:indent():line(false, self.data.level_change):get()
    for row = start_row, end_row do
        self.marks:add(self.config, 'indent', row, 0, {
            priority = self.config.priority,
            virt_text = line,
            virt_text_pos = 'inline',
        })
    end
end

---@private
---@return integer
function Render:start_below()
    if self.config.skip_heading then
        local empty = self:empty('first', 1)
        return empty and 2 or 1
    else
        local empty = self:empty('above', 1)
        local only = self:heading('above', 2)
        return (empty and not only) and -1 or 0
    end
end

---@private
---@return integer
function Render:end_above()
    local empty = self:empty('last', 0)
    local only = self:heading('last', 1)
    return (empty and not only) and 1 or 0
end

---@private
---@param position render.md.node.Position
---@param by integer
---@return boolean
function Render:empty(position, by)
    local _, line = self.node:line(position, by)
    return str.width(line) == 0
end

---@private
---@param position render.md.node.Position
---@param by integer
---@return boolean
function Render:heading(position, by)
    local _, line = self.node:line(position, by)
    if not line then
        return false
    end
    -- An asciidoc heading line starts with '=' + optional whitespace
    return line:match('^%s*=') ~= nil
end

return Render
