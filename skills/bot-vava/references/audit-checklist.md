# MQL5 EA audit checklist

Read every source file first (`.mq5` + local `.mqh`). For each item: verdict (PASS / FAIL / N/A), file:line, fix.
The `grep` hints are starting points, not proof; confirm each hit by reading the code.

## A. Compile-level and API correctness

| # | Check | Grep hint | Typical fix |
|---|---|---|---|
| A1 | MQL4 leftovers | `OrderSend\(.*,.*,.*,.*,.*,.*,` · `\bBid\b|\bAsk\b|\bPoint\b|\bDigits\b` · `OrderSelect\(.*SELECT_BY` · `MODE_TRADES` · `iMA\(.*,.*,.*,.*,.*,.*,\s*\d+\)` (shift arg) | `CTrade`, `SymbolInfoDouble`, `_Point`, `_Digits`, handles + `CopyBuffer` |
| A2 | Indicator called like MQL4 (value instead of handle) | `= iRSI\(` inside `OnTick` used as a number | Create the handle in `OnInit`, read with `CopyBuffer` |
| A3 | Return values ignored | `OrderSend\(`, `PositionModify\(`, `CopyBuffer\(`, `OrderCalcMargin\(`, `SymbolSelect\(` | Check the bool/int and `ResultRetcode()` |
| A4 | Shadowing / duplicates | locals named like inputs/globals (`lot`, `sl`, `tp`, `magic`) | Rename locals |
| A5 | Narrowing conversions | `int x = <double expr>`, `(int)` on prices, `ulong` magic into `int` | Explicit cast after range check; keep `ulong` for magic |
| A6 | Name collisions with built-ins | enum values `IND_*`, `MODE_*`, functions `Point()`, `Bars()` | Prefix custom names |
| A7 | Wrong signatures | `CalendarValueHistory` (bool), `CopyTicksRange`, `iBands` (shift arg), `iStochastic` (method, price field) | Match the current docs |
| A8 | Division by zero | `/ atr`, `/ tickSize`, `/ (high-low)` | Guard `> 0` |
| A9 | Array access out of range | `CopyBuffer` count vs index, `ArraySetAsSeries` mismatches | Check the copied count; set series consistently |
| A10 | Handles | `iMA(`/`iATR(` inside `OnTick`; no `IndicatorRelease` | Create once in `OnInit`, release in `OnDeinit`, check `INVALID_HANDLE` |

## B. Trading logic

| # | Check | What to look for |
|---|---|---|
| B1 | Repainting / look-ahead | Signals reading shift 0 for closed-bar logic; ZigZag/fractal current values; `iHighest` including bar 0; using future bars `i-1` in loops over history |
| B2 | Overtrading | Entry logic on every tick without a new-bar gate or "one trade per bar/signal" |
| B3 | Ownership filters | Position/order loops missing `POSITION_MAGIC` **and** `POSITION_SYMBOL` checks |
| B4 | Loop direction | Closing positions while looping forward (`for(i=0;i<PositionsTotal();i++)` + close) → loop backwards |
| B5 | Account type | Hedging assumptions on netting accounts (opposite orders net out); `ACCOUNT_MARGIN_MODE` checked? |
| B6 | SL/TP sanity | Wrong side, below stops level, not normalized to tick size, freeze level ignored on modify |
| B7 | Units | Points vs pips; gold 2/3-digit; hard-coded `0.0001`; `*10` pip multipliers |
| B8 | Lot handling | Not floored to `SYMBOL_VOLUME_STEP`, not clamped to min/max, no margin check |
| B9 | Execution | No deviation/slippage, no retry on requote/price changed, fixed filling mode |
| B10 | Pending orders | Never expire / never cleaned; OCO missing for straddles |
| B11 | Opposite signals | Undefined behaviour when the opposite signal arrives (stacking both directions by accident) |
| B12 | Time | Server vs local vs GMT confusion; `TimeLocal()` in the tester; DST; rollover spreads |
| B13 | State | Counters/flags kept only in globals → lost on restart; no rebuild from open positions in `OnInit` |
| B14 | Tester-only bias | `MQLInfoInteger(MQL_TESTER)` branches that change trading logic |
| B15 | Grid / martingale / recovery | No max levels, no lot cap, no basket stop, no equity kill switch, multiplier on losses. **Compute the worst case** |

## C. Risk guardrails (every EA must have these)

| # | Guardrail | Minimum standard |
|---|---|---|
| C1 | Hard stop loss | Every position has a broker-side SL (or a documented basket/equity stop that closes it) |
| C2 | Position sizing | Lot from risk % and SL distance, or a fixed lot with a documented cap |
| C3 | Margin | `OrderCalcMargin` before sending; skip or reduce lot when it does not fit |
| C4 | Spread | Max spread filter (gold: 25–60 points on 2-digit) |
| C5 | Daily loss | Stop new trades (optionally close) after X% day loss |
| C6 | Drawdown | Equity drawdown kill switch persisted across restarts |
| C7 | Exposure | Max open positions, max total lots |
| C8 | Weekend / news | Friday close or no new trades late Friday; news filter for high-impact USD events |
| C9 | Errors | Trade errors logged with retcode and description; EA does not hammer the server |

## Worst-case template (averaging systems)

```
levels L, step S points, lots l0..lL, adverse move M points (gold 3000 / FX 300 pips)
floating loss ≈ Σ lk × (M − k×S) × value_per_point_per_lot      (only levels with k×S < M)
total lots = Σ lk  → compare with free margin (OrderCalcMargin) and the account balance
```
Report it as a table and state whether the EA's own stops cap it before the account does.

## Severity

- **Critical:** can blow the account or trade unintended size (no SL with averaging, wrong lot units, look-ahead that
  invalidates every backtest, closes other EAs' trades).
- **High:** wrong orders/fills under normal conditions, invalid stops, state loss on restart, overtrading.
- **Medium:** missing filters/guards, inefficiency, poor error handling.
- **Low:** style, logging, naming.
