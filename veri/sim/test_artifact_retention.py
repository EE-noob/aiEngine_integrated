"""Retention boundaries: preserve evidence and never traverse linked inputs."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from sim_run_common import mark_run_directory, prune_run_artifacts, _artifact_operation


class RetentionTests(unittest.TestCase):
    def put(self, root, name, data=b'fixture'):
        path = root/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(data)
        return path

    def test_completed_run_keeps_evidence_and_removes_private_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)/'run'; root.mkdir()
            mark_run_directory(root)
            retained = ['console_seed_7.log','sim/compile_seed_7.log','sim/tb_top_seed_7.wlf',
                        'sim/nested/waves.fsdb','summary.json','keywords.json','fail_20261125.list',
                        'cases/001_case_seed_7/reproduce_seed_7.json','cases/001_case_seed_7/sim/waves.vcd']
            removed = ['work/rtl/top.sv','work/veri/env/agent.sv','work/build/host/lib.a',
                       'libs/design.msim/_info','tmp/tool.tmp','sim/cpu.mem','sim/simv.daidir/obj.o',
                       'make_case.sh']
            for name in retained+removed:
                self.put(root,name)
            self.put(root,'work/veri/sim/runs/npu/seed_7/sim.log',b'inner log')
            self.put(root,'work/veri/sim/runs/npu/seed_7/waves.fst',b'inner wave')
            self.put(root,'libs/compiler/transcript',b'compiler log')
            prune_run_artifacts(root)
            for name in retained:
                self.assertTrue((root/name).is_file(),name)
            for name in removed+['work','libs','tmp']:
                self.assertFalse((root/name).exists(),name)
            self.assertEqual((root/'artifacts/work/veri/sim/runs/npu/seed_7/sim.log').read_bytes(),b'inner log')
            self.assertEqual((root/'artifacts/work/veri/sim/runs/npu/seed_7/waves.fst').read_bytes(),b'inner wave')
            self.assertEqual((root/'artifacts/libs/compiler/transcript').read_bytes(),b'compiler log')
            prune_run_artifacts(root)  # Safe to repeat.

    def test_case_cleanup_does_not_touch_shared_work_or_other_runs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)/'run'; root.mkdir(); mark_run_directory(root)
            case = root/'cases/001_case_seed_1'
            self.put(root,'cases/001_case_seed_1/sim/log.log')
            self.put(root,'cases/001_case_seed_1/sim/wave.wlf')
            self.put(root,'cases/001_case_seed_1/sim/cpu.bin')
            self.put(root,'work/rtl/top.sv')
            self.put(root,'libs/shared/_info')
            sibling = self.put(Path(folder),'other_run/work/rtl/top.sv')
            prune_run_artifacts(root,case)
            self.assertFalse((case/'sim/cpu.bin').exists())
            self.assertTrue((case/'sim/log.log').is_file())
            self.assertTrue((root/'work/rtl/top.sv').is_file())
            self.assertTrue((root/'libs/shared/_info').is_file())
            self.assertTrue(sibling.is_file())
            with self.assertRaises(ValueError):
                prune_run_artifacts(root,Path(folder)/'other_run')

    def test_cleanup_requires_matching_run_marker(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sentinel = self.put(root,'rtl/top.sv')
            with self.assertRaises(FileNotFoundError):
                prune_run_artifacts(root)
            (root/'retention.json').write_text(json.dumps({'root':str(root/'different')}))
            with self.assertRaises(ValueError):
                prune_run_artifacts(root)
            self.assertTrue(sentinel.exists())

    def test_directory_link_is_unlinked_without_deleting_its_target(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)/'run'; root.mkdir(); mark_run_directory(root)
            outside = Path(folder)/'source'
            sentinel = self.put(outside,'rtl/top.sv',b'original RTL')
            link = root/'work'; link.mkdir()
            link = link/'external'
            if os.name == 'nt':
                import _winapi
                _winapi.CreateJunction(str(outside),str(link))
            else:
                link.symlink_to(outside,target_is_directory=True)
            prune_run_artifacts(root)
            self.assertEqual(sentinel.read_bytes(),b'original RTL')
            self.assertFalse(link.exists())

    @unittest.skipUnless(os.name == 'nt','Windows file sharing violation')
    def test_transient_windows_file_lock_is_retried(self):
        locked = PermissionError('file temporarily open'); locked.winerror = 32
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'intermediate.o'
            with patch('sim_run_common.time.sleep'), patch.object(Path,'unlink',side_effect=[locked,None]) as unlink:
                _artifact_operation(path,path.unlink)
                self.assertEqual(unlink.call_count,2)

    @unittest.skipUnless(os.name == 'nt','Windows file sharing violation')
    def test_locked_file_is_revisited_after_the_rest_of_the_tree(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); mark_run_directory(root)
            locked = self.put(root,'work/rtl/top.sv')
            attempts = []
            def operation(path, action):
                if path == locked:
                    attempts.append(path)
                    if len(attempts) == 1:
                        error = PermissionError('indexer still reading'); error.winerror = 32
                        raise error
                return action()
            with patch('sim_run_common._artifact_operation',side_effect=operation), patch('sim_run_common.time.sleep'):
                prune_run_artifacts(root)
            self.assertEqual(len(attempts),2)
            self.assertFalse((root/'work').exists())
            self.assertEqual(json.loads((root/'cleanup.log').read_text())['errors'],[])


if __name__ == '__main__':
    unittest.main()
