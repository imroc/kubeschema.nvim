local M = {}

local path_separator = package.config:sub(1, 1)
local regHelm = vim.regex([[\v\{\{.+\}\}]])

local detach = function(client, bufnr)
	vim.diagnostic.enable(false, { bufnr = bufnr })
	vim.defer_fn(function()
		vim.diagnostic.reset(nil, bufnr)
		vim.lsp.buf_detach_client(bufnr, client.id)
	end, 500)
end

local buf_schemas = {}

local function set_schema(schema_file, bufuri, schemas)
	local old_schema_file = buf_schemas[bufuri]
	if old_schema_file then
		if old_schema_file == schema_file then
			return false
		end
		-- clean old schema
		local file_pattern = schemas[old_schema_file]
		if file_pattern then
			local tp = type(file_pattern)
			if tp == "table" then
				for i = #file_pattern, 1, -1 do
					if file_pattern[i] == bufuri then
						table.remove(file_pattern, i)
					end
				end
			else
				if tp == "string" and file_pattern == bufuri then
					schemas[old_schema_file] = nil
				end
			end
		end
	end
	buf_schemas[bufuri] = schema_file
	local schema = schemas[schema_file]
	if not schema then
		schema = {}
	end
	if type(schema) == "string" then
		schema = { schema }
	end
	if vim.list_contains(schema, bufuri) then
		return false
	end
	vim.list_extend(schema, { bufuri })
	schemas[schema_file] = schema
	return true
end

---@param key string
---@param str string
local function parse_value(key, str)
	return str:match("^" .. key .. ":%s*([^#%s]+)$")
end

---@param config kubeschema.Config?
local get_kube_schema_settings = function(client, bufnr, config)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local kind = nil
	local apiVersion = nil
	local multi = false
	for _, line in ipairs(lines) do
		if regHelm:match_str(line) then -- ignore helm template
			detach(client, bufnr)
			return nil
		end

		local v = parse_value("apiVersion", line)
		if v then
			if apiVersion then
				multi = true
			else
				apiVersion = v
			end
			if kind then
				break
			end
		else
			if not kind then
				kind = parse_value("kind", line)
				if kind and apiVersion then
					break
				end
			end
		end
	end

	if kind and apiVersion then
		local filename = ""
		if multi then
			filename = "kubernetes.json"
		else
			local ss = vim.split(apiVersion, "/")
			local group = "core"
			local version = apiVersion
			if #ss == 2 then
				group = ss[1]
				version = ss[2]
			end
			filename = group .. path_separator .. kind .. "_" .. version .. ".json"
			filename = string.lower(filename)
		end
		local schema_file = config.extra_schema.dir .. path_separator .. filename -- check extra schema first
		if not vim.uv.fs_stat(schema_file) then -- fallback to default schema if extra schema not exsited
			schema_file = config.schema.dir .. path_separator .. filename
		end
		if vim.uv.fs_stat(schema_file) then
			local schemas = client.config.settings.yaml.schemas or {}
			local bufuri = vim.uri_from_bufnr(bufnr)
			if set_schema(schema_file, bufuri, schemas) then
				client.config.settings.yaml.schemas = schemas
				return client.config.settings
			end
		end
	end
end

local match = require("kubeschema.match")

---@param config kubeschema.Config
function M.on_buf_write(bufnr, config)
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
	for _, client in ipairs(clients) do
		if client.name == "yamlls" then
			M.update_yamlls_config(client, bufnr, config)
			return
		end
	end
end

---@param config kubeschema.Config
function M.update_yamlls_config(client, bufnr, config)
	if client.name ~= "yamlls" then
		return
	end

	-- remove yamlls from not yaml files
	-- https://github.com/towolf/vim-helm/issues/15
	if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
		-- detach(client, bufnr)
		return
	end

	--  ignore kustomization.yaml and k3d.yaml to avoid conflict with schemastore.nvim
	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	if not config.match_ignore then
		match.setup_matcher(config)
	end
	if config.match_ignore(buf_path) then
		return
	end

	-- if buf_path:match("kustomization.ya?ml$") or buf_path:match("k3d.ya?ml$") then
	-- 	return
	-- end

	local settings = get_kube_schema_settings(client, bufnr, config)
	if settings then
		-- client.server_capabilities.documentRangeFormattingProvider = true
		client.workspace_did_change_configuration(settings)
	end
end

return M
