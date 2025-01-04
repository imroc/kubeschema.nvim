local M = {}

---@param config kubeschema.Config
function M.setup_matcher(config)
	local matches = {}
	for _, pattern in ipairs(config.ignore_file_patterns) do
		if type(pattern) == "string" and #pattern > 0 then
			table.insert(matches, vim.regex([[\v]] .. pattern))
		end
	end
	if #matches == 0 then
		config.match_ignore = function(path)
			return false
		end
	else
		config.match_ignore = function(path)
			for _, reg in ipairs(matches) do
				if reg:match_str(path) then
					return true
				end
			end
			return false
		end
	end
end

return M
