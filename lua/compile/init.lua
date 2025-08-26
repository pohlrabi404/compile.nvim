local M = {}

-- Load submodules
M.term = require("compile.term")
M.utils = require("compile.utils")
M.highlight = require("compile.highlight")
M.keymaps = require("compile.keymaps")

-- Default configuration
M.opts = {
	term_win_name = "CompileTerm",
	term_win_opts = {
		split = "below",
		height = 0.4,
		width = 1,
	},

	normal_win_opts = {
		split = "above",
		height = 0.6,
		width = 1,
	},

	enter = false,

	highlight_under_cursor = {
		enabled = true,
		timeout_term = 500,
		timeout_normal = 200,
	},

	cmds = {
		default = "make -k",
	},

	patterns = {
		rust = { "(%S+%.%a+):(%d+):(%d+)", "123" },
		csharp = { "(%S+%.%a+)%((%d+),(%d+)%)", "123" },
		Makefile = { "%[(%S+):(%d+):.+%]", "12" },
	},

	colors = {
		file = "WarningMsg",
		row = "CursorLineNr",
		col = "CursorLineNr",
	},

	keys = {
		global = {
			["n"] = {
				["<localleader>cc"] = "require('compile').compile()",
				["<localleader>cn"] = "require('compile').next_error()",
				["<localleader>cp"] = "require('compile').prev_error()",
				["<localleader>cl"] = "require('compile').last_error()",
				["<localleader>cf"] = "require('compile').first_error()",
				["<localleader>cj"] = "require('compile.term').jump_to()",
			},
		},
		term = {
			global = {
				["n"] = {
					["<localleader>cr"] = "require('compile').clear()",
					["<localleader>cq"] = "require('compile').destroy()",
				},
			},
			buffer = {
				["n"] = {
					["r"] = "require('compile').clear()",
					["c"] = "require('compile').compile()",
					["q"] = "require('compile').destroy()",
					["n"] = "require('compile').next_error()",
					["p"] = "require('compile').prev_error()",
					["0"] = "require('compile').first_error()",
					["$"] = "require('compile').last_error()",
					["<Cr>"] = "require('compile').nearest_error()",
				},
				["t"] = {
					["<CR>"] = "require('compile').clear_hl()",
					["<C-j>"] = "require('compile.term').send_cmd('')",
				},
			},
		},
	},
}

---Clear terminal and reinitialize
function M.clear()
	M.utils.enter_wrapper(function()
		M.term.destroy()
		M.term.init()
	end)
end

---Clear highlight and warning_list
function M.clear_hl()
	M.highlight.clear_hl_warning()
	local cursor_pos = vim.api.nvim_win_get_cursor(M.term.state.win)
	M.term.state.last_line = cursor_pos[1]
	-- M.term.attach_event()
	vim.api.nvim_chan_send(M.term.state.channel, "\n")
end

---Compile project and capture errors
function M.compile(cmd)
	cmd = cmd or M.opts.cmds.default
	M.utils.enter_wrapper(function()
		M.term.destroy()
		if M.highlight.has_warnings() then
			M.highlight.clear_hl_warning()
		end
		M.term.show()
		M.term.attach_event()
		M.term.send_cmd(cmd)
	end)
end

---Destroy terminal buffer and window
function M.destroy()
	M.utils.enter_wrapper(function()
		M.term.destroy()
		M.highlight.clear_hl_warning()
	end)
end

---Navigate to current error location
function M.goto_error()
	local c_error = M.highlight.get_current_warning()
	if not c_error then
		return
	end

	local win = M.utils.get_normal_win()
	vim.cmd("edit " .. c_error.file.val)
	vim.api.nvim_win_set_cursor(win, { c_error.row.val, c_error.col.val })
	vim.api.nvim_win_set_cursor(M.term.state.win, { c_error.file.pos[1][1] + 1, c_error.file.pos[1][2] })

	if M.opts.highlight_under_cursor.enabled then
		vim.hl.range(
			M.term.state.buf,
			M.highlight.ns,
			"Cursor",
			c_error.file.pos[1],
			c_error.file.pos[2],
			{ priority = 2000, timeout = M.opts.highlight_under_cursor.timeout_term }
		)

		vim.hl.range(
			vim.api.nvim_win_get_buf(win),
			M.highlight.ns,
			"Cursor",
			{ c_error.row.val - 1, 0 },
			{ c_error.row.val - 1, -1 },
			{ priority = 2000, timeout = M.opts.highlight_under_cursor.timeout_normal }
		)
	end
end

---Navigate to error nearest before the cursor
function M.nearest_error()
	if not M.highlight.has_warnings() then
		return
	end
	M.utils.enter_wrapper(function()
		M.term.show()
		--- find the nearest error
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local warning_row_list = {}
		for _, file in ipairs(M.highlight.state.warning_index) do
			local warning_list = M.highlight.state.warning_list
			local row = warning_list[file].file.pos[1][1]
			table.insert(warning_row_list, row)
		end

		local warning_index = M.utils.binary_search(warning_row_list, cursor_pos[1] - 1)
		M.highlight.state.current_warning = warning_index
		M.goto_error()
	end)
end

---Navigate to next error
function M.next_error()
	if not M.highlight.has_warnings() then
		return
	end
	M.utils.enter_wrapper(function()
		M.term.show()
		M.highlight.next_warning()
		M.goto_error()
	end)
end

---Navigate to previous error
function M.prev_error()
	if not M.highlight.has_warnings() then
		return
	end
	M.utils.enter_wrapper(function()
		M.term.show()
		M.highlight.prev_warning()
		M.goto_error()
	end)
end

---Navigate to last error
function M.last_error()
	if not M.highlight.has_warnings() then
		return
	end
	M.utils.enter_wrapper(function()
		M.term.show()
		M.highlight.last_warning()
		M.goto_error()
	end)
end

---Navigate to first error
function M.first_error()
	if not M.highlight.has_warnings() then
		return
	end
	M.utils.enter_wrapper(function()
		M.term.show()
		M.highlight.first_warning()
		M.goto_error()
	end)
end

---Setup plugin with user configuration
function M.setup(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	---Make sure to respect float configuration
	if M.opts.term_win_opts.relative ~= nil then
		M.opts.term_win_opts.split = nil
	end

	-- Convert relative heights to absolute
	if M.opts.term_win_opts.height <= 1 then
		M.opts.term_win_opts.height = math.floor(vim.o.lines * M.opts.term_win_opts.height)
	end
	if M.opts.normal_win_opts.height <= 1 then
		M.opts.normal_win_opts.height = math.floor(vim.o.lines * M.opts.normal_win_opts.height)
	end
	if M.opts.term_win_opts.width <= 1 then
		M.opts.term_win_opts.width = math.floor(vim.o.columns * M.opts.term_win_opts.width)
	end
	if M.opts.normal_win_opts.width <= 1 then
		M.opts.normal_win_opts.width = math.floor(vim.o.columns * M.opts.normal_win_opts.width)
	end

	-- Initialize submodules
	M.term.setup(M.opts)
	M.highlight.setup(M.opts)
	M.keymaps.setup(M.opts)
end

return M
