"""Runner contracts: verdicts, list validation, live status and continuation."""
import contextlib
import io
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import os
import uuid
from unittest.mock import patch

import run_regr as runner


class RegressionTests(unittest.TestCase):
    def setUp(self):
        self.rules = runner.load_rules(runner.HERE/'regr_keywords.json')

    @unittest.skipUnless(os.name=='nt','Windows local tool/input configuration')
    def test_snapshot_copies_relative_mnist_input_privately(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder)
            source=base/'source'
            for name in ['rtl','include','picorv32','drivers/tflm/my_tflm','veri/flist','veri/interface',
                         'veri/env','veri/test','veri/uvc','veri/soc_csrc','veri/sim','veri/tb/sram',
                         'veri/top_regression','veri/tools','build/windows']:
                (source/name).mkdir(parents=True,exist_ok=True)
            (source/'drivers/gempact_tiling.h').write_text('// fixture\n')
            (source/'veri/sim/windows.local.mk').write_text('TFLM_MNIST_ACCURACY_DATASET := ../../build/windows/mnist.npz\n')
            (source/'build/windows/mnist.npz').write_bytes(b'fixture dataset')
            dest=base/('test_'+uuid.uuid4().hex[:12]); dest.mkdir()
            alias=None
            try:
                work,alias=runner.prepare_workspace(dest,include_tflm=True,project=source)
                self.assertEqual((dest/'work/build/data/mnist.npz').read_bytes(),b'fixture dataset')
                self.assertIn('TFLM_MNIST_ACCURACY_DATASET := ../../build/data/mnist.npz',
                              (work/'windows.local.mk').read_text())
                (dest/'work/build/data/mnist.npz').write_bytes(b'changed private copy')
                self.assertEqual((source/'build/windows/mnist.npz').read_bytes(),b'fixture dataset')
            finally:
                runner.remove_alias(alias)

    def test_verdict_priority(self):
        cases = [
            ('PASS', '\033[32m[TEST_RESULT] TEST PASS\033[0m\n# UVM_ERROR : 0\n# UVM_FATAL : 0', 0, ''),
            ('FAIL', '[TEST_RESULT] TEST PASS\n# UVM_ERROR : 1', 0, ''),
            ('FAIL', '[TEST_RESULT] TEST PASS', 2, ''),
            ('FAIL', '# UVM_FATAL file.sv: error', 0, ''),
            ('UNKNOWN', 'completed without verdict', 0, ''),
            ('UNKNOWN', '[TEST_RESULT] TEST PASS', None, 'timeout'),
        ]
        for want, text, rc, reason in cases:
            with self.subTest(want=want, text=text):
                self.assertEqual(runner.classify(text, rc, self.rules, reason)[0], want)

    def test_lists_and_bad_input(self):
        for path in (runner.HERE/'regr').glob('*.list'):
            _, rows = runner.read_cases(str(path))
            self.assertTrue(all(comment for _, comment, _, _ in rows))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'test.list'
            path.write_text('\ufeff# comment\n\nfirst # detail\nfirst # repeat allowed\n', encoding='utf-8')
            self.assertEqual(len(runner.read_cases(str(path))[1]), 2)
            path.write_text('first second # forbidden\n', encoding='utf-8')
            with self.assertRaises(ValueError):
                runner.read_cases(str(path))

    def test_live_runner_continues_fail_unknown_timeout(self):
        real_popen = subprocess.Popen
        scripts = {
            'ok': 'print("[TEST_RESULT] TEST PASS")',
            'bad': 'print("[TEST_RESULT] TEST PASS"); raise SystemExit(2)',
            'unclear': 'print("no verdict")',
            'slow': 'import time; time.sleep(30)',
        }
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            listing = root/'contract.list'
            listing.write_text('ok\nbad\nunclear\nslow\nok\n', encoding='utf-8')

            def spawn(cmd, **kwargs):
                return real_popen([sys.executable, '-c', scripts[cmd[3]]], **kwargs)

            def stop(proc):
                proc.kill()
                proc.wait()

            args = ['run_regr.py', '--list', str(listing), '--simtool', 'modelsim',
                    '--out', str(root/'out'), '--keywords', str(runner.HERE/'regr_keywords.json'),
                    '--interval', '.1', '--timeout', '3', '--color', 'always','--seed','1']
            output = io.StringIO()
            cwd = Path.cwd()
            try:
                with patch.object(sys, 'argv', args), patch.object(runner, 'prepare_workspace', return_value=(root, None)), \
                     patch.object(runner.subprocess, 'Popen', side_effect=spawn), patch.object(runner, 'stop_tree', side_effect=stop), \
                     contextlib.redirect_stdout(output):
                    self.assertEqual(runner.main(), 1)
            finally:
                import os
                os.chdir(cwd)
            summary = next((root/'out').glob('*/summary.json'))
            data = json.loads(summary.read_text(encoding='utf-8'))
            self.assertEqual([r['status'] for r in data['results']], ['PASS', 'FAIL', 'UNKNOWN', 'UNKNOWN', 'PASS'])
            self.assertNotIn('[REGR] START', output.getvalue())
            self.assertNotIn('[REGR] RUNNING', output.getvalue())
            self.assertEqual(len([line for line in output.getvalue().splitlines()
                                  if re.match(r'\[REGR\] \x1b\[\d+m(PASS|FAIL|UNKNOWN)\x1b\[0m ',line)]),5)
            self.assertIn('[REGR] \033[32mPASS\033[0m 1/5 \033[32mok\033[0m | seed=1 | case ', output.getvalue())
            self.assertIn('[REGR] \033[31mFAIL\033[0m 2/5 \033[31mbad\033[0m | seed=1 | case ', output.getvalue())
            self.assertIn('\033[32m', output.getvalue())
            self.assertIn('\033[31m', output.getvalue())
            self.assertIn('ETA remaining', output.getvalue())
            self.assertEqual(data['completed'], 5)
            self.assertFalse(data['passed'])
            failures = list(summary.parent.glob('fail_*.list'))
            self.assertEqual(len(failures),1)
            _, rows = runner.read_cases(str(failures[0]))
            self.assertEqual([r[0] for r in rows],['bad','unclear','slow'])
            for _,comment,_,params in rows:
                repro=runner.repro_settings(comment)
                self.assertEqual(repro['seed'],1)
                self.assertEqual(repro['make_vars']['SOC_SEED'],'1')
                self.assertEqual(params['seed'],'1')
            self.assertTrue(all('_seed_1.log' in r['log'] for r in data['results']))

    def test_single_case_unique_directories_and_input_overrides(self):
        real_popen = subprocess.Popen
        from datetime import datetime
        import os
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            commands = []

            def spawn(cmd, **kwargs):
                commands.append(cmd)
                return real_popen([sys.executable,'-c','print("[TEST_RESULT] TEST PASS")'], **kwargs)

            args = ['run_regr.py','--case','run','--display-name','my_case','--simtool','modelsim',
                    '--out',str(root/'out'),'--override-names','case seed',
                    '--keywords',str(runner.HERE/'regr_keywords.json')]
            cwd = Path.cwd()
            try:
                with patch.object(sys,'argv',args), patch.object(runner,'prepare_workspace',return_value=(root,None)), \
                     patch.object(runner.subprocess,'Popen',side_effect=spawn), \
                     patch.dict(os.environ,{'case':'ai_mem_gen_smoke_test','seed':'303'}), \
                     patch.object(runner,'datetime') as clock, contextlib.redirect_stdout(io.StringIO()):
                    clock.now.return_value = datetime(2026,11,24,12,0,0)
                    self.assertEqual(runner.main(),0)
                    self.assertEqual(runner.main(),0)
            finally:
                os.chdir(cwd)
            summaries = list((root/'out').glob('my_case_*/summary.json'))
            self.assertEqual(len(summaries),2)
            self.assertIn('ISOLATED_RUN=1',commands[0])
            self.assertIn('case=ai_mem_gen_smoke_test',commands[0])
            self.assertIn('seed=303',commands[0])
            self.assertIn('SOC_SEED=303',commands[0])
            self.assertIn('REGR_SEED=303',commands[0])
            self.assertIn('SIM_ARGS= +MEM_GEN_SEED=303',commands[0])
            self.assertEqual(json.loads(summaries[0].read_text())['results'][0]['case'],'my_case')

    def test_failure_replay_retains_seed_inputs_snapshot_and_budget(self):
        real_popen = subprocess.Popen
        import os
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            args = ['run_regr.py','--case','run','--display-name','my_case','--simtool','modelsim',
                    '--out',str(root/'out'),'--override-names','case seed SIM_ARGS',
                    '--timeout','12','--keywords',str(runner.HERE/'regr_keywords.json')]
            commands=[]
            def spawn(cmd,**kwargs):
                commands.append(cmd)
                return real_popen([sys.executable,'-c','raise SystemExit(2)'],**kwargs)
            cwd=Path.cwd()
            try:
                with patch.object(sys,'argv',args), patch.object(runner,'prepare_workspace',return_value=(root,None)), \
                     patch.object(runner.subprocess,'Popen',side_effect=spawn), \
                     patch.dict(os.environ,{'case':'ai_mem_gen_smoke_test','seed':'919','SIM_ARGS':'+MEM_GEN_K=0'}), \
                     contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(runner.main(),1)
                first=next((root/'out').glob('*/summary.json'))
                snap=first.parent/'work/veri/sim'
                snap.mkdir(parents=True)
                for name in ('Makefile','regr_cases.mk','modelsim_backend.py'):
                    shutil.copy2(runner.HERE/name,snap/name)
                failure=next(first.parent.glob('fail_*.list'))
                args=['run_regr.py','--list',str(failure),'--simtool','modelsim','--out',str(root/'replayed'),
                      '--keywords',str(runner.HERE/'regr_keywords.json')]
                with patch.object(sys,'argv',args), patch.object(runner,'prepare_workspace',return_value=(root,None)) as prep, \
                     patch.object(runner.subprocess,'Popen',side_effect=spawn), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(runner.main(),1)
                    self.assertEqual(prep.call_args.kwargs['project'],first.parent/'work')
                replayed=json.loads(next((root/'replayed').glob('*/summary.json')).read_text())
                self.assertEqual(replayed['results'][0]['seed'],919)
                self.assertEqual(replayed['results'][0]['reproduce']['timeout'],12)
                self.assertEqual(replayed['results'][0]['target'],'run')
                self.assertIn('case=ai_mem_gen_smoke_test',commands[1])
                self.assertIn('SIM_ARGS=+MEM_GEN_K=0 +MEM_GEN_SEED=919',commands[1])
                self.assertTrue(all('seed_919' in r['log'] for r in replayed['results']))
            finally:
                os.chdir(cwd)

    def test_inline_seeds_fixed_and_missing_seeds_random_each_repeat(self):
        real_popen=subprocess.Popen
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); listing=root/'seeds.list'
            listing.write_text('ok seed=42 # fixed\nok # random\nok seed=8 # fixed\n',encoding='utf-8')
            args=['run_regr.py','--list',str(listing),'--simtool','modelsim','--out',str(root/'out'),
                  '--repeat','2','--keywords',str(runner.HERE/'regr_keywords.json')]
            def spawn(cmd,**kwargs):
                return real_popen([sys.executable,'-c','print("[TEST_RESULT] TEST PASS")'],**kwargs)
            cwd=Path.cwd()
            try:
                with patch.object(sys,'argv',args), patch.object(runner,'prepare_workspace',return_value=(root,None)), \
                     patch.object(runner.subprocess,'Popen',side_effect=spawn), \
                     patch.object(runner.secrets,'randbelow',side_effect=[100,200]), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(runner.main(),0)
            finally:
                os.chdir(cwd)
            data=json.loads(next((root/'out').glob('*/summary.json')).read_text())
            self.assertEqual([r['seed'] for r in data['results']],[42,101,8,42,201,8])
            self.assertEqual([r['seed_origin'] for r in data['results']],['list','random','list']*2)


if __name__ == '__main__':
    unittest.main()
