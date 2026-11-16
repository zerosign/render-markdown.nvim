local Base = require('render-markdown.render.base')

---Map asciidoc block macro names to display config.
---@type table<string, { icon: string, highlight: string }>
local MACRO_CONFIG = {
    image = { icon = '󰥶 ', highlight = 'RenderMarkdownLink' },
    link = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
    video = { icon = '󰕧 ', highlight = 'RenderMarkdownLink' },
    audio = { icon = '󰝚 ', highlight = 'RenderMarkdownLink' },
    toc = { icon = '󰠮 ', highlight = 'RenderMarkdownLink' },
    icon = { icon = '󰥔 ', highlight = 'RenderMarkdownLink' },
    pass = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
    stem = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
    asciimath = { icon = '󰨊 ', highlight = 'RenderMarkdownCodeInline' },
    footnote = { icon = '󰋚 ', highlight = 'RenderMarkdownLink' },
    footnoteref = { icon = '󰋚 ', highlight = 'RenderMarkdownLink' },
}

---@class render.md.render.asciidoc.BlockMacro: render.md.Render
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

---@private
---@return string?
function Render:get_alt_text()
    local alt_text = nil
    self.node:for_each_child(function(child)
        if alt_text then
            return
        end
        if child.type == 'block_macro_attr' then
            local attr_name = child:child('attribute_name')
            local attr_val = child:child('attribute_value')
            if attr_val and attr_name and vim.trim(attr_name.text) == 'alt' then
                -- Named alt="...", strip quotes
                local text = vim.trim(attr_val.text)
                alt_text = text:match('^["\']?(.-)["\']?$')
            elseif not attr_val and attr_name then
                -- First positional attribute is the alt text / caption
                local text = vim.trim(attr_name.text)
                if #text > 0 then
                    alt_text = text
                end
            end
        end
    end)
    return alt_text
end

---@protected
function Render:run()
    local macro_name = self.node:child('block_macro_name')
    if not macro_name then
        return
    end
    local name = macro_name.text

    local cfg = MACRO_CONFIG[name]
        or { icon = '󰈚 ', highlight = 'RenderMarkdownLink' }

    local target = self.node:child('target')
    local target_text = target and vim.trim(target.text) or ''

    local display_text = self:get_alt_text()
    if not display_text or #display_text == 0 then
        display_text = target_text
    end

    local icon = cfg.icon
    if name == 'image' and self.config.image then
        icon = self.config.image
    elseif name == 'link' and self.config.hyperlink then
        icon = self.config.hyperlink
    end

    -- Conceal the raw block macro syntax on this line
    local line_text = vim.api.nvim_buf_get_lines(
        self.context.buf,
        self.node.start_row,
        self.node.start_row + 1,
        false
    )[1] or ''

    self.marks:add(
        self.config,
        true,
        self.node.start_row,
        self.node.start_col,
        {
            end_row = self.node.start_row,
            end_col = #line_text,
            conceal = '',
        }
    )

    -- Display icon and alt text / display text inline
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
