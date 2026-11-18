local M = {}
function M.check()
  vim.health.start("clective")
  if vim.fn.has("nvim-0.11") == 1 then vim.health.ok("Neovim 0.11+ available")
  else vim.health.error("Neovim 0.11+ is required"); return end
  local options = require("clective").options()
  vim.health.info("State: " .. require("clective.state").path())
  if vim.fn.executable("clangd") == 1 then vim.health.ok("clangd: " .. vim.fn.exepath("clangd"))
  else vim.health.warn("clangd is not on PATH; an explicitly configured LSP executable may still work") end
  vim.health.info("clective configures attached clangd clients; it does not start a second server")
  for name, profile in pairs(options.profiles) do
    if profile.discover and vim.fn.executable(profile.compiler) ~= 1 then
      vim.health.warn(name .. ": compiler discovery executable is missing: " .. profile.compiler)
    end
    if profile.system_headers == false and not profile.target then
      vim.health.warn(name .. ": host headers disabled, but no target specified; target ABI is not emulated")
    end
  end
  local checked = 0
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and require("clective.util").supported(buffer) then
      local c = require("clective").context(buffer)
      if c then
        checked = checked + 1
        for _, dir in ipairs(c.missing_dirs) do vim.health.warn(c.profile .. ": missing directory: " .. dir) end
        for _, warning in ipairs(c.warnings) do vim.health.warn(warning) end
      end
    end
  end
  vim.health.info("Checked " .. checked .. " loaded source/header buffers; use :ClectiveInfo for the effective command")
end
return M
