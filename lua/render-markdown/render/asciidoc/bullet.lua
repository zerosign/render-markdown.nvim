local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')
local str = require('render-markdown.lib.str')

---@class render.md.bullet.Data
---@field marker render.md.Node
---@field level integer
---@field index integer
---@field icon? string
---@field highlight? string
---@field scope_highlight? string
---@field left_pad integer
---@field right_pad integer

---@class render.md.render.asciidoc.Bullet: render.md.Render
---@field private config render.md.bullet.Config
---@field private data render.md.bullet.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.bullet
    if not self.config.enabled then
        return false
    end
    local marker = self:marker_leaf()
    if not marker then
        return false
    end
    local list_type = self.node.type == 'ordered_list_item' and 'ordered_list' or 'unordered_list'
    local level = self.node:level_in(list_type)
    local ordered_types = { 'list_marker_digit', 'list_marker_alpha' }
    local ordered = vim.tbl_contains(ordered_types, marker.type)
    local icons = ordered and self.config.ordered_icons or self.config.icons
    ---@type render.md.bullet.Context
    local ctx = {
        level = level,
        index = self.node:sibling_count(self.node.type),
        value = marker.text,
    }
    self.data = {
        marker = marker,
        level = level,
        index = ctx.index,
        icon = Render.get_string(icons, ctx),
        highlight = Render.get_string(self.config.highlight, ctx),
        scope_highlight = Render.get_string(self.config.scope_highlight, ctx),
        left_pad = Render.get_integer(self.config.left_pad, ctx),
        right_pad = Render.get_integer(self.config.right_pad, ctx),
    }
    return true
end

---Find the actual marker leaf (e.g. `list_marker_hyphen`) behind the
---asciidoc `unordered_list_marker` / `ordered_list_marker` wrapper.
---@return render.md.Node?
function Render:marker_leaf()
    local wrapper = self.node:child('unordered_list_marker')
        or self.node:child('ordered_list_marker')
    if not wrapper then
        return nil
    end
    return wrapper:child_at(0)
end

---@private
---@param values render.md.bullet.String
---@param ctx render.md.bullet.Context
---@return string?
function Render.get_string(values, ctx)
    if type(values) == 'function' then
        return values(ctx)
    else
        local value = list.cycle(values, ctx.level)
        return list.clamp(value, ctx.index)
    end
end

---@private
---@param value render.md.bullet.Integer
---@param ctx render.md.bullet.Context
---@return integer
function Render.get_integer(value, ctx)
    if type(value) == 'function' then
        return value(ctx)
    else
        return value
    end
end

---@protected
function Render:run()
    self:marker()
    self:padding()
    self:scope()
end

---@private
function Render:marker()
    local icon = self.data.icon
    local highlight = self.data.highlight
    if not icon or not highlight then
        return
    end
    local node = self.data.marker
    local text = str.pad(str.spaces('start', node.text)) .. icon
    local overflow = str.width(text) > str.width(node.text)
    self.marks:over(self.config, 'bullet', node, {
        virt_text = { { text, highlight } },
        virt_text_pos = overflow and 'inline' or 'overlay',
        conceal = overflow and '' or nil,
    })
end

---@private
function Render:padding()
    local left_line = self:line():pad(self.data.left_pad):get()
    local right_line = self:line():pad(self.data.right_pad):get()
    if #left_line == 0 and #right_line == 0 then
        return
    end
    local start_row, end_row = self.node.start_row, self.node.end_row
    for row = start_row, end_row - 1 do
        local left = self.node.start_col
        local right = row == start_row and self.data.marker.end_col - 1 or left
        if #left_line > 0 then
            self.marks:add(self.config, false, row, left, {
                priority = 100,
                virt_text = left_line,
                virt_text_pos = 'inline',
            })
        end
        if #right_line > 0 then
            self.marks:add(self.config, false, row, right, {
                priority = 100,
                virt_text = right_line,
                virt_text_pos = 'inline',
            })
        end
    end
end

---@private
function Render:scope()
    local highlight = self.data.scope_highlight
    if not highlight then
        return
    end
    self.marks:over(self.config, true, self.node:scope(), {
        priority = self.config.scope_priority,
        hl_group = highlight,
    })
end

return Render
