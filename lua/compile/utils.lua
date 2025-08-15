---@meta
---@class UtilsModule
---@field enter_wrapper fun(func: function)
---@field split_to_char fun(str: string): string[]
---@field split_to_num fun(str: string): integer[]
---@field get_normal_win fun(): integer

local M = {}

---Execute function with optional focus preservation
---@param func function Function to execute
function M.enter_wrapper(func)
	local current_win = vim.api.nvim_get_current_win()
	func()
	if (not require("compile").opts.enter) and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

---Split string into character array
---@param str string Input string
---@return string[]
function M.split_to_char(str)
	local char_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(char_table, char)
	end
	return char_table
end

---Split string into numeric array
---@param str string Input string
---@return integer[]
function M.split_to_num(str)
	local num_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(num_table, tonumber(char))
	end
	return num_table
end

---Get valid non-terminal window
---@return integer Window ID
function M.get_normal_win()
	if vim.api.nvim_get_current_win() == require("compile.term").state.win then
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

---Binary search index
---@param list integer[] sorted list of integers
---@param num integer the number to find index
---@return integer index
function M.binary_search(list, num)
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

return M
