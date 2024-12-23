local M = {}

local function remove_prefix(str, prefix)
	if str:sub(1, #prefix) == prefix then
		return str:sub(#prefix + 1)
	else
		return str
	end
end

local path_separator = package.config:sub(1, 1)

-- local kubeschemas_dir = os.getenv("HOME") .. path_separator .. ".config" .. path_separator .. "kubeschemas"

-- local kubeschemas = kubeschemas_dir .. path_separator .. "kubernetes.json"
local regKind = vim.regex([[\v^kind: \S+$]])
local regApiVersion = vim.regex([[\v^apiVersion: \S+$]])
local regHelm = vim.regex([[\v\{\{.+\}\}]])
local detach = function(client, bufnr)
	vim.diagnostic.enable(false, { bufnr = bufnr })
	vim.defer_fn(function()
		vim.diagnostic.reset(nil, bufnr)
		vim.lsp.buf_detach_client(bufnr, client.id)
	end, 500)
end

local get_new_settings = function(client, bufnr, kubeschemas_dir)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local kind = nil
	local apiVersion = nil
	local multi = false
	for _, line in ipairs(lines) do
		if regHelm:match_str(line) then -- ignore helm template
			detach(client, bufnr)
			return nil
		end
		if regKind:match_str(line) then
			if kind then
				multi = true
				break
			end
			kind = remove_prefix(line, "kind: ")
		end
		if not apiVersion then
			if regApiVersion:match_str(line) then
				apiVersion = remove_prefix(line, "apiVersion: ")
			end
		end
	end

	if kind then
		local filename = ""
		if multi then
			filename = "kubernetes.json"
		else
			if apiVersion then
				local ss = vim.split(apiVersion, "/")
				local group = "core.api.k8s.io"
				local version = apiVersion
				if #ss == 2 then
					group = ss[1]
					version = ss[2]
					if #vim.split(group, ".", { plain = true }) == 1 then -- 不存在 "."，是 k8s 自带的 API
						group = group .. ".api.k8s.io"
					end
				end
				filename = group .. path_separator .. kind .. "_" .. version .. ".json"
				filename = string.lower(filename)
			end
		end
		vim.notify("use schema " .. filename)
		local jsonschema = kubeschemas_dir .. path_separator .. filename
		if vim.uv.fs_stat(jsonschema) then
			local schemas = client.config.settings.yaml.schemas or {}
			local schema = schemas[jsonschema] or {}
			local bufuri = vim.uri_from_bufnr(bufnr)
			if not vim.tbl_contains(schema, bufuri) then
				vim.list_extend(schema, { bufuri })
				schemas[jsonschema] = schema
				client.config.settings.yaml.schemas = schemas
				return client.config.settings
			end
		end
	end
end

M.on_attach = function(client, bufnr, kubeschemas_dir)
	vim.notify("use cache dir:" .. kubeschemas_dir)
	if client.name ~= "yamlls" then
		return
	end
	--  忽略 kustomization.yaml，因为由另外的 schema 处理
	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	if buf_path:match("kustomization.ya?ml$") then
		return
	end
	-- remove yamlls from not yaml files
	-- https://github.com/towolf/vim-helm/issues/15
	if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
		-- detach(client, bufnr)
		return
	end

	local new_settings = get_new_settings(client, bufnr, kubeschemas_dir)
	if new_settings then
		client.server_capabilities.documentRangeFormattingProvider = true
		client.workspace_did_change_configuration(new_settings)
	end
end

return M
