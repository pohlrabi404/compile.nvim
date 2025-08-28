local compile = {}
compile.term = {}

compile.term.state = {
	buf = -1,
	win = -1,
	channel = -1,
	last_line = 1,
	warning_list = {},
	warning_index = {},
	current_warning = 0,
}

local opts = {}

--- Initialize terminal module
function compile.term.setup(o)
	opts = o
end

--- Initialize terminal buffer and window
function compile.term.init()
	compile.term.state.buf = vim.api.nvim_create_buf(false, true)
	compile.term.state.win = vim.api.nvim_open_win(compile.term.state.buf, true, opts.term_win_opts)
	vim.cmd("term")
	compile.term.state.channel = vim.api.nvim_get_option_value("channel", { buf = compile.term.state.buf })
	vim.api.nvim_buf_set_name(compile.term.state.buf, opts.term_win_name)
end

--- Show terminal window
function compile.term.show()
	if vim.api.nvim_win_is_valid(compile.term.state.win) then
		return
	end

	if vim.api.nvim_buf_is_valid(compile.term.state.buf) then
		compile.term.state.win = vim.api.nvim_open_win(compile.term.state.buf, true, opts.term_win_opts)
	else
		compile.term.init()
	end
end

--- Hide terminal window
function compile.term.hide()
	if vim.api.nvim_win_is_valid(compile.term.state.win) then
		vim.api.nvim_win_hide(compile.term.state.win)
		compile.term.state.win = -1
	end
end

--- Jump to terminal window
function compile.term.jump_to()
	compile.term.show()
	vim.api.nvim_set_current_win(compile.term.state.win)
end

--- Destroy terminal resources
function compile.term.destroy()
	compile.term.hide()
	if vim.api.nvim_buf_is_valid(compile.term.state.buf) then
		vim.api.nvim_buf_delete(compile.term.state.buf, { force = true })
		compile.term.state.win = -1
		compile.term.state.buf = -1
		compile.term.state.channel = -1
		compile.term.state.last_line = 0
	end
end

--- Toggle terminal visibility
function compile.term.toggle()
	if vim.api.nvim_win_is_valid(compile.term.state.win) then
		compile.term.hide()
	else
		compile.term.show()
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

--- Get terminator based on OS
function compile.term.get_terminator()
	if is_windows_os() then
		return " \r"
	else
		return "\n"
	end
end

--- Send command to terminal
---
---@param cmd string Command to execute
function compile.term.send_cmd(cmd)
	local line_count = vim.api.nvim_buf_line_count(compile.term.state.buf)
	vim.api.nvim_win_set_cursor(compile.term.state.win, { line_count, 0 })
	local terminator = compile.term.get_terminator()
	vim.api.nvim_chan_send(compile.term.state.channel, cmd .. terminator)
end

--- Attach warning parsing to terminal buffer
function compile.term.attach_event()
	vim.api.nvim_buf_attach(compile.term.state.buf, false, {
		on_lines = function(_, _, _, first_line, _, last_line)
			if last_line <= compile.term.state.last_line then
				return
			end
			if first_line < compile.term.state.last_line then
				first_line = compile.term.state.last_line
			end
			local lines = vim.api.nvim_buf_get_lines(compile.term.state.buf, first_line, last_line, false)
			require("compile.highlight").process_lines(lines, first_line)
		end,
	})
end

return compile.term
