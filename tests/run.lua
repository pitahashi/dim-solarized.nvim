-- Run with: nvim -l tests/run.lua
-- Plain-Lua tests with no external dependencies.

-- Make the plugin under test loadable regardless of the working directory
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

local failures = 0

--- Run one named check and report its result.
---@param name string Test name
---@param fn fun() Function that raises an error on failure
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end

local color = require("dim-solarized.color")
local contrast = color.contrast

local palette = require("dim-solarized.palette").get()
local highlights = require("dim-solarized.highlights")
local plugin = require("dim-solarized")
local accents = { "yellow", "orange", "red", "magenta", "violet", "blue", "cyan", "green" }

--- Convert #rrggbb to the integer that nvim_get_hl returns.
---@param hex string
---@return integer
local function to_int(hex)
	return tonumber(hex:sub(2), 16)
end

--- Restore the default options so tests do not leak state into each other.
local function reset()
	plugin.options = vim.deepcopy(plugin.defaults)
end

-- Groups drawn as separators, guides, or filler. They are meant to be subtle, so they only
-- need to stay faintly visible (2:1) instead of reaching the text threshold.
local DECORATIVE = {
	WinSeparator = true, NonText = true, Whitespace = true, SpecialKey = true,
	FloatBorder = true, TelescopeBorder = true, TelescopeResultsBorder = true,
	TelescopePreviewBorder = true, SnacksIndent = true, PmenuThumb = true, PmenuSbar = true,
	Conceal = true,
}
-- Groups that intentionally blend into their background to hide the element (e.g. the `~` after the last line)
local HIDDEN = { EndOfBuffer = true, TelescopePromptBorder = true }
local TEXT_MIN, DECORATIVE_MIN = 4.5, 2.0

test("contrast calculation matches WCAG reference pairs", function()
	assert(math.abs(contrast("#000000", "#ffffff") - 21) < 0.001)
	assert(contrast("#002b36", "#002b36") == 1)
	assert(math.abs(contrast("#777777", "#ffffff") - 4.478) < 0.001)
end)

test("palette values are #rrggbb strings", function()
	for key, value in pairs(palette) do
		assert(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), key .. " = " .. tostring(value))
	end
end)

--- Raw 0-255 channels of a #rrggbb color.
---@param hex string
---@return integer r, integer g, integer b
local function channels(hex)
	return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

test("backgrounds are dark teal-blue (red lowest, blue at least green)", function()
	for _, name in ipairs({ "bg", "bg_alt", "bg_float" }) do
		local r, g, b = channels(palette[name])
		assert(b >= g and g > r, name .. ": " .. palette[name])
	end
end)

test("every accent has 5.5-8.0:1 contrast against bg", function()
	for _, name in ipairs(accents) do
		local ratio = contrast(palette[name], palette.bg)
		assert(ratio > 5.5 and ratio < 8.0, string.format("%s: %.2f", name, ratio))
	end
end)

test("accents keep the original Solarized hue order", function()
	-- The LCh hue angle isn't exposed, so compare the dominant RGB channel instead
	local r, _, b = channels(palette.red)
	assert(r > b, "red should be warm")
	r, _, b = channels(palette.blue)
	assert(b > r, "blue should be cool")
	local _, g
	_, g, b = channels(palette.green)
	assert(g > b, "green should have more green than blue")
end)

test("comment and dim foreground have at least 4.5:1 against bg and bg_alt", function()
	for _, bg in ipairs({ "bg", "bg_alt", "bg_float" }) do
		for _, fg in ipairs({ "comment", "fg_dim" }) do
			local ratio = contrast(palette[fg], palette[bg])
			assert(ratio >= TEXT_MIN, string.format("%s on %s: %.2f", fg, bg, ratio))
		end
	end
end)

test("body text has at least 4.5:1 against every text background", function()
	for _, bg in ipairs({ "bg", "bg_alt", "bg_sel", "bg_float", "diff_add", "diff_change", "diff_delete" }) do
		local ratio = contrast(palette.fg, palette[bg])
		assert(ratio >= TEXT_MIN, string.format("fg on %s: %.2f", bg, ratio))
	end
end)

test("accents have at least 4.5:1 on cursor line and syntax-preserving diff surfaces", function()
	for _, bg in ipairs({ "bg_alt", "diff_change", "diff_delete" }) do
		for _, name in ipairs(accents) do
			local ratio = contrast(palette[name], palette[bg])
			assert(ratio >= TEXT_MIN - 0.05, string.format("%s on %s: %.2f", name, bg, ratio))
		end
	end
end)

--- Names of built-in groups with an explicit hex fg whose contrast against `bg_of(def)` falls short.
---@param bg_of fun(def: table): string? Background to check against, or nil to skip the group
---@return string[]
local function unreadable(bg_of)
	reset()
	local failed = {}
	for name, def in pairs(highlights.build(palette, plugin.options)) do
		local bg = not HIDDEN[name] and not def.link and def.fg and def.fg:sub(1, 1) == "#" and bg_of(def)
		if bg and bg:sub(1, 1) == "#" then
			local min = DECORATIVE[name] and DECORATIVE_MIN or TEXT_MIN
			local ratio = contrast(def.fg, bg)
			if ratio < min - 0.05 then
				table.insert(failed, string.format("%s %.2f", name, ratio))
			end
		end
	end
	table.sort(failed)
	return failed
end

test("every highlight group with fg and bg is readable", function()
	local failed = unreadable(function(def)
		return def.bg
	end)
	assert(#failed == 0, table.concat(failed, ", "))
end)

test("every highlight group with only fg is readable on bg", function()
	local failed = unreadable(function(def)
		return not def.bg and palette.bg or nil
	end)
	assert(#failed == 0, table.concat(failed, ", "))
end)

test("link targets exist in the generated groups", function()
	reset()
	local groups = highlights.build(palette, plugin.options)
	for name, def in pairs(groups) do
		if def.link then
			assert(groups[def.link], name .. " links to missing group " .. def.link)
		end
	end
end)

test("every generated group is accepted by nvim_set_hl", function()
	reset()
	for name, def in pairs(highlights.build(palette, plugin.options)) do
		local ok, err = pcall(vim.api.nvim_set_hl, 0, name, def)
		assert(ok, name .. ": " .. tostring(err))
	end
end)

test("colorscheme loads and sets colors_name", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	assert(vim.g.colors_name == "dim-solarized", tostring(vim.g.colors_name))
	assert(vim.o.background == "dark")
end)

test("loading twice gives the same result", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local first = vim.api.nvim_get_hl(0, { name = "Normal" })
	vim.cmd("colorscheme dim-solarized")
	assert(vim.inspect(first) == vim.inspect(vim.api.nvim_get_hl(0, { name = "Normal" })))
end)

test("background stays dark after setting it to light", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	vim.o.background = "light"
	vim.cmd("colorscheme dim-solarized")
	assert(vim.o.background == "dark")
end)

test("Normal and terminal colors match the palette", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
	assert(normal.bg == to_int(palette.bg), "Normal.bg")
	assert(normal.fg == to_int(palette.fg), "Normal.fg")
	assert(vim.g.terminal_color_1 == palette.red, "terminal_color_1")
	assert(vim.g.terminal_color_4 == palette.blue, "terminal_color_4")
	for i = 0, 15 do
		local color = vim.g["terminal_color_" .. i]
		assert(color and color:match("^#%x%x%x%x%x%x$"), "terminal_color_" .. i)
	end
end)

test("italic_comments toggles italic on Comment", function()
	reset()
	plugin.setup({ italic_comments = false })
	vim.cmd("colorscheme dim-solarized")
	assert(not vim.api.nvim_get_hl(0, { name = "Comment" }).italic)
	plugin.setup({ italic_comments = true })
	vim.cmd("colorscheme dim-solarized")
	assert(vim.api.nvim_get_hl(0, { name = "Comment" }).italic)
end)

test("transparent removes only the Normal-family backgrounds", function()
	reset()
	plugin.setup({ transparent = true })
	vim.cmd("colorscheme dim-solarized")
	assert(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil, "Normal")
	assert(vim.api.nvim_get_hl(0, { name = "NormalFloat" }).bg == nil, "NormalFloat")
	assert(vim.api.nvim_get_hl(0, { name = "CursorLine" }).bg == to_int(palette.bg_alt), "CursorLine")
end)

test("on_highlights overrides groups and wins over transparent", function()
	reset()
	plugin.setup({
		transparent = true,
		on_highlights = function(c)
			return { CursorLine = { bg = c.red }, Normal = { fg = c.fg, bg = c.bg } }
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(vim.api.nvim_get_hl(0, { name = "CursorLine" }).bg == to_int(palette.red), "CursorLine")
	assert(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == to_int(palette.bg), "Normal")
end)

test("overrides replace a group instead of merging attributes", function()
	reset()
	plugin.setup({
		on_highlights = function(c)
			return { Comment = { fg = c.red } }
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(not vim.api.nvim_get_hl(0, { name = "Comment" }).italic)
end)

test("invalid on_highlights values do not break loading", function()
	for _, value in ipairs({ false, "x" }) do
		reset()
		plugin.options.on_highlights = value
		vim.cmd("colorscheme dim-solarized")
		assert(vim.g.colors_name == "dim-solarized")
	end
	reset()
	plugin.setup({
		on_highlights = function()
			return nil
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(vim.g.colors_name == "dim-solarized")
end)

test("lualine theme exposes every mode with readable colors", function()
	local theme = require("lualine.themes.dim-solarized")
	for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
		assert(theme[mode] and theme[mode].a and theme[mode].b and theme[mode].c, mode)
		for _, section in ipairs({ "a", "b", "c" }) do
			local s = theme[mode][section]
			local ratio = contrast(s.fg, s.bg)
			assert(ratio >= TEXT_MIN - 0.05, string.format("%s.%s: %.2f", mode, section, ratio))
		end
	end
end)

test("modifying a returned palette does not affect later callers", function()
	local copy = require("dim-solarized.palette").get()
	copy.red = "#000000"
	assert(require("dim-solarized.palette").get().red == palette.red)
end)

test("on_colors changes the palette used by highlights, terminal colors and colors()", function()
	reset()
	plugin.setup({
		on_colors = function(c)
			c.red = "#ff0000"
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(plugin.colors().red == "#ff0000", "colors()")
	assert(vim.g.terminal_color_1 == "#ff0000", "terminal_color_1")
	assert(vim.api.nvim_get_hl(0, { name = "Substitute" }).bg == to_int("#ff0000"), "Substitute")
	package.loaded["lualine.themes.dim-solarized"] = nil
	assert(require("lualine.themes.dim-solarized").replace.a.bg == "#ff0000", "lualine override")
	package.loaded["lualine.themes.dim-solarized"] = nil
	assert(require("dim-solarized.palette").get().red == palette.red, "base palette must stay untouched")
	reset()
end)

test("invalid on_colors values do not break loading", function()
	reset()
	plugin.options.on_colors = "x"
	vim.cmd("colorscheme dim-solarized")
	assert(vim.g.colors_name == "dim-solarized")
	reset()
end)

test("on_highlights receives the built-in groups", function()
	reset()
	local seen
	plugin.setup({
		on_highlights = function(_, groups)
			seen = groups
			return { Comment = { fg = groups.Comment.fg, italic = false } }
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(seen and seen.Normal, "groups table")
	assert(not vim.api.nvim_get_hl(0, { name = "Comment" }).italic)
	reset()
end)

test("bright terminal colors reuse the accents and bright black stays readable", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	for i = 1, 6 do
		assert(vim.g["terminal_color_" .. i] == vim.g["terminal_color_" .. (i + 8)], "bright " .. i)
	end
	assert(contrast(vim.g.terminal_color_8, palette.bg) >= TEXT_MIN, "bright black")
	assert(contrast(vim.g.terminal_color_7, palette.bg) >= TEXT_MIN, "white")
end)

test("no group falls back to a color outside the palette", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local known = {}
	for _, v in pairs(palette) do
		known[to_int(v)] = true
	end
	local leaks = {}
	for name in pairs(vim.api.nvim_get_hl(0, {})) do
		-- Skip Neovim's internal debug groups; they aren't part of the theme
		if not name:match("^Nvim") and not name:match("^RedrawDebug") then
			local def = vim.api.nvim_get_hl(0, { name = name, link = false })
			for _, key in ipairs({ "fg", "bg", "sp" }) do
				if def[key] and not known[def[key]] then
					table.insert(leaks, string.format("%s.%s=#%06x", name, key, def[key]))
				end
			end
		end
	end
	table.sort(leaks)
	assert(#leaks == 0, table.concat(leaks, ", "))
end)

test("every standard LSP semantic token type is mapped", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local types = {
		"namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter",
		"variable", "property", "enumMember", "event", "function", "method", "macro", "keyword",
		"modifier", "comment", "string", "number", "regexp", "operator", "decorator",
	}
	for _, name in ipairs(types) do
		local def = vim.api.nvim_get_hl(0, { name = "@lsp.type." .. name, link = false })
		-- Generic variables explicitly retain the underlying syntax/Tree-sitter color.
		assert(name == "variable" or def.fg, "@lsp.type." .. name .. " has no color")
	end
end)

test("routine identifiers are neutral across syntax, Tree-sitter and LSP", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local function fg(name)
		return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
	end
	for _, name in ipairs({ "Identifier", "@variable", "@variable.parameter", "@property",
		"@lsp.type.parameter", "@lsp.type.property" }) do
		assert(fg(name) == to_int(palette.fg), name)
	end
	-- Leave generic semantic variables uncolored so a server cannot erase
	-- more specific Tree-sitter captures (e.g. callable names).
	assert(not fg("@lsp.type.variable"))
	for _, pair in ipairs({
		{ "@lsp.type.function", "@function" }, { "@lsp.type.method", "@function.method" },
		{ "@lsp.type.type", "@type" }, { "@lsp.type.keyword", "@keyword" },
		{ "@lsp.type.string", "@string" }, { "@lsp.type.comment", "@comment" },
	}) do
		assert(fg(pair[1]) == fg(pair[2]), table.concat(pair, " / "))
	end
	assert(fg("Function") == to_int(palette.blue))
	assert(fg("Function") ~= fg("Identifier"))
	for _, name in ipairs({ "Delimiter", "@punctuation.delimiter", "@punctuation.bracket", "@markup.list" }) do
		assert(fg(name) == to_int(palette.fg_dim), name .. " should be secondary, not red")
	end
	assert(fg("DiagnosticError") == to_int(palette.red))
end)

test("defaultLibrary and readonly modifiers resolve to their role", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local function fg(name)
		return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
	end
	assert(fg("@lsp.typemod.variable.defaultLibrary") == fg("@variable.builtin"))
	assert(fg("@lsp.typemod.function.defaultLibrary") == fg("@function.builtin"))
	assert(fg("@lsp.typemod.class.defaultLibrary") == fg("@type.builtin"))
	assert(fg("@lsp.typemod.variable.readonly") == fg("@variable"))
	assert(fg("@lsp.typemod.property.readonly") == fg("@property"))
end)

test("every Tree-sitter and LSP group is readable once links are resolved", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local failed = {}
	for name in pairs(highlights.build(palette, plugin.options)) do
		if name:sub(1, 1) == "@" then
			local def = vim.api.nvim_get_hl(0, { name = name, link = false })
			if def.fg then
				local ratio = contrast(string.format("#%06x", def.fg), palette.bg)
				if ratio < TEXT_MIN - 0.05 then
					table.insert(failed, string.format("%s %.2f", name, ratio))
				end
			end
		end
	end
	table.sort(failed)
	assert(#failed == 0, table.concat(failed, ", "))
end)

-- Inspect the loaded definitions, including link resolution, rather than
-- only the palette. Surface thresholds are design regression guards, not WCAG.
local function loaded(name)
	local def = vim.api.nvim_get_hl(0, { name = name, link = false })
	for _, key in ipairs({ "fg", "bg" }) do
		if def[key] then def[key] = string.format("#%06x", def[key]) end
	end
	return def
end

local function readable(fg, bg, label)
	local ratio = contrast(fg, bg)
	assert(ratio >= TEXT_MIN, string.format("%s: %.2f:1 < 4.5:1", label, ratio))
end

test("Normal, comments and line numbers retain text contrast and a lightness hierarchy", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local normal = loaded("Normal")
	local previous = math.huge
	for _, name in ipairs({ "Normal", "Comment", "LineNr" }) do
		local fg = loaded(name).fg
		readable(fg, normal.bg, name)
		local L = color.to_lch(fg)
		assert(previous - L >= 3, name .. " must be quieter than the preceding role")
		previous = L
	end
	assert(loaded("StatusLine").fg ~= loaded("StatusLineNC").fg)
	assert(loaded("WinBar").fg ~= loaded("WinBarNC").fg)
	readable(loaded("StatusLineNC").fg, loaded("StatusLineNC").bg, "inactive statusline")
end)

test("selection surface is separated from Normal and CursorLine without extra chroma", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local visual = loaded("Visual")
	local L, C = color.to_lch(visual.bg)
	local baseL = color.to_lch(loaded("Normal").bg)
	assert(L - baseL >= 10, "selection needs at least 10 L* above Normal")
	assert(C <= 9, "selection must stay low chroma")
	assert(contrast(visual.bg, loaded("Normal").bg) >= 1.4, "selection / Normal surface")
	assert(contrast(visual.bg, loaded("CursorLine").bg) >= 1.2, "selection / CursorLine surface")
	readable(loaded("Normal").fg, visual.bg, "Normal foreground / Visual background")
end)

test("selected comments, strings and text use a readable explicit foreground", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	for _, selection in ipairs({ "Visual", "VisualNOS" }) do
		local visual = loaded(selection)
		assert(visual.fg, "selection must override syntax foregrounds")
		-- Definition-level checks; tests/render.lua additionally verifies
		-- the actual screen output with Tree-sitter and LSP active together.
		for _, name in ipairs({ "Normal", "Comment", "String", "@comment", "@string" }) do
			assert(loaded(name).fg, name)
			readable(visual.fg, visual.bg, selection .. " over " .. name)
		end
	end
end)

test("search, current match, selection and LSP references have different cues", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local visual, search, inc = loaded("Visual"), loaded("Search"), loaded("IncSearch")
	readable(search.fg, search.bg, "Search")
	readable(inc.fg, inc.bg, "IncSearch")
	assert(search.bg ~= visual.bg and inc.bg ~= visual.bg and search.bg ~= inc.bg)
	assert(contrast(search.bg, inc.bg) >= 2, "current search match surface needs a stronger cue")
	assert(loaded("CurSearch").bg == inc.bg)
	for _, name in ipairs({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }) do
		local ref = loaded(name)
		assert(ref.bg ~= visual.bg and ref.underline, name)
		for _, syntax in ipairs({ "Normal", "Comment", "String" }) do
			readable(loaded(syntax).fg, ref.bg, name .. " / " .. syntax)
		end
	end
	assert(loaded("LspReferenceWrite").bold, "write references need a non-color cue")
end)

test("all diagnostic virtual text severities retain 4.5:1 on their actual backgrounds", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	for _, severity in ipairs({ "Error", "Warn", "Info", "Hint" }) do
		local name = "DiagnosticVirtualText" .. severity
		local def = loaded(name)
		readable(def.fg, def.bg, name)
	end
end)

test("popup text and selected item are readable on distinguishable surfaces", function()
	reset()
	vim.cmd("colorscheme dim-solarized")
	local menu, selected = loaded("Pmenu"), loaded("PmenuSel")
	readable(menu.fg, menu.bg, "Pmenu")
	readable(selected.fg, selected.bg, "PmenuSel")
	assert(contrast(menu.bg, selected.bg) >= 1.5, "popup selection surface")
	assert(menu.fg ~= selected.fg, "popup selection also changes foreground")
end)

test("help file generates tags and every reference resolves", function()
	-- Work on a copy so the repository doesn't end up with a generated doc/tags file
	local tmp = vim.fn.tempname()
	vim.fn.mkdir(tmp .. "/doc", "p")
	vim.fn.writefile(vim.fn.readfile(root .. "/doc/dim-solarized.txt"), tmp .. "/doc/dim-solarized.txt")
	-- helptags raises on duplicate tags (E154)
	vim.cmd("helptags " .. tmp .. "/doc")
	local tags = table.concat(vim.fn.readfile(tmp .. "/doc/tags"), "\n")
	assert(tags:find("dim%-solarized%-options", 1), "dim-solarized-options")
	assert(tags:find("dim%-solarized%.setup%(%)", 1), "dim-solarized.setup()")

	local text = table.concat(vim.fn.readfile(root .. "/doc/dim-solarized.txt"), "\n")
	local defined = {}
	for tag in text:gmatch("%*([^%*%s]+)%*") do
		defined[tag] = true
	end
	for ref in text:gmatch("|([^|%s]+)|") do
		-- Options, commands, and built-in help tags aren't defined in this file
		if not ref:match("^[':]") and ref ~= "terminal" then
			assert(defined[ref], "undefined help reference: " .. ref)
		end
	end
end)

test("help file documents every option and palette key", function()
	local text = table.concat(vim.fn.readfile(root .. "/doc/dim-solarized.txt"), "\n")
	for name in pairs(plugin.options) do
		assert(text:find(name, 1, true), "option not documented: " .. name)
	end
	for name in pairs(palette) do
		assert(text:find(name, 1, true), "palette key not documented: " .. name)
	end
end)

test("help file lines fit in 78 columns", function()
	for i, line in ipairs(vim.fn.readfile(root .. "/doc/dim-solarized.txt")) do
		assert(#line <= 78, string.format("line %d has %d columns", i, #line))
	end
end)

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
