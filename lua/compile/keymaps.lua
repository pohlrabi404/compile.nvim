---@meta
---@class KeymapsModule
---@field setup fun(main: Compile, opts: CompileConfig)

local M = {}

---Setup keybindings for plugin
---@param main Compile Main plugin instance
---@param opts CompileConfig Configuration options
function M.setup(main, opts)
	local term_group = vim.api.nvim_create_augroup("Compile", { clear = true })

	-- Global keymaps
	for modes, keymap in pairs(opts.keys.global) do
		for key, cmd in pairs(keymap) do
			vim.keymap.set(require("compile.utils").split_to_char(modes), key, function()
				main[cmd]()
			end, { silent = true })
		end
	end

	-- Terminal-specific keymaps
	vim.api.nvim_create_autocmd("BufCreate", {
		group = term_group,
		callback = function(ev)
			local term_buf = require("compile.term").state.buf
			if ev.buf ~= term_buf then
				return
			end

			-- Global terminal keymaps
			for modes, keymap in pairs(opts.keys.term.global) do
				for key, cmd in pairs(keymap) do
					vim.keymap.set(require("compile.utils").split_to_char(modes), key, function()
						main[cmd]()
					end, { silent = true })
				end
			end

			-- Buffer-local keymaps
			for modes, keymap in pairs(opts.keys.term.buffer) do
				for key, cmd in pairs(keymap) do
					vim.keymap.set(require("compile.utils").split_to_char(modes), key, function()
						main[cmd]()
					end, { buffer = ev.buf, silent = true })
				end
			end
		end,
	})

	-- Cleanup keymaps on buffer delete
	vim.api.nvim_create_autocmd("BufDelete", {
		group = term_group,
		callback = function(ev)
			if ev.buf == require("compile.term").state.buf then
				for modes, keymap in pairs(opts.keys.term.global) do
					for key in pairs(keymap) do
						pcall(vim.keymap.del, modes, key, { buffer = false })
					end
				end
			end
		end,
	})
end

return M
