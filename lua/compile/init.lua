local M = {}

local term = {
	buf = -1,
	win = -1,
	warning_list = {},
	warning_index = {},
	current_warning = 0,
}

local utils = {}

local term_group = vim.api.nvim_create_augroup("Terminal", { clear = true })
local ns = vim.api.nvim_create_namespace("TermHl")

function M.clear()
	utils.enter_wrapper(function()
		term.destroy()
		term.init()
	end)
end

function M.compile()
	utils.enter_wrapper(function()
		-- remove hl and warning list before continuing
		if term.warning_list and vim.api.nvim_buf_is_valid(term.buf) then
			term.clear_hl_warning()
		end
		term.show()
		term.attach_event()
		-- TODO more command template for each project type
		term.send_cmd(M.opts.cmds.default)
	end)
end

function M.destroy()
	utils.enter_wrapper(function()
		term.destroy()
	end)
end

function M.goto_error()
	local c_error = term.warning_list[term.warning_index[term.current_warning]]
	local win = utils.get_normal_win()
	-- open error file
	vim.cmd("edit " .. c_error.file.val)
	vim.api.nvim_win_set_cursor(win, { c_error.row.val, c_error.col.val })
	-- set term cursor as well
	vim.api.nvim_win_set_cursor(term.win, { c_error.file.pos[1][1] + 1, c_error.file.pos[1][2] })
	if M.opts.highlight_under_cursor.enabled then
		vim.hl.range(
			term.buf,
			ns,
			"Cursor",
			c_error.file.pos[1],
			c_error.file.pos[2],
			{ priority = 2000, timeout = M.opts.highlight_under_cursor.timeout }
		)
	end
end

function M.next_error()
	if #term.warning_index == 0 then
		return
	end
	utils.enter_wrapper(function()
		term.show()
		if term.current_warning >= #term.warning_index then
			term.current_warning = 1
		else
			term.current_warning = term.current_warning + 1
		end
		M.goto_error()
	end)
end

function M.prev_error()
	if #term.warning_index == 0 then
		return
	end
	utils.enter_wrapper(function()
		term.show()
		if term.current_warning <= 1 then
			term.current_warning = #term.warning_index
		else
			term.current_warning = term.current_warning - 1
		end
		M.goto_error()
	end)
end

function M.last_error()
	if #term.warning_index == 0 then
		return
	end
	utils.enter_wrapper(function()
		term.show()
		term.current_warning = #term.warning_index
		M.goto_error()
	end)
end

function M.first_error()
	if #term.warning_index == 0 then
		return
	end
	utils.enter_wrapper(function()
		term.show()
		term.current_warning = 1
		M.goto_error()
	end)
end

function M.debug()
	print(vim.inspect(term.warning_list))
end

function term.init()
	term.buf = vim.api.nvim_create_buf(false, true)
	term.win = vim.api.nvim_open_win(term.buf, true, M.opts.term_win_opts)
	vim.cmd("term")
	term.channel = vim.api.nvim_get_option_value("channel", { buf = term.buf })
end

function term.show()
	if vim.api.nvim_win_is_valid(term.win) then
		return
	end
	if vim.api.nvim_buf_is_valid(term.buf) then
		term.win = vim.api.nvim_open_win(term.buf, true, M.opts.term_win_opts)
	else
		term.init()
	end
end

function term.hide()
	if vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_hide(term.win)
		term.win = -1
	end
end

function term.destroy()
	term.hide()
	term.clear_hl_warning()
	if vim.api.nvim_buf_is_valid(term.buf) then
		vim.api.nvim_buf_delete(term.buf, { force = true })
		term.win = -1
		term.buf = -1
		term.channel = -1
	end
end

function term.toggle()
	if vim.api.nvim_win_is_valid(term.win) then
		term.hide()
	else
		term.show()
	end
end

local function highlight_extract(location_pattern, lines, first_line)
	local pattern = location_pattern[1]
	local positions = utils.split_to_num(location_pattern[2])
	local info = {}
	local formatted = {}
	for index, line in ipairs(lines) do
		local a, b, c = string.match(line, pattern)
		if not (a or b or c) then
			return
		end
		local as, ae = string.find(line, a, 1, true)
		local bs, be = string.find(line, b, ae + 1, true)
		local cs, ce = string.find(line, c, be + 1, true)

		info[positions[1]] = { a, as, ae }
		info[positions[2]] = { b, bs, be }
		info[positions[3]] = { c, cs, ce }

		formatted["file"] = {
			val = info[1][1],
			pos = { { first_line + index - 1, info[1][2] - 1 }, { first_line + index - 1, info[1][3] } },
		}
		formatted["row"] = {
			val = tonumber(info[2][1]),
			pos = { { first_line + index - 1, info[2][2] - 1 }, { first_line + index - 1, info[2][3] } },
		}
		formatted["col"] = {
			val = tonumber(info[3][1]),
			pos = { { first_line + index - 1, info[3][2] - 1 }, { first_line + index - 1, info[3][3] } },
		}

		-- highlight
		vim.hl.range(term.buf, ns, M.opts.colors.file, formatted["file"].pos[1], formatted["file"].pos[2])
		vim.hl.range(term.buf, ns, M.opts.colors.row, formatted["row"].pos[1], formatted["row"].pos[2])
		vim.hl.range(term.buf, ns, M.opts.colors.col, formatted["col"].pos[1], formatted["col"].pos[2])

		-- extract location
		local str = a .. ":" .. b .. ":" .. c
		if term.warning_list[str] ~= nil then
			return
		end
		term.warning_list[str] = formatted
		table.insert(term.warning_index, str)
	end
end

function term.attach_event()
	vim.api.nvim_buf_attach(term.buf, false, {
		on_lines = function(_, _, _, first_line, _, last_line, _, _, _)
			local lines = vim.api.nvim_buf_get_lines(term.buf, first_line, last_line, false)
			for _, location_pattern in pairs(M.opts.patterns) do
				highlight_extract(location_pattern, lines, first_line)
			end
		end,
	})
end

function term.send_cmd(cmd)
	-- alway set cursor at the end before sending command
	local line_count = vim.api.nvim_buf_line_count(term.buf)
	vim.api.nvim_win_set_cursor(term.win, { line_count, 0 })

	vim.api.nvim_chan_send(term.channel, cmd .. "\n")
end

function term.clear_hl_warning()
	if vim.api.nvim_buf_is_valid(term.buf) then
		vim.api.nvim_buf_clear_namespace(term.buf, ns, 0, -1)
	end
	term.warning_list = {}
	term.warning_index = {}
end

function utils.enter_wrapper(func)
	local current_win = vim.api.nvim_get_current_win()
	func()
	if (not M.opts.enter) and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

function utils.split_to_char(str)
	local char_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(char_table, char)
	end
	return char_table
end

function utils.split_to_num(str)
	local char_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(char_table, tonumber(char))
	end
	return char_table
end

function utils.get_normal_win()
	if vim.api.nvim_get_current_win() == term.win then
		-- look for other window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if win ~= term.win then
				vim.api.nvim_set_current_win(win)
				return win
			end
		end
		-- no window, create new
		local buf = vim.api.nvim_create_buf(true, false)
		return vim.api.nvim_open_win(buf, true, M.opts.normal_win_opts)
	else
		-- use current one
		return vim.api.nvim_get_current_win()
	end
end

M.opts = {
	---@type vim.api.keyset.win_config
	term_win_opts = {
		split = "below",
		height = 0.4,
	},

	normal_win_opts = {
		split = "above",
		height = 0.6,
	},

	enter = false,

	highlight_under_cursor = {
		enabled = true,
		timeout = 500,
	},

	cmds = {
		default = "make -k",
	},

	patterns = {
		rust = { "(%S+):(%d+):(%d+)", "123" },
	},

	colors = {
		file = "WarningMsg",
		row = "CursorLineNr",
		col = "CursorLineNr",
	},

	keys = {
		global = {
			["n"] = {
				["<localleader>cc"] = M.compile,
				["<localleader>cn"] = M.next_error,
				["<localleader>cp"] = M.prev_error,
				["<localleader>cl"] = M.last_error,
				["<localleader>cf"] = M.first_error,
			},
		},
		term = {
			global = {
				["n"] = {
					["<localleader>cr"] = M.clear,
					["<localleader>cq"] = M.destroy,
				},
			},
			buffer = {
				["n"] = {
					["r"] = M.clear,
					["c"] = M.compile,
					["q"] = M.destroy,
					["n"] = M.next_error,
					["p"] = M.prev_error,
					["0"] = M.first_error,
					["$"] = M.last_error,
					["d"] = M.debug,
				},
			},
		},
	},
}

M.setup = function(opts, _)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	if M.opts.term_win_opts.height < 1 then
		M.opts.term_win_opts.height = math.floor(vim.o.lines * M.opts.term_win_opts.height)
	end
	if M.opts.normal_win_opts.height < 1 then
		M.opts.normal_win_opts.height = math.floor(vim.o.lines * M.opts.normal_win_opts.height)
	end

	-- keymaps setup
	-- global
	for modes, keys in pairs(M.opts.keys.global) do
		for key, func in pairs(keys) do
			vim.keymap.set(utils.split_to_char(modes), key, func, {})
		end
	end

	vim.api.nvim_create_autocmd("BufCreate", {
		group = term_group,
		callback = function(ev)
			if term.buf == ev.buf then
				-- global keymaps if buffer exists
				for modes, keys in pairs(M.opts.keys.term.global) do
					for key, func in pairs(keys) do
						vim.keymap.set(utils.split_to_char(modes), key, func, {})
					end
				end

				-- buffer only keymaps
				for modes, keys in pairs(M.opts.keys.term.buffer) do
					for key, func in pairs(keys) do
						vim.keymap.set(utils.split_to_char(modes), key, func, { buffer = ev.buf })
					end
				end
			end
		end,
	})

	-- clean up
	vim.api.nvim_create_autocmd("BufDelete", {
		group = term_group,
		callback = function(ev)
			if term.buf == ev.buf then
				for modes, keys in pairs(M.opts.keys.term.global) do
					for key, _ in pairs(keys) do
						-- delete just doesn't work for some reasons
						-- so just set to nothing as a workaround
						vim.keymap.set(utils.split_to_char(modes), key, "", {})
					end
				end
			end
		end,
	})
end

return M
