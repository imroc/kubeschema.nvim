local M = {}

local Job = require("plenary.job")
local Path = require("plenary.path")

---@class kubernetes.Schema
---@field url? string
---@field dir? string

---@class kubernetes.Config
---@field schema? kubernetes.Schema
---@field extra_schema? kubernetes.Schema
---@field ignore_file_patterns? string[]
local config = {
	schema = {
		url = "https://github.com/imroc/kubeschemas",
		dir = vim.fn.stdpath("data") .. "/kubernetes/schemas",
	},
	extra_schema = {
		dir = vim.fn.stdpath("data") .. "/kubernetes/extra_schemas",
	},
	ignore_file_patterns = {
		[[kustomization\.ya?ml$]],
		[[k3d\.ya?ml$]],
	},
}

M.did_setup = false

---@param schema kubernetes.Schema?
local function ensure_schema_dir(schema)
	if schema.dir then
		schema.dir = schema.dir:gsub("~", os.getenv("HOME") or "~")
		if not vim.uv.fs_stat(schema.dir) and schema.url then
			vim.notify("downloading kubernetes json schema from " .. schema.url)
			Job:new({
				command = "git",
				args = { "clone", "--depth=1", schema.url, schema.dir },
				on_exit = function(job, code)
					if code ~= 0 then
						vim.notify("git clone exited with status " .. code)
					else
						vim.notify("kubernetes json schema downloaded successfully")
					end
				end,
			}):start()
		end
	end
end

---@param opts kubernetes.Config?
function M.setup(opts)
	if M.did_setup then
		return vim.notify("kubernetes.nvim is already setup", vim.log.levels.ERROR, { title = "kubernetes.nvim" })
	end
	M.did_setup = true
	config = vim.tbl_deep_extend("force", config, opts or {})
	ensure_schema_dir(config.schema)
	ensure_schema_dir(config.extra_schema)
	require("kubernetes.match").setup_matcher(config)
end

function M.dump_schema()
	Path:new(config.extra_schema.dir):mkdir({ parents = true })
	Job:new({
		command = "kubeschema",
		args = { "dump", "--index", "--out-dir", config.extra_schema.dir, "--extra-dir", config.schema.dir },
		on_exit = function(job, code)
			if code ~= 0 then
				vim.notify("kubeschema exited status " .. code)
			else
				vim.notify("kubernetes json schema generated successfully")
			end
		end,
	}):start()
end

---@param schema kubernetes.Schema?
local function update_schema(schema)
	if
		schema.dir
		and os.execute(string.format("git -C %s rev-parse --is-inside-work-tree 2>/dev/null", schema.dir)) == 0
	then
		Job:new({
			command = "git",
			args = { "-C", schema.dir, "pull" },
			on_exit = function(job, code)
				if code ~= 0 then
					vim.notify("git pull exited status " .. code)
				else
					vim.notify("kubernetes json schema updated")
				end
			end,
		}):start()
	end
end

function M.update_schema()
	update_schema(config.schema)
	update_schema(config.extra_schema)
end

M.on_attach = function(client, bufnr)
	require("kubernetes.yamlls").on_attach(client, bufnr, config)
end

return M
