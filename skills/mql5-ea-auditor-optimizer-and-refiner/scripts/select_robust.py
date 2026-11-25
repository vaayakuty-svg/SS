#!/usr/bin/env python3
"""Pick optimization parameters from a stable plateau, confirmed by the forward period.

  python select_robust.py --is opt.csv [--fwd fwd.csv] [--params InpA,InpB] [--metric Result]
                          [--min-trades 200] [--min-fwd-trades 50] [--out choice.json] [--values values.json]

Inputs are the CSVs written by parse_report.py from the tester's optimization XML files.
Logic:
  1. drop passes with too few trades or a non-positive metric;
  2. neighbourhood of a pass = passes whose every optimized parameter is within one grid step;
     plateau score = MEDIAN metric of the neighbourhood (outlier-proof); stability = worst neighbour / median;
  3. if a forward CSV is given, keep only passes that are profitable in the forward period
     (Profit > 0, Profit Factor >= 1.0 and enough trades) - joined by Pass number;
  4. rank by plateau score (isolated peaks with < 2 neighbours are ranked last).
Nothing here is a profit forecast: it only orders passes the tester already produced.
"""
import argparse, csv, json, statistics, sys

KNOWN = {'pass', 'result', 'profit', 'expected payoff', 'profit factor', 'recovery factor', 'sharpe ratio',
         'custom', 'equity dd %', 'trades', 'forward result', 'back result', 'balance dd %', 'drawdown %'}


def load(path):
    with open(path, newline='', encoding='utf-8') as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k, v in list(r.items()):
            try:
                r[k] = float(v)
            except (TypeError, ValueError):
                pass
    return rows


def col(rows, *names):
    if not rows:
        return None
    keys = {k.lower(): k for k in rows[0]}
    for n in names:
        if n.lower() in keys:
            return keys[n.lower()]
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--is', dest='insample', required=True)
    ap.add_argument('--fwd')
    ap.add_argument('--params', default='')
    ap.add_argument('--metric', default='Result')
    ap.add_argument('--min-trades', type=float, default=200)
    ap.add_argument('--min-fwd-trades', type=float, default=50)
    ap.add_argument('--stability', type=float, default=0.7, help='worst neighbour >= this x neighbourhood median')
    ap.add_argument('--top', type=int, default=5)
    ap.add_argument('--out')
    ap.add_argument('--values', help='write the chosen pass inputs as JSON for extract_inputs.py --values')
    a = ap.parse_args()

    rows = load(a.insample)
    if not rows:
        sys.exit('no passes in ' + a.insample)
    mcol = col(rows, a.metric, 'Custom', 'Result')
    tcol = col(rows, 'Trades')
    pcol = col(rows, 'Pass')
    params = [p.strip() for p in a.params.split(',') if p.strip()] or \
             [k for k in rows[0] if k.lower() not in KNOWN and isinstance(rows[0][k], float)]
    # keep only parameters that actually vary
    params = [p for p in params if len({r[p] for r in rows}) > 1]
    if not params:
        sys.exit('no varying parameters found; pass --params')
    grid = {p: sorted({r[p] for r in rows}) for p in params}
    pos = lambda r, p: grid[p].index(r[p])

    ok = [r for r in rows if isinstance(r.get(mcol), float) and r[mcol] > 0 and (tcol is None or r[tcol] >= a.min_trades)]
    dropped_trades = len(rows) - len(ok)

    fwd = {}
    if a.fwd:
        frows = load(a.fwd)
        fp = col(frows, 'Pass'); fprofit = col(frows, 'Profit'); fpf = col(frows, 'Profit Factor'); ftr = col(frows, 'Trades')
        for r in frows:
            fwd[r[fp]] = r
        def fwd_ok(r):
            f = fwd.get(r[pcol])
            if not f:
                return False
            return (f.get(fprofit, 0) > 0 and (fpf is None or f.get(fpf, 0) >= 1.0) and
                    (ftr is None or f.get(ftr, 0) >= a.min_fwd_trades))
        ok = [r for r in ok if fwd_ok(r)]

    scored = []
    for r in ok:
        nb = [o for o in rows if all(abs(pos(o, p) - pos(r, p)) <= 1 for p in params)]
        vals = [o[mcol] if isinstance(o.get(mcol), float) else 0.0 for o in nb]
        # median, not mean: one outlier pass next door must not lift a weak pass
        score = statistics.median(vals)
        worst = min(vals)
        stab = worst / score if score > 0 else 0
        isolated = len(nb) - 1 < 2
        rec = {'pass': r.get(pcol), 'metric': r[mcol], 'plateau_score': round(score, 6), 'neighbours': len(nb) - 1,
               'worst_neighbour': worst, 'stability': round(stab, 3), 'stable': stab >= a.stability and not isolated,
               'trades': r.get(tcol), 'params': {p: r[p] for p in params}}
        if fwd:
            f = fwd[r[pcol]]
            rec['forward'] = {k: f[k] for k in f if isinstance(f[k], float) and k.lower() in KNOWN}
        scored.append(rec)
    scored.sort(key=lambda x: (not x['stable'], -x['plateau_score'], -x['metric']))

    result = {'source_in_sample': a.insample, 'source_forward': a.fwd, 'metric': mcol, 'params': params,
              'passes_total': len(rows), 'passes_after_filters': len(ok), 'dropped_low_trades_or_metric': dropped_trades,
              'candidates': scored[:a.top]}
    if not scored:
        result['verdict'] = 'NO ROBUST CANDIDATE: no pass met the trade-count / forward filters'
    elif not scored[0]['stable']:
        result['verdict'] = 'WEAK: best candidate is an isolated peak or unstable; treat as curve-fit'
    else:
        result['verdict'] = 'CANDIDATE FOUND: verify with a full-period backtest and the stress pass'
    if a.out:
        json.dump(result, open(a.out, 'w'), indent=2)
    if a.values and scored:
        json.dump(scored[0]['params'], open(a.values, 'w'), indent=2)
    print(json.dumps({k: v for k, v in result.items() if k != 'candidates'}, indent=2))
    for c in scored[:a.top]:
        print(f"  pass {c['pass']}: metric={c['metric']} plateau={c['plateau_score']} stab={c['stability']} "
              f"nb={c['neighbours']} stable={c['stable']} {c['params']}")


if __name__ == '__main__':
    main()
