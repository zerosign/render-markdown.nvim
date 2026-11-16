local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')
local colors = require('render-markdown.core.colors')
local env = require('render-markdown.lib.env')
local icons = require('render-markdown.lib.icons')
local str = require('render-markdown.lib.str')

---@class render.md.code.Data
---@field language? render.md.Node
---@field attr? render.md.Node
---@field language_padding integer
---@field padding integer
---@field body integer
---@field margin integer

---@class render.md.render.asciidoc.Code: render.md.Render
---@field private config render.md.code.Config
---@field private data render.md.code.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.code
    if not self.config.enabled then
        return false
    end
    -- skip single line code block
    if self.node:height() <= 2 then
        return false
    end

    local widths = self.node:widths()
    local width = vim.fn.max(widths)

    local language_padding = self:offset(self.config.language_pad, width)
    local left = self:offset(self.config.left_pad, width)
    local right = self:offset(self.config.right_pad, width)

    local body = str.width(self.config.language_left)
        + str.width(self.config.language_right)
        + language_padding
        + widths[1]
    body = math.max(body, left + width + right, self.config.min_width)

    local language, attr = self:get_language()
    self.data = {
        language = language,
        attr = attr,
        language_padding = language_padding,
        padding = left,
        body = body,
        margin = self:offset(self.config.left_margin, body),
    }

    return self:enabled(self.config.disable)
end

---Resolve the listing/literal block language and attribute node from a preceding
---`[source,ruby]` style `element_attr` node.
---@return render.md.Node?, render.md.Node?
function Render:get_language()
    local ts_node = self.node:get()
    while ts_node do
        ts_node = ts_node:prev_sibling()
        if not ts_node then
            break
        end
        if ts_node:type() == 'element_attr' then
            local leaf ---@type TSNode?
            for child in ts_node:iter_children() do
                local t = child:type()
                if t == 'positional_attr' then
                    leaf = child
                elseif t == 'block_style' and not leaf then
                    leaf = child
                end
            end
            local attr = Node.new(self.context.buf, ts_node)
            local lang = leaf and Node.new(self.context.buf, leaf) or nil
            return lang, attr
        end
    end
    return nil, nil
end

---@private
---@param value integer
---@param used integer
---@return integer
function Render:offset(value, used)
    if value <= 0 then
        return 0
    end
    local result = env.win.percent(self.context.win, value, used)
    local text = vim.treesitter.get_node_text(self.node:get(), self.context.buf)
    if text:find('\t') then
        -- round to the next multiple of tab
        local tab = env.buf.get(self.context.buf, 'tabstop')
        result = math.ceil(result / tab) * tab
    end
    return result
end

---@private
---@param disable boolean|string[]
---@return boolean
function Render:enabled(disable)
    if type(disable) == 'boolean' then
        return not disable
    else
        local language = self.data.language
        return not language or not vim.tbl_contains(disable, language.text)
    end
end

---@protected
function Render:run()
    -- Anchor the content rows on the block body so the last body line is never
    -- cut off by background_inset or the end-marker offset.
    local body = self.node:child('listing_block_body')
        or self.node:child('literal_block_body')
    local start_row = body and body.start_row or self.node.start_row
    local end_row = body and (body.end_row - 1) or (self.node.end_row - 1)

    if self.config.conceal_delimiters then
        if self.data.attr then
            self.marks:over(self.config, true, self.data.attr, {
                conceal = '',
                conceal_lines = '',
            })
        end
        -- Delimiters for each block type
        local start_markers = {
            'listing_block_start_marker',
            'literal_block_marker',
            'passthrough_block_marker',
        }
        local end_markers = {
            'listing_block_end_marker',
            'passthrough_block_marker',
        }
        for _, name in ipairs(start_markers) do
            local m = self.node:child(name)
            if m then
                self.marks:over(self.config, true, m, { conceal = '' })
            end
        end
        for _, name in ipairs(end_markers) do
            local m = self.node:child(name)
            if m and vim.tbl_contains(start_markers, name) == false then
                self.marks:over(self.config, true, m, { conceal = '' })
            end
        end
    end

    self:language()

    local background = self:enabled(self.config.disable_background)
    if background then
        local inset = body and 0 or self.config.background_inset
        self:background(start_row + inset, end_row - inset)
    end
    self:padding(background)
end

---@private
function Render:language()
    if not self.config.language then
        return
    end
    local language = self.data.language
    if not language then
        return
    end

    local icon, icon_hl = icons.get(language.text)
    local language_hl = { icon_hl or self.config.highlight_fallback } ---@type string[]
    local border_hl = self.config.highlight_border or nil
    if border_hl then
        language_hl[#language_hl + 1] = border_hl
        border_hl = colors.bg_as_fg(border_hl)
    end

    local text = self:line()
    if self.config.language_icon and icon then
        text:text(icon .. ' ', language_hl)
    end
    if self.config.language_name then
        text:text(language.text, language_hl)
    end
    if text:empty() then
        return
    end

    local body = self:line()
        :text(self.config.language_left, border_hl)
        :extend(text)
        :text(self.config.language_right, border_hl)

    local anchor = self.node:child('listing_block_start_marker')
        or self.node:child('literal_block_marker')
        or self.node
    return self.marks:start(self.config, 'code_language', anchor, {
        virt_text = body:get(),
        virt_text_pos = 'overlay',
    })
end

---@private
---@param start_row integer
---@param end_row integer
function Render:background(start_row, end_row)
    local padding = self:line()
    local win_col = 0
    if self.config.width == 'block' then
        padding:pad(vim.o.columns * 2)
        win_col = self.data.margin + self.data.body + self:indent():size()
    end
    local col = self.node.start_col
    for row = start_row, end_row do
        self.marks:add(self.config, 'code_background', row, col, {
            end_row = row + 1,
            priority = self.config.priority,
            hl_group = self.config.highlight,
            hl_eol = true,
        })
        if not padding:empty() and win_col > 0 then
            -- overwrite anything beyond width with padding
            self.marks:add(self.config, 'code_background', row, col, {
                priority = 0,
                virt_text = padding:get(),
                virt_text_win_col = win_col,
            })
        end
    end
end

---@private
---@param background boolean
function Render:padding(background)
    local col = self.node.start_col
    local start_row, end_row = self.node.start_row, self.node.end_row - 1
    local empty = {} ---@type integer[]
    local widths = col == 0 and {} or self.node:widths()
    for i, width in ipairs(widths) do
        if width == 0 then
            empty[#empty + 1] = (start_row + i - 1)
        end
    end
    if #empty == 0 and self.data.margin <= 0 and self.data.padding <= 0 then
        return
    end
    local highlight = background and self.config.highlight or nil
    for row = start_row, end_row do
        local line = self:line()
        if vim.tbl_contains(empty, row) then
            line:pad(col)
        end
        line:pad(self.data.margin)
        if row > start_row and row < end_row then
            line:pad(self.data.padding, highlight)
        end
        if not line:empty() then
            self.marks:add(self.config, false, row, col, {
                priority = 100,
                virt_text = line:get(),
                virt_text_pos = 'inline',
            })
        end
    end
end

return Render
