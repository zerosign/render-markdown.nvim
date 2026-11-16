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
    stem = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
    asciimath = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
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
        self.marks:add(self.config, true, self.node.start_row, self.node.start_col, {
            end_row = self.node.end_row,
            end_col = self.node.end_col,
            conceal = '',
        })
        return
    end

    -- Get the target (first positional argument)
    local target = self.node:child('target')
    local target_text = target and target.text or ''

    -- Overlay the macro icon at the start
    local icon_line = self:line():text(cfg.icon, cfg.highlight)
    self.marks:over(self.config, 'inline_macro', self.node, {
        virt_text = icon_line:get(),
        virt_text_pos = 'overlay',
    })

    -- Conceal the macro syntax (macro_name:target[attr])
    self.marks:add(self.config, true, self.node.start_row, self.node.start_col, {
        end_row = self.node.end_row,
        end_col = self.node.end_col,
        conceal = '',
    })

    -- If there's a target, show it as text after the concealed macro
    if target and #target_text > 0 then
        local target_line = self:line():text(target_text, cfg.highlight)
        self.marks:add(self.config, false, self.node.start_row, self.node.start_col, {
            virt_text = target_line:get(),
            virt_text_pos = 'inline',
        })
    end
end

return Render
