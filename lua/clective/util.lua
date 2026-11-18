local M = {}
local uv = vim.uv or vim.loop
function M.path(value, base)
  if not value or value == "" then return nil end
  value = value:gsub("^~", vim.env.HOME or "~")
    :gsub("%$" .. "{([%w_]+)}", function(k) return vim.env[k] or "$" .. "{" .. k .. "}" end)
    :gsub("%$([%w_]+)", function(k) return vim.env[k] or "$" .. k end)
  value = value:gsub("/%*%*$", ""):gsub("/+$", "")
  if value == "" then value = "/" end
  if not value:match("^/") and not value:match("^%a:[/\\]") then value = (base or uv.cwd()) .. "/" .. value end
  return vim.fs.normalize(value)
end
function M.under(path, root) return path == root or path:sub(1, #root + 1) == root .. "/" end
function M.read(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local value = file:read("*a"); file:close()
  return value
end
function M.json(path)
  local text = M.read(path)
  if not text then return nil end
  local ok, value = pcall(vim.json.decode, text)
  if ok and type(value) == "table" then return value end
  return nil, "Invalid JSON: " .. path
end
function M.write_json(path, data)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temp = path .. "." .. uv.os_getpid() .. "." .. tostring(uv.hrtime()) .. ".tmp"
  local file, message = io.open(temp, "wb")
  if not file then return nil, message end
  local ok, error_message = file:write(vim.json.encode(data)); file:close()
  if not ok then os.remove(temp); return nil, error_message end
  local renamed, err = uv.fs_rename(temp, path)
  if not renamed then os.remove(temp) end
  return renamed, err
end
function M.signature(path)
  local s = uv.fs_stat(path)
  return s and (s.size .. ":" .. s.mtime.sec .. ":" .. s.mtime.nsec) or "missing"
end
function M.unique(values)
  local output, seen = {}, {}
  for _, value in ipairs(values) do
    if value and value ~= "" and not seen[value] then seen[value] = true; output[#output + 1] = value end
  end
  return output
end
function M.bufnr(buffer) return buffer and buffer ~= 0 and buffer or vim.api.nvim_get_current_buf() end
function M.language(path)
  local ext = path:match("%.([^./]+)$")
  if ext == "c" then return "c" end
  if ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "C" or ext == "hpp"
    or ext == "hh" or ext == "hxx" or ext == "ipp" or ext == "tpp" then return "cpp" end
end
function M.supported(buffer)
  buffer = M.bufnr(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].buftype ~= "" then return false end
  local path = vim.api.nvim_buf_get_name(buffer)
  if path == "" then return false end
  local ft = vim.bo[buffer].filetype
  return ft == "c" or ft == "cpp" or M.language(path) ~= nil or path:match("%.h$") ~= nil
end
function M.root(path, markers)
  local directory = vim.fs.dirname(path)
  local found = vim.fs.find(markers, { path = directory, upward = true })[1]
  if found then return M.path(vim.fs.dirname(found)) end
  local cwd = M.path(uv.cwd())
  return M.under(path, cwd) and cwd or directory
end
-- Tokenize a compile command without executing or expanding shell expressions.
function M.words(command)
  local words, word, quote, active, i = {}, {}, nil, false, 1
  while i <= #command do
    local c = command:sub(i, i)
    if c == "\\" and quote ~= "'" then
      local nextc = command:sub(i + 1, i + 1)
      if quote == '"' and nextc ~= "$" and nextc ~= string.char(96) and nextc ~= '"' and nextc ~= "\\" then word[#word + 1] = c
      else i = i + 1; word[#word + 1] = nextc end
      active = true
    elseif quote then
      if c == quote then quote = nil else word[#word + 1] = c end
    elseif c == "'" or c == '"' then quote = c; active = true
    elseif c:match("%s") then
      if active then words[#words + 1] = table.concat(word); word = {}; active = false end
    else word[#word + 1] = c; active = true end
    i = i + 1
  end
  if quote then return nil, "Unterminated quote in compile command" end
  if active then words[#words + 1] = table.concat(word) end
  return words
end
function M.notify(message, level) vim.notify("clective: " .. tostring(message), level or vim.log.levels.INFO) end
return M
