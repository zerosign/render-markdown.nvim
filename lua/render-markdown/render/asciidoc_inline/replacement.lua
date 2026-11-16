local Base = require('render-markdown.render.base')
local str = require('render-markdown.lib.str')

---Map asciidoc replacements to their unicode equivalents.
---@type table<string, string>
local REPLACEMENT_MAP = {
    ['(C)'] = '©',
    ['(R)'] = '®',
    ['(TM)'] = '™',
    ['...'] = '…',
    ["`'"] = '``',
}

---@class render.md.render.asciidoc_inline.Replacement: render.md.Render
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
    local text = self.node.text
    local replacement = REPLACEMENT_MAP[text] or text

    -- Conceal the replacement text and show the unicode equivalent
    self.marks:add(self.config, true, self.node.start_row, self.node.start_col, {
        end_row = self.node.end_row,
        end_col = self.node.end_col,
        conceal = '',
    })

    self.marks:over(self.config, 'replacement', self.node, {
        virt_text = { { replacement, self.config.highlight } },
        virt_text_pos = 'overlay',
    })
end

return Render
