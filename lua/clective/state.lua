local M = {}
local util = require("clective.util")
local filename, cached, signature
local function read()
  local current = util.signature(filename)
  if cached and signature == current then return cached end
  local value, err = util.json(filename)
  if err then util.notify(err, vim.log.levels.WARN) end
  cached = type(value) == "table" and value.version == 1 and value or {}
  cached.projects = type(cached.projects) == "table" and cached.projects or {}
  cached.files = type(cached.files) == "table" and cached.files or {}
  signature = current
  return cached
end
function M.setup(path) filename, cached, signature = path, nil, nil end
function M.get(root, path)
  local s = read()
  return type(s.files[path]) == "string" and s.files[path] or nil,
    type(s.projects[root]) == "string" and s.projects[root] or nil
end
function M.set(scope, key, profile)
  local s = read()
  s[scope][key] = profile; s.version = 1
  local ok, err = util.write_json(filename, s)
  if not ok then util.notify("Cannot save profiles: " .. tostring(err), vim.log.levels.ERROR) end
  signature = util.signature(filename)
  return ok
end
function M.path() return filename end
return M
