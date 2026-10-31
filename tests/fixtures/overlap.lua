-- Executed inside the embedded Neovim controlled by tests/render.lua.
local root = vim.fn.getcwd()
local real_lsp = _G.overlap_real_lsp
-- Server status notifications are outside this buffer-color test. Keep them
-- from opening a hit-enter prompt while RPC is driving the embedded UI;
-- still fail if the client reports an error.
local client_errors = {}
vim.notify = function(message, level)
	if level and level >= vim.log.levels.ERROR then
		client_errors[#client_errors + 1] = tostring(message)
	end
end
vim.o.termguicolors = true
vim.o.showmode = false
vim.o.ruler = false
vim.o.laststatus = 0
vim.o.number = false
vim.o.relativenumber = false
vim.o.signcolumn = "no"
vim.o.foldcolumn = "0"
vim.o.cursorline = false
vim.o.wrap = false
vim.o.swapfile = false
vim.o.hlsearch = false
vim.cmd("colorscheme dim-solarized")
local c = require("dim-solarized").colors()
local lines = {
	"-- quiet comment",
	'local label = "Recent notes"',
	"local total = 2",
	"local function greet(name)",
	"  return label .. name",
	"end",
	"greet(label)",
	"local opts = { title = label }",
	"local kind = label",
	"print(label)",
	"local old = label",
	"local self = label",
	"local Kind = {}",
	"local enabled = true",
	"local LIMIT = 10",
	"local ratio = 1.5",
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_buf_set_name(0, root .. "/tests/samples/overlap-fixture.lua")
vim.bo.filetype = "lua"
vim.treesitter.start(0, "lua")
local parser = assert(vim.treesitter.get_parser(0, "lua"))
parser:parse()

local cases, tokens = {}, {}
local types = { "variable", "parameter", "property", "function", "comment", "string", "number", "class" }
local modifiers = { "readonly", "defaultLibrary", "deprecated" }
local function add(name, row, needle, color, token_type, mods, styles)
	local start = assert(lines[row]:find(needle, 1, true))
	local case = {
		name = name, row = row, col = start, text = needle:sub(1, 1),
		fg = tonumber(c[color]:sub(2), 16), bg = tonumber(c.bg:sub(2), 16),
		selected_fg = tonumber(c.fg_bright:sub(2), 16), selected_bg = tonumber(c.bg_sel:sub(2), 16),
	}
	for key, value in pairs(styles or {}) do case[key] = value end
	cases[#cases + 1] = case
	if token_type then
		local mask = 0
		for _, mod in ipairs(mods or {}) do
			local index = vim.fn.index(modifiers, mod)
			assert(index >= 0, "unknown modifier: " .. mod)
			mask = mask + 2 ^ index
		end
		local index = vim.fn.index(types, token_type)
		assert(index >= 0, "unknown token type: " .. token_type)
		tokens[#tokens + 1] = { row - 1, start - 1, #needle, index, mask }
	end
end
add("comment", 1, "quiet", "comment", "comment", nil, { italic = true })
add("readonly variable", 2, "label", "fg", "variable", { "readonly" })
add("string", 2, "Recent", "cyan", "string")
add("number", 3, "2", "cyan", "number")
add("function declaration", 4, "greet", "blue", "function")
add("parameter", 4, "name", "fg", "parameter")
add("keyword", 5, "return", "green")
add("variable", 5, "label", "fg", "variable")
add("generic variable on callable", 7, "greet", "blue", "variable", { "readonly" })
add("delimiter", 7, "(", "fg_dim")
add("readonly property", 8, "title", "fg", "property", { "readonly" })
add("ordinary variable", 9, "kind", "fg", "variable")
add("builtin function", 10, "print", "blue", "function", { "defaultLibrary" })
add(real_lsp and "ordinary local" or "deprecated variable", 11, "old", "fg", "variable", { "deprecated" })
add("builtin variable", 12, "self", "fg", "variable", { "defaultLibrary" }, { italic = true })
-- Tree-sitter sees a variable; LSP supplies a more specific type role.
add("semantic class", 13, "Kind", "fg", "class", nil, real_lsp and {} or { lsp_fg = tonumber(c.yellow:sub(2), 16) })

add("boolean", 14, "true", "cyan")
add("named constant", 15, "LIMIT", "cyan")
add("float", 16, "1.5", "cyan", "number")

table.sort(tokens, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
local data, prev_row, prev_col = {}, 0, 0
for _, token in ipairs(tokens) do
	vim.list_extend(data, { token[1] - prev_row, token[1] == prev_row and token[2] - prev_col or token[2], token[3], token[4], token[5] })
	prev_row, prev_col = token[1], token[2]
end

local client_id
function _G.start_overlap_lsp()
	local log_dir = vim.env.XDG_STATE_HOME
	client_id = assert(vim.lsp.start({
		name = "dim-solarized-render-fixture",
		cmd = real_lsp and {
			"lua-language-server", "--logpath=" .. log_dir .. "/luals-log", "--metapath=" .. log_dir .. "/luals-meta",
		} or { "python3", root .. "/tests/fixtures/semantic_server.py" },
		root_dir = root,
		init_options = not real_lsp and { legend = { tokenTypes = types, tokenModifiers = modifiers }, data = data } or nil,
		settings = real_lsp and { Lua = {
			semantic = { enable = true, variable = true },
			workspace = { checkThirdParty = false, maxPreload = 5000, library = {} },
			diagnostics = { enable = false }, hint = { enable = false },
		} } or nil,
	}))
	return client_id
end
function _G.overlap_lsp_ready()
	assert(#client_errors == 0, table.concat(client_errors, "\n"))
	if real_lsp then
		for _, position in ipairs({ { 3, 15 }, { 3, 21 }, { 7, 15 } }) do
			local result = vim.lsp.semantic_tokens.get_at_pos(0, position[1], position[2])
			if not result or #result == 0 then return false end
		end
		return true
	end
	for _, token in ipairs(tokens) do
		local result = vim.lsp.semantic_tokens.get_at_pos(0, token[1], token[2])
		if not result or #result == 0 then return false end
		assert(result[1].type == types[token[4] + 1], "unexpected semantic token type")
	end
	return true
end
return cases
