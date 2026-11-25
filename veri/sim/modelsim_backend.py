"""Translate the legacy VCS build/run interface to native ModelSim commands.

The Makefile retains firmware dependencies; this adapter only handles HDL.
Each SIMV marker describes a distinct ModelSim library and elaboration profile.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import argparse
import shlex
import hashlib
import concurrent.futures


def execute(cmd):
    print('[MODELSIM] ' + subprocess.list2cmdline(list(map(str, cmd))), flush=True)
    result = subprocess.run([str(a).replace('\\', '/') for a in cmd])
    if result.returncode:
        raise RuntimeError(f'{cmd[0]} exited {result.returncode}')


def tool(name):
    return str(Path(os.environ['MODELSIM_BIN']) / (name + '.exe')) if os.environ.get('MODELSIM_BIN') else (shutil.which(name) or name)


def flatten(filename):
    result = []
    for line in Path(filename).read_text().splitlines():
        line = line.split('//')[0].strip()
        if not line:
            continue
        if line.startswith('-f '):
            result.extend(flatten(line[3:].strip()))
        else:
            result.append(line)
    return result


def compile_hdl(args):
    output = args[args.index('-o') + 1]
    log = Path(args[args.index('-l') + 1])
    log.parent.mkdir(parents=True, exist_ok=True)
    build_root = Path(os.environ.get('MODELSIM_BUILD_ROOT', '../../build/modelsim')).resolve()
    library = (build_root / (Path(output).name + '.msim')).resolve()
    if library.parent != build_root:
        raise RuntimeError('Library path escapes the selected build root')
    library.parent.mkdir(parents=True, exist_ok=True)
    if library.exists():
        shutil.rmtree(library)
    execute([tool('vlib'), library])
    root = Path(shutil.which(tool('vlog')) or tool('vlog')).resolve().parents[1]
    uvm = Path(os.environ.get('MSIM_UVM_HOME', root / 'verilog_src/uvm-1.1d/src'))
    sources = flatten(args[args.index('-f') + 1])
    defines = [a for a in args if a.startswith('+define+')]
    params = [a[len('-pvalue+'):].split('.', 1)[1] for a in args if a.startswith('-pvalue+')]
    cov = '-cm' in args
    cmd = [tool('vlog'), '-modelsimini', root / 'modelsim.ini', '-sv', '-mfcu', '-work', library, '-L', 'sv_std', '-L', 'mtiUvm',
           '+incdir+' + str(uvm), '+define+SIMTOOL_MODELSIM', '-l', log]
    if cov:
        cmd += ['+cover=bcesft']
    execute(cmd + defines + sources)
    Path(output).write_text(json.dumps({'library': str(library), 'params': params,
                                      'top': args[args.index('-top') + 1], 'coverage': cov}))


def run_hdl(args):
    marker = args.pop(0)
    profile = json.loads(Path(marker).read_text())
    log = Path(args[args.index('-l') + 1])
    log.parent.mkdir(parents=True, exist_ok=True)
    plusargs = [a for a in args if a.startswith('+') and not a.startswith(('+vcs', '+dump_fsdb', '+fsdbfile'))]
    plusargs += ['+PYTHON_BIN=' + Path(sys.executable).as_posix()]
    seed = next((a.split('=')[1] for a in plusargs if a.startswith('+ntb_random_seed=')), '1')
    script = ['onerror {quit -code 1 -f}', 'onbreak {quit -code 1 -f}']
    if '+dump_fsdb' in args:
        script += ['log -r /*']
    if profile['coverage']:
        db = log.parent / 'coverage.ucdb'
        script += ['coverage save -onexit {' + db.resolve().as_posix() + '}']
    script += ['run -all', 'quit -code 0 -f']
    root = Path(shutil.which(tool('vsim')) or tool('vsim')).resolve().parents[1]
    cmd = [tool('vsim'), '-modelsimini', root / 'modelsim.ini', '-c', '-onfinish', 'stop', '-L', 'sv_std', '-L', 'mtiUvm',
           '-lib', profile['library'], profile['top'], '-sv_seed', seed, '-l', log,
           '-wlf', log.parent / f'tb_top_seed_{seed}.wlf']
    if profile['coverage']:
        cmd += ['-coverage']
    cmd += ['-g' + p for p in profile['params']]
    execute(cmd + plusargs + ['-do', '; '.join(script)])
    text = log.read_text(errors='replace')
    banner = r'\[TB\] PASS' if profile['top'] == 'tb_npu_top' else r'TEST PASS'
    if not re.search(banner, text) or re.search(r'UVM_(?:ERROR|FATAL)\s*:\s*[1-9]|\*\* (?:Error|Fatal)', text):
        raise RuntimeError('Simulation did not pass; see ' + str(log))


def wave(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('file', type=Path)
    parser.add_argument('--batch', action='store_true')
    opt = parser.parse_args(args)
    path = opt.file.resolve()
    if not path.is_file() and re.search(r'_seed_\d+\.wlf$',path.name):
        legacy = path.with_name('tb_top.wlf')
        if legacy.is_file():
            path = legacy
    if not path.is_file():
        raise RuntimeError('No WLF; run the same test with DUMPOPTS=1 first')
    root = Path(tool('vsim')).resolve().parents[1]
    command = [tool('vsim'),'-modelsimini',(root/'modelsim.ini').as_posix()]
    if opt.batch:
        execute(command+['-c','-view',path.as_posix(),'-do','quit -f'])
    else:
        subprocess.Popen(command+['-view',path.as_posix()])


def npu(args):
    parser = argparse.ArgumentParser()
    for name, default in [('size',4),('cache',4),('ps',8),('count',20),('seed',1000),('read-outstanding',4)]:
        parser.add_argument('--'+name, type=int, default=default)
    parser.add_argument('--trace', action='store_true')
    parser.add_argument('--gen', default='--random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 32')
    parser.add_argument('--args', default='')
    opt = parser.parse_args(args)
    folder = Path('runs/modelsim_npu_top').resolve()
    folder.mkdir(parents=True, exist_ok=True)
    rtl = Path('../../rtl/axi_accelerator/npu').resolve()
    filelist = folder/'sources.f'
    filelist.write_text('\n'.join(p.as_posix() for p in [
        Path('../top_regression/tb_npu_top.sv').resolve(),
        Path('../top_regression/ddr_axi_mem_model.sv').resolve(),
        *sorted(rtl.glob('*.sv')), *sorted(rtl.glob('*.v'))]))
    marker = str(folder/f'model_s{opt.size}_c{opt.cache}_p{opt.ps}_ro{opt.read_outstanding}')
    compile_hdl(['-o',marker,'-l',str(folder/f'compile_seed_{opt.seed}.log'),'-f',str(filelist),'-top','tb_npu_top',
        f'+define+TB_SIZE={opt.size}',f'+define+TB_IA_CACHE_BLOCKS={opt.cache}',
        f'+define+TB_PS_FRAME_COUNT={opt.ps}',
        f'+define+TB_AXI_READ_OUTSTANDING={opt.read_outstanding}'])
    summary = []
    for seed in range(opt.seed, opt.seed+opt.count):
        case = folder/f'seed_{seed}'
        execute([sys.executable,'../top_regression/gen_mem.py','--out_dir',case,
                 '--size',str(opt.size),'--ia_cache_blocks',str(opt.cache),
                 '--ps_frame_count',str(opt.ps),'--seed',str(seed),*shlex.split(opt.gen)])
        run_hdl([marker,'-l',str(case/f'sim_seed_{seed}.log'),'+INIT_MEM='+str(case/'init.mem'),
                 '+GOLDEN_MEM='+str(case/'golden.mem'),'+CASE_MEM='+str(case/'config.mem'),
                 *shlex.split(opt.args),f'+DDR_SEED={seed}',f'+ntb_random_seed={seed}',
                 *(['+dump_fsdb'] if opt.trace else [])])
        summary.append({'seed':seed,'passed':True,'log':str(case/f'sim_seed_{seed}.log')})
        (folder/'summary.json').write_text(json.dumps(summary,indent=2))
    print(f'[run_random] PASS={len(summary)} FAIL=0')


def definition_report(opt, databases):
    """Union native executed source lines, matching the legacy line/definition goal.

    Report each elaboration independently: ModelSim 10.4 cannot safely merge
    UCDB statement layouts from different array/PS parameter elaborations.
    """
    npu_scope = bool(opt.hier) and 'u_npu_axil_top' in Path(opt.hier).read_text()
    rules = json.loads(Path('coverage_line_exclude.json').read_text(encoding='utf-8'))['exclude']
    def extract(database):
        output = database.parent/'native_statement_details.txt'
        if not output.exists() or output.stat().st_mtime < database.stat().st_mtime:
            execute([tool('vcover'),'report','-details','-byfile','-code','s','-file',output,database])
        return output
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        details = list(pool.map(extract,databases))
    lines = {}
    excluded = set()
    sources = {}
    for detail in details:
        filename = None
        for row in detail.read_text(errors='replace').splitlines():
            header = re.match(r'=== File:\s+(.+)',row)
            if header:
                filename = header[1].strip()
                if npu_scope:
                    eligible = '/npu/' in filename or '/axi_top/' in filename and Path(filename).stem != 'axil_top_with_ram'
                else:
                    eligible = '/rtl/' in filename or '/picorv32/' in filename or '/tb/sram/' in filename
                if not eligible:
                    filename = None
                continue
            if filename is None:
                continue
            # Fixed native detail columns: source line, statement count, hits.
            match = re.match(r'^\s*(\d+)\s+(\d+)\s+(\*{3}\d+\*{3}|\d+)\s*$',row[:52])
            if not match:
                if re.match(r'^\s*\d+\s+\d+\s+',row[:52]):
                    raise RuntimeError('Unrecognized native statement row: '+row[:52])
                continue
            if int(match[2]) == 0:
                continue
            path = Path(filename)
            if filename not in sources:
                sources[filename] = path.read_text(encoding='utf-8').splitlines()
            number = int(match[1])
            key = (filename,number)
            source = sources[filename][number-1]
            if any(re.search(rule['pattern'],source) for rule in rules):
                excluded.add(key)
                continue
            lines[key] = lines.get(key,False) or int(match[3].strip('*')) > 0
    if not lines:
        raise RuntimeError('No native source-line evidence found')
    hits = sum(lines.values())
    score = 100*hits/len(lines)
    result = {'tool':'modelsim','metric':'line','source':'native vcover statement detail rows',
              'merge_mode':'definition','active':len(lines),'hits':hits,'misses':len(lines)-hits,
              'score':score,'goal':opt.goal,'passed':score>=opt.goal,
              'excluded_source_lines':len(excluded),'exclusion_rules':'coverage_line_exclude.json',
              'databases':list(map(str,databases)),
              'source_sha256':{name:hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in sources},
              'uncovered':[{'source':key[0],'line':key[1]} for key,value in sorted(lines.items()) if not value]}
    (opt.root/'native_line_evidence.json').write_text(json.dumps(
        [{'source':k[0],'line':k[1],'hit':v} for k,v in sorted(lines.items())],indent=2),encoding='utf-8')
    for stem in ('coverage_report_summary','coverage_code_report_summary'):
        (opt.root/(stem+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
        (opt.root/(stem+'.md')).write_text(
            f'# ModelSim native line coverage\n\nDefinition union of native statement source lines.\n\n'
            f'Active: {len(lines)}; hit: {hits}; excluded: {len(excluded)}.\n\n'
            f'Coverage: {score:.4f}%; goal: {opt.goal}%; passed: {result["passed"]}.\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('metric','active','hits','score','goal','passed')}))
    if not result['passed']:
        raise RuntimeError(f'Native line coverage {score:.4f}% below {opt.goal}%')


def report(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--goal', type=float, default=95)
    parser.add_argument('--hier', default='')
    parser.add_argument('--merge-mode', choices=['instance','definition'], default='instance')
    opt = parser.parse_args(args)
    databases = sorted(p for p in opt.root.rglob('coverage.ucdb'))
    if not databases:
        raise RuntimeError('No UCDB databases under ' + str(opt.root))
    if opt.merge_mode == 'definition':
        return definition_report(opt,databases)
    merged = opt.root/'merged.ucdb'
    execute([tool('vcover'),'merge',merged,*databases])
    raw = opt.root/'modelsim_coverage_raw.txt'
    execute([tool('vcover'),'report','-code','s','-totals','-file',raw,merged])
    exclusions = []
    rulefile = Path('coverage_line_exclude.json')
    if rulefile.is_file():
        rules = json.loads(rulefile.read_text(encoding='utf-8'))['exclude']
        sources = set(flatten('../flist/tb_axil.f') + flatten('../flist/tb_axi_soc.f'))
        commands = ['onerror {quit -code 1 -f}']
        for filename in sorted(sources):
            path = Path(filename)
            if filename.startswith('+') or not path.is_file():
                continue
            lines = []
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                reasons = [r['reason'] for r in rules if re.search(r['pattern'],line)]
                if reasons:
                    lines.append(number)
                    exclusions.append({'source':filename,'line':number,'reasons':reasons})
            if lines:
                commands.append('coverage exclude -srcfile {' + filename +
                                '} -code s -linerange ' + ' '.join(map(str,lines)))
        filtered = opt.root/'filtered.ucdb'
        commands += ['coverage save -codeAll {' + filtered.resolve().as_posix() + '}', 'quit -f']
        script = opt.root/'apply_exclusions.do'
        script.write_text('\n'.join(commands),encoding='utf-8')
        execute([tool('vsim'),'-c','-viewcov',merged,'-do','do {'+script.resolve().as_posix()+'}'])
        (opt.root/'modelsim_exclusions.json').write_text(json.dumps(exclusions,indent=2),encoding='utf-8')
        merged = filtered
    output = opt.root/'modelsim_coverage.txt'
    scope = []
    if opt.hier:
        hierarchy = Path(opt.hier).read_text()
        roots = re.findall(r'\+tree\s+(\S+)', hierarchy)
        if not roots:
            raise RuntimeError('No +tree in hierarchy file')
        path = roots[0]
        path = 'tb_top.*.u_npu_axil_top' if path.endswith('.u_npu_axil_top') else path
        scope = ['-instance','/' + path.replace('.', '/'),'-recursive']
    execute([tool('vcover'),'report','-code','s','-totals',*scope,'-file',output,merged])
    text = output.read_text(errors='replace')
    print(text)
    # Require a numeric statement coverage score; missing evidence never passes.
    scores = re.findall(r'Total coverage[^\n]*?:\s*([\d.]+)%',text,re.I)
    if not scores:
        raise RuntimeError('No statement coverage metric in ' + str(output))
    score = float(scores[-1])
    result = {'tool':'modelsim','metric':'statement','score':score,'goal':opt.goal,
              'passed':score>=opt.goal,'databases':[str(p) for p in databases],
              'exclusion_rules':str(rulefile),'excluded_source_lines':len(exclusions),
              'merge_mode':opt.merge_mode}
    for stem in ('coverage_report_summary','coverage_code_report_summary'):
        (opt.root/(stem+'.json')).write_text(json.dumps(result,indent=2))
        (opt.root/(stem+'.md')).write_text(f'# ModelSim native coverage\n\nStatement coverage: {score}%\nGoal: {opt.goal}%\nPassed: {result["passed"]}\n')
    if score < opt.goal:
        raise RuntimeError(f'Statement coverage {score}% below {opt.goal}%')


if __name__ == '__main__':
    try:
        {'compile': compile_hdl, 'run': run_hdl, 'wave':wave, 'npu':npu,
         'report':report}[sys.argv[1]](sys.argv[2:])
    except (RuntimeError, OSError, ValueError, KeyError) as exc:
        print('[MODELSIM] ERROR:', exc, file=sys.stderr)
        sys.exit(1)
