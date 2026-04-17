--- Peekr highlights — inherits directly from your colorscheme.
local config = require('peekr.config')
local M = {}

local function set_hl(group, value)
  vim.api.nvim_set_hl(0, config.hl_ns .. group, vim.tbl_extend('keep', value, { default = true }))
end

local function setup_links()
  -- Preview — inherit NormalFloat so it matches your float style
  set_hl('PreviewNormal', { link = 'NormalFloat' })
  set_hl('PreviewCursorLine', { link = 'CursorLine' })
  set_hl('PreviewSignColumn', { link = 'SignColumn' })
  set_hl('PreviewLineNr', { link = 'LineNr' })
  set_hl('PreviewMatch', { link = 'Search' })

  -- List — same NormalFloat bg
  set_hl('ListNormal', { link = 'NormalFloat' })
  set_hl('ListCursorLine', { link = 'CursorLine' })
  set_hl('ListMatch', { link = 'Search' })
  set_hl('ListFilename', { link = 'Directory' })
  set_hl('ListFilepath', { link = 'Comment' })
  set_hl('ListCount', { link = 'Number' })

  -- Hide end-of-buffer tildes — fg matches NormalFloat bg
  local float_hl = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
  local float_bg = float_hl.bg and ('#%06x'):format(float_hl.bg) or nil
  if float_bg then
    set_hl('PreviewEndOfBuffer', { fg = float_bg, bg = float_bg })
    set_hl('ListEndOfBuffer', { fg = float_bg, bg = float_bg })
  else
    set_hl('PreviewEndOfBuffer', { link = 'NormalFloat' })
    set_hl('ListEndOfBuffer', { link = 'NormalFloat' })
  end

  -- Separator between list and preview — use NormalFloat bg with FloatBorder fg
  local border_hl = vim.api.nvim_get_hl(0, { name = 'FloatBorder', link = false })
  local border_fg = border_hl.fg and ('#%06x'):format(border_hl.fg) or nil
  if float_bg and border_fg then
    set_hl('Separator', { fg = border_fg, bg = float_bg })
  else
    set_hl('Separator', { link = 'FloatBorder' })
  end

  -- Borders
  set_hl('Border', { link = 'FloatBorder' })

  -- Title in the border
  set_hl('Title', { link = 'FloatTitle' })

  -- Fold & indent
  set_hl('FoldIcon', { link = 'Comment' })
  set_hl('Indent', { link = 'Comment' })

  -- Winbar
  set_hl('WinBarFilename', { link = 'FloatTitle' })
  set_hl('WinBarFilepath', { link = 'Comment' })
  set_hl('WinBarTitle', { link = 'FloatTitle' })
end

function M.setup()
  setup_links()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('PeekrColorScheme', { clear = true }),
    callback = setup_links,
  })
end

return M
