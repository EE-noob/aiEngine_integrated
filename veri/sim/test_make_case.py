"""Single-case make flow: helpers prepare/record, never launch simulation."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import sim_run_common as common


class NativeMakeCaseTests(unittest.TestCase):
    def test_makefile_does_not_invoke_single_or_regression_runner(self):
        recipe=(common.HERE/'isolated_dispatch.mk').read_text(encoding='utf-8')
        self.assertNotIn('run_case.py',recipe)
        self.assertNotIn('run_regr.py',recipe)
        self.assertIn('"$$CASE_TARGET" "$${CASE_ARGS[@]}"',recipe)

    def test_windows_launcher_uses_short_native_working_directory(self):
        work = 'D:/courseware/mst4/.regr_paths/example/veri/sim'
        command = ('make.exe', '-j1', 'tflm_mnist_mlp_run', 'ISOLATED_RUN=1')
        with patch.object(common.subprocess, 'Popen') as launch:
            launch.return_value.wait.return_value = 2
            self.assertEqual(common.launch_windows_make(work, '60', *command), 2)
        launch.assert_called_once_with(command, cwd=work)
        launch.return_value.wait.assert_called_once_with(timeout=60)

    def test_windows_launcher_stops_process_tree_on_timeout(self):
        with patch.object(common.subprocess, 'Popen') as launch, patch.object(common, 'stop_tree') as stop:
            launch.return_value.wait.side_effect = subprocess.TimeoutExpired('make.exe', 60)
            self.assertEqual(common.launch_windows_make('D:/work', '60', 'make.exe'), 124)
            stop.assert_called_once_with(launch.return_value)

    def test_preparation_and_result_recording_do_not_start_processes(self):
        for succeeds in [True,False]:
            with self.subTest(succeeds=succeeds), tempfile.TemporaryDirectory() as folder:
                root=Path(folder)
                inputs={'AI_CASE_TARGET':'run','AI_CASE_NAME':'soc_unaligned_randlat_ws_int8',
                        'AI_CASE_OUT':str(root),'AI_CASE_TOOL':'modelsim','AI_CASE_DUMP':'0',
                        'AI_CASE_KEYWORDS':str(common.HERE/'regr_keywords.json'),
                        'AI_CASE_OVERRIDES':'case seed','case':'soc_unaligned_randlat_ws_int8','seed':'72003'}
                with patch.dict(os.environ,inputs), patch.object(common,'prepare_workspace',return_value=(root,None)), \
                     patch.object(common.subprocess,'Popen',side_effect=AssertionError('filesystem helper launched process')):
                    plan=Path(common.prepare_make_case())
                    state=json.loads((plan.parent/'make_case_state.json').read_text())
                    self.assertEqual(state['reproduce']['target'],'soc_unaligned_randlat_ws_int8')
                    self.assertEqual(state['reproduce']['seed'],72003)
                    self.assertNotIn('case',state['reproduce']['make_vars'])
                    self.assertIn('SOC_SEED=72003',plan.read_text())
                    with Path(state['log']).open('a') as stream:
                        stream.write('[TEST_RESULT] TEST PASS\n' if succeeds else 'compile error\n')
                    with contextlib.redirect_stdout(io.StringIO()) as output:
                        self.assertEqual(common.finish_make_case(plan.parent,0 if succeeds else 2),0 if succeeds else 1)
                    self.assertNotIn('[REGR]',output.getvalue())
                    self.assertEqual(len(list(plan.parent.glob('fail_*.list'))),0 if succeeds else 1)


if __name__=='__main__':
    unittest.main()
