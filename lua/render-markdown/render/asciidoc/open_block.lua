local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')
local list = require('render-markdown.lib.list')

---@class render.md.render.asciidoc.OpenBlock: render.md.Render
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

    local attr = self:get_attr()
    if attr then
        local style = attr:child('positional_attr')
        if
            style
            and vim.tbl_contains(
                { 'stem', 'latexmath', 'asciimath', 'latex' },
                style.text
            )
        then
            return false
        end
    end

    local level = self.node:level_in('open_block')
    if level == 0 then
        level = 1
    end
    self.data = {
        level = level,
        icon = '│ ',
        highlight = list.cycle(self.config.highlight, level)
            or 'RenderMarkdownQuote',
    }
    return true
end

---@protected
function Render:run()
    local markers = {}
    self.node:for_each_child(function(child)
        if child.type == 'open_block_marker' then
            table.insert(markers, child)
        end
    end)

    if #markers < 2 then
        return
    end

    local start_m = markers[1]
    local end_m = markers[2]

    -- Conceal start marker line (--)
    self.marks:add(self.config, true, start_m.start_row, 0, {
        end_row = start_m.start_row + 1,
        end_col = 0,
        conceal = '',
        conceal_lines = '',
    })

    -- Conceal end marker line (--)
    self.marks:add(self.config, true, end_m.start_row, 0, {
        end_row = end_m.start_row + 1,
        end_col = 0,
        conceal = '',
        conceal_lines = '',
    })

    -- Conceal preceding element_attr if present
    local attr = self:get_attr()
    if attr then
        self.marks:over(self.config, true, attr, {
            conceal = '',
            conceal_lines = '',
        })
    end

    local first_content_row = start_m.start_row + 1
    local last_content_row = end_m.start_row - 1

    -- Prefix each open block content line with the container bar
    for r = first_content_row, last_content_row do
        self.marks:add(self.config, false, r, 0, {
            priority = 9000,
            hl_mode = 'combine',
            virt_text = { { self.data.icon, self.data.highlight } },
            virt_text_pos = 'inline',
        })
    end
end

---@private
---@return render.md.Node?
function Render:get_attr()
    local parent = self.node:get():parent()
    if parent and parent:type() == 'section_block' then
        local pnode = Node.new(self.context.buf, parent)
        local attr = pnode:child('element_attr')
        if attr then
            return attr
        end
    end
    local ts_node = self.node:get():prev_sibling()
    while ts_node do
        if ts_node:type() == 'element_attr' then
            return Node.new(self.context.buf, ts_node)
        end
        if
            ts_node:type() ~= 'line_comment'
            and ts_node:type() ~= 'block_comment'
        then
            break
        end
        ts_node = ts_node:prev_sibling()
    end
    return nil
end

return Render
