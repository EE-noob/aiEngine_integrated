"""List-driven make regression with isolated workspaces and live progress."""
import argparse
from contextlib import ExitStack
import hashlib
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import secrets
import signal
import subprocess
import sys
import time
import uuid

from sim_run_common import (HERE, ANSI, seed_for, load_rules, classify, stop_tree,
                            prepare_workspace, remove_alias, duration, replay_command, parse_replay_command,
                            mark_run_directory, prune_run_artifacts, stop_if_running)
REPRO_TAG = 'REPRO_JSON='


def repro_settings(comment):
    if not comment.startswith(REPRO_TAG):
        return parse_replay_command(comment)
    data = json.loads(comment[len(REPRO_TAG):])
    if not isinstance(data,dict) or not isinstance(data.get('make_vars',{}),dict):
        raise ValueError('Invalid REPRO_JSON object')
    return data




def read_cases(value):
    path = Path(value)
    if path.suffix != '.list':
        path = Path(str(path) + '.list')
    if not path.is_file():
        path = HERE / 'regr' / path
    rows = []
    for number, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        body, _, comment = line.partition('#')
        words = shlex.split(body)
        if not words:
            continue
        name = words[0]
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', name):
            raise ValueError(f'{path}:{number}: invalid case/target name')
        if name in {'regr', 'clean', 'cov_clean', 'help', 'vd'}:
            raise ValueError(f'{path}:{number}: {name} is not a regression case')
        params={}
        for word in words[1:]:
            key,sep,value=word.partition('=')
            if key!='seed' or not sep or key in params or not re.fullmatch(r'\d+',value):
                raise ValueError(f'{path}:{number}: expected case [seed=INTEGER] # comment')
            params[key]=str(seed_for(name,{},int(value)))
        rows.append((name, comment.strip(), number, params))
    if not rows:
        raise ValueError(f'{path}: no cases')
    return path.resolve(), rows
















def main():
    with ExitStack() as cleanup:
        return run(cleanup)


def run(cleanup):
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--list')
    selection.add_argument('--case', help='Single make target, isolated like a regression')
    parser.add_argument('--display-name', help='Single-case directory/display name')
    parser.add_argument('--override-names', default='', help='Names of exported make command-line inputs')
    parser.add_argument('--make', default='make')
    parser.add_argument('--simtool', choices=['modelsim', 'vcs'], required=True)
    parser.add_argument('--out', type=Path, default=Path('runs/regr'))
    parser.add_argument('--keywords', type=Path, default=HERE/'regr_keywords.json')
    parser.add_argument('--timeout', type=float, default=3600)
    parser.add_argument('--interval', type=float, default=5)
    parser.add_argument('--seed', type=int)
    parser.add_argument('--repeat', type=int, default=1)
    parser.add_argument('--dumpopts', choices=['0', '1'], default='0')
    parser.add_argument('--color', choices=['always', 'auto', 'never'], default='always')
    parser.add_argument('--fail-fast', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    opt = parser.parse_args()
    if opt.timeout <= 0 or opt.interval <= 0 or opt.repeat < 1:
        parser.error('timeout, interval and repeat must be positive')
    os.chdir(HERE)
    if opt.case:
        label = opt.display_name or opt.case
        if not all(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', n) for n in (opt.case,label)):
            parser.error('case and display name must be target identifiers')
        source, cases = Path(label+'.list'), [(label,'single-case invocation',1,{})]
    else:
        source, cases = read_cases(opt.list)
    replay = [repro_settings(comment) for _,comment,_,_ in cases]
    snapshots = {r['snapshot'] for r in replay if r.get('snapshot')}
    if len(snapshots)>1:
        parser.error('A replay list must reference one source snapshot')
    snapshot = Path(next(iter(snapshots))) if snapshots else None
    if snapshot and not (snapshot/'veri/sim/Makefile').is_file():
        parser.error(f'Replay snapshot unavailable: {snapshot}')
    if replay and replay[0].get('keywords'):
        opt.keywords = Path(replay[0]['keywords'])
    protected = {'OUT_DIR','SIMV','SIM_RUNNER','SIM_LAUNCHER','SOC_CASE_DIR','SOC_RUNTIME_BUILD_DIR',
                 'SOC_RUNTIME_CPU_MEM','TFLM_BUILD_DIR','TFLM_HOST_BUILD_DIR','TFLM_LIB','TFLM_HOST_LIB',
                 'COMPILE_LOG','SIM_LOG','FSDB','MODELSIM_BUILD_ROOT','TFLM_GENFILES','TFLM_DATA_STAMP',
                 'SOC_C_SRC','SOC_RUNTIME_C_SRC'}
    overrides = []
    for name in opt.override_names.split():
        if name in protected:
            parser.error(f'{name} redirects isolated files; configure inputs in a case target instead')
        if name in {'ISOLATED_RUN','MAKE','SHELL','simtool','DUMPOPTS','regrlist'} or name.startswith(('regr_','case_')):
            continue
        if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name) and name in os.environ:
            overrides.append(f'{name}={os.environ[name]}')
    base_values = dict(v.split('=',1) for v in overrides)
    rules = load_rules(opt.keywords)
    started = time.monotonic()
    run_stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    initial_seed = seed_for(opt.case,base_values,opt.seed) if opt.case else None
    root = opt.out/f'{source.stem}_{run_stamp}{"_seed_"+str(initial_seed) if initial_seed is not None else ""}_{uuid.uuid4().hex[:12]}'
    root = root.resolve()
    root.mkdir(parents=True)
    mark_run_directory(root)
    cleanup.callback(prune_run_artifacts,root)
    if opt.case:
        (root/source.name).write_text(opt.case+' # single-case invocation\n',encoding='utf-8')
    else:
        shutil.copy2(source, root/source.name)
    shutil.copy2(opt.keywords, root/'keywords.json')
    results = []
    fail_list = root/f'fail_{run_stamp}.list'
    current = None
    total = len(cases)*opt.repeat
    color = opt.color == 'always' or opt.color == 'auto' and sys.stdout.isatty()
    history = {}
    for summary in sorted(root.parent.glob(f'{source.stem}_*/summary.json'), reverse=True):
        try:
            previous = json.loads(summary.read_text(encoding='utf-8'))
            if previous.get('simtool') == opt.simtool:
                for row in previous['results']:
                    if row['status'] == 'PASS':
                        history.setdefault(row['case'], row['seconds'])
        except (OSError, ValueError, KeyError):
            continue

    def emit(message, status=None):
        with (root/'progress.log').open('a', encoding='utf-8') as stream:
            stream.write(message+'\n')
        colors = {'PASS':32, 'FAIL':31, 'UNKNOWN':33}
        if color and status in colors:
            match = re.fullmatch(r'(\[REGR\] )('+status+r')(\s+\d+/\d+\s+)(\S+)(.*)', message)
            if match:
                tint, reset = f'\033[{colors[status]}m', '\033[0m'
                message = (match[1]+tint+match[2]+reset+match[3]
                           +tint+match[4]+reset+match[5])
        print(message, flush=True)

    def eta():
        estimates = dict(history)
        estimates.update({r['case']:r['seconds'] for r in results if r['status']=='PASS'})
        mean = sum(r['seconds'] for r in results)/len(results) if results else None
        remaining = [cases[i % len(cases)][0] for i in range(len(results),total)]
        values = [estimates.get(n,mean) for n in remaining]
        if any(v is None for v in values):
            return None
        elapsed = time.monotonic()-current['start'] if current else 0
        if current and values:
            # Do not claim zero remaining while an underestimated case still runs.
            values[0] = max(values[0], elapsed*1.25)
        return sum(values) - elapsed

    def progress_times():
        elapsed = time.monotonic()-started
        remaining = eta()
        estimate = elapsed+remaining if remaining is not None else None
        return f'total {duration(elapsed)} | ETA remaining {duration(remaining)} | estimated total {duration(estimate)}'

    def save():
        counts = {s:sum(r['status']==s for r in results) for s in ('PASS','FAIL','UNKNOWN','DRY_RUN')}
        remaining = eta()
        elapsed = time.monotonic()-started
        doc = {'list':str(source), 'mode':'single' if opt.case else 'regression', 'simtool':opt.simtool, 'dry_run':opt.dry_run,
               'requested':total, 'completed':len(results), 'counts':counts,
               'elapsed_seconds':elapsed, 'estimated_remaining_seconds':remaining,
               'estimated_total_seconds':elapsed+remaining if remaining is not None else None,
               'current_case_elapsed_seconds':time.monotonic()-current['start'] if current else None,
               'current_case':current['case'] if current else None,
               'current_case_seed':current['seed'] if current else None,
               'current_reproduce':current['reproduce'] if current else None,
               'fail_list':str(fail_list) if any(r['status'] in ('FAIL','UNKNOWN') for r in results) else None,
               'passed':counts['PASS']==total, 'results':results}
        (root/'summary.json').write_text(json.dumps(doc, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        lines = ['# Regression results', '', f'Total elapsed: {duration(doc["elapsed_seconds"])}; ETA remaining: {duration(eta())}', '',
                 '| Case | Seed | Status | Elapsed | Reason | Log |', '|---|---:|---|---|---|---|']
        lines += [f'| {r["case"]} | {r["seed"]} | {r["status"]} | {duration(r["seconds"])} | {r["reason"]} | [log]({Path(r["log"]).relative_to(root).as_posix()}) |' for r in results]
        (root/'summary.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
        failed = [r for r in results if r['status'] in ('FAIL','UNKNOWN')]
        if failed:
            entries = ['# Replay: make regr regrlist='+fail_list.as_posix(),
                       '# Uses current project sources unless an external single_snapshot is specified; retain keywords.json.']
            entries += [r['case']+f' seed={r["seed"]} # '+replay_command(r['case'],r['reproduce']) for r in failed]
            fail_list.write_text('\n'.join(entries)+'\n',encoding='utf-8')

    emit(f'[REGR] directory: {root}')
    emit('[REGR] preparing isolated workspace (copy source inputs and private library caches)...')
    needs_tflm = any(n.startswith('tflm') or n == 'soc_sensor_int16x8_output' for n,_,_,_ in cases)
    needs_tflm = needs_tflm or any(v.startswith('SOC_APP=tflm') for v in overrides)
    needs_tflm = needs_tflm or any(r.get('make_vars',{}).get('SOC_APP','').startswith('tflm') for r in replay)
    work, alias = prepare_workspace(root, include_tflm=needs_tflm, project=snapshot) if not opt.dry_run else (HERE,None)
    cleanup.callback(remove_alias,alias)
    input_sim = snapshot/'veri/sim' if snapshot else HERE
    manifest = {'source_project':str(snapshot.resolve() if snapshot else HERE.parents[1]),'python':sys.version,
                'inputs_sha256':{name:hashlib.sha256((input_sim/name).read_bytes()).hexdigest()
                                 for name in ('Makefile','regr_cases.mk','modelsim_backend.py')}}
    (root/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    env = os.environ.copy()
    for key in ('MAKEFLAGS','MFLAGS','MAKEOVERRIDES'):
        env.pop(key,None)
    env['MODELSIM_BUILD_ROOT'] = (root/'libs').as_posix()
    used_seeds=set()
    for repeat in range(opt.repeat):
        for name, comment, line, line_params in cases:
            entry = repro_settings(comment)
            target = entry.get('target',opt.case or name)
            values = {**base_values,**entry.get('make_vars',{}),**line_params}
            if 'seed' in line_params:
                actual_seed=int(line_params['seed']); seed_origin='list'
            elif 'seed' in entry:
                actual_seed=int(entry['seed']); seed_origin='replay'
            elif opt.seed is not None or any(k in base_values for k in ('REGR_SEED','seed','SOC_SEED')):
                actual_seed=seed_for(target,base_values,opt.seed)+repeat; seed_origin='global'
            elif opt.case:
                actual_seed=seed_for(target,values); seed_origin='single-default'
            else:
                actual_seed=secrets.randbelow(2147483647)+1
                while actual_seed in used_seeds:
                    actual_seed=secrets.randbelow(2147483647)+1
                seed_origin='random'
            actual_seed = seed_for(target,{},actual_seed)
            used_seeds.add(actual_seed)
            for key in ('REGR_SEED','seed','SOC_SEED','TOP_REGRESS_SEED','SOC_REGRESS_START_SEED','SOC_PERF_SEED'):
                values[key] = str(actual_seed)
            if target in ('run','sim'):
                sim_args = values.get('SIM_ARGS','')
                sim_args = re.sub(r'(?:^|\s)\+MEM_GEN_SEED=\S+','',sim_args).strip()
                values['SIM_ARGS'] = sim_args+f' +MEM_GEN_SEED={actual_seed}'
            case_tool = entry.get('simtool',opt.simtool)
            case_timeout = float(entry.get('timeout',opt.timeout))
            folder = root/'cases'/f'{len(results)+1:03d}_{name}_seed_{actual_seed}'
            folder.mkdir(parents=True)
            log = folder/f'console_seed_{actual_seed}.log'
            output = folder/'sim'
            cmd = [opt.make,'--no-print-directory','-j1',target,*[f'{k}={v}' for k,v in values.items()],
                   'ISOLATED_RUN=1',f'simtool={case_tool}',f'DUMPOPTS={entry.get("dumpopts",opt.dumpopts)}',f'OUT_DIR={output.as_posix()}']
            reproduction = {'target':target,'seed':actual_seed,'make_vars':values,'simtool':case_tool,'timeout':case_timeout,
                            'dumpopts':entry.get('dumpopts',opt.dumpopts),
                            'keywords':(root/'keywords.json').as_posix(),
                            **({'snapshot':snapshot.resolve().as_posix()} if snapshot else {})}
            (folder/f'reproduce_seed_{actual_seed}.json').write_text(json.dumps(reproduction,ensure_ascii=False,indent=2),encoding='utf-8')
            current = {'case':name,'start':time.monotonic(),'seed':actual_seed,'reproduce':reproduction}
            save()
            reason = ''
            rc = None
            try:
                if opt.dry_run:
                    log.write_text(subprocess.list2cmdline(cmd)+'\n',encoding='utf-8')
                    status, reason = 'DRY_RUN','command only; no simulation'
                else:
                    with log.open('wb') as stream:
                        stream.write(('[REPRO] '+json.dumps(reproduction,ensure_ascii=False)+'\n').encode('utf-8'))
                        stream.flush()
                        proc = subprocess.Popen(cmd,cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=os.name!='nt')
                        cleanup.callback(stop_if_running,proc)
                        while True:
                            try:
                                rc = proc.wait(timeout=min(opt.interval,max(.01,case_timeout-(time.monotonic()-current['start']))))
                                break
                            except subprocess.TimeoutExpired:
                                elapsed = time.monotonic()-current['start']
                                if elapsed >= case_timeout:
                                    stop_tree(proc)
                                    reason = f'timeout after {case_timeout:g}s; process tree terminated'
                                    break
                                save()
                            except KeyboardInterrupt:
                                stop_tree(proc)
                                reason = 'interrupted; process tree terminated'
                                break
                    status, reason = classify(log.read_text(encoding='utf-8',errors='replace'),rc,rules,reason)
            except OSError as exc:
                status, reason = 'UNKNOWN',str(exc)
            results.append({'case':name,'repeat':repeat+1,'list_line':line,'description':comment,
                            'target':target,'seed':actual_seed,'seed_origin':seed_origin,'make_vars':values,'reproduce':reproduction,
                            'status':status,'reason':reason,'returncode':rc,'seconds':time.monotonic()-current['start'],
                            'command':cmd,'log':str(log)})
            current = None
            save()
            prune_run_artifacts(root,folder)
            emit(f'[REGR] {status} {len(results)}/{total} {name} | seed={actual_seed} | case {duration(results[-1]["seconds"])} | {progress_times()} | {reason}',status)
            if reason.startswith('interrupted') or opt.fail_fast and status not in ('PASS','DRY_RUN'):
                emit(f'[REGR] summary: {root / "summary.md"}')
                remove_alias(alias)
                return 1
    counts = ' '.join(f'{s}={sum(r["status"]==s for r in results)}' for s in ('PASS','FAIL','UNKNOWN'))
    emit(f'[REGR] DONE {counts} | total {duration(time.monotonic()-started)} | summary: {root / "summary.md"}'
         +(f' | fail list: {fail_list}' if fail_list.exists() else ''))
    remove_alias(alias)
    return int(any(r['status'] not in ('PASS','DRY_RUN') for r in results))


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError,ValueError,re.error,subprocess.CalledProcessError) as exc:
        print(f'[REGR] ERROR: {exc}',file=sys.stderr)
        sys.exit(2)
