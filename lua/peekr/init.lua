--- Peekr — A modern LSP peek plugin for Neovim 0.12+
--- Supports ALL standard LSP location methods with treesitter highlighting.
--- Clean floating window UI that inherits your colorscheme.
local config = require('peekr.config')
local highlights = require('peekr.highlights')
local utils = require('peekr.utils')
local lsp = require('peekr.lsp')

local Peekr = {}
local peekr = {}
Peekr.__index = Peekr
local initialized = false
local last_session = nil

---@param opts? table
function Peekr.setup(opts)
  if initialized then return end
  config.setup(opts, Peekr.actions)
  highlights.setup()
  lsp.setup()
  initialized = true
end

local function is_open()
  if vim.tbl_isempty(peekr) then return false end
  return (peekr.preview and peekr.preview:is_valid()) and (peekr.list and peekr.list:is_valid())
end

--- Compute the float geometry: centered on screen, list + preview side by side
local function get_layout()
  local opts = config.options
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines - vim.o.cmdheight - 1 -- subtract statusline/cmdline

  -- Total float dimensions
  local total_w = math.floor(editor_w * opts.width)
  local total_h = math.min(opts.height, editor_h - 4) -- leave some breathing room

  -- Center it
  local row = math.floor((editor_h - total_h) / 2)
  local col = math.floor((editor_w - total_w) / 2)

  -- List and preview widths (inside the float, no border counted)
  local list_w = math.floor(total_w * opts.list.width)
  local preview_w = total_w - list_w - 1 -- -1 for the separator

  local lpos = opts.list.position
  local list_col = lpos == 'left' and col or (col + preview_w + 1)
  local preview_col = lpos == 'left' and (col + list_w + 1) or col

  return {
    total_w = total_w,
    total_h = total_h,
    list = {
      relative = 'editor',
      width = list_w,
      height = total_h,
      row = row,
      col = list_col,
      zindex = opts.zindex,
      border = 'none',
      style = 'minimal',
    },
    preview = {
      relative = 'editor',
      width = preview_w,
      height = total_h,
      row = row,
      col = preview_col,
      zindex = opts.zindex,
      border = 'none',
    },
    -- Outer border window (background + border)
    backdrop = {
      relative = 'editor',
      width = total_w,
      height = total_h,
      row = row,
      col = col,
      zindex = opts.zindex - 1,
      border = opts.border,
      style = 'minimal',
    },
    row = row,
    col = col,
  }
end

local function create(results, parent_buf, parent_win, params, method, enc)
  peekr = Peekr:create({
    bufnr = parent_buf, winnr = parent_win, params = params,
    results = results, method = method, offset_encoding = enc,
  })

  local aug = vim.api.nvim_create_augroup('Peekr', { clear = true })

  Peekr._cleanup = vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = aug,
    callback = function()
      local w = vim.api.nvim_get_current_win()
      local b = vim.api.nvim_get_current_buf()
      local in_preview = w == peekr.preview.winnr
      local in_list = w == peekr.list.winnr and b == peekr.list.bufnr
      if not in_preview and not in_list then
        pcall(vim.api.nvim_del_autocmd, Peekr._cleanup)
        Peekr._cleanup = 0
        Peekr.actions.close()
      end
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = aug, buffer = peekr.list.bufnr,
    callback = function() peekr:update_preview(peekr.list:get_current_item()) end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = aug,
    pattern = { tostring(peekr.list.winnr), tostring(peekr.preview.winnr), tostring(parent_win) },
    callback = function() Peekr.actions.close() end,
  })

  local debounced_resize = utils.debounce(function()
    if is_open() then peekr:on_resize() end
  end, 50)

  vim.api.nvim_create_autocmd('VimResized', {
    group = aug,
    callback = debounced_resize,
  })
end

local function open(opts)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  lsp.request(opts.method, buf, function(results, ctx)
    if vim.tbl_isempty(results) then
      return utils.info(('No %s found'):format(lsp.methods[opts.method].label))
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)

    if is_open() then
      peekr.list:setup({
        results = results, position_params = ctx.params,
        method = opts.method, offset_encoding = client.offset_encoding,
      })
      peekr.preview:clear_hl()
      peekr:update_preview(peekr.list:get_current_item())
      vim.api.nvim_set_current_win(peekr.list.winnr)
    else
      local function _open(r)
        create(r or results, buf, win, ctx.params, opts.method, client.offset_encoding)
      end
      local function _jump(r)
        r = r or results[1]
        vim.lsp.util.show_document(r, client.offset_encoding, { focus = true })
      end

      local hooks = opts.hooks or config.options.hooks
      if hooks and type(hooks.before_open) == 'function' then
        hooks.before_open(results, _open, _jump, opts.method)
      else
        _open()
      end
    end
  end)
end

-- Actions -----------------------------------------------------------------

Peekr.actions = {
  close = function()
    if not vim.tbl_isempty(peekr) then
      peekr:close()
      peekr:destroy()
    end
  end,
  enter_win = function(win)
    return function()
      if not is_open() then return end
      if win == 'preview' then vim.api.nvim_set_current_win(peekr.preview.winnr)
      elseif win == 'list' then vim.api.nvim_set_current_win(peekr.list.winnr) end
    end
  end,
  next = function()
    peekr:update_preview(peekr.list:next())
  end,
  previous = function()
    peekr:update_preview(peekr.list:previous())
  end,
  next_location = function()
    peekr:update_preview(peekr.list:next({ skip_groups = true, cycle = true }))
  end,
  previous_location = function()
    peekr:update_preview(peekr.list:previous({ skip_groups = true, cycle = true }))
  end,
  preview_scroll_win = function(dist)
    return function()
      local cmd = dist > 0 and [[\<C-y>]] or [[\<C-e>]]
      vim.api.nvim_win_call(peekr.preview.winnr, function()
        vim.cmd(('exec "norm! %d%s"'):format(math.abs(dist), cmd))
      end)
    end
  end,
  jump = function(opts) peekr:jump(opts) end,
  jump_vsplit = function() peekr:jump({ cmd = 'vsplit' }) end,
  jump_split = function() peekr:jump({ cmd = 'split' }) end,
  jump_tab = function() peekr:jump({ cmd = 'tabe' }) end,
  open = function(method, opts)
    Peekr.setup()
    open({ method = method, hooks = opts and opts.hooks })
  end,
  quickfix = function()
    local items = {}
    for _, group in pairs(peekr.list.groups) do
      for _, item in ipairs(group.items) do
        table.insert(items, {
          bufnr = item.bufnr, filename = item.filename,
          lnum = item.start_line + 1, end_lnum = item.end_line + 1,
          col = item.start_col + 1, end_col = item.end_col + 1,
          text = item.full_text,
        })
      end
    end
    vim.fn.setqflist({}, ' ', { items = items, nr = '$', title = 'Peekr' })
    Peekr.actions.close()
    if config.options.use_trouble_qf and pcall(require, 'trouble') then
      require('trouble').open('quickfix')
    else
      vim.cmd.copen()
    end
  end,
  toggle_fold = function() peekr:toggle_fold() end,
  open_fold = function() peekr:toggle_fold(true) end,
  close_fold = function() peekr:toggle_fold(false) end,
  resume = function()
    if not last_session then return utils.info('No previous Peekr session') end
    local w = vim.api.nvim_get_current_win()
    local b = vim.api.nvim_get_current_buf()
    create(last_session.results, b, w,
      vim.lsp.util.make_position_params(w, last_session.offset_encoding),
      last_session.method, last_session.offset_encoding)
  end,
}

-- Peekr instance methods --------------------------------------------------

function Peekr:create(opts)
  local push = utils.create_push_tagstack(opts.winnr)
  local layout = get_layout()

  -- Create the backdrop window (provides the outer rounded border)
  local backdrop_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[backdrop_buf].bufhidden = 'wipe'
  local title = lsp.methods[opts.method]
    and ('  ' .. utils.capitalize(lsp.methods[opts.method].label) .. ' ')
    or ('  ' .. opts.method .. ' ')
  local backdrop_win_opts = vim.tbl_extend('force', layout.backdrop, {
    title = title,
    title_pos = 'center',
  })
  local backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, backdrop_win_opts)
  vim.wo[backdrop_win].winhighlight = 'Normal:PeekrListNormal,FloatBorder:PeekrBorder,FloatTitle:PeekrTitle'
  vim.wo[backdrop_win].winblend = 0

  -- Create list
  local list = require('peekr.list').create({
    results = opts.results, parent_winnr = opts.winnr,
    position_params = opts.params, method = opts.method,
    win_opts = layout.list, offset_encoding = opts.offset_encoding,
  })

  -- Create separator buffer (single column of │)
  local sep_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[sep_buf].bufhidden = 'wipe'
  local sep_lines = {}
  for i = 1, layout.total_h do sep_lines[i] = '│' end
  vim.api.nvim_buf_set_lines(sep_buf, 0, -1, false, sep_lines)

  local sep_col = config.options.list.position == 'left'
    and (layout.col + layout.list.width)
    or (layout.col + layout.preview.width)
  local sep_win = vim.api.nvim_open_win(sep_buf, false, {
    relative = 'editor',
    width = 1,
    height = layout.total_h,
    row = layout.row,
    col = sep_col,
    zindex = config.options.zindex,
    style = 'minimal',
    border = 'none',
  })
  vim.wo[sep_win].winhighlight = 'Normal:PeekrSeparator,NormalFloat:PeekrSeparator'
  vim.wo[sep_win].winblend = 0

  -- Create preview
  local first_item = list:get_current_item()
  local preview = require('peekr.preview').create({
    parent_winnr = opts.winnr, parent_bufnr = opts.bufnr,
    win_opts = layout.preview, preview_bufnr = first_item.bufnr,
  })

  last_session = {
    results = opts.results, position_params = opts.params,
    method = opts.method, offset_encoding = opts.offset_encoding,
  }

  local scope = {
    list = list, preview = preview, push_tagstack = push,
    parent_winnr = opts.winnr, parent_bufnr = opts.bufnr,
    backdrop_win = backdrop_win, backdrop_buf = backdrop_buf,
    sep_win = sep_win, sep_buf = sep_buf,
  }
  return setmetatable(scope, self)
end

function Peekr:on_resize()
  local layout = get_layout()
  pcall(vim.api.nvim_win_set_config, self.list.winnr, layout.list)
  pcall(vim.api.nvim_win_set_config, self.preview.winnr, layout.preview)
  pcall(vim.api.nvim_win_set_config, self.backdrop_win, layout.backdrop)

  local sep_col = config.options.list.position == 'left'
    and (layout.col + layout.list.width)
    or (layout.col + layout.preview.width)
  pcall(vim.api.nvim_win_set_config, self.sep_win, {
    relative = 'editor', width = 1, height = layout.total_h,
    row = layout.row, col = sep_col,
  })
end

function Peekr:jump(opts)
  opts = opts or {}
  local item = self.list:get_current_item()
  if not item or item.is_unreachable then return end
  if item.is_group then return self.list:toggle_fold(item) end

  self:close()
  self.push_tagstack()

  if opts.cmd then
    if type(opts.cmd) == 'function' then opts.cmd(item) else vim.cmd(opts.cmd) end
  end

  if vim.fn.buflisted(item.bufnr) == 1 then
    vim.cmd(('buffer %s'):format(item.bufnr))
  else
    vim.cmd(('edit %s'):format(vim.fn.fnameescape(item.filename)))
  end
  vim.api.nvim_win_set_cursor(0, { item.start_line + 1, item.start_col })
  vim.cmd('norm! zz')
  self:destroy()
end

function Peekr:toggle_fold(expand)
  local item = self.list:get_current_item()
  if not item or self.list:is_flat() then return end
  if expand == nil then return self.list:toggle_fold(item)
  elseif expand then return self.list:open_fold(item)
  else return self.list:close_fold(item) end
end

function Peekr:update_preview(item)
  if item and not item.is_group then
    self.preview:update(item, self.list:get_active_group({ location = item }))
  end
end

function Peekr:close()
  local hooks = config.options.hooks or {}
  if type(hooks.before_close) == 'function' then hooks.before_close() end

  if Peekr._cleanup and Peekr._cleanup > 0 then
    pcall(vim.api.nvim_del_autocmd, Peekr._cleanup)
  end

  if vim.api.nvim_win_is_valid(self.parent_winnr) then
    vim.api.nvim_set_current_win(self.parent_winnr)
  end

  pcall(vim.api.nvim_del_augroup_by_name, 'Peekr')
  self.list:close()
  self.preview:close()

  -- Close backdrop and separator
  pcall(function()
    if vim.api.nvim_win_is_valid(self.sep_win) then vim.api.nvim_win_close(self.sep_win, true) end
  end)
  pcall(function()
    if vim.api.nvim_win_is_valid(self.backdrop_win) then vim.api.nvim_win_close(self.backdrop_win, true) end
  end)

  if type(hooks.after_close) == 'function' then vim.schedule(hooks.after_close) end
end

function Peekr:destroy()
  self.list:destroy()
  self.preview:destroy()
  peekr = {}
end

-- Public API

Peekr.register_method = function(method)
  vim.validate({
    name = { method.name, 'string' },
    label = { method.label, 'string' },
    method = { method.method, 'string' },
  })
  if lsp.methods[method.name] then
    return utils.error(("Method '%s' already registered"):format(method.name))
  end
  lsp.methods[method.name] = {
    label = method.label, lsp_method = method.method,
    non_standard = true, transform = method.transform,
  }
end

Peekr.open = Peekr.actions.open
Peekr.is_open = is_open

return Peekr
