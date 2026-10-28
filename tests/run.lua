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

--- Relative luminance of an sRGB color as defined by WCAG 2.x.
---@param hex string Color formatted as #rrggbb
---@return number
local function luminance(hex)
	-- Split "#rrggbb" into three channels scaled to 0-1
	local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
	local ch = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
	for i, v in ipairs(ch) do
		-- Undo the sRGB transfer function to get linear light
		ch[i] = v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	-- Weight the channels by the eye's sensitivity (Rec. 709 coefficients)
	return 0.2126 * ch[1] + 0.7152 * ch[2] + 0.0722 * ch[3]
end

--- WCAG contrast ratio between two colors.
---@param a string Color formatted as #rrggbb
---@param b string Color formatted as #rrggbb
---@return number
local function contrast(a, b)
	local la, lb = luminance(a), luminance(b)
	-- The lighter color goes in the numerator; 0.05 is the flare offset from the spec
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local palette = require("dim-solarized.palette").get()
local accents = { "yellow", "orange", "red", "magenta", "violet", "blue", "cyan", "green" }

test("palette values are #rrggbb strings", function()
	for key, value in pairs(palette) do
		assert(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), key .. " = " .. tostring(value))
	end
end)

test("background matches Solarized base03/base02", function()
	assert(palette.bg == "#002b36", palette.bg)
	assert(palette.bg_alt == "#073642", palette.bg_alt)
end)

test("every accent has about 6.1:1 contrast against bg", function()
	for _, name in ipairs(accents) do
		local ratio = contrast(palette[name], palette.bg)
		assert(ratio > 5.9 and ratio < 6.4, string.format("%s: %.2f", name, ratio))
	end
end)

test("comment has about 4.0:1 contrast against bg", function()
	local ratio = contrast(palette.comment, palette.bg)
	assert(ratio > 3.8 and ratio < 4.3, string.format("%.2f", ratio))
end)

test("body text keeps at least 4.5:1 against bg", function()
	local ratio = contrast(palette.fg, palette.bg)
	assert(ratio >= 4.5, string.format("%.2f", ratio))
end)

test("colorscheme loads and sets colors_name", function()
	vim.cmd("colorscheme dim-solarized")
	assert(vim.g.colors_name == "dim-solarized", tostring(vim.g.colors_name))
	assert(vim.o.background == "dark")
end)

test("Normal and terminal colors are applied", function()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
	assert(normal.bg == tonumber(palette.bg:sub(2), 16), "Normal.bg")
	for i = 0, 15 do
		assert(vim.g["terminal_color_" .. i], "terminal_color_" .. i)
	end
end)

test("transparent removes the Normal background", function()
	require("dim-solarized").setup({ transparent = true })
	vim.cmd("colorscheme dim-solarized")
	assert(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil)
	require("dim-solarized").setup({ transparent = false })
end)

test("on_highlights overrides groups", function()
	require("dim-solarized").setup({
		on_highlights = function(c)
			return { CursorLine = { bg = c.red } }
		end,
	})
	vim.cmd("colorscheme dim-solarized")
	assert(vim.api.nvim_get_hl(0, { name = "CursorLine" }).bg == tonumber(palette.red:sub(2), 16))
end)

test("lualine theme exposes every mode", function()
	local theme = require("lualine.themes.dim-solarized")
	for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
		assert(theme[mode] and theme[mode].a and theme[mode].b and theme[mode].c, mode)
	end
end)

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
