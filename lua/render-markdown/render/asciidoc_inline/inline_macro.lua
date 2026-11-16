local Base = require('render-markdown.render.base')
local icons = require('render-markdown.lib.icons')
local str = require('render-markdown.lib.str')

---Map asciidoc macro names to display config.
---@type table<string, { icon: string, highlight: string }>
local MACRO_CONFIG = {
    image = { icon = '󰈚 ', highlight = 'RenderMarkdownLink' },
    link = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
    mailto = { icon = '󰀓 ', highlight = 'RenderMarkdownLink' },
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

    -- For link and mailto macros, prefer the label (attr) if present, else target
    local display_text = ''
    if name == 'mailto' or name == 'link' then
        local attr = self.node:child('attr')
        local target = self.node:child('target')
        if attr and #vim.trim(attr.text) > 0 then
            display_text = vim.trim(attr.text)
        elseif target and #vim.trim(target.text) > 0 then
            display_text = vim.trim(target.text)
        end
    else
        local target = self.node:child('target') or self.node:child('attr')
        display_text = target and target.text or ''
    end

    local icon = cfg.icon
    if name == 'mailto' and self.config.email then
        icon = self.config.email
    elseif (name == 'link' or name == 'image') and self.config.hyperlink then
        icon = self.config.hyperlink
    end

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

    -- Add icon and display text inline
    local line = self:line():text(icon, cfg.highlight)
    if #display_text > 0 then
        line:text(display_text, cfg.highlight)
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
