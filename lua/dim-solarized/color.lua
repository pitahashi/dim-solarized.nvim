local M = {}

local WHITE = { x = 0.95047, z = 1.08883 }

---@param t number
---@return number
local function lab_f(t)
	if t > (6 / 29) ^ 3 then
		return t ^ (1 / 3)
	end
	return t / (3 * (6 / 29) ^ 2) + 4 / 29
end

---@param t number
---@return number
local function lab_f_inv(t)
	if t > 6 / 29 then
		return t ^ 3
	end
	return 3 * (6 / 29) ^ 2 * (t - 4 / 29)
end

--- Convert a linear sRGB value to a gamma-encoded one.
---@param c number
---@return number
local function gamma(c)
	if c <= 0.0031308 then
		return 12.92 * c
	end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

--- Convert a gamma-encoded sRGB value to a linear one.
---@param v number
---@return number
local function linear(v)
	if v <= 0.04045 then
		return v / 12.92
	end
	return ((v + 0.055) / 1.055) ^ 2.4
end

--- Linear sRGB channels (0-1) of a #rrggbb color.
---@param hex string
---@return number r, number g, number b
function M.linear_rgb(hex)
	local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
	return linear(tonumber(r, 16) / 255), linear(tonumber(g, 16) / 255), linear(tonumber(b, 16) / 255)
end

--- Convert CIE LCh(ab) (D65) to sRGB #rrggbb.
--- Out-of-gamut colors are clamped to 0-1 per channel.
---@param L number Lightness L* (0-100)
---@param C number Chroma C*
---@param h number Hue angle (degrees)
---@return string
function M.lch(L, C, h)
	local a = C * math.cos(math.rad(h))
	local b = C * math.sin(math.rad(h))
	local fy = (L + 16) / 116
	local X = WHITE.x * lab_f_inv(fy + a / 500)
	local Y = lab_f_inv(fy)
	local Z = WHITE.z * lab_f_inv(fy - b / 200)
	local r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
	local g = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
	local bl = 0.0557 * X - 0.2040 * Y + 1.0570 * Z
	local function byte(v)
		return math.floor(gamma(math.min(1, math.max(0, v))) * 255 + 0.5)
	end
	return string.format("#%02x%02x%02x", byte(r), byte(g), byte(bl))
end

--- Convert sRGB #rrggbb to CIE LCh(ab) (D65). Inverse of `lch`.
---@param hex string
---@return number L, number C, number h
function M.to_lch(hex)
	local r, g, b = M.linear_rgb(hex)
	local X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / WHITE.x
	local Y = 0.2126 * r + 0.7152 * g + 0.0722 * b
	local Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / WHITE.z
	local fx, fy, fz = lab_f(X), lab_f(Y), lab_f(Z)
	local a, bb = 500 * (fx - fy), 200 * (fy - fz)
	local h = math.deg(math.atan(bb / a))
	if a < 0 then
		h = h + 180
	end
	return 116 * fy - 16, math.sqrt(a * a + bb * bb), h % 360
end

--- Relative luminance as defined by WCAG 2.x.
---@param hex string
---@return number
function M.luminance(hex)
	local r, g, b = M.linear_rgb(hex)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

--- WCAG contrast ratio between two colors.
---@param a string
---@param b string
---@return number
function M.contrast(a, b)
	local la, lb = M.luminance(a), M.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

return M
