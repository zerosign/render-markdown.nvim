local Base = require('render-markdown.render.base')
local Node = require('render-markdown.lib.node')
local env = require('render-markdown.lib.env')
local str = require('render-markdown.lib.str')

---@class render.md.render.asciidoc.Math: render.md.Render
---@field private config render.md.latex.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.latex
    return true
end

---@protected
function Render:run()
    local attr = self:get_attr()
    -- Conceal the preceding [stem] / [latexmath] attribute line
    if attr then
        self.marks:over(self.config, true, attr, {
            conceal = '',
            conceal_lines = '',
        })
    end

    local last_row = self.node.end_col > 0 and self.node.end_row
        or (self.node.end_row - 1)
    local start_r = self.node.start_row + 1
    local end_r = last_row - 1

    local raw_text = ''
    local lines = {}
    if start_r <= end_r then
        lines = vim.api.nvim_buf_get_lines(
            self.context.buf,
            start_r,
            end_r + 1,
            false
        )
        raw_text = table.concat(lines, '\n')
    end

    local cmds = env.commands(self.config.converter)
    local converted = nil
    if
        self.config.enabled
        and self.config.block
        and #cmds > 0
        and #raw_text > 0
    then
        local cmd = cmds[1]
        if vim.system then
            local task = vim.system({ cmd }, { stdin = raw_text, text = true })
                :wait()
            if
                task.code == 0
                and task.stdout
                and #vim.trim(task.stdout) > 0
            then
                converted = vim.trim(task.stdout)
            end
        else
            local out = vim.fn.system(cmd, raw_text)
            if vim.v.shell_error == 0 and out and #vim.trim(out) > 0 then
                converted = vim.trim(out)
            end
        end
    end

    if converted then
        local out_lines = vim.split(converted, '\n')
        local virt_lines = {}
        for _, l in ipairs(out_lines) do
            local line = self:line()
            line:pad(2)
            line:text(l, self.config.highlight)
            virt_lines[#virt_lines + 1] = line:get()
        end
        self.marks:replace(self.config, self.node, virt_lines)
    else
        -- Conceal opening delimiter line (++++, ----, --)
        self.marks:add(self.config, true, self.node.start_row, 0, {
            end_row = self.node.start_row + 1,
            end_col = 0,
            conceal = '',
            conceal_lines = '',
        })

        -- Conceal closing delimiter line (++++, ----, --)
        self.marks:add(self.config, true, last_row, 0, {
            end_row = last_row + 1,
            end_col = 0,
            conceal = '',
            conceal_lines = '',
        })

        -- Fallback: highlight raw formula with RenderMarkdownMath
        for r = start_r, end_r do
            local line_text = lines[r - start_r + 1] or ''
            self.marks:add(self.config, false, r, 0, {
                end_row = r,
                end_col = #line_text,
                hl_group = self.config.highlight,
            })
        end
    end
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

return Render
