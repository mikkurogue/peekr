vim.api.nvim_create_user_command('Peekr', function(ev)
  if ev.args == 'resume' then
    require('peekr').actions.resume()
  else
    require('peekr').open(ev.args)
  end
end, {
  nargs = 1,
  complete = function(arg)
    local list = vim.tbl_keys(require('peekr.lsp').methods)
    table.insert(list, 'resume')
    return vim.tbl_filter(function(s) return s:match('^' .. arg) end, list)
  end,
})
