#!/usr/bin/env python3
"""Parse a MetaEditor compile log (metaeditor64.exe /compile ... /log:file).

MetaEditor writes the log as UTF-16LE (with BOM); UTF-8/ANSI logs are also accepted.
Typical lines:
  C:\\...\\MyEA.mq5(123,45) : error 256: undeclared identifier 'x'
  C:\\...\\Inc.mqh(10,3) : warning 43: possible loss of data due to type conversion from 'double' to 'int'
  Result: 1 errors, 2 warnings, 345 msec elapsed

Usage: python parse_compile_log.py compile.log [--json out.json]
Exit code: 0 = compiled with 0 errors, 1 = errors, 2 = log missing/unreadable or no result line.
"""
import json, re, sys, argparse

LINE_RE = re.compile(r'^(?P<file>.+?)\((?P<line>\d+),(?P<col>\d+)\)\s*:\s*(?P<kind>error|warning|information)\s*(?P<code>\d+)?\s*:\s*(?P<msg>.*)$', re.I)
RESULT_RE = re.compile(r'(?:Result:\s*)?(?P<err>\d+)\s+errors?,\s*(?P<warn>\d+)\s+warnings?', re.I)

# hints keyed on message text (robust across MetaEditor builds; code numbers vary)
HINTS = [
    (r'undeclared identifier', 'declare it, fix the spelling, or include the header that defines it'),
    (r'wrong parameters count', 'check the function signature for this MQL5 build (MQL4 call?)'),
    (r'unexpected end of program', 'a brace or parenthesis is not closed'),
    (r'unbalanced|expected', 'missing ; ) } or an MQL4-only construct near this line'),
    (r'possible loss of data', 'add an explicit cast after checking the value range'),
    (r'hides (global|member)|already defined|redefinition', 'shadowing/duplicate: rename the local variable'),
    (r'cannot convert|type mismatch|implicit conversion', 'pass the correct type or cast explicitly'),
    (r'return value of .* should be checked', 'check the bool/int result (OrderSend, OrderCalcMargin, CopyBuffer...)'),
    (r'deprecated', 'replace with the current MQL5 API'),
    (r'not all control paths return', 'add a return value on every path'),
]


def read(path):
    raw = open(path, 'rb').read()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')
    if len(raw) > 1 and raw[1:2] == b'\x00':
        return raw.decode('utf-16-le', 'replace')
    for enc in ('utf-8-sig', 'cp1252'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            pass
    return raw.decode('latin-1', 'replace')


def parse(text):
    items, result = [], None
    for line in text.splitlines():
        line = line.strip()
        m = LINE_RE.match(line)
        if m:
            d = m.groupdict()
            d['line'], d['col'] = int(d['line']), int(d['col'])
            d['kind'] = d['kind'].lower()
            d['hint'] = next((h for rx, h in HINTS if re.search(rx, d['msg'], re.I)), '')
            items.append(d)
            continue
        r = RESULT_RE.search(line)
        if r and ('result' in line.lower() or 'error' in line.lower()):
            result = {'errors': int(r.group('err')), 'warnings': int(r.group('warn')), 'line': line}
    errors = [i for i in items if i['kind'] == 'error']
    warnings = [i for i in items if i['kind'] == 'warning']
    return {'result_line': result, 'errors': errors, 'warnings': warnings,
            'error_count': result['errors'] if result else len(errors),
            'warning_count': result['warnings'] if result else len(warnings),
            'compiled': bool(result) and result['errors'] == 0}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('log')
    ap.add_argument('--json')
    a = ap.parse_args()
    try:
        text = read(a.log)
    except OSError as e:
        print(json.dumps({'compiled': False, 'error': f'log not readable: {e}'}))
        sys.exit(2)
    res = parse(text)
    res['log'] = a.log
    if a.json:
        json.dump(res, open(a.json, 'w'), indent=2)
    print(f"[compile] source={a.log} errors={res['error_count']} warnings={res['warning_count']} "
          f"result_line={'found' if res['result_line'] else 'MISSING'}")
    for i in res['errors'] + res['warnings']:
        print(f"  {i['kind'].upper()} {i.get('code') or ''} {i['file'].split(chr(92))[-1]}:{i['line']}:{i['col']} {i['msg']}"
              + (f"  -> {i['hint']}" if i['hint'] else ''))
    if not res['result_line']:
        sys.exit(2)
    sys.exit(0 if res['compiled'] else 1)


if __name__ == '__main__':
    main()
