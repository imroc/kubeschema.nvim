local kubernetes = require("kubernetes")

vim.api.nvim_create_user_command("KubeSchemaUpdate", kubernetes.update_schema, { desc = "Dump kubernetes json schema" })
