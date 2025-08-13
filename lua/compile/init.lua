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

---@class Location
---@field start_pos [integer, integer]
---@field end_pos [integer, integer]
---@field pattern string
---@field path string
---@field pos [integer, integer]

---@class Locations
---@type table<string, Location>
local location_info = {}

---@class Lookup
---@type table<string>
local location_lookup = {}

local state = {
	win = -1,
	buf = -1,
	current_error_pos = nil,
	current_error_index = 0,
	compile_cmd_flag = false,
	initialized_flag = false,
}

-- handle highlighting
local ns = vim.api.nvim_create_namespace("CompileNvim")

local function find_all_location(str, line_num, on_complete)
	for _, pattern in ipairs(M.opts.patterns) do
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
					path = "",
					pos = { 0, 0 },
				}
				table.insert(location_lookup, found_str)
			end

			start = e + 1
		end
	end
	on_complete()
end

-- Handling highlighting found pattern and extract location info
local function process_new_lines(first_line, last_line)
	local lines = vim.api.nvim_buf_get_lines(state.buf, first_line, last_line, false)

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

-- reset highlight and location data before sending new command
local function reset()
	state.current_error_file = nil
	state.current_error_index = 0
	location_info = {}
	location_lookup = {}
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
end

-- attach to term buffer
local function setup_auto_highlight()
	vim.api.nvim_buf_attach(state.buf, false, {
		on_lines = function(_, _, changedTick, first_line, _, last_line_new, _)
			if changedTick == nil then
				return
			end
			process_new_lines(first_line, last_line_new)
			-- set cursor to the end
			local line_count = vim.api.nvim_buf_line_count(state.buf)
			vim.api.nvim_win_set_cursor(state.win, { line_count, 0 })
		end,
		on_detach = function()
			reset()
		end,
	})
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

local function open_win(path, pos, go_into)
	local current_win_id = vim.api.nvim_get_current_win()
	if current_win_id == state.win then
		-- find other window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if win ~= state.win then
				vim.api.nvim_set_current_win(win)
				vim.cmd("edit " .. path)
				vim.api.nvim_win_set_cursor(win, pos)
				if not go_into then
					vim.api.nvim_set_current_win(current_win_id)
				end
				return
			end
		end
		-- no other window
		local buf = vim.api.nvim_create_buf(true, false)
		local win = vim.api.nvim_open_win(buf, true, M.opts.win_opts)
		vim.cmd("edit " .. path)
		vim.api.nvim_win_set_cursor(win, pos)
		if not go_into then
			vim.api.nvim_set_current_win(current_win_id)
		end
	else
		-- use this window
		vim.cmd("edit " .. path)
		vim.api.nvim_win_set_cursor(0, pos)

		-- open terminal back if it's closed
		if not vim.api.nvim_win_is_valid(state.win) then
			open_terminal()
		end
	end
end

local function edit_file(go_into)
	open_win(state.current_error_file.path, state.current_error_file.pos, go_into)

	local pos = { state.current_error_file.start_pos[1] + 1, state.current_error_file.start_pos[2] }
	vim.api.nvim_win_set_cursor(state.win, pos)
	vim.hl.range(
		state.buf,
		ns,
		"Search",
		state.current_error_file.start_pos,
		state.current_error_file.end_pos,
		{ timeout = 500, priority = 2000 }
	)
end

function M.next_error(go_into)
	if go_into == nil then
		go_into = true
	end
	-- no error case
	if #location_lookup < 1 then
		print("No Warning")
		return
	end
	if state.current_error_index == #location_lookup then
		state.current_error_index = 1
		local location = location_lookup[1]
		state.current_error_file = location_info[location]
	else
		state.current_error_index = state.current_error_index + 1
		local location = location_lookup[state.current_error_index]
		state.current_error_file = location_info[location]
	end
	edit_file(go_into)
end

function M.prev_error(go_into)
	if go_into == nil then
		go_into = true
	end
	-- no error case
	if #location_lookup < 1 then
		print("No Warning")
		return
	end
	if state.current_error_index <= 1 then
		state.current_error_index = #location_lookup
		local location = location_lookup[#location_lookup]
		state.current_error_file = location_info[location]
	else
		state.current_error_index = state.current_error_index - 1
		local location = location_lookup[state.current_error_index]
		state.current_error_file = location_info[location]
	end
	edit_file(go_into)
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

function M.terminate()
	local channel_id = vim.api.nvim_get_option_value("channel", { buf = state.buf })
	vim.api.nvim_chan_send(channel_id, "\x03")
end

function M.go_to_error()
	local cursor_row, cursor_col = vim.api.nvim_win_get_cursor(state.win)[1], vim.api.nvim_win_get_cursor(state.win)[2]
	cursor_row = cursor_row - 1
	for _, location in pairs(location_info) do
		local after_start = (cursor_row > location.start_pos[1])
			or (cursor_row == location.start_pos[1] and cursor_col >= location.start_pos[2])
		local before_end = (cursor_row < location.end_pos[1])
			or (cursor_row == location.start_pos[1] and cursor_col <= location.end_pos[2])

		if after_start and before_end then
			open_win(location.path, location.pos)
			return
		end
	end
end

-- main compile command
-- toggle terminal
-- -> attach set highlight + get location info
-- -> send command
-- -> populate function to navigate location info
function M.make()
	-- get compile command
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
		-- also set keymap once
	end
	-- terminate before running new commands
	if state.initialized_flag then
		M.terminate()
	end
	open_terminal()
	reset()
	setup_auto_highlight()
	send_cmd()
end

vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		if buf == state.buf then
			vim.keymap.set("n", "<CR>", M.go_to_error, { buffer = state.buf })
			vim.keymap.set("n", "n", function()
				M.next_error(false)
			end, { buffer = state.buf })
			vim.keymap.set("n", "p", function()
				M.prev_error(false)
			end, { buffer = state.buf })
		end
	end,
})
vim.api.nvim_create_autocmd("BufLeave", {
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		if buf == state.buf then
			vim.keymap.del("n", "<CR>", { buffer = state.buf })
			vim.keymap.del("n", "n", { buffer = state.buf })
			vim.keymap.del("n", "p", { buffer = state.buf })
		end
	end,
})

vim.keymap.set("n", "<leader>cc", M.make)
vim.keymap.set("n", "<leader>ct", M.terminate)
vim.keymap.set("n", "<leader>cs", M.set_cmd)
vim.keymap.set("n", "<leader>cn", M.next_error)
vim.keymap.set("n", "<leader>cp", M.prev_error)

return M
