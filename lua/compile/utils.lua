local compile = {}
compile.utils = {}

--- Execute function with optional focus preservation
function compile.utils.enter_wrapper(func)
	local current_win = vim.api.nvim_get_current_win()
	func()
	if (not require("compile").opts.enter) and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

--- Split string into character array
function compile.utils.split_to_char(str)
	local char_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(char_table, char)
	end
	return char_table
end

--- Split string into numeric array
function compile.utils.split_to_num(str)
	local num_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(num_table, tonumber(char))
	end
	return num_table
end

--- Get valid non-terminal window
function compile.utils.get_normal_win()
	local warning_filename = require("compile.highlight").get_current_warning().file.val

	local function endsWith(str, suffix)
		return str:sub(-#suffix) == suffix
	end

	-- use the window that already has the warning in it first
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local filename = vim.api.nvim_buf_get_name(buf)
		if endsWith(filename, warning_filename) then
			vim.api.nvim_set_current_win(win)
			return win
		end
	end

	if vim.api.nvim_get_current_win() == require("compile.term").state.win then
		-- get the first instance of non-terminal window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if win ~= require("compile.term").state.win then
				vim.api.nvim_set_current_win(win)
				return win
			end
		end
		-- Create new window if none found
		local buf = vim.api.nvim_create_buf(true, false)
		local win = vim.api.nvim_open_win(buf, true, require("compile").opts.normal_win_opts)
		vim.api.nvim_set_option_value("number", true, { win = win })
		return win
	end
	return vim.api.nvim_get_current_win()
end

--- Binary search index
function compile.utils.binary_search(list, num)
	local bot = 1
	local top = #list
	local middle = math.floor((top + bot) / 2)
	while top > bot + 1 do
		middle = math.floor((top + bot) / 2)
		if list[middle] < num then
			bot = middle
		elseif list[middle] > num then
			top = middle
		else
			return middle
		end
	end

	--- top = bot + 1
	if list[top] <= num then
		return top
	end
	return bot
end

return compile.utils
