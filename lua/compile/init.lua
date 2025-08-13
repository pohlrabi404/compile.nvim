local M = {}

M.opts = {}

M.setup = function(opts, _)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", opts, M.opts)
end

return M
