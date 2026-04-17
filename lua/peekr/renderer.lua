local config = require('peekr.config')
local Renderer = {}
Renderer.__index = Renderer

function Renderer:new(bufnr)
  return setmetatable({
    lines = {}, hl = {}, line_nr = 0, current = '', bufnr = bufnr,
  }, self)
end

function Renderer:nl()
  table.insert(self.lines, self.current)
  self.current = ''
  self.line_nr = self.line_nr + 1
end

function Renderer:append(str, group, append_str)
  str = str:gsub('[\n]', ' ')
  if group then
    group = config.hl_ns .. group
    local from = #self.current
    table.insert(self.hl, {
      line_nr = self.line_nr, from = from, to = from + #str, group = group,
    })
  end
  self.current = self.current .. str
  if type(append_str) == 'string' then
    self.current = self.current .. append_str
  end
end

function Renderer:render()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, self.lines)
end

function Renderer:highlight()
  for _, h in ipairs(self.hl) do
    vim.api.nvim_buf_add_highlight(self.bufnr, config.namespace, h.group, h.line_nr, h.from, h.to)
  end
end

return Renderer
