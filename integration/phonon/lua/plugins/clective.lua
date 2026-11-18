-- Local installation. Keep this file when clective moves to a Git repository.
return {
  dir = vim.fn.stdpath("config") .. "/scripts/clective",
  name = "clective",
  main = "clective",
  lazy = false,
  dependencies = { "hrsh7th/nvim-cmp" },
  keys = {
    { "<leader>Kc", "<cmd>ClectiveProfile<CR>", desc = "Clective: project profile" },
    { "<leader>Kb", "<cmd>ClectiveProfile!<CR>", desc = "Clective: file profile" },
    { "<leader>Ki", "<cmd>ClectiveInfo<CR>", desc = "Clective: effective settings" },
    { "<leader>Ks", "<cmd>ClectiveSwitch<CR>", desc = "Clective: source / header" },
    { "<leader>Kr", "<cmd>ClectiveRefresh<CR>", desc = "Clective: refresh paths" },
    { "<leader>Kp", "<cmd>ClectiveIndex<CR>", desc = "Clective: index project" },
    { "<leader>Kw", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Clective: project symbols" },
    { "<leader>Ko", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Clective: document symbols" },
  },
  opts = {
    default_profile = "project",
    build_dirs = { "build" },
    profiles = {
      ["native-c"] = {
        label = "Linux C (GCC)", language = "c", compiler = "gcc", discover = true,
      },
      ["native-cpp"] = {
        label = "Linux C++ (G++)", language = "cpp", compiler = "g++", discover = true,
      },
      ["amiga-c"] = {
        label = "Amiga C", language = "c", build = "ignore", system_headers = false,
        include_dirs = { "~/Development/codesnips/amiga/include" },
      },
      ["NDK3.5-c"] = {
        label = "Amiga NDK 3.5 · C", language = "c", build = "ignore", system_headers = false,
        include_dirs = { "~/Development/codesnips/amiga/AmigaDevCD/NDK/NDK_3.5/Include/include_h" },
      },
      c64 = {
        label = "C64 · Oscar64 C", language = "c", build = "ignore", system_headers = false,
        include_dirs = { "~/Development/lang/C64-oscar64/include" },
      },
    },
  },
}
