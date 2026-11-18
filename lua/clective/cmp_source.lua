
-- clective/cmp_source.lua
-- nvim-cmp source für #include <> und #include ""

local source = {}

function source:is_available()
  return vim.bo.filetype == "c" or vim.bo.filetype == "cpp"
end

-- erlaubt auch "/" im Keyword
function source:get_keyword_pattern()
  return [[\%(\k\|/\)\+]]
end

function source:complete(params, callback)
  local line = params.context.cursor_before_line

  -- delim = < oder " ; prefix = bisheriger Inhalt (inkl. /, falls vorhanden)
  local delim, prefix = line:match('#%s*include%s*([<"])([^">]*)')
  if not prefix or prefix == "" then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local matches = {}

  -- Hilfsfunktion: scannt ein glob und fügt Treffer ein
  local function scan(glob, base_prefix)
    for _, f in ipairs(vim.fn.glob(glob, 0, 1)) do
      if vim.fn.isdirectory(f) == 1 then
        local name = f:match("[^/]+$")
        table.insert(matches, { label = name .. "/" })

        -- Inhalte des Ordners gleich mit anbieten
        local subglob = f .. "/*"
        for _, sf in ipairs(vim.fn.glob(subglob, 0, 1)) do
          if vim.fn.isdirectory(sf) == 1 then
            table.insert(matches, { label = name .. "/" .. sf:match("[^/]+$") .. "/" })
          else
            table.insert(matches, { label = name .. "/" .. sf:match("[^/]+$") })
          end
        end
      else
        -- Dateien direkt hinzufügen
        if base_prefix:sub(-1) == "/" then
          table.insert(matches, { label = base_prefix .. f:match("[^/]+$") })
        else
          table.insert(matches, { label = f:match("[^/]+$") })
        end
      end
    end
  end

  -- Bei "" zuerst Buffer-Verzeichnis
  if delim == '"' then
    local buf_dir = vim.fn.expand("%:p:h")
    if vim.fn.isdirectory(buf_dir) == 1 then
      scan(buf_dir .. "/" .. prefix .. "*", prefix)
    end
  end

  -- Dann alle 'path'-Einträge
  local paths = vim.split(vim.o.path, ",")
  for _, p in ipairs(paths) do
    local dir = p:gsub("/%*%*$", "")
    if vim.fn.isdirectory(dir) == 1 then
      scan(dir .. "/" .. prefix .. "*", prefix)
    end
  end

  callback({ items = matches, isIncomplete = false })
end

function source.new()
  return setmetatable({}, { __index = source })
end

return source
