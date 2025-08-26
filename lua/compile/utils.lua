local M = {}

---Execute function with optional focus preservation
function M.enter_wrapper(func)
	local current_win = vim.api.nvim_get_current_win()
	func()
	if (not require("compile").opts.enter) and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

---Split string into character array
function M.split_to_char(str)
	local char_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(char_table, char)
	end
	return char_table
end

---Split string into numeric array
function M.split_to_num(str)
	local num_table = {}
	for char in string.gmatch(str, ".") do
		table.insert(num_table, tonumber(char))
	end
	return num_table
end

---Get valid non-terminal window
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
