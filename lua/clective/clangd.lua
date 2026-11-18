local M = {}
local sent = {}
function M.sync(context, client_id)
  local clients = vim.lsp.get_clients({ bufnr = context.buffer, name = "clangd" })
  local signature = vim.json.encode({ context.directory, context.command })
  context.clangd_clients = {}
  for _, client in ipairs(clients) do
    if not client_id or client.id == client_id then
      context.clangd_clients[#context.clangd_clients + 1] = client.id
      sent[client.id] = sent[client.id] or {}
      if sent[client.id][context.path] ~= signature then
        local update = { [context.path] = { workingDirectory = context.directory, compilationCommand = context.command } }
        local ok = client:notify("workspace/didChangeConfiguration", { settings = { compilationDatabaseChanges = update } })
        if ok then sent[client.id][context.path] = signature end
      end
    end
  end
end
function M.forget(client_id) sent[client_id] = nil end
function M.sync_many(buffer, contexts)
  local clients = vim.lsp.get_clients({bufnr=buffer,name="clangd"})
  for _, client in ipairs(clients) do
    local updates = {}
    sent[client.id] = sent[client.id] or {}
    for _, context in ipairs(contexts) do
      local signature = vim.json.encode({context.directory,context.command})
      if sent[client.id][context.path] ~= signature then
        updates[context.path] = {workingDirectory=context.directory,compilationCommand=context.command}
      end
    end
    if not vim.tbl_isempty(updates) then
      local ok = client:notify("workspace/didChangeConfiguration",{settings={compilationDatabaseChanges=updates}})
      if ok then
        for _, context in ipairs(contexts) do sent[client.id][context.path] = vim.json.encode({context.directory,context.command}) end
      end
    end
  end
  return #clients
end
function M.switch(buffer)
  local client = vim.lsp.get_clients({ bufnr = buffer, name = "clangd" })[1]
  if not client then require("clective.util").notify("No clangd attached"); return end
  client:request("textDocument/switchSourceHeader", { uri = vim.uri_from_bufnr(buffer) }, function(err, uri)
    if err or not uri or uri == "" then require("clective.util").notify("No matching source/header"); return end
    vim.schedule(function() require("clective").open_path(vim.uri_to_fname(uri), buffer) end)
  end, buffer)
end
return M
