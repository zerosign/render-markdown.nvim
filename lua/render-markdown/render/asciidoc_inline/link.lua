local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Link: render.md.Render
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
    -- If this autolink is inside a macro's target, skip it
    local ts = vim.treesitter.get_parser(self.context.buf, 'asciidoc')
    if ts then
        local main_tree = ts:parse()[1]
        if main_tree then
            local host = main_tree:root():descendant_for_range(
                self.node.start_row,
                self.node.start_col,
                self.node.start_row,
                self.node.start_col
            )
            while host do
                local htype = host:type()
                if
                    htype == 'block_macro'
                    or htype == 'inline_macro'
                    or htype == 'target'
                then
                    return false
                end
                host = host:parent()
            end
        end
    end
    return true
end

---@protected
function Render:run()
    local labled_uri = self.node:child('labled_uri')
    if labled_uri then
        local uri = labled_uri:child('uri')
        local label = labled_uri:child('uri_label')
        local is_email = uri and uri:child('email') ~= nil
        local icon_str = is_email and (self.config.email or '󰀓 ')
            or (self.config.hyperlink or '󰌹 ')

        -- Add icon before the link
        self.marks:add(
            self.config,
            false,
            self.node.start_row,
            self.node.start_col,
            {
                priority = 9000,
                hl_mode = 'combine',
                virt_text = { { icon_str, self.config.highlight } },
                virt_text_pos = 'inline',
            }
        )

        -- Conceal the raw URI
        if uri then
            self.marks:add(self.config, true, uri.start_row, uri.start_col, {
                end_row = uri.end_row,
                end_col = uri.end_col,
                conceal = '',
            })
        end

        -- Conceal the opening bracket `[`
        local bracket_start = uri and uri.end_col or self.node.start_col
        local label_start = label and label.start_col or bracket_start
        if label_start > bracket_start then
            self.marks:add(
                self.config,
                true,
                self.node.start_row,
                bracket_start,
                {
                    end_row = self.node.start_row,
                    end_col = label_start,
                    conceal = '',
                }
            )
        end

        -- Highlight the link label text
        if label then
            self.marks:add(
                self.config,
                false,
                label.start_row,
                label.start_col,
                {
                    end_row = label.end_row,
                    end_col = label.end_col,
                    hl_group = self.config.highlight,
                }
            )
        end

        -- Conceal the closing bracket `]`
        local label_end = label and label.end_col or labled_uri.end_col
        if labled_uri.end_col > label_end then
            self.marks:add(self.config, true, self.node.start_row, label_end, {
                end_row = labled_uri.end_row,
                end_col = labled_uri.end_col,
                conceal = '',
            })
        end
    else
        -- Raw URL or raw email
        local is_email = self.node:descendant('email') ~= nil
        local icon_str = is_email and (self.config.email or '󰀓 ')
            or (self.config.hyperlink or '󰌹 ')

        -- Add icon before the URL
        self.marks:add(
            self.config,
            false,
            self.node.start_row,
            self.node.start_col,
            {
                priority = 9000,
                hl_mode = 'combine',
                virt_text = { { icon_str, self.config.highlight } },
                virt_text_pos = 'inline',
            }
        )

        -- Highlight the raw URL/email without concealing it
        self.marks:add(
            self.config,
            false,
            self.node.start_row,
            self.node.start_col,
            {
                end_row = self.node.end_row,
                end_col = self.node.end_col,
                hl_group = self.config.highlight,
            }
        )
    end
end

return Render
