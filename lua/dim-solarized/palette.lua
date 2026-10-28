---@class DimSolarizedPalette
---@field bg string Normal background
---@field bg_alt string Background for the cursor line, statusline, etc.
---@field bg_sel string Background of selections
---@field bg_float string Background of floating windows
---@field fg string Normal foreground
---@field fg_dim string Secondary foreground
---@field fg_bright string Emphasized foreground
---@field comment string Comments
---@field border string Borders
---@field yellow string
---@field orange string
---@field red string
---@field magenta string
---@field violet string
---@field blue string
---@field cyan string
---@field green string
---@field diff_add string
---@field diff_change string
---@field diff_delete string
---@field diff_text string

local M = {}

--- Inverse of the CIELAB helper function f(t), used when converting Lab back to XYZ.
---@param t number
---@return number
local function lab_f_inv(t)
	-- Use the cubic branch above 6/29 and the linear branch below it
	if t > 6 / 29 then
		return t ^ 3
	end
	return 3 * (6 / 29) ^ 2 * (t - 4 / 29)
end

--- Convert linear sRGB to a gamma-encoded sRGB value.
---@param c number Linear value
---@return number
local function gamma(c)
	-- sRGB transfer function: linear near black, a 1/2.4 power curve everywhere else
	if c <= 0.0031308 then
		return 12.92 * c
	end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

--- Convert CIE LCh(ab) (D65) to sRGB #rrggbb.
--- Out-of-gamut colors are clamped to 0-1 per channel.
---@param L number Lightness L* (0-100)
---@param C number Chroma C*
---@param h number Hue angle (degrees)
---@return string
local function lch(L, C, h)
	-- Convert polar (C, h) to Cartesian coordinates on the a*b* plane
	local a = C * math.cos(math.rad(h))
	local b = C * math.sin(math.rad(h))
	-- Compute the intermediate values fx, fy, fz from L*a*b*
	local fy = (L + 16) / 116
	local fx = fy + a / 500
	local fz = fy - b / 200
	-- Scale by the D65 white point (0.95047, 1.0, 1.08883) to get XYZ
	local X = 0.95047 * lab_f_inv(fx)
	local Y = lab_f_inv(fy)
	local Z = 1.08883 * lab_f_inv(fz)
	-- Convert XYZ to linear sRGB
	local r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
	local g = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
	local bl = 0.0557 * X - 0.2040 * Y + 1.0570 * Z
	-- Apply gamma, round to 0-255, and format as a hex string
	local function byte(v)
		v = math.min(1, math.max(0, v))
		return math.floor(gamma(v) * 255 + 0.5)
	end
	return string.format("#%02x%02x%02x", byte(r), byte(g), byte(bl))
end

-- LCh hue angles (in degrees) of the original Solarized accents, computed from the original hex values such as #b58900
local HUES = {
	yellow = 84.1,
	orange = 47.9,
	red = 34.1,
	magenta = 354.9,
	violet = 294.3,
	blue = 265.8,
	cyan = 187.8,
	green = 110.7,
}

-- LCh hue angles and chroma C* of the original Solarized base colors (computed from base03, base02, base01, base0, and base2)
local BASE_H = { bg = 229.9, bg_alt = 229.2, text = 209.0, muted = 225.9, bright = 96.6 }
local BASE_C = { bg = 14.5, bg_alt = 15.6, text = 6.4, muted = 9.2, bright = 10.0 }

-- Lightness and chroma shared by all accents. The original uses L* 49-60, C* 34-77.
-- L* sits slightly below the body foreground (L* 70) to reduce glare, and C* is about half of the original.
-- Hues match the original and L*/C* are the same for every accent, so each one has the same contrast of about 6.1:1 against the background
local ACCENT_L = 68
local ACCENT_C = 32

-- Backgrounds use the original's hue, chroma, and lightness (base03, base02).
-- Foregrounds keep the original's hue and chroma and are only made lighter for readability
-- (body L* 60 -> 70, comments L* 45 -> 63; comment contrast against the background goes from 2.8:1 in the original to about 5.2:1).
-- Selection and diff backgrounds are darker than the values derived from the original, so body text and accents keep at least 4.5:1 contrast on them
---@type table<"dark", DimSolarizedPalette>
M.palettes = {
	dark = {
		bg = lch(15.5, BASE_C.bg, BASE_H.bg),
		bg_alt = lch(20.3, BASE_C.bg_alt, BASE_H.bg_alt),
		bg_sel = lch(25, 16, BASE_H.muted),
		bg_float = lch(13, 14, BASE_H.bg),
		fg = lch(70, BASE_C.text, BASE_H.text),
		fg_dim = lch(63, BASE_C.muted, BASE_H.muted),
		fg_bright = lch(87, BASE_C.bright, BASE_H.bright),
		comment = lch(63, BASE_C.muted, BASE_H.muted),
		border = lch(42, 17, BASE_H.muted),
		yellow = lch(ACCENT_L, ACCENT_C, HUES.yellow),
		orange = lch(ACCENT_L, ACCENT_C, HUES.orange),
		red = lch(ACCENT_L, ACCENT_C, HUES.red),
		magenta = lch(ACCENT_L, ACCENT_C, HUES.magenta),
		violet = lch(ACCENT_L, ACCENT_C, HUES.violet),
		blue = lch(ACCENT_L, ACCENT_C, HUES.blue),
		cyan = lch(ACCENT_L, ACCENT_C, HUES.cyan),
		green = lch(ACCENT_L, ACCENT_C, HUES.green),
		-- Diff backgrounds use the original accent hues, darkened and desaturated
		diff_add = lch(24, 17, HUES.cyan),
		diff_change = lch(23, 17, HUES.blue),
		diff_delete = lch(22, 10, HUES.magenta),
		diff_text = lch(34, 20, HUES.blue),
	},
}

--- Return a copy of the palette, so callers can modify it without affecting anyone else. Only the dark palette exists for now.
---@return DimSolarizedPalette
function M.get()
	return vim.deepcopy(M.palettes.dark)
end

return M
