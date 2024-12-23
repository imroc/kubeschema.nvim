local kubernetes = require("kubernetes")

vim.api.nvim_create_user_command("KubeSchema", kubernetes.kubeschema, { desc = "Dump kubernetes json schema" })
