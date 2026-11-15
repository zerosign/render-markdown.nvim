local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.Table: render.md.Render
---@field private config render.md.pipe_table.Config
---@field private data render.md.table.Data?
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.pipe_table
    if not self.config.enabled then
        return false
    end
    self.data = { rows = 0, cols = 0 }
    return true
end

---@protected
function Render:run()
    -- Conceal the table block markers (|===, ,===, :===, !===)
    self:conceal_block_markers()

    -- Conceal cell delimiters based on table type
    if self.node.type == 'table_block' then
        self:conceal_pipe_delimiters()
    elseif self.node.type == 'csv_table_block' then
        self:conceal_csv_delimiters()
    elseif self.node.type == 'dsv_table_block' then
        self:conceal_dsv_delimiters()
    elseif self.node.type == 'ntable_block' then
        self:conceal_ntable_delimiters()
    end

    -- Add top and bottom borders
    self:add_borders()
end

---Conceal the table block start/end markers (e.g. |===, ,===).
function Render:conceal_block_markers()
    for _, target in ipairs({ 'table_block_marker', 'csv_table_block_marker',
        'dsv_table_block_marker', 'ntable_block_marker' }) do
        local marker = self.node:child(target)
        if marker then
            self.marks:add(self.config, true, marker.start_row, marker.start_col, {
                end_row = marker.end_row,
                end_col = marker.end_col,
                conceal = '',
            })
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
    -- The pipe separator is the first child of table_cell that is exactly '|' or '¦'
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
            local text = vim.treesitter.get_node_text(child:get(), self.context.buf)
            if text == ',' then
                self.marks:add(self.config, true, child.start_row, child.start_col, {
                    end_row = child.end_row,
                    end_col = child.end_col,
                    conceal = '',
                })
            end
        end)
    end)
end

---Conceal the `:` delimiters in a DSV table.
function Render:conceal_dsv_delimiters()
    self.node:for_each_child(function(record)
        record:for_each_child(function(child)
            local text = vim.treesitter.get_node_text(child:get(), self.context.buf)
            if text == ':' then
                self.marks:add(self.config, true, child.start_row, child.start_col, {
                    end_row = child.end_row,
                    end_col = child.end_col,
                    conceal = '',
                })
            end
        end)
    end)
end

---Conceal the `!` delimiters in an NTable.
function Render:conceal_ntable_delimiters()
    self.node:for_each_child(function(cell)
        -- ntable_cell starts with '!' followed by content
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
