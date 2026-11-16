local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc_inline.Xref: render.md.Render
---@field private config render.md.link.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.link
    return self.config.enabled
end

---@protected
function Render:run()
    -- Overlay a link icon before the cross reference
    local icon = { self.config.hyperlink or '󰌹 ', self.config.highlight } ---@type render.md.mark.Text
    self.marks:add(
        self.config,
        false,
        self.node.start_row,
        self.node.start_col,
        {
            priority = 9000,
            hl_mode = 'combine',
            virt_text = { icon },
            virt_text_pos = 'inline',
        }
    )

    local reftext = self.node:child('reftext')
    if reftext then
        -- Conceal `<<id,` prefix
        self.marks:add(
            self.config,
            true,
            self.node.start_row,
            self.node.start_col,
            {
                end_row = self.node.start_row,
                end_col = reftext.start_col,
                conceal = '',
            }
        )
        -- Highlight the displayed reftext label
        self.marks:add(
            self.config,
            false,
            reftext.start_row,
            reftext.start_col,
            {
                end_row = reftext.end_row,
                end_col = reftext.end_col,
                hl_group = self.config.highlight,
            }
        )
        -- Conceal `>>` suffix
        self.marks:add(
            self.config,
            true,
            self.node.start_row,
            reftext.end_col,
            {
                end_row = self.node.end_row,
                end_col = self.node.end_col,
                conceal = '',
            }
        )
    else
        -- No label, display the id
        local id = self.node:child('id')
        if id then
            -- Conceal `<<`
            self.marks:add(
                self.config,
                true,
                self.node.start_row,
                self.node.start_col,
                {
                    end_row = self.node.start_row,
                    end_col = id.start_col,
                    conceal = '',
                }
            )
            -- Highlight id
            self.marks:add(self.config, false, id.start_row, id.start_col, {
                end_row = id.end_row,
                end_col = id.end_col,
                hl_group = self.config.highlight,
            })
            -- Conceal `>>`
            self.marks:add(self.config, true, self.node.start_row, id.end_col, {
                end_row = self.node.end_row,
                end_col = self.node.end_col,
                conceal = '',
            })
        end
    end
end

return Render
