local M = {}
-- Existing Space f i mapping now uses the current buffer's Clective profile.
function M.search_standard_includes()
  require("clective").browse()
end
return M
