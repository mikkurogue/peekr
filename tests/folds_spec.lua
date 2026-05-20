-- Tests for peekr.folds
-- We need to stub the config module before requiring folds
package.loaded['peekr.config'] = {
  options = {
    folds = {
      folded = true,
    },
  },
}

local folds = require('peekr.folds')

describe('folds', function()
  before_each(function()
    folds.reset()
  end)

  describe('with folded = true (default)', function()
    before_each(function()
      package.loaded['peekr.config'].options.folds.folded = true
    end)

    it('returns true by default for unknown files', function()
      assert.is_true(folds.is_folded('foo.lua'))
    end)

    it('returns false after opening', function()
      folds.open('foo.lua')
      assert.is_false(folds.is_folded('foo.lua'))
    end)

    it('returns true after closing', function()
      folds.open('foo.lua')
      folds.close('foo.lua')
      assert.is_true(folds.is_folded('foo.lua'))
    end)

    it('toggles correctly', function()
      assert.is_true(folds.is_folded('foo.lua'))
      folds.toggle('foo.lua')
      assert.is_false(folds.is_folded('foo.lua'))
      folds.toggle('foo.lua')
      assert.is_true(folds.is_folded('foo.lua'))
    end)
  end)

  describe('with folded = false', function()
    before_each(function()
      package.loaded['peekr.config'].options.folds.folded = false
    end)

    it('returns false by default for unknown files', function()
      assert.is_false(folds.is_folded('bar.lua'))
    end)

    it('returns true after closing', function()
      folds.close('bar.lua')
      assert.is_true(folds.is_folded('bar.lua'))
    end)
  end)

  describe('reset', function()
    it('clears all fold state', function()
      folds.open('a.lua')
      folds.close('b.lua')
      folds.reset()
      -- After reset with folded=false, everything should be unfolded
      package.loaded['peekr.config'].options.folds.folded = false
      assert.is_false(folds.is_folded('a.lua'))
      assert.is_false(folds.is_folded('b.lua'))
    end)
  end)
end)
