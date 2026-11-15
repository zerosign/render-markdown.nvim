local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')

---@class render.md.render.asciidoc.Heading: render.md.Render
---@field private config render.md.heading.Config
---@field private data render.md.heading.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.heading
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
    -- conceal the heading marker (e.g. '===') so the icon takes its place
    self.marks:over(self.config, true, self.data.marker, { conceal = '' })
    -- overlay the heading icon on the concealed marker
    if self.data.icon then
        self.marks:over(self.config, 'head_icon', self.data.marker, {
            virt_text = { { self.data.icon, { self.data.fg, self.data.bg } } },
            virt_text_pos = 'overlay',
        })
    end
    -- background across the heading line(s)
    if self.data.bg then
        for row = self.node.start_row, self.node.end_row - 1 do
            self.marks:add(self.config, 'head_background', row, self.node.start_col, {
                end_row = row + 1,
                hl_group = self.data.bg,
                hl_eol = true,
            })
        end
    end
end

return Render
