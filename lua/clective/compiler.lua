local M = {}
local util = require("clective.util")
local cache = {}
-- Only explicitly configured drivers are probed; build database commands are never executed.
function M.paths(profile, language, root, changed)
  if not profile.discover or not profile.compiler then return { paths = {} } end
  local compiler = profile.compiler:find("/", 1, true) and util.path(profile.compiler, root)
    or vim.fn.exepath(profile.compiler)
  local argv = { compiler ~= "" and compiler or profile.compiler }
  vim.list_extend(argv, profile.compiler_args)
  if profile.sysroot then argv[#argv + 1] = "--sysroot=" .. util.path(profile.sysroot, root) end
  vim.list_extend(argv, { "-E", "-x", language == "cpp" and "c++" or "c", "-v", "-" })
  local key = vim.json.encode({ argv, root })
  if cache[key] then return cache[key] end
  local result = { paths = {}, pending = true }
  cache[key] = result
  local ok, err = pcall(vim.system, argv, { text = true, stdin = "", cwd = root, timeout = 5000 }, function(process)
    vim.schedule(function()
      result.pending = false
      if process.code ~= 0 then result.error = "Compiler discovery failed: " .. argv[1]
      else
        local capture = false
        for line in ((process.stderr or "") .. "\n" .. (process.stdout or "")):gmatch("[^\r\n]+") do
          if line:find("#include <...> search starts here:", 1, true) then capture = true
          elseif line:find("End of search list.", 1, true) then capture = false
          elseif capture then
            local path = vim.trim(line):gsub(" %(framework directory%)$", "")
            if path ~= "" then result.paths[#result.paths + 1] = util.path(path, root) end
          end
        end
        result.paths = util.unique(result.paths)
      end
      changed()
    end)
  end)
  if not ok then result.pending = false; result.error = tostring(err) end
  return result
end
function M.clear() cache = {} end
return M
