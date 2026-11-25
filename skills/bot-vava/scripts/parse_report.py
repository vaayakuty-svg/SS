#!/usr/bin/env python3
"""Parse MetaTrader 5 Strategy Tester output.

  Single test report (.htm/.html, usually UTF-16LE):
      python parse_report.py report.htm [--json out.json]
  Optimization / forward results (.xml SpreadsheetML written by the tester):
      python parse_report.py opt.xml --csv opt.csv
      python parse_report.py opt.forward.xml --csv fwd.csv

The HTML parser reads label/value pairs of the summary table. It expects the terminal language
to be English (labels such as "Total Net Profit:"). Every number printed carries the file it came from.
Exit code 2 if the file is missing or contains no recognised metrics.
"""
import argparse, csv, html, json, re, sys
import xml.etree.ElementTree as ET

LABELS = {
    'Initial Deposit': 'initial_deposit',
    'Total Net Profit': 'net_profit',
    'Gross Profit': 'gross_profit',
    'Gross Loss': 'gross_loss',
    'Profit Factor': 'profit_factor',
    'Expected Payoff': 'expected_payoff',
    'Recovery Factor': 'recovery_factor',
    'Sharpe Ratio': 'sharpe_ratio',
    'Balance Drawdown Absolute': 'balance_dd_abs',
    'Balance Drawdown Maximal': 'balance_dd_max',
    'Balance Drawdown Relative': 'balance_dd_rel',
    'Equity Drawdown Absolute': 'equity_dd_abs',
    'Equity Drawdown Maximal': 'equity_dd_max',
    'Equity Drawdown Relative': 'equity_dd_rel',
    'Total Trades': 'total_trades',
    'Total Deals': 'total_deals',
    'Profit Trades (% of total)': 'profit_trades',
    'Loss Trades (% of total)': 'loss_trades',
    'Short Trades (won %)': 'short_trades',
    'Long Trades (won %)': 'long_trades',
    'Largest loss trade': 'largest_loss',
    'Maximum consecutive losses ($)': 'max_consec_losses',
    'History Quality': 'history_quality',
    'Bars': 'bars',
    'Ticks': 'ticks',
    'Symbol': 'symbol',
    'Period': 'period',
    'Expert': 'expert',
    'Inputs': 'inputs_first',
    'Company': 'company',
    'Currency': 'currency',
    'Leverage': 'leverage',
}


def read(path):
    raw = open(path, 'rb').read()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')
    if len(raw) > 1 and raw[1:2] == b'\x00':
        return raw.decode('utf-16-le', 'replace')
    return raw.decode('utf-8', 'replace')


def num(s):
    """'1 234.56' -> 1234.56 ; '12.34% (567.89)' -> 12.34 ; '-' -> None"""
    s = s.replace('\xa0', ' ').strip()
    m = re.match(r'^-?[\d ]+(?:\.\d+)?', s)
    if not m:
        return None
    try:
        return float(m.group(0).replace(' ', ''))
    except ValueError:
        return None


def second_num(s):
    m = re.search(r'\(([-\d .]+)%?\)', s.replace('\xa0', ' '))
    return float(m.group(1).replace(' ', '')) if m else None


def parse_html(path):
    text = read(path)
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', text, re.S | re.I)
    out = {}
    inputs = []
    in_inputs = False
    for r in rows:
        cells = [html.unescape(re.sub(r'<[^>]+>', '', c)).replace('\xa0', ' ').strip()
                 for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.S | re.I)]
        cells = [c for c in cells if c != '']
        i = 0
        while i < len(cells) - 1:
            lab = cells[i].rstrip(':').strip()
            val = cells[i + 1]
            if cells[i].endswith(':') and lab in LABELS:
                key = LABELS[lab]
                in_inputs = (key == 'inputs_first')
                if key in ('symbol', 'period', 'expert', 'company', 'currency', 'leverage'):
                    out[key] = val
                elif key == 'inputs_first':
                    inputs.append(val)
                elif key in ('balance_dd_rel', 'equity_dd_rel'):
                    out[key + '_pct'] = num(val)
                    out[key + '_money'] = second_num(val)
                elif key in ('balance_dd_max', 'equity_dd_max'):
                    out[key + '_money'] = num(val)
                    out[key + '_pct'] = second_num(val)
                elif key in ('profit_trades', 'loss_trades', 'short_trades', 'long_trades'):
                    out[key] = num(val)
                    out[key + '_pct'] = second_num(val)
                elif key == 'history_quality':
                    out[key + '_pct'] = num(val)
                else:
                    out[key] = num(val)
                i += 2
                continue
            i += 1
        # input lines follow the "Inputs:" row as single-value rows ("InpX=1.5")
        if in_inputs and len(cells) == 1 and '=' in cells[0]:
            inputs.append(cells[0])
        elif in_inputs and len(cells) >= 1 and cells[0].endswith(':') and cells[0].rstrip(':') not in ('Inputs',):
            in_inputs = False
    if inputs:
        out['inputs'] = inputs
    out['source'] = path
    return out


NS = {'ss': 'urn:schemas-microsoft-com:office:spreadsheet'}


def parse_xml(path):
    raw = open(path, 'rb').read()
    root = ET.fromstring(raw)
    rows = []
    for row in root.iter('{urn:schemas-microsoft-com:office:spreadsheet}Row'):
        vals, col = [], 0
        for cell in row.findall('ss:Cell', NS):
            idx = cell.get('{urn:schemas-microsoft-com:office:spreadsheet}Index')
            if idx:
                while col < int(idx) - 1:
                    vals.append(''); col += 1
            data = cell.find('ss:Data', NS)
            vals.append(data.text if data is not None and data.text is not None else '')
            col += 1
        rows.append(vals)
    if not rows:
        return [], []
    header = [h.strip() for h in rows[0]]
    recs = []
    for r in rows[1:]:
        if not any(r):
            continue
        rec = {}
        for k, v in zip(header, r):
            try:
                rec[k] = float(v)
            except (TypeError, ValueError):
                rec[k] = v
        recs.append(rec)
    return header, recs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('file')
    ap.add_argument('--json')
    ap.add_argument('--csv')
    a = ap.parse_args()
    try:
        if a.file.lower().endswith('.xml'):
            header, recs = parse_xml(a.file)
            if not recs:
                print(f'[report] {a.file}: no optimization rows found'); sys.exit(2)
            if a.csv:
                with open(a.csv, 'w', newline='', encoding='utf-8') as f:
                    w = csv.DictWriter(f, fieldnames=header); w.writeheader(); w.writerows(recs)
            if a.json:
                json.dump({'source': a.file, 'header': header, 'rows': recs}, open(a.json, 'w'), indent=1)
            print(f'[report] source={a.file} passes={len(recs)} columns={header}')
        else:
            res = parse_html(a.file)
            metrics = [k for k in res if k not in ('source', 'inputs')]
            if len(metrics) < 3:
                print(f'[report] {a.file}: no summary metrics recognised (terminal language must be English)'); sys.exit(2)
            if a.json:
                json.dump(res, open(a.json, 'w'), indent=2)
            print(f'[report] source={a.file}')
            for k in metrics:
                print(f'  {k} = {res[k]}')
    except (OSError, ET.ParseError) as e:
        print(f'[report] cannot read {a.file}: {e}'); sys.exit(2)


if __name__ == '__main__':
    main()
