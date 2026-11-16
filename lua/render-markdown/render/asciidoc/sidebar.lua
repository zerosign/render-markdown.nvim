local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')

---@class render.md.render.asciidoc.Sidebar: render.md.Render
---@field private config render.md.quote.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.quote
    if not self.config.enabled then
        return false
    end
    return true
end

---@protected
function Render:run()
    local start_marker = self.node:child('sidebar_block_start_marker')
    local end_marker = self.node:child('sidebar_block_end_marker')

    -- Conceal the sidebar block markers (e.g. '****')
    if start_marker then
        self.marks:add(
            self.config,
            true,
            start_marker.start_row,
            start_marker.start_col,
            {
                end_row = start_marker.end_row,
                end_col = start_marker.end_col,
                conceal = '',
            }
        )
    end
    if end_marker then
        self.marks:add(
            self.config,
            true,
            end_marker.start_row,
            end_marker.start_col,
            {
                end_row = end_marker.end_row,
                end_col = end_marker.end_col,
                conceal = '',
            }
        )
    end

    -- Overlay icon at the start of the sidebar block
    local level = self.node:level_in('sidebar_block')
    local icon = list.cycle(self.config.icon, level)
    local highlight = list.cycle(self.config.highlight, level)
    if icon and highlight then
        self.marks:over(self.config, 'sidebar', self.node, {
            virt_text = { { icon, highlight } },
            virt_text_pos = 'overlay',
        })
    end
end

return Render
