
if vim.g.loaded_clective then return end
vim.g.loaded_clective = true
-- Defer defaults so an explicit package-manager setup takes precedence.
vim.schedule(function()
  require("clective").options()
end)

