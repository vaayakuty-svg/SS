#!/usr/bin/env python3
"""Inventory the `input`/`sinput` parameters of an MQL5 EA (following local #include files),
classify them (optimizable / fixed / protected / other) and optionally write an MT5 .set file
with optimization ranges.

Usage:
  python extract_inputs.py EA.mq5 --out inputs.json
  python extract_inputs.py EA.mq5 --set opt.set --optimize auto            # top-5 by priority
  python extract_inputs.py EA.mq5 --set opt.set --optimize InpA,InpB,InpC  # explicit
  python extract_inputs.py EA.mq5 --set original.set                       # no optimization flags (baseline)
  python extract_inputs.py EA.mq5 --set final.set --values chosen.json     # write chosen values

.set line format (MT5): Name=value||start||step||stop||Y/N   (Y = optimize this input)
Files are written UTF-16LE with BOM (what MT5 itself writes) unless --encoding utf8.
"""
import argparse, json, math, os, re, sys

INPUT_RE = re.compile(r'^\s*(sinput|input)\s+(?!group\b)([\w:]+)\s+(\w+)\s*(?:=\s*(.*?))?\s*;\s*(?://\s*(.*))?$')
GROUP_RE = re.compile(r'^\s*input\s+group\s+"(.*?)"')
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"')
ENUM_RE = re.compile(r'enum\s+(\w+)\s*\{(.*?)\}\s*;', re.S)

FIXED_PAT = re.compile(r'magic|comment|colou?r|clr|panel|show|draw|alert|push|sound|notif|telegram|token|chat|debug|log|file|font|corner|xdist|ydist|^inp?[xy]$|persist|restart|filling|policy|async|account|symbol|server|gmtoffset', re.I)
PROTECTED_PAT = re.compile(r'risk|maxlot|maximumlot|minlot|minimumlot|fixedlot|lotsize|^inp?lots?$|dailyloss|maxdaily|drawdown|maxdd|dd(pct|percent)?$|equitystop|equitysl|maxspread|maximumspread|spreadmult|maxtrades|maximumopen|maxopen|maxpos|totallots|gridlevel|maximumgrid|maxgrid|martingale|marti|lotmult|recoverylot|maximumrecovery|hedgelot|maxorders|margin|slippage', re.I)
OPT_PAT = re.compile(r'period|mult|atr|stoploss|takeprofit|(^|[a-z])sl($|[A-Z_]|points|dist)|(^|[a-z])tp($|[A-Z_]|points|dist)|trail|breakeven|(^|[a-z])be[A-Z_]|rr$|riskreward|ratio|level|threshold|buffer|distance|offset|bars|ema|sma|rsi|macd|stoch|bb|band|dev|fast|slow|signal|lookback|length|len$|hour|minute|zentry|fibo|k$|step', re.I)

PRIORITY = [  # earlier = optimized first in --optimize auto
    (re.compile(r'(atr).*(sl|stop)|(sl|stop).*(atr)|multiplier.?sl', re.I), 100),
    (re.compile(r'(atr).*(tp|take)|(tp|take).*(atr)|riskreward|rr$|multiplier.?tp', re.I), 95),
    (re.compile(r'stoploss|(^|[a-z])sl(points|dist)?$', re.I), 90),
    (re.compile(r'takeprofit|(^|[a-z])tp(points|dist)?$', re.I), 88),
    (re.compile(r'(fast|slow|ema|sma|ma)period|period(fast|slow)|^inp?(ema|sma)(fast|slow)', re.I), 85),
    (re.compile(r'period', re.I), 80),
    (re.compile(r'trail', re.I), 70),
    (re.compile(r'breakeven|(^|[a-z])be[A-Z_]', re.I), 65),
    (re.compile(r'level|threshold|overbought|oversold|zentry', re.I), 60),
    (re.compile(r'buffer|distance|offset|bars|lookback', re.I), 50),
    (re.compile(r'hour|minute', re.I), 30),
]

NUMERIC_INT = {'int', 'uint', 'long', 'ulong', 'short', 'ushort', 'char', 'uchar'}
NUMERIC_FLOAT = {'double', 'float'}


def strip_comments_keep_inline(text):
    return re.sub(r'/\*.*?\*/', '', text, flags=re.S)


def read_text(path):
    raw = open(path, 'rb').read()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')
    for enc in ('utf-8-sig', 'cp1252', 'latin-1'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode('latin-1', 'replace')


def collect_files(path, seen=None):
    """The EA file plus every local #include "..." (recursively)."""
    seen = seen if seen is not None else []
    path = os.path.normpath(path)
    if path in seen or not os.path.isfile(path):
        return seen
    seen.append(path)
    base = os.path.dirname(path)
    for line in read_text(path).splitlines():
        m = INCLUDE_RE.match(line)
        if m:
            inc = m.group(1).replace('\\', '/')
            collect_files(os.path.join(base, inc), seen)
    return seen


def parse_enums(texts):
    enums = {}
    for t in texts:
        t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
        for m in ENUM_RE.finditer(t):
            name, body = m.group(1), m.group(2)
            items, val = [], -1
            for raw in body.split('\n'):
                code = raw.split('//')[0]
                desc = raw.split('//', 1)[1].strip() if '//' in raw else ''
                for part in code.split(','):
                    part = part.strip()
                    if not part:
                        continue
                    if '=' in part:
                        k, v = [x.strip() for x in part.split('=', 1)]
                        try:
                            val = int(v, 0)
                        except ValueError:
                            val += 1
                    else:
                        k = part
                        val += 1
                    items.append({'name': k, 'value': val, 'desc': desc})
            enums[name] = items
    return enums


def classify(name, typ, enums):
    n = name
    if typ == 'string' or typ == 'color' or typ == 'datetime':
        return 'fixed'
    if FIXED_PAT.search(n):
        return 'fixed'
    if re.search(r'riskreward|rewardrisk|(^|[a-z])rr($|ratio)', n, re.I):
        return 'optimizable'   # a target ratio, not a risk limit
    if PROTECTED_PAT.search(n):
        return 'protected'
    if typ == 'bool':
        return 'other'      # strategy switches are the user's choice, not auto-optimized
    if typ in enums or typ.startswith('ENUM_'):
        return 'other'      # modes: optimize only on explicit request
    if (typ in NUMERIC_INT or typ in NUMERIC_FLOAT) and OPT_PAT.search(n):
        return 'optimizable'
    return 'other'


def priority(name):
    for rx, score in PRIORITY:
        if rx.search(name):
            return score
    return 10


def bucket(name):
    for k, (rx, _) in enumerate(PRIORITY):
        if rx.search(name):
            return k
    return len(PRIORITY)


def parse_inputs(files, enums):
    out, group = [], ''
    for f in files:
        for ln, raw in enumerate(strip_comments_keep_inline(read_text(f)).splitlines(), 1):
            g = GROUP_RE.match(raw)
            if g:
                group = g.group(1)
                continue
            m = INPUT_RE.match(raw)
            if not m:
                continue
            kind, typ, name, default, comment = m.groups()
            default = (default or '').strip()
            out.append({'name': name, 'type': typ, 'default': default, 'comment': (comment or '').strip(),
                        'group': group, 'sinput': kind == 'sinput', 'file': os.path.basename(f), 'line': ln,
                        'class': 'fixed' if kind == 'sinput' else classify(name, typ, enums),
                        'priority': priority(name)})
    return out


def numeric_default(inp, enums):
    d = inp['default'].rstrip('fFlLuU')
    if inp['type'] == 'bool':
        return 1 if d.lower() == 'true' else 0
    if inp['type'] in enums:
        for it in enums[inp['type']]:
            if it['name'] == d:
                return it['value']
        return 0
    if inp['type'].startswith('PERIOD') or d.startswith('PERIOD_'):
        return d
    try:
        return float(eval(d, {'__builtins__': {}}, {})) if d else 0.0
    except Exception:
        return None


def nice_step(span, n=8, is_int=False):
    if span <= 0:
        return 1 if is_int else 0.1
    raw = span / n
    if is_int and raw <= 1:
        return 1
    mag = 10 ** math.floor(math.log10(raw))
    for m in (1, 2, 2.5, 5, 10):
        if raw <= m * mag:
            v = round(m * mag, 10)
            return max(1, int(round(v))) if is_int else v
    return max(1, int(round(raw))) if is_int else round(raw, 10)


def opt_range(inp, val):
    """Range around the user's default. Protected inputs: only equal or stricter values."""
    is_int = inp['type'] in NUMERIC_INT
    name = inp['name'].lower()
    if val == 0:
        lo, hi = 0, (10 if is_int else 1.0)
    elif 'hour' in name:
        lo, hi = max(0, val - 3), min(23, val + 3)
    elif 'minute' in name:
        lo, hi = 0, 45
    elif re.search(r'mult|ratio|rr$|riskreward|zentry|dev|factor|percent|pct|fibo', name):
        lo, hi = val * 0.5, val * 1.5
    else:
        lo, hi = val * 0.5, val * 2.0
    if inp['class'] == 'protected':      # stricter only: smaller limits
        lo, hi = val * 0.5, val
    if is_int:
        lo, hi = int(math.floor(lo)), int(math.ceil(hi))
        lo = max(lo, 1) if val >= 1 and 'hour' not in name and 'minute' not in name else lo
    step = nice_step(hi - lo, 8, is_int)
    if not is_int:
        lo, hi = round(lo, 6), round(hi, 6)
    return lo, step, hi


def fmt(v, is_int=False):
    if isinstance(v, str):
        return v
    if is_int:
        return str(int(round(v)))
    s = ('%.8f' % v).rstrip('0').rstrip('.')
    return s if s else '0'


def write_set(inputs, enums, path, optimize, values, encoding):
    lines = []
    for inp in inputs:
        name, typ = inp['name'], inp['type']
        val = values.get(name, None)
        if typ == 'string':
            v = val if val is not None else inp['default'].strip('"')
            lines.append(f'{name}={v}')
            continue
        dv = numeric_default(inp, enums) if val is None else val
        if isinstance(dv, str) and not re.match(r'^-?[\d.]+$', str(dv)):
            lines.append(f'{name}={dv}')           # e.g. PERIOD_M15 / colour names
            continue
        if dv is None:
            lines.append(f'{name}={inp["default"]}')
            continue
        dv = float(dv)
        is_int = typ in NUMERIC_INT or typ == 'bool' or typ in enums or typ.startswith('ENUM_')
        if typ == 'bool':
            lines.append(f'{name}={"true" if dv else "false"}||false||0||true||N')
            continue
        if typ in enums:
            vals = [it['value'] for it in enums[typ]] or [0]
            flag = 'Y' if name in optimize else 'N'
            lines.append(f'{name}={int(dv)}||{min(vals)}||1||{max(vals)}||{flag}')
            continue
        if name in optimize:
            lo, st, hi = opt_range(inp, dv)
            lines.append(f'{name}={fmt(dv, is_int)}||{fmt(lo, is_int)}||{fmt(st, is_int)}||{fmt(hi, is_int)}||Y')
        else:
            lines.append(f'{name}={fmt(dv, is_int)}||{fmt(dv, is_int)}||{fmt(1 if is_int else 0.1, is_int)}||{fmt(dv, is_int)}||N')
    text = '\r\n'.join(['; generated by mql5-ea-auditor-optimizer-and-refiner'] + lines) + '\r\n'
    if encoding == 'utf16':
        open(path, 'wb').write(b'\xff\xfe' + text.encode('utf-16-le'))
    else:
        open(path, 'w', encoding='utf-8', newline='').write(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ea')
    ap.add_argument('--out', help='write the inventory JSON here')
    ap.add_argument('--set', help='write an MT5 .set file here')
    ap.add_argument('--optimize', default='', help="'auto' (top-N optimizable by priority) or comma list of input names")
    ap.add_argument('--max', type=int, default=5, help='inputs per round for --optimize auto (3-5 recommended)')
    ap.add_argument('--exclude', default='', help='comma list of inputs already optimized in earlier rounds')
    ap.add_argument('--values', help='JSON {name: value} to write as values (final .set)')
    ap.add_argument('--encoding', choices=['utf16', 'utf8'], default='utf16')
    a = ap.parse_args()

    files = collect_files(a.ea)
    if not files:
        sys.exit(f'not found: {a.ea}')
    texts = [read_text(f) for f in files]
    enums = parse_enums(texts)
    inputs = parse_inputs(files, enums)

    exclude = {x.strip() for x in a.exclude.split(',') if x.strip()}
    if a.optimize == 'auto':
        cands = [i for i in inputs if i['class'] == 'optimizable' and i['name'] not in exclude
                 and numeric_default(i, enums) not in (None, 0, 0.0)]
        cands.sort(key=lambda i: -i['priority'])
        # one input per category (e.g. one SL distance), so sibling inputs of inactive modes are not all picked;
        # review the picks against the modes that are actually enabled
        optimize, used = [], set()
        for i in cands:
            b = bucket(i['name'])
            if b < len(PRIORITY) and b in used:
                continue
            used.add(b)
            optimize.append(i['name'])
            if len(optimize) >= a.max:
                break
    else:
        optimize = [x.strip() for x in a.optimize.split(',') if x.strip()]
    known = {i['name'] for i in inputs}
    bad = [o for o in optimize if o not in known]
    if bad:
        sys.exit(f'unknown inputs: {bad}')
    for o in optimize:
        cls = next(i['class'] for i in inputs if i['name'] == o)
        if cls in ('fixed',):
            sys.exit(f'{o} is a fixed (non-strategy) input and must not be optimized')
        if cls == 'protected':
            print(f'note: {o} is a protected risk input: only equal-or-stricter values will be tested', file=sys.stderr)

    summary = {'files': files, 'count': len(inputs), 'optimize': optimize,
               'by_class': {c: [i['name'] for i in inputs if i['class'] == c] for c in ('optimizable', 'protected', 'fixed', 'other')},
               'inputs': inputs, 'enums': enums}
    if a.out:
        json.dump(summary, open(a.out, 'w'), indent=2)
    if a.set:
        values = json.load(open(a.values)) if a.values else {}
        write_set(inputs, enums, a.set, set(optimize), values, a.encoding)
    print(json.dumps({'files': len(files), 'inputs': len(inputs), 'optimize': optimize,
                      'classes': {k: len(v) for k, v in summary['by_class'].items()}}, indent=2))


if __name__ == '__main__':
    main()
