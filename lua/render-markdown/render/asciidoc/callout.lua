local Base = require('render-markdown.render.base')

---Map tree-sitter admonition node types to the lowercase callout key used to
---look up `config.callout[key]`.
local KIND = {
    admonition_note = 'note',
    admonition_tip = 'tip',
    admonition_important = 'important',
    admonition_caution = 'caution',
    admonition_warning = 'warning',
}

---@class render.md.render.asciidoc.Callout: render.md.Render
---@field private config render.md.callout.Configs
---@field private data render.md.callout.Data?
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.asciidoc.callout
    if not self.config then
        return false
    end
    local marker = self.node:child_at(0)
    if not marker then
        return false
    end
    local kind = KIND[marker.type]
    if not kind then
        return false
    end
    local cfg = self.config[kind]
    if not cfg then
        return false
    end
    self.data = { kind = kind, cfg = cfg }
    return true
end

---@protected
function Render:run()
    local cfg = assert(self.data.cfg)
    local node = self.node

    -- Conceal the admonition keyword (e.g. 'NOTE') plus the trailing ': '
    -- separator so the icon overlay takes its place.
    local marker = node:child_at(0)
    if marker then
        local end_col = marker.end_col + 2
        self.marks:add(self.config, true, marker.start_row, marker.start_col, {
            end_row = marker.start_row,
            end_col = end_col,
            conceal = '',
        })
    end

    -- Overlay the callout icon + rendered text at the start of the block.
    self.marks:over(self.config, 'callout', node, {
        virt_text = { { cfg.rendered, cfg.highlight } },
        virt_text_pos = 'overlay',
    })
end

return Render
