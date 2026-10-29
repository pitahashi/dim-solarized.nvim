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

local lch = require("dim-solarized.color").lch

local M = {}

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

-- LCh hue angles and chroma C* of the base colors. The bg and bg_alt values are the original Solarized base03 and base02 (#002b36, #073642), and the muted value is taken from Twitter's "Dim" theme (#8b98a5).
-- The text and bright values come from the original Solarized (base0, base2)
local BASE_H = { bg = 229.9, bg_alt = 229.2, text = 209.0, muted = 257.6, bright = 96.6 }
local BASE_C = { bg = 14.5, bg_alt = 15.6, text = 6.4, muted = 8.6, bright = 10.0 }

-- Lightness and chroma shared by all accents. The original uses L* 49-60, C* 34-77.
-- L* sits slightly below the body foreground (L* 70) to reduce glare, and C* is about 45-100% of the original.
-- Hues match the original and L*/C* are the same for every accent, so each one has the same contrast of about 5.9:1 against the background
local ACCENT_L = 66
local ACCENT_C = 36

-- Per-accent L* offsets for the warm hues, which look alike at equal lightness (red, orange, magenta).
-- Offsets are only positive so every accent keeps at least 4.5:1 contrast on the selection background
local ACCENT_L_SHIFT = { red = 0, magenta = 3, orange = 6 }

-- Per-accent chroma offsets. Red keeps the original hue but gets extra chroma, so it stays red instead of washing out to salmon at the shared lightness.
-- Cyan gets less chroma, so it looks softer next to the other accents
local ACCENT_C_SHIFT = { red = 20, cyan = -7 }

--- Chroma of an accent: the shared ACCENT_C plus its optional offset.
---@param name string Accent name
---@return number
local function accent_c(name)
	return ACCENT_C + (ACCENT_C_SHIFT[name] or 0)
end

--- Lightness of an accent: the shared ACCENT_L plus its optional offset.
---@param name string Accent name
---@return number
local function accent_l(name)
	return ACCENT_L + (ACCENT_L_SHIFT[name] or 0)
end

-- Backgrounds follow the original Solarized base03 and base02. Selection and border share their hue, and the muted foreground follows Twitter's "Dim" theme.
-- Foregrounds keep the original's hue and chroma and are only made lighter for readability
-- (body L* 60 -> 70, comments L* 45 -> 63; comment contrast against the background goes from 2.8:1 in the original to about 5.7:1).
-- Selection and diff backgrounds are darker than the values derived from the original, so body text and accents keep at least 4.5:1 contrast on them
---@type table<"dark", DimSolarizedPalette>
M.palettes = {
	dark = {
		bg = lch(15.5, BASE_C.bg, BASE_H.bg),
		bg_alt = lch(20.3, BASE_C.bg_alt, BASE_H.bg_alt),
		bg_sel = lch(22.5, 14, BASE_H.bg_alt),
		bg_float = lch(12.5, 13, BASE_H.bg),
		fg = lch(70, BASE_C.text, BASE_H.text),
		fg_dim = lch(63, BASE_C.muted, BASE_H.muted),
		fg_bright = lch(87, BASE_C.bright, BASE_H.bright),
		comment = lch(63, BASE_C.muted, BASE_H.muted),
		border = lch(38, 10, BASE_H.bg_alt),
		yellow = lch(accent_l("yellow"), ACCENT_C, HUES.yellow),
		orange = lch(accent_l("orange"), ACCENT_C, HUES.orange),
		red = lch(accent_l("red"), accent_c("red"), HUES.red),
		magenta = lch(accent_l("magenta"), ACCENT_C, HUES.magenta),
		violet = lch(accent_l("violet"), ACCENT_C, HUES.violet),
		blue = lch(accent_l("blue"), ACCENT_C, HUES.blue),
		cyan = lch(accent_l("cyan"), accent_c("cyan"), HUES.cyan),
		green = lch(accent_l("green"), ACCENT_C, HUES.green),
		-- Diff backgrounds use the original accent hues, darkened, with chroma proportional to ACCENT_C so they follow the accents
		diff_add = lch(24, ACCENT_C * 0.53, HUES.cyan),
		diff_change = lch(23, ACCENT_C * 0.53, HUES.blue),
		diff_delete = lch(22, ACCENT_C * 0.31, HUES.magenta),
		diff_text = lch(34, ACCENT_C * 0.62, HUES.blue),
	},
}

--- Return a copy of the palette, so callers can modify it without affecting anyone else. Only the dark palette exists for now.
---@return DimSolarizedPalette
function M.get()
	return vim.deepcopy(M.palettes.dark)
end

return M
