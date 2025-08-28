local compile = {}
compile.highlight = {}

compile.highlight.state = {
	warning_list = {},
	warning_index = {},
	current_warning = 0,
}

compile.highlight.ns = vim.api.nvim_create_namespace("TermHl")

local opts = {}

--- Initialize highlight module
function compile.highlight.setup(o)
	opts = o
end

--- Clear all warning highlights
function compile.highlight.clear_hl_warning()
	if vim.api.nvim_buf_is_valid(require("compile.term").state.buf) then
		vim.api.nvim_buf_clear_namespace(require("compile.term").state.buf, compile.highlight.ns, 0, -1)
	end
	compile.highlight.state.warning_list = {}
	compile.highlight.state.warning_index = {}
end

--- Check if warnings exist
function compile.highlight.has_warnings()
	return #compile.highlight.state.warning_index > 0
end

--- Get current warning data
function compile.highlight.get_current_warning()
	if not compile.highlight.has_warnings() then
		return nil
	end
	return compile.highlight.state.warning_list[compile.highlight.state.warning_index[compile.highlight.state.current_warning]]
end

--- Navigate to next warning
function compile.highlight.next_warning()
	if compile.highlight.state.current_warning >= #compile.highlight.state.warning_index then
		compile.highlight.state.current_warning = 1
	else
		compile.highlight.state.current_warning = compile.highlight.state.current_warning + 1
	end
end

--- Navigate to previous warning
function compile.highlight.prev_warning()
	if compile.highlight.state.current_warning <= 1 then
		compile.highlight.state.current_warning = #compile.highlight.state.warning_index
	else
		compile.highlight.state.current_warning = compile.highlight.state.current_warning - 1
	end
end

--- Navigate to first warning
function compile.highlight.first_warning()
	compile.highlight.state.current_warning = 1
end

--- Navigate to last warning
function compile.highlight.last_warning()
	compile.highlight.state.current_warning = #compile.highlight.state.warning_index
end

-- Process new terminal lines for warnings
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
				compile.highlight.ns,
				opts.colors.file,
				formatted.file.pos[1],
				formatted.file.pos[2]
			)
			vim.hl.range(
				require("compile.term").state.buf,
				compile.highlight.ns,
				opts.colors.row,
				formatted.row.pos[1],
				formatted.row.pos[2]
			)

			-- Store warning
			local key = a .. ":" .. b
			if not compile.highlight.state.warning_list[key] then
				compile.highlight.state.warning_list[key] = formatted
				table.insert(compile.highlight.state.warning_index, key)
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
			compile.highlight.ns,
			opts.colors.file,
			formatted.file.pos[1],
			formatted.file.pos[2]
		)
		vim.hl.range(
			require("compile.term").state.buf,
			compile.highlight.ns,
			opts.colors.row,
			formatted.row.pos[1],
			formatted.row.pos[2]
		)
		vim.hl.range(
			require("compile.term").state.buf,
			compile.highlight.ns,
			opts.colors.col,
			formatted.col.pos[1],
			formatted.col.pos[2]
		)

		-- Store warning
		local key = a .. ":" .. b .. ":" .. c
		if not compile.highlight.state.warning_list[key] then
			compile.highlight.state.warning_list[key] = formatted
			table.insert(compile.highlight.state.warning_index, key)
		end

		::continue::
	end
end

--- Process incoming terminal lines
function compile.highlight.process_lines(lines, first_line)
	for _, location_pattern in pairs(opts.patterns) do
		highlight_extract(location_pattern, lines, first_line)
	end
end

return compile.highlight
