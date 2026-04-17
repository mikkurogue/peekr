local Color = {}
Color.__index = Color

function Color.hex2rgb(hex)
  hex = hex:gsub('#', '')
  return tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16)
end

function Color.rgb2hex(r, g, b)
  local utils = require('peekr.utils')
  r = math.min(math.max(0, utils.round(r)), 255)
  g = math.min(math.max(0, utils.round(g)), 255)
  b = math.min(math.max(0, utils.round(b)), 255)
  return '#' .. ('%02X%02X%02X'):format(r, g, b)
end

function Color.hex2luminance(hex)
  if not hex or hex == 'NONE' then return 0 end
  local r, g, b = Color.hex2rgb(hex)
  local function lx(x)
    x = x / 255
    return x <= 0.03928 and x / 12.92 or math.pow((x + 0.055) / 1.055, 2.4)
  end
  return 0.2126 * lx(r) + 0.7152 * lx(g) + 0.0722 * lx(b)
end

-- LAB color space for perceptual brightness adjustments
local LAB = {
  Kn = 18, Xn = 0.950470, Yn = 1, Zn = 1.088830,
  t0 = 0.137931034, t1 = 0.206896552, t2 = 0.12841855, t3 = 0.008856452,
}

local function is_nan(v) return type(v) == 'number' and v ~= v end
local function xyz_rgb(r)
  return 255 * (r <= 0.00304 and 12.92 * r or 1.055 * math.pow(r, 1 / 2.4) - 0.055)
end
local function lab_xyz(t) return t > LAB.t1 and t * t * t or LAB.t2 * (t - LAB.t0) end
local function rgb_xyz(r) r = r / 255; return r <= 0.04045 and r / 12.92 or math.pow((r + 0.055) / 1.055, 2.4) end
local function xyz_lab(t) return t > LAB.t3 and math.pow(t, 1 / 3) or t / LAB.t2 + LAB.t0 end

local function lab2rgb(l, a, b)
  local y = (l + 16) / 116
  local x = is_nan(a) and y or y + a / 500
  local z = is_nan(b) and y or y - b / 200
  y = LAB.Yn * lab_xyz(y)
  x = LAB.Xn * lab_xyz(x)
  z = LAB.Zn * lab_xyz(z)
  return xyz_rgb(3.2404542 * x - 1.5371385 * y - 0.4985314 * z),
    xyz_rgb(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z),
    xyz_rgb(0.0556434 * x - 0.2040259 * y + 1.0572252 * z)
end

local function rgb2lab(r, g, b)
  r, g, b = rgb_xyz(r), rgb_xyz(g), rgb_xyz(b)
  local x = xyz_lab((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / LAB.Xn)
  local y = xyz_lab((0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / LAB.Yn)
  local z = xyz_lab((0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / LAB.Zn)
  local l = 116 * y - 16
  return math.max(0, l), 500 * (x - y), 200 * (y - z)
end

function Color:modify(amount)
  return amount > 0 and self:brighten(amount) or self:darken(math.abs(amount))
end

function Color:darken(amount)
  local l = self.lab[1] - (LAB.Kn * amount)
  local r, g, b = lab2rgb(l, self.lab[2], self.lab[3])
  return Color.rgb2hex(r, g, b)
end

function Color:brighten(amount) return self:darken(-amount) end

function Color.new(hex)
  if not hex or hex == 'NONE' then return nil end
  local r, g, b = Color.hex2rgb(hex)
  local self = setmetatable({}, Color)
  self[1], self[2], self[3] = r, g, b
  self.lab = { rgb2lab(r, g, b) }
  self.hex = hex
  return self
end

return Color
