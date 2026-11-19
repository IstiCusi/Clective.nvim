# Moving from the local Clective script to the GitHub plugin

Replace the local Lazy source:

```lua
dir = vim.fn.stdpath("config") .. "/scripts/clective",
```

with the repository source:

```lua
"IstiCusi/Clective.nvim",
name = "clective",
main = "clective",
```

Keep your existing profiles and keys. Keep only one Clective specification;
do not load the local script and GitHub plugin together. Restart Neovim and
install Clective through Lazy. The previous scripts/clective directory can be
kept as a backup while you check the switch.

The profile-based local version already uses
`stdpath("state") .. "/clective/state.json"`. Its project and file selections
continue to work when their profile IDs and state_file setting are unchanged.
The earlier global scripts/clective/state.json is not imported because it does
not identify which project or file owned its single selection.

Use a statusline component such as:

```lua
function()
  local ok, clective = pcall(require, "clective")
  return ok and clective.status() or vim.bo.filetype
end
```

For a former header-search mapping, use `:ClectiveHeaders` or
`require("clective").browse()`.

Keep your existing clangd client. Remove a hardcoded
`--compile-commands-dir=.` if it prevents clangd from finding the appropriate
build database. Clective sends effective per-file commands to that client.
It does not change the compiler used by your build.

The public plugin includes no installer that rewrites other Neovim plugins.
Personal SDK paths belong in your own Lazy opts. New users can start from
[examples/lazy.lua](examples/lazy.lua).
