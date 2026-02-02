-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Auto-format Python files on save using conform
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.py",
  callback = function() require("conform").format { timeout_ms = 2000, lsp_fallback = true } end,
})
