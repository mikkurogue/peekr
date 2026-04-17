--- Peekr preview window with treesitter highlighting support.
local config = require('peekr.config')
local utils = require('peekr.utils')
local Winbar = require('peekr.winbar')

local Preview = {}
Preview.__index = Preview

local touched_buffers = {}

local winhl = {
  'Normal:PeekrPreviewNormal',
  'NormalFloat:PeekrPreviewNormal',
  'CursorLine:PeekrPreviewCursorLine',
  'SignColumn:PeekrPreviewSignColumn',
  'EndOfBuffer:PeekrPreviewEndOfBuffer',
  'LineNr:PeekrPreviewLineNr',
}

local base_win_opts = {
  winfixwidth = true,
  winfixheight = true,
  cursorbind = false,
  scrollbind = false,
  winhighlight = table.concat(winhl, ','),
}

local float_only_opts = {
  'number', 'relativenumber', 'cursorline', 'cursorcolumn',
  'foldcolumn', 'spell', 'list', 'signcolumn', 'colorcolumn',
  'fillchars', 'winhighlight',
}

local function clear_hl(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, 0, -1)
  end
end

--- Ensure treesitter highlighting is active for a buffer.
--- This is the key difference from glance.nvim — we force treesitter
--- to provide syntax highlighting in the floating preview buffer.
local function ensure_treesitter(bufnr)
  if not config.options.treesitter.enable then return end

  -- Get the filetype of the buffer
  local ft = vim.bo[bufnr].filetype
  if ft == '' then return end

  -- Try to get the language for this filetype
  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then return end

  -- Check if parser exists
  local ok = pcall(vim.treesitter.language.add, lang)
  if not ok then return end

  -- Start treesitter highlighting if not already active
  local has_ts = pcall(vim.treesitter.get_parser, bufnr, lang)
  if has_ts then
    -- Use vim.treesitter.start which is the modern API (0.10+)
    pcall(vim.treesitter.start, bufnr, lang)
  end
end

function Preview.create(opts)
  local merged = vim.tbl_extend('keep', base_win_opts, config.options.preview_win_opts or {})
  local preview = Preview:new(opts, merged)
  return preview
end

function Preview:new(opts, wopts)
  local winnr = vim.api.nvim_open_win(opts.preview_bufnr, false, opts.win_opts)

  local scope = {
    winnr = winnr,
    bufnr = opts.preview_bufnr,
    parent_winnr = opts.parent_winnr,
    parent_bufnr = opts.parent_bufnr,
    current_location = nil,
    winbar = nil,
    _wopts = wopts,
  }

  -- Apply win options using modern API
  for k, v in pairs(wopts) do
    if not vim.tbl_contains(float_only_opts, k) then
      pcall(function() vim.wo[winnr][k] = v end)
    end
  end
  for _, k in ipairs(float_only_opts) do
    if wopts[k] ~= nil then
      pcall(function() vim.wo[winnr][k] = wopts[k] end)
    end
  end

  if config.options.winbar.enable then
    table.insert(float_only_opts, 'winbar')
    scope.winbar = Winbar:new(winnr)
    scope.winbar:append('filename', 'WinBarFilename')
    scope.winbar:append('filepath', 'WinBarFilepath')
  end

  -- Enable treesitter on the initial buffer
  ensure_treesitter(opts.preview_bufnr)

  setmetatable(scope, self)
  return scope
end

function Preview:is_valid()
  return self.winnr and vim.api.nvim_win_is_valid(self.winnr)
end

function Preview:on_attach_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local throttled, timer = utils.throttle(function()
    if self.current_location and bufnr == self.current_location.bufnr then
      if vim.fn.buflisted(bufnr) ~= 1 then
        vim.bo[bufnr].buflisted = true
        vim.bo[bufnr].bufhidden = ''
      end
    end
  end, 1000)

  local autocmd_id = vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = 'Peekr',
    buffer = bufnr,
    callback = throttled,
  })

  self._detach = function()
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
    if timer then timer:close(); timer = nil end
  end

  local kopts = { buffer = bufnr, noremap = true, nowait = true, silent = true }
  for key, action in pairs(config.options.mappings.preview) do
    vim.keymap.set('n', key, action, kopts)
  end
end

function Preview:on_detach_buffer(bufnr)
  if type(self._detach) == 'function' then self._detach(); self._detach = nil end
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    for lhs, _ in pairs(config.options.mappings.preview) do
      pcall(vim.api.nvim_buf_del_keymap, bufnr, 'n', lhs)
    end
  end
end

function Preview:restore_win_opts()
  if not vim.api.nvim_win_is_valid(self.parent_winnr) then return end
  if not vim.api.nvim_win_is_valid(self.winnr) then return end
  for opt, _ in pairs(self._wopts) do
    if not vim.tbl_contains(float_only_opts, opt) then
      pcall(function()
        vim.wo[self.winnr][opt] = vim.wo[self.parent_winnr][opt]
      end)
    end
  end
  for _, opt in ipairs(float_only_opts) do
    pcall(function()
      vim.wo[self.winnr][opt] = vim.wo[self.parent_winnr][opt]
    end)
  end
end

function Preview:close()
  self:on_detach_buffer((self.current_location or {}).bufnr)
  self:restore_win_opts()

  if vim.api.nvim_win_is_valid(self.winnr) then
    vim.api.nvim_win_close(self.winnr, true)
  end

  for _, bufnr in ipairs(touched_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) ~= 1 then
      pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
      vim.api.nvim_buf_delete(bufnr, { force = true })
    else
      clear_hl(bufnr)
    end
  end
  touched_buffers = {}
end

function Preview:clear_hl()
  for _, bufnr in ipairs(touched_buffers) do clear_hl(bufnr) end
  touched_buffers = {}
end

function Preview:hl_buf(location)
  for row = location.start_line, location.end_line do
    local sc = row == location.start_line and location.start_col or 0
    local ec = row == location.end_line and location.end_col or -1
    vim.api.nvim_buf_add_highlight(location.bufnr, config.namespace, config.hl_ns .. 'PreviewMatch', row, sc, ec)
  end
end

function Preview:update(item, group)
  if not vim.api.nvim_win_is_valid(self.winnr) then return end
  if not item or item.is_group or item.is_unreachable then return end
  if vim.deep_equal(self.current_location, item) then return end

  local cur_buf = (self.current_location or {}).bufnr

  if cur_buf ~= item.bufnr then
    self:restore_win_opts()
    self:on_detach_buffer(cur_buf)
    vim.api.nvim_win_set_buf(self.winnr, item.bufnr)

    -- Re-apply win options
    for k, v in pairs(self._wopts) do
      pcall(function() vim.wo[self.winnr][k] = v end)
    end

    if self.winbar then
      self.winbar:render({
        filename = vim.fn.fnamemodify(item.filename, ':t'),
        filepath = vim.fn.fnamemodify(item.filename, ':p:~:h'),
      })
    end

    -- Trigger filetype detection and treesitter
    vim.api.nvim_buf_call(item.bufnr, function()
      if vim.bo[item.bufnr].filetype == '' then
        vim.cmd('do BufRead')
      end
    end)

    -- Enable treesitter highlighting in the preview
    ensure_treesitter(item.bufnr)

    self:on_attach_buffer(item.bufnr)
  end

  vim.api.nvim_win_set_cursor(self.winnr, { item.start_line + 1, item.start_col })
  vim.api.nvim_win_call(self.winnr, function()
    vim.cmd('norm! zv')
    vim.cmd('norm! zz')
  end)

  self.current_location = item

  if not vim.tbl_contains(touched_buffers, item.bufnr) then
    for _, loc in pairs(group.items) do
      self:hl_buf(loc)
    end
    table.insert(touched_buffers, item.bufnr)
  end
end

function Preview:destroy()
  self.winnr = nil
  self.bufnr = nil
  self.parent_winnr = nil
  self.parent_bufnr = nil
  self.current_location = nil
  self.winbar = nil
end

return Preview
