# Universal Gold EA: Master Blueprint & Implementation Reference

**Platform:** MetaTrader 5 · **Language:** native MQL5 (CTrade) · **Instrument:** XAUUSD (gold)
**Source:** `Experts/UniversalGoldEA/UniversalGoldEA.mq5` + `Experts/UniversalGoldEA/Include/*.mqh`

This document is the specification for the EA in this repository. The tables in this document are generated from
`UGE_Inputs.mqh` and `UGE_Enums.mqh`, so parameter names, data types, defaults and dropdown options match the code exactly.
Each group also has notes on how it works: working logic, entry behaviour, exit behaviour, risk impact and compatibility.

> **No profit is implied.** Every mode is implemented and can be back-tested on its own, but whether a mode makes money
> can only be shown by out-of-sample, forward and demo testing. Grid, martingale, hedge-recovery and recovery modes can
> lose the whole account in one sustained trend.

## 1. Conventions

| Item | Rule |
|---|---|
| Distances | In **points** unless the name says `Price` (gold $ move), `Money` (account currency) or `Percent`. |
| XAUUSD 2-digit | 1 point = 0.01 → a $1.00 move = 100 points. Default inputs assume this. |
| XAUUSD 3-digit | 1 point = 0.001 → a $1.00 move = 1000 points. Multiply point inputs by 10, or use the `...Price`/ATR modes. |
| Contract | Usually 100 oz: 1.00 lot × $1 move = $100. Money maths uses `OrderCalcProfit()` with a tick-value fallback, so broker contract size is respected. |
| Closed bars | Signals read bar index ≥ 1 (no repaint). Only Candle `CANDLE_NOW` reads the forming bar, and only if you select it. |
| Magic numbers | `MagicNumber` = main entries, `+1` grid, `+2` hedge, `+3` recovery. Every loop filters magic **and** symbol. |
| Enum naming | `ENUM_*` types, English option names; MT5 shows the English description in the dropdown. |
| Validation | `OnInit()` rejects contradictory settings (`INIT_PARAMETERS_INCORRECT`) and logs warnings for risky ones. |

## 2. Architecture

| File | Responsibility |
|---|---|
| `UniversalGoldEA.mq5` | Orchestration: `OnInit` validation/handles/restart recovery, `OnTick` pipeline, entry engine, execution modes, opposite-signal logic, `OnTradeTransaction`, `OnTester`. |
| `UGE_Enums.mqh` | Every selectable mode as an ENUM. |
| `UGE_Inputs.mqh` | All inputs, grouped 01–35. |
| `UGE_Core.mqh` | Logging, point/price maths, lot normalisation, margin, stop/freeze level, filling mode, order send with retry, modify (throttled), close/partial/close-all, pending delete/expiry. |
| `UGE_Data.mqh` | Indicator handles (created once, released on exit), buffer reads, swing pivots, structure bias, VWAP, MTF bias. |
| `UGE_Filters.mqh` | Session, day, rollover, weekend, spread + spike, volatility, news (MT5 calendar + manual list), MTF confirmation. |
| `UGE_SMC.mqh` | Smart Money Concepts engine (swings, BOS, CHOCH, BSL/SSL, inducement, OB, FVG, breaker, mitigation block, PD, displacement). |
| `UGE_Signals.mqh` | Candle, breakout, pullback, indicator and strategy preset modules + combiner. |
| `UGE_Risk.mqh` | Persistent state, 14 lot modes, daily loss / profit target, drawdown, exposure caps, cooldowns, streak statistics. |
| `UGE_Manage.mqh` | SL/TP calculation, break-even, trailing, partial closes, time/signal exits, basket/equity exits. |
| `UGE_Grid.mqh` | Grid (15 modes), spacing (8), lot progression (12), hedge (10), recovery (10). |
| `UGE_Panel.mqh` | Dashboard, markers, level lines, popup/push/sound/Telegram alerts. |

### OnTick order (fixed)

1. Spread sample → new-day reset → **RiskMonitor** (daily loss, daily target, drawdown; may close all / halt / remove EA).
2. Forced exits: weekend close, news action, session-end close.
3. Management: **basket/equity → per-position (money TP/SL → time exit → candle-close/trend exits → partial → break-even → trailing) → grid → hedge → recovery** → expired pendings.
4. Entry (only when the timing gate fires): signal → direction → MTF → session → day → news → spread → volatility → frequency → per-bar/per-signal → opposite-signal handling → SL/TP/lot → risk gate → execution.
5. Dashboard (max once per second; skipped in non-visual tests).

### Module independence

* Entry modules (`InpUse...Entry`) are independent booleans. Enable **one** to back-test it alone; enable several and
  choose `InpEntryCombine` (ALL agree / ANY / MAJORITY).
* Exit, lot, risk, grid, hedge, recovery, session and MTF settings are separate input groups. Changing one never changes
  another module's maths.
* A disabled module creates no indicator handles and runs no code.

### Hard conflicts refused at start

| Combination | Reason |
|---|---|
| Grid + Recovery `GRID`/`LOT_MULT`/`MULTI_LEVEL`/`AVERAGE_PRICE`/`HEDGE_ZONE` | Both add to the same losing exposure. |
| Grid `HEDGED` + Hedge module | Both open hedge legs. |
| Hedge module + Recovery `HEDGE_ZONE`/`OPPOSITE` | Both open opposite trades. |
| Lot mode `RECOVERY` + Recovery `PROFIT_TARGET` | Both chase the same realised debt. |
| `EnableBuy`=`EnableSell`=false, direction contradictions, RiskPercent outside (0,10], partial % > 100 | Invalid. |

On a **netting** account, grid, hedge and recovery are switched off automatically (one position per symbol), and
`OPP_HEDGE` behaves like `OPP_IGNORE`. All other modes work on both account types.

---

## 01 General Settings

* **Working logic:** `EnableTrading` gates only *new* entries (grid seeds included); management, risk closes and exits keep running. `EnableBuy/EnableSell` are hard direction switches applied before every entry.
* **Risk impact:** none directly. Use a unique `MagicNumber` per chart: the EA owns Magic … Magic+3.
* **Compatibility:** all modes.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpMagicNumber` | ulong | - | `77001` | unique per chart | Magic number (main trades; +1 grid, +2 hedge, +3 recovery) |
| `InpTradeComment` | string | - | `"UGE"` | - | Trade comment (info only, max 31 chars) |
| `InpEnableTrading` | bool | true / false | `true` | true / false | Master switch: allow NEW trades |
| `InpEnableBuy` | bool | true / false | `true` | true / false | Allow buy entries |
| `InpEnableSell` | bool | true / false | `true` | true / false | Allow sell entries |

---

## 02 Trading Direction

* **Working logic:** `DIR_AUTO_TREND` allows buys only when the last closed `DirectionTF` candle closes above EMA(`DirectionEMA`), sells only below. The same EMA drives `ExitOnTrendChange` and the counter-trend grid.
* **Entry behaviour:** filter only, applied after the signal. **Exit behaviour:** none.
* **Compatibility:** combines with every entry module; combined with `EnableBuy/EnableSell` (both must allow).

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpTradeDirection` | ENUM (ENUM_TRADE_DIRECTION) | `DIR_BOTH` Both directions<br>`DIR_BUY_ONLY` Buy only<br>`DIR_SELL_ONLY` Sell only<br>`DIR_AUTO_TREND` Auto: only with trend EMA (Direction TF) | `DIR_BOTH` | see options | Direction mode |
| `InpDirectionTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_H1` | M1-D1 | Auto-trend timeframe |
| `InpDirectionEMA` | int | - | `200` | 50-200 | Auto-trend EMA period |

---

## 03 Entry Strategy Selection

* **Working logic:** each `Use...Entry` module returns +1/−1/0 from closed bars. `COMBINE_ALL_AGREE`: every enabled module must give the same direction on the same evaluation. `COMBINE_ANY`: at least one module signals and none disagree. `COMBINE_MAJORITY`: more than half of the enabled modules agree.
* **Advanced strategy presets** (`StrategyMode`, real logic each, on `StrategyTF`): Trend following (EMA20>50>200 + ADX>22 + DI + fresh EMA20 reclaim) · Counter trend (RSI <25/>75 + close back inside Bollinger) · Mean reversion (BB re-entry while ADX<25) · Momentum (MACD histogram turn + RSI 55/45 + EMA50 side) · Scalping (EMA9/21 cross + RSI 50 + EMA50 side) · Swing (HH/HL structure + EMA50 pullback + RSI reset) · Breakout retest (20-bar break then retest within 8 bars) · Reversal (engulfing at 20-bar extreme + RSI turn) · Continuation (inside-bar break with EMA50/200 trend) · Range (ADX<20, band rejection toward mid) · Volatility (bar range ≥1.8× average + 10-bar break) · Liquidity (swing sweep and close back inside) · Statistical (close z-score ≥ `StatZEntry` reversal) · Arbitrage (single-leg gold/`ArbSymbol` price-ratio z-score; true multi-venue arbitrage is not possible in one EA).
* **Compatibility:** any mix; for clean back-tests enable one module.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpUseCandleEntry` | bool | true / false | `true` | true / false | Module: Candle-based entry |
| `InpUseBreakoutEntry` | bool | true / false | `false` | true / false | Module: Breakout entry |
| `InpUsePullbackEntry` | bool | true / false | `false` | true / false | Module: Pullback entry |
| `InpUseIndicatorEntry` | bool | true / false | `false` | true / false | Module: Indicator entry |
| `InpUseSMCEntry` | bool | true / false | `false` | true / false | Module: Smart Money Concepts entry |
| `InpUseStrategyEntry` | bool | true / false | `false` | true / false | Module: Advanced strategy preset |
| `InpEntryCombine` | ENUM (ENUM_ENTRY_COMBINE) | `COMBINE_ALL_AGREE` All enabled entry modules must agree<br>`COMBINE_ANY` Any enabled module (first non-zero, no conflict)<br>`COMBINE_MAJORITY` Majority vote of enabled modules | `COMBINE_ALL_AGREE` | see options | How enabled modules combine |
| `InpStrategyMode` | ENUM (ENUM_STRATEGY) | `STRAT_TREND_FOLLOWING` Trend following<br>`STRAT_COUNTER_TREND` Counter trend<br>`STRAT_MEAN_REVERSION` Mean reversion<br>`STRAT_MOMENTUM` Momentum<br>`STRAT_SCALPING` Scalping<br>`STRAT_SWING` Swing trading<br>`STRAT_BREAKOUT_RETEST` Breakout retest<br>`STRAT_REVERSAL` Reversal<br>`STRAT_CONTINUATION` Continuation<br>`STRAT_RANGE` Range trading<br>`STRAT_VOLATILITY` Volatility expansion<br>`STRAT_LIQUIDITY` Liquidity sweep<br>`STRAT_STATISTICAL` Statistical z-score<br>`STRAT_ARBITRAGE` Statistical pair (ratio) arbitrage | `STRAT_TREND_FOLLOWING` | see options | Advanced strategy preset |
| `InpStrategyTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Strategy preset timeframe |
| `InpArbSymbol` | string | - | `"XAGUSD"` | - | Arbitrage: paired symbol (ratio z-score) |
| `InpStatPeriod` | int | - | `50` | 20-200 | Statistical/Arbitrage: z-score period |
| `InpStatZEntry` | double | - | `2.0` | 1.5-3.0 | Statistical/Arbitrage: entry |z| threshold |

---

## 04 Candle Entry Settings

* **Working logic:** `CandleSelection BEFORE` evaluates the last closed candle (shift 1), `NOW` the forming candle (shift 0, repaints by nature: use with tick/timer timing). Colour modes require `MinimumBodySize` and `MaximumWickRatio`. Engulfing: body fully engulfs the previous opposite body. Pin bar: tail ≥ `PinBarRatio`×body and ≥60% of range. Inside bar: candle s+1 inside mother s+2, signal when s closes beyond the inside bar. Outside bar: range engulfs previous, direction = colour. Doji: doji at s+1 after an opposite candle, confirmed by a close beyond the doji. High/Low/Body breakout: crossing of previous candle high/low/body (once per crossing). Wick rejection: tail ≥ `WickRejectRatio`×range and close in the opposite half. Consecutive: `RequiredCandles` same colour.
* **Entry behaviour:** with `EntryOnNewCandle`, evaluated once per new `CandleTF` candle; `OneTradePerCandle` caps entries per candle.
* **Example:** `CP_PREV_COLOR_REVERSE`: previous candle RED → BUY, GREEN → SELL.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpCandlePatternMode` | ENUM (ENUM_CANDLE_PATTERN) | `CP_PREV_BULLISH_BUY` Previous candle bullish -> Buy<br>`CP_PREV_BEARISH_SELL` Previous candle bearish -> Sell<br>`CP_PREV_COLOR_FOLLOW` Follow previous colour (green Buy / red Sell)<br>`CP_PREV_COLOR_REVERSE` Reverse previous colour (red Buy / green Sell)<br>`CP_TWO_BULLISH_BUY` Two bullish candles -> Buy<br>`CP_TWO_BEARISH_SELL` Two bearish candles -> Sell<br>`CP_THREE_CANDLE_CONFIRM` Three same-colour candles -> follow<br>`CP_ENGULFING` Engulfing pattern<br>`CP_PIN_BAR` Pin bar<br>`CP_INSIDE_BAR` Inside bar breakout<br>`CP_OUTSIDE_BAR` Outside bar<br>`CP_DOJI_REVERSAL` Doji reversal<br>`CP_HIGH_BREAKOUT` Candle high breakout -> Buy<br>`CP_LOW_BREAKOUT` Candle low breakout -> Sell<br>`CP_BODY_BREAKOUT` Candle body breakout (both ways)<br>`CP_WICK_REJECTION` Wick rejection<br>`CP_CONSECUTIVE` N consecutive candles same direction | `CP_ENGULFING` | see options | Candle pattern mode |
| `InpCandleSelection` | ENUM (ENUM_CANDLE_SELECTION) | `CANDLE_BEFORE` BEFORE - last closed candle (no repaint)<br>`CANDLE_NOW` NOW - forming candle (intrabar, can repaint) | `CANDLE_BEFORE` | see options | Candle: BEFORE (closed) / NOW (forming) |
| `InpCandleTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Candle timeframe |
| `InpRequiredCandles` | int | - | `3` | 2-5 | Required candles (consecutive mode) |
| `InpMinimumBodySize` | int | - | `50` | 0-300 | Minimum body size (points), 0 = off |
| `InpMaximumWickRatio` | double | - | `0.70` | 0.4-0.9 | Max wick/range ratio for colour modes (0-1) |
| `InpPinBarRatio` | double | - | `2.0` | 1.5-3.0 | Pin bar: tail >= ratio x body |
| `InpDojiBodyRatio` | double | - | `0.10` | 0.05-0.2 | Doji: body <= ratio x range |
| `InpWickRejectRatio` | double | - | `0.50` | 0.4-0.7 | Wick rejection: tail >= ratio x range |
| `InpEntryOnNewCandle` | bool | true / false | `true` | true / false | Evaluate only on a new candle |
| `InpOneTradePerCandle` | bool | true / false | `true` | true / false | Max one entry per candle |

---

## 05 Breakout Entry Settings

* **Working logic:** levels: previous candle H/L (bar 2, broken by bar 1), previous day/week H/L, Asian opening range (`AsianRangeMinutes`), London breaks the Asian range, New York breaks the London-morning range, N-bar range (only if height ≤ `MaxRangePoints`), last swing S/R, Donchian(N), volatility (day open ± k×daily ATR). With `RequireCandleClose` the closed candle must cross level ± `BreakoutBuffer` + `MinBreakoutDistance`; otherwise the live bid crossing is used. The crossing rule prevents repeated signals on the same level.
* **Retest:** with `RetestConfirmation` the break only *arms* a setup; the entry fires when a later candle touches the level (± buffer) and closes on the breakout side within `MaximumRetestBars`.
* **Compatibility:** pairs well with `EXEC_STOP` (pending beyond the level) and session filters.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpBreakoutMode` | ENUM (ENUM_BREAKOUT_MODE) | `BO_PREV_CANDLE_HIGH` Previous candle high breakout (Buy)<br>`BO_PREV_CANDLE_LOW` Previous candle low breakout (Sell)<br>`BO_PREV_CANDLE_HL` Previous candle high/low (both)<br>`BO_DAILY_HL` Previous day high/low<br>`BO_WEEKLY_HL` Previous week high/low<br>`BO_ASIAN_SESSION` Asian opening-range breakout<br>`BO_LONDON_SESSION` London breaks Asian range<br>`BO_NEWYORK_SESSION` New York breaks London-morning range<br>`BO_RANGE` N-bar consolidation range breakout<br>`BO_SUPPORT_RESIST` Swing support/resistance breakout<br>`BO_DONCHIAN` Donchian channel breakout<br>`BO_VOLATILITY` Volatility breakout (day open +/- k*ATR) | `BO_PREV_CANDLE_HL` | see options | Breakout mode |
| `InpBreakoutTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Breakout timeframe |
| `InpBreakoutBuffer` | int | - | `30` | 0-100 | Buffer beyond level (points) |
| `InpRequireCandleClose` | bool | true / false | `true` | true / false | Require candle CLOSE beyond level |
| `InpMinBreakoutDistance` | int | - | `0` | 0-100 | Min distance beyond level (points) |
| `InpRetestConfirmation` | bool | true / false | `false` | true / false | Wait for retest of broken level |
| `InpMaximumRetestBars` | int | - | `6` | 3-12 | Max bars to wait for retest |
| `InpRangeBars` | int | - | `20` | 10-50 | Range/Donchian bars |
| `InpMaxRangePoints` | int | - | `1500` | 500-3000 | Range mode: max range height (points) |
| `InpVolBreakoutK` | double | - | `0.5` | 0.3-1.0 | Volatility breakout: k x daily ATR |
| `InpAsianRangeMinutes` | int | - | `60` | 30-120 | Asian breakout: opening range minutes |

---

## 06 Pullback Entry Settings

* **Working logic:** EMA (slope up, price was ≥2×tolerance away within `MaximumWaitBars`, candle touches EMA ± `PullbackDistance` and closes above) · S/R (recent swing high broken, now retested as support) · Fibonacci (last swing impulse, close inside `FiboMin`–`FiboMax` retracement) · Trendline (line through last two rising lows / falling highs) · VWAP (daily tick-volume VWAP touch with trend) · Breakout retest (Donchian break within N bars, retest) · Order block / FVG retest (uses the SMC engine zones).
* **Confirmation:** `RequireRejection` (≥30% wick on the trade side) + `EntryConfirmation` (close direction, engulfing, or next candle breaks the setup candle; in that case the setup is read on bar 2).

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpPullbackMode` | ENUM (ENUM_PULLBACK_MODE) | `PB_EMA` EMA pullback<br>`PB_SUPPORT_RESIST` Broken S/R pullback<br>`PB_FIBONACCI` Fibonacci retracement zone<br>`PB_TRENDLINE` Swing trendline pullback<br>`PB_VWAP` VWAP pullback<br>`PB_BREAKOUT_RETEST` Breakout retest<br>`PB_ORDER_BLOCK` Order block retest (SMC engine)<br>`PB_FVG` Fair value gap retest (SMC engine) | `PB_EMA` | see options | Pullback mode |
| `InpPullbackTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Pullback timeframe |
| `InpPullbackEMAPeriod` | int | - | `50` | 20-100 | Pullback EMA period |
| `InpPullbackDistance` | int | - | `100` | 30-300 | Touch tolerance around level (points) |
| `InpRequireRejection` | bool | true / false | `true` | true / false | Signal candle must show rejection wick |
| `InpMaximumWaitBars` | int | - | `20` | 10-40 | Impulse must be within N bars |
| `InpEntryConfirmation` | ENUM (ENUM_ENTRY_CONFIRM) | `CONF_NONE` No confirmation<br>`CONF_CLOSE_DIR` Signal candle closes in trade direction<br>`CONF_ENGULFING` Signal candle engulfs previous candle<br>`CONF_NEXT_BAR_BREAK` Next candle breaks setup candle high/low | `CONF_CLOSE_DIR` | see options | Entry confirmation |
| `InpFiboMin` | double | - | `0.50` | 0.382-0.5 | Fibonacci zone min (0.5 = 50%) |
| `InpFiboMax` | double | - | `0.618` | 0.618-0.786 | Fibonacci zone max |
| `InpSwingBars` | int | - | `3` | 2-5 | Swing pivot strength (bars each side) |

---

## 07 Indicator Settings

* **Working logic:** every enabled indicator votes `allowBuy/allowSell`. Directional indicators (EMA, SMA, RSI, MACD, Stoch, BB, ADX trend, CCI, Ichimoku, SAR, VWAP) add a vote; gates (ATR range, ADX strength, BB/MACD volatility logic) only allow or block. A buy needs every enabled indicator to allow it and at least `IndMinVotes` directional buy votes.
* **Logic per type:** `CROSS` fast/slow or signal line cross on bars 2→1 · `LEVEL` close vs slow line / oscillator mid-level cross · `OBOS` exit from oversold (buy) / overbought (sell) · `TREND` steady side/slope · `MOMENTUM` widening spread or rising oscillator · `VOLATILITY` gate only.
* **Compatibility:** one timeframe for all indicators (`IndTF`); handles are created only for enabled indicators.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpIndTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Indicator timeframe (all indicators) |
| `InpIndMinVotes` | int | - | `1` | 1-3 | Min directional indicator votes required |
| `InpUseEMA` | bool | true / false | `true` | true / false | EMA: enable |
| `InpEMALogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_CROSS` | see options | EMA: logic (Cross/Level=price vs slow/Trend=slope) |
| `InpEMAFast` | int | - | `20` | 8-30 | EMA: fast period |
| `InpEMASlow` | int | - | `50` | 30-200 | EMA: slow period |
| `InpUseSMA` | bool | true / false | `false` | true / false | SMA: enable |
| `InpSMALogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_TREND` | see options | SMA: logic |
| `InpSMAFast` | int | - | `50` | 20-100 | SMA: fast period |
| `InpSMASlow` | int | - | `200` | 100-200 | SMA: slow period |
| `InpUseRSI` | bool | true / false | `false` | true / false | RSI: enable |
| `InpRSILogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_OBOS` | see options | RSI: logic (OBOS/Level=50 cross/Trend/Momentum) |
| `InpRSIPeriod` | int | - | `14` | 7-21 | RSI: period |
| `InpRSIOverbought` | double | - | `70.0` | 65-80 | RSI: overbought level |
| `InpRSIOversold` | double | - | `30.0` | 20-35 | RSI: oversold level |
| `InpUseMACD` | bool | true / false | `false` | true / false | MACD: enable |
| `InpMACDLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_CROSS` | see options | MACD: logic (Cross=signal/Level=zero/Momentum=hist) |
| `InpMACDFast` | int | - | `12` | 8-15 | MACD: fast EMA |
| `InpMACDSlow` | int | - | `26` | 20-30 | MACD: slow EMA |
| `InpMACDSignal` | int | - | `9` | 5-12 | MACD: signal period |
| `InpUseStoch` | bool | true / false | `false` | true / false | Stochastic: enable |
| `InpStochLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_OBOS` | see options | Stochastic: logic |
| `InpStochK` | int | - | `14` | 5-21 | Stochastic: %K |
| `InpStochD` | int | - | `3` | 3-5 | Stochastic: %D |
| `InpStochSlowing` | int | - | `3` | 1-5 | Stochastic: slowing |
| `InpStochOverbought` | double | - | `80.0` | 75-90 | Stochastic: overbought |
| `InpStochOversold` | double | - | `20.0` | 10-25 | Stochastic: oversold |
| `InpUseBB` | bool | true / false | `false` | true / false | Bollinger: enable |
| `InpBBLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_OBOS` | see options | Bollinger: logic (OBOS=reversion/Cross=breakout/Trend=mid) |
| `InpBBPeriod` | int | - | `20` | 14-30 | Bollinger: period |
| `InpBBDeviation` | double | - | `2.0` | 1.8-2.5 | Bollinger: deviation |
| `InpUseATRInd` | bool | true / false | `false` | true / false | ATR: enable (volatility gate) |
| `InpATRIndPeriod` | int | - | `14` | 10-21 | ATR: period |
| `InpATRIndMinPoints` | int | - | `100` | 50-300 | ATR: minimum (points) |
| `InpATRIndMaxPoints` | int | - | `3000` | 1500-5000 | ATR: maximum (points) |
| `InpUseADX` | bool | true / false | `false` | true / false | ADX: enable |
| `InpADXLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_TREND` | see options | ADX: logic (Trend=DI direction / Volatility=gate) |
| `InpADXPeriod` | int | - | `14` | 10-21 | ADX: period |
| `InpADXLevel` | double | - | `20.0` | 18-30 | ADX: minimum trend strength |
| `InpUseCCI` | bool | true / false | `false` | true / false | CCI: enable |
| `InpCCILogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_OBOS` | see options | CCI: logic |
| `InpCCIPeriod` | int | - | `20` | 14-30 | CCI: period |
| `InpCCILevel` | double | - | `100.0` | 80-200 | CCI: +/- level |
| `InpUseIchimoku` | bool | true / false | `false` | true / false | Ichimoku: enable |
| `InpIchiLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_TREND` | see options | Ichimoku: logic (Cross=TK cross / Trend=cloud) |
| `InpIchiTenkan` | int | - | `9` | 7-12 | Ichimoku: Tenkan |
| `InpIchiKijun` | int | - | `26` | 20-30 | Ichimoku: Kijun |
| `InpIchiSenkouB` | int | - | `52` | 44-60 | Ichimoku: Senkou B |
| `InpUseSAR` | bool | true / false | `false` | true / false | Parabolic SAR: enable |
| `InpSARLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_CROSS` | see options | SAR: logic (Cross=flip / Trend=side) |
| `InpSARStep` | double | - | `0.02` | 0.01-0.04 | SAR: step |
| `InpSARMax` | double | - | `0.2` | 0.1-0.3 | SAR: maximum |
| `InpUseVWAP` | bool | true / false | `false` | true / false | VWAP (daily, tick volume): enable |
| `InpVWAPLogic` | ENUM (ENUM_IND_LOGIC) | `ILOGIC_CROSS` Indicator cross<br>`ILOGIC_LEVEL` Above / below level<br>`ILOGIC_OBOS` Overbought / oversold reversal<br>`ILOGIC_TREND` Trend confirmation<br>`ILOGIC_MOMENTUM` Momentum confirmation<br>`ILOGIC_VOLATILITY` Volatility confirmation (gate only) | `ILOGIC_TREND` | see options | VWAP: logic (Cross / Trend=side) |

---

## 08 SMC Settings

* **Working logic:** rebuilt once per new `SMCTF` bar from `SMCLookback` closed bars. Swings = fractal pivots of `SMCSwingLen`. BOS = break of the last swing in trend direction; CHOCH = first break against the current structure. OB = last opposite candle before the break (body or wick, per `OrderBlockMode`), flagged if followed by a displacement candle (body ≥ `DisplacementATR`× average range). FVG = 3-candle gap ≥ `FVGMinPoints`. A broken OB becomes a **breaker** in the opposite direction. **Mitigation block** = the failed-swing candle when a CHOCH happens without a new extreme. BSL/SSL sweep = wick beyond swing/equal highs/lows or previous day H/L and close back inside. Inducement = minor 1-bar swing swept inside the trend. Premium/discount = above/below the 50% of the dealing range.
* **Entry behaviour:** zone entries need the last closed candle to touch the zone's entry level (edge / 50% / full by mode) and close in the trade direction; `MitigationMode` chooses first-touch, any-touch or must-reach-50%. Combo = sell-side sweep → bullish CHOCH → retest of an OB or FVG created after the sweep (mirror for sells), all within `SMCMaxSetupBars`.
* **Filters:** `PremiumDiscountMode` (discount buys / premium sells, or OTE 62–79%), `SweepConfirmation`, `InducementFilter`, `HTFStructureFilter` (structure trend on `SMCHTF` must match).
* **Exit link:** `SL_STRUCTURE` uses the protecting swing; `TP_STRUCTURE` targets the opposite liquidity.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpSMCEntryMode` | ENUM (ENUM_SMC_ENTRY) | `SMC_ORDER_BLOCK` Order Block (OB) retest<br>`SMC_FVG` Fair Value Gap retest<br>`SMC_BOS` Break of Structure (continuation)<br>`SMC_CHOCH` Change of Character (reversal)<br>`SMC_BSL` Buy-side liquidity sweep -> Sell<br>`SMC_SSL` Sell-side liquidity sweep -> Buy<br>`SMC_LIQUIDITY_SWEEP` Any liquidity sweep + rejection<br>`SMC_INDUCEMENT` Inducement sweep in trend<br>`SMC_PREMIUM_ZONE` Sell rejections in premium<br>`SMC_DISCOUNT_ZONE` Buy rejections in discount<br>`SMC_EQUILIBRIUM` Equilibrium reclaim with trend<br>`SMC_DISPLACEMENT` Displacement candle with trend<br>`SMC_MITIGATION` First mitigation of BOS order block<br>`SMC_BREAKER_BLOCK` Breaker block retest<br>`SMC_MITIGATION_BLOCK` Mitigation block retest<br>`SMC_COMBO_SWEEP_CHOCH_OB_FVG` Sweep + CHOCH + OB/FVG (recommended) | `SMC_COMBO_SWEEP_CHOCH_OB_FVG` | see options | SMC entry mode |
| `InpSMCTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | SMC timeframe |
| `InpOrderBlockMode` | ENUM (ENUM_OB_MODE) | `OB_BODY` Body of OB candle<br>`OB_WICK` Full wick range<br>`OB_MEAN` Entry at 50% of OB | `OB_BODY` | see options | Order block zone definition |
| `InpFVGMode` | ENUM (ENUM_FVG_MODE) | `FVG_EDGE` Enter at gap edge<br>`FVG_MID` Enter at 50% of gap<br>`FVG_FULL` Gap fully tested | `FVG_EDGE` | see options | FVG entry level |
| `InpStructureMode` | ENUM (ENUM_STRUCT_MODE) | `STRUCT_CLOSE` Body close beyond swing<br>`STRUCT_WICK` Wick beyond swing | `STRUCT_CLOSE` | see options | Structure break confirmation |
| `InpLiquidityMode` | ENUM (ENUM_LIQ_MODE) | `LIQ_SWING` Swing high/low<br>`LIQ_EQUAL_HL` Equal highs/lows<br>`LIQ_PREV_DAY` Previous day high/low | `LIQ_SWING` | see options | Liquidity pool definition |
| `InpPremiumDiscountMode` | ENUM (ENUM_PD_MODE) | `PD_OFF` No premium/discount filter<br>`PD_FILTER` Buy discount / Sell premium<br>`PD_OTE` Optimal trade entry 62-79% | `PD_FILTER` | see options | Premium / discount filter |
| `InpMitigationMode` | ENUM (ENUM_MIT_MODE) | `MIT_FIRST_TOUCH` First touch only<br>`MIT_MULTI_TOUCH` Any touch until broken<br>`MIT_50PCT` Must reach 50% of zone | `MIT_FIRST_TOUCH` | see options | Zone mitigation rule |
| `InpDisplacementFilter` | bool | true / false | `true` | true / false | OB must be followed by displacement |
| `InpDisplacementATR` | double | - | `1.2` | 1.0-2.0 | Displacement: body >= x avg range |
| `InpInducementFilter` | bool | true / false | `false` | true / false | Require inducement sweep before entry |
| `InpSweepConfirmation` | bool | true / false | `false` | true / false | Require recent liquidity sweep |
| `InpHTFStructureFilter` | bool | true / false | `true` | true / false | Trade only with HTF structure |
| `InpSMCHTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_H4` | M1-D1 | HTF structure timeframe |
| `InpSMCSwingLen` | int | - | `3` | 2-5 | Swing pivot strength (bars each side) |
| `InpSMCLookback` | int | - | `300` | 150-500 | Bars analysed |
| `InpSMCMaxSetupBars` | int | - | `30` | 10-50 | Max age of sweep/CHOCH for combo (bars) |
| `InpFVGMinPoints` | int | - | `50` | 20-200 | Min FVG size (points) |
| `InpEqualHLTolerance` | int | - | `50` | 20-100 | Equal highs/lows tolerance (points) |

---

## 09 Multi-Timeframe Settings

* **Working logic:** bias per TF by `MTFMethod`: EMA slope (EMA bar1 vs bar3), close vs EMA, last candle colour, or HH/HL vs LH/LL structure. Modes: all agree · any · ≥ `MinimumTFConfirmations` · TF1 (primary) only · lowest TF candle confirms · TF1 bias + lowest TF candle.
* **Example:** H1, M15, M5 bullish + M1 bullish candle → `MTF_HTF_LTF` allows a buy.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableMTF` | bool | true / false | `false` | true / false | Enable MTF confirmation |
| `InpMTFMode` | ENUM (ENUM_MTF_MODE) | `MTF_ALL` All timeframes confirm<br>`MTF_ANY` Any timeframe confirms<br>`MTF_MAJORITY` Majority / minimum confirmations<br>`MTF_HTF_BIAS` Primary (highest) TF bias only<br>`MTF_LTF_ENTRY` Lowest TF candle must confirm<br>`MTF_HTF_LTF` HTF trend + LTF signal candle | `MTF_ALL` | see options | MTF mode |
| `InpMTFMethod` | ENUM (ENUM_MTF_METHOD) | `MTFM_EMA_SLOPE` EMA slope<br>`MTFM_PRICE_VS_EMA` Close vs EMA<br>`MTFM_CANDLE_DIR` Last closed candle colour<br>`MTFM_STRUCTURE` Swing structure (HH/HL vs LH/LL) | `MTFM_PRICE_VS_EMA` | see options | Bias method per TF |
| `InpMTFCount` | int | - | `3` | 2-4 | Number of TFs used (1-5) |
| `InpPrimaryTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_H1` | M1-D1 | TF 1 (highest / primary) |
| `InpSecondaryTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | TF 2 |
| `InpThirdTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M5` | M1-D1 | TF 3 |
| `InpFourthTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M1` | M1-D1 | TF 4 |
| `InpFifthTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M1` | M1-D1 | TF 5 |
| `InpMTFEMAPeriod` | int | - | `50` | 20-200 | EMA period for bias |
| `InpMinimumTFConfirmations` | int | - | `2` | 2-3 | Majority mode: min confirmations |

---

## 10 Entry Execution Settings

* **Working logic:** `EXEC_MARKET` fills at Ask/Bid. `EXEC_STOP`: Buy Stop at Ask + offset / Sell Stop at Bid − offset. `EXEC_LIMIT`: Buy Limit at Bid − offset / Sell Limit at Ask + offset. `EXEC_RETEST`: limit at the signal candle's close (market if price is already better). `EXEC_HYBRID`: market if within `HybridMaxDistance` of the signal close, else a limit there, else skip (no chasing).
* **Timing:** bar open (once per chart bar), bar close (last `BarCloseSeconds`), every tick, timer. Pending prices are pushed outside the stops level; expiry uses broker-specified time when supported, otherwise the EA deletes expired orders itself.
* **Retries:** requote / price-changed / off-quotes / timeouts / too-many-requests are retried (`MaxOrderRetries`), with requote handling retry, widen deviation or abort.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpExecutionMode` | ENUM (ENUM_EXEC_MODE) | `EXEC_MARKET` Market order<br>`EXEC_STOP` Stop order (Buy Stop above / Sell Stop below)<br>`EXEC_LIMIT` Limit order (Buy Limit below / Sell Limit above)<br>`EXEC_RETEST` Retest: limit at signal candle close<br>`EXEC_HYBRID` Hybrid: market if close to ideal price else limit | `EXEC_MARKET` | see options | Execution mode |
| `InpEntryTiming` | ENUM (ENUM_ENTRY_TIMING) | `TIMING_BAR_OPEN` Bar open (evaluate closed bar once)<br>`TIMING_BAR_CLOSE` Bar close (last N seconds of the bar)<br>`TIMING_EVERY_TICK` Instant / every tick<br>`TIMING_TIMER` Timer (every N seconds) | `TIMING_BAR_OPEN` | see options | Entry timing |
| `InpBarCloseSeconds` | int | - | `10` | 5-30 | Bar close: seconds before close |
| `InpTimerSeconds` | int | - | `5` | 1-60 | Timer timing: interval seconds |
| `InpPendingOffset` | int | - | `100` | 30-300 | Pending order offset (points) |
| `InpOrderExpirationMin` | int | - | `60` | 15-240 | Pending expiry (minutes, 0 = GTC) |
| `InpMaximumSlippage` | int | - | `30` | 10-50 | Max slippage / deviation (points) |
| `InpHybridMaxDistance` | int | - | `50` | 20-150 | Hybrid: market if within (points) |
| `InpMaxOrderRetries` | int | - | `3` | 1-5 | Max order retries |

---

## 06b Entry Frequency & Opposite Signal

* **Working logic:** per-bar, per-signal (a signal key built from each enabled module's candle time), per-day caps, minimum interval and cooldowns after loss/win.
* **Opposite signal** (main positions only): Ignore → keep; Close → close, no new trade; Reverse → close and open opposite; Hedge → keep and open opposite (hedging accounts); Close & re-enter → close now, enter on the next new signal; Close if profitable / if losing → close only in that case, then open; Wait → no new trade until the position is closed. `ExitOnOppositeSignal` forces the close first.
* **Example:** BUY open, SELL signal: Ignore = BUY stays; Close = BUY closed; Reverse = BUY closed + SELL opened; Hedge = BUY kept + SELL opened.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpOneTradePerBar` | bool | true / false | `true` | true / false | One trade per bar (chart TF) |
| `InpOneTradePerSignal` | bool | true / false | `true` | true / false | One trade per signal |
| `InpMaxTradesPerBar` | int | - | `1` | 1-2 | Max trades per bar |
| `InpMaxTradesPerSession` | int | - | `10` | 3-20 | Max trades per day/session |
| `InpMinEntryInterval` | int | - | `0` | 0-900 | Min seconds between entries |
| `InpEnableCooldown` | bool | true / false | `false` | true / false | Enable cooldown |
| `InpCooldownAfterLoss` | int | - | `30` | 15-120 | Cooldown after loss (minutes) |
| `InpCooldownAfterWin` | int | - | `0` | 0-60 | Cooldown after win (minutes) |
| `InpAllowMultiplePositions` | bool | true / false | `false` | true / false | Allow multiple main positions |
| `InpMaxMainPositions` | int | - | `3` | 1-5 | Max main positions (if multiple) |
| `InpOppositeSignalMode` | ENUM (ENUM_OPPOSITE_MODE) | `OPP_IGNORE` Ignore opposite signal<br>`OPP_CLOSE` Close current position<br>`OPP_REVERSE` Close and open opposite<br>`OPP_HEDGE` Keep and open opposite (hedging only)<br>`OPP_CLOSE_REENTER` Close, re-enter on next confirmed signal<br>`OPP_CLOSE_IF_PROFIT` Close only if profitable<br>`OPP_CLOSE_IF_LOSS` Close only if losing<br>`OPP_WAIT` Wait until current trade closes | `OPP_IGNORE` | see options | Opposite signal handling |

---

## 11 Exit Strategy Selection

* **Working logic:** time exits (seconds, minutes, bars on the chart TF, session end, in-profit after N seconds; optionally profit-only) and signal exits (opposite signal, `DirectionTF` EMA trend flip, close at the end of the entry candle). Applied to main positions before partial/BE/trailing.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpTimeExitMode` | ENUM (ENUM_TIME_EXIT) | `TEXIT_OFF` Disabled<br>`TEXIT_SECONDS` Fixed seconds<br>`TEXIT_MINUTES` Minutes<br>`TEXIT_BARS` Bars<br>`TEXIT_SESSION_END` At session end<br>`TEXIT_PROFIT_TIME` In profit after N seconds | `TEXIT_OFF` | see options | Time-based exit |
| `InpMaximumHoldingTime` | int | - | `240` | 60-1440 | Seconds/Minutes value for time exit |
| `InpExitAfterBars` | int | - | `20` | 5-60 | Bars-based exit |
| `InpExitAfterProfitSeconds` | int | - | `300` | 60-1800 | Profit-time exit: seconds |
| `InpTimeExitOnlyProfit` | bool | true / false | `false` | true / false | Time exit only if in profit |
| `InpExitOnOppositeSignal` | bool | true / false | `false` | true / false | Exit on opposite signal |
| `InpExitOnTrendChange` | bool | true / false | `false` | true / false | Exit when Direction-TF EMA trend flips |
| `InpExitOnCandleClose` | bool | true / false | `false` | true / false | Exit at close of entry candle |

---

## 12 Take Profit Settings

* **Working logic:** Fixed ($ distance), Points, Price (absolute; ignored if on the wrong side), Money (virtual close at `TakeProfitMoney` per position), ATR × multiplier, RR × SL distance, Structure (SMC opposite liquidity, else next swing, else RR), Basket (no per-trade TP; group 17 closes). `ATRPeriod`/`ATRTF` define the core ATR used by SL/TP/BE/grid.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableTakeProfit` | bool | true / false | `true` | true / false | Enable take profit |
| `InpTakeProfitMode` | ENUM (ENUM_TP_MODE) | `TP_NONE` Disabled<br>`TP_FIXED` Fixed price distance ($)<br>`TP_POINTS` Points<br>`TP_PRICE` Absolute price level<br>`TP_MONEY` Money per position (virtual)<br>`TP_ATR` ATR multiple<br>`TP_RR` Risk:Reward of SL distance<br>`TP_STRUCTURE` Next swing / liquidity level<br>`TP_BASKET` Basket only (no per-trade TP) | `TP_RR` | see options | Take profit mode |
| `InpTakeProfitFixed` | double | - | `10.0` | 2-30 ($) | Fixed TP distance ($ of price) |
| `InpTakeProfitPoints` | int | - | `1000` | 200-3000 | TP (points) |
| `InpTakeProfitPrice` | double | - | `0.0` | - | Absolute TP price |
| `InpTakeProfitMoney` | double | - | `20.0` | 5-100 | Money TP per position |
| `InpATRMultiplierTP` | double | - | `3.0` | 1.5-5 | ATR x for TP |
| `InpRiskRewardRatio` | double | - | `2.0` | 1.0-3.0 | Risk:Reward ratio |
| `InpATRPeriod` | int | - | `14` | 10-21 | Core ATR period (SL/TP/BE/grid) |
| `InpATRTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Core ATR timeframe |

---

## 13 Stop Loss Settings

* **Working logic:** Fixed ($), Points, Price, ATR × multiplier, previous candle wick/body ± buffer, swing (lowest low of N bars or last fractal) ± buffer, structure (SMC swing), Money (distance computed from the final lot), Equity (no per-trade SL; groups 17/20 protect). The result is clamped to `MinSLPoints`–`MaxSLPoints`; invalid levels fall back to ATR. BUY SL is below entry, SELL SL above.
* **Risk impact:** SL distance drives risk-based lot sizing; without an SL, sizing uses `NoSLFallbackPoints`.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableStopLoss` | bool | true / false | `true` | true / false | Enable stop loss |
| `InpStopLossMode` | ENUM (ENUM_SL_MODE) | `SL_NONE` Disabled (use with care)<br>`SL_FIXED` Fixed price distance ($)<br>`SL_POINTS` Points<br>`SL_PRICE` Absolute price level<br>`SL_ATR` ATR multiple<br>`SL_PREV_CANDLE` Previous candle high/low<br>`SL_SWING` Swing high/low<br>`SL_STRUCTURE` SMC structure level<br>`SL_MONEY` Money per position<br>`SL_EQUITY` Equity protection only (no per-trade SL) | `SL_ATR` | see options | Stop loss mode |
| `InpStopLossFixed` | double | - | `5.0` | 2-15 ($) | Fixed SL distance ($ of price) |
| `InpStopLossPoints` | int | - | `500` | 150-1500 | SL (points) |
| `InpStopLossPrice` | double | - | `0.0` | - | Absolute SL price |
| `InpStopLossMoney` | double | - | `10.0` | 5-50 | Money SL per position |
| `InpATRMultiplierSL` | double | - | `1.5` | 1.0-3.0 | ATR x for SL |
| `InpCandleSLMode` | ENUM (ENUM_CANDLE_SL) | `CSL_WICK` Candle wick<br>`CSL_BODY` Candle body | `CSL_WICK` | see options | Previous candle SL: wick/body |
| `InpSwingSLMode` | ENUM (ENUM_SWING_SL) | `SSL_LOOKBACK` Lowest low / highest high of N bars<br>`SSL_FRACTAL` Last confirmed fractal swing | `SSL_LOOKBACK` | see options | Swing SL method |
| `InpSwingSLBars` | int | - | `10` | 5-20 | Swing SL lookback bars |
| `InpSLBuffer` | int | - | `30` | 10-100 | Buffer beyond candle/swing (points) |
| `InpMinSLPoints` | int | - | `150` | 100-300 | Min SL distance (points) |
| `InpMaxSLPoints` | int | - | `3000` | 1500-5000 | Max SL distance (points) |
| `InpNoSLFallbackPoints` | int | - | `1000` | 500-2000 | Risk sizing distance if no SL (points) |

---

## 14 Trailing Stop Settings

* **Working logic** (starts after `TrailingStart` points of profit; only moves in the profit direction; never crosses price): Fixed (price − distance, updates ≥ step) · Step (staircase: locks `Start − Distance + k×Step`) · ATR (price − ATR×mult) · Percent (keeps `TrailingPercent` of open profit) · Candle (previous candle low/high ± distance) · Swing (last fractal ± distance) · SAR · Chandelier (highest high(N) − ATR×mult).
* **Broker rules:** stops level, freeze level and throttling (min seconds and min change) are enforced in `ModifyPosition`.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableTrailing` | bool | true / false | `true` | true / false | Enable trailing |
| `InpTrailingMode` | ENUM (ENUM_TRAIL_MODE) | `TRAIL_OFF` Disabled<br>`TRAIL_FIXED` Fixed distance<br>`TRAIL_STEP` Step (staircase lock)<br>`TRAIL_ATR` ATR distance<br>`TRAIL_PERCENT` Keep % of open profit<br>`TRAIL_CANDLE` Previous candle high/low<br>`TRAIL_SWING` Last swing high/low<br>`TRAIL_SAR` Parabolic SAR<br>`TRAIL_CHANDELIER` Chandelier exit | `TRAIL_ATR` | see options | Trailing mode |
| `InpTrailingStart` | int | - | `300` | 100-1000 | Start after profit (points) |
| `InpTrailingDistance` | int | - | `250` | 100-800 | Distance / buffer (points) |
| `InpTrailingStep` | int | - | `50` | 10-200 | Step (points) |
| `InpATRTrailingMultiplier` | double | - | `1.5` | 1.0-3.0 | ATR x for ATR/Chandelier |
| `InpTrailingPercent` | double | - | `50.0` | 30-80 | Percent: keep % of profit |
| `InpTrailingTimeframe` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Candle/swing/SAR/ATR trail TF |
| `InpChandelierBars` | int | - | `22` | 14-30 | Chandelier lookback |

---

## 15 Break Even Settings

* **Working logic:** Fixed (trigger → SL = entry), Plus (SL = entry + offset), ATR (trigger = ATR × mult), Percent (trigger = % of TP distance), Partial (after TP1 partial close). `BreakEvenAfterProfit` adds a money trigger.
* **Example:** BUY 2650.00, trigger 200 points ($2.00): at 2652.00 SL → 2650.00 (Fixed) or 2650.20 with a 20-point offset (Plus).

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableBreakEven` | bool | true / false | `true` | true / false | Enable break even |
| `InpBreakEvenMode` | ENUM (ENUM_BE_MODE) | `BE_OFF` Disabled<br>`BE_FIXED` Fixed trigger -> SL at entry<br>`BE_PLUS` Trigger -> SL at entry + offset<br>`BE_ATR` ATR trigger<br>`BE_PERCENT` % of TP distance trigger<br>`BE_PARTIAL` After TP1 partial close | `BE_PLUS` | see options | Break even mode |
| `InpBreakEvenTrigger` | int | - | `200` | 100-600 | Trigger (points) |
| `InpBreakEvenOffset` | int | - | `20` | 10-60 | Lock offset (points) |
| `InpBreakEvenATR` | double | - | `1.0` | 0.5-1.5 | ATR trigger multiple |
| `InpBreakEvenPercent` | double | - | `50.0` | 30-70 | % of TP distance trigger |
| `InpBreakEvenAfterProfit` | double | - | `0.0` | 0-50 | Also trigger at money profit (0 = off) |

---

## 16 Partial Close Settings

* **Working logic:** stages TP1→TP2→TP3 measured in points (fixed modes), % of TP distance, or money profit. Each stage closes its % of the **initial** volume (stored per position, restart-safe); the final stage of the 3-level mode closes the remainder. Volumes are floored to the broker step; if the remainder would fall below the minimum volume, the whole position is closed.
* **Example:** 0.10 BUY → TP1 30% (0.03) → TP2 30% (0.03) → TP3 the remaining 0.04.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnablePartialClose` | bool | true / false | `false` | true / false | Enable partial close |
| `InpPartialCloseMode` | ENUM (ENUM_PARTIAL_MODE) | `PC_OFF` Disabled<br>`PC_SINGLE` Single partial (TP1)<br>`PC_TP1_TP2` TP1 + TP2<br>`PC_TP1_2_3` TP1 + TP2 + TP3<br>`PC_PERCENT` Levels as % of TP distance<br>`PC_MONEY` Levels as money profit | `PC_TP1_TP2` | see options | Partial mode |
| `InpTP1Distance` | double | - | `300` | by mode | TP1 (points / % / money by mode) |
| `InpTP1ClosePercent` | double | - | `50` | 25-60 | TP1 close % of initial volume |
| `InpTP2Distance` | double | - | `600` | by mode | TP2 |
| `InpTP2ClosePercent` | double | - | `30` | 20-40 | TP2 close % |
| `InpTP3Distance` | double | - | `900` | by mode | TP3 |
| `InpTP3ClosePercent` | double | - | `20` | remaining | TP3 close % (remaining is closed at TP3) |

---

## 17 Basket Management

* **Working logic:** Money (floating P/L ≥ TP or ≤ −SL), Percent (of balance), Points (lot-weighted points), Weighted average (break-even price of the net position ± points), Equity (equity vs day-start equity ± X), Combined (money + equity). Scope: all EA positions or buy/sell baskets separately. `IncludeManualTrades` adds magic-0 trades on this symbol.
* **Example:** total floating +$10 with `BasketTakeProfit` = 10 → all included positions closed.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpBasketExitMode` | ENUM (ENUM_BASKET_MODE) | `BASKET_OFF` Disabled<br>`BASKET_MONEY` Money target / stop<br>`BASKET_PERCENT` % of balance target / stop<br>`BASKET_POINTS` Lot-weighted points<br>`BASKET_WAVG` Weighted average (break-even) price exit<br>`BASKET_EQUITY` Equity take profit / stop loss<br>`BASKET_COMBINED` Money + equity together | `BASKET_OFF` | see options | Basket exit mode |
| `InpBasketScope` | ENUM (ENUM_BASKET_SCOPE) | `BSCOPE_ALL` All EA positions<br>`BSCOPE_PER_DIR` Buy and sell baskets separately | `BSCOPE_ALL` | see options | Basket scope |
| `InpBasketTakeProfit` | double | - | `10.0` | by mode | Basket TP (money / % / points) |
| `InpBasketStopLoss` | double | - | `0.0` | by mode | Basket SL (money / % / points, 0 = off) |
| `InpEquityTakeProfit` | double | - | `0.0` | 0 or 1-5% of balance | Equity TP: day-start equity + X (0 = off) |
| `InpEquityStopLoss` | double | - | `0.0` | 0 or 2-10% of balance | Equity SL: day-start equity - X (0 = off) |
| `InpCloseAllOnTarget` | bool | true / false | `true` | true / false | Close basket on target |
| `InpCloseAllOnLoss` | bool | true / false | `true` | true / false | Close basket on loss |
| `InpIncludeManualTrades` | bool | true / false | `false` | true / false | Include manual trades (magic 0, this symbol) |

---

## 18 Lot Sizing Settings

* **Working logic:** see Appendix A for the risk formula. Dynamic = FixedLot × balance/BalanceBase. Compounding = FixedLot × (balance/base)^factor. Anti-compounding shrinks the lot after gains and after losses. ATR = risk % over an ATR×SL-multiplier distance. Volatility = FixedLot × (100-bar average range / ATR). Martingale / anti-martingale / Fibonacci / custom sequence step on the consecutive loss (or win) count, settings in group 24. Recovery = lot whose TP recovers the realised debt + `RecoveryLotTarget`.
* **Validation:** volume step, broker min/max, EA min/max, margin fit, `MaximumTotalLots`, symbol volume limit.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpLotMode` | ENUM (ENUM_LOT_MODE) | `LOT_FIXED` Fixed lot<br>`LOT_RISK_BALANCE` Balance % risk<br>`LOT_RISK_EQUITY` Equity % risk<br>`LOT_RISK_FREEMARGIN` Free margin % risk<br>`LOT_DYNAMIC` Dynamic: FixedLot per BalanceBase<br>`LOT_COMPOUNDING` Compounding (power curve)<br>`LOT_ANTI_COMPOUNDING` Anti-compounding (lock gains)<br>`LOT_ATR` ATR risk (ATR stop distance)<br>`LOT_VOLATILITY` Volatility scaled (inverse ATR)<br>`LOT_MARTINGALE` Martingale after losses<br>`LOT_ANTI_MARTINGALE` Anti-martingale after wins<br>`LOT_FIBONACCI` Fibonacci after losses<br>`LOT_CUSTOM_SEQUENCE` Custom sequence after losses<br>`LOT_RECOVERY` Recovery: TP recovers realized debt | `LOT_RISK_EQUITY` | see options | Lot mode |
| `InpFixedLot` | double | - | `0.01` | 0.01-0.10 | Fixed / base lot |
| `InpMinimumLot` | double | - | `0.01` | broker min | Minimum lot (EA cap) |
| `InpMaximumLot` | double | - | `1.00` | 0.10-5.0 | Maximum lot per order (EA cap) |
| `InpLotStep` | double | - | `0.0` | 0 (broker) | Lot step override (0 = broker) |
| `InpRiskPercent` | double | - | `1.0` | 0.25-2.0 | Risk % per trade |
| `InpBalanceBase` | double | - | `1000.0` | 500-10000 | Balance base for dynamic/compounding |
| `InpCompoundingFactor` | double | - | `1.0` | 0.5-1.0 | Compounding exponent |
| `InpEnableDynamicLot` | bool | true / false | `true` | true / false | Reduce lot to fit free margin |
| `InpCustomLotSequence` | string | - | `"0.01,0.02,0.03,0.05,0.08"` | - | Custom lot sequence |
| `InpRecoveryLotTarget` | double | - | `5.0` | 1-20 | Recovery lot: extra profit target (money) |

---

## 19 Risk Management

* **Working logic:** daily loss (money and/or % of day-start balance) on realised, floating or combined P/L; daily profit target; daily trade limit; max open trades / per direction / total lots; stop after N consecutive losses or N wins today; minimum margin level. Breach → `RiskAction`: block new, close all + block, or close all + remove the EA. The daily halt clears at the next server day.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableDailyLossLimit` | bool | true / false | `true` | true / false | Enable daily loss limit |
| `InpMaxDailyLossMoney` | double | - | `0.0` | 0 or 2-5% of balance | Max daily loss money (0 = off) |
| `InpMaxDailyLossPercent` | double | - | `3.0` | 2-5 | Max daily loss % of day-start balance |
| `InpLossBasis` | ENUM (ENUM_LOSS_BASIS) | `LOSS_REALIZED` Realized only<br>`LOSS_FLOATING` Floating only<br>`LOSS_COMBINED` Realized + floating | `LOSS_COMBINED` | see options | Daily loss basis |
| `InpDailyProfitTarget` | double | - | `0.0` | 0 or 1-5% of balance | Daily profit target money (0 = off) |
| `InpDailyTradeLimit` | int | - | `20` | 3-30 | Max entries per day (0 = off) |
| `InpMaximumOpenTrades` | int | - | `10` | 1-20 | Max open EA positions (all magics) |
| `InpMaximumBuyPositions` | int | - | `10` | 1-10 | Max buy positions |
| `InpMaximumSellPositions` | int | - | `10` | 1-10 | Max sell positions |
| `InpMaximumTotalLots` | double | - | `2.0` | 0.1-5.0 | Max total open lots |
| `InpStopTradingAfterLoss` | int | - | `0` | 0-5 | Stop for day after N consecutive losses (0 = off) |
| `InpStopTradingAfterWin` | int | - | `0` | 0-5 | Stop for day after N wins today (0 = off) |
| `InpMinMarginLevel` | double | - | `300.0` | 200-1000 | Min margin level % for new trades (0 = off) |
| `InpRiskAction` | ENUM (ENUM_RISK_ACTION) | `RACT_BLOCK_NEW` Block new entries<br>`RACT_CLOSE_BLOCK` Close all and block<br>`RACT_CLOSE_REMOVE` Close all and remove EA | `RACT_CLOSE_BLOCK` | see options | Action on daily limit breach |

---

## 20 Drawdown Protection

* **Working logic:** drawdown from start balance, start equity or peak equity (tracked every tick, persisted). Breach → close/block per `DrawdownAction`; the halt survives restarts until `ResetDrawdownHalt` is set to true once.
* **Compatibility:** applies to every mode, including grid/hedge/recovery (their adds call the same risk gate).

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableMaxDrawdown` | bool | true / false | `true` | true / false | Enable max drawdown |
| `InpDrawdownMode` | ENUM (ENUM_DD_MODE) | `DD_BALANCE` Balance from start<br>`DD_EQUITY` Equity from start<br>`DD_PEAK_EQUITY` From peak equity | `DD_PEAK_EQUITY` | see options | Drawdown reference |
| `InpMaxDrawdownPercent` | double | - | `10.0` | 5-20 | Max drawdown % |
| `InpMaxDrawdownMoney` | double | - | `0.0` | 0 or account based | Max drawdown money (0 = off) |
| `InpDrawdownAction` | ENUM (ENUM_RISK_ACTION) | `RACT_BLOCK_NEW` Block new entries<br>`RACT_CLOSE_BLOCK` Close all and block<br>`RACT_CLOSE_REMOVE` Close all and remove EA | `RACT_CLOSE_BLOCK` | see options | Action on drawdown breach |
| `InpResetDrawdownHalt` | bool | true / false | `false` | true / false | Set true once to clear a drawdown halt |

---

## 21 Spread & Slippage

* **Working logic:** Spread = Ask − Bid in points. Entries blocked above `MaximumSpread` or above `MaximumSpreadMultiplier` × the rolling average of the last `SpreadAveragePeriod` ticks. Fill slippage above `MaximumSlippagePoints` is logged, and the position is closed at once if `CloseOnExcessSlippage` is on.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableSpreadFilter` | bool | true / false | `true` | true / false | Enable spread filter |
| `InpMaximumSpread` | int | - | `40` | 25-60 | Max spread (points) |
| `InpMaximumSlippagePoints` | int | - | `30` | 10-50 | Max slippage after fill (points, log/close) |
| `InpCloseOnExcessSlippage` | bool | true / false | `false` | true / false | Close fill if slippage exceeds max |
| `InpEnableSpreadSpikeFilter` | bool | true / false | `true` | true / false | Enable spread spike filter |
| `InpSpreadAveragePeriod` | int | - | `100` | 50-300 | Spread average (ticks) |
| `InpMaximumSpreadMultiplier` | double | - | `2.5` | 1.5-3.0 | Block if spread > avg x this |
| `InpRetryFailedOrders` | bool | true / false | `true` | true / false | Retry failed orders |
| `InpRetryCount` | int | - | `3` | 1-5 | Retry count |
| `InpRetryDelayMilliseconds` | int | - | `300` | 100-1000 | Retry delay (ms) |

---

## 22 Grid Settings

* **Working logic:** averaging modes add a level when price moves `GridStep(level)` against the worst open price of the basket (main seed + grid). Classic/Buy/Sell/Buy & Sell/Counter-trend (seeds only when price is ≥1.5 ATR beyond the direction EMA)/Recovery (adds only after `RecoveryTriggerLoss`)/Dynamic (ATR step × expansion)/Adaptive (step × ATR regime × expansion)/Candle (add needs a new bar closing in basket direction)/Hedged (from `GridHedgeFromLevel` each level is an opposite hedge leg). Reverse: each step move opens a trade *in* the move direction. Trend: pyramid in profit while the direction EMA agrees, basket stop one step behind the newest add. Breakout: stop-order ladder both sides, OCO removes the other side. Zone: limit ladder inside a price zone (or previous day H/L), each with a one-step TP. Multi-level: once a seed exists, all levels are placed as limit orders.
* **Exits:** average price + points, basket money, or first+last pair; basket SL money and max DD % always active; at max level: hold, close, hedge net exposure, or stop.
* **Example:** BUY grid at 2650.00 with $2 step → 2648.00, 2646.00, 2644.00, 2642.00. SELL grid → 2652.00, 2654.00, ….

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableGrid` | bool | true / false | `false` | true / false | Enable grid |
| `InpGridMode` | ENUM (ENUM_GRID_MODE) | `GRID_CLASSIC` Classic averaging grid<br>`GRID_BUY` Buy grid only<br>`GRID_SELL` Sell grid only<br>`GRID_BUY_SELL` Independent buy & sell grids<br>`GRID_REVERSE` Reverse: trade in direction of each step<br>`GRID_TREND` Trend-following pyramid<br>`GRID_COUNTER_TREND` Counter-trend (fade EMA) averaging<br>`GRID_HEDGED` Hedged grid (opposite after level N)<br>`GRID_RECOVERY` Recovery grid (starts at loss trigger)<br>`GRID_DYNAMIC` Dynamic grid (ATR step per level)<br>`GRID_ADAPTIVE` Adaptive (volatility-regime step)<br>`GRID_CANDLE` Candle-confirmed averaging<br>`GRID_BREAKOUT` Breakout stop-order ladder<br>`GRID_ZONE` Zone (range) limit ladder<br>`GRID_MULTI_LEVEL` Multi-level pending limit ladder | `GRID_CLASSIC` | see options | Grid mode |
| `InpGridDirection` | ENUM (ENUM_GRID_DIRECTION) | `GDIR_BOTH` Both<br>`GDIR_BUY` Buy only<br>`GDIR_SELL` Sell only<br>`GDIR_SIGNAL` Follow entry signal | `GDIR_SIGNAL` | see options | Grid direction |
| `InpGridAutoStart` | bool | true / false | `false` | true / false | Auto start without entry signal |
| `InpGridSpacingMode` | ENUM (ENUM_GRID_SPACING) | `GSP_FIXED_PRICE` Fixed price distance ($)<br>`GSP_POINTS` Points<br>`GSP_ATR` ATR multiple<br>`GSP_PERCENT` % of price<br>`GSP_CANDLE_RANGE` Average candle range<br>`GSP_FIBONACCI` Fibonacci expanding<br>`GSP_DYNAMIC` Dynamic (expansion per level, clamped)<br>`GSP_ADAPTIVE` Adaptive (ATR regime x expansion) | `GSP_POINTS` | see options | Grid spacing mode |
| `InpGridStepPrice` | double | - | `2.0` | 1-10 ($) | Step price distance ($) |
| `InpGridStepPoints` | int | - | `300` | 150-1500 | Step (points) |
| `InpATRGridMultiplier` | double | - | `1.0` | 0.5-2.0 | ATR x step |
| `InpGridStepPercent` | double | - | `0.10` | 0.05-0.5 | Step % of price |
| `InpGridSpacingMultiplier` | double | - | `1.0` | 1.0-1.5 | Step multiplier per level (1 = flat) |
| `InpGridExpansionFactor` | double | - | `1.2` | 1.0-1.5 | Dynamic/adaptive expansion per level |
| `InpDynamicStepMinimum` | int | - | `150` | 100-500 | Dynamic step min (points) |
| `InpDynamicStepMaximum` | int | - | `2000` | 1000-5000 | Dynamic step max (points) |
| `InpMaximumGridLevels` | int | - | `5` | 2-8 | Max grid levels per basket |
| `InpMaximumGridOrders` | int | - | `10` | 4-16 | Max grid orders (positions + pendings) |
| `InpGridStartDistance` | int | - | `0` | 0-1000 | Distance before first level (points, 0 = step) |
| `InpGridHedgeFromLevel` | int | - | `3` | 2-5 | Hedged grid: opposite from level |
| `InpZoneHigh` | double | - | `0.0` | - | Zone grid: upper price (0 = prev day high) |
| `InpZoneLow` | double | - | `0.0` | - | Zone grid: lower price (0 = prev day low) |
| `InpGridTPMode` | ENUM (ENUM_GRID_TP) | `GTP_AVG_PRICE` Average price + points<br>`GTP_BASKET_MONEY` Basket money<br>`GTP_LAST_LEVEL` First + last level pair | `GTP_AVG_PRICE` | see options | Grid take profit mode |
| `InpGridTPPoints` | int | - | `300` | 100-800 | Grid TP beyond average (points) |
| `InpGridTPMoney` | double | - | `10.0` | 2-50 | Grid basket TP (money) |
| `InpGridStopLossMoney` | double | - | `100.0` | mandatory: 2-10% of balance | Grid basket SL (money, 0 = off) |
| `InpGridMaxDDPercent` | double | - | `15.0` | 5-20 | Grid max DD % of balance (0 = off) |
| `InpGridOnMaxLevel` | ENUM (ENUM_GRID_ONMAX) | `GMAX_HOLD` Hold, no more levels<br>`GMAX_CLOSE_ALL` Close grid<br>`GMAX_HEDGE` Hedge net exposure<br>`GMAX_STOP` Stop new trading | `GMAX_HOLD` | see options | Action at max level |

---

## 23 Grid Lot Progression

* **Working logic** (level 1 = first add): Fixed 0.01→0.01→0.01 · Arithmetic 0.01→0.02→0.03 · Geometric ×mult · Martingale ×2 (0.01→0.02→0.04→0.08) · Anti-martingale ÷mult · Fibonacci · Custom list (e.g. 0.01, 0.09, 0.45, 2.25) · Risk-based (risk % over two steps) · Recovery (pulls the average within one TP of price) · Decreasing · Alternating · Hybrid (fixed until level N, then geometric). Every lot is capped by `GridMaxLot`, `GridMaxTotalLots`, the broker step and the global total-lot cap.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpGridLotMode` | ENUM (ENUM_GRID_LOT) | `GLOT_FIXED` Fixed<br>`GLOT_ARITHMETIC` Arithmetic (+add per level)<br>`GLOT_GEOMETRIC` Geometric (x multiplier)<br>`GLOT_MARTINGALE` Martingale (x2)<br>`GLOT_ANTI_MARTINGALE` Anti-martingale (/ multiplier)<br>`GLOT_FIBONACCI` Fibonacci<br>`GLOT_CUSTOM` Custom sequence<br>`GLOT_RISK_BASED` Risk % to grid basket SL<br>`GLOT_RECOVERY` Pull average price toward market<br>`GLOT_DECREASING` Decreasing (-add per level)<br>`GLOT_ALTERNATING` Alternating base / base x mult<br>`GLOT_HYBRID` Fixed until level N, then geometric | `GLOT_FIXED` | see options | Grid lot progression |
| `InpGridInitialLot` | double | - | `0.01` | 0.01-0.05 | Initial grid lot |
| `InpGridLotMultiplier` | double | - | `1.5` | 1.1-2.0 | Multiplier |
| `InpGridLotAddition` | double | - | `0.01` | 0.01-0.05 | Addition per level |
| `InpGridCustomLots` | string | - | `"0.01,0.02,0.03,0.05,0.08"` | - | Custom sequence |
| `InpGridHybridLevel` | int | - | `3` | 2-5 | Hybrid: geometric from level |
| `InpGridRiskPercent` | double | - | `0.5` | 0.1-1.0 | Risk-based: % per level |
| `InpGridMaxLot` | double | - | `0.50` | 0.05-1.0 | Max lot per grid level |
| `InpGridMaxTotalLots` | double | - | `1.00` | 0.1-2.0 | Max total grid lots |
| `InpEnableLotCap` | bool | true / false | `true` | true / false | Enforce grid lot caps |

---

## 24 Martingale Settings

* **Working logic:** parameters for lot modes Martingale / Anti-martingale / Fibonacci / Custom: double, multiplier or additive step, `MartingaleMaxSteps` cap (then the sequence resets), reset on win.
* **Risk impact:** high. Losses grow geometrically; keep the step cap small.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpMartingaleMode` | ENUM (ENUM_MARTI_MODE) | `MARTI_DOUBLE` Double (x2)<br>`MARTI_MULTIPLIER` Custom multiplier<br>`MARTI_ADDITIVE` Add fixed lot per step | `MARTI_MULTIPLIER` | see options | Martingale progression |
| `InpMartingaleMultiplier` | double | - | `1.5` | 1.2-2.0 | Multiplier |
| `InpMartingaleAddition` | double | - | `0.01` | 0.01-0.05 | Additive step |
| `InpMartingaleMaxSteps` | int | - | `4` | 2-5 | Max steps (then reset) |
| `InpMartingaleResetOnWin` | bool | true / false | `true` | true / false | Reset sequence on win |

---

## 25 Hedge Settings

* **Working logic:** watches the protected side (main + grid + recovery). Full = 100% opposite lots; Partial = `HedgePercentage`; Dynamic = scales with loss/(2×trigger); Recovery = exposure × multiplier; Emergency = equity DD from peak ≥ `HedgeEmergencyDD`; Grid = at grid max level; Signal = only when the entry engine signals the opposite direction; Profit lock = after profit ≥ `HedgeLockProfit` retraces `HedgeLockRetrace` %; Directional = only when `HedgeTF` EMA trend is against the position (unlocked when it turns back). Extra hedges need `AllowMultipleHedges` and an escalated loss. The pair closes at net ≥ `HedgeCloseProfit`; an orphan hedge is closed.
* **Risk impact:** a hedge freezes the loss; it does not remove it. Spread, commission and swap continue.
* **Example:** BUY 0.10 → Full hedge SELL 0.10, Partial (50%) SELL 0.05.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableHedge` | bool | true / false | `false` | true / false | Enable hedge |
| `InpHedgeMode` | ENUM (ENUM_HEDGE_MODE) | `HEDGE_DISABLED` Disabled<br>`HEDGE_FULL` Full hedge (100%)<br>`HEDGE_PARTIAL` Partial hedge (%)<br>`HEDGE_DYNAMIC` Dynamic (scales with loss)<br>`HEDGE_RECOVERY` Recovery hedge (x multiplier)<br>`HEDGE_EMERGENCY` Emergency (equity DD trigger)<br>`HEDGE_GRID` Grid hedge (at grid max level)<br>`HEDGE_SIGNAL` Signal-based (opposite signal in loss)<br>`HEDGE_PROFIT_LOCK` Profit lock (after retrace from peak)<br>`HEDGE_DIRECTIONAL` Directional (HTF trend against position) | `HEDGE_PARTIAL` | see options | Hedge mode |
| `InpHedgeTriggerLoss` | double | - | `20.0` | 10-200 | Trigger loss (money) |
| `InpHedgeLotMode` | ENUM (ENUM_HEDGE_LOT) | `HLOT_SAME` Same as exposure<br>`HLOT_MULTIPLIER` Exposure x multiplier<br>`HLOT_PERCENT` Exposure x percentage | `HLOT_PERCENT` | see options | Hedge lot mode |
| `InpHedgeLotMultiplier` | double | - | `1.2` | 1.0-2.0 | Hedge lot multiplier |
| `InpHedgePercentage` | double | - | `50.0` | 25-100 | Hedge percentage |
| `InpMaximumHedgePositions` | int | - | `2` | 1-3 | Max hedge positions |
| `InpAllowMultipleHedges` | bool | true / false | `false` | true / false | Allow multiple hedges |
| `InpHedgeCloseProfit` | double | - | `0.0` | 0-20 | Close hedge pair at net >= money |
| `InpHedgeEmergencyDD` | double | - | `8.0` | 5-15 | Emergency: equity DD % |
| `InpHedgeLockProfit` | double | - | `15.0` | 5-100 | Profit lock: min profit money |
| `InpHedgeLockRetrace` | double | - | `40.0` | 20-60 | Profit lock: retrace % from peak |
| `InpHedgeTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_H1` | M1-D1 | Directional: trend TF |
| `InpHedgeEMA` | int | - | `50` | 20-200 | Directional: EMA period |

---

## 26 Recovery Settings

* **Working logic:** arms when main + recovery floating ≤ −`RecoveryTriggerLoss`; closes everything at net ≥ `RecoveryTargetMoney`, or at the timeout. Lot multiplier (adds ×mult each step against) · Opposite (opposite leg ×mult at each trigger multiple) · Grid (flat adds) · Hedge/zone recovery (alternating legs sized by the zone formula in Appendix A) · Basket (no new trades, waits for break-even + target) · Partial (closes winners and the matching fraction of the worst loser) · Average price · Profit target (closes when floating ≥ realised debt + target) · Multi-level (escalating trigger and lot).
* **Caps:** `MaximumRecoveryLevels`, `MaximumRecoveryLot`, global total lots and drawdown halt.
* **Example:** BUY 0.01 floating −$5, trigger $5 → recovery arms; positions close when the combined basket reaches the target.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableRecovery` | bool | true / false | `false` | true / false | Enable recovery |
| `InpRecoveryMode` | ENUM (ENUM_RECOVERY_MODE) | `REC_DISABLED` Disabled<br>`REC_LOT_MULT` Lot multiplier adds<br>`REC_OPPOSITE` Opposite direction recovery<br>`REC_GRID` Grid recovery (flat adds)<br>`REC_HEDGE_ZONE` Hedge / zone recovery<br>`REC_BASKET` Basket break-even target<br>`REC_PARTIAL` Partial close loser with winners<br>`REC_AVERAGE_PRICE` Average price recovery<br>`REC_PROFIT_TARGET` Realized-debt profit target<br>`REC_MULTI_LEVEL` Multi-level escalating | `REC_BASKET` | see options | Recovery mode |
| `InpRecoveryTriggerLoss` | double | - | `10.0` | 5-200 | Trigger floating loss (money) |
| `InpRecoveryMultiplier` | double | - | `1.5` | 1.2-2.0 | Lot multiplier |
| `InpRecoveryTargetMoney` | double | - | `2.0` | 0.5-20 | Net profit target to close (money) |
| `InpRecoveryStepPoints` | int | - | `300` | 200-1500 | Step / zone width (points) |
| `InpRecoveryTPPoints` | int | - | `300` | 200-1500 | Zone recovery TP distance (points) |
| `InpMaximumRecoveryLevels` | int | - | `4` | 2-6 | Max recovery levels |
| `InpMaximumRecoveryLot` | double | - | `0.50` | 0.05-1.0 | Max recovery lot per order |
| `InpRecoveryTimeoutMinutes` | int | - | `0` | 0-1440 | Close all after N minutes (0 = off) |

---

## 27 Trading Session

* **Working logic:** windows in server time or UTC (`TimeSource`; the tester uses `ServerGMTOffset`). Asian / London / New York / London + New York / custom / multiple switches / overlap (NY open to London close) / session breakout (first N minutes after each enabled open). `AvoidSessionOpening/Closing` trim the window; `CloseAtSessionEnd` closes main positions outside it; `SkipRollover` blocks 23:50–00:15 server.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableSessionFilter` | bool | true / false | `false` | true / false | Enable session filter |
| `InpTradingSessionMode` | ENUM (ENUM_SESSION_MODE) | `SESS_24H` 24-hour trading<br>`SESS_ASIAN` Asian session<br>`SESS_LONDON` London session<br>`SESS_NEWYORK` New York session<br>`SESS_LONDON_NY` London + New York<br>`SESS_CUSTOM` Custom window<br>`SESS_MULTIPLE` Multiple sessions (switches)<br>`SESS_OVERLAP` London / New York overlap<br>`SESS_BREAKOUT` First N minutes after each session open | `SESS_LONDON_NY` | see options | Session mode |
| `InpTimeSource` | ENUM (ENUM_TIME_SOURCE) | `TSRC_SERVER` Broker server time<br>`TSRC_UTC` UTC (GMT) | `TSRC_SERVER` | see options | Time reference |
| `InpServerGMTOffset` | int | - | `2` | 2-3 (broker) | Server GMT offset (tester UTC conversion) |
| `InpAsianStartHour` | int | - | `1` | - | Asian start hour |
| `InpAsianEndHour` | int | - | `9` | - | Asian end hour |
| `InpLondonStartHour` | int | - | `10` | - | London start hour |
| `InpLondonEndHour` | int | - | `19` | - | London end hour |
| `InpNYStartHour` | int | - | `15` | - | New York start hour |
| `InpNYEndHour` | int | - | `23` | - | New York end hour |
| `InpUseAsian` | bool | true / false | `false` | true / false | Multiple: Asian |
| `InpUseLondon` | bool | true / false | `true` | true / false | Multiple: London |
| `InpUseNewYork` | bool | true / false | `true` | true / false | Multiple: New York |
| `InpSessionStartHour` | int | - | `9` | - | Custom start hour |
| `InpSessionStartMinute` | int | - | `0` | - | Custom start minute |
| `InpSessionEndHour` | int | - | `21` | - | Custom end hour |
| `InpSessionEndMinute` | int | - | `0` | - | Custom end minute |
| `InpSessionBreakoutMinutes` | int | - | `60` | 30-120 | Session breakout window (minutes) |
| `InpCloseAtSessionEnd` | bool | true / false | `false` | true / false | Close positions outside session |
| `InpAvoidSessionOpening` | int | - | `0` | 0-30 | Skip first N minutes of session |
| `InpAvoidSessionClosing` | int | - | `0` | 0-30 | Skip last N minutes of session |
| `InpSkipRollover` | bool | true / false | `true` | true / false | Skip 23:50-00:15 server rollover |

---

## 28 Day Filter

* **Working logic:** per-weekday switches, Friday stop hour for new trades, and `CloseBeforeWeekend` closes everything (and deletes pendings) from the Friday close time.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableMonday` | bool | true / false | `true` | true / false | Monday |
| `InpEnableTuesday` | bool | true / false | `true` | true / false | Tuesday |
| `InpEnableWednesday` | bool | true / false | `true` | true / false | Wednesday |
| `InpEnableThursday` | bool | true / false | `true` | true / false | Thursday |
| `InpEnableFriday` | bool | true / false | `true` | true / false | Friday |
| `InpEnableSaturday` | bool | true / false | `false` | true / false | Saturday |
| `InpEnableSunday` | bool | true / false | `false` | true / false | Sunday |
| `InpFridayStopTradingHour` | int | - | `20` | 18-21 | Friday: no new trades from hour (server, -1 = off) |
| `InpCloseBeforeWeekend` | bool | true / false | `true` | true / false | Close all before weekend |
| `InpFridayCloseHour` | int | - | `22` | 21-23 | Friday close hour (server) |
| `InpFridayCloseMinute` | int | - | `30` | 0-59 | Friday close minute |

---

## 29 News Filter

* **Working logic:** MT5 economic calendar events for `NewsCurrencies` at the chosen impact, refreshed every 15 minutes; window = before/after minutes. Action: block new entries, close all, close profitable only, or delete pendings. `ManualNewsTimes` (server time, `yyyy.mm.dd hh:mi;…`) works in the tester. The volatility filter (ATR, standard deviation or average candle range in points) also lives in this group and blocks entries outside `MinimumATR`–`MaximumATR`.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableNewsFilter` | bool | true / false | `false` | true / false | Enable news filter (MT5 calendar) |
| `InpNewsImpact` | ENUM (ENUM_NEWS_IMPACT) | `NEWS_LOW` Low and above<br>`NEWS_MEDIUM` Medium and above<br>`NEWS_HIGH` High only<br>`NEWS_ALL` All events | `NEWS_HIGH` | see options | Impact level |
| `InpNewsCurrencies` | string | - | `"USD"` | - | Currencies (comma separated) |
| `InpNewsBeforeMinutes` | int | - | `30` | 15-60 | Minutes before event |
| `InpNewsAfterMinutes` | int | - | `30` | 15-60 | Minutes after event |
| `InpNewsAction` | ENUM (ENUM_NEWS_ACTION) | `NEWS_BLOCK_NEW` Block new entries<br>`NEWS_CLOSE_ALL` Close positions<br>`NEWS_CLOSE_PROFIT` Close profitable only<br>`NEWS_DELETE_PENDING` Delete pending orders | `NEWS_BLOCK_NEW` | see options | Action during news window |
| `InpManualNewsTimes` | string | - | `""` | - | Manual events (server) "yyyy.mm.dd hh:mi;..." (tester) |
| `InpEnableVolatilityFilter` | bool | true / false | `false` | true / false | Enable volatility filter |
| `InpVolatilityMode` | ENUM (ENUM_VOL_MODE) | `VOL_ATR` ATR<br>`VOL_STDDEV` Standard deviation<br>`VOL_CANDLE_RANGE` Average candle range | `VOL_ATR` | see options | Volatility measure |
| `InpVolatilityTF` | ENUM_TIMEFRAMES | timeframe | `PERIOD_M15` | M1-D1 | Volatility timeframe |
| `InpVolatilityPeriod` | int | - | `14` | 10-21 | Volatility period |
| `InpMinimumATR` | int | - | `100` | 50-300 | Min volatility (points) |
| `InpMaximumATR` | int | - | `3000` | 1500-5000 | Max volatility (points) |

---

## 30 Advanced Execution

* **Working logic:** sync/async sending; filling mode FOK/IOC/RETURN with automatic fallback to what the symbol allows; fixed or exponential retry delays (no waits in the tester); throttled SL/TP modification; pending order cap; EA-side expiry; OCO deletion of opposite pendings when one fills; stop-level and freeze-level protection.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpExecutionPolicy` | ENUM (ENUM_EXEC_POLICY) | `EPOL_SYNC` Synchronous<br>`EPOL_ASYNC` Asynchronous | `EPOL_SYNC` | see options | Execution policy |
| `InpFillingMode` | ENUM (ENUM_FILL_MODE) | `FILL_AUTO` Automatic<br>`FILL_FOK` FOK<br>`FILL_IOC` IOC<br>`FILL_RETURN` RETURN | `FILL_AUTO` | see options | Filling mode |
| `InpOrderRetryMode` | ENUM (ENUM_RETRY_MODE) | `RETRY_NONE` No retry<br>`RETRY_FIXED` Fixed delay<br>`RETRY_EXPONENTIAL` Exponential back-off | `RETRY_FIXED` | see options | Retry mode |
| `InpOrderModificationMode` | ENUM (ENUM_MODIFY_MODE) | `MOD_IMMEDIATE` Immediate<br>`MOD_THROTTLED` Throttled (min seconds + min step) | `MOD_THROTTLED` | see options | SL/TP modification mode |
| `InpModifyMinSeconds` | int | - | `2` | 1-10 | Throttle: min seconds between modifies |
| `InpModifyMinStep` | int | - | `10` | 5-50 | Throttle: min SL change (points) |
| `InpMaximumPendingOrders` | int | - | `4` | 1-10 | Max pending orders |
| `InpDeleteExpiredOrders` | bool | true / false | `true` | true / false | EA deletes expired pendings itself |
| `InpDeleteOppositePending` | bool | true / false | `true` | true / false | OCO: delete opposite pendings on fill |
| `InpRequoteHandling` | ENUM (ENUM_REQUOTE) | `REQ_RETRY` Retry with new price<br>`REQ_WIDEN` Retry with wider deviation<br>`REQ_ABORT` Abort | `REQ_RETRY` | see options | Requote handling |
| `InpFreezeLevelProtection` | bool | true / false | `true` | true / false | Respect freeze level |
| `InpStopLevelProtection` | bool | true / false | `true` | true / false | Respect stops level |

---

## 31 Account Management

* **Working logic:** auto/hedging/netting (forcing netting on a hedging account enforces one position per direction). Position scope for risk and basket: EA magic only, all on this symbol, or all positions (risk closes only). Close-all order: ticket order, losers first, winners first. Pending orders on new signals: keep, delete opposite, replace.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpAccountMode` | ENUM (ENUM_ACCOUNT_MODE) | `ACC_AUTO` Auto detect<br>`ACC_HEDGING` Hedging<br>`ACC_NETTING` Netting | `ACC_AUTO` | see options | Account mode |
| `InpPositionManagement` | ENUM (ENUM_POS_SCOPE) | `PSCOPE_EA_ONLY` EA magic only<br>`PSCOPE_SYMBOL` All on this symbol<br>`PSCOPE_ALL` All positions (risk/basket only) | `PSCOPE_EA_ONLY` | see options | Position scope (risk/basket) |
| `InpPositionCloseMode` | ENUM (ENUM_CLOSE_ORDER) | `CLOSE_ANY_ORDER` Ticket order<br>`CLOSE_LOSERS_FIRST` Largest loss first<br>`CLOSE_WINNERS_FIRST` Profitable first | `CLOSE_LOSERS_FIRST` | see options | Close-all order |
| `InpPendingOrderManagement` | ENUM (ENUM_PENDING_MGMT) | `PEND_KEEP` Keep<br>`PEND_DELETE_OPPOSITE` Delete on opposite signal<br>`PEND_REPLACE` Replace on new signal | `PEND_DELETE_OPPOSITE` | see options | Pending orders on signals |

---

## 32 Restart Recovery

* **Working logic:** state (day start, peak equity, streaks, halts, debt, partial stages, initial volumes) is kept in terminal global variables. On restart: resume management, close all EA trades, or leave existing trades unmanaged. Tester passes always start fresh.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpRestartRecoveryMode` | ENUM (ENUM_RESTART_MODE) | `RESTART_RESUME` Resume managing<br>`RESTART_CLOSE_ALL` Close EA positions<br>`RESTART_IGNORE` Ignore existing (unmanaged) | `RESTART_RESUME` | see options | On (re)start |
| `InpPersistState` | bool | true / false | `true` | true / false | Persist state in global variables |

---

## 33 Alerts & Notifications

* **Working logic:** popup, push, sound and Telegram on entries, closes and protection events (all off in the tester). Telegram needs `https://api.telegram.org` in *Tools → Options → Expert Advisors → Allow WebRequest*. Keep the bot token private and do not share `.set` files that contain it.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableAlerts` | bool | true / false | `false` | true / false | Popup alerts |
| `InpEnablePushNotification` | bool | true / false | `false` | true / false | Push notifications |
| `InpEnableSoundAlert` | bool | true / false | `false` | true / false | Sound alerts |
| `InpSoundFile` | string | - | `"alert.wav"` | - | Sound file |
| `InpEnableTelegram` | bool | true / false | `false` | true / false | Telegram (add api.telegram.org to WebRequest list) |
| `InpTelegramBotToken` | string | - | `""` | - | Telegram bot token (keep private) |
| `InpTelegramChatID` | string | - | `""` | - | Telegram chat id |

---

## 34 Chart Dashboard

* **Working logic:** balance, equity, today's realised and floating P/L, drawdown, open lots per side and per magic, streaks, last signal, halts; break-even line of the net position; next grid levels; entry arrows. Not drawn in non-visual tests.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpShowChartPanel` | bool | true / false | `true` | true / false | Show dashboard |
| `InpShowProfitPanel` | bool | true / false | `true` | true / false | Show profit lines |
| `InpShowEntryMarkers` | bool | true / false | `true` | true / false | Entry arrows |
| `InpShowSLTPLevels` | bool | true / false | `true` | true / false | Virtual SL/TP and basket lines |
| `InpShowGridLevels` | bool | true / false | `true` | true / false | Next grid level lines |
| `InpPanelX` | int | - | `10` | 0-500 | Panel X |
| `InpPanelY` | int | - | `25` | 0-500 | Panel Y |
| `InpPanelColor` | color | - | `clrWhite` | - | Panel text colour |

---

## 35 Debug & Logging

* **Working logic:** errors only / info / full debug (filter reasons, modifications, signal sources). CTrade's own log level follows this setting.

| Parameter | Type | Available modes / options | Default | Recommended range | Description |
|---|---|---|---|---|---|
| `InpEnableDebugLog` | bool | true / false | `false` | true / false | Detailed debug log |
| `InpLogLevel` | ENUM (ENUM_LOG_LEVEL) | `LOG_ERRORS` Errors only<br>`LOG_INFO` Info<br>`LOG_DEBUG` Full debug | `LOG_INFO` | see options | Log level |

---

## Appendix A: Formulas

**Risk lot** (`LOT_RISK_BALANCE / EQUITY / FREEMARGIN`, `LOT_ATR`):

```
RiskMoney  = Base × RiskPercent / 100            (Base = balance, equity or free margin)
MoneyPerLot= OrderCalcProfit(BUY, 1.0 lot, price → price + SLdistance)   (tick-value fallback)
Lot        = RiskMoney / MoneyPerLot  → floor to volume step → clamp [max(brokerMin, MinimumLot), min(brokerMax, MaximumLot)]
           → reduce until OrderCalcMargin() ≤ 90% of free margin (EnableDynamicLot) → MaximumTotalLots / volume-limit check
```

Worked example (2-digit gold, 100 oz): equity $10,000, risk 1% = $100, ATR(M15) = $4.00, SL = 1.5 × ATR = $6.00 = 600 points.
1 lot loses $600 over $6.00, so lot = 100 / 600 = 0.166 → **0.16** after flooring to step 0.01.
If the broker minimum lot would risk more than 1.5× the budget, the trade is skipped.

**Break-even price of a mixed basket** (`BASKET_WAVG`, panel line): `BE = (ΣbuyLots·buyAvg − ΣsellLots·sellAvg) / (buyLots − sellLots)`.

**Zone recovery leg size** (`REC_HEDGE_ZONE`): for the new leg at a zone edge with take-profit price `P_tp`,
`Lot = (TargetMoney − NetPL_existing(P_tp)) / MoneyPerLot(TP distance)`; `NetPL_existing` uses `OrderCalcProfit` for every open leg.

**Average-price recovery** (`REC_AVERAGE_PRICE`, `GLOT_RECOVERY`): to pull the average of `V` lots at `A` to `D` from price `P`:
`x = V × (|A − P| − D) / D`.

## Appendix B: Worst-case grid exposure (read before enabling grid)

Defaults: 5 levels, 300-point step, fixed 0.01 lot. A 3,000-point ($30) adverse move fills all 5 levels
(0.06 lots including the seed) and the floating loss is roughly
0.01 × (3000 + 2700 + 2400 + 2100 + 1800 + 1500) points ≈ **$135** at $1/point/lot. With `GLOT_MARTINGALE`
the lots are 0.01, 0.02, 0.04, 0.08, 0.16, 0.32 (0.63 lots) and the same move costs about **$1,120**.
`GridStopLossMoney` (default $100), `GridMaxDDPercent` (15%) and the global drawdown halt (10%) are what stop this. Keep them on.

## Appendix C: Starter presets (XAUUSD M15, 2-digit, $10k demo)

| Preset | Key inputs |
|---|---|
| Candle engulfing, ATR exits | `UseCandleEntry`, `CP_ENGULFING`, `SL_ATR 1.5`, `TP_RR 2.0`, `BE_PLUS 200/20`, `TRAIL_ATR 1.5`, `LOT_RISK_EQUITY 1%` |
| London breakout | `UseBreakoutEntry`, `BO_LONDON_SESSION`, `RequireCandleClose`, `SL_PREV_CANDLE`, `TP_RR 1.5`, session `LONDON` |
| SMC sniper | `UseSMCEntry`, `SMC_COMBO_SWEEP_CHOCH_OB_FVG`, `HTFStructureFilter` H4, `PD_FILTER`, `SL_STRUCTURE`, `TP_STRUCTURE` |
| Trend + MTF | `UseStrategyEntry STRAT_TREND_FOLLOWING`, `EnableMTF MTF_ALL (H1,M15,M5)`, `TRAIL_CHANDELIER` |
| Capped grid (demo only) | `EnableGrid GRID_CLASSIC`, `GSP_ATR 1.0`, `GLOT_FIXED`, 4 levels, `GTP_AVG_PRICE 300`, `GridStopLossMoney` 2% of balance |

## Appendix D: Testing blueprint

1. **Data:** Strategy Tester → *Every tick based on real ticks*, 3–5 years including 2020, 2022 and recent gold rallies, on your live broker's data.
2. **Costs:** real commission, swaps on, current spread; then repeat at 2–3× spread (60–90 points) and with *Random delay*.
3. **One module at a time:** enable a single entry module, keep exits simple (ATR SL + RR TP), then add exits, then filters.
4. **Optimise 3–5 inputs at a time**, coarse steps, genetic algorithm, criterion *Custom max* (the EA returns profit factor × recovery factor and 0 below 30 trades).
5. **Robustness:** 70/30 forward split, walk-forward; pick a stable plateau, not the single best pass.
6. **Pass/fail:** out-of-sample PF ≥ 1.3, max relative DD ≤ 15–20%, recovery factor ≥ 2, ≥ 200 trades, stable across neighbouring values.
7. **Forward:** 1–3 months demo, then a small live account (minimum lots) before scaling.

The MT5 economic calendar is not available in the Strategy Tester: use `InpManualNewsTimes` to test the news filter.
Telegram/push/sound are disabled in the tester.

*This EA is a tool, not financial advice.*
