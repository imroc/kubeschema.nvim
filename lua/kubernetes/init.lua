local M = {}

---@class kubernetes.Config
---@field cache_dir? string
local config = {
	cache_dir = vim.fn.stdpath("data") .. "/kubenretes",
}

M.did_setup = false

---@param opts kubernetes.Config?
function M.setup(opts)
	if M.did_setup then
		return vim.notify("kubernetes.nvim is already setup", vim.log.levels.ERROR, { title = "kubernetes.nvim" })
	end
	M.did_setup = true
	config = vim.tbl_deep_extend("force", config, opts or {})
end

M.update_schema = function()
	vim.notify("update schema")
end

return M
