local M = {}
local util = require("clective.util")
local cache = {}
local function database(path)
  local stamp = util.signature(path)
  if cache[path] and cache[path].stamp == stamp then return cache[path].entries, cache[path].error end
  local data, err = util.json(path)
  local entries = {}
  for _, entry in ipairs(data or {}) do
    if type(entry) == "table" and type(entry.file) == "string" then
      local dir = util.path(entry.directory or ".", vim.fs.dirname(path))
      local argv = type(entry.arguments) == "table" and vim.deepcopy(entry.arguments)
        or type(entry.command) == "string" and util.words(entry.command)
      if argv and #argv > 0 then
        local valid = true
        for _, arg in ipairs(argv) do if type(arg) ~= "string" then valid = false end end
        if valid then entries[#entries + 1] = { file = util.path(entry.file, dir), directory = dir, arguments = argv } end
      end
    end
  end
  cache[path] = { stamp = stamp, entries = entries, error = err }
  return entries, err
end
local function locate(path, root, build_dirs)
  local dir = vim.fs.dirname(path)
  if not util.under(path, root) then dir = root end
  while dir do
    local names = { dir .. "/compile_commands.json", dir .. "/compile_flags.txt" }
    for _, sub in ipairs(build_dirs) do names[#names + 1] = util.path(sub, dir) .. "/compile_commands.json" end
    for _, candidate in ipairs(names) do if vim.fn.filereadable(candidate) == 1 then return candidate end end
    if dir == root or dir == "/" then break end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
end
function M.load(path, root, options, source_path)
  local filename = locate(path, root, options.build_dirs)
  if not filename then return nil end
  if filename:match("compile_flags%.txt$") then
    local argv = { "clang" }
    for line in (util.read(filename) or ""):gmatch("[^\r\n]+") do
      line = vim.trim(line)
      if line ~= "" then
        -- compile_flags.txt is one argument per line, not a shell command.
        -- Accept quoted paths as a courtesy, but keep unquoted spaces intact.
        local flag, path = line:match("^(%-I)(.+)$")
        if not flag then flag, path = line:match("^(%-isystem)(.+)$") end
        if not flag then flag, path = line:match("^(%-iquote)(.+)$") end
        if flag then
          path = vim.trim(path)
          argv[#argv + 1] = flag .. (path:match('^"(.*)"$') or path:match("^'(.*)'$") or path)
        else argv[#argv + 1] = line:match('^"(.*)"$') or line:match("^'(.*)'$") or line end
      end
    end
    return { file = path, directory = vim.fs.dirname(filename), arguments = argv, origin = filename }
  end
  local entries, err = database(filename)
  if err then return { error = err, origin = filename } end
  local best, best_score
  local ext = path:match("%.([^./]+)$")
  local header = not ext or vim.tbl_contains({"h", "hpp", "hh", "hxx", "ipp", "tpp"}, ext)
  local stem = vim.fs.basename(path):gsub("%.[^.]+$", "")
  for _, entry in ipairs(entries) do
    if entry.file == path or entry.file == source_path then
      best = vim.deepcopy(entry); best.inferred = entry.file ~= path; break
    end
    if header then
      local score = 0
      while score < math.min(#path, #entry.file) and path:sub(score + 1, score + 1) == entry.file:sub(score + 1, score + 1) do score = score + 1 end
      if vim.fs.basename(entry.file):gsub("%.[^.]+$", "") == stem then score = score + 100000 end
      if not best_score or score > best_score then best_score = score; best = vim.deepcopy(entry); best.inferred = true end
    end
  end
  if best then best.origin = filename; return best end
  return { origin = filename }
end
function M.clean(entry)
  if not entry or not entry.arguments then return {} end
  local argv, output = entry.arguments, {}
  local i = 1
  while argv[i] and (vim.fs.basename(argv[i]) == "ccache" or vim.fs.basename(argv[i]) == "sccache"
    or vim.fs.basename(argv[i]) == "env" or argv[i]:match("^[%w_]+=")) do i = i + 1 end
  output[1] = argv[i] or "clang"
  i = i + 1
  local takes = { ["-o"] = true, ["-MF"] = true, ["-MT"] = true, ["-MQ"] = true, ["-MJ"] = true,
    ["--serialize-diagnostics"] = true }
  local skip = { ["-c"] = true, ["-MD"] = true, ["-MMD"] = true, ["-MP"] = true }
  while i <= #argv do
    local arg = argv[i]
    if takes[arg] then i = i + 2
    elseif skip[arg] or (arg:sub(1, 1) ~= "-" and util.path(arg, entry.directory) == entry.file) then i = i + 1
    else output[#output + 1] = arg; i = i + 1 end
  end
  return output
end
function M.flags(argv, directory)
  local out = { include_dirs = {}, system_dirs = {}, quote_dirs = {}, after_dirs = {} }
  local types = { ["-I"] = "include_dirs", ["-isystem"] = "system_dirs", ["-iquote"] = "quote_dirs", ["-idirafter"] = "after_dirs" }
  local i = 2
  while i <= #argv do
    local arg = argv[i]
    local matched = false
    for _, flag in ipairs({ "-isystem", "-idirafter", "-iquote", "-I" }) do
      local value
      if arg == flag then i = i + 1; value = argv[i]
      elseif arg:sub(1, #flag) == flag then value = arg:sub(#flag + 1):gsub("^=", "") end
      if value then
        out[types[flag]][#out[types[flag]] + 1] = util.path(value, directory)
        matched = true; break
      end
    end
    if not matched then
      local lang
      if arg == "-x" then i = i + 1; lang = argv[i]
      elseif arg:sub(1, 2) == "-x" then lang = arg:sub(3) end
      if lang then out.language = lang:find("++", 1, true) and "cpp" or lang:match("^c") and "c" or nil end
      if arg:match("^%-std=") then out.standard = arg:sub(6) end
    end
    i = i + 1
  end
  if not out.language and out.standard then out.language = out.standard:find("++", 1, true) and "cpp" or "c" end
  return out
end
return M
