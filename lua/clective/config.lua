local M = {}


M.include_configs = {
["c++-12"] = {
-- C++ Standard-Bibliothek
"/usr/include/c++/12",
"/usr/include/c++/12/x86_64-linux-gnu",


-- GCC Builtins
"/usr/lib/gcc/x86_64-linux-gnu/12/include",


-- System-Header: erst Top-Level, danach rekursiv (wird in init.lua umgesetzt)
"/usr/include",
"/usr/include/x86_64-linux-gnu",


-- Lokale Overrides
"/usr/local/include",
},


["c-12"] = {
-- GCC Builtins
"/usr/lib/gcc/x86_64-linux-gnu/12/include",


-- System-Header (Top-Level zuerst)
"/usr/include",
"/usr/include/x86_64-linux-gnu",


-- Lokale Overrides
"/usr/local/include",
},


["c64"] = {
"/home/phonon/Development/lang/C64-oscar64/include",
},
}


--- Merge user-defined include configurations into the default include table.
--- Replaces existing include lists for any matching keys.
--- @param user_configs table<string, string[]> A table of include configurations,
--- where each key corresponds to a language/toolchain (e.g. "c++-12") and the value
--- is a list of include paths.
function M.merge(user_configs)
if not user_configs then return end
for k, v in pairs(user_configs) do
M.include_configs[k] = v
end
end


--- Appends additional include paths to the existing list for a given configuration key.
--- If the key does not exist, it initializes a new include list.
--- The provided includes are appended to the end of the existing list.
--- @param key string The configuration key (e.g. "c++-12", "c64").
--- @param new_includes string[] A list of include paths to append.
function M.append_includes(key, new_includes)
if type(new_includes) ~= "table" then return end
if M.include_configs[key] == nil then
M.include_configs[key] = {}
end
vim.list_extend(M.include_configs[key], new_includes)
end


return M
