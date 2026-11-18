local M = {}
local fn = vim.fn


local config = require("clective.config")
local config_path = vim.fn.stdpath("config") .. "/scripts/clective"
local state_file = config_path .. "/state.json"


-- === State I/O ===
local function read_state()
  local f = io.open(state_file, "r")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  local ok, data = pcall(vim.json.decode, s)
  return ok and data or nil
end


local function write_state(state)
  vim.fn.mkdir(config_path, "p")
  local f = io.open(state_file, "w")
  if not f then return end
  f:write(vim.json.encode(state))
  f:close()
end


-- === Helpers für Pfadaufbau ===
local function clean(path)
  return path:gsub("/+%$", ""):gsub("/%*%*%$", ""):gsub("/+%$", "")
end


-- Erst Top-Level, dann rekursiv – garantiert, dass /usr/include/stdio.h vor bits/stdio.h gefunden wird
local function add_both(dst, dir)
  dir = dir:gsub("/+%$", ""):gsub("/%*%*%$", "")
  table.insert(dst, dir) -- Top-Level (kein /**)
  table.insert(dst, dir .. "/**") -- rekursiv
end


-- Nur rekursiv (z. B. GCC builtins)
local function add_tree(dst, dir)
  dir = dir:gsub("/+%$", ""):gsub("/%*%*%$", "")
  table.insert(dst, dir .. "/**")
end


--- Applies configuration with a given key name
function M.apply_config(name)
  local include_configs = config.include_configs or {}
  local includes = include_configs[name]
  if not includes then return end


  local path_entries = {}


  -- 1) compile_flags.txt im Buffer-CWD respektieren (-I / -isystem)
  local buf_path = vim.api.nvim_buf_get_name(0)
  local cwd = vim.fn.fnamemodify(buf_path, ":p:h")
  local flags_path = cwd .. "/compile_flags.txt"
  local f = io.open(flags_path, "r")
  if f then
    for line in f:lines() do
      local inc = line:match("^%s*%-I%s*(.+)") or line:match("^%s*%-isystem%s*(.+)")
      if inc then
        inc = inc:gsub("\"", "")
        add_both(path_entries, inc)
      end
    end
    f:close()
  end


  -- 2) Profile eintragen – Spezialbehandlung für GCC-Builtins
  for _, dir in ipairs(includes) do
    local d = dir:gsub("/+%$", ""):gsub("/%*%*%$", "")
    if d:find("/usr/lib/gcc/", 1, true) then
      add_tree(path_entries, d)
    else
      add_both(path_entries, d)
    end
  end


  -- Setzen
  vim.opt_local.path = table.concat(path_entries, ",")
  vim.opt_local.suffixesadd:append({ ".h", ".hpp", ".hh", ".hxx", ".c", ".cpp", ".cc", ".cxx" })


  write_state({ active_config = name })
end


function M.select_config()
  local include_configs = config.include_configs or {}
  local keys = {}
  for k, _ in pairs(include_configs) do table.insert(keys, k) end
  table.sort(keys)
  vim.ui.select(keys, { prompt = "Select Include Config:" }, function(choice)
    if choice then M.apply_config(choice) end
  end)
end


function M.setup(opts)
  -- Merge User-Profile
  config.merge(opts and opts.profiles)


  -- Beim Öffnen von C/C++-Dateien aktive Config anwenden
  vim.api.nvim_create_autocmd("BufWinEnter", {
    pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
    callback = function()
      local st = read_state()
      if st and st.active_config then
        -- WICHTIG: kein self-require, direkt M nutzen
        M.apply_config(st.active_config)
      end
    end,
  })
end


return M

