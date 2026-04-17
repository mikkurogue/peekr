local config = require('peekr.config')
local Winbar = {}
Winbar.__index = Winbar

function Winbar:new(winnr)
  return setmetatable({ sections = {}, winnr = winnr, last_values = {} }, self)
end

function Winbar:append(key, group)
  self.sections[key] = group and (config.hl_ns .. group) or nil
end

function Winbar:render(values)
  if vim.deep_equal(values, self.last_values) then return end
  local s = ''
  for section, value in pairs(values) do
    s = ('%s%%#%s# %s'):format(s, self.sections[section], value)
  end
  self.last_values = values
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(self.winnr) then
      vim.wo[self.winnr].winbar = s
    end
  end)
end

return Winbar
