---@meta
---@class TermModule
---@field state TermState
---@field setup fun(opts: table)
---@field init fun()
---@field show fun()
---@field hide fun()
---@field destroy fun()
---@field toggle fun()
---@field send_cmd fun(cmd: string)
---@field attach_event fun()

---@class TermState
---@field buf integer Terminal buffer ID
---@field win integer Terminal window ID
---@field channel integer Terminal channel ID
---@field warning_list table Parsed warning data
---@field warning_index table Warning index list
---@field current_warning integer Current warning index
local M = {}

M.state = {
	buf = -1,
	win = -1,
	channel = -1,
	last_line = 1,
	warning_list = {},
	warning_index = {},
	current_warning = 0,
}

local opts = nil

---Initialize terminal module
---@param o table Configuration options
function M.setup(o)
	opts = o
end

---Initialize terminal buffer and window
function M.init()
	M.state.buf = vim.api.nvim_create_buf(false, true)
	M.state.win = vim.api.nvim_open_win(M.state.buf, true, opts.term_win_opts)
	vim.cmd("term")
	M.state.channel = vim.api.nvim_get_option_value("channel", { buf = M.state.buf })
	vim.api.nvim_buf_set_name(M.state.buf, opts.term_win_name)
end

---Show terminal window
function M.show()
	if vim.api.nvim_win_is_valid(M.state.win) then
		return
	end

	if vim.api.nvim_buf_is_valid(M.state.buf) then
		M.state.win = vim.api.nvim_open_win(M.state.buf, true, opts.term_win_opts)
	else
		M.init()
	end
end

---Hide terminal window
function M.hide()
	if vim.api.nvim_win_is_valid(M.state.win) then
		vim.api.nvim_win_hide(M.state.win)
		M.state.win = -1
	end
end

---Destroy terminal resources
function M.destroy()
	M.hide()
	if vim.api.nvim_buf_is_valid(M.state.buf) then
		vim.api.nvim_buf_delete(M.state.buf, { force = true })
		M.state.win = -1
		M.state.buf = -1
		M.state.channel = -1
		M.state.last_line = 0
	end
end

---Toggle terminal visibility
function M.toggle()
	if vim.api.nvim_win_is_valid(M.state.win) then
		M.hide()
	else
		M.show()
	end
end

local function is_windows_os()
	local sys = vim.loop.os_uname()
	if sys.sysname == "Window_NT" then
		return true
	else -- Linux/Macs/BSD should all have \n as terminator
		return false
	end
end

function M.get_terminator()
	if is_windows_os() then
		return " \r"
	else
		return "\n"
	end
end

---Send command to terminal
---@param cmd string Command to execute
function M.send_cmd(cmd)
	local line_count = vim.api.nvim_buf_line_count(M.state.buf)
	vim.api.nvim_win_set_cursor(M.state.win, { line_count, 0 })
	local terminator = M.get_terminator()
	vim.api.nvim_chan_send(M.state.channel, cmd .. terminator)
end

---Attach warning parsing to terminal buffer
function M.attach_event()
	vim.api.nvim_buf_attach(M.state.buf, false, {
		on_lines = function(_, _, _, first_line, _, last_line)
			if last_line <= M.state.last_line then
				return
			end
			if first_line < M.state.last_line then
				first_line = M.state.last_line
			end
			local lines = vim.api.nvim_buf_get_lines(M.state.buf, first_line, last_line, false)
			require("compile.highlight").process_lines(lines, first_line)
		end,
	})
end

return M
