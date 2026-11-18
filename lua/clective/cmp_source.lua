local source = {}
local headers = require("clective.headers")
function source:is_available() return require("clective.util").supported(0) end
function source:get_keyword_pattern() return [[\%(\k\|/\|\.\|-\)\+]] end
function source:get_trigger_characters() return { "<", '"', "/" } end
function source:get_position_encoding_kind() return "utf-8" end
function source:complete(params, callback)
  local prefix = headers.prefix(params.context.cursor_before_line)
  local context = require("clective").context(params.context.bufnr or 0)
  if not prefix or not context then callback({ items={}, isIncomplete=false }); return end
  local row = params.context.cursor.row - 1
  local ending = #params.context.cursor_before_line
  local tail = (params.context.cursor_line or ""):sub(ending + 1):match('^[^">]*') or ""
  local items = {}
  for index, entry in ipairs(headers.complete(context, prefix.text, prefix.delimiter)) do
    items[#items + 1] = {
      label = entry.label, filterText = entry.label,
      kind = entry.directory and 19 or 17, detail = entry.path,
      documentation = { kind="plaintext", value=context.label .. "\n" .. entry.path },
      sortText = string.format("%06d", index),
      textEdit = {
        newText = entry.label,
        range = { start = {line=row, character=prefix.start}, ["end"] = {line=row, character=ending + #tail} },
      },
    }
  end
  callback({ items=items, isIncomplete=true })
end
function source.new() return setmetatable({}, {__index=source}) end
return source
