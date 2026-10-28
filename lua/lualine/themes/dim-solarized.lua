local c = require("dim-solarized").colors()

--- Build one mode section set. `a` is the mode label, `b`/`c` are the inner sections.
---@param accent string Background color of the mode label
---@return table
local function mode(accent)
	return {
		a = { fg = c.bg, bg = accent, gui = "bold" },
		b = { fg = c.fg, bg = c.bg_sel },
		c = { fg = c.fg, bg = c.bg_alt },
	}
end

-- Colors follow the MiniStatuslineMode* groups so the mode colors match across statusline plugins
return {
	normal = mode(c.blue),
	insert = mode(c.green),
	visual = mode(c.magenta),
	replace = mode(c.red),
	command = mode(c.yellow),
	terminal = mode(c.cyan),
	inactive = {
		a = { fg = c.fg_dim, bg = c.bg_alt },
		b = { fg = c.fg_dim, bg = c.bg_alt },
		c = { fg = c.fg_dim, bg = c.bg_alt },
	},
}
