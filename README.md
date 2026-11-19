# Clective.nvim

Clective connects a C/C++ language context with a named set of SDK include
directories. Choose **Amiga C**, **Amiga NDK 3.5**, **C64/Oscar64**, or a native
C/C++ profile once, and use that context for include completion, header
navigation, the status line, and the existing clangd language server.

Repository: [IstiCusi/Clective.nvim](https://github.com/IstiCusi/Clective.nvim).
Native profiles are built in; SDK profiles point to your own SDK installations.
No SDK, compiler or language-server binary is bundled.

## What changes when you select a profile?

A profile contains a language, include paths and optional parsing settings.
Selecting it updates loaded C/C++ buffers belonging to that project. A second
project can keep another profile in the same Neovim session. You can also give
one file its own profile.

For example, select Amiga C in an Amiga project:

1. Typing `#include <exec/li` offers `exec/libraries.h` from that SDK.
2. Accepting the suggestion keeps the complete relative path.
3. `gf` on the include opens the header from the same search paths.
4. `:ClectiveHeaders` browses those headers.
5. An ambiguous `.h` file uses the selected C language context.
6. An attached clangd receives the corresponding language and include flags.
7. The status line reports the profile for the buffer it is displaying.

Selecting a profile **does not change your Makefile, CMake configuration or
actual build compiler**. It configures editing and analysis.

## Requirements

- Neovim **0.11 or newer**. Tested with 0.11.5 and 0.12.6.
- A configured **clangd** client for semantic features. Clective uses the
  existing client and does not install or start another one. Tested with
  clangd 19.1.2.
- **nvim-cmp**, optional, for include completion.
- **Telescope**, optional, for the header picker. Without it, the picker uses
  `vim.ui.select`.
- GCC or Clang only when an explicitly configured native compiler is queried
  for its default include paths.

Python is needed only to run the development tests, not to install or use the plugin.

## Install with lazy.nvim

Add this specification to your Neovim configuration, for example in
`lua/plugins/clective.lua`. Your existing clangd and nvim-cmp configuration
continues to supply semantic completion and completion key bindings.

```lua
return {
  "IstiCusi/Clective.nvim",
  name = "clective",
  main = "clective",
  lazy = false,
  dependencies = { "hrsh7th/nvim-cmp" },
  keys = {
    { "<leader>Kc", "<cmd>ClectiveProfile<CR>", desc = "Choose project profile" },
    { "<leader>Kb", "<cmd>ClectiveProfile!<CR>", desc = "Choose file profile" },
    { "<leader>Ki", "<cmd>ClectiveInfo<CR>", desc = "Show effective settings" },
  },
  opts = {
    default_profile = "project",
    profiles = {
      ["amiga-c"] = {
        label = "Amiga C",
        language = "c",
        build = "ignore",
        system_headers = false,
        include_dirs = { "~/SDKs/amiga/include" }, -- change to your SDK path
      },
    },
  },
}
```

Remove the example Amiga profile if you do not use that SDK. The built-in
`project`, `native-c` and `native-cpp` profiles remain available.

See [examples/lazy.lua](examples/lazy.lua) for a complete starter specification
with optional key bindings. Set your preferred `vim.g.mapleader` before
`require("lazy").setup(...)`; Clective does not change the leader.
Keep `main = "clective"` because the Lua module name is lowercase.
The core plugin defines no leader mappings.

If clangd is not configured yet, [examples/clangd.lua](examples/clangd.lua)
contains a minimal Neovim 0.11+ configuration. Use your existing LSP setup when
you already have one. Clective configures an attached server, so installing
only this plugin does not start clangd.

For a plain Neovim package installation:

```sh
git clone https://github.com/IstiCusi/Clective.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins/start/Clective.nvim"
```

The package loader supplies defaults. To configure SDKs, call
`require("clective").setup({ profiles = { ... } })` from your init.lua.
nvim-cmp remains optional; remove its dependency if you only need commands,
header navigation, status integration and clangd synchronization.

Coming from the old local script? See [MIGRATING.md](MIGRATING.md).

## First use

1. Open a C/C++ file and run `:ClectiveProfile`.
2. Choose the project's build settings, a native compiler profile or your SDK.
3. Use `:ClectiveInfo` to inspect the project root, paths and clangd command.
4. Type an include such as `#include <exec/`, or use `:ClectiveHeaders`.

With the key bindings in examples/lazy.lua and a Space leader:

| Shortcut | Action |
| --- | --- |
| Space K c | Project profile |
| Space K b | File profile override |
| Space K i | Effective settings |
| Space K h | Find a header |
| Space K s | Switch source/header |
| Space K r | Refresh paths |
| Space K p | Index project sources |

`K` is uppercase. These bindings are examples; all commands also work directly.

## Profile settings

```lua
profiles = {
  my_sdk = {
    label = "My SDK · C++",
    language = "cpp",             -- "c", "cpp", or "auto"
    build = "merge",              -- "merge" or "ignore"
    include_dirs = { "include", "~/SDK/include" },
    quote_dirs = { "private" },
    system_dirs = { "~/SDK/system" },
    defines = { "FEATURE=1", "DEBUG" },
    standard = "c++20",
    -- compiler = "clang++",
    -- target = "...",           -- use a target supported by your clangd
    -- sysroot = "~/SDK/sysroot",
    -- compiler_args = {},
    -- flags = {},
    -- discover = true,          -- requires an explicit compiler
    -- system_headers = false,  -- add -nostdinc
    -- clangd = false,           -- disable synchronization for this profile
  },
}
```

| Setting | Meaning |
| --- | --- |
| `language` | Language for ambiguous headers; explicit C/C++ extensions keep their language. |
| `include_dirs` | Ordered `-I` directories; relative paths are relative to the project root. |
| `quote_dirs` | `-iquote` paths, used for quoted includes. |
| `system_dirs` | `-isystem` paths. |
| `defines` | Preprocessor definitions without the `-D` prefix. |
| `standard` | Parsing standard such as `c11` or `c++20`. |
| `compiler` | Driver identity passed to clangd; also the executable queried when `discover=true`. |
| `compiler_args` | Arguments included in both the driver query and the analysis command. |
| `target`, `sysroot` | Explicit parsing target and SDK root; Clective does not guess them. |
| `flags` | Extra analysis arguments, appended after the structured profile settings. |
| `build="merge"` | Keep discovered build arguments and append profile settings. Existing build include paths precede added paths. |
| `build="ignore"` | Construct the analysis command from the profile; useful for selecting an independent retro SDK. |
| `system_headers=false` | Disable implicit standard include paths with `-nostdinc`; explicit build/profile paths still apply. |
| `discover=true` | Query the configured GCC/Clang-compatible compiler asynchronously for default include paths. |

`~`, `$VARIABLE` and `${VARIABLE}` are expanded in configured directory paths.
Trailing slashes and the old `/**` notation are normalized. Completion walks the
directory being typed; it does not recursively invent shorter include names.

The built-in profiles are `project`, `native-c` and `native-cpp`. A user profile
with the same ID replaces that profile in full. Native profiles query `cc` or
`c++`; you can explicitly configure `gcc`, `g++`, `clang` or `clang++`.

Old list-only profiles are accepted for migration, but they cannot describe all
language and compiler settings. Use the structured form for new profiles.
The old global `scripts/clective/state.json` is no longer read.

## Build settings and .h files

The `project` profile reads `compile_commands.json` or `compile_flags.txt`.
Clective searches from the current file toward the detected project root; it
also checks configured `build_dirs` for a compilation database.
Defaults are `build_dirs = { "build" }`. For another layout:

```lua
build_dirs = { "build", "build/debug", "build/release" }
```

The nearest matching root marker establishes the Clective project:
`.git`, `compile_commands.json`, `compile_flags.txt`, `CMakeLists.txt` or
`Makefile`. Without a marker it uses the working directory if it contains
the file, otherwise the file's directory. Inspect the result with
`:ClectiveInfo`; use a project marker when files should share one selection.

CMake users should generate a real compilation database with
`CMAKE_EXPORT_COMPILE_COMMANDS` enabled. That database retains per-file flags
and is more precise than one global list of include paths.

For `compile_flags.txt`, write **one argument per line**:

```text
-I
include with spaces
-isystem
vendor/include
-DPROJECT_FEATURE=1
-std=c11
```

A `.h` suffix does not establish whether the file is C or C++. Resolution is:

1. Explicit extensions: `.c` is C; `.cpp`, `.cc`, `.cxx`, `.C`,
   `.hpp`, `.hh`, `.hxx`, `.ipp`, `.tpp` are C++.
2. For an ambiguous header, use the selected profile's explicit language.
3. With `language="auto"`, use the compilation command or an associated source
   entry. A matching basename is preferred when inferring a header command.
4. Use the including source's context when the header was opened through Clective.
5. Finally, fall back to the editor's original filetype.

Selecting a C profile while editing `main.cpp` therefore keeps C++ and reports
the mismatch in `:ClectiveInfo`. The profile can still supply its include paths.
It never renames files or rewrites their contents.

## Selection scope and persistence

`:ClectiveProfile amiga-c` selects a project profile.
`:ClectiveProfile! native-cpp` gives the current file an override. That override
is persisted by absolute filename, not merely by temporary buffer number.

Precedence is: current file override, an inherited source file override,
project selection, then the configured default. A project selection clears
the current file's older override; explicit overrides on other files remain.

State is stored under `stdpath("state") .. "/clective/state.json"`. You can
override `state_file`. Switching to a buffer in a different project applies
that project's selection. Updates use atomic file replacement; concurrent
Neovim processes can still race if both write at precisely the same time.

Opening a file does not create a saved file entry. Only explicit selections
are stored: one entry per selected project, plus any file overrides. These
are profile IDs, not copies of all include paths. Entries for renamed or
deleted files are not pruned in this version.

Headers opened with Clective retain the source project's context even outside
its root. One Neovim buffer for a shared SDK header can only hold one context:
opening that same header from another project changes the header buffer's
inherited context. The distinct source buffers keep their own profiles.

## Completion and navigation

Include completion recognizes `#include <...>` and `#include "..."`, including
an empty prefix and paths such as `exec/li`. It also offers directories and
extensionless standard-library headers such as `vector`.

Search order is:

- Quoted includes: the source directory, quote directories, normal include
  directories, system directories, then `-idirafter` directories.
- Angle includes: normal include directories, system directories, then
  `-idirafter` directories.

The first matching include name wins. Identical names from later roots do not
create duplicate completion entries. The completion detail shows the full path.
Lines starting with `// #include` are not treated as active includes.

While the cursor is inside an include, `exclusive_includes=true` temporarily
uses the Clective completion source. It restores the prior source configuration
when leaving the include or buffer, preserving other buffer completion settings.
Set it to `false` to combine sources yourself; add
`{ name="clective_includes", keyword_length=0 }` to your cmp sources in that case.

When no existing `gf` mapping owns the key, Clective installs a buffer mapping:
on an include it opens the resolved header; elsewhere it retains native `gf`.
Use `map_gf=false` to disable this mapping.

## Commands

| Command | Action |
| --- | --- |
| `:ClectiveProfile [id]` | Select a project profile; omit ID for a picker. |
| `:ClectiveProfile! [id]` | Select an override for the current file. |
| `:ClectiveReset` | Clear the project selection and current file override. |
| `:ClectiveReset!` | Clear only the current file override. |
| `:ClectiveInfo` | Show profile, scope, language origin, paths, missing directories and command sent to clangd. Close with `q`. |
| `:ClectiveHeaders` | Browse headers using Telescope or `vim.ui.select`. |
| `:ClectiveOpen [include]` | Open an include; without an argument, read the directive under the cursor. |
| `:ClectiveOpen! [include]` | Open the header in a vertical split. |
| `:ClectiveSwitch` | Ask clangd for the corresponding source/header. |
| `:ClectiveRefresh` | Refresh loaded buffers, build settings and compiler include discovery. |
| `:ClectiveIndex` | Scan project sources and send their commands to attached clangd for background indexing. |
| `:checkhealth clective` | Check requirements and loaded buffer contexts. |

The header browser defaults to at most 20,000 entries. Project indexing defaults
to 5,000 sources, skips hidden directories, `node_modules`, `build` and
`target`, and does not follow directory symlinks. Configure `max_headers` and
`max_sources` as needed. Directory scanning yields between batches; clangd
indexing runs in the language server and may take time.

`:ClectiveIndex` is useful for small projects without a compilation database:
it makes commands available for files that have never been opened. Re-run it
after adding source files. A real compilation database is preferable for a
large or generated project. Profile changes also update commands already
submitted by Clective in that session.

## clangd, symbols and retro compilers

**Keep clangd.** Include paths alone cannot provide semantic definitions,
references, completion, rename or workspace symbols. Clective supplies parsing
context; clangd supplies those semantic features. Existing Neovim/Telescope LSP
bindings continue to work.

Clective sends per-file commands through clangd's documented
`workspace/didChangeConfiguration` compilation-command extension. It does not
rewrite a project's compilation database to switch a profile. The source/header
command uses `textDocument/switchSourceHeader`.

Amiga SDK selection and Oscar64 SDK selection do **not** make clangd an Amiga
or 6502 compiler. Unsupported compiler extensions, pragmas, builtins and ABI
differences can still produce inaccurate diagnostics. Configure supported
target flags and genuine SDK definitions when available. The supplied retro
profiles disable implicit host headers, but deliberately do not invent target
triples or compatibility macros.

If a project needs small compatibility declarations, keep them in a separate
analysis-only header and pass `-include` through that profile. Do not alter the
real SDK headers just to silence clangd.

## Status line and API

```lua
-- A lualine component, evaluated for the window being rendered:
function()
  return require("clective").status()
end
```

`status(bufnr)` supports an explicit buffer. The component uses cached context,
not JSON file reads on each redraw. A `User ClectiveProfileChanged` event carries
`data.buffer` and `data.profile` for other integrations.

Public entry points are `setup(opts)`, `options()`, `context(bufnr)`,
`status(bufnr)`, `apply_config(id, scope, bufnr)`, `select_config(scope)`,
`reset(scope)`, `refresh()`, `browse()`, `open(name, split)`, `info()`, `index()`.
Use `scope="file"` or `"buffer"` with `apply_config`; the interactive
`select_config` and `reset` functions use `"buffer"` for file overrides.

## Current boundaries

- Completion reads paths in supported build flags and profiles. It does not
  parse YAML `.clangd` fragments, response files or framework search paths.
  clangd can interpret more settings, so its final search paths can differ.
  Put required completion paths in the profile or compilation database.
- The `project` profile does not query an arbitrary compiler from a build
  database. For implicit native standard headers in the picker/completion,
  choose a native profile with compiler discovery enabled.
- Compiler discovery uses only the explicitly configured executable. Commands
  found in a compilation database are parsed, never executed by Clective.
- POSIX-style compilation commands and Linux paths are the tested platform.
  Windows command-line quoting/MSVC and Objective-C/CUDA are outside this version.
- Macro-generated includes, multiline include directives and all preprocessor
  conditional states are not resolved by the filename completion source.
- Target-specific Amiga/Oscar64 behavior still requires tests with the real SDKs.
- Root detection uses the nearest configured marker and a working-directory
  fallback; explicit persistent workspace roots are not implemented yet.

## Tests and design references

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r tests/requirements.txt
python3 tests/run.py --nvim /path/to/nvim --clangd /path/to/clangd --plugins /path/to/plugins
python3 tests/package.py --nvim /path/to/nvim --plugins /path/to/plugins
```

The first suite launches real Neovim processes. clangd tests exercise SDK
definition changes, symbols from unopened files, document symbols and
source/header switching. The cmp tests use the real nvim-cmp dependency.
Without optional arguments those integrations are reported as skipped.

The plugins directory used by tests contains nvim-cmp and, for the package
tests, lazy.nvim. CI downloads pinned versions and tests both supported
Neovim release lines. See [CONTRIBUTING.md](CONTRIBUTING.md) for details and
[RESEARCH.md](RESEARCH.md) for the design references.

## Runnable example

[examples/demo](examples/demo) contains a C project and two tiny test SDKs.
In Neovim, run `:luafile /absolute/path/to/Clective.nvim/examples/demo/profile-setup.lua`.
Switch between Demo SDK A and B, then use your LSP definition mapping on
`platform_value`: its definition should move between the two SDK directories.
See [examples/demo/README.md](examples/demo/README.md) for the remaining checks.

## License

[MIT](LICENSE). Copyright 2026 Stephan Strauss.
