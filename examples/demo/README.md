# Try Clective without an external SDK

From Neovim, load:

```vim
:luafile /absolute/path/to/Clective.nvim/examples/demo/profile-setup.lua
```

This adds three demo profiles for the current session, opens project/main.c,
and selects Demo SDK A. No external SDK is required. clangd must be installed
and attached for the symbol checks.

1. Jump to the definition of platform_value from main.c. SDK A returns 1.
2. Select Demo SDK B with ClectiveProfile and repeat. Its header returns 2.
3. Complete exec/li inside an include. The result is exec/libraries.h.
4. Open the include with gf or ClectiveOpen; it keeps the source project context.
5. Open shared.h and select Demo C++ with ClectiveProfile! for this file.
   The filetype becomes cpp and clangd sees the demo::Example class.
6. ClectiveReset! returns shared.h to the project's C language context.
7. In main.c, run ClectiveIndex, then use your workspace-symbol picker to find
   demo_unopened_symbol in helper.c without opening that file first.

Reload profile-setup.lua after a Neovim restart to define the demo profiles again.
The headers demonstrate profile selection; they do not emulate a real retro SDK.
