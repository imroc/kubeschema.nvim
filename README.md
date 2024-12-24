# kubenretes.nvim

A neovim plugin for kubernetes.

## Requirements

- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) and [kubeschema](https://github.com/imroc/kubeschema) installed and and operate the target cluster (Optional, used to dump json schema from current cluster by `KubeSchemaDump` command).

## Installation

Use [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        "imroc/kubernetes.nvim",
      },
    },
    opts = {
      servers = {
        yamlls = {
          on_attach = function(client, bufnr)
            require("kubernetes").on_attach(client, bufnr)
          end,
        },
      },
    },
  },
}
```

