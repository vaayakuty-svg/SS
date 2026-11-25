# MetaTrader 5 command line, tester `.ini` and `.set` reference

## MetaEditor (compile)

```
metaeditor64.exe /compile:"C:\...\MQL5\Experts\MyEA\MyEA.mq5" /log:"C:\...\compile.log" /include:"C:\...\MQL5"
```
- `/compile:` file or folder; `/log:` log file (UTF-16LE); `/include:` the MQL5 folder used for `<...>` includes
  (needed when the source is outside the terminal's data folder); `/s` = syntax check only (no .ex5).
- The process exit code is **not** a reliable error count. Read the log's last line:
  `Result: N errors, M warnings, T msec elapsed`. Confirm the `.ex5` timestamp changed.
- Under Wine: `wine metaeditor64.exe /compile:"Z:\path\EA.mq5" /log:"Z:\path\compile.log"` (convert paths with `winepath -w`).

## Terminal (Strategy Tester)

```
terminal64.exe /config:"C:\...\_audit\opt_round1.ini" [/portable]
```
- Close MT5 first: if a terminal is already running on the same data folder, the new instance may not start the
  test and no report is written. The runners check for this and report a missing report instead of guessing.
- `/portable` = data folder is the install folder.
- With `ShutdownTerminal=1` the terminal closes after the test, so a script can wait for the process to exit.
- The terminal language should be English so report labels parse (`parse_report.py`).

## `[Tester]` keys

| Key | Values |
|---|---|
| `Expert` | Path relative to `MQL5\Experts`, e.g. `MyEA\MyEA.ex5` |
| `ExpertParameters` | `.set` file name in `MQL5\Profiles\Tester\` |
| `Symbol` | e.g. `XAUUSD` (exact broker name, incl. suffixes like `XAUUSD.m`) |
| `Period` | `M1 … M30, H1 … H12, D1, W1, MN1` |
| `Login` | optional account number (tester uses that server's symbols/history) |
| `Model` | 0 every tick · 1 1-minute OHLC · 2 open prices only · 3 math calculations · **4 every tick based on real ticks** |
| `ExecutionMode` | 0 normal · -1 random delay · N = fixed delay in ms |
| `Optimization` | 0 off · 1 slow complete · **2 fast genetic** · 3 all symbols in Market Watch |
| `OptimizationCriterion` | 0 balance · 1 profit factor · 2 expected payoff · 3 drawdown min · 4 recovery factor · 5 Sharpe · **6 custom (OnTester)** · 7 complex |
| `FromDate`, `ToDate` | `yyyy.mm.dd` |
| `ForwardMode` | 0 off · 1 = 1/2 · 2 = 1/3 · 3 = 1/4 · **4 custom** (`ForwardDate=yyyy.mm.dd`) |
| `Deposit`, `Currency`, `Leverage` | e.g. `10000`, `USD`, `1:100` |
| `ProfitInPips` | 0 money · 1 pips |
| `UseLocal`, `UseRemote`, `UseCloud` | agents (cloud costs money: keep 0 unless the user asks) |
| `Visual` | 0 / 1 |
| `Report` | path **relative to the data folder**, without extension |
| `ReplaceReport` | 1 = overwrite |
| `ShutdownTerminal` | 1 = close when done |

Inputs can be given either via `ExpertParameters=<file>.set` (used by this skill) or a `[TesterInputs]` section with
the same `Name=value||start||step||stop||Y/N` lines.

## Outputs

| Run | File(s) under the data folder |
|---|---|
| Single test | `<Report>.htm` (UTF-16LE HTML) + images |
| Optimization | `<Report>.xml` (SpreadsheetML: Pass, Result, Profit, Expected Payoff, Profit Factor, Recovery Factor, Sharpe Ratio, Custom, Equity DD %, Trades, inputs…) |
| Optimization with forward | `<Report>.forward.xml` (adds Forward Result / Back Result) |
| Journals | `logs\yyyymmdd.log` (terminal), `Tester\logs\yyyymmdd.log` (tester agents) |
| Cache | `Tester\cache\*.opt` (previous optimizations; delete to force a re-run) |

Column names can differ slightly by build; `select_robust.py` matches them case-insensitively.

## `.set` format

```
; comment
InpPeriod=20||10||5||40||Y          value || start || step || stop || optimize?
InpUseFilter=true||false||0||true||N
InpMode=2||0||1||5||N               enums are written as their integer value
InpComment=My EA                    strings: value only
```
MT5 writes `.set` files as UTF-16LE with BOM; `extract_inputs.py` does the same by default.

## Spread stress

The tester has no "spread multiplier" key. For a spread stress pass, run
`templates/CreateStressSymbol.mq5` once (as a script) to clone the symbol into a custom symbol whose ask is widened
(e.g. 2× spread), then test on that symbol (`--stress-symbol XAUUSD_STRESS`). Combine with `ExecutionMode=-1`.

## Common tester journal errors to look for

`not enough money` (lot/margin sizing), `invalid stops` / `[Invalid stops]` (stops level or wrong side),
`invalid volume` (step/min/max), `market closed`, `unsupported filling mode`, `4756` (trade request failed),
`array out of range` / `zero divide` (runtime crash: the EA stops, results are invalid),
`history quality` below 90% (real-tick history missing).
