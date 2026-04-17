local Range = {}
Range.__index = Range

function Range:new(sl, sc, el, ec)
  local s = {}
  if sl > el or (sl == el and sc > ec) then
    s.start_line, s.start_col, s.end_line, s.end_col = el, ec, sl, sc
  else
    s.start_line, s.start_col, s.end_line, s.end_col = sl, sc, el, ec
  end
  return setmetatable(s, self)
end

function Range:contains(pos)
  if pos.line < self.start_line or pos.line > self.end_line then return false end
  if pos.line == self.start_line and pos.col < self.start_col then return false end
  if pos.line == self.end_line and pos.col > self.end_col then return false end
  return true
end

return Range
