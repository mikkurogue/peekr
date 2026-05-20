-- Tests for LSP method transform functions
local lsp = require('peekr.lsp')

describe('lsp transforms', function()
  describe('incoming_calls transform', function()
    local transform = lsp.methods.incoming_calls.transform

    it('extracts uri and range from incoming call items', function()
      local results = {
        {
          from = {
            uri = 'file:///foo.lua',
            selectionRange = { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 5 } },
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 10, character = 0 } },
          },
        },
      }
      local locs = transform(results)
      assert.are.equal(1, #locs)
      assert.are.equal('file:///foo.lua', locs[1].uri)
      -- Should prefer selectionRange
      assert.are.equal(1, locs[1].range.start.line)
    end)

    it('falls back to range when selectionRange is missing', function()
      local results = {
        {
          from = {
            uri = 'file:///bar.lua',
            range = { start = { line = 5, character = 0 }, ['end'] = { line = 5, character = 10 } },
          },
        },
      }
      local locs = transform(results)
      assert.are.equal(5, locs[1].range.start.line)
    end)

    it('handles empty results', function()
      local locs = transform({})
      assert.are.equal(0, #locs)
    end)
  end)

  describe('outgoing_calls transform', function()
    local transform = lsp.methods.outgoing_calls.transform

    it('extracts uri and range from outgoing call items', function()
      local results = {
        {
          to = {
            uri = 'file:///target.lua',
            selectionRange = { start = { line = 3, character = 2 }, ['end'] = { line = 3, character = 8 } },
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 20, character = 0 } },
          },
        },
      }
      local locs = transform(results)
      assert.are.equal(1, #locs)
      assert.are.equal('file:///target.lua', locs[1].uri)
      assert.are.equal(3, locs[1].range.start.line)
    end)
  end)

  describe('workspace_symbols transform', function()
    local transform = lsp.methods.workspace_symbols.transform

    it('extracts location from symbols', function()
      local results = {
        {
          name = 'MyClass',
          location = {
            uri = 'file:///class.lua',
            range = { start = { line = 10, character = 0 }, ['end'] = { line = 10, character = 7 } },
          },
        },
        {
          name = 'orphan_sym',
          -- no location field
        },
      }
      local locs = transform(results)
      assert.are.equal(1, #locs)
      assert.are.equal('file:///class.lua', locs[1].uri)
    end)
  end)

  describe('method registration', function()
    it('has all built-in methods', function()
      local expected = {
        'definitions',
        'type_definitions',
        'references',
        'implementations',
        'declaration',
        'incoming_calls',
        'outgoing_calls',
        'document_symbols',
        'workspace_symbols',
      }
      for _, name in ipairs(expected) do
        assert.is_not_nil(lsp.methods[name], 'missing method: ' .. name)
        assert.is_not_nil(lsp.methods[name].lsp_method, 'missing lsp_method for: ' .. name)
        assert.is_not_nil(lsp.methods[name].label, 'missing label for: ' .. name)
      end
    end)
  end)
end)
