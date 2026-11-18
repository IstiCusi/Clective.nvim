#!/usr/bin/env python3
"""Real-Neovim regression tests; optional real clangd and nvim-cmp integration."""
import argparse, json, os, sys, tempfile, unittest
from pathlib import Path
import pynvim

parser = argparse.ArgumentParser()
parser.add_argument('--nvim', required=True)
parser.add_argument('--clangd')
parser.add_argument('--plugins')
parser.add_argument('--output')
args, remaining = parser.parse_known_args()
args.nvim = str(Path(args.nvim).resolve())
if args.clangd: args.clangd = str(Path(args.clangd).resolve())
if args.plugins: args.plugins = str(Path(args.plugins).resolve())
REPO = Path(__file__).resolve().parents[1]

class Clective(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='clective-test-')
        self.root=Path(self.tmp.name)
        self.a=self.root/'project_a';self.b=self.root/'project_b'
        self.sdk=self.root/'sdk a';self.sdk2=self.root/'sdk b'
        for d in [self.a/'.git',self.b/'.git',self.a/'src',self.sdk/'exec',self.sdk2]:d.mkdir(parents=True,exist_ok=True)
        for sdk,number in [(self.sdk,1),(self.sdk2,2)]:
            (sdk/'platform.h').write_text('static inline int platform_value(void) { return '+str(number)+'; }\n')
        (self.sdk/'exec/libraries.h').write_text('struct Library { int version; };\n')
        (self.sdk/'vector').write_text('namespace example { class Vector {}; }\n')
        (self.sdk/'ignored.cpp').write_text('int implementation;\n')
        self.source=self.a/'src/main.c'
        self.source.write_text('#include <platform.h>\nint run(void) { return platform_value(); }\n')
        self.n=pynvim.attach('child',argv=['env','XDG_STATE_HOME='+str(self.root/'state'),
            args.nvim,'--embed','--headless','-u','NONE','-i','NONE','-n'])
        self.n.ui_attach(180,50,rgb=True)
        self.n.exec_lua('vim.opt.rtp:prepend(...);vim.cmd("filetype on");vim.opt.hidden=true;_G.messages={};vim.notify=function(m,l) table.insert(messages,{text=tostring(m),level=l or 2}) end',str(REPO))
        self.cmd('cd '+str(self.root))
        self.options={'state_file':str(self.root/'state.json'),'default_profile':'a','profiles':{
            'a':{'label':'SDK A','language':'c','include_dirs':[str(self.sdk)],'build':'ignore','system_headers':False},
            'b':{'label':'SDK B','language':'c','include_dirs':[str(self.sdk2)],'build':'ignore','system_headers':False},
            'cpp':{'label':'SDK C++','language':'cpp','include_dirs':[str(self.sdk)],'build':'ignore','system_headers':False}}}
        self.setup()
        self.cmd('edit '+str(self.source))
    def tearDown(self):
        try:self.n.command('qa!')
        except (EOFError,OSError):pass
        self.n.close();self.tmp.cleanup()
    def setup(self):self.n.exec_lua('require("clective").setup(...)',self.options);self.settle()
    def settle(self,ms=100):self.n.exec_lua('vim.wait(...);vim.cmd("redraw")',ms)
    def cmd(self,s):self.n.command(s);self.settle()
    def keys(self,s):self.n.input(s);self.settle()
    def context(self,buf=0):return self.n.exec_lua('return require("clective").context(...)',buf)
    def choose(self,name,scope='project'):self.n.exec_lua('require("clective").apply_config(...)',name,scope);self.settle()
    def complete(self,text,delim='<'):return self.n.exec_lua('local prefix,delim=...;return require("clective.headers").complete(require("clective").context(0),prefix,delim)',text,delim)
    def errors(self):return [m for m in self.n.exec_lua('return messages') if m['level']>=4]
    def start_lsp(self):
        if not args.clangd:self.skipTest('pass --clangd for semantic integration tests')
        self.client=self.n.exec_lua('local exe,root=...;return vim.lsp.start({name="clangd",cmd={exe,"--background-index"},root_dir=root})',args.clangd,str(self.a))
        self.assertTrue(self.n.exec_lua('local id=...;return vim.wait(6000,function() local c=vim.lsp.get_client_by_id(id);return c and c.initialized end)',self.client))
        self.settle(500)
    def request(self,method,params):
        result=self.n.exec_lua('local id,method,params=...;return vim.lsp.get_client_by_id(id):request_sync(method,params,5000,0)',self.client,method,params)
        self.assertIsNotNone(result,(method,self.errors()))
        self.assertNotIn('err',result,result)
        return result.get('result')
    def definition(self):
        return self.request('textDocument/definition',{'textDocument':{'uri':self.source.as_uri()},'position':{'line':1,'character':24}})

    def test_project_state_and_status_match_each_window(self):
        first=self.n.current.buffer.number;left=self.n.current.window.handle
        other=self.b/'second.c';other.write_text('int second;\n')
        self.cmd('vsplit '+str(other));self.choose('b')
        self.n.api.set_current_win(left);self.settle()
        self.assertEqual(self.context()['profile'],'a')
        self.assertIn('SDK A',self.n.exec_lua('return require("clective").status(...)',first))
        self.assertIn(str(self.sdk).replace(' ','\\ '),self.n.current.buffer.options['path'])
    def test_project_choice_updates_already_loaded_buffers(self):
        first=self.n.current.buffer.number
        second=self.a/'second.c';second.write_text('int second;\n')
        self.cmd('edit '+str(second));self.choose('b')
        self.assertEqual(self.context(first)['profile'],'b')
        self.assertEqual(self.context()['profile'],'b')
    def test_file_override_and_reset(self):
        self.choose('b','buffer');self.assertEqual(self.context()['scope'],'file')
        self.cmd('ClectiveReset!');self.assertEqual(self.context()['profile'],'a')
    def test_state_persists_without_writing_plugin_directory(self):
        self.choose('b');state=json.loads((self.root/'state.json').read_text())
        self.assertEqual(state['projects'][str(self.a)],'b')
        self.setup();self.assertEqual(self.context()['profile'],'b')
        self.assertFalse((REPO/'state.json').exists())
    def test_cpp_source_extensions_and_h_context(self):
        for ext in ['cc','cxx','cpp','hpp','hh','hxx']:
            file=self.a/('sample.'+ext);file.write_text('int value;\n')
            self.cmd('edit '+str(file));self.assertEqual(self.context()['language'],'cpp')
            self.assertEqual(self.context()['include_dirs'],[str(self.sdk)])
        file=self.a/'shared.h';file.write_text('int value;\n');self.cmd('edit '+str(file))
        self.assertEqual(self.n.current.buffer.options['filetype'],'c')
        self.choose('cpp');self.assertEqual(self.n.current.buffer.options['filetype'],'cpp')
    def test_empty_nested_and_extensionless_completion(self):
        labels=[i['label'] for i in self.complete('')]
        self.assertIn('platform.h',labels);self.assertIn('vector',labels);self.assertNotIn('ignored.cpp',labels)
        self.assertEqual([i['label'] for i in self.complete('exec/li')],['exec/libraries.h'])
        self.assertEqual(len(labels),len(set(labels)))
    def test_duplicate_roots_and_trailing_slashes(self):
        self.options['profiles']['a']['include_dirs']=[str(self.sdk)+'/',str(self.sdk)+'/**']
        self.setup();self.assertEqual(self.context()['include_dirs'],[str(self.sdk)])
        self.assertEqual(len(self.complete('plat')),1)
    def test_quote_vs_angle_precedence(self):
        local=self.source.parent/'platform.h';local.write_text('// local\n')
        q=self.complete('plat','"');a=self.complete('plat','<')
        self.assertEqual(q[0]['path'],str(local));self.assertEqual(a[0]['path'],str(self.sdk/'platform.h'))
    def test_no_false_include_in_comment(self):
        self.assertIsNone(self.n.exec_lua('return require("clective.headers").prefix("// #include <plat")'))
    def test_open_header_preserves_context_outside_project(self):
        self.cmd('ClectiveOpen');self.assertEqual(self.n.current.buffer.name,str(self.sdk/'platform.h'))
        self.assertEqual(self.context()['root'],str(self.a));self.assertEqual(self.context()['language'],'c')
        self.assertEqual(self.n.current.buffer.options['filetype'],'c')
    def test_no_recursive_false_include_resolution(self):
        self.assertIsNone(self.n.exec_lua('return require("clective.headers").resolve(require("clective").context(0),"libraries.h","<")'))
    def test_setup_is_idempotent(self):
        count=self.n.exec_lua('return #vim.api.nvim_get_autocmds({group="Clective"})')
        self.setup();self.assertEqual(self.n.exec_lua('return #vim.api.nvim_get_autocmds({group="Clective"})'),count)
        self.assertEqual(self.errors(),[])
    def test_parent_flags_split_arguments_and_relative_paths(self):
        (self.a/'compile_flags.txt').write_text('-I\n"should remain quoted"\n-I"include with spaces"\n-Iunquoted space\n-isystem\nsystem\n-DPROJECT=1\n')
        self.choose('project');c=self.context()
        self.assertIn(str(self.a/'include with spaces'),c['include_dirs'])
        self.assertIn(str(self.a/'unquoted space'),c['include_dirs'])
        self.assertIn(str(self.a/'system'),c['system_dirs'])
        self.assertIn('-DPROJECT=1',c['command'])
    def test_compile_database_arguments_and_header_inference(self):
        database=[{'directory':str(self.a),'file':'src/main.c','arguments':['cc','-I','include with spaces','-DVALUE=7','-c','src/main.c','-o','main.o']}]
        (self.a/'compile_commands.json').write_text(json.dumps(database))
        self.choose('project');c=self.context()
        self.assertIn(str(self.a/'include with spaces'),c['include_dirs']);self.assertNotIn('main.o',c['command'])
        header=self.a/'src/main.h';header.write_text('int value;\n');self.cmd('edit '+str(header));c=self.context()
        self.assertTrue(c['inferred']);self.assertEqual(c['language'],'c')
        self.assertNotIn('src/main.c',c['command']);self.assertEqual(c['command'][-1],str(header))
    def test_compile_command_shell_quoting_without_execution(self):
        db=[{'directory':str(self.a),'file':'src/main.c','command':'cc -I"include with spaces" -DNAME=\'two words\' -c src/main.c'}]
        (self.a/'compile_commands.json').write_text(json.dumps(db));self.choose('project')
        self.assertIn(str(self.a/'include with spaces'),self.context()['include_dirs'])
        self.assertIn('-DNAME=two words',self.context()['command'])
    def test_cdb_reload_after_disk_change(self):
        path=self.a/'compile_flags.txt';path.write_text('-Ione\n');self.choose('project')
        self.assertIn(str(self.a/'one'),self.context()['include_dirs'])
        path.write_text('-Itwo\n');self.cmd('ClectiveRefresh')
        self.assertIn(str(self.a/'two'),self.context()['include_dirs'])
    def test_native_compiler_discovery(self):
        if not self.n.funcs.executable('cc'):self.skipTest('cc unavailable')
        self.choose('native-c')
        self.assertTrue(self.n.exec_lua('return vim.wait(7000,function() return not require("clective").context(0).discovering end)'))
        c=self.context();self.assertTrue(c['system_dirs'],c)
        self.assertTrue(any(i['label']=='stdio.h' for i in self.complete('stdio')))
    def test_profile_change_does_not_modify_source(self):
        before=self.source.read_bytes();self.choose('b');self.choose('cpp')
        self.assertEqual(before,self.source.read_bytes());self.assertFalse(self.n.current.buffer.options['modified'])
        self.assertEqual(self.n.current.buffer.options['filetype'],'c')
    def test_info_and_health(self):
        self.cmd('ClectiveInfo');self.assertIn('Profile: SDK A [a]',list(self.n.current.buffer))
        self.keys('q');self.cmd('checkhealth clective');self.assertEqual(self.errors(),[])
    def test_real_clangd_definition_changes_with_profile(self):
        self.start_lsp()
        self.assertIn((self.sdk/'platform.h').as_uri(),str(self.definition()))
        self.choose('b');self.settle(500)
        self.assertIn((self.sdk2/'platform.h').as_uri(),str(self.definition()))
        self.assertEqual(self.errors(),[])
    def test_real_clangd_document_symbols(self):
        self.start_lsp();result=self.request('textDocument/documentSymbol',{'textDocument':{'uri':self.source.as_uri()}})
        self.assertTrue(any(s['name']=='run' for s in result),result)
    def test_completion_text_edit_keeps_subdirectory(self):
        result=self.n.exec_lua('''local out; require('clective.cmp_source').new():complete({context={bufnr=vim.api.nvim_get_current_buf(),cursor_before_line='#include <exec/li',cursor_line='#include <exec/li>',cursor={row=1,col=17}}},function(r) out=r end);return out''')
        self.assertEqual(result['items'][0]['textEdit']['newText'],'exec/libraries.h')
        self.assertEqual(result['items'][0]['textEdit']['range']['start']['character'],10)
    def test_real_cmp_accepts_nested_path_and_restores_other_sources(self):
        if not args.plugins:self.skipTest('pass --plugins for nvim-cmp test')
        self.n.exec_lua('''vim.opt.rtp:prepend(...)
          local cmp=require('cmp')
          cmp.setup({completion={keyword_length=3},sources={{name='sentinel'}}})
          cmp.setup.buffer({completion={keyword_length=7},experimental={ghost_text=true}})
          cmp.register_source('sentinel',{complete=function(_,_,cb) cb({items={{label='ordinary_symbol'}}}) end})
          require('clective.completion').register()''',str(Path(args.plugins)/'nvim-cmp'))
        self.n.api.buf_set_lines(0,0,-1,False,['#include <exec/li>'])
        self.keys('0f>i')
        self.n.exec_lua('require("cmp").complete()');self.settle(300)
        labels=self.n.exec_lua('local out={};for _,e in ipairs(require("cmp").get_entries()) do out[#out+1]=e.completion_item.label end;return out')
        self.assertEqual(labels,['exec/libraries.h'])
        self.n.exec_lua('require("cmp").confirm({select=true})');self.settle()
        self.assertEqual(self.n.current.line,'#include <exec/libraries.h>')
        self.keys('<Esc>oordinary<Esc>')
        self.assertEqual(self.n.exec_lua('return require("cmp").get_config().sources[1].name'),'sentinel')
        self.assertEqual(self.n.exec_lua('return require("cmp").get_config().completion.keyword_length'),7)
        self.assertTrue(self.n.exec_lua('return require("cmp").get_config().experimental.ghost_text'))
        self.assertTrue(self.n.exec_lua('return require("cmp.config").buffers[vim.api.nvim_get_current_buf()].sources == nil'))
    def test_real_cmp_empty_include_shows_headers(self):
        if not args.plugins:self.skipTest('pass --plugins for nvim-cmp test')
        self.n.exec_lua('vim.opt.rtp:prepend(...);require("cmp").setup({completion={keyword_length=3},sources={}});require("clective.completion").register()',str(Path(args.plugins)/'nvim-cmp'))
        self.n.api.buf_set_lines(0,0,-1,False,['#include <>']);self.keys('0f>i')
        self.n.exec_lua('require("cmp").complete()');self.settle(300)
        labels=self.n.exec_lua('local out={};for _,e in ipairs(require("cmp").get_entries()) do out[#out+1]=e.completion_item.label end;return out')
        self.assertIn('platform.h',labels)
    def test_real_clangd_indexes_unopened_project_file(self):
        other=self.a/'unopened.c';other.write_text('int never_opened_function(void) { return 7; }\n')
        self.start_lsp();self.cmd('ClectiveIndex')
        found=False
        for _ in range(20):
            self.settle(200)
            symbols=self.request('workspace/symbol',{'query':'never_opened_function'}) or []
            if any(s['name']=='never_opened_function' for s in symbols):found=True;break
        self.assertTrue(found,symbols)
        self.assertEqual(self.n.funcs.bufnr(str(other)),-1)

suite=unittest.defaultTestLoader.loadTestsFromNames(remaining or ['__main__.Clective'])
result=unittest.TextTestRunner(verbosity=2).run(suite)
report={'tests':result.testsRun,'failures':[str(x[0])+': '+x[1] for x in result.failures],
        'errors':[str(x[0])+': '+x[1] for x in result.errors], 'skipped':[(str(x),why) for x,why in result.skipped],
        'nvim':args.nvim,'clangd':args.clangd,'passed':result.wasSuccessful()}
if args.output:Path(args.output).write_text(json.dumps(report,indent=2))
raise SystemExit(not result.wasSuccessful())
