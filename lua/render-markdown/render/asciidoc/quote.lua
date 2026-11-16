local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')
local list = require('render-markdown.lib.list')

---@class render.md.render.asciidoc.Quote: render.md.Render
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
    local level = self.node:level_in('quoted_block')
    if level == 0 then
        level = self.node:level_in('quoted_md_block')
    end
    if level == 0 then
        level = 1
    end
    self.data = {
        level = level,
        icon = list.cycle(self.config.icon, level) or '▎',
        highlight = list.cycle(self.config.highlight, level)
            or 'RenderMarkdownQuote',
    }
    return true
end

---@protected
function Render:run()
    if self.node.type == 'quoted_block' then
        self:quoted_block()
    elseif self.node.type == 'quoted_md_block' then
        self:quoted_md_block()
    end
end

---@private
function Render:quoted_block()
    local icon = self.data.icon .. ' '
    local highlight = self.data.highlight

    local start_m = self.node:child('quoted_block_start_marker')
    local end_m = self.node:child('quoted_block_end_marker')

    local start_row = start_m and start_m.start_row or self.node.start_row
    local end_row = end_m and end_m.start_row or self.node.end_row

    -- Conceal start marker line (____)
    if start_m then
        self.marks:add(self.config, true, start_m.start_row, 0, {
            end_row = start_m.start_row + 1,
            end_col = 0,
            conceal = '',
            conceal_lines = '',
        })
    end

    -- Conceal end marker line (____)
    if end_m then
        self.marks:add(self.config, true, end_m.start_row, 0, {
            end_row = end_m.start_row + 1,
            end_col = 0,
            conceal = '',
            conceal_lines = '',
        })
    end

    -- Check preceding element_attr for [quote, author, source]
    local attr = self:get_attr()
    local attribution = nil
    if attr then
        self.marks:over(self.config, true, attr, {
            conceal = '',
            conceal_lines = '',
        })
        local attrs = {}
        attr:for_each_child(function(c)
            if c.type == 'positional_attr' then
                table.insert(attrs, vim.trim(c.text))
            end
        end)
        -- attrs[1] is block_style ("quote"), attrs[2] is author, attrs[3] is source
        local parts = {}
        if attrs[2] and #attrs[2] > 0 and attrs[2] ~= 'quote' then
            table.insert(parts, attrs[2])
        end
        if attrs[3] and #attrs[3] > 0 then
            table.insert(parts, attrs[3])
        end
        if #parts > 0 then
            attribution = table.concat(parts, ', ')
        end
    end

    local first_content_row = start_row + 1
    local last_content_row = end_row - 1

    -- Prefix each quote content line with the quote icon
    for r = first_content_row, last_content_row do
        self.marks:add(self.config, false, r, 0, {
            priority = 9000,
            hl_mode = 'combine',
            virt_text = { { icon, highlight } },
            virt_text_pos = 'inline',
        })
    end

    -- Add attribution below the last content line if present
    if attribution and last_content_row >= first_content_row then
        self.marks:add(self.config, false, last_content_row, 0, {
            virt_lines = {
                {
                    { icon .. '  — ' .. attribution, highlight },
                },
            },
            virt_lines_above = false,
        })
    end
end

---@private
function Render:quoted_md_block()
    local icon = self.data.icon
    local highlight = self.data.highlight
    self.node:for_each_child(function(child)
        if child.type == 'quoted_block_md_marker' then
            self.marks:over(self.config, 'quote', child, {
                virt_text = { { icon, highlight } },
                virt_text_pos = 'overlay',
            })
        end
    end)
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
