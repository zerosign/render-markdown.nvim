local Base = require('render-markdown.render.base')
local env = require('render-markdown.lib.env')

---@class render.md.render.asciidoc_inline.Stem: render.md.Render
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
    local attr = self.node:child('attr')
    if not attr then
        -- Conceal empty stem macro e.g. stem:[]
        self.marks:add(
            self.config,
            true,
            self.node.start_row,
            self.node.start_col,
            {
                end_row = self.node.end_row,
                end_col = self.node.end_col,
                conceal = '',
            }
        )
        return
    end

    -- Conceal opening delimiter (e.g. `stem:[`, `latexmath:[`, `asciimath:[`)
    if attr.start_col > self.node.start_col then
        self.marks:add(
            self.config,
            true,
            self.node.start_row,
            self.node.start_col,
            {
                end_row = self.node.start_row,
                end_col = attr.start_col,
                conceal = '',
            }
        )
    end

    -- Conceal closing delimiter (`]`)
    if self.node.end_col > attr.end_col then
        self.marks:add(self.config, true, self.node.start_row, attr.end_col, {
            end_row = self.node.start_row,
            end_col = self.node.end_col,
            conceal = '',
        })
    end

    -- If LaTeX converter is NOT active, highlight the formula with RenderMarkdownMath
    local converter_active = self.config.enabled
        and self.config.inline
        and #env.commands(self.config.converter) > 0

    if not converter_active then
        self.marks:add(self.config, false, attr.start_row, attr.start_col, {
            end_row = attr.end_row,
            end_col = attr.end_col,
            hl_group = self.config.highlight or 'RenderMarkdownMath',
        })
    end
end

return Render
