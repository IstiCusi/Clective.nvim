local M = {}
local util = require("clective.util")
local uv = vim.uv or vim.loop
local cache, generation = {}, 0
function M.prefix(line)
  local delim, prefix = line:match('^%s*#%s*include%s*([<"])([^">]*)$')
  if not delim then return nil end
  local opening = line:find('[<"]')
  return { delimiter = delim, text = prefix, start = opening }
end
function M.directive(line)
  local delim, name = line:match('^%s*#%s*include%s*([<"])([^">]+)[">]')
  return name, delim
end
local extensions = { h=true, hpp=true, hh=true, hxx=true, inc=true, inl=true, ipp=true, tpp=true, def=true }
function M.is_header(name)
  local ext = name:match("%.([^.]*)$")
  return not ext or extensions[ext:lower()] == true
end
function M.roots(context, delimiter)
  local paths = {}
  if delimiter == '"' then
    paths[#paths + 1] = vim.fs.dirname(context.path)
    vim.list_extend(paths, context.quote_dirs)
  end
  vim.list_extend(paths, context.include_dirs)
  vim.list_extend(paths, context.system_dirs)
  vim.list_extend(paths, context.after_dirs or {})
  return util.unique(paths)
end
local function directory(path)
  local stamp = util.signature(path)
  if cache[path] and cache[path].stamp == stamp then return cache[path].files end
  local output, scan = {}, uv.fs_scandir(path)
  if scan then
    while true do
      local name, kind = uv.fs_scandir_next(scan)
      if not name then break end
      if kind == "link" then local s = uv.fs_stat(path .. "/" .. name); kind = s and s.type or kind end
      output[#output + 1] = { name = name, kind = kind }
    end
  end
  table.sort(output, function(a,b) return a.name < b.name end)
  cache[path] = { stamp = stamp, files = output }
  return output
end
function M.complete(context, prefix, delimiter)
  local head = prefix:match("^(.*[/])") or ""
  local leaf = prefix:sub(#head + 1)
  local output, seen = {}, {}
  for _, root in ipairs(M.roots(context, delimiter)) do
    local dir = head ~= "" and util.path(head, root) or root
    for _, entry in ipairs(directory(dir)) do
      if entry.name:sub(1, #leaf) == leaf and (entry.kind == "directory" or M.is_header(entry.name)) then
        local label = head .. entry.name .. (entry.kind == "directory" and "/" or "")
        if not seen[label] then
          seen[label] = true
          output[#output + 1] = { label = label, path = dir .. "/" .. entry.name, directory = entry.kind == "directory" }
        end
      end
    end
  end
  return output
end
function M.resolve(context, name, delimiter)
  if name:match("^/") and vim.fn.filereadable(name) == 1 then return util.path(name) end
  for _, root in ipairs(M.roots(context, delimiter)) do
    local path = util.path(name, root)
    if vim.fn.filereadable(path) == 1 then return path end
  end
end
-- Yield between directory batches, cap work, and never follow a symlink cycle.
function M.list(context, limit, callback)
  generation = generation + 1
  local token = generation
  local queue, output, labels, visited = {}, {}, {}, {}
  for _, root in ipairs(M.roots(context, '"')) do
    queue[#queue + 1] = { root = root, dir = root, relative = "" }
  end
  local index, count = 1, 0
  local function step()
    if token ~= generation then return end
    local until_time = uv.hrtime() + 8e6
    while index <= #queue and #output < limit and count < limit * 3 and uv.hrtime() < until_time do
      local job = queue[index]; index = index + 1; count = count + 1
      local real = uv.fs_realpath(job.dir)
      local key = job.root .. "\0" .. tostring(real)
      if real and not visited[key] then
        visited[key] = true
        for _, entry in ipairs(directory(job.dir)) do
          if entry.name:sub(1,1) ~= "." then
            local relative, path = job.relative .. entry.name, job.dir .. "/" .. entry.name
            if entry.kind == "directory" then queue[#queue + 1] = { root=job.root, dir=path, relative=relative .. "/" }
            elseif M.is_header(entry.name) and not labels[relative] then
              labels[relative] = true; output[#output + 1] = { label=relative, path=path }
              if #output >= limit then break end
            end
          end
        end
      end
    end
    if index <= #queue and #output < limit and count < limit * 3 then vim.schedule(step)
    else
      table.sort(output, function(a,b) return a.label < b.label end)
      callback(output, index <= #queue or #output >= limit)
    end
  end
  vim.schedule(step)
end
function M.clear() cache = {}; generation = generation + 1 end
return M
