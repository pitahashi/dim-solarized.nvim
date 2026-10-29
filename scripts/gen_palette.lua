-- Generate docs/palette.svg, the color palette chart for the README.
-- Each color is shown with its CIE LCh(ab) coordinates and its WCAG contrast ratio against the pair listed in `groups`.
-- Usage: run `nvim -l scripts/gen_palette.lua` from the plugin root
vim.opt.rtp:prepend(vim.fn.getcwd())
local c = require("dim-solarized.palette").get()
local color = require("dim-solarized.color")

-- `against` is the color each member is measured against: text colors on the background, and the body text on background-like colors
local groups = {
	{ "Background", "Surfaces, measured with fg text on top", "fg", { "bg", "bg_alt", "bg_sel", "bg_float", "border" }, true },
	{ "Foreground", "Text, measured on bg", "bg", { "fg", "fg_dim", "fg_bright", "comment" } },
	{ "Accent", "Shared lightness and chroma, hues from Solarized, measured on bg", "bg", { "yellow", "orange", "red", "magenta", "violet", "blue", "cyan", "green" } },
	{ "Diff", "Backgrounds, measured with fg text on top", "fg", { "diff_add", "diff_change", "diff_delete", "diff_text" }, true },
}

local PAD = 28
local SW, SH = 96, 72
local GAP = 12
local COLS = 8
local FONT = "JetBrains Mono, SF Mono, Menlo, Consolas, monospace"
local W = PAD * 2 + COLS * SW + (COLS - 1) * GAP

---@param ratio number
---@return string
local function grade(ratio)
	if ratio >= 7 then
		return "AAA"
	elseif ratio >= 4.5 then
		return "AA"
	elseif ratio >= 3 then
		return "AA large"
	end
	return "-"
end

local function text(x, y, fill, size, body, extra)
	return string.format('<text x="%d" y="%d" fill="%s" font-size="%d" %s>%s</text>', x, y, fill, size, extra or "", body)
end

local body = {}
local y = PAD
for _, group in ipairs(groups) do
	local title, note, against, names, against_is_text = group[1], group[2], group[3], group[4], group[5]
	body[#body + 1] = text(PAD, y + 14, c.fg_bright, 15, title, 'font-weight="bold"')
	body[#body + 1] = text(PAD, y + 32, c.comment, 11, note)
	y = y + 48
	for i, name in ipairs(names) do
		local x = PAD + (i - 1) * (SW + GAP)
		local hex = c[name]
		local L, C, h = color.to_lch(hex)
		local ratio = against_is_text and color.contrast(c[against], hex) or color.contrast(hex, c[against])
		body[#body + 1] = string.format(
			'<rect x="%d" y="%d" width="%d" height="%d" rx="6" fill="%s" stroke="%s"/>',
			x, y, SW, SH, hex, c.border
		)
		body[#body + 1] = text(x, y + SH + 16, c.fg, 12, name, 'font-weight="bold"')
		body[#body + 1] = text(x, y + SH + 31, c.fg_dim, 11, hex)
		body[#body + 1] = text(x, y + SH + 45, c.comment, 10, string.format("L %d  C %d  h %d", L + 0.5, C + 0.5, h + 0.5))
		body[#body + 1] = text(x, y + SH + 59, c.comment, 10, string.format("%.1f:1  %s", ratio, grade(ratio)))
	end
	y = y + SH + 59 + 26
end

local H = y + PAD - 26
local out = {
	string.format(
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="%s">',
		W, H, W, H, FONT
	),
	string.format('<rect width="%d" height="%d" rx="12" fill="%s"/>', W, H, c.bg),
}
vim.list_extend(out, body)
out[#out + 1] = "</svg>\n"

vim.fn.mkdir("docs", "p")
local f = assert(io.open("docs/palette.svg", "w"))
f:write(table.concat(out, "\n"))
f:close()
