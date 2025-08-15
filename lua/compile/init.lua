---@meta
---@class Compile
---@field opts CompileConfig
---@field term TermModule
---@field utils UtilsModule
---@field highlight HighlightModule
---@field keymaps KeymapsModule

---@class CompileConfig
---@field term_win_opts table Terminal window options
---@field normal_win_opts table Normal window options
---@field enter boolean Keep focus in terminal after commands
---@field highlight_under_cursor {enabled: boolean, timeout: number}
---@field cmds {default: string} Compilation commands
---@field patterns table Error pattern definitions
---@field colors {file: string, row: string, col: string} Highlight groups
---@field keys CompileKeymaps Keybinding configuration

---@class CompileKeymaps
---@field global table Global keymaps
---@field term {global: table, buffer: table} Terminal-specific keymaps

local M = {}

-- Load submodules
M.term = require("compile.term")
M.utils = require("compile.utils")
M.highlight = require("compile.highlight")
M.keymaps = require("compile.keymaps")

-- Default configuration
M.opts = {
	---@type vim.api.keyset.win_config
	term_win_opts = {
		split = "below",
		height = 0.4,
	},

	---@type vim.api.keyset.win_config
	normal_win_opts = {
		split = "above",
		height = 0.6,
	},

	---@type boolean
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
		rust = { "(%S+):(%d+):(%d+)", "123" },
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
				["<localleader>cc"] = "compile",
				["<localleader>cn"] = "next_error",
				["<localleader>cp"] = "prev_error",
				["<localleader>cl"] = "last_error",
				["<localleader>cf"] = "first_error",
			},
		},
		term = {
			global = {
				["n"] = {
					["<localleader>cr"] = "clear",
					["<localleader>cq"] = "destroy",
				},
			},
			buffer = {
				["n"] = {
					["r"] = "clear",
					["c"] = "compile",
					["q"] = "destroy",
					["n"] = "next_error",
					["p"] = "prev_error",
					["0"] = "first_error",
					["$"] = "last_error",
					["d"] = "debug",
					["<Cr>"] = "nearest_error",
				},
				["t"] = {
					["<Cr>"] = "clear_hl",
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
	vim.api.nvim_chan_send(M.term.state.channel, "\n")
end

---Compile project and capture errors
function M.compile()
	M.utils.enter_wrapper(function()
		M.term.destroy()
		if M.highlight.has_warnings() then
			M.highlight.clear_hl_warning()
		end
		M.term.show()
		M.term.attach_event()
		M.term.send_cmd(M.opts.cmds.default)
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

---Debug: Print warning list
function M.debug()
	M.highlight.clear_hl_warning()
end

---Setup plugin with user configuration
---@param opts CompileConfig
function M.setup(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	-- Convert relative heights to absolute
	if M.opts.term_win_opts.height < 1 then
		M.opts.term_win_opts.height = math.floor(vim.o.lines * M.opts.term_win_opts.height)
	end
	if M.opts.normal_win_opts.height < 1 then
		M.opts.normal_win_opts.height = math.floor(vim.o.lines * M.opts.normal_win_opts.height)
	end

	-- Initialize submodules
	M.term.setup(M.opts)
	M.highlight.setup(M.opts)
	M.keymaps.setup(M, M.opts)
end

return M
