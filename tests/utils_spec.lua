-- Tests for peekr.utils (pure functions only)
local utils = require('peekr.utils')

describe('utils', function()
  describe('round', function()
    it('rounds 0.5 up', function()
      assert.are.equal(1, utils.round(0.5))
    end)

    it('rounds 0.4 down', function()
      assert.are.equal(0, utils.round(0.4))
    end)

    it('rounds negative numbers correctly', function()
      assert.are.equal(-1, utils.round(-0.5))
      assert.are.equal(-2, utils.round(-1.5))
    end)

    it('handles integers', function()
      assert.are.equal(3, utils.round(3))
    end)
  end)

  describe('capitalize', function()
    it('capitalises first letter', function()
      assert.are.equal('Hello', utils.capitalize('hello'))
    end)

    it('leaves already capitalised strings unchanged', function()
      assert.are.equal('World', utils.capitalize('World'))
    end)

    it('handles single character', function()
      assert.are.equal('A', utils.capitalize('a'))
    end)

    it('handles empty string', function()
      assert.are.equal('', utils.capitalize(''))
    end)
  end)

  describe('tbl_find', function()
    it('finds matching element', function()
      local t = { 10, 20, 30 }
      local val, idx = utils.tbl_find(t, function(v)
        return v == 20
      end)
      assert.are.equal(20, val)
      assert.are.equal(2, idx)
    end)

    it('returns nil when no match', function()
      local val = utils.tbl_find({ 1, 2, 3 }, function(v)
        return v == 99
      end)
      assert.is_nil(val)
    end)

    it('handles empty table', function()
      local val = utils.tbl_find({}, function()
        return true
      end)
      assert.is_nil(val)
    end)
  end)

  describe('get_value_in_range', function()
    it('extracts substring from text', function()
      assert.are.equal('llo', utils.get_value_in_range(2, 5, 'hello world'))
    end)

    it('returns empty string when start equals end', function()
      assert.are.equal('', utils.get_value_in_range(3, 3, 'hello'))
    end)
  end)

  describe('get_word_until_position', function()
    it('extracts word at position', function()
      local result = utils.get_word_until_position(5, 'hello world')
      assert.are.equal('hello', result.match)
    end)

    it('returns empty match for empty text', function()
      local result = utils.get_word_until_position(0, '')
      assert.are.equal('', result.match)
    end)

    it('handles position at 0', function()
      local result = utils.get_word_until_position(0, 'hello')
      assert.are.equal('', result.match)
    end)
  end)
end)
