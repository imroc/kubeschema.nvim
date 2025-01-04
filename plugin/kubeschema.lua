local kubeschema = require("kubeschema")

vim.api.nvim_create_user_command(
	"KubeschemaDump",
	kubeschema.dump_schema,
	{ desc = "Dump kubernetes json schema from current cluster" }
)

vim.api.nvim_create_user_command(
	"KubeschemaUpdate",
	kubeschema.update_schema,
	{ desc = "Update kubernetes json schema from remote git repo" }
)
