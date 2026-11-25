# <EA name>: Audit, Fix & Optimization Report

## 1. Setup
| Item | Value |
|---|---|
| Files audited | `<EA>.mq5`, `<include>.mqh`, … |
| Symbol / timeframe | XAUUSD / M15 |
| Period | yyyy.mm.dd → yyyy.mm.dd (in-sample) · forward from yyyy.mm.dd |
| Model | Every tick based on real ticks (4) · execution normal / random delay |
| Deposit / leverage | 10,000 USD · 1:100 |
| Execution level | A (ran here) / B (user ran scripts) / C (static only) |
| Assumptions | <every default assumed, one line each> |

## 2. Audit findings
| # | Severity | File:line | Finding | Why it matters | Fix |
|---|---|---|---|---|---|

Worst case for averaging logic (if any): <table>

## 3. Changes made
### Fix #1: <title>
- **What was broken:** …
- **Why it matters:** live: … / backtest: …
- **Diff:**
```diff
- old
+ new   // [AUDIT-FIX #1]
```
Inputs added (if any): `<name>` in group `<group>`, default `<value>` (keeps the fixed behaviour).
Deviations from the original strategy (only clear bugs): none / <list>.

## 4. Compile
Source: `_audit/compile.log` → `Result: <N> errors, <M> warnings` *(quoted from the log; "not compiled" if no log)*

## 5. Results (every number cites its report file)
| Run | Inputs | Net profit | PF | Recovery F. | Max equity DD % | Trades | Source |
|---|---|---|---|---|---|---|---|
| Baseline | original.set | | | | | | `_audit/baseline.htm` |
| Optimization best plateau (in-sample) | final.set | | | | | | `opt<k>_is.csv` pass <n> |
| Forward | final.set | | | | | | `opt<k>_fwd.csv` pass <n> |
| Verify (full period) | final.set | | | | | | `_audit/verify.htm` |
| Stress: random delay | final.set | | | | | | `_audit/stress_delay.htm` |
| Stress: 2x spread | final.set | | | | | | `_audit/stress_spread.htm` |

## 6. Parameter choice
Optimized this round: `<inputs>` (ranges from `opt_round<k>.set`). Protected inputs not loosened: `<list>`.
Plateau: <neighbour values and their criterion>; stability <x>; isolated peaks rejected: <list>.

## 7. Verdict
Acceptance thresholds: PF ≥ 1.30 · DD ≤ 20% · RF ≥ 2 · trades ≥ 100 (OOS) · quality ≥ 90% · stress positive · plateau stable.
**Met / Not met** — <reasons>. A backtest result does not guarantee live results.
Next: demo forward test 1–3 months with `final.set`, then the smallest live size.

## 8. Files delivered
Patched sources, `<name>.orig.mq5` backups, `original.set`, `opt_round<k>.set`, `final.set`, `.ini` files,
`run_*.ps1`, parsed CSV/JSON, `runs.jsonl`.
