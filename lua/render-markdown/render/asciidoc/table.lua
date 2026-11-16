local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.Table: render.md.Render
---@field private config render.md.pipe_table.Config
---@field private data render.md.table.Data?
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.table
    if not self.config.enabled then
        return false
    end
    self.data = { rows = 0, cols = 0 }
    return true
end

---@protected
function Render:run()
    if self.node.type == 'table_block' then
        self:render_pipe_table()
    else
        -- Conceal block markers and cell delimiters for csv/dsv/ntable
        self:conceal_block_markers()
        if self.node.type == 'csv_table_block' then
            self:conceal_csv_delimiters()
        elseif self.node.type == 'dsv_table_block' then
            self:conceal_dsv_delimiters()
        elseif self.node.type == 'ntable_block' then
            self:conceal_ntable_delimiters()
        end
        self:add_borders()
    end
end

---Render an asciidoc pipe table (|===) as a formatted Unicode box table.
---@private
function Render:render_pipe_table()
    local attr = self:get_attr()
    local attr_text = attr and attr.text or nil

    -- 1. Gather all cells from table_block children
    local cells = {} ---@type { node: render.md.Node, text: string, start_row: integer, end_row: integer }[]
    for child in self.node:get():iter_children() do
        local t = child:type()
        if t == 'table_cell' or t:find('cell') then
            local cnode = self.node:create(child)
            local raw = vim.treesitter.get_node_text(child, self.context.buf)
                or ''
            local text = raw:gsub('^[ \t]*[|¦]', ''):gsub('[|¦][ \t]*$', '')
            text = text:match('^%s*(.-)%s*$') or ''
            local c_end_row = (
                cnode.end_col == 0 and cnode.end_row > cnode.start_row
            )
                    and (cnode.end_row - 1)
                or cnode.end_row
            cells[#cells + 1] = {
                node = cnode,
                text = text,
                start_row = cnode.start_row,
                end_row = c_end_row,
            }
        end
    end

    if #cells == 0 then
        self:conceal_block_markers()
        return
    end

    -- 2. Determine number of columns and alignments
    local num_cols, alignments = self:parse_cols(attr_text)
    if not num_cols or num_cols <= 0 then
        local first_row = cells[1].start_row
        num_cols = 0
        for _, cell in ipairs(cells) do
            if cell.start_row == first_row then
                num_cols = num_cols + 1
            else
                break
            end
        end
        if num_cols == 0 then
            num_cols = 1
        end
        alignments = {}
        for i = 1, num_cols do
            alignments[i] = 'left'
        end
    end

    -- 3. Group cells into rows (AsciiDoc fills row-by-row, left-to-right)
    local rows = {} ---@type { cells: string[], start_row: integer, end_row: integer }[]
    local num_rows = math.ceil(#cells / num_cols)
    for r = 1, num_rows do
        local row_cells = {}
        local r_start = nil
        local r_end = nil
        for c = 1, num_cols do
            local idx = (r - 1) * num_cols + c
            local cell = cells[idx]
            if cell then
                row_cells[c] = cell.text
                if not r_start or cell.start_row < r_start then
                    r_start = cell.start_row
                end
                if not r_end or cell.end_row > r_end then
                    r_end = cell.end_row
                end
            else
                row_cells[c] = ''
            end
        end
        rows[r] = {
            cells = row_cells,
            start_row = r_start or self.node.start_row,
            end_row = r_end or r_start or self.node.start_row,
        }
    end

    -- 4. Calculate column widths
    local padding = self.config.padding or 1
    local min_width = self.config.min_width or 0
    local col_widths = {}
    for c = 1, num_cols do
        local max_w = min_width
        for r = 1, num_rows do
            local w = str.width(rows[r].cells[c]) + 2 * padding
            if w > max_w then
                max_w = w
            end
        end
        col_widths[c] = max_w
    end

    -- 5. Build horizontal border strings
    local border = self.config.border
    local icon_h = border[11]
    local icon_v = border[10]
    local parts = {}
    for c = 1, num_cols do
        parts[c] = icon_h:rep(col_widths[c])
    end

    local top_border = border[1] .. table.concat(parts, border[2]) .. border[3]
    local delimiter = border[4] .. table.concat(parts, border[5]) .. border[6]
    local bottom_border = border[7]
        .. table.concat(parts, border[8])
        .. border[9]

    -- 6. Build lines for marks:replace
    local lines = {} ---@type render.md.mark.Line[]

    -- Top border
    if self.config.border_enabled ~= false then
        local line = self:line()
        line:text(top_border, self.config.head)
        lines[#lines + 1] = line:get()
    end

    -- Rows and delimiter
    for r = 1, num_rows do
        local row = rows[r]
        local is_head = (r == 1)
        local hl = is_head and self.config.head or self.config.row

        local line = self:line()
        line:text(icon_v, hl)
        for c = 1, num_cols do
            local text = row.cells[c]
            local align = alignments[c] or 'left'
            local inner_w = col_widths[c] - 2 * padding
            local text_w = str.width(text)
            local extra = math.max(inner_w - text_w, 0)
            local left_pad, right_pad
            if align == 'right' then
                left_pad = padding + extra
                right_pad = padding
            elseif align == 'center' then
                local left_extra = math.floor(extra / 2)
                left_pad = padding + left_extra
                right_pad = padding + (extra - left_extra)
            else
                left_pad = padding
                right_pad = padding + extra
            end
            line:pad(left_pad)
            line:text(text, hl)
            line:pad(right_pad)
            line:text(icon_v, hl)
        end
        lines[#lines + 1] = line:get()

        -- Add delimiter below header row
        if is_head and num_rows > 1 then
            local delim_line = self:line()
            delim_line:text(delimiter, self.config.head)
            lines[#lines + 1] = delim_line:get()
        end
    end

    -- Bottom border
    if self.config.border_enabled ~= false then
        local line = self:line()
        line:text(bottom_border, self.config.row)
        lines[#lines + 1] = line:get()
    end

    -- 7. Conceal preceding [cols="..."] element_attr line
    if attr then
        self.marks:over(self.config, true, attr, {
            conceal = '',
            conceal_lines = '',
        })
    end

    -- 8. Entirely replace table_block with formatted table virt_lines
    self.marks:replace(self.config, self.node, lines)
end

---@private
---@param attr_text string?
---@return integer?, string[]?
function Render:parse_cols(attr_text)
    if not attr_text then
        return nil, nil
    end
    local cols_str = attr_text:match('cols%s*=%s*"([^"]+)"')
        or attr_text:match("cols%s*=%s*'([^']+)'")
        or attr_text:match('cols%s*=%s*([%w%*^<>,]+)')
    if not cols_str then
        return nil, nil
    end

    local parts = vim.split(cols_str, '%s*,%s*')
    local alignments = {}
    for _, part in ipairs(parts) do
        local mult_count, mult_align = part:match('^(%d+)%*([<>%^]?)')
        if mult_count then
            local count = tonumber(mult_count) or 1
            local align = (mult_align == '>' and 'right')
                or (mult_align == '^' and 'center')
                or 'left'
            for _ = 1, count do
                alignments[#alignments + 1] = align
            end
        else
            local align = (part:find('>') and 'right')
                or (part:find('%^') and 'center')
                or 'left'
            alignments[#alignments + 1] = align
        end
    end
    return #alignments, alignments
end

---@private
---@return render.md.Node?
function Render:get_attr()
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

---Conceal the table block start/end markers (e.g. |===, ,===).
function Render:conceal_block_markers()
    for child in self.node:get():iter_children() do
        local t = child:type()
        if t:find('marker') then
            local marker = self.node:create(child)
            self.marks:add(
                self.config,
                true,
                marker.start_row,
                marker.start_col,
                {
                    end_row = marker.end_row,
                    end_col = marker.end_col,
                    conceal = '',
                }
            )
        end
    end
end

---Conceal the `|` cell separators in a pipe table.
function Render:conceal_pipe_delimiters()
    self.node:for_each_child(function(cell)
        local pipe = self:find_pipe(cell)
        if pipe then
            self.marks:add(self.config, true, pipe.start_row, pipe.start_col, {
                end_row = pipe.end_row,
                end_col = pipe.end_col,
                conceal = '',
            })
        end
    end)
end

---Find the pipe separator node within a table_cell by scanning its text.
---@param cell render.md.Node
---@return render.md.Node?
function Render:find_pipe(cell)
    for child in cell:get():iter_children() do
        local text = vim.treesitter.get_node_text(child, self.context.buf)
        if text == '|' or text == '¦' then
            return self.node:create(child)
        end
    end
    return nil
end

---Conceal the `,` delimiters in a CSV table.
function Render:conceal_csv_delimiters()
    self.node:for_each_child(function(record)
        record:for_each_child(function(child)
            local text =
                vim.treesitter.get_node_text(child:get(), self.context.buf)
            if text == ',' then
                self.marks:add(
                    self.config,
                    true,
                    child.start_row,
                    child.start_col,
                    {
                        end_row = child.end_row,
                        end_col = child.end_col,
                        conceal = '',
                    }
                )
            end
        end)
    end)
end

---Conceal the `:` delimiters in a DSV table.
function Render:conceal_dsv_delimiters()
    self.node:for_each_child(function(record)
        record:for_each_child(function(child)
            local text =
                vim.treesitter.get_node_text(child:get(), self.context.buf)
            if text == ':' then
                self.marks:add(
                    self.config,
                    true,
                    child.start_row,
                    child.start_col,
                    {
                        end_row = child.end_row,
                        end_col = child.end_col,
                        conceal = '',
                    }
                )
            end
        end)
    end)
end

---Conceal the `!` delimiters in an NTable.
function Render:conceal_ntable_delimiters()
    self.node:for_each_child(function(cell)
        local text = vim.treesitter.get_node_text(cell:get(), self.context.buf)
        local first_char = text:sub(1, 1)
        if first_char == '!' then
            self.marks:add(self.config, true, cell.start_row, cell.start_col, {
                end_row = cell.start_row,
                end_col = cell.start_col + 1,
                conceal = '',
            })
        end
    end)
end

---Add top and bottom border lines around the table.
function Render:add_borders()
    local border_char = '─'
    local width = vim.o.columns
    local line = self:line():rep(border_char, width, self.config.head)
    local top_row = self.node.start_row
    local bottom_row = self.node.end_row - 1

    self.marks:add(self.config, false, top_row, 0, {
        virt_text = line:get(),
        virt_text_pos = 'overlay',
    })
    self.marks:add(self.config, false, bottom_row, 0, {
        virt_text = line:get(),
        virt_text_pos = 'overlay',
    })
end

return Render
