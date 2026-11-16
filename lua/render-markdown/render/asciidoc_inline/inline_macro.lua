local Base = require('render-markdown.render.base')
local icons = require('render-markdown.lib.icons')
local str = require('render-markdown.lib.str')

---Map asciidoc macro names to display config.
---@type table<string, { icon: string, highlight: string }>
local MACRO_CONFIG = {
    image = { icon = '󰈚 ', highlight = 'RenderMarkdownLink' },
    link = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
    icon = { icon = '󰥔 ', highlight = 'RenderMarkdownLink' },
    pass = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
    footnote = { icon = '󰋚 ', highlight = 'RenderMarkdownLink' },
    footnoteref = { icon = '󰋚 ', highlight = 'RenderMarkdownLink' },
}

---@class render.md.render.asciidoc_inline.InlineMacro: render.md.Render
---@field private config render.md.link.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.link
    if not self.config.enabled then
        return false
    end
    return true
end

---@protected
function Render:run()
    local macro_name = self.node:child('macro_name')
    if not macro_name then
        return
    end
    local name = macro_name.text

    local cfg = MACRO_CONFIG[name]
    if not cfg then
        -- Unknown macro: conceal the whole macro
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

    -- Get the target (first positional argument) or attr
    local target = self.node:child('target') or self.node:child('attr')
    local target_text = target and target.text or ''

    -- Conceal the raw macro syntax
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

    -- Add icon and target text inline
    local line = self:line():text(cfg.icon, cfg.highlight)
    if #target_text > 0 then
        line:text(target_text, cfg.highlight)
    end
    self.marks:add(
        self.config,
        false,
        self.node.start_row,
        self.node.start_col,
        {
            virt_text = line:get(),
            virt_text_pos = 'inline',
        }
    )
end

return Render
