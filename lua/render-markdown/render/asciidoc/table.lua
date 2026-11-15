local Base = require('render-markdown.render.base')

---@class render.md.render.asciidoc.Table: render.md.Render
---@field private config render.md.table.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.pipe_table
    -- Table rendering is deferred for the asciidoc MVP; return no marks.
    return false
end

---@protected
function Render:run()
    -- no-op
end

return Render
