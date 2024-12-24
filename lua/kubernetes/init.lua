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

local Job = require("plenary.job")
local Path = require("plenary.path")

M.dump_schema = function()
	Path:new(config.cache_dir):mkdir({ parents = true })
	vim.notify("running: kubeschema dump --index --out-dir " .. config.cache_dir)
	Job:new({
		command = "kubeschema",
		args = { "dump", "--index", "--out-dir", config.cache_dir },
		on_exit = function(job, code)
			if code ~= 0 then
				vim.notify("kubeschema exited status " .. code .. " : " .. job:result())
			else
				vim.notify("kubernetes json schema generated successfully")
			end
		end,
	}):start()
end

M.on_attach = function(client, bufnr)
	require("kubernetes.yamlls").on_attach(client, bufnr, config.cache_dir)
end

return M
