local palette = require("dim-solarized.palette")
local highlights = require("dim-solarized.highlights")

local M = {}

---@class DimSolarizedOptions
---@field transparent boolean Make the background of Normal-family groups transparent
---@field italic_comments boolean Italicize comments
---@field on_highlights fun(c: DimSolarizedPalette): table<string, vim.api.keyset.highlight>? Function returning highlights to add or override

---@type DimSolarizedOptions
M.options = {
	transparent = false,
	italic_comments = true,
	on_highlights = function()
		return {}
	end,
}

--- Apply user options. Call before running `colorscheme`.
--- Example: `require("dim-solarized").setup({ transparent = true })`
---@param opts? DimSolarizedOptions|table Options to override
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

--- Apply the colorscheme.
function M.load()
	-- Reset existing highlights and syntax to clear leftovers from the previous theme
	vim.cmd("highlight clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end

	-- Changing 'background' reloads the colorscheme when g:colors_name is set,
	-- so clear colors_name first to prevent re-entry
	vim.g.colors_name = nil
	vim.o.background = "dark"

	local c = palette.get()
	for name, def in pairs(highlights.build(c, M.options)) do
		vim.api.nvim_set_hl(0, name, def)
	end

	-- 16 colors for :terminal, ordered as ANSI (black, red, green, yellow, blue, magenta, cyan, white, then each bright)
	local ansi = {
		c.bg_alt, c.red, c.green, c.yellow, c.blue, c.magenta, c.cyan, c.fg,
		c.fg_dim, c.orange, c.comment, c.fg_dim, c.fg, c.violet, c.fg_bright, c.fg_bright,
	}
	for i, color in ipairs(ansi) do
		vim.g["terminal_color_" .. (i - 1)] = color
	end

	vim.g.colors_name = "dim-solarized"
end

return M
