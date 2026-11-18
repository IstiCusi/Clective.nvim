local M = {}
local api = vim.api
local util = require("clective.util")
local state = require("clective.state")
local build = require("clective.build")
local headers = require("clective.headers")
local contexts, inherited, originals, applying = {}, {}, {}, {}
local options, queued = nil, false
local indexed = {}

function M.options()
  if not options then M.setup() end
  return options
end

local function append_flags(command, flag, paths, root)
  for _, path in ipairs(paths) do
    command[#command + 1] = flag
    command[#command + 1] = util.path(path, root)
  end
end

local function resolve(buffer, requested)
  local path = requested and requested.path or util.path(api.nvim_buf_get_name(buffer))
  local from = inherited[path]
  local root = requested and requested.root or from and from.root or util.root(path, options.root_markers)
  local file_choice, project_choice = state.get(root, path)
  local source_choice = from and from.use_file_override ~= false and state.get(root, from.source) or nil
  local id = file_choice or source_choice or project_choice or options.default_profile
  if not options.profiles[id] then id = options.default_profile end
  local profile = options.profiles[id]
  local entry = profile.build == "merge" and build.load(path, root, options, from and from.source) or nil
  local command = build.clean(entry)
  local directory = entry and entry.directory or root
  local flags = build.flags(command, directory)
  local language = util.language(path)
  local language_origin = language and "file extension" or nil
  if not language and profile.language ~= "auto" then language, language_origin = profile.language, "profile" end
  if not language then
    language = flags.language or (entry and entry.file and util.language(entry.file))
    if language then language_origin = "build command" end
  end
  if not language and from then language, language_origin = from.language, "including source" end
  if not language then
    language = (originals[buffer] and originals[buffer].filetype or vim.bo[buffer].filetype) == "cpp" and "cpp" or "c"
    language_origin = "editor fallback"
  end
  command[1] = profile.compiler or command[1] or (language == "cpp" and "clang++" or "clang")
  if profile.compiler and profile.compiler:find("/",1,true) then command[1] = util.path(profile.compiler, root) end
  vim.list_extend(command, profile.compiler_args)
  vim.list_extend(command, { "-x", language == "cpp" and "c++" or "c" })
  if profile.standard then command[#command + 1] = "-std=" .. profile.standard end
  if profile.target then command[#command + 1] = "--target=" .. profile.target end
  if profile.sysroot then command[#command + 1] = "--sysroot=" .. util.path(profile.sysroot, root) end
  if profile.system_headers == false then command[#command + 1] = "-nostdinc" end
  append_flags(command, "-iquote", profile.quote_dirs, root)
  append_flags(command, "-I", profile.include_dirs, root)
  append_flags(command, "-isystem", profile.system_dirs, root)
  local discovery = require("clective.compiler").paths(profile, language, root, function() M.refresh() end)
  append_flags(command, "-isystem", discovery.paths, root)
  for _, define in ipairs(profile.defines) do command[#command + 1] = "-D" .. define end
  vim.list_extend(command, profile.flags)
  command[#command + 1] = path
  local parsed = build.flags(command, directory)
  local warnings = {}
  if entry and entry.error then warnings[#warnings + 1] = entry.error end
  if discovery.error then warnings[#warnings + 1] = discovery.error end
  if profile.language ~= "auto" and profile.language ~= language then
    warnings[#warnings + 1] = "Explicit source extension is " .. language .. "; profile language is " .. profile.language
  end
  local context = {
    buffer=buffer, path=path, root=root, profile=id, label=profile.label, language=language,
    source=from and from.source or path,
    language_origin=language_origin, scope=file_choice and "file" or source_choice and "inherited" or project_choice and "project" or from and "inherited" or "default",
    command=command, directory=directory, build_file=entry and entry.origin, inferred=entry and entry.inferred or false,
    include_dirs=util.unique(parsed.include_dirs), quote_dirs=util.unique(parsed.quote_dirs),
    system_dirs=util.unique(parsed.system_dirs), after_dirs=util.unique(parsed.after_dirs),
    discovering=discovery.pending or false, warnings=warnings, missing_dirs={},
  }
  for _, dir in ipairs(headers.roots(context, '"')) do
    if vim.fn.isdirectory(dir) ~= 1 then context.missing_dirs[#context.missing_dirs + 1] = dir end
  end
  return context
end

function M.context(buffer)
  buffer = util.bufnr(buffer)
  M.options()
  if not util.supported(buffer) then return nil end
  if not contexts[buffer] then M.apply(buffer) end
  return contexts[buffer]
end

function M.apply(buffer)
  buffer = util.bufnr(buffer)
  if applying[buffer] or not util.supported(buffer) then return end
  applying[buffer] = true
  local ok, message = xpcall(function()
    if not originals[buffer] then
      originals[buffer] = { path=vim.bo[buffer].path, suffixesadd=vim.bo[buffer].suffixesadd, filetype=vim.bo[buffer].filetype }
    end
    local context = resolve(buffer)
    contexts[buffer] = context
    if vim.bo[buffer].filetype ~= context.language then vim.bo[buffer].filetype = context.language end
    local paths = { "." }
    for _, path in ipairs(headers.roots(context, '"')) do paths[#paths + 1] = vim.fn.escape(path, " ,\\") end
    vim.bo[buffer].path = table.concat(paths, ",")
    vim.bo[buffer].suffixesadd = context.language == "cpp" and ".h,.hpp,.hh,.hxx,.ipp,.tpp" or ".h"
    if options.map_gf then
      local mapping = api.nvim_buf_call(buffer, function() return vim.fn.maparg("gf", "n", false, true) end)
      if vim.tbl_isempty(mapping) or mapping.desc == "Clective: open include" then
        vim.keymap.set("n", "gf", function()
          if headers.directive(api.nvim_get_current_line()) then M.open()
          else vim.cmd.normal({ args={"gf"}, bang=true }) end
        end, {buffer=buffer, silent=true, desc="Clective: open include"})
      end
    end
    if options.clangd.enabled and options.profiles[context.profile].clangd ~= false then
      require("clective.clangd").sync(context)
    end
    api.nvim_exec_autocmds("User", {pattern="ClectiveProfileChanged", modeline=false, data={buffer=buffer, profile=context.profile}})
    vim.cmd.redrawstatus()
  end, debug.traceback)
  applying[buffer] = nil
  if not ok then util.notify(message, vim.log.levels.ERROR) end
end

function M.refresh()
  if queued then return end
  queued = true
  vim.schedule(function()
    queued = false; headers.clear()
    for _, buffer in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(buffer) and util.supported(buffer) then M.apply(buffer) end
    end
    for root, job in pairs(indexed) do
      if api.nvim_buf_is_valid(job.buffer) then M.sync_index(root) end
    end
  end)
end

function M.sync_index(root)
  local job = indexed[root]
  if not job or not api.nvim_buf_is_valid(job.buffer) or not options.clangd.enabled then return end
  local all = {}
  for _, path in ipairs(job.paths) do
    if vim.fn.filereadable(path) == 1 then
      local context = resolve(job.buffer,{path=path,root=root})
      if options.profiles[context.profile].clangd ~= false then all[#all+1] = context end
    end
  end
  return require("clective.clangd").sync_many(job.buffer,all)
end

function M.index()
  local context = M.context(0)
  if not context then return end
  require("clective.index").scan(context.root,options.max_sources,function(paths,truncated)
    if not api.nvim_buf_is_valid(context.buffer) then return end
    indexed[context.root] = {buffer=context.buffer,paths=paths}
    local clients = M.sync_index(context.root) or 0
    util.notify(#paths .. " source commands sent to " .. clients .. " clangd client(s)" .. (truncated and " (scan limited)" or ""))
  end)
end

function M.apply_config(name, scope, buffer)
  buffer = util.bufnr(buffer)
  local context = M.context(buffer)
  if not context then util.notify("Open a named C/C++ source or header first"); return false end
  if not options.profiles[name] then util.notify("Unknown profile: " .. tostring(name), vim.log.levels.ERROR); return false end
  local kind = scope == "buffer" or scope == "file"
  state.set(kind and "files" or "projects", kind and context.path or context.root, name)
  -- Selecting a project profile should also remove this file's older override.
  if not kind then
    state.set("files", context.path, nil)
    if inherited[context.path] then inherited[context.path].use_file_override = false end
  end
  M.apply(buffer); M.refresh()
  return true
end

function M.select_config(scope)
  local buffer = api.nvim_get_current_buf()
  if not M.context(buffer) then util.notify("Open a C/C++ file first"); return end
  local keys = vim.tbl_keys(options.profiles)
  table.sort(keys, function(a,b) return options.profiles[a].label < options.profiles[b].label end)
  vim.ui.select(keys, {
    prompt=scope == "buffer" and "File profile:" or "Project profile:",
    format_item=function(id)
      local p=options.profiles[id]
      return p.label .. "  [" .. (p.language == "cpp" and "C++" or p.language == "c" and "C" or "build") .. "]"
    end,
  }, function(choice)
    if choice and api.nvim_buf_is_valid(buffer) then M.apply_config(choice, scope, buffer) end
  end)
end

function M.reset(scope)
  local context = M.context(0)
  if not context then return end
  local kind = scope == "buffer"
  state.set(kind and "files" or "projects", kind and context.path or context.root, nil)
  if not kind then state.set("files", context.path, nil) end
  if not kind and inherited[context.path] then inherited[context.path].use_file_override = false end
  M.apply(context.buffer); M.refresh()
end

function M.status(buffer)
  if not buffer and type(vim.g.statusline_winid) == "number" and api.nvim_win_is_valid(vim.g.statusline_winid) then
    buffer = api.nvim_win_get_buf(vim.g.statusline_winid)
  end
  buffer = util.bufnr(buffer)
  local context = contexts[buffer]
  if not context then return vim.bo[buffer].filetype end
  return (context.language == "cpp" and "C++" or "C") .. " · " .. context.label .. (context.discovering and " …" or "")
end

function M.open_path(path, source_buffer, split)
  local context = M.context(source_buffer)
  path = util.path(path, context and context.root)
  if context then
    inherited[path] = {root=context.root, profile=context.profile, language=context.language, source=context.source}
  end
  vim.cmd((split and "vsplit " or "edit ") .. vim.fn.fnameescape(path))
  contexts[api.nvim_get_current_buf()] = nil
  M.apply(api.nvim_get_current_buf())
end

function M.open(name, split)
  local context = M.context(0)
  if not context then return end
  local found_name, delimiter = headers.directive(api.nvim_get_current_line())
  name = name and name ~= "" and name or found_name
  if not name then util.notify("Place the cursor on an #include directive"); return end
  local path = headers.resolve(context, name, delimiter or '"')
  if not path then util.notify("Header not found in " .. context.label .. ": " .. name, vim.log.levels.WARN); return end
  M.open_path(path, context.buffer, split)
end

function M.browse()
  local context = M.context(0)
  if not context then util.notify("Open a C/C++ file first"); return end
  headers.list(context, options.max_headers, function(items, truncated)
    if truncated then util.notify("Header list limited to " .. #items .. " entries") end
    if #items == 0 then util.notify("No headers in " .. context.label); return end
    local ok, pickers = pcall(require, "telescope.pickers")
    local function open(item)
      if item and api.nvim_buf_is_valid(context.buffer) then M.open_path(item.path, context.buffer) end
    end
    if not ok then vim.ui.select(items, {prompt=context.label, format_item=function(item) return item.label end}, open); return end
    local actions, action_state = require("telescope.actions"), require("telescope.actions.state")
    pickers.new({}, {
      prompt_title="Includes · " .. context.label,
      finder=require("telescope.finders").new_table({results=items, entry_maker=function(item)
        return {value=item, display=item.label, ordinal=item.label, filename=item.path}
      end}),
      sorter=require("telescope.config").values.generic_sorter({}),
      previewer=require("telescope.config").values.file_previewer({}),
      attach_mappings=function(prompt)
        actions.select_default:replace(function()
          local selection=action_state.get_selected_entry()
          actions.close(prompt); open(selection and selection.value)
        end)
        return true
      end,
    }):find()
  end)
end

function M.info()
  local c = M.context(0)
  if not c then util.notify("Open a C/C++ file first"); return end
  local lines = {
    "Clective", "", "Profile: " .. c.label .. " [" .. c.profile .. "]", "Selection: " .. c.scope,
    "File: " .. c.path, "Project: " .. c.root, "Language: " .. c.language .. " (" .. c.language_origin .. ")",
    "Build settings: " .. (c.build_file or "profile / fallback") .. (c.inferred and " (inferred)" or ""),
    "Working directory: " .. c.directory, "",
  }
  for _, item in ipairs({{"Quote includes",c.quote_dirs},{"Includes",c.include_dirs},{"System includes",c.system_dirs},{"After includes",c.after_dirs}}) do
    lines[#lines+1] = item[1] .. ":"
    for _, path in ipairs(item[2]) do lines[#lines+1] = "  " .. path end
  end
  lines[#lines+1] = ""; lines[#lines+1] = "clangd compile command (one argument per line):"
  for _, arg in ipairs(c.command) do lines[#lines+1] = "  " .. arg end
  lines[#lines+1] = ""; lines[#lines+1] = "Attached clangd clients: " .. #vim.lsp.get_clients({bufnr=c.buffer,name="clangd"})
  for _, path in ipairs(c.missing_dirs) do lines[#lines+1] = "Missing directory: " .. path end
  for _, warning in ipairs(c.warnings) do lines[#lines+1] = "Warning: " .. warning end
  vim.cmd("botright new")
  local buffer = api.nvim_get_current_buf()
  vim.bo[buffer].buftype, vim.bo[buffer].bufhidden, vim.bo[buffer].swapfile = "nofile", "wipe", false
  api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].filetype, vim.bo[buffer].modifiable = "text", false
  vim.keymap.set("n","q","<cmd>close<CR>",{buffer=buffer,silent=true})
end

function M.setup(opts)
  if vim.fn.has("nvim-0.11") ~= 1 then util.notify("Neovim 0.11 or newer is required",vim.log.levels.WARN); return end
  options = require("clective.config").resolve(opts)
  state.setup(util.path(options.state_file))
  contexts = {}
  local group = api.nvim_create_augroup("Clective", {clear=true})
  api.nvim_create_autocmd({"BufEnter","BufWinEnter","FileType"}, {group=group, callback=function(event) M.apply(event.buf) end})
  api.nvim_create_autocmd("BufWritePost", {group=group, pattern={"compile_commands.json","compile_flags.txt",".clangd"},
    callback=function() M.refresh() end})
  api.nvim_create_autocmd({"DirChanged","FocusGained"}, {group=group, callback=function() M.refresh() end})
  api.nvim_create_autocmd("LspAttach", {group=group, callback=function(event)
    vim.schedule(function()
      if api.nvim_buf_is_valid(event.buf) then
        M.apply(event.buf)
        local context = contexts[event.buf]
        if context and indexed[context.root] then
          indexed[context.root].buffer = event.buf; M.sync_index(context.root)
        end
      end
    end)
  end})
  api.nvim_create_autocmd("LspDetach", {group=group, callback=function(event)
    if event.data then require("clective.clangd").forget(event.data.client_id) end
  end})
  api.nvim_create_autocmd({"InsertEnter","TextChangedI","CursorMovedI"}, {group=group, callback=function(event)
    require("clective.completion").update(event.buf)
  end})
  api.nvim_create_autocmd({"InsertLeave","BufLeave"}, {group=group, callback=function(event)
    require("clective.completion").update(event.buf,true)
  end})
  api.nvim_create_autocmd("BufWipeout", {group=group, callback=function(event)
    contexts[event.buf], originals[event.buf] = nil, nil
    require("clective.completion").forget(event.buf)
  end})
  require("clective.completion").register()
  local function command(name, callback, settings)
    settings = vim.tbl_extend("force", settings or {}, {force=true})
    api.nvim_create_user_command(name, callback, settings)
  end
  command("ClectiveProfile", function(c)
    if c.args == "" then M.select_config(c.bang and "buffer" or "project")
    else M.apply_config(c.args,c.bang and "buffer" or "project") end
  end, {nargs="?",bang=true,complete=function() local names=vim.tbl_keys(options.profiles);table.sort(names);return names end,
    desc="Choose a project profile; ! chooses a file override"})
  command("ClectiveReset", function(c) M.reset(c.bang and "buffer" or "project") end, {bang=true})
  command("ClectiveInfo", M.info, {desc="Show effective profile, include paths and clangd command"})
  command("ClectiveHeaders", M.browse, {desc="Browse headers from the effective profile"})
  command("ClectiveIndex", M.index, {desc="Supply project source commands to clangd for background indexing"})
  command("ClectiveOpen", function(c) M.open(c.args,c.bang) end, {nargs="?",bang=true})
  command("ClectiveRefresh", function()
    require("clective.compiler").clear(); M.refresh()
  end, {})
  command("ClectiveSwitch", function() require("clective.clangd").switch(api.nvim_get_current_buf()) end, {})
  M.refresh()
end
return M

