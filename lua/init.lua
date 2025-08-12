local M = {}

-- merge user options and default options
M.opts = {
	---@type vim.api.keyset.win_config
	win_opts = {
		split = "below",
		height = math.floor(vim.o.lines * 30 / 100),
	},

	---@type string
	default_cmd = "cargo check",

	---@type string[]
	patterns = {
		-- rust, cpp
		"(%S+):(%d+):(%d+)",
	},
}
M.setup = function(user_opts, _)
	user_opts = user_opts or {}
	M.opts = vim.tbl_deep_extend("force", user_opts, M.opts)
end

local location_info = {}
local location_lookup = {}

local state = {
	win = -1,
	buf = -1,
	current_error_pos = {},
	current_error_index = 0,
	compile_cmd_flag = false,
}

-- handle highlighting
local ns = vim.api.nvim_create_namespace("CompileNvim")

local function find_all_location(str, line_num, on_complete)
	local pattern_index = 1

	local function process_next_pattern(index)
		if index > #M.opts.patterns then
			if on_complete then
				on_complete()
			end
			return
		end

		local pattern = M.opts.patterns[pattern_index]
		local start = 1

		-- Inner loop to find all matches for the current pattern
		while true do
			local s, e = string.find(str, pattern, start)
			if not s then
				break
			end
			local found_str = string.sub(str, s, e)

			if location_info[found_str] == nil then
				location_info[found_str] = {
					start_pos = { line_num, s - 1 },
					end_pos = { line_num, e },
					pattern = pattern,
				}
				table.insert(location_lookup, found_str)
			else
				break
			end

			start = e + 1
		end

		-- Schedule the next pattern to be processed on the next event loop tick
		vim.schedule(function()
			process_next_pattern(index + 1)
		end)
	end

	process_next_pattern(pattern_index)
end

-- Handling highlighting found pattern and extract location info
local function process_new_lines(first_line, last_line)
	local lines = vim.api.nvim_buf_get_lines(state.buf, first_line, last_line - 1, false)

	if lines == nil then
		return
	end

	for i = 1, #lines do
		find_all_location(lines[i], first_line + i - 1, function()
			for str, location in pairs(location_info) do
				-- highlight pattern
				vim.schedule(function()
					vim.hl.range(state.buf, ns, "StderrMsg", location.start_pos, location.end_pos, {
						priority = 1000,
					})
				end)
				-- find location info from pattern
				local path, row, col = string.match(str, location.pattern)
				if path ~= nil then
					location.path = path
					location.pos = { tonumber(row), tonumber(col) }
				end
			end
		end)
	end
end

-- attach to term buffer
local function setup_auto_highlight()
	vim.api.nvim_buf_attach(state.buf, false, {
		on_lines = function(_, _, changedTick, first_line, last_line, _)
			vim.schedule(function()
				if changedTick == nil then
					return
				end
				process_new_lines(first_line, last_line)
				-- set cursor to the end
				local line_count = vim.api.nvim_buf_line_count(state.buf)
				vim.api.nvim_win_set_cursor(state.win, { line_count, 0 })
			end)
		end,
	})
end

-- reset highlight and location data before sending new command
local function reset()
	state.current_error_index = 0
	location_info = {}
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
end

function M.reset()
	if vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
		vim.api.nvim_buf_delete(state.buf, {
			force = true,
			unload = true,
		})
	end
	state.buf = -1
	state.win = -1
	state.current_error_index = 0
	location_info = {}
end

-- handle openning terminal
local function open_terminal()
	local buf = nil
	if vim.api.nvim_buf_is_valid(state.buf) then
		buf = state.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
		state.buf = buf
	end

	if not vim.api.nvim_win_is_valid(state.win) then
		state.win = vim.api.nvim_open_win(state.buf, true, M.opts.win_opts)
		if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "terminal" then
			vim.cmd.terminal()
		end
		vim.cmd("wincmd p")
	end
end

local function send_cmd()
	local channel_id = vim.api.nvim_get_option_value("channel", { buf = state.buf })
	-- clear before sending data
	vim.api.nvim_chan_send(channel_id, "clear\n")
	vim.api.nvim_chan_send(channel_id, M.opts.default_cmd .. "\n")
end

local function edit_file()
	vim.cmd("edit " .. state.current_error_file.path)
	vim.api.nvim_win_set_cursor(0, state.current_error_file.pos)

	if state.win == vim.api.nvim_get_current_win() then
		state.win = vim.api.nvim_open_win(state.buf, false, M.opts.win_opts)
	end

	if not vim.api.nvim_win_is_valid(state.win) then
		open_terminal()
	end

	vim.api.nvim_win_set_cursor(state.win, state.current_error_file.start_pos)
	vim.hl.range(
		state.buf,
		ns,
		"Search",
		state.current_error_file.start_pos,
		state.current_error_file.end_pos,
		{ timeout = 500, priority = 2000 }
	)
end

function M.next_error()
	if state.current_error_index == #location_lookup then
		state.current_error_index = 1
		local location = location_lookup[1]
		state.current_error_file = location_info[location]
	else
		state.current_error_index = state.current_error_index + 1
		local location = location_lookup[state.current_error_index]
		state.current_error_file = location_info[location]
	end
	edit_file()
end

function M.prev_error()
	if state.current_error_index <= 1 then
		state.current_error_index = #location_lookup
		local location = location_lookup[#location_lookup]
		state.current_error_file = location_info[location]
	else
		state.current_error_index = state.current_error_index - 1
		local location = location_lookup[state.current_error_index]
		state.current_error_file = location_info[location]
	end
	edit_file()
end

function M.set_cmd()
	vim.ui.input({ prompt = "Enter compile command: ", default = M.opts.default_cmd }, function(input)
		if input then
			M.opts.default_cmd = input
			state.compile_cmd_flag = true
		else
			print("Cancelled")
		end
	end)
end

-- main compile command
-- toggle terminal
-- -> attach set highlight + get location info
-- -> send command
-- -> populate function to navigate location info
function M.make()
	if not state.compile_cmd_flag then
		vim.ui.input({ prompt = "Enter compile command: ", default = M.opts.default_cmd }, function(input)
			if input then
				M.opts.default_cmd = input
				state.compile_cmd_flag = true
			else
				print("Cancelled")
				return
			end
		end)
	end
	open_terminal()
	reset()
	setup_auto_highlight()
	send_cmd()
end

vim.keymap.set("n", "<C-c><C-r>", M.reset)
vim.keymap.set("n", "<C-c><C-c>", M.make)
vim.keymap.set("n", "<C-c>c", M.set_cmd)
vim.keymap.set("n", "<C-c><C-n>", M.next_error)
vim.keymap.set("n", "<C-c><C-p>", M.prev_error)

return M
