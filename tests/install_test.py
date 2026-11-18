#!/usr/bin/env python3
import importlib.util, tempfile, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('clective_install',Path(__file__).resolve().parents[1]/'install.py')
installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)

class Install(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)/'config with spaces'
        (self.root/'lua/plugins').mkdir(parents=True)
        (self.root/'lua/modules').mkdir()
        (self.root/'init.lua').write_text('-- existing init\n')
        (self.root/'lua/keymaps.lua').write_text('-- unrelated mappings\n')
        (self.root/'lua/plugins/clective.lua').write_text('-- old plugin spec\n')
        (self.root/'lua/modules/lookup_includes.lua').write_text('-- old picker\n')
        (self.root/'lua/plugins/lualine.lua').write_text('''-- unrelated status settings
    local function filetype_with_compiler()
      return "old"
    end

    local function copilot_status()
      return "copilot unchanged"
    end
''')
        (self.root/'lua/plugins/lspconfig.lua').write_text('''return {
  clangd = {
    cmd = {
      "clangd",
      "--compile-commands-dir=.",
      "--background-index",
      "--log=verbose",
    },
    root_markers = { ".clang" },
  },
  pyright = { settings = { keep = true } },
}
''')
        (self.root/'scripts/clective/.git').mkdir(parents=True)
        (self.root/'scripts/clective/.git/HEAD').write_text('ref: refs/heads/main\n')
    def tearDown(self):self.temp.cleanup()
    def test_install_backup_and_idempotence(self):
        old=(self.root/'lua/plugins/lspconfig.lua').read_bytes()
        backup=installer.install(self.root)
        self.assertEqual((backup/'lua/plugins/lspconfig.lua').read_bytes(),old)
        self.assertEqual(installer.changes(self.root),{})
        self.assertEqual((self.root/'scripts/clective/.git/HEAD').read_text(),'ref: refs/heads/main\n')
        self.assertEqual((self.root/'lua/keymaps.lua').read_text(),'-- unrelated mappings\n')
        lsp=(self.root/'lua/plugins/lspconfig.lua').read_text()
        self.assertIn('"--log=verbose"',lsp)
        self.assertIn('pyright = { settings = { keep = true } }',lsp)
        self.assertNotIn('--compile-commands-dir=.',lsp)
        self.assertIn('copilot unchanged',(self.root/'lua/plugins/lualine.lua').read_text())
    def test_dry_run_changes_nothing(self):
        old=(self.root/'lua/plugins/clective.lua').read_bytes()
        installer.install(self.root,True)
        self.assertEqual((self.root/'lua/plugins/clective.lua').read_bytes(),old)
        self.assertFalse(list(self.root.parent.glob('nvim-clective-backup-*')))
    def test_unknown_layout_stops_before_any_write(self):
        target=self.root/'lua/plugins/lspconfig.lua'
        target.write_text('-- radically different layout\n')
        before={str(p.relative_to(self.root)):p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        with self.assertRaises(ValueError):installer.install(self.root)
        after={str(p.relative_to(self.root)):p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before,after)
        self.assertFalse(list(self.root.parent.glob('nvim-clective-backup-*')))

if __name__=='__main__':unittest.main()
