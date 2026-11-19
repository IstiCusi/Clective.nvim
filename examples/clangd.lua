-- Optional: use ONLY when clangd is not already configured elsewhere.
-- Requires an installed clangd executable on PATH, and Neovim 0.11+.
vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index" },
  filetypes = { "c", "cpp" },
  root_markers = {
    "compile_commands.json", "compile_flags.txt", ".clangd",
    "CMakeLists.txt", "Makefile", ".git",
  },
})
vim.lsp.enable("clangd")
