# Development

Clective is Lua code for Neovim 0.11+. Its runtime has no Python dependency.
Tests use Python 3.10+ and pynvim to drive real Neovim processes.

## Run tests

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r tests/requirements.txt
python3 tests/run.py --nvim /path/to/nvim --clangd /path/to/clangd --plugins /path/to/plugins
python3 tests/package.py --nvim /path/to/nvim --clangd /path/to/clangd --plugins /path/to/plugins
```

The plugins directory contains checked-out nvim-cmp and lazy.nvim directories.
CI pins their commits and clangd 19.1.2, and runs Neovim 0.11.5 and 0.12.6.
The workflow requires no repository secrets and has read-only contents access.

tests/run.py covers profile scopes, persistence across a new Neovim process,
header language, build settings, include completion, navigation and actual
clangd symbol behavior. The optional dependencies are skipped if omitted.

tests/package.py loads examples/lazy.lua through real lazy.nvim, checks the
native package loader without nvim-cmp, and verifies the optional standalone
clangd configuration when --clangd is supplied.

## Changes

- Keep default setup independent of personal filesystem layouts.
- Preserve user keymaps and completion settings.
- Use temporary directories and isolated state in regression tests.
- Update README.md and doc/clective.txt when changing public options or commands.
- Explain observable behavior and validation in pull requests.

The repository retains the original local implementation and its development
commits. Machine-specific installation helpers from that stage remain
available in history, but are not part of the current public plugin.
