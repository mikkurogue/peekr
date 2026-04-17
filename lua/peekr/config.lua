local M = {}
M.options = {}

M.namespace = vim.api.nvim_create_namespace('Peekr')
M.hl_ns = 'Peekr'

---@param user_config table|nil
---@param actions table
function M.setup(user_config, actions)
  local defaults = {
    height = 20,
    width = 0.75,       -- fraction of editor width
    zindex = 50,
    border = 'rounded', -- any nvim border spec: 'rounded', 'single', 'double', 'solid', etc.
    preview_win_opts = {
      cursorline = true,
      number = true,
      wrap = true,
    },
    list = {
      position = 'left',
      width = 0.30,     -- fraction of the float width
    },
    treesitter = {
      enable = true,
    },
    mappings = {
      list = {
        ['j'] = actions.next,
        ['k'] = actions.previous,
        ['<Down>'] = actions.next,
        ['<Up>'] = actions.previous,
        ['<Tab>'] = actions.next_location,
        ['<S-Tab>'] = actions.previous_location,
        ['<C-u>'] = actions.preview_scroll_win(5),
        ['<C-d>'] = actions.preview_scroll_win(-5),
        ['v'] = actions.jump_vsplit,
        ['s'] = actions.jump_split,
        ['t'] = actions.jump_tab,
        ['<CR>'] = actions.jump,
        ['l'] = actions.open_fold,
        ['h'] = actions.close_fold,
        ['o'] = actions.jump,
        ['<leader>l'] = actions.enter_win('preview'),
        ['q'] = actions.close,
        ['Q'] = actions.close,
        ['<Esc>'] = actions.close,
        ['<C-q>'] = actions.quickfix,
      },
      preview = {
        ['Q'] = actions.close,
        ['<Tab>'] = actions.next_location,
        ['<S-Tab>'] = actions.previous_location,
        ['<leader>l'] = actions.enter_win('list'),
        ['q'] = actions.close,
        ['<Esc>'] = actions.close,
      },
    },
    hooks = {},
    folds = {
      fold_closed = '',
      fold_open = '',
      folded = true,
    },
    indent_lines = {
      enable = true,
      icon = '│',
    },
    winbar = {
      enable = true,
    },
    use_trouble_qf = false,
  }

  M.options = vim.tbl_deep_extend('force', {}, defaults, user_config or {})

  -- Filter disabled mappings
  for _, mappings in pairs(M.options.mappings) do
    for key, action in pairs(mappings) do
      if type(key) == 'string' and action == false then
        mappings[key] = nil
      end
    end
  end
end

return M
