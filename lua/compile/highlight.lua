local M = {}

M.state = {
	warning_list = {},
	warning_index = {},
	current_warning = 0,
}

M.ns = vim.api.nvim_create_namespace("TermHl")

local opts = {}

---Initialize highlight module
function M.setup(o)
	opts = o
end

---Clear all warning highlights
function M.clear_hl_warning()
	if vim.api.nvim_buf_is_valid(require("compile.term").state.buf) then
		vim.api.nvim_buf_clear_namespace(require("compile.term").state.buf, M.ns, 0, -1)
	end
	M.state.warning_list = {}
	M.state.warning_index = {}
end

---Check if warnings exist
function M.has_warnings()
	return #M.state.warning_index > 0
end

---Get current warning data
function M.get_current_warning()
	if not M.has_warnings() then
		return nil
	end
	return M.state.warning_list[M.state.warning_index[M.state.current_warning]]
end

---Navigate to next warning
function M.next_warning()
	if M.state.current_warning >= #M.state.warning_index then
		M.state.current_warning = 1
	else
		M.state.current_warning = M.state.current_warning + 1
	end
end

---Navigate to previous warning
function M.prev_warning()
	if M.state.current_warning <= 1 then
		M.state.current_warning = #M.state.warning_index
	else
		M.state.current_warning = M.state.current_warning - 1
	end
end

---Navigate to first warning
function M.first_warning()
	M.state.current_warning = 1
end

---Navigate to last warning
function M.last_warning()
	M.state.current_warning = #M.state.warning_index
end

---Process new terminal lines for warnings
local function highlight_extract(location_pattern, lines, first_line)
	local pattern = location_pattern[1]
	local positions = require("compile.utils").split_to_num(location_pattern[2])

	if #positions == 2 then
		local formatted = {}
		for index, line in ipairs(lines) do
			local a, b = string.match(line, pattern)
			if not (a and b) then
				goto continue
			end

			local as, ae = string.find(line, a, 1, true)
			local bs, be = string.find(line, b, ae + 1, true)

			local sorted = {}
			sorted[positions[1]] = { a, as, ae }
			sorted[positions[2]] = { b, bs, be }

			formatted["file"] = {
				val = sorted[1][1],
				pos = { { first_line + index - 1, sorted[1][2] - 1 }, { first_line + index - 1, sorted[1][3] } },
			}
			formatted["row"] = {
				val = tonumber(sorted[2][1]),
				pos = { { first_line + index - 1, sorted[2][2] - 1 }, { first_line + index - 1, sorted[2][3] } },
			}
			formatted["col"] = {
				val = 0,
				pos = { { first_line + index - 1, sorted[2][2] - 1 }, { first_line + index - 1, sorted[2][3] } },
			}

			-- Apply highlights
			vim.hl.range(
				require("compile.term").state.buf,
				M.ns,
				opts.colors.file,
				formatted.file.pos[1],
				formatted.file.pos[2]
			)
			vim.hl.range(
				require("compile.term").state.buf,
				M.ns,
				opts.colors.row,
				formatted.row.pos[1],
				formatted.row.pos[2]
			)

			-- Store warning
			local key = a .. ":" .. b
			if not M.state.warning_list[key] then
				M.state.warning_list[key] = formatted
				table.insert(M.state.warning_index, key)
			end

			::continue::
		end
		return
	end

	for index, line in ipairs(lines) do
		local formatted = {}
		local a, b, c = string.match(line, pattern)
		if not (a and b and c) then
			goto continue
		end

		local as, ae = string.find(line, a, 1, true)
		local bs, be = string.find(line, b, ae + 1, true)
		local cs, ce = string.find(line, c, be + 1, true)

		local sorted = {}
		sorted[positions[1]] = { a, as, ae }
		sorted[positions[2]] = { b, bs, be }
		sorted[positions[3]] = { c, cs, ce }

		formatted["file"] = {
			val = sorted[1][1],
			pos = { { first_line + index - 1, sorted[1][2] - 1 }, { first_line + index - 1, sorted[1][3] } },
		}
		formatted["row"] = {
			val = tonumber(sorted[2][1]),
			pos = { { first_line + index - 1, sorted[2][2] - 1 }, { first_line + index - 1, sorted[2][3] } },
		}
		formatted["col"] = {
			val = tonumber(sorted[3][1]),
			pos = { { first_line + index - 1, sorted[3][2] - 1 }, { first_line + index - 1, sorted[3][3] } },
		}

		-- Apply highlights
		vim.hl.range(
			require("compile.term").state.buf,
			M.ns,
			opts.colors.file,
			formatted.file.pos[1],
			formatted.file.pos[2]
		)
		vim.hl.range(
			require("compile.term").state.buf,
			M.ns,
			opts.colors.row,
			formatted.row.pos[1],
			formatted.row.pos[2]
		)
		vim.hl.range(
			require("compile.term").state.buf,
			M.ns,
			opts.colors.col,
			formatted.col.pos[1],
			formatted.col.pos[2]
		)

		-- Store warning
		local key = a .. ":" .. b .. ":" .. c
		if not M.state.warning_list[key] then
			M.state.warning_list[key] = formatted
			table.insert(M.state.warning_index, key)
		end

		::continue::
	end
end

---Process incoming terminal lines
function M.process_lines(lines, first_line)
	for _, location_pattern in pairs(opts.patterns) do
		highlight_extract(location_pattern, lines, first_line)
	end
end

return M
