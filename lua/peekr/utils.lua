local M = {}

function M.create_push_tagstack(winnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  local word = vim.fn.expand('<cword>')
  local from = { vim.api.nvim_get_current_buf(), pos[1], pos[2], 0 }
  local items = { { tagname = word, from = from } }
  return function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_call(winnr, function()
        vim.cmd("norm! m'")
        vim.fn.settagstack(winnr, { items = items }, 't')
      end)
    end
  end
end

function M.is_float(winnr)
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end
  return vim.api.nvim_win_get_config(winnr).relative ~= ''
end

function M.round(n)
  return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
end

function M.capitalize(s)
  return (s:gsub('^%l', string.upper))
end

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'Peekr' })
end

function M.warn(msg) M.notify(msg, vim.log.levels.WARN) end
function M.error(msg) M.notify(msg, vim.log.levels.ERROR) end
function M.info(msg) M.notify(msg, vim.log.levels.INFO) end

function M.debounce(fn, ms)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then timer:stop() end
    timer = vim.defer_fn(function()
      fn(unpack(args))
      timer = nil
    end, ms)
  end
end

function M.throttle(fn, ms)
  local timer = vim.uv.new_timer()
  local running = false
  local function wrapped(...)
    if not running then
      timer:start(ms, 0, function() running = false end)
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end
  return wrapped, timer
end

function M.tbl_find(t, pred)
  for i, v in ipairs(t) do
    if pred(v, i) then return v, i end
  end
  return nil
end

function M.get_line_byte_from_position(line, position, offset_encoding)
  local col = position.character
  if col > 0 then
    local ok, result = pcall(vim.str_byteindex, line, offset_encoding, col)
    if ok then return result end
    ok, result = pcall(vim.str_byteindex, line, col, offset_encoding == 'utf-16')
    if ok then return result end
    return math.min(#line, col)
  end
  return col
end

function M.get_word_until_position(pos, text)
  pos = math.max(0, pos)
  local str = string.sub(text, 0, pos)
  if #str == 0 then
    return { match = '', start_col = 0, end_col = pos }
  end
  local match, index = nil, 0
  local re = vim.regex([[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]])
  while true do
    local s, e = re:match_str(str)
    if not s then break end
    match = string.sub(str, s + 1, e)
    index = index + e
    str = string.sub(str, e + 1)
  end
  if match then
    return { match = match, start_col = index - #match, end_col = index }
  end
  return { match = '', start_col = pos, end_col = pos }
end

function M.get_value_in_range(start_col, end_col, text)
  if start_col == end_col then return '' end
  return string.sub(text, start_col + 1, end_col)
end

--- Read lines from a buffer or file on disk
---@param bufnr integer
---@param uri string
---@param rows integer[]
---@return table<integer, string>|nil
function M.get_lines(bufnr, uri, rows)
  rows = type(rows) == 'table' and rows or { rows }
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  local function buf_lines()
    local lines = {}
    for _, row in pairs(rows) do
      lines[row] = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { '' })[1]
    end
    return lines
  end

  if uri:sub(1, 4) ~= 'file' then
    vim.fn.bufload(bufnr)
    return buf_lines()
  end

  if vim.fn.bufloaded(bufnr) == 1 then
    return buf_lines()
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local fd = vim.uv.fs_open(filename, 'r', 438)
  if not fd then return nil end
  local stat = vim.uv.fs_fstat(fd)
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  local lines = {}
  local rows_needed = 0
  for _, row in pairs(rows) do
    if not lines[row] then rows_needed = rows_needed + 1 end
    lines[row] = true
  end

  local found, lnum = 0, 0
  for line in string.gmatch(data, '([^\n]*)\n?') do
    if lines[lnum] == true then
      lines[lnum] = line
      found = found + 1
      if found == rows_needed then break end
    end
    lnum = lnum + 1
  end

  for i, v in pairs(lines) do
    if v == true then lines[i] = '' end
  end
  return lines
end

return M
