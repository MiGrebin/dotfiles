-- Customize Treesitter
---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "python", -- add python parser
      -- add more arguments for adding more treesitter parsers
    },
    indent = {
      enable = true,
      disable = { "python" }, -- Disable treesitter indent for Python
    },
  },
}
