-- Generate docs/palette.svg, the palette image for the README.
-- Lay the palette out on a mock Neovim window (tabline, code with line numbers, floats, statusline, command line).
-- The left side shows the palette itself as Lua code; the floats on the right show accents, foregrounds, and diff colors.
-- Usage: run `nvim -l scripts/gen_palette.lua` from the plugin root
vim.opt.rtp:prepend(vim.fn.getcwd())
local c = require("dim-solarized.palette").get()

-- Groups to display (headings and color names in order)
local groups = {
	{ "Background", { "bg", "bg_alt", "bg_sel", "bg_float", "border" } },
	{ "Foreground", { "fg", "fg_dim", "fg_bright", "comment" } },
	{ "Accent", { "yellow", "orange", "red", "magenta", "violet", "blue", "cyan", "green" } },
	{ "Diff", { "diff_add", "diff_change", "diff_delete", "diff_text" } },
}

local W = 880 -- image width
local LH = 22 -- height of one line
local CW = 7.8 -- width of one character in a 13px monospace font (approximate, for alignment inside floats)
local TAB_H = 32 -- tabline height
local STATUS_H, CMD_H = 26, 24
local CURSOR_NAME = "blue" -- color name used for the cursor line
local FONT = "JetBrains Mono, SF Mono, Menlo, Consolas, monospace"

local out = {}

--- Escape text that cannot appear in an SVG string.
---@param s string
---@return string
local function esc(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--- Return whether a background color is dark. Dark colors cannot be used as text colors, so this guides foreground color choice.
---@param hex string #rrggbb
---@return boolean
local function is_dark(hex)
	-- Split the hex string into RGB values in 0-255
	local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
	-- Treat the color as dark when the perceived luminance (Rec.601 weights) is below 90
	return 0.299 * r + 0.587 * g + 0.114 * b < 90
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param fill string
---@param extra? string extra attributes (rx, stroke, etc.)
local function rect(x, y, w, h, fill, extra)
	out[#out + 1] = string.format('<rect x="%g" y="%g" width="%g" height="%g" fill="%s" %s/>', x, y, w, h, fill, extra or "")
end

--- Emit one <text>. body may be a tspan sequence built by the caller.
---@param x number
---@param y number
---@param fill string
---@param body string
---@param extra? string
local function text(x, y, fill, body, extra)
	out[#out + 1] = string.format(
		'<text x="%g" y="%g" fill="%s" font-size="13" xml:space="preserve" %s>%s</text>',
		x, y, fill, extra or "", body
	)
end

--- Build a colored tspan.
---@param s string
---@param fill string
---@param extra? string
---@return string
local function span(s, fill, extra)
	return string.format('<tspan fill="%s" %s>%s</tspan>', fill, extra or "", esc(s))
end

--- Draw a floating window whose border carries a title.
---@param x number
---@param y number
---@param w number
---@param h number
---@param title string
local function float(x, y, w, h, title)
	rect(x, y, w, h, c.bg_float, string.format('rx="8" stroke="%s" stroke-width="1.5"', c.border))
	-- Cut the border out with the background color for the width of the title, then place the title on top
	local tw = #title * CW + 16
	rect(x + 14, y - 2, tw, 4, c.bg_float)
	text(x + 22, y + 4, c.fg_bright, esc(title), 'font-weight="bold"')
end

-- Build the code lines first so the overall height can be decided
---@class GenRow
---@field kind "plain"|"comment"|"entry"
---@field body string tspan sequence
---@field hex? string swatch color
---@field name? string

---@type GenRow[]
local rows = {}
rows[#rows + 1] = {
	kind = "plain",
	body = span("local", c.green) .. span(" palette ", c.fg) .. span("= {", c.fg_dim),
}
for _, group in ipairs(groups) do
	rows[#rows + 1] = { kind = "comment", body = span("  -- " .. group[1], c.comment, 'font-style="italic"') }
	for _, name in ipairs(group[2]) do
		local hex = c[name]
		-- Dark colors would sink into the background as text, so write them in the body color; write bright colors in their own color
		local value_fill = is_dark(hex) and c.fg or hex
		rows[#rows + 1] = {
			kind = "entry",
			name = name,
			hex = hex,
			body = span("  " .. string.format("%-9s", name), c.fg)
				.. span(" = ", c.fg_dim)
				.. span('"' .. hex .. '"', value_fill)
				.. span(",", c.fg_dim),
		}
	end
end
rows[#rows + 1] = { kind = "plain", body = span("}", c.fg_dim) }

-- Line number of the cursor line (for the statusline)
local cursor_ln = 1
for i, row in ipairs(rows) do
	if row.name == CURSOR_NAME then
		cursor_ln = i
	end
end

local code_h = #rows * LH + 24
local H = TAB_H + code_h + STATUS_H + CMD_H
local status_y = TAB_H + code_h
local SPLIT_X = 400 -- boundary between code and floats

out[#out + 1] = string.format(
	'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="%s">',
	W, H, W, H, FONT
)
out[#out + 1] = string.format('<clipPath id="win"><rect width="%d" height="%d" rx="12"/></clipPath>', W, H)
out[#out + 1] = '<g clip-path="url(#win)">'
rect(0, 0, W, H, c.bg)

-- Tabline: give the active tab the same background as the body and draw an accent line along its top edge
rect(0, 0, W, TAB_H, c.bg_float)
rect(0, 0, 168, TAB_H, c.bg)
rect(0, 0, 168, 2, c.yellow)
text(16, 21, c.fg_bright, span("● ", c.yellow) .. span("palette.lua", c.fg_bright))
text(184, 21, c.comment, "highlights.lua")
text(W - 16, 21, c.comment, "dim-solarized.nvim", 'text-anchor="end"')

-- Code side: draw the cursor line, line numbers, body, and swatches in that order
for i, row in ipairs(rows) do
	local y = TAB_H + 12 + (i - 1) * LH
	local is_cursor = row.name == CURSOR_NAME
	if is_cursor then
		-- Mark the cursor line with a sign on the left edge and a band
		rect(0, y, SPLIT_X - 20, LH, c.bg_alt)
		rect(0, y, 3, LH, c.blue)
	end
	text(40, y + 15, is_cursor and c.fg_bright or c.comment, tostring(i), 'text-anchor="end"')
	text(64, y + 15, c.fg, row.body)
	if row.hex then
		-- Place the swatch at the end of the line like virtual text. Add a thin outline so colors close to the background stay visible
		rect(296, y + 4, 40, LH - 8, row.hex, string.format('rx="3" stroke="%s"', c.border))
	end
end

-- Right float 1: accents. The selected row uses the same color as the cursor
local fx, fw = SPLIT_X, W - SPLIT_X - 20
local ay = TAB_H + 16
local accents = groups[3][2]
float(fx, ay, fw, #accents * LH + 32, "Accent")
for i, name in ipairs(accents) do
	local y = ay + 16 + (i - 1) * LH
	if name == CURSOR_NAME then
		rect(fx + 8, y, fw - 16, LH, c.bg_sel, 'rx="4"')
	end
	text(fx + 20, y + 15, c[name], "●")
	text(fx + 44, y + 15, c.fg, esc(name))
	text(fx + fw - 20, y + 15, c.fg_dim, esc(c[name]), 'text-anchor="end"')
end

-- Right float 2: foregrounds. Each name is written in its own color
local py = ay + #accents * LH + 32 + 24
local fgs = { "fg_bright", "fg", "comment" }
float(fx, py, fw, #fgs * LH + 32, "Foreground")
for i, name in ipairs(fgs) do
	local y = py + 16 + (i - 1) * LH
	local extra = name == "comment" and 'font-style="italic"' or ""
	text(fx + 20, y + 15, c[name], esc(string.format("%-10s", name)) .. "The quick brown fox", extra)
	text(fx + fw - 20, y + 15, c.fg_dim, esc(c[name]), 'text-anchor="end"')
end

-- Right float 3: diff. Show full-line backgrounds and the highlight for changed parts (diff_text)
local dy = py + #fgs * LH + 32 + 24
float(fx, dy, fw, 4 * LH + 32, "Diff")
local diff_rows = {
	{ bg = c.diff_add, mark = "+", pre = "local added   = ", hl = nil, post = "" },
	{ bg = c.diff_change, mark = "~", pre = "local changed = ", hl = "42", post = "" },
	{ bg = c.diff_delete, mark = "-", pre = "local removed = ", hl = nil, post = "" },
}
for i, d in ipairs(diff_rows) do
	local y = dy + 16 + (i - 1) * LH
	rect(fx + 8, y, fw - 16, LH, d.bg)
	local line = d.mark .. " " .. d.pre
	text(fx + 20, y + 15, c.fg, esc(line))
	-- For the emphasized value, compute the x coordinate from the length of the preceding text and overlay the background
	local vx = fx + 20 + #line * CW
	if d.hl then
		rect(vx - 2, y + 2, #d.hl * CW + 4, LH - 4, c.diff_text, 'rx="3"')
		text(vx, y + 15, c.fg_bright, esc(d.hl))
	else
		text(vx, y + 15, c.fg, d.mark == "-" and "nil" or "true")
	end
end
-- Legend line for diff_text
local ly = dy + 16 + 3 * LH
rect(fx + 8, ly, fw - 16, LH, c.bg_alt)
text(fx + 20, ly + 15, c.comment, esc("diff_text highlights changed parts"), 'font-style="italic"')

-- Statusline: show the mode as a rounded blue label and put position info on the right
rect(0, status_y, W, STATUS_H, c.bg_alt)
rect(0, status_y, 92, STATUS_H, c.blue)
text(46, status_y + 17, c.bg, "NORMAL", 'text-anchor="middle" font-weight="bold"')
text(106, status_y + 17, c.fg_bright, "palette.lua")
text(W - 16, status_y + 17, c.fg_dim, string.format("lua  utf-8  ln %d/%d", cursor_ln, #rows), 'text-anchor="end"')

-- Command line
text(16, status_y + STATUS_H + 16, c.fg, span(":", c.yellow) .. span("colorscheme ", c.fg) .. span("dim-solarized", c.cyan))

out[#out + 1] = "</g>"
-- Overlay the outer frame outside the clip to draw a line that follows the rounded corners
out[#out + 1] = string.format(
	'<rect x="0.5" y="0.5" width="%d" height="%d" rx="12" fill="none" stroke="%s"/>',
	W - 1, H - 1, c.border
)
out[#out + 1] = "</svg>\n"

vim.fn.mkdir("docs", "p")
local f = assert(io.open("docs/palette.svg", "w"))
f:write(table.concat(out, "\n"))
f:close()
