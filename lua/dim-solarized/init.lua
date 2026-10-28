local palette = require("dim-solarized.palette")
local highlights = require("dim-solarized.highlights")

local M = {}

---@class DimSolarizedOptions
---@field transparent boolean Make the background of Normal-family groups transparent
---@field italic_comments boolean Italicize comments
---@field on_colors fun(c: DimSolarizedPalette)? Modifies the palette in place before highlights are built
---@field on_highlights fun(c: DimSolarizedPalette, groups: table<string, vim.api.keyset.highlight>): table<string, vim.api.keyset.highlight>? Returns highlights to add or override; `groups` contains the built-in definitions

---@type DimSolarizedOptions
M.options = {
	transparent = false,
	italic_comments = true,
	on_colors = function() end,
	on_highlights = function()
		return {}
	end,
}

--- Apply user options. Call this before `:colorscheme`.
--- Example: `require("dim-solarized").setup({ transparent = true })`
---@param opts? DimSolarizedOptions|table Options to override
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

--- Return the palette with the `on_colors` option applied.
---@return DimSolarizedPalette
function M.colors()
	local c = palette.get()
	-- Skip on_colors unless it is a function, so a bad value can't break loading
	if type(M.options.on_colors) == "function" then
		M.options.on_colors(c)
	end
	return c
end

--- Apply the colorscheme.
function M.load()
	-- Clear existing highlights and syntax so nothing is left over from the previous colorscheme
	vim.cmd("highlight clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end

	-- Setting 'background' re-sources the colorscheme when g:colors_name is set,
	-- so clear colors_name first to avoid recursion
	vim.g.colors_name = nil
	vim.o.background = "dark"

	local c = M.colors()
	for name, def in pairs(highlights.build(c, M.options)) do
		vim.api.nvim_set_hl(0, name, def)
	end

	-- 16 colors for :terminal, ordered as ANSI (black, red, green, yellow, blue, magenta, cyan, white, then each bright).
	-- The bright variants reuse the accents so bright red/green/yellow/blue/magenta/cyan stay recognizable;
	-- bright black is the dim foreground so "dim" output stays readable on the background
	local ansi = {
		c.bg_alt, c.red, c.green, c.yellow, c.blue, c.magenta, c.cyan, c.fg,
		c.fg_dim, c.red, c.green, c.yellow, c.blue, c.magenta, c.cyan, c.fg_bright,
	}
	for i, color in ipairs(ansi) do
		vim.g["terminal_color_" .. (i - 1)] = color
	end

	vim.g.colors_name = "dim-solarized"
end

return M
