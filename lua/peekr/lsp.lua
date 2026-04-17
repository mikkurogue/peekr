--- Peekr LSP layer — supports ALL standard LSP location methods plus custom ones.
local utils = require('peekr.utils')
local M = {}

--- Built-in LSP methods that return locations.
--- Users can register more via Peekr.register_method().
M.methods = {
  definitions = {
    label = 'definitions',
    lsp_method = 'textDocument/definition',
  },
  type_definitions = {
    label = 'type definitions',
    lsp_method = 'textDocument/typeDefinition',
  },
  references = {
    label = 'references',
    lsp_method = 'textDocument/references',
    extra_params = { context = { includeDeclaration = true } },
  },
  implementations = {
    label = 'implementations',
    lsp_method = 'textDocument/implementation',
  },
  declaration = {
    label = 'declaration',
    lsp_method = 'textDocument/declaration',
  },
  incoming_calls = {
    label = 'incoming calls',
    lsp_method = 'callHierarchy/incomingCalls',
    prepare = 'textDocument/prepareCallHierarchy',
    transform = function(results)
      local locs = {}
      for _, item in ipairs(results) do
        local from = item.from or item
        table.insert(locs, {
          uri = from.uri,
          range = from.selectionRange or from.range,
        })
      end
      return locs
    end,
  },
  outgoing_calls = {
    label = 'outgoing calls',
    lsp_method = 'callHierarchy/outgoingCalls',
    prepare = 'textDocument/prepareCallHierarchy',
    transform = function(results)
      local locs = {}
      for _, item in ipairs(results) do
        local to = item.to or item
        table.insert(locs, {
          uri = to.uri,
          range = to.selectionRange or to.range,
        })
      end
      return locs
    end,
  },
  document_symbols = {
    label = 'document symbols',
    lsp_method = 'textDocument/documentSymbol',
    transform = function(results)
      local locs = {}
      local function flatten(symbols, uri)
        for _, sym in ipairs(symbols) do
          table.insert(locs, {
            uri = uri,
            range = sym.selectionRange or sym.range or sym.location.range,
          })
          if sym.children then
            flatten(sym.children, uri)
          end
        end
      end
      -- documentSymbol results don't carry a URI, we inject the current buffer URI
      local uri = vim.uri_from_bufnr(0)
      flatten(results, uri)
      return locs
    end,
    params_fn = function()
      return { textDocument = vim.lsp.util.make_text_document_params() }
    end,
  },
  workspace_symbols = {
    label = 'workspace symbols',
    lsp_method = 'workspace/symbol',
    transform = function(results)
      local locs = {}
      for _, sym in ipairs(results) do
        local loc = sym.location
        if loc then
          table.insert(locs, { uri = loc.uri, range = loc.range })
        end
      end
      return locs
    end,
    params_fn = function()
      local word = vim.fn.expand('<cword>')
      return { query = word }
    end,
  },
}

--- Create a handler function for a given method definition
local function create_handler(method)
  return function(bufnr, params, cb)
    local lsp_method = method.lsp_method
    local prepare = method.prepare

    local function handle_results(results, ctx)
      if method.transform then
        results = method.transform(results)
      end
      cb(results, ctx)
    end

    -- Some methods (callHierarchy) need a prepare step first
    if prepare then
      vim.lsp.buf_request_all(bufnr, prepare, params, function(responses)
        for client_id, resp in pairs(responses) do
          if resp.result and not vim.tbl_isempty(resp.result) then
            local item = vim.islist(resp.result) and resp.result[1] or resp.result
            vim.lsp.buf_request_all(bufnr, lsp_method, { item = item }, function(call_responses)
              for cid, cresp in pairs(call_responses) do
                if cresp.result and not vim.tbl_isempty(cresp.result) then
                  handle_results(cresp.result, { client_id = cid, params = params })
                  return
                end
              end
              cb({})
            end)
            return
          end
        end
        cb({})
      end)
      return
    end

    -- Standard single-step request
    local _ids, cancel
    _ids, cancel = vim.lsp.buf_request(bufnr, lsp_method, params, function(err, result, ctx)
      if err and not method.non_standard then
        utils.error(('Error requesting %s: %s'):format(method.label, err.message))
      end
      if not result or vim.tbl_isempty(result) then
        -- No result from this client; wait for others (handled by buf_request callback semantics)
        cb({})
        return
      end
      if cancel then cancel() end
      result = vim.islist(result) and result or { result }
      handle_results(result, ctx)
    end)
  end
end

function M.setup()
  for key, method in pairs(M.methods) do
    M.methods[key].handler = create_handler(method)
  end
end

--- Build position params, compatible with Neovim 0.11+/0.12
local function make_position_params(extra)
  local win = vim.api.nvim_get_current_win()
  -- Neovim 0.11+ make_position_params can accept a function for per-client params
  return function(client)
    local ret = vim.lsp.util.make_position_params(win, client.offset_encoding)
    return vim.tbl_extend('force', ret, extra or {})
  end
end

--- Check if any attached client supports the given LSP method
local function has_capability(bufnr, lsp_method)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client:supports_method(lsp_method, bufnr) then
      return true
    end
  end
  return false
end

function M.request(name, bufnr, cb)
  local method = M.methods[name]
  if not method then
    return utils.error(("Unknown Peekr method '%s'"):format(name))
  end

  -- Check capability before firing the request
  local check_method = method.prepare or method.lsp_method
  if not method.non_standard and not has_capability(bufnr, check_method) then
    return utils.warn(("No LSP server supports '%s' for this buffer"):format(method.label))
  end

  local params
  if method.params_fn then
    params = method.params_fn()
  else
    params = make_position_params(method.extra_params)
  end

  method.handler(bufnr, params, cb)
end

return M
