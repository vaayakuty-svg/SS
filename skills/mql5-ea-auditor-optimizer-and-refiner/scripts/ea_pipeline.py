#!/usr/bin/env python3
"""MQL5 EA pipeline: detect toolchain -> compile -> baseline -> optimize -> select -> verify -> stress.

Subcommands
  detect                       find metaeditor64.exe / terminal64.exe / data folder (Windows or Wine)
  compile  --ea X.mq5          compile and parse the log (exit 1 on errors)
  run      --ea X.mq5 ...      full round: compile, baseline, optimization, selection, verification, stress
  package  --ea X.mq5 ...      write _audit/run_all.ps1 + .ini/.set files for the user to run on their PC

Common options
  --terminal PATH  --metaeditor PATH  --data PATH (terminal data folder)  --portable  --wine
  --symbol XAUUSD --period M15 --from 2022.11.01 --to 2025.10.31 --forward-date 2024.12.01
  --model 4 --deposit 10000 --leverage 1:100 --optimize InpA,InpB,InpC|auto --stress-symbol XAUUSD_STRESS
  --min-trades 200 --timeout 7200

Every result printed comes from a file the tester or MetaEditor wrote in this run; each record in
_audit/runs.jsonl names its source file. If a step cannot run, the pipeline says so and stops.
"""
import argparse, datetime as dt, glob, json, os, platform, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
IS_WIN = platform.system() == 'Windows'


# ---------------------------------------------------------------- helpers
def log_run(audit, rec):
    rec['time'] = dt.datetime.now().isoformat(timespec='seconds')
    with open(os.path.join(audit, 'runs.jsonl'), 'a', encoding='utf-8') as f:
        f.write(json.dumps(rec) + '\n')


def script(name, *args, check=False):
    r = subprocess.run([PY, os.path.join(HERE, name)] + [str(a) for a in args], capture_output=True, text=True)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    if check and r.returncode != 0:
        raise SystemExit(f'{name} failed ({r.returncode})')
    return r


def to_win(path, wine):
    if not wine:
        return path
    r = subprocess.run(['winepath', '-w', path], capture_output=True, text=True)
    return r.stdout.strip() or path


def exe_cmd(exe, wine):
    return (['wine', exe] if wine else [exe])


def read_any(path):
    raw = open(path, 'rb').read()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')
    return raw.decode('utf-8', 'replace')


# ---------------------------------------------------------------- detection
def candidates_install(wine):
    roots = []
    if IS_WIN:
        for env in ('ProgramFiles', 'ProgramFiles(x86)'):
            if os.environ.get(env):
                roots.append(os.environ[env])
    if wine or not IS_WIN:
        roots += glob.glob(os.path.expanduser('~/.wine/drive_c/Program Files*'))
    found = []
    for r in roots:
        found += glob.glob(os.path.join(r, '*', 'terminal64.exe'))
    return found


def data_folder_for(install, wine, portable):
    if portable:
        return install
    bases = []
    if IS_WIN and os.environ.get('APPDATA'):
        bases.append(os.path.join(os.environ['APPDATA'], 'MetaQuotes', 'Terminal'))
    bases += glob.glob(os.path.expanduser('~/.wine/drive_c/users/*/AppData/Roaming/MetaQuotes/Terminal'))
    inst_win = to_win(install, wine).lower().rstrip('\\')
    for b in bases:
        for origin in glob.glob(os.path.join(b, '*', 'origin.txt')):
            try:
                if read_any(origin).strip().lower().rstrip('\\') in (inst_win, install.lower().rstrip('\\/')):
                    return os.path.dirname(origin)
            except OSError:
                pass
    return None


def detect(a):
    wine = a.wine or (not IS_WIN and shutil.which('wine') is not None)
    terminal = a.terminal
    if not terminal:
        c = candidates_install(wine)
        terminal = c[0] if c else None
    install = os.path.dirname(terminal) if terminal else None
    metaeditor = a.metaeditor or (os.path.join(install, 'metaeditor64.exe') if install else None)
    data = a.data or (data_folder_for(install, wine, a.portable) if install else None)
    ok = bool(terminal and os.path.isfile(terminal) and metaeditor and os.path.isfile(metaeditor) and data
              and os.path.isdir(os.path.join(data, 'MQL5')))
    if not IS_WIN and not wine:
        ok = False
    info = {'level': 'A' if ok else 'B/C', 'os': platform.system(), 'wine': wine, 'terminal': terminal,
            'metaeditor': metaeditor, 'data_folder': data, 'portable': a.portable,
            'note': 'toolchain usable' if ok else 'MT5 not runnable here: use `package` and let the user run it'}
    return info


# ---------------------------------------------------------------- EA placement / compile
def place_ea(ea, data):
    """Return (mq5 path inside MQL5/Experts, Expert= value without extension)."""
    experts = os.path.join(data, 'MQL5', 'Experts')
    ea = os.path.abspath(ea)
    if os.path.commonpath([ea, os.path.abspath(experts)]) == os.path.abspath(experts):
        rel = os.path.relpath(ea, experts)
        return ea, os.path.splitext(rel)[0].replace('/', '\\')
    # copy the EA folder (keeps relative includes) into Experts/<name>_audit
    src_dir = os.path.dirname(ea)
    dst_dir = os.path.join(experts, os.path.basename(src_dir) + '_audit')
    if os.path.exists(dst_dir):
        shutil.rmtree(dst_dir)
    shutil.copytree(src_dir, dst_dir, ignore=shutil.ignore_patterns('_audit', '*.ex5', '.git'))
    dst = os.path.join(dst_dir, os.path.basename(ea))
    return dst, os.path.splitext(os.path.relpath(dst, experts))[0].replace('/', '\\')


def compile_ea(info, mq5, audit):
    logf = os.path.join(audit, 'compile.log')
    if os.path.exists(logf):
        os.remove(logf)
    inc = os.path.join(info['data_folder'], 'MQL5')
    cmd = exe_cmd(info['metaeditor'], info['wine']) + [
        f'/compile:{to_win(mq5, info["wine"])}', f'/log:{to_win(logf, info["wine"])}', f'/include:{to_win(inc, info["wine"])}']
    print('[run]', ' '.join(cmd))
    subprocess.run(cmd, timeout=600)
    for _ in range(30):
        if os.path.exists(logf):
            break
        time.sleep(1)
    r = script('parse_compile_log.py', logf, '--json', os.path.join(audit, 'compile.json'))
    res = json.load(open(os.path.join(audit, 'compile.json'))) if os.path.exists(os.path.join(audit, 'compile.json')) else {}
    log_run(audit, {'step': 'compile', 'source': logf, 'errors': res.get('error_count'),
                    'warnings': res.get('warning_count'), 'compiled': res.get('compiled', False)})
    ex5 = os.path.splitext(mq5)[0] + '.ex5'
    if r.returncode == 0 and not os.path.exists(ex5):
        print('[compile] log says 0 errors but the .ex5 is missing - treating as failed')
        return False
    return r.returncode == 0


# ---------------------------------------------------------------- tester
def install_set(info, setfile):
    dst_dir = os.path.join(info['data_folder'], 'MQL5', 'Profiles', 'Tester')
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copy(setfile, os.path.join(dst_dir, os.path.basename(setfile)))
    return os.path.basename(setfile)


def make_ini(audit, name, expert, setname, a, report, **kw):
    ini = os.path.join(audit, name + '.ini')
    args = ['--out', ini, '--expert', expert + '.ex5', '--set', setname, '--symbol', kw.get('symbol', a.symbol),
            '--period', a.period, '--from', a.date_from, '--to', a.date_to, '--model', a.model,
            '--execution', kw.get('execution', 0), '--optimization', kw.get('optimization', 0),
            '--criterion', kw.get('criterion', 6), '--deposit', a.deposit, '--leverage', a.leverage, '--report', report]
    if kw.get('forward'):
        args += ['--forward-mode', 4, '--forward-date', a.forward_date]
    script('make_tester_ini.py', *args, check=True)
    return ini


def run_tester(info, ini, report_rel, ext, timeout):
    data = info['data_folder']
    target = os.path.join(data, report_rel + ext)
    start = time.time()
    cmd = exe_cmd(info['terminal'], info['wine']) + [f'/config:{to_win(ini, info["wine"])}']
    if info['portable']:
        cmd.append('/portable')
    print('[run]', ' '.join(cmd))
    try:
        subprocess.run(cmd, timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f'[tester] timeout after {timeout}s')
    for _ in range(60):  # the report can appear a little after the terminal exits
        if os.path.exists(target) and os.path.getmtime(target) >= start - 5:
            return target
        time.sleep(2)
    print(f'[tester] no fresh report at {target}. Is another terminal instance using this data folder? '
          'Close MT5 first; check the terminal and tester journals (logs\\, Tester\\logs\\).')
    return None


def backtest(info, a, audit, expert, setname, tag, **kw):
    rel = os.path.join('reports', f'uge_audit_{tag}').replace('/', '\\')
    ini = make_ini(audit, tag, expert, setname, a, rel, **kw)
    rep = run_tester(info, ini, rel.replace('\\', os.sep), '.htm', a.timeout)
    if not rep:
        log_run(audit, {'step': tag, 'ok': False, 'reason': 'no report'})
        return None
    out = os.path.join(audit, tag + '.json')
    script('parse_report.py', rep, '--json', out)
    shutil.copy(rep, os.path.join(audit, tag + '.htm'))
    res = json.load(open(out)) if os.path.exists(out) else None
    log_run(audit, {'step': tag, 'source': rep, 'metrics': res})
    return res


# ---------------------------------------------------------------- commands
def has_ontester(ea):
    sys.path.insert(0, HERE)
    from extract_inputs import collect_files, read_text
    return any(re.search(r'\bdouble\s+OnTester\s*\(', read_text(f)) for f in collect_files(ea))


def cmd_run(a):
    info = detect(a)
    print(json.dumps(info, indent=2))
    if info['level'] != 'A':
        sys.exit('toolchain not runnable here - use `package`')
    audit = os.path.join(os.path.dirname(os.path.abspath(a.ea)), '_audit')
    os.makedirs(audit, exist_ok=True)
    mq5, expert = place_ea(a.ea, info['data_folder'])
    # R1 compile
    if not compile_ea(info, mq5, audit):
        sys.exit('[stop] compile failed - fix errors (see _audit/compile.json) and run again')
    # inventory + sets
    script('extract_inputs.py', a.ea, '--out', os.path.join(audit, 'inputs.json'), '--set', os.path.join(audit, 'original.set'), check=True)
    original = install_set(info, os.path.join(audit, 'original.set'))
    # R2 baseline with the user's inputs
    backtest(info, a, audit, expert, original, 'baseline')
    # R3 optimization
    optset = os.path.join(audit, f'opt_round{a.round}.set')
    script('extract_inputs.py', a.ea, '--set', optset, '--optimize', a.optimize, '--exclude', a.exclude, check=True)
    optname = install_set(info, optset)
    crit = 6 if has_ontester(a.ea) else 7
    if crit == 7:
        print('[note] EA has no OnTester(): using complex criterion (7). Patch library has an OnTester() to add.')
    rel = os.path.join('reports', f'uge_audit_opt{a.round}').replace('/', '\\')
    ini = make_ini(audit, f'opt_round{a.round}', expert, optname, a, rel, optimization=2, criterion=crit, forward=True)
    xml = run_tester(info, ini, rel.replace('\\', os.sep), '.xml', a.timeout)
    if not xml:
        sys.exit('[stop] optimization produced no XML report')
    is_csv, fwd_csv = os.path.join(audit, f'opt{a.round}_is.csv'), os.path.join(audit, f'opt{a.round}_fwd.csv')
    script('parse_report.py', xml, '--csv', is_csv, check=True)
    fxml = xml[:-4] + '.forward.xml'
    fwd_ok = os.path.exists(fxml) and script('parse_report.py', fxml, '--csv', fwd_csv).returncode == 0
    log_run(audit, {'step': f'optimization{a.round}', 'source': xml, 'forward_source': fxml if fwd_ok else None})
    # R4 select
    sel = ['--is', is_csv, '--min-trades', a.min_trades, '--out', os.path.join(audit, f'select{a.round}.json'),
           '--values', os.path.join(audit, f'values{a.round}.json')]
    if fwd_ok:
        sel += ['--fwd', fwd_csv]
    script('select_robust.py', *sel)
    vals = os.path.join(audit, f'values{a.round}.json')
    if not os.path.exists(vals):
        sys.exit('[stop] no robust candidate - report this honestly; consider logic changes or another round')
    final = os.path.join(audit, 'final.set')
    script('extract_inputs.py', a.ea, '--set', final, '--values', vals, check=True)
    finalname = install_set(info, final)
    # R5 verify + R6 stress
    backtest(info, a, audit, expert, finalname, 'verify')
    backtest(info, a, audit, expert, finalname, 'stress_delay', execution=-1)
    if a.stress_symbol:
        backtest(info, a, audit, expert, finalname, 'stress_spread', symbol=a.stress_symbol, execution=-1)
    print(f'[done] round {a.round}. Results: {audit}/runs.jsonl (every metric lists its source report).')


def cmd_compile(a):
    info = detect(a)
    if info['level'] != 'A':
        sys.exit('toolchain not runnable here - use `package`')
    audit = os.path.join(os.path.dirname(os.path.abspath(a.ea)), '_audit')
    os.makedirs(audit, exist_ok=True)
    mq5, _ = place_ea(a.ea, info['data_folder'])
    sys.exit(0 if compile_ea(info, mq5, audit) else 1)


def cmd_package(a):
    """Level B: pre-generate .set/.ini files and a pure-PowerShell runner for the user's Windows PC.
    --stage optimize : compile + baseline backtest + optimization round (default)
    --stage verify   : needs --values (chosen pass JSON) -> final.set + verify + stress runs"""
    ea = os.path.abspath(a.ea)
    audit = os.path.join(os.path.dirname(ea), '_audit')
    os.makedirs(audit, exist_ok=True)
    folder = os.path.basename(os.path.dirname(ea)) + '_audit'
    expert = folder + '\\' + os.path.splitext(os.path.basename(ea))[0]
    runs = []   # (ini name, report rel path, extension)

    def ini(tag, setname, **kw):
        rel = 'reports\\uge_audit_' + tag
        make_ini(audit, tag, expert, setname, a, rel, **kw)
        runs.append((tag + '.ini', rel, '.xml' if kw.get('optimization') else '.htm'))

    if a.stage == 'optimize':
        script('extract_inputs.py', ea, '--out', os.path.join(audit, 'inputs.json'),
               '--set', os.path.join(audit, 'original.set'), check=True)
        optset = f'opt_round{a.round}.set'
        script('extract_inputs.py', ea, '--set', os.path.join(audit, optset), '--optimize', a.optimize,
               '--exclude', a.exclude, check=True)
        crit = 6 if has_ontester(ea) else 7
        ini('baseline', 'original.set')
        ini(f'opt_round{a.round}', optset, optimization=2, criterion=crit, forward=True)
    else:
        if not a.values:
            sys.exit('--stage verify needs --values <chosen pass json from select_robust.py>')
        script('extract_inputs.py', ea, '--set', os.path.join(audit, 'final.set'), '--values', a.values, check=True)
        ini('verify', 'final.set')
        ini('stress_delay', 'final.set', execution=-1)
        if a.stress_symbol:
            ini('stress_spread', 'final.set', symbol=a.stress_symbol, execution=-1)

    ps = open(os.path.join(HERE, 'run_pipeline.ps1'), encoding='utf-8').read()
    # one "+= ,@(...)" per run: avoids PowerShell flattening a single nested array
    runlist = '\n'.join(f"$Runs += ,@('{i}','{r}','{e}')" for i, r, e in runs)
    ps = (ps.replace('__EA_FILE__', os.path.basename(ea)).replace('__EA_FOLDER__', folder)
            .replace('__RUNS__', runlist).replace('__COMPILE__', '$true' if a.stage == 'optimize' else '$false'))
    out = os.path.join(audit, f'run_{a.stage}.ps1')
    open(out, 'w', encoding='utf-8-sig', newline='\r\n').write(ps)
    dst = os.path.join(audit, 'scripts')
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(HERE, dst, ignore=shutil.ignore_patterns('__pycache__'))
    print(f'[package] {out}\n  Run on the Windows PC (MT5 closed):  powershell -ExecutionPolicy Bypass -File "{out}"\n'
          f'  Optional: -Terminal "C:\\Program Files\\<Broker> MetaTrader 5\\terminal64.exe" -Portable\n'
          '  Then send back the _audit folder (results\\ + compile.log). Nothing has been compiled or tested yet.')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd', choices=['detect', 'compile', 'run', 'package'])
    ap.add_argument('--ea')
    ap.add_argument('--terminal'); ap.add_argument('--metaeditor'); ap.add_argument('--data')
    ap.add_argument('--portable', action='store_true'); ap.add_argument('--wine', action='store_true')
    ap.add_argument('--symbol', default='XAUUSD'); ap.add_argument('--period', default='M15')
    ap.add_argument('--from', dest='date_from'); ap.add_argument('--to', dest='date_to')
    ap.add_argument('--forward-date', default='')
    ap.add_argument('--model', type=int, default=4); ap.add_argument('--deposit', type=float, default=10000)
    ap.add_argument('--leverage', default='1:100'); ap.add_argument('--optimize', default='auto')
    ap.add_argument('--exclude', default=''); ap.add_argument('--round', type=int, default=1)
    ap.add_argument('--stress-symbol', default=''); ap.add_argument('--min-trades', type=float, default=200)
    ap.add_argument('--timeout', type=int, default=7200)
    ap.add_argument('--stage', choices=['optimize', 'verify'], default='optimize')
    ap.add_argument('--values')
    a = ap.parse_args()

    if a.cmd == 'detect':
        print(json.dumps(detect(a), indent=2)); return
    if not a.ea:
        sys.exit('--ea is required')
    if a.cmd in ('run', 'package'):
        # defaults: last 36 full months, newest 30% forward
        if not a.date_to:
            first = dt.date.today().replace(day=1)
            a.date_to = (first - dt.timedelta(days=1)).strftime('%Y.%m.%d')
        if not a.date_from:
            end = dt.datetime.strptime(a.date_to, '%Y.%m.%d').date()
            a.date_from = (end.replace(day=1) - dt.timedelta(days=365 * 3 - 31)).replace(day=1).strftime('%Y.%m.%d')
        if not a.forward_date:
            s = dt.datetime.strptime(a.date_from, '%Y.%m.%d'); e = dt.datetime.strptime(a.date_to, '%Y.%m.%d')
            a.forward_date = (s + (e - s) * 0.7).strftime('%Y.%m.%d')
        print(f'[setup] {a.symbol} {a.period} {a.date_from} -> {a.date_to}, forward from {a.forward_date}, model {a.model}')
    {'compile': cmd_compile, 'run': cmd_run, 'package': cmd_package}[a.cmd](a)


if __name__ == '__main__':
    main()
