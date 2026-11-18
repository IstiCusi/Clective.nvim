
local ok, mod = pcall(require, "clective")
if not ok then
vim.notify("clective: load failed: " .. tostring(mod), vim.log.levels.ERROR)
return
end


mod.setup()

local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.register_source("clective_includes", require("clective.cmp_source").new())
end

