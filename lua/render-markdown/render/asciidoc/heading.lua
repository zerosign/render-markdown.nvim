local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.Heading: render.md.Render
---@field private config render.md.heading.Config
---@field private data render.md.heading.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.heading
    if not self.config.enabled then
        return false
    end
    local level ---@type integer
    local marker ---@type render.md.Node
    if self.node.type == 'document_title' then
        level = 1
        marker = self.node:child_at(0)
    else
        level = tonumber(self.node.type:match('%d+$')) or 1
        level = math.min(math.max(level, 1), 6)
        marker = self.node:child(('title_h%d_marker'):format(level))
    end
    if not marker then
        return false
    end
    local custom = self:custom()
    self.data = {
        level = level,
        marker = marker,
        icon = custom.icon or list.cycle(self.config.icons, level),
        sign = list.cycle(self.config.signs, level),
        fg = custom.foreground or list.clamp(self.config.foregrounds, level),
        bg = custom.background or list.clamp(self.config.backgrounds, level),
    }
    return true
end

---@private
---@return render.md.heading.Custom
function Render:custom()
    for _, custom in pairs(self.config.custom) do
        if self.node.text:find(custom.pattern) then
            return custom
        end
    end
    return {}
end

---@protected
function Render:run()
    self:sign(self.config, self.config.sign, self.data.sign, self.data.fg)
    local icon = self.data.icon
    local position = self.config.position or 'overlay'
    local highlight = {} ---@type string[]
    highlight[#highlight + 1] = self.data.fg
    highlight[#highlight + 1] = self.data.bg

    local marker = self.data.marker
    local width = self.context:width(marker) + 1
    local offset = { 0, 0, 0, 1 } ---@type Range4

    if not icon or #highlight == 0 then
        self.marks:over(self.config, true, marker, { conceal = '' }, offset)
    elseif position == 'eol' or position == 'right' then
        self.marks:over(self.config, true, marker, { conceal = '' }, offset)
        self.marks:start(self.config, 'head_icon', marker, {
            priority = 1000,
            virt_text = { { icon, highlight } },
            virt_text_pos = position == 'eol' and 'eol_right_align' or 'eol',
        })
    else
        local space = width - str.width(icon)
        if position == 'inline' or space < 0 then
            self.marks:over(self.config, 'head_icon', marker, {
                virt_text = { { icon, highlight } },
                virt_text_pos = 'inline',
                conceal = '',
            }, offset)
        else
            self.marks:over(self.config, 'head_icon', marker, {
                virt_text = { { str.pad(space) .. icon, highlight } },
                virt_text_pos = 'overlay',
            })
        end
    end

    -- background across the heading line(s)
    if self.data.bg then
        for row = self.node.start_row, self.node.end_row - 1 do
            self.marks:add(
                self.config,
                'head_background',
                row,
                self.node.start_col,
                {
                    end_row = row + 1,
                    hl_group = self.data.bg,
                    hl_eol = true,
                }
            )
        end
    end
end

return Render
