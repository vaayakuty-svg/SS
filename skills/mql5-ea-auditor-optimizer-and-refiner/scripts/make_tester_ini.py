#!/usr/bin/env python3
"""Write a MetaTrader 5 Strategy Tester config for `terminal64.exe /config:<file.ini>`.

Examples
  # single backtest, real ticks
  python make_tester_ini.py --out bt.ini --expert "MyEA\\MyEA.ex5" --set MyEA_final.set \
      --symbol XAUUSD --period M15 --from 2022.11.01 --to 2025.10.31 --model 4 --report "reports\\MyEA_bt"

  # genetic optimization, custom criterion, forward test from a date
  python make_tester_ini.py --out opt.ini --expert "MyEA\\MyEA.ex5" --set MyEA_opt.set --optimization 2 \
      --criterion 6 --forward-mode 4 --forward-date 2024.12.01 --symbol XAUUSD --period M15 \
      --from 2022.11.01 --to 2025.10.31 --model 4 --report "reports\\MyEA_opt"

  # stress: random execution delay (use a widened-spread custom symbol for spread stress)
  python make_tester_ini.py ... --execution -1 --symbol XAUUSD_STRESS

Key values (see references/tester-ini-reference.md):
  Model: 0 every tick, 1 1-minute OHLC, 2 open prices, 3 math calculations, 4 every tick based on real ticks
  Optimization: 0 off, 1 slow complete, 2 fast genetic, 3 all symbols in Market Watch
  OptimizationCriterion: 0 balance max, 1 profit factor max, 2 expected payoff max, 3 drawdown min,
                         4 recovery factor max, 5 Sharpe max, 6 custom max (OnTester), 7 complex criterion max
  ForwardMode: 0 off, 1 = 1/2, 2 = 1/3, 3 = 1/4, 4 custom date (ForwardDate)
  ExecutionMode: 0 normal (no delay), -1 random delay, N = fixed delay in ms
ExpertParameters must be a .set file name inside <data folder>\\MQL5\\Profiles\\Tester\\ (the pipeline copies it there).
"""
import argparse, re, sys

PERIODS = {'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M10', 'M12', 'M15', 'M20', 'M30',
           'H1', 'H2', 'H3', 'H4', 'H6', 'H8', 'H12', 'D1', 'W1', 'MN1'}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', required=True)
    ap.add_argument('--expert', required=True, help=r'path relative to MQL5\Experts, e.g. MyEA\MyEA.ex5')
    ap.add_argument('--set', help='set file name (in MQL5\\Profiles\\Tester)')
    ap.add_argument('--symbol', required=True)
    ap.add_argument('--period', required=True)
    ap.add_argument('--from', dest='date_from', required=True, help='yyyy.mm.dd')
    ap.add_argument('--to', dest='date_to', required=True, help='yyyy.mm.dd')
    ap.add_argument('--model', type=int, default=4)
    ap.add_argument('--execution', type=int, default=0)
    ap.add_argument('--optimization', type=int, default=0)
    ap.add_argument('--criterion', type=int, default=6)
    ap.add_argument('--forward-mode', type=int, default=0)
    ap.add_argument('--forward-date', default='')
    ap.add_argument('--deposit', type=float, default=10000)
    ap.add_argument('--currency', default='USD')
    ap.add_argument('--leverage', default='1:100')
    ap.add_argument('--report', required=True, help=r'report path relative to the terminal data folder, no extension')
    ap.add_argument('--login', default='', help='only for local runs; never share an ini containing it')
    ap.add_argument('--use-local', type=int, default=1)
    ap.add_argument('--use-cloud', type=int, default=0)
    ap.add_argument('--visual', type=int, default=0)
    ap.add_argument('--no-shutdown', action='store_true')
    a = ap.parse_args()

    if a.period.upper() not in PERIODS:
        sys.exit(f'bad period {a.period}')
    for d in (a.date_from, a.date_to) + ((a.forward_date,) if a.forward_date else ()):
        if not re.match(r'^\d{4}\.\d{2}\.\d{2}$', d):
            sys.exit(f'bad date {d} (use yyyy.mm.dd)')
    if a.forward_mode == 4 and not a.forward_date:
        sys.exit('--forward-mode 4 needs --forward-date')
    if a.forward_date and not (a.date_from < a.forward_date < a.date_to):
        sys.exit('forward date must be inside the test range')

    lines = ['[Tester]', f'Expert={a.expert}']
    if a.set:
        lines.append(f'ExpertParameters={a.set}')
    lines += [f'Symbol={a.symbol}', f'Period={a.period.upper()}', f'Model={a.model}',
              f'ExecutionMode={a.execution}', f'Optimization={a.optimization}']
    if a.optimization:
        lines.append(f'OptimizationCriterion={a.criterion}')
    lines += [f'FromDate={a.date_from}', f'ToDate={a.date_to}', f'ForwardMode={a.forward_mode}']
    if a.forward_mode == 4:
        lines.append(f'ForwardDate={a.forward_date}')
    lines += [f'Deposit={a.deposit:g}', f'Currency={a.currency}', f'Leverage={a.leverage}',
              f'UseLocal={a.use_local}', f'UseCloud={a.use_cloud}', f'Visual={a.visual}',
              f'Report={a.report}', 'ReplaceReport=1', f'ShutdownTerminal={0 if a.no_shutdown else 1}']
    if a.login:
        lines.insert(1, f'Login={a.login}')
    open(a.out, 'w', encoding='utf-8', newline='').write('\r\n'.join(lines) + '\r\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
