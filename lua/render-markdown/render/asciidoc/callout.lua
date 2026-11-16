local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')

---Map tree-sitter admonition node types to the lowercase callout key used to
---look up `config.callout[key]`.
local KIND = {
    admonition_note = 'note',
    admonition_tip = 'tip',
    admonition_important = 'important',
    admonition_caution = 'caution',
    admonition_warning = 'warning',
    note = 'note',
    tip = 'tip',
    important = 'important',
    caution = 'caution',
    warning = 'warning',
}

---@class render.md.render.asciidoc.Callout: render.md.Render
---@field private config render.md.callout.Configs
---@field private data render.md.callout.Data?
---@field private attr render.md.Node?
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.callout
    if not self.config then
        return false
    end

    if self.node.type == 'admonition' then
        local marker = self.node:child_at(0)
        if not marker then
            return false
        end
        local kind = KIND[marker.type]
        if not kind then
            return false
        end
        local cfg = self.config[kind]
        if not cfg then
            return false
        end
        self.data = { kind = kind, cfg = cfg }
        return true
    elseif self.node.type == 'delimited_block' then
        local attr_node, kind = self:get_admonition_attr()
        if not kind then
            return false
        end
        local cfg = self.config[kind]
        if not cfg then
            return false
        end
        self.attr = attr_node
        self.data = { kind = kind, cfg = cfg }
        return true
    end

    return false
end

---@private
---@return render.md.Node?, string?
function Render:get_admonition_attr()
    local prev = self.node:get():prev_sibling()
    while prev do
        if prev:type() == 'element_attr' then
            local text = vim.treesitter.get_node_text(prev, self.context.buf)
                or ''
            local name = text:match('%[([%w_]+)%]')
            if name then
                local k = KIND[name:lower()]
                if k then
                    return Node.new(self.context.buf, prev), k
                end
            end
        end
        if prev:type() ~= 'line_comment' and prev:type() ~= 'block_comment' then
            break
        end
        prev = prev:prev_sibling()
    end
    return nil, nil
end

---@protected
function Render:run()
    if self.node.type == 'admonition' then
        self:run_single_line()
    elseif self.node.type == 'delimited_block' then
        self:run_delimited_block()
    end
end

---@private
function Render:run_single_line()
    local cfg = assert(self.data.cfg)
    local marker = self.node:child_at(0)
    if not marker then
        return
    end

    -- Conceal 'NOTE: ' and insert the callout icon + title inline without eating characters
    local end_col = marker.end_col + 2
    self.marks:add(self.config, 'callout', marker.start_row, marker.start_col, {
        end_row = marker.start_row,
        end_col = end_col,
        virt_text = { { cfg.rendered .. ' ', cfg.highlight } },
        virt_text_pos = 'inline',
        conceal = '',
    })
end

---@private
function Render:run_delimited_block()
    local cfg = assert(self.data.cfg)

    -- 1. Conceal preceding [WARNING] element_attr
    if self.attr then
        self.marks:over(self.config, true, self.attr, {
            conceal = '',
            conceal_lines = '',
        })
    end

    -- 2. Opening ==== -> replace with callout header line
    local start_marker = self.node:child('delimited_block_start_marker')
    if start_marker then
        self.marks:over(self.config, 'callout', start_marker, {
            virt_text = { { cfg.rendered, cfg.highlight } },
            virt_text_pos = 'overlay',
            conceal = '',
        })
    end

    -- 3. Body lines: draw callout bar '▋ ' on the left
    local start_row = (
        start_marker and start_marker.start_row or self.node.start_row
    ) + 1
    local end_marker = self.node:child('delimited_block_end_marker')
    local end_row = (end_marker and end_marker.start_row or self.node.end_row)
        - 1

    for row = start_row, end_row do
        self.marks:add(self.config, 'callout', row, 0, {
            virt_text = { { '▋ ', cfg.highlight } },
            virt_text_pos = 'inline',
        })
    end

    -- 4. Closing ==== -> conceal
    if end_marker then
        self.marks:over(self.config, true, end_marker, {
            conceal = '',
            conceal_lines = '',
        })
    end
end

return Render
