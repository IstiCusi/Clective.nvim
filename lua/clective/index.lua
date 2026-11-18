local M = {}
local uv = vim.uv or vim.loop
local blocked = { [".git"]=true, [".cache"]=true, node_modules=true, build=true, target=true }
local generation = 0
function M.scan(root, limit, callback)
  generation = generation + 1
  local token, queue, paths, index, visits = generation, {root}, {}, 1, 0
  local function step()
    if token ~= generation then return end
    local until_time = uv.hrtime() + 8e6
    while index <= #queue and #paths < limit and visits < limit * 10 and uv.hrtime() < until_time do
      local dir = queue[index]; index = index + 1; visits = visits + 1
      local scan = uv.fs_scandir(dir)
      if scan then
        while true do
          local name, kind = uv.fs_scandir_next(scan)
          if not name then break end
          local path = dir .. "/" .. name
          if kind == "directory" and not blocked[name] and name:sub(1,1) ~= "." then queue[#queue + 1] = path
          elseif kind == "file" then
            local ext = name:match("%.([^.]*)$")
            if ext and vim.tbl_contains({"c","cpp","cc","cxx","C"},ext) then paths[#paths + 1] = path end
            if #paths >= limit then break end
          end
        end
      end
    end
    if index <= #queue and #paths < limit and visits < limit * 10 then vim.schedule(step)
    else table.sort(paths); callback(paths, index <= #queue or #paths >= limit) end
  end
  vim.schedule(step)
end
return M
