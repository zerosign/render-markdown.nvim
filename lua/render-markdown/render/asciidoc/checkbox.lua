local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.Checkbox: render.md.Render
---@field private config render.md.checkbox.Config
---@field private data render.md.checkbox.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.checkbox
    if not self.config.enabled then
        return false
    end
    local checked = self.node:child('checked_list_marker_checked')
    local unchecked = self.node:child('checked_list_marker_unchecked')
    local marker = checked or unchecked
    if not marker then
        return false
    end
    local value = checked and self.config.checked or self.config.unchecked
    self.data = {
        marker = marker,
        icon = value.icon,
        highlight = value.highlight,
        scope_highlight = value.scope_highlight,
    }
    return true
end

---@protected
function Render:run()
    self:marker()
    self:checkbox()
    self:scope()
end

---@private
function Render:marker()
    if self.config.bullet then
        -- fall back to bullet styling for the marker
    else
        -- https://github.com/tree-sitter-grammars/tree-sitter-markdown/issues/127
        local node = self.data.marker
        self.marks:over(self.config, 'check_icon', node, {
            conceal = '',
        }, { 0, str.spaces('start', node.text), 0, 0 })
    end
end

---@private
function Render:checkbox()
    -- add 1 to end to account for space after checkbox
    local node = self.data.marker
    local row = node.start_row
    local start_col = node.start_col
    local end_col = node.end_col + 1
    local width = self.context:width(node) + 1

    local line = self:line()
        :pad(self.config.left_pad)
        :text(self.data.icon, self.data.highlight)
        :pad(self.config.right_pad)

    local overlay = line:sub(1, width)
    local used = overlay:width()
    if not overlay:empty() then
        self.marks:add(self.config, 'check_icon', row, start_col, {
            hl_mode = 'combine',
            virt_text = overlay:get(),
            virt_text_pos = 'overlay',
        })
    end

    local inline = line:sub(used + 1, line:width())
    if not inline:empty() then
        self.marks:add(self.config, 'check_icon', row, end_col, {
            hl_mode = 'combine',
            virt_text = inline:get(),
            virt_text_pos = 'inline',
        })
    end

    local space = width - used
    if space > 0 then
        self.marks:add(self.config, 'check_icon', row, end_col - space, {
            end_col = end_col,
            conceal = '',
        })
    end
end

---@private
function Render:scope()
    local highlight = self.data.scope_highlight
    if not highlight then
        return
    end
    self.marks:over(self.config, 'check_scope', self.node:scope(), {
        priority = self.config.scope_priority,
        hl_group = highlight,
    })
end

return Render
