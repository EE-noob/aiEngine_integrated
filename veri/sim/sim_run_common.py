"""Shared simulation workspace/seed utilities; no regression scheduling or output."""
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import time
import uuid
from datetime import datetime

HERE = Path(__file__).resolve().parent
ANSI = re.compile(r'\x1b\[[0-9;]*m')
WAVE_SUFFIXES = {'.wlf', '.vcd', '.fst', '.fsdb', '.vpd', '.evcd', '.wdb', '.ghw', '.lxt', '.lxt2'}


def _artifact_operation(path, action):
    # Windows scanners/indexers may briefly hold a just-produced file open.
    for delay in (0, .1, .3, 1, 2):
        if delay:
            time.sleep(delay)
        try:
            return action()
        except OSError as exc:
            if os.name != 'nt' or getattr(exc,'winerror',None) not in (5,32,33) or delay == 2:
                raise
            if getattr(exc,'winerror',None) == 5 and path.is_file() and not path.is_symlink():
                path.chmod(path.stat().st_mode | 0o200)


def mark_run_directory(root):
    """Authorize retention cleanup only for this newly created run directory."""
    root = Path(root).resolve(strict=True)
    (root/'retention.json').write_text(json.dumps({'root':str(root), 'policy':'logs-waves-metadata'},indent=2),encoding='utf-8')


def prune_run_artifacts(root, case=None):
    """Keep logs/waves and run records, without following directory links.

    A case can be pruned while the regression's private workspace/libraries
    remain in use. Full cleanup happens only after all child processes exit.
    """
    root = Path(root).absolute()
    if root.is_symlink() or root.is_junction():
        raise ValueError('Refusing cleanup through a linked run directory')
    root = root.resolve(strict=True)
    marker = root/'retention.json'
    if marker.is_symlink() or json.loads(marker.read_text(encoding='utf-8')).get('root') != str(root):
        raise ValueError('Run retention marker does not match its directory')
    target = Path(case).absolute() if case else root
    if case and (target.parent != root/'cases' or target.is_symlink() or target.is_junction()):
        raise ValueError('Case cleanup must be directly inside this run/cases')
    stats = {'removed_files':0, 'removed_bytes':0, 'archived_files':0}
    errors = []
    transient_locks = []

    def prune(directory):
        # Verify each actual deletion directory stays inside the marked run.
        if not directory.resolve(strict=True).is_relative_to(root):
            raise ValueError('Cleanup directory escapes this run: '+str(directory))
        for path in list(directory.iterdir()):
            try:
                if path.is_junction():
                    _artifact_operation(path,lambda: os.rmdir(path))  # Never visit its target.
                    continue
                if path.is_symlink():
                    _artifact_operation(path,path.unlink)
                    continue
                if path.is_dir():
                    prune(path)
                    if not any(path.iterdir()):
                        _artifact_operation(path,path.rmdir)
                    continue
                relative = path.relative_to(root)
                artifact = path.suffix.lower() in WAVE_SUFFIXES | {'.log'} or path.name.lower() == 'transcript'
                record = (len(relative.parts) == 1 or
                          len(relative.parts) == 3 and relative.parts[0] == 'cases')
                record = record and path.suffix.lower() in {'.json', '.list', '.md'}
                if artifact and relative.parts[0] in {'work', 'libs', 'tmp'}:
                    dest = root/'artifacts'/relative
                    # Do not traverse an unexpected link planted in the archive.
                    for parent in reversed(dest.parents):
                        if parent == root or not parent.is_relative_to(root):
                            continue
                        if parent.is_symlink() or parent.is_junction():
                            raise ValueError('Linked archive directory: '+str(parent))
                    dest.parent.mkdir(parents=True,exist_ok=True)
                    if dest.exists() or dest.is_symlink():
                        raise ValueError('Archive destination already exists: '+str(dest))
                    _artifact_operation(path,lambda: path.rename(dest))
                    stats['archived_files'] += 1
                elif not (artifact or record):
                    size = path.stat().st_size
                    _artifact_operation(path,path.unlink)
                    stats['removed_files'] += 1
                    stats['removed_bytes'] += size
            except (OSError, ValueError) as exc:
                errors.append(str(exc))
                if os.name == 'nt' and getattr(exc,'winerror',None) in (32,33):
                    transient_locks.append(path)

    # Retry the remaining locked entries after the rest of the tree is gone.
    # This also allows directories left nonempty on the first pass to vanish.
    deadline = time.monotonic()+30
    for delay in (0, .5, 1, 2, 4, 8):
        if delay:
            time.sleep(min(delay,max(0,deadline-time.monotonic())))
        errors.clear()
        transient_locks.clear()
        prune(target)
        if not transient_locks or time.monotonic() >= deadline:
            break
    with (root/'cleanup.log').open('a',encoding='utf-8') as stream:
        stream.write(json.dumps({'scope':str(target.relative_to(root)), **stats, 'errors':errors},ensure_ascii=False)+'\n')
    if errors:
        print('[SIM] WARNING: some artifacts could not be removed; see '+str(root/'cleanup.log'),flush=True)
    return stats


def prepare_make_case():
    """Prepare the workspace and write the arguments for the child make."""
    name=os.environ['AI_CASE_NAME']
    target=os.environ['AI_CASE_TARGET']
    if not all(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*',n) for n in (name,target)):
        raise ValueError('Invalid case/target name')
    protected={'OUT_DIR','SIMV','SIM_RUNNER','SIM_LAUNCHER','SOC_CASE_DIR','SOC_RUNTIME_BUILD_DIR',
               'SOC_RUNTIME_CPU_MEM','TFLM_BUILD_DIR','TFLM_HOST_BUILD_DIR','TFLM_LIB','TFLM_HOST_LIB',
               'COMPILE_LOG','SIM_LOG','FSDB','MODELSIM_BUILD_ROOT','TFLM_GENFILES','TFLM_DATA_STAMP',
               'SOC_C_SRC','SOC_RUNTIME_C_SRC'}
    values={}
    for key in os.environ.get('AI_CASE_OVERRIDES','').split():
        if key in protected: raise ValueError(f'{key} redirects isolated output')
        if key in {'ISOLATED_RUN','MAKE','SHELL','simtool','DUMPOPTS'} or key.startswith(('regr_','single_','case_')): continue
        if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',key) and key in os.environ: values[key]=os.environ[key]
    if target in ('run','sim') and named_case_target(name):
        target=name
        values.pop('case',None)
    seed=seed_for(target,values)
    for key in ('REGR_SEED','seed','SOC_SEED','TOP_REGRESS_SEED','SOC_REGRESS_START_SEED','SOC_PERF_SEED'):
        values[key]=str(seed)
    if target in ('run','sim'):
        values.setdefault('case',name)
        args=re.sub(r'(?:^|\s)\+MEM_GEN_SEED=\S+','',values.get('SIM_ARGS','')).strip()
        values['SIM_ARGS']=args+f' +MEM_GEN_SEED={seed}'
    stamp=datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    root=(Path(os.environ.get('AI_CASE_OUT','runs/cases'))/f'{name}_{stamp}_seed_{seed}_{uuid.uuid4().hex[:12]}').resolve()
    root.mkdir(parents=True)
    mark_run_directory(root)
    timeout=float(os.environ.get('AI_CASE_TIMEOUT','3600'))
    if timeout<=0: raise ValueError('single_timeout must be positive')
    keyword=Path(os.environ.get('AI_CASE_KEYWORDS','regr_keywords.json'))
    load_rules(keyword)
    (root/'keywords.json').write_bytes(keyword.read_bytes())
    snapshot=Path(os.environ['AI_CASE_SNAPSHOT']) if os.environ.get('AI_CASE_SNAPSHOT') else None
    if snapshot and not (snapshot/'veri/sim/Makefile').is_file(): raise ValueError('Source snapshot unavailable')
    model=target.startswith('tflm') or target=='soc_sensor_int16x8_output' or values.get('SOC_APP','').startswith('tflm')
    work,alias=prepare_workspace(root,include_tflm=model,project=snapshot)
    repro={'target':target,'seed':seed,'make_vars':values,'simtool':os.environ.get('AI_CASE_TOOL','modelsim'),
           'dumpopts':os.environ.get('AI_CASE_DUMP','0'),'timeout':timeout,
           'keywords':(root/'keywords.json').as_posix(),
           **({'snapshot':snapshot.resolve().as_posix()} if snapshot else {})}
    (root/f'reproduce_seed_{seed}.json').write_text(json.dumps(repro,ensure_ascii=False,indent=2),encoding='utf-8')
    console=root/f'console_seed_{seed}.log'
    console.write_text('[REPRO] '+json.dumps(repro,ensure_ascii=False)+'\n',encoding='utf-8')
    state={'case':name,'reproduce':repro,'log':str(console),'alias':str(alias) if alias else None,'started':time.time()}
    (root/'make_case_state.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
    args=[*[f'{k}={v}' for k,v in values.items()],'ISOLATED_RUN=1',f'simtool={repro["simtool"]}',
          f'DUMPOPTS={repro["dumpopts"]}',f'OUT_DIR={root.as_posix()}/sim']
    shell={ 'CASE_ROOT':root.as_posix(),'CASE_WORK':work.as_posix(),'CASE_TARGET':target,
            'CASE_LOG':console.as_posix(),'CASE_TIMEOUT':str(timeout),'CASE_SEED':str(seed),'CASE_NAME':name}
    plan=root/'make_case.sh'
    plan.write_text('\n'.join(f'{k}={shlex.quote(v)}' for k,v in shell.items())+'\nCASE_ARGS=('+shlex.join(args)+')\n',encoding='utf-8')
    return plan.as_posix()


def launch_windows_make(work, timeout, *command):
    # MSYS make -C resolves the junction and exposes the long snapshot path to
    # native compilers. Create the child directly with the short Windows cwd.
    proc = subprocess.Popen(command, cwd=work)
    try:
        return proc.wait(timeout=float(timeout))
    except subprocess.TimeoutExpired:
        stop_tree(proc)
        return 124
    except KeyboardInterrupt:
        stop_tree(proc)
        return 130


def finish_make_case(root, rc):
    """Record make's exit/result; never starts or schedules simulation."""
    root=Path(root)
    state=json.loads((root/'make_case_state.json').read_text(encoding='utf-8'))
    repro=state['reproduce']; seed=repro['seed']; name=state['case']
    remove_alias(Path(state['alias']) if state['alias'] else None)
    reason='wall-clock timeout' if rc==124 else 'interrupted' if rc in (130,143) else ''
    status,detail=classify(Path(state['log']).read_text(encoding='utf-8',errors='replace'),rc,
                           load_rules(root/'keywords.json'),reason)
    result={**state,'status':status,'reason':detail,'returncode':rc,'seconds':time.time()-state['started'],
            'seed':seed,'target':repro['target']}
    (root/f'result_seed_{seed}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    if status!='PASS':
        failure=root/f'fail_{datetime.now():%Y%m%d_%H%M%S_%f}.list'
        failure.write_text(name+f' seed={seed} # '+replay_command(name,repro)+'\n',encoding='utf-8')
        print('[SIM] replay list:',failure,flush=True)
    prune_run_artifacts(root)
    color={'PASS':32,'FAIL':31,'UNKNOWN':33}[status]
    print(f'[SIM] \033[{color}m{status}\033[0m \033[{color}m{name}\033[0m | seed={seed} | elapsed {duration(result["seconds"])}',flush=True)
    return int(status!='PASS')


def named_case_target(name):
    if name.startswith('ai_'):
        return False  # UVM class names keep the generic run/sim interface.
    presets=set(re.findall(r'^([A-Za-z][A-Za-z0-9_]*):',(HERE/'regr_cases.mk').read_text(encoding='utf-8'),re.M))
    targets=set(re.findall(r'^([A-Za-z][A-Za-z0-9_]*):',(HERE/'Makefile').read_text(encoding='utf-8'),re.M))
    return name in presets or name in targets and (name.endswith('_run') or name in {'npu_top_regress','soc_regress','soc_perf_sweep'})


def replay_command(name, repro):
    """A shell-quoted command, directly executable in the project's Git Bash."""
    values=dict(repro.get('make_vars',{}))
    target=repro.get('target',name)
    case=values.get('case',name) if target in ('run','sim') else target
    args=['make','run',f'case={case}',f'seed={repro["seed"]}',f'simtool={repro["simtool"]}']
    seed_names={'REGR_SEED','seed','SOC_SEED','TOP_REGRESS_SEED','SOC_REGRESS_START_SEED','SOC_PERF_SEED'}
    for key,value in values.items():
        if key in seed_names or key=='case':
            continue
        if key=='SIM_ARGS':
            value=re.sub(r'(?:^|\s)\+MEM_GEN_SEED=\S+','',str(value)).strip()
            if not value: continue
        args.append(f'{key}={value}')
    args += [f'DUMPOPTS={repro.get("dumpopts","0")}',f'single_timeout={repro.get("timeout",3600):g}']
    if repro.get('snapshot'): args.append('single_snapshot='+repro['snapshot'])
    if repro.get('keywords'): args.append('single_keywords='+repro['keywords'])
    return shlex.join(args)


def parse_replay_command(comment):
    if not comment.startswith('make '):
        return {}
    tokens=shlex.split(comment)
    if tokens[:2] not in (['make','run'],['make','sim']):
        raise ValueError('Replay comment must start with make run or make sim')
    values={}
    for token in tokens[2:]:
        key,sep,value=token.partition('=')
        if not sep or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',key):
            raise ValueError('Expected VAR=value in replay command: '+token)
        values[key]=value
    case=values.pop('case')
    seed=int(values.pop('seed'))
    tool=values.pop('simtool','modelsim')
    dump=values.pop('DUMPOPTS','0')
    timeout=float(values.pop('single_timeout','3600'))
    snapshot=values.pop('single_snapshot',None)
    keywords=values.pop('single_keywords',None)
    target=case if named_case_target(case) else tokens[1]
    if target in ('run','sim'): values['case']=case
    for key in ('REGR_SEED','seed','SOC_SEED','TOP_REGRESS_SEED','SOC_REGRESS_START_SEED','SOC_PERF_SEED'):
        values[key]=str(seed)
    return {'target':target,'seed':seed,'make_vars':values,'simtool':tool,'dumpopts':dump,
            'timeout':timeout,**({'snapshot':snapshot} if snapshot else {}),
            **({'keywords':keywords} if keywords else {})}


def seed_for(target, values, explicit=None):
    if explicit is not None:
        value = explicit
    else:
        value = next((values[k] for k in ('REGR_SEED','seed','SOC_SEED') if k in values), None)
        if value is None:
            plan = json.loads((HERE/'coverage_plan.json').read_text(encoding='utf-8'))
            preset = next((x['vars'] for x in plan['tests'] if x['name']==target), {})
            value = preset.get('seed',preset.get('SOC_SEED',1000 if target=='npu_top_regress' else 80000 if target=='soc_perf_sweep' else 1))
    value = int(value)
    if not 0 <= value <= 2147483647:
        raise ValueError('seed must be in 0..2147483647')
    return value


def load_rules(path):
    rules = json.loads(path.read_text(encoding='utf-8-sig'))
    flags = re.M | (0 if rules.get('case_sensitive', True) else re.I)
    compiled = {}
    for kind in ('pass', 'fail'):
        patterns = rules.get(kind)
        if not isinstance(patterns, list) or not patterns or any(not isinstance(p, str) or not p for p in patterns):
            raise ValueError(f'{path}: {kind} must contain nonempty regex strings')
        compiled[kind] = [re.compile(p, flags) for p in patterns]
    return compiled


def classify(text, rc, rules, reason=''):
    text = ANSI.sub('', text)
    if reason:
        return 'UNKNOWN', reason
    if rc != 0:
        return 'FAIL', f'process exit code {rc}'
    for pattern in rules['fail']:
        if pattern.search(text):
            return 'FAIL', f'fail keyword: {pattern.pattern}'
    for pattern in rules['pass']:
        if pattern.search(text):
            return 'PASS', f'pass keyword: {pattern.pattern}'
    return 'UNKNOWN', 'exit code 0 but no pass/fail keyword matched'


def stop_tree(proc):
    if os.name == 'nt':
        subprocess.run(['C:/Windows/System32/taskkill.exe', '/PID', str(proc.pid), '/T', '/F'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        os.killpg(proc.pid, signal.SIGKILL)
    proc.wait()


def stop_if_running(proc):
    """Exit callbacks must stop children before deleting their workspace."""
    if proc.poll() is None:
        stop_tree(proc)


def prepare_workspace(root, include_tflm=True, project=None):
    # Replay sources can exceed MAX_PATH too, independently of destination paths.
    if project is not None and os.name == 'nt':
        import _winapi
        short_source = HERE.parents[2]/'.regr_paths'/(root.name.rsplit('_',1)[-1]+'_src')
        short_source.parent.mkdir(exist_ok=True)
        _winapi.CreateJunction(str(Path(project).resolve()),str(short_source))
        try:
            return _prepare_workspace(root,include_tflm,short_source)
        finally:
            remove_alias(short_source)
    return _prepare_workspace(root,include_tflm,project)


def _prepare_workspace(root, include_tflm=True, project=None):
    """Copy inputs, never hardlink sources; contain relative-path writes."""
    project = Path(project) if project else HERE.parents[1]
    actual = root/'work'
    actual.mkdir()
    work = actual
    alias = None
    if os.name == 'nt':
        # Junction is only a short access path; all bytes remain below root/work.
        alias = HERE.parents[2]/'.regr_paths'/root.name.rsplit('_', 1)[-1]
        alias.parent.mkdir(exist_ok=True)
        if alias.exists():
            raise ValueError(f'Short-path alias already exists: {alias}')
        import _winapi
        _winapi.CreateJunction(str(actual), str(alias))
        work = alias
    ignore = shutil.ignore_patterns('.git', '__pycache__', '.venv', 'build', 'build-*', 'obj_dir', 'runs')
    inputs = ['rtl', 'include', 'picorv32']
    if include_tflm:
        inputs.append('drivers/tflm/my_tflm')
    for name in inputs:
        shutil.copytree(project/name, work/name, ignore=ignore)
    (work/'drivers').mkdir(exist_ok=True)
    shutil.copy2(project/'drivers/gempact_tiling.h', work/'drivers/gempact_tiling.h')
    for name in ('flist', 'interface', 'env', 'test', 'uvc', 'soc_csrc'):
        shutil.copytree(project/'veri'/name, work/'veri'/name, ignore=ignore)
    for name in ('sim', 'tb', 'top_regression', 'tools'):
        src, dst = project/'veri'/name, work/'veri'/name
        dst.mkdir(parents=True)
        for path in src.iterdir():
            if path.is_file() and (name != 'sim' or path.suffix in ('.py', '.mk', '.json', '.hier', '.sh') or path.name in ('Makefile', 'oldMakefile')):
                shutil.copy2(path, dst/path.name)
        if name == 'tb':
            shutil.copytree(src/'sram', dst/'sram', ignore=ignore)
    local = project/'veri/sim/windows.local.mk'
    if os.name == 'nt' and local.is_file():
        config = local.read_text(encoding='utf-8')
        build = work/'build'
        build.mkdir()
        for cache, target in [('tflm-rv32im-hw-S16-C4-P16', 'rv-rv32im-hw-S16-C4-P16'), ('tflm-host-sw', 'host')]:
            library = project/'build/windows'/cache/'libtflite-micro.a'
            if not library.is_file():
                library = project/'build'/target/'libtflite-micro.a'
            if include_tflm and library.is_file():
                dest = build/target
                shutil.copytree(library.parent, dest, ignore=shutil.ignore_patterns('*.exe', '*.rsp'))
        config += ('\nTFLM_BUILD_DIR = ../../../build/rv-$(SOC_ARCH_TAG)-$(TFLM_ACCEL_TAG)-S$(MMA_SIZE)-C$(MMA_IA_CACHE_BLOCKS)-P$(MMA_PS_FRAME_COUNT)\n'
                   'TFLM_HOST_BUILD_DIR := ../../../build/host\n')
        if include_tflm:
            dataset_setting = re.findall(r'^TFLM_MNIST_ACCURACY_DATASET\s*:?=\s*(.*?)\s*$',config,re.M)
            dataset = Path(dataset_setting[-1]) if dataset_setting else Path.home()/'.keras/datasets/mnist.npz'
            if not dataset.is_absolute():
                dataset = project/'veri/sim'/dataset
            if dataset.is_file():
                # Relative inputs must not be resolved against the new workspace.
                data_dir = build/'data'
                data_dir.mkdir(exist_ok=True)
                shutil.copy2(dataset,data_dir/'mnist.npz')
                config += 'TFLM_MNIST_ACCURACY_DATASET := ../../build/data/mnist.npz\n'
        for var in ('MODELSIM_BUILD_ROOT', 'TEMP', 'TMP', 'TMPDIR'):
            dest = root/('libs' if var == 'MODELSIM_BUILD_ROOT' else 'tmp')
            dest.mkdir(exist_ok=True)
            config += f'export {var} := {dest.as_posix()}\n'
        (work/'veri/sim/windows.local.mk').write_text(config, encoding='utf-8')
    return work/'veri/sim', alias


def remove_alias(alias):
    if alias is not None and alias.is_junction():
        # Remove only the junction entry, never traverse the workspace it targets.
        os.rmdir(alias)


def duration(seconds):
    if seconds is None:
        return '--'
    seconds = max(0, int(seconds))
    return f'{seconds//3600:02d}:{seconds//60%60:02d}:{seconds%60:02d}'
