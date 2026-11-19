-- ~/.config/nvim/lua/plugins/clective.lua
-- Define vim.g.mapleader before lazy.setup() if using the example mappings.
return {
  "IstiCusi/Clective.nvim",
  name = "clective",
  main = "clective",
  lazy = false,
  dependencies = { "hrsh7th/nvim-cmp" },
  keys = {
    { "<leader>Kc", "<cmd>ClectiveProfile<CR>", desc = "Clective: project profile" },
    { "<leader>Kb", "<cmd>ClectiveProfile!<CR>", desc = "Clective: file profile" },
    { "<leader>Ki", "<cmd>ClectiveInfo<CR>", desc = "Clective: effective settings" },
    { "<leader>Kh", "<cmd>ClectiveHeaders<CR>", desc = "Clective: find header" },
    { "<leader>Ks", "<cmd>ClectiveSwitch<CR>", desc = "Clective: source / header" },
    { "<leader>Kr", "<cmd>ClectiveRefresh<CR>", desc = "Clective: refresh paths" },
    { "<leader>Kp", "<cmd>ClectiveIndex<CR>", desc = "Clective: index project" },
  },
  opts = {
    default_profile = "project",
    build_dirs = { "build" },
    -- Native C and Native C++ are built in and query cc / c++.
    -- Add only the SDK profiles available on your machine. For example:
    -- profiles = {
    --   ["amiga-c"] = {
    --     label = "Amiga C", language = "c",
    --     build = "ignore", system_headers = false,
    --     include_dirs = { "~/SDKs/amiga/include" },
    --   },
    -- },
  },
}
