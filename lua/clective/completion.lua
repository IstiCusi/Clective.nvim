local M = {}
local saved, registered = {}, false
function M.register()
  local ok, cmp = pcall(require, "cmp")
  if ok and not registered then
    cmp.register_source("clective_includes", require("clective.cmp_source").new())
    registered = true
  end
  return ok and cmp or nil
end
function M.update(buffer, leaving)
  local cmp = package.loaded.cmp
  if not cmp or buffer ~= vim.api.nvim_get_current_buf() then return end
  if not registered then M.register() end
  -- cmp.setup.buffer replaces the whole local table. Preserve all unrelated
  -- settings and preserve inheritance when the buffer has no local sources.
  local ok, config = pcall(require, "cmp.config")
  if not ok or type(config.buffers) ~= "table" then return end
  local options = require("clective").options()
  local before = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
  local active = not leaving and options.exclusive_includes and require("clective.util").supported(buffer)
    and require("clective.headers").prefix(before)
  if active and not saved[buffer] then
    local local_config = vim.deepcopy(config.buffers[buffer] or {})
    saved[buffer] = { sources=vim.deepcopy(local_config.sources) }
    local_config.sources = {{name="clective_includes", keyword_length=0}}
    cmp.setup.buffer(local_config)
    -- Changing sources does not itself trigger cmp. In particular its first
    -- TextChangedI event in a buffer may only initialize its cursor tracking.
    vim.schedule(function()
      if saved[buffer] and vim.api.nvim_get_current_buf() == buffer
        and vim.fn.mode():sub(1,1) == "i" and config.enabled()
        and cmp.get_config().completion.autocomplete ~= false then cmp.complete() end
    end)
  elseif not active and saved[buffer] then
    local local_config = vim.deepcopy(config.buffers[buffer] or {})
    local current = local_config.sources or {}
    if #current == 1 and current[1].name == "clective_includes" then
      local_config.sources = saved[buffer].sources
      cmp.setup.buffer(local_config)
    end
    saved[buffer] = nil
  end
end
function M.forget(buffer) saved[buffer] = nil end
return M
