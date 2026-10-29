-- Run with: nvim -l tests/render.lua
-- Read real ext_linegrid cells from a clean embedded Neovim. No UI/RPC package
-- dependencies: the parent uses Neovim's bundled MessagePack and libuv.
-- Optional: nvim -l tests/render.lua --real-lsp (installed lua-language-server).
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local real_lsp = arg[1] == "--real-lsp"
local uv = vim.uv or vim.loop
-- Isolate child state/logs and queries from the user's Neovim setup.
local state = vim.fn.tempname()
vim.fn.mkdir(state, "p")
local env = vim.fn.environ()
env.XDG_STATE_HOME, env.XDG_CACHE_HOME = state, state
env.NVIM_LOG_FILE = state .. "/nvim.log"
local child_env = {}
for key, value in pairs(env) do child_env[#child_env + 1] = key .. "=" .. value end
local input, output, errors = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
local responses, attrs, grid = {}, {}, {}
local default_fg, default_bg
local unpacker = vim.mpack.Unpacker()
local sequence, stopped, read_error, stderr = 0, false, nil, ""
local process = assert(uv.spawn(vim.v.progpath, {
	args = { "--embed", "--headless", "--clean", "-n" },
	cwd = root,
	env = child_env,
	stdio = { input, output, errors },
}, function()
	stopped = true
end))

local function receive(message)
	if message[1] == 1 then
		responses[message[2]] = message
	elseif message[1] == 2 and message[2] == "redraw" then
		for _, event in ipairs(message[3]) do
			for i = 2, #event do
				local arg = event[i]
				if event[1] == "default_colors_set" then
					default_fg, default_bg = arg[1], arg[2]
				elseif event[1] == "hl_attr_define" then
					attrs[arg[1]] = arg[2]
				elseif event[1] == "grid_line" and arg[1] == 1 then
					local row, col, hl = arg[2] + 1, arg[3] + 1, 0
					grid[row] = grid[row] or {}
					for _, cell in ipairs(arg[4]) do
						hl = cell[2] or hl
						for _ = 1, cell[3] or 1 do
							grid[row][col] = { text = cell[1], hl = hl }
							col = col + 1
						end
					end
				elseif event[1] == "grid_clear" and arg[1] == 1 then
					grid = {}
				end
			end
		end
	end
end
output:read_start(function(err, data)
	if err then read_error = err end
	if not data then return end
	local ok, failure = pcall(function()
		local pos = 1
		while pos <= #data do
			local message
			message, pos = unpacker(data, pos)
			if message then receive(message) end
		end
	end)
	if not ok then read_error = failure end
end)
errors:read_start(function(_, data)
	stderr = stderr .. (data or "")
end)

local function request(method, args)
	sequence = sequence + 1
	local id = sequence
	input:write(vim.mpack.encode({ 0, id, method, args or {} }))
	local answered = vim.wait(10000, function() return responses[id] ~= nil or stopped or read_error ~= nil end, 5)
	if not answered then
		local screen = {}
		for row = 1, 30 do
			local line = {}
			for col = 1, 100 do line[col] = grid[row] and grid[row][col] and grid[row][col].text or " " end
			screen[row] = table.concat(line)
		end
		error(method .. " timed out\n" .. table.concat(screen, "\n"))
	end
	assert(not read_error, tostring(read_error))
	local response = assert(responses[id], method .. ": child exited: " .. stderr)
	responses[id] = nil
	assert(response[3] == vim.NIL, vim.inspect(response[3]))
	return response[4]
end

local function lua(code, args)
	return request("nvim_exec_lua", { code, args or {} })
end

local function run()
	request("nvim_ui_attach", { 100, 30, { rgb = true, ext_linegrid = true } })
	lua("vim.opt.rtp:prepend(...)", { root })
	lua("_G.overlap_real_lsp = ...", { real_lsp })
	local cases = lua("return dofile(...)", { root .. "/tests/fixtures/overlap.lua" })
	-- A synchronous RPC after redraw is a barrier: prior UI notifications have
	-- been decoded before this response is observed.
	local function redraw()
		request("nvim_command", { "redraw!" })
		request("nvim_eval", { "1" })
	end
	local function keys(input_keys, mode)
		request("nvim_input", { input_keys })
		for _ = 1, 100 do
			if request("nvim_get_mode").mode == mode then return end
			vim.wait(20, function() return false end)
		end
		error("input did not enter mode " .. mode)
	end
	local function check(label, selected, semantic)
		redraw()
		for _, case in ipairs(cases) do
			local cell = assert(grid[case.row] and grid[case.row][case.col], case.name .. ": missing cell")
			local attr = assert(attrs[cell.hl], case.name .. ": missing RGB attributes")
			assert(cell.text == case.text, case.name .. ": unexpected screen position: " .. cell.text)
			local fg = selected and case.selected_fg or (semantic and case.lsp_fg or case.fg)
			local bg = selected and case.selected_bg or case.bg
			assert((attr.foreground or default_fg) == fg, string.format("%s %s fg: #%06x != #%06x", label, case.name, attr.foreground or default_fg or 0, fg))
			assert((attr.background or default_bg) == bg, string.format("%s %s bg: #%06x != #%06x", label, case.name, attr.background or default_bg or 0, bg))
			if case.italic then assert(attr.italic, case.name .. ": italic cue lost") end
			if case.name == "deprecated variable" and label ~= "Tree-sitter alone" then
				assert(attr.strikethrough, case.name .. ": deprecated cue lost")
			end
		end
		print("ok   " .. label .. " (" .. #cases .. " rendered positions)")
	end
	check("Tree-sitter alone", false)
	lua("return _G.start_overlap_lsp()")
	-- Wait for a real semantic token result and its redraw-time extmarks.
	local ready = false
	for _ = 1, 500 do
		redraw()
		ready = lua("return _G.overlap_lsp_ready()")
		if ready then break end
		vim.wait(20, function() return false end)
	end
	assert(ready, "semantic tokens were not applied")
	check("Tree-sitter + LSP semantic tokens", false, true)
	keys("<Esc>gg0VG", "V")
	check("linewise Visual over Tree-sitter + LSP", true, true)
	keys("<Esc>", "n")
	check("syntax colors restored after Visual", false, true)
	keys("gg0vG$", "v")
	check("characterwise Visual over Tree-sitter + LSP", true, true)
	keys("<Esc>", "n")
	lua("vim.o.virtualedit = 'block'")
	keys("gg0<C-v>G80|", string.char(22))
	check("blockwise Visual over Tree-sitter + LSP", true, true)
end

local ok, err = xpcall(run, debug.traceback)
input:write(vim.mpack.encode({ 2, "nvim_command", { "qa!" } }))
if not vim.wait(2000, function() return stopped end, 10) then process:kill("sigterm") end
for _, handle in ipairs({ input, output, errors, process }) do
	if not handle:is_closing() then handle:close() end
end
vim.fn.delete(state, "rf")
if not ok then
	io.stderr:write(tostring(err) .. "\n" .. stderr)
	os.exit(1)
end
print("all render tests passed")
