local Base = require('render-markdown.render.base')

---@class render.md.checkbox.Data
---@field marker render.md.Node
---@field bullet? render.md.Node
---@field icon string
---@field highlight string
---@field scope_highlight? string

---@class render.md.render.asciidoc.Checkbox: render.md.Render
---@field private config render.md.checkbox.Config
---@field private data render.md.checkbox.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.checkbox
    if not self.config.enabled then
        return false
    end
    local marker_node = self.node:child('checked_list_marker')
    if not marker_node then
        return false
    end
    local checked = marker_node:child('checked_list_marker_checked')
    local unchecked = marker_node:child('checked_list_marker_unchecked')
    local marker = checked or unchecked
    if not marker then
        return false
    end
    local bullet = marker_node:child('unordered_list_marker')
    local value = checked and self.config.checked or self.config.unchecked
    self.data = {
        marker = marker,
        bullet = bullet,
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
    if self.data.bullet and not self.config.bullet then
        -- Conceal the leading bullet (e.g. '* ') when bullet is disabled for checkboxes
        self.marks:add(
            self.config,
            true,
            self.data.bullet.start_row,
            self.data.bullet.start_col,
            {
                end_row = self.data.bullet.start_row,
                end_col = self.data.marker.start_col,
                conceal = '',
            }
        )
    end
end

---@private
function Render:checkbox()
    local node = self.data.marker
    self.marks:over(self.config, 'check_icon', node, {
        virt_text = { { self.data.icon, self.data.highlight } },
        virt_text_pos = 'inline',
        conceal = '',
    })
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
