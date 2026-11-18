-- Run :luafile /absolute/path/to/examples/demo/profile-setup.lua in Neovim.
local demo = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
demo = vim.fn.fnamemodify(demo, ":p")
local opts = vim.deepcopy(require("clective").options())
opts.profiles["demo-a"] = {
  label="Demo SDK A", language="c", build="ignore", system_headers=false,
  include_dirs={demo .. "/sdk-a"},
}
opts.profiles["demo-b"] = {
  label="Demo SDK B", language="c", build="ignore", system_headers=false,
  include_dirs={demo .. "/sdk-b"},
}
opts.profiles["demo-cpp"] = {
  label="Demo C++", language="cpp", build="ignore", system_headers=false,
  include_dirs={demo .. "/sdk-b"},
}
require("clective").setup(opts)
vim.cmd.edit(vim.fn.fnameescape(demo .. "/project/main.c"))
require("clective").apply_config("demo-a")
