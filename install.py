#!/usr/bin/env python3
"""Install the local plugin and patch only its four Neovim integration points."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import os
import re
import shutil
import tempfile

SOURCE = Path(__file__).resolve().parent
STATUS = '''    local function filetype_with_compiler()
      local ok, clective = pcall(require, "clective")
      return ok and clective.status() or vim.bo.filetype
    end

'''

def changes(target):
    planned = {}
    for rel in ("lua/plugins/clective.lua", "lua/modules/lookup_includes.lua"):
        planned[rel] = (SOURCE / "integration/phonon" / rel).read_bytes()
    rel = "lua/plugins/lualine.lua"
    text = (target / rel).read_text()
    pattern = r'(?m)^ *local function filetype_with_compiler\(\).*?(?=^ *local function copilot_status\()'
    text, count = re.subn(pattern, lambda _: STATUS, text, flags=re.S)
    if count != 1:
        raise ValueError("Cannot identify the Clective status function in " + rel)
    planned[rel] = text.encode()
    rel = "lua/plugins/lspconfig.lua"
    text = (target / rel).read_text()
    pattern = r'(clangd\s*=\s*\{)(.*?)(\n\s*\},\s*\n\s*pyright\s*=)'
    matches = list(re.finditer(pattern, text, flags=re.S))
    if len(matches) != 1:
        raise ValueError("Cannot identify the clangd configuration in " + rel)
    match = matches[0]
    body = match[2]
    body = re.sub(r'(?m)^\s*"--compile-commands-dir=\.",\s*\n', '', body)
    body, count = re.subn(r'root_markers\s*=\s*\{[^}]*\}',
        'root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", "CMakeLists.txt", "Makefile", ".git" }', body)
    if count != 1:
        raise ValueError("Cannot identify clangd root_markers in " + rel)
    text = text[:match.start(2)] + body + text[match.end(2):]
    planned[rel] = text.encode()
    for folder in ("lua", "plugin", "doc", "examples", "integration", "tests"):
        for file in sorted((SOURCE / folder).rglob("*")):
            if file.is_file() and not {"__pycache__", ".cache", ".git"}.intersection(file.parts) and file.suffix != ".pyc":
                planned[str(Path("scripts/clective") / file.relative_to(SOURCE))] = file.read_bytes()
    for name in ("README.md", "CHANGELOG.md", "INSTALL_DE.md", "RESEARCH.md", "TEST_REPORT.md", "install.py"):
        if (SOURCE / name).exists():
            planned["scripts/clective/" + name] = (SOURCE / name).read_bytes()
    return {rel: data for rel, data in planned.items()
            if not (target / rel).is_file() or (target / rel).read_bytes() != data}

def install(target, dry_run=False):
    target = target.expanduser().resolve()
    if not (target / "init.lua").is_file():
        raise ValueError("Not a Neovim configuration directory: " + str(target))
    planned = changes(target)  # Validate every integration point before writing.
    if not planned:
        print("Clective is already up to date."); return None
    print("Updating %d files in %s" % (len(planned), target))
    for rel in planned: print("  " + rel)
    if dry_run: return None
    backup = target.parent / ("nvim-clective-backup-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f"))
    backup.mkdir()
    created = []
    for rel in planned:
        old = target / rel
        if old.exists():
            dest = backup / rel; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(old, dest)
        else: created.append(rel)
    (backup / "NEW_FILES.txt").write_text("\n".join(created) + "\n")
    # Same-directory temporary files make each individual replacement atomic.
    completed = []
    try:
        for rel, data in planned.items():
            path = target / rel; path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temp:
                temp.write(data); temp_name = temp.name
            os.chmod(temp_name, path.stat().st_mode & 0o777 if path.exists() else 0o644)
            os.replace(temp_name, path); completed.append(rel)
    except Exception:
        for rel in reversed(completed):
            path = target / rel
            if rel in created: path.unlink(missing_ok=True)
            else: shutil.copy2(backup / rel, path)
        raise
    print("Backup: " + str(backup))
    print("Installed. Restart Neovim, open a C/C++ file, then use Space K c.")
    return backup

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config")))/"nvim")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try: install(args.config, args.dry_run)
    except (ValueError, OSError) as error: parser.exit(1, "Installation stopped: " + str(error) + "\n")
