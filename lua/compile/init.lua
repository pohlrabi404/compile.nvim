local compile = {}

-- Load submodules
compile.term = require("compile.term")
compile.utils = require("compile.utils")
compile.highlight = require("compile.highlight")
compile.keymaps = require("compile.keymaps")
compile.opts = require("compile.opts")

--- Clears the terminal and reinitializes it.
--- This function effectively resets the compiler environment, removing any previous output and preparing it for a new compilation run.
function compile.clear()
	compile.utils.enter_wrapper(function()
		compile.term.destroy()
		compile.term.init()
	end)
end

--- Clears all highlight markers and the internal warning list.
function compile.clear_hl()
	compile.highlight.clear_hl_warning()
	local cursor_pos = vim.api.nvim_win_get_cursor(compile.term.state.win)
	compile.term.state.last_line = cursor_pos[1]
	vim.api.nvim_chan_send(compile.term.state.channel, "\n")
end

--- Compiles the project and captures errors in the terminal.
--- This is the core function for running the build process. It takes an optional command string, falls back to the default `make -k` command, and then initiates the compilation within the integrated terminal.
---@param cmd? string|function The command to execute. Defaults to `compile.opts.cmds.default`.
function compile.compile(cmd)
	cmd = cmd or compile.opts.cmds.default
	if type(cmd) == 'function' then
		cmd = cmd()
	end

	compile.utils.enter_wrapper(function()
		compile.term.destroy()
		if compile.highlight.has_warnings() then
			compile.highlight.clear_hl_warning()
		end
		compile.term.show()

		compile.term.attach_event()
		compile.term.send_cmd(cmd)
	end)
end

--- Destroys the terminal buffer and window.
function compile.destroy()
	compile.utils.enter_wrapper(function()
		compile.term.destroy()
		compile.highlight.clear_hl_warning()
	end)
end

--- Navigates to the current error location in the code.
function compile.goto_error()
	local c_error = compile.highlight.get_current_warning()
	if not c_error then
		return
	end

	local win = compile.utils.get_normal_win()
	vim.cmd("edit " .. c_error.file.val)
	vim.api.nvim_win_set_cursor(win, { c_error.row.val, c_error.col.val })
	vim.api.nvim_win_set_cursor(compile.term.state.win, { c_error.file.pos[1][1] + 1, c_error.file.pos[1][2] })

	if compile.opts.highlight_under_cursor.enabled then
		vim.hl.range(
			compile.term.state.buf,
			compile.highlight.ns,
			"Cursor",
			c_error.file.pos[1],
			c_error.file.pos[2],
			{ priority = 2000, timeout = compile.opts.highlight_under_cursor.timeout_term }
		)

		vim.hl.range(
			vim.api.nvim_win_get_buf(win),
			compile.highlight.ns,
			"Cursor",
			{ c_error.row.val - 1, 0 },
			{ c_error.row.val - 1, -1 },
			{ priority = 2000, timeout = compile.opts.highlight_under_cursor.timeout_normal }
		)
	end
end

--- Navigates to the error nearest to the cursor's current position.
--- This function searches the list of errors for the one that appears immediately before the cursor's current line in the editor, and then jumps to it.
function compile.nearest_error()
	if not compile.highlight.has_warnings() then
		return
	end
	compile.utils.enter_wrapper(function()
		compile.term.show()
		--- find the nearest error
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local warning_row_list = {}
		for _, file in ipairs(compile.highlight.state.warning_index) do
			local warning_list = compile.highlight.state.warning_list
			local row = warning_list[file].file.pos[1][1]
			table.insert(warning_row_list, row)
		end

		local warning_index = compile.utils.binary_search(warning_row_list, cursor_pos[1] - 1)
		compile.highlight.state.current_warning = warning_index
		compile.goto_error()
	end)
end

--- Navigates to the next error in the list.
function compile.next_error()
	if not compile.highlight.has_warnings() then
		return
	end
	compile.utils.enter_wrapper(function()
		compile.term.show()
		compile.highlight.next_warning()
		compile.goto_error()
	end)
end

--- Navigates to the previous error in the list.
function compile.prev_error()
	if not compile.highlight.has_warnings() then
		return
	end
	compile.utils.enter_wrapper(function()
		compile.term.show()
		compile.highlight.prev_warning()
		compile.goto_error()
	end)
end

--- Navigates to the last error in the list.
function compile.last_error()
	if not compile.highlight.has_warnings() then
		return
	end
	compile.utils.enter_wrapper(function()
		compile.term.show()
		compile.highlight.last_warning()
		compile.goto_error()
	end)
end

--- Navigates to the first error in the list.
function compile.first_error()
	if not compile.highlight.has_warnings() then
		return
	end
	compile.utils.enter_wrapper(function()
		compile.term.show()
		compile.highlight.first_warning()
		compile.goto_error()
	end)
end

--- Sets up the plugin with user configuration.
---
--- This is the main entry point for configuring the plugin. It merges user-provided options with the defaults, performs necessary calculations for window sizes, and initializes the submodules.
---
---@param opts table|nil A table of user options to override the defaults.
function compile.setup(opts)
	opts = opts or {}
	compile.opts = vim.tbl_deep_extend("force", compile.opts, opts)

	---Make sure to respect float configuration
	if compile.opts.term_win_opts.relative ~= nil then
		compile.opts.term_win_opts.split = nil
	end

	-- Convert relative heights to absolute
	if compile.opts.term_win_opts.height <= 1 then
		compile.opts.term_win_opts.height = math.floor(vim.o.lines * compile.opts.term_win_opts.height)
	end
	if compile.opts.normal_win_opts.height <= 1 then
		compile.opts.normal_win_opts.height = math.floor(vim.o.lines * compile.opts.normal_win_opts.height)
	end
	if compile.opts.term_win_opts.width <= 1 then
		compile.opts.term_win_opts.width = math.floor(vim.o.columns * compile.opts.term_win_opts.width)
	end
	if compile.opts.normal_win_opts.width <= 1 then
		compile.opts.normal_win_opts.width = math.floor(vim.o.columns * compile.opts.normal_win_opts.width)
	end

	-- Initialize submodules
	compile.term.setup(compile.opts)
	compile.highlight.setup(compile.opts)
	compile.keymaps.setup(compile.opts)
end

return compile
