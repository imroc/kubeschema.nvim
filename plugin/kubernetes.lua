local kubernetes = require("kubernetes")

vim.api.nvim_create_user_command(
	"KubeSchemaDump",
	kubernetes.dump_schema,
	{ desc = "Dump kubernetes json schema from current cluster" }
)
