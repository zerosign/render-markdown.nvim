local Base = require('render-markdown.render.base')
local list = require('render-markdown.lib.list')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.DescriptionList: render.md.Render
---@field private config render.md.bullet.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.bullet
    if not self.config.enabled then
        return false
    end
    return true
end

---@protected
function Render:run()
    self.node:for_each_child(function(item)
        if item.type ~= 'description_list_item' then
            return
        end

        local marker = item:child('description_marker')
        local term = item:child('term')
        if not marker or not term then
            return
        end

        -- Conceal the description marker (e.g. '::', ':::', ';;')
        self.marks:add(self.config, true, marker.start_row, marker.start_col, {
            end_row = marker.end_row,
            end_col = marker.end_col,
            conceal = '',
        })

        -- Level from nesting inside description_list
        local level = self.node:level_in('description_list')
        local icon = list.cycle(self.config.icons, level)
        local highlight = list.cycle(self.config.highlight, level)
        if icon and highlight then
            self.marks:over(self.config, 'description_list', term, {
                virt_text = { { icon .. ' ', highlight } },
                virt_text_pos = 'overlay',
            })
        end
    end)
end

return Render
