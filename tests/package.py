#!/usr/bin/env python3
"""Load the distributable through real lazy.nvim and the native package loader."""
import argparse, json, os, tempfile, unittest
from pathlib import Path
import pynvim

p=argparse.ArgumentParser()
p.add_argument('--nvim',required=True)
p.add_argument('--plugins',required=True)
p.add_argument('--clangd')
p.add_argument('--spec',help='Optional alternative Lazy specification to verify')
p.add_argument('--output')
args=p.parse_args()
repo=Path(__file__).resolve().parents[1]
nvim=str(Path(args.nvim).resolve());plugins=Path(args.plugins).resolve()
spec=Path(args.spec).resolve() if args.spec else repo/'examples/lazy.lua'

class Package(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='clective-package-')
        self.root=Path(self.temp.name)
        (self.root/'.git').mkdir()
        self.file=self.root/'main.c';self.file.write_text('int package_symbol(void) { return 0; }\n')
        self.n=None
    def tearDown(self):
        if self.n:
            try:self.n.command('qa!')
            except (EOFError,OSError):pass
            self.n.close()
        self.temp.cleanup()
    def launch(self,lazy=False):
        init=self.root/'init.lua'
        lines=['vim.g.mapleader=" "', 'vim.opt.swapfile=false', 'vim.cmd("filetype on")',
               '_G.errors={};vim.notify=function(m,l) if l==vim.log.levels.ERROR then table.insert(errors,tostring(m)) end end']
        if lazy:
            lines += ['vim.opt.rtp:prepend('+json.dumps(str(plugins/'lazy.nvim'))+')',
                      'local spec=dofile('+json.dumps(str(spec))+')',
                      'assert(spec[1]=="IstiCusi/Clective.nvim" and spec.main=="clective")',
                      'spec.dir='+json.dumps(str(repo)),
                      'spec.dependencies={{name="nvim-cmp",dir='+json.dumps(str(plugins/'nvim-cmp'))+'}}',
                      'require("lazy").setup({spec={spec},root='+json.dumps(str(self.root/'plugins'))+
                      ',lockfile='+json.dumps(str(self.root/'lazy-lock.json'))+
                      ',local_spec=false,install={missing=false},checker={enabled=false},change_detection={enabled=false},rocks={enabled=false},pkg={enabled=false},readme={enabled=false}})']
        else:lines += ['vim.opt.rtp:prepend('+json.dumps(str(repo))+')']
        init.write_text('\n'.join(lines)+'\n')
        env=['XDG_'+kind+'_HOME='+str(self.root/kind.lower()) for kind in ['CONFIG','STATE','CACHE','DATA']]
        if args.clangd:env += ['PATH='+str(Path(args.clangd).resolve().parent)+os.pathsep+os.environ['PATH']]
        self.n=pynvim.attach('child',argv=['env']+env+[nvim,'--embed','--headless','-u',str(init),'-i','NONE','-n',str(self.file)])
        self.n.ui_attach(120,40,rgb=True);self.n.exec_lua('vim.wait(400)')
    def test_lazy_spec_loads_plugin_commands_and_cmp(self):
        self.launch(lazy=True)
        self.assertEqual(self.n.funcs.exists(':ClectiveProfile'),2)
        self.assertEqual(self.n.funcs.maparg(' Kc','n'),'<Cmd>ClectiveProfile<CR>')
        self.assertEqual(self.n.exec_lua('return require("clective").options().default_profile'),'project')
        self.assertTrue(self.n.exec_lua('for _,s in ipairs(require("cmp").get_registered_sources()) do if s.name=="clective_includes" then return true end end;return false'))
        self.assertEqual(self.n.exec_lua('return errors'),[])
    def test_native_package_supplies_defaults_without_cmp(self):
        self.launch()
        self.assertEqual(self.n.funcs.exists(':ClectiveProfile'),2)
        self.assertEqual(self.n.exec_lua('return require("clective").context(0).language'),'c')
        self.assertTrue(self.n.exec_lua('return package.loaded.cmp==nil'))
        self.assertEqual(self.n.exec_lua('return errors'),[])
    def test_standalone_clangd_example_attaches_one_server(self):
        if not args.clangd:self.skipTest('pass --clangd to verify the optional LSP example')
        self.launch()
        self.n.command('luafile '+self.n.funcs.fnameescape(str(repo/'examples/clangd.lua')))
        self.assertTrue(self.n.exec_lua('return vim.wait(6000,function() local c=vim.lsp.get_clients({bufnr=0,name="clangd"})[1];return c and c.initialized end)'))
        self.n.exec_lua('vim.wait(200)')
        self.assertEqual(self.n.exec_lua('return #vim.lsp.get_clients({bufnr=0,name="clangd"})'),1)
        self.assertEqual(self.n.exec_lua('return #require("clective").context(0).clangd_clients'),1)
        self.assertEqual(self.n.exec_lua('return errors'),[])

result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Package))
if args.output:
    Path(args.output).write_text(json.dumps({'tests':result.testsRun,'passed':result.wasSuccessful(),
        'failures':[str(t)+': '+s for t,s in result.failures],'errors':[str(t)+': '+s for t,s in result.errors],
        'skipped':[(str(t),why) for t,why in result.skipped]},indent=2)+'\n')
raise SystemExit(not result.wasSuccessful())
