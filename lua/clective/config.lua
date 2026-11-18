local M = {}
M.defaults = {
  default_profile = "project",
  root_markers = { ".git", "compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile" },
  build_dirs = { "build" },
  state_file = vim.fn.stdpath("state") .. "/clective/state.json",
  map_gf = true, exclusive_includes = true,
  clangd = { enabled = true }, max_headers = 20000, max_sources = 5000,
  profiles = {
    project = { label = "Project build settings", language = "auto", build = "merge" },
    ["native-c"] = { label = "Native C", language = "c", compiler = "cc", discover = true },
    ["native-cpp"] = { label = "Native C++", language = "cpp", compiler = "c++", discover = true },
  },
}
local function strings(value, name)
  assert(type(value) == "table", name .. " must be a list")
  for _, item in ipairs(value) do assert(type(item) == "string" and item ~= "", name .. " contains an invalid value") end
end
function M.resolve(options)
  options = options or {}
  local out = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options)
  out.profiles = vim.deepcopy(M.defaults.profiles)
  for name, value in pairs(options.profiles or {}) do
    assert(type(name) == "string" and type(value) == "table", "invalid profile")
    if value[1] then
      value = { label = name, language = (name:find("c++", 1, true) or name:find("cpp", 1, true)) and "cpp" or "c",
        include_dirs = vim.deepcopy(value), build = "merge" }
    end
    out.profiles[name] = vim.deepcopy(value)
  end
  for name, p in pairs(out.profiles) do
    p.label, p.language, p.build = p.label or name, p.language or "auto", p.build or "merge"
    assert(p.language == "c" or p.language == "cpp" or p.language == "auto", "invalid language in " .. name)
    assert(p.build == "merge" or p.build == "ignore", "invalid build policy in " .. name)
    for _, key in ipairs({ "include_dirs", "quote_dirs", "system_dirs", "defines", "flags", "compiler_args" }) do
      p[key] = p[key] or {}; strings(p[key], name .. "." .. key)
    end
    for _, key in ipairs({ "compiler", "standard", "target", "sysroot" }) do
      assert(p[key] == nil or type(p[key]) == "string", "invalid " .. key .. " in " .. name)
    end
    if p.discover then assert(p.compiler, "compiler discovery requires an explicit compiler: " .. name) end
  end
  assert(out.profiles[out.default_profile], "default_profile is unknown")
  assert(type(out.max_headers) == "number" and out.max_headers > 0, "max_headers must be positive")
  assert(type(out.max_sources) == "number" and out.max_sources > 0, "max_sources must be positive")
  strings(out.root_markers, "root_markers"); strings(out.build_dirs, "build_dirs")
  assert(type(out.state_file) == "string" and out.state_file ~= "", "state_file must be a path")
  return out
end
return M
