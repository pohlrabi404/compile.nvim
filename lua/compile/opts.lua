--- Default configuration options for the plugin. Users can override these with `compile.setup()`.
---
---@class compile.opts
---
---@field term_win_name string The name of the terminal window.
---@field term_win_opts vim.api.keyset.win_config Options of the terminal window
---@field normal_win_opts vim.api.keyset.win_config Options of the normal window (if there is not one already)
---@field enter boolean If true, automatically enter the terminal window after compiling.
---@field highlight_under_cursor table Options for highlighting the error under the cursor in both terminal and normal windows.
---@field cmds table A table of commands to execute for different file types.
---@field patterns table A table of regular expression patterns used to parse compiler errors.
---@field colors table A table of highlight groups to use for coloring different parts of an error message.
---@field keys table A table of keymaps for global and terminal-specific actions.
return {
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

	hidden = true,

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
		python = { 'File "(%S+%.%a+)", line (%d+)', "12" },
	},

	colors = {
		file = "WarningMsg",
		row = "CursorLineNr",
		col = "CursorLineNr",
	},

	keys = {
		global = {
			["n"] = {
				["<localleader>cn"] = "require('compile').next_error()",
				["<localleader>cp"] = "require('compile').prev_error()",
			},
		},
		term = {
			global = {
				["n"] = {},
			},
			buffer = {
				["n"] = {
					["n"] = "require('compile').next_error()",
					["p"] = "require('compile').prev_error()",
					["0"] = "require('compile').first_error()",
					["$"] = "require('compile').last_error()",
					["<Cr>"] = "require('compile').nearest_error()",
				},
				["t"] = {
					["<CR>"] = "require('compile').clear_hl()",
				},
			},
		},
	},
}
