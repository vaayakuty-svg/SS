# Universal EA Master Blueprint (XAUUSD, MT5, native MQL5)

Source: the user's *COMPLETE UNIVERSAL EA MASTER BLUEPRINT*. This file is Bot Vava's standard for
(a) **building** a universal modular EA or adding modules when the user asks, and (b) **auditing** any EA module
against the same rules (§31 compliance checklist).

> Suggested defaults and ranges are starting points for testing, not profitable settings. XAUUSD price units, points,
> ticks, contract size, spread, volume step and stop levels vary by broker.

## How to read this file

For **every** parameter the blueprint requires ten attributes. The tables give attributes 1–6 per parameter;
each section's *Behaviour* block gives 7–10 (entry, exit, risk impact, compatibility) for the whole group.

1. Name · 2. Type · 3. Modes/options · 4. Default · 5. Recommended range · 6. Working logic ·
7. Entry behaviour · 8. Exit behaviour · 9. Risk impact · 10. Compatibility

**Units (always state them):** `pts` = points (`_Point`; 2-digit gold 1 pt = 0.01, $1 move = 100 pts; 3-digit gold
$1 = 1000 pts) · `price` = gold price units ($ move) · `money` = account currency · `%` · `s` seconds · `min` · `bars`.
In code: `input` names in English with an `Inp` prefix, enums `ENUM_*` with English options, grouped with `input group`.

---

## 01. Entry modes

### A. Candle-based entry
Modes (`ENUM_CANDLE_PATTERN`): Previous Candle Bullish → Buy · Previous Candle Bearish → Sell · Two Bullish Candles → Buy ·
Two Bearish Candles → Sell · Three Candle Confirmation · Engulfing Pattern · Pin Bar · Inside Bar · Outside Bar ·
Doji Reversal · Candle High Breakout · Candle Low Breakout · Candle Body Breakout · Wick Rejection · Consecutive Candle Direction.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| CandlePatternMode | ENUM | the 15 modes above | — | — | Selects the pattern evaluated on the selected candle |
| CandleSelection | ENUM | BEFORE, NOW | BEFORE | — | BEFORE = last fully closed candle (shift 1). NOW = forming candle (shift 0): direction and signal can change before close |
| RequiredCandles | int | — | 2 | 1–5 | Candles that must agree (two/three/consecutive modes) |
| MinimumBodySize | double (price) | — | broker/strategy dependent | — | Signal candle body must be at least this size |
| MaximumWickRatio | double | — | 2 | 0.5–5 | Max wick ÷ body; filters indecision candles |
| EntryOnNewCandle | bool | — | true | — | Evaluate once when a new candle opens |
| OneTradePerCandle | bool | — | true | — | At most one entry per candle |

*Example:* previous candle bearish → buy, bullish → sell. This is a **contrarian example, not a universal rule**.
**Behaviour:** entry on the candle condition (closed-bar unless NOW). Exit is not set here (exit modules). Risk: NOW
mode repaints and can overtrade intrabar. Compatible with every exit/lot module; with NOW use tick or bar-close timing.

### B. Breakout entry
Modes (`ENUM_BREAKOUT_MODE`): Previous Candle High · Previous Candle Low · Daily High/Low · Weekly High/Low · Asian Session ·
London Session · New York Session · Range · Support/Resistance · Donchian Channel · Volatility.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| BreakoutMode | ENUM | 11 modes above | — | — | Level source |
| BreakoutBuffer | double (price) | — | 0.20 | 0–10 | Extra distance beyond the level before a break counts |
| RequireCandleClose | bool | — | true | — | Wait for a candle to close beyond the level |
| MinimumBreakoutDistance | double (price) | — | 0.10 | — | Minimum distance beyond level ± buffer |
| RetestConfirmation | bool | — | false | — | After the break, wait for price to return to the level and confirm |
| MaximumRetestBars | int (bars) | — | 5 | 1–50 | Retest window; setup cancelled afterwards |

**Behaviour:** break above the selected high → buy, below the low → sell. Signal once per level crossing (no repeats).
Risk: false breaks in ranges, slippage on stop entries. Compatible with stop orders (§05), session filter (§22).

### C. Pullback entry
Modes (`ENUM_PULLBACK_MODE`): EMA · Support/Resistance · Fibonacci Retracement · Trendline · VWAP · Breakout Retest ·
Order Block Retest · Fair Value Gap Retest.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| PullbackMode | ENUM | 8 modes above | — | — | Level price returns to |
| PullbackDistance | double (price) | — | 0.50 | 0.05–20 | Touch tolerance around the level |
| RequireRejection | bool | — | true | — | Signal candle must reject the level (wick) |
| MaximumWaitBars | int (bars) | — | 10 | 1–100 | Max bars between the impulse and the pullback |
| EntryConfirmation | ENUM | Touch, Rejection, Candle Close | — | — | Touch = level touched; Rejection = wick + close back; Candle Close = closes in trade direction beyond level |

**Behaviour:** after price moves away from a level, wait for the return and enter only on the selected confirmation.
OB/FVG retest modes use the SMC engine (§02). Risk: catching a reversal when the trend fails; use structure SL.

### D. Indicator-based entry
| Indicator | Modes | Common settings |
|---|---|---|
| EMA | Cross, Above, Below, Pullback | periods 9–200 |
| SMA | Cross, Trend | periods 10–200 |
| RSI | Overbought, Oversold, Cross | range 0–100 |
| MACD | Signal Cross, Zero Cross | 12, 26, 9 |
| Stochastic | Cross, Overbought, Oversold | 5, 3, 3 |
| Bollinger Bands | Upper, Lower, Middle Breakout | 20, 2 |
| ATR | Volatility filter | 14 |
| ADX | Trend strength | 14 |
| CCI | Overbought/Oversold | 20 |
| Ichimoku | Cloud Breakout, TK Cross | 9, 26, 52 |
| Parabolic SAR | Direction change | 0.02, 0.2 |
| VWAP | Above/Below, Reversion | session based |

| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| EnableEMAFilter | bool | false | — | EMA condition required |
| EnableRSIFilter | bool | false | — | RSI condition required |
| RSIOverbought | double | 70 | 0–100 | Sell zone / reversal level |
| RSIOversold | double | 30 | 0–100 | Buy zone / reversal level |
| EnableMACDFilter | bool | false | — | MACD condition required |
| EnableATRFilter | bool | false | — | Volatility gate |
| EnableADXFilter | bool | false | — | Trend-strength gate |
| MinimumADX | double | 20 | 0–100 | ADX must be ≥ this |

Each indicator also needs Enable, Period, Level and Timeframe inputs. **Combination must be defined:** AND,
OR, or weighted/majority. Behaviour: entry permitted only when the selected indicator conditions hold on closed bars;
handles created once in `OnInit`. Gates (ATR, ADX) only allow/block; they never give direction.

---

## 02. Smart Money Concepts (SMC)
Concepts: Order Block · Fair Value Gap · BOS · CHOCH · Buy-Side Liquidity · Sell-Side Liquidity · Liquidity Sweep ·
Inducement · Premium Zone · Discount Zone · Equilibrium · Displacement · Mitigation · Breaker Block · Mitigation Block.

| Parameter | Type | Options | Default | Working logic |
|---|---|---|---|---|
| SMCEntryMode | ENUM | OB, FVG, BOS, CHOCH, Liquidity, Hybrid | — | Primary SMC trigger; Hybrid = Sweep + CHOCH + OB + FVG |
| OrderBlockMode | ENUM | Bullish, Bearish, Both | — | Which OB zones are traded |
| FVGMode | ENUM | Bullish, Bearish, Both | — | Which FVGs are traded |
| StructureMode | ENUM | BOS, CHOCH, Both | — | Which structure events count |
| LiquidityMode | ENUM | BSL, SSL, Both | — | Which liquidity pools are watched |
| PremiumDiscountMode | ENUM | Premium, Discount, Both | — | Sell premium / buy discount / either |
| MitigationMode | ENUM | First Touch, Full Mitigation, Partial Mitigation | — | When a zone counts as used |
| DisplacementFilter | bool | — | true | OB must be followed by an impulsive candle |
| InducementFilter | bool | — | false | Require an inducement sweep first |
| SweepConfirmation | bool | — | true | Require a recent liquidity sweep |
| HTFStructureFilter | bool | — | true | Trade only with higher-timeframe structure |

Logic: bullish OB / bullish FVG = potential buy zones; bearish = sell zones. BOS = structure break; CHOCH = possible
change of character. Sweep = run beyond a prior high/low, then rejection or confirmation. Premium/discount needs a
defined dealing range and equilibrium (50%). **Recommended combined model: Liquidity Sweep + CHOCH + Order Block + FVG.**
These concepts are not standardized, so the code must define precisely: swing detection (pivot strength), zone
invalidation (close beyond far edge), minimum displacement (body ≥ k × average range) and confirmation (closed bars).
Risk: zone over-fitting; stops beyond the zone/swing.

---

## 03. Multi-timeframe confirmation
Modes: All Timeframes Confirm · Any Timeframe Confirm · Majority Confirmation · Higher Timeframe Bias ·
Lower Timeframe Entry · HTF Trend + LTF Signal.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| EnableMTF | bool | — | true | — | Turn MTF confirmation on |
| MTFMode | ENUM | 6 modes above | Majority | — | Agreement rule |
| PrimaryTF | ENUM | M1, M5, M15, M30, H1, H4, D1 | M1 | — | TF 1 |
| SecondaryTF | ENUM | same | M5 | — | TF 2 |
| ThirdTF | ENUM | same | M15 | — | TF 3 |
| FourthTF | ENUM | same | H1 | — | TF 4 |
| FifthTF | ENUM | same | H4 | — | TF 5 |
| MinimumTFConfirmations | int | — | 3 | 1–5 | Majority threshold |

All = every TF agrees; Any = at least one; Majority = more than half or the minimum; HTF bias = higher TF direction
while a lower TF triggers. *Example:* H1, M15, M5 bullish + M1 entry confirmation → buy allowed.
**Must specify closed vs forming candle per TF** (default closed). Filter only; no exits.

---

## 04. News & market-condition filters
| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| EnableNewsFilter | bool | — | false | — | Block entries around news |
| NewsImpact | ENUM | Low, Medium, High, All | High | — | Minimum impact |
| NewsBeforeMinutes | int (min) | — | 30 | 0–180 | Window before |
| NewsAfterMinutes | int (min) | — | 30 | 0–180 | Window after |
| EnableVolatilityFilter | bool | — | false | — | Volatility gate |
| VolatilityMode | ENUM | ATR, Standard Deviation, Candle Range | — | — | Measure |
| MinimumATR | double | — | strategy dependent | — | Block below |
| MaximumATR | double | — | strategy dependent | — | Block above |
| EnableSpreadFilter | bool | — | true | — | See §16 |

A **separate setting** decides whether open positions are held, reduced or closed during news. News needs the MT5
Economic Calendar (not available in the tester) or a reliable external source.

---

## 05. Entry execution modes
Modes: Market Order · Buy Stop · Sell Stop · Buy Limit · Sell Limit · Instant Entry · Tick-Based Entry · Bar Open Entry ·
Bar Close Entry · Retest Entry · Hybrid Execution.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| ExecutionMode | ENUM | Market, Pending, Hybrid | Market | — | Order style |
| PendingOrderType | ENUM | Buy Stop, Sell Stop, Buy Limit, Sell Limit | — | — | Pending type |
| EntryTiming | ENUM | Instant, Tick, Bar Open, Bar Close | — | — | When signals are evaluated |
| OrderExpiration | ENUM | GTC, Specified Time, Specified Bars | — | — | Pending lifetime |
| MaximumSlippage | int (pts) | — | 20 | broker dependent | Max deviation |
| EntryDeviation | int (pts) | — | 20 | — | Allowed distance from intended price |
| MaxOrderRetries | int | — | 3 | 0–10 | Retries on transient errors |

Market = current price. Buy Stop above / Sell Stop below price; Buy Limit below / Sell Limit above. Hybrid chooses
market or pending by configured rules. **Expiration and retry behaviour must prevent duplicate orders.**

---

## 06. Entry frequency & opposite signal
| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| OneTradePerBar | bool | true | — | One entry per bar |
| OneTradePerSignal | bool | true | — | The same signal never trades twice |
| MaximumTradesPerBar | int | 1 | 1–20 | Cap per bar |
| MaximumTradesPerSession | int | 10 | 1–100 | Cap per session |
| MinimumEntryInterval | int (s) | 60 | — | Seconds between entries |
| EnableCooldown | bool | true | — | Cooldowns on |
| CooldownAfterLoss | int (s) | 300 | — | Pause after a loss |
| CooldownAfterWin | int (s) | 0 | — | Pause after a win |
| AllowMultiplePositions | bool | false | — | Several positions at once |

**OppositeSignalMode** (ENUM): 1 Ignore · 2 Close Current Position · 3 Reverse Position · 4 Hedge Opposite Position ·
5 Close and Re-enter · 6 Close Only If Profitable · 7 Close Only If Losing · 8 Wait Until Current Trade Closes.
*Example:* BUY open, SELL signal → Ignore: BUY stays · Close: BUY closed · Reverse: BUY closed + SELL opened ·
Hedge: BUY kept + SELL opened (needs a hedging account or netting-specific handling).

---

## 07. Take profit modes
Modes: Fixed · Points · Price · Money · ATR · Risk-Reward · Structure · Basket.

| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| TakeProfitMode | ENUM | Fixed | — | Mode |
| TakeProfitPoints | double (pts) | 500 | broker dependent | Distance |
| TakeProfitPrice | double (price) | — | — | Absolute level |
| TakeProfitMoney | double (money) | 5 | — | Close at this profit |
| RiskRewardRatio | double | 2 | 0.5–20 | TP = SL distance × RR |
| ATRMultiplierTP | double | 2 | 0.5–10 | TP = ATR × mult |
| EnableTakeProfit | bool | true | — | TP on |

Fixed/points/price set a price target; money closes at the profit amount; ATR scales with volatility; RR from SL
distance; structure targets a defined S/R or liquidity level; basket closes the group at its combined target.

## 08. Stop loss modes
Modes: Fixed · Points · Price · ATR · Previous Candle · Swing High/Low · Structure · Money · Equity-Based Protection.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| StopLossMode | ENUM | modes above | Fixed | — | Mode |
| StopLossPoints | double (pts) | — | 500 | broker dependent | Distance |
| StopLossMoney | double (money) | — | 20 | — | Loss limit per position |
| ATRMultiplierSL | double | — | 1.5 | 0.5–10 | SL = ATR × mult |
| CandleSLMode | ENUM | Previous Low/High, Current Low/High | — | — | Candle reference |
| SwingSLMode | ENUM | Recent Swing, Last Confirmed Swing | — | — | Swing reference |
| EnableStopLoss | bool | — | true | — | SL on |

Buy SL below entry, sell SL above. Money/equity protection may need closing positions instead of a broker stop.
**Define whether SL is fixed at entry or recalculated.**

## 09. Trailing stop modes
Modes: Fixed · Step · ATR · Percentage · Candle · Swing · Parabolic SAR · Chandelier Exit.

| Parameter | Type | Default | Working logic |
|---|---|---|---|
| TrailingMode | ENUM | Fixed | Mode |
| EnableTrailing | bool | false | Trailing on |
| TrailingStart | double (pts) | 300 | Activation profit |
| TrailingDistance | double (pts) | 150 | Distance from price |
| TrailingStep | double (pts) | 50 | Minimum move per update |
| ATRTrailingMultiplier | double | 2 | ATR distance multiple |
| TrailingTimeframe | ENUM | M5 | TF for candle/swing/ATR/SAR |

After activation the stop follows price; buy SL only moves up, sell SL only down; never back toward loss. Respect
stop/freeze levels and throttle modifications.

## 10. Break-even modes
Modes: Fixed · Break Even Plus · ATR · Percentage · Partial.

| Parameter | Type | Default | Working logic |
|---|---|---|---|
| BreakEvenMode | ENUM | Fixed | Mode |
| EnableBreakEven | bool | false | BE on |
| BreakEvenTrigger | double (pts) | 200 | Profit that triggers |
| BreakEvenOffset | double (pts) | 20 | Lock beyond entry |
| BreakEvenAfterProfit | bool | true | Trigger only once the trade is in profit by the trigger |

*Example:* buy 2650.00, trigger 2.00 → at 2652.00 SL = 2650.00, or 2650.20 with offset. Include commission and swap
when true net break-even is required.

## 11. Partial close & multiple targets
Modes: Single Partial · TP1+TP2 · TP1+TP2+TP3 · Percentage-Based · Money-Based.

| Parameter | Type | Default | Working logic |
|---|---|---|---|
| PartialCloseMode | ENUM | — | Mode |
| EnablePartialClose | bool | false | On |
| TP1Distance / TP1ClosePercent | double (pts) / % | 300 / 30 | First target |
| TP2Distance / TP2ClosePercent | double (pts) / % | 600 / 30 | Second target |
| TP3Distance / TP3ClosePercent | double (pts) / % | 1000 / 40 | Third target |

*Example:* 0.10 lot → 30% at TP1, 30% at TP2, remaining 40% at TP3. Normalize to volume step/min volume and handle a
residual that would be invalid (close it all).

## 12. Time-based & signal-based exit
| Parameter | Type | Options | Default | Working logic |
|---|---|---|---|---|
| TimeExitMode | ENUM | Disabled, Fixed Seconds, Minutes, Bars, Session End | — | Mode |
| MaximumHoldingTime | int (s) | — | 3600 | Max position age |
| ExitAfterBars | int (bars) | — | 20 | Bars-based exit |
| ExitOnOppositeSignal | bool | — | false | Close on opposite signal |
| ExitOnTrendChange | bool | — | false | Close on trend change |
| ExitOnCandleClose | bool | — | false | Close at candle close |
| ExitAfterProfitSeconds | int (s) | — | 5 | Close after being in profit this long |

**Specify whether timers start at fill time or signal time** (default: fill time).

## 13. Basket & equity management
Modes: Money Basket TP · Percentage Basket TP · Points Basket TP · Weighted Average Exit · Equity TP · Equity SL ·
Combined Basket Protection.

| Parameter | Type | Default | Working logic |
|---|---|---|---|
| BasketExitMode | ENUM | Money | Mode |
| BasketTakeProfit | double (money) | 10 | Group target |
| BasketStopLoss | double (money) | 50 | Group loss limit |
| EquityTakeProfit | double (%) | 5 | Equity gain target |
| EquityStopLoss | double (%) | 10 | Equity loss limit |
| CloseAllOnTarget | bool | true | Close group at target |
| CloseAllOnLoss | bool | true | Close group at loss limit |
| IncludeManualTrades | bool | false | Include manual trades |

Define whether profit includes commission, swap, realized and floating P/L. Scope = magic + symbol unless configured.
*Example:* floating +$10 with BasketTakeProfit 10 → close all included positions.

---

## 14. Lot sizing modes
Modes: Fixed · Balance % Risk · Equity % Risk · Free Margin · Dynamic · Compounding · Anti-Compounding · ATR-Based ·
Volatility-Based · Martingale · Anti-Martingale · Fibonacci · Custom Sequence · Recovery-Based.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| LotMode | ENUM | 14 modes | Fixed | — | Mode |
| FixedLot | double | — | 0.01 | — | Fixed volume |
| MinimumLot | double | — | broker min | — | Lower clamp |
| MaximumLot | double | — | 1.00 | account dependent | Upper clamp |
| LotStep | double | — | broker step | — | Rounding step |
| RiskPercent | double (%) | — | 1.0 | 0.1–2 | Risk per trade |
| BalanceBase | ENUM | Balance, Equity | — | — | Base for risk/dynamic modes |
| CompoundingFactor | double | — | 1.0 | — | Compounding strength |
| EnableDynamicLot | bool | — | false | — | Dynamic adjustment on |

**Risk formula:** Risk Amount = Equity × Risk% ÷ 100; Lot = Risk Amount ÷ loss of 1 lot at the stop, using tick size,
tick value and contract specs (`OrderCalcProfit()`), then normalized to `SYMBOL_VOLUME_MIN/MAX/STEP`.
Martingale and recovery modes increase exposure and can cause rapid losses.

## 15. Risk management
| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| EnableDailyLossLimit | bool | true | — | Daily loss on |
| MaxDailyLossMoney | double (money) | e.g. 50 | account dependent | Money limit |
| MaxDailyLossPercent | double (%) | 3 | 1–5 | % limit |
| EnableMaxDrawdown | bool | true | — | DD limit on |
| MaxDrawdownPercent | double (%) | 10 | 5–20 | DD % limit |
| MaxDrawdownMoney | double (money) | account dependent | — | DD money limit |
| MaximumOpenTrades | int | 5 | — | Position cap |
| MaximumBuyPositions | int | 5 | — | Buy cap |
| MaximumSellPositions | int | 5 | — | Sell cap |
| MaximumTotalLots | double | account dependent | — | Exposure cap |
| StopTradingAfterLoss | int | 3 | — | Consecutive losses |
| StopTradingAfterWin | int | 0 | — | Wins (0 = off) |
| DailyProfitTarget | double (money) | account dependent | — | Stop after target |
| DailyTradeLimit | int | 20 | — | Entries per day |

Protection modes: Daily Money Loss · Daily % Loss · Floating Loss · Realized Loss · Combined Loss · Balance DD ·
Equity DD · Peak Equity DD · Consecutive Loss · Margin Protection. At a limit: stop new trades; a **separate option**
closes existing positions. Define the daily reset time and scope (per EA, per symbol or account-wide).

## 16. Spread & slippage protection
| Parameter | Type | Default | Working logic |
|---|---|---|---|
| EnableSpreadFilter | bool | true | On |
| MaximumSpread | double | e.g. 0.50 price units | Block above |
| MaximumSlippagePoints | int (pts) | 20 | Max slippage |
| EnableSpreadSpikeFilter | bool | true | Spike filter |
| SpreadAveragePeriod | int | 20 | Average length |
| MaximumSpreadMultiplier | double | 2.0 | Block above avg × this |
| RetryFailedOrders | bool | true | Retry on |
| RetryCount | int | 3 | Retries |
| RetryDelayMilliseconds | int (ms) | 500 | Delay |

Spread = Ask − Bid. Slippage = expected − actual fill price. Distinguish price units from points.

---

## 17. Grid trading modes
Modes: Classic · Buy · Sell · Buy & Sell · Reverse · Trend Following · Counter Trend · Hedged · Recovery · Dynamic ·
Adaptive · Candle-Based · Breakout · Zone-Based · Multi-Level.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| EnableGrid | bool | — | false | — | Grid on |
| GridMode | ENUM | 15 modes | Classic | — | Mode |
| GridDirection | ENUM | Buy, Sell, Both | — | — | Direction |
| GridStepMode | ENUM | Fixed, ATR, Percentage | — | — | Step source |
| GridStepPrice | double (price) | — | e.g. 2.00 | — | Price step |
| GridStepPoints | int (pts) | — | broker dependent | — | Point step |
| MaximumGridLevels | int | — | 5 | 1–20 | Level cap |
| MaximumGridOrders | int | — | 5 | 1–50 | Order cap |
| GridStartDistance | double (price) | — | 1.00 | — | Distance to first level |
| GridSpacingMultiplier | double | — | 1.0 | — | Step growth per level |

*Example (2.00 step):* buy levels 2650, 2648, 2646, 2644, 2642; sell levels 2650, 2652, 2654, 2656, 2658. Placement
accounts for the reference price, existing positions, spread and broker constraints. Hedged/recovery grids need
explicit exposure and loss limits.

## 18. Grid spacing modes
Modes: Fixed Price · Points · ATR · Percentage · Candle Range · Fibonacci · Dynamic · Adaptive.

| Parameter | Type | Default | Working logic |
|---|---|---|---|
| GridSpacingMode | ENUM | Fixed Price | Mode |
| FixedGridDistance | double (price) | 2.00 | Constant distance |
| ATRPeriod | int | 14 | ATR length |
| ATRGridMultiplier | double | 1.5 | ATR × mult |
| DynamicStepMinimum | double (price) | 0.10 | Minimum spacing |
| DynamicStepMaximum | double (price) | 10.0 | Maximum spacing |
| GridExpansionFactor | double | 1.0 | Growth per level |

Always enforce minimum and maximum spacing.

## 19. Grid lot progression
Modes: Fixed · Arithmetic · Geometric · Martingale · Anti-Martingale · Fibonacci · Custom Sequence · Risk-Based ·
Recovery-Based · Decreasing · Alternating · Hybrid.

| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| GridLotMode | ENUM | Fixed | — | Progression |
| InitialLot | double | 0.01 | — | Level 0 lot |
| LotMultiplier | double | 2.0 | 1–5 | Geometric/martingale factor |
| LotAddition | double | 0.01 | — | Arithmetic increment |
| MaximumLot | double | account dependent | — | Per-order cap |
| MaximumTotalLots | double | account dependent | — | Total cap |
| EnableLotCap | bool | true | — | Caps on |

Examples: Fixed 0.01→0.01→0.01→0.01 · Arithmetic 0.01→0.02→0.03→0.04 · Martingale ×2 0.01→0.02→0.04→0.08 ·
Geometric ×1.5 0.01→0.015→0.0225→0.03375 (then normalized to the volume step) · Fibonacci 0.01→0.01→0.02→0.03→0.05→0.08 ·
Custom e.g. 0.01→0.09→0.45→2.25. Normalize each lot and enforce per-order and total caps.

## 20. Hedge modes
Modes: Disabled · Full · Partial · Dynamic · Recovery · Emergency · Grid · Signal-Based · Profit Lock · Directional.

| Parameter | Type | Options | Default | Range | Working logic |
|---|---|---|---|---|---|
| EnableHedge | bool | — | false | — | On |
| HedgeMode | ENUM | 10 modes | Full Hedge | — | Mode |
| HedgeTriggerLoss | double (money) | — | — | — | Loss that triggers |
| HedgeLotMode | ENUM | Equal Lot, Multiplier, Percentage, Fixed | — | — | Hedge size rule |
| HedgeLotMultiplier | double | — | 1.0 | — | Multiplier |
| HedgePercentage | double (%) | — | 50 | 1–100 | Percentage |
| MaximumHedgePositions | int | — | 2 | — | Cap |
| AllowMultipleHedges | bool | — | false | — | Several hedges |

*Example:* BUY 0.10 → full hedge SELL 0.10, partial SELL 0.05. A hedge does not erase the loss; spread, commission,
swap and margin remain. Confirm the account supports hedging.

## 21. Recovery modes
Modes: Disabled · Lot Multiplier · Opposite Direction · Grid · Hedge · Basket · Partial · Average Price · Profit Target ·
Multi-Level.

| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| EnableRecovery | bool | false | — | On |
| RecoveryMode | ENUM | Basket Recovery | — | Mode |
| RecoveryTriggerLoss | double (money) | e.g. 20 | — | Activation loss |
| RecoveryMultiplier | double | 1.5 | 1–3 | Lot growth |
| RecoveryTargetMoney | double (money) | e.g. 5 | — | Close basket at this net |
| MaximumRecoveryLevels | int | 3 | 1–10 | Level cap |
| MaximumRecoveryLot | double | account dependent | — | Lot cap |
| RecoveryTimeoutMinutes | int (min) | 120 | — | Give-up time |

*Example:* BUY 0.01 at −$5 with trigger $5 → recovery activates; close the basket at the target. Enforce exposure,
margin, drawdown and timeout limits. **Recovery is not guaranteed.**

---

## 22. Session & time filters
Modes: 24-Hour · Asian · London · New York · London + New York · Custom · Multiple · Overlap · Session Breakout.

| Parameter | Type | Default | Range | Working logic |
|---|---|---|---|---|
| EnableSessionFilter | bool | false | — | On |
| TradingSessionMode | ENUM | 24 Hours | — | Mode |
| SessionStartHour | int | — | 0–23 | Custom start hour |
| SessionStartMinute | int | — | 0–59 | Custom start minute |
| SessionEndHour | int | — | 0–23 | Custom end hour |
| SessionEndMinute | int | — | 0–59 | Custom end minute |
| CloseAtSessionEnd | bool | false | — | Close at end |
| AvoidSessionOpening | int (min) | 0 | — | Skip first minutes |
| AvoidSessionClosing | int (min) | 0 | — | Skip last minutes |

Times in broker server time or UTC; handle daylight saving. Specify whether session end only blocks entries or also closes.

## 23. Day-of-week filter
| Parameter | Type | Default |
|---|---|---|
| EnableMonday | bool | true |
| EnableTuesday | bool | true |
| EnableWednesday | bool | true |
| EnableThursday | bool | true |
| EnableFriday | bool | true |
| EnableSaturday | bool | false |
| EnableSunday | bool | false |
| CloseBeforeWeekend | bool | true |
| FridayStopTradingHour | int | 20 |

Use broker trading hours; do not assume every broker closes at the same time.

## 24. General EA settings
| Parameter | Type | Default |
|---|---|---|
| MagicNumber | ulong | unique per EA |
| TradeComment | string | "Gold EA" |
| EnableBuy / EnableSell / EnableTrading | bool | true |
| EnableAlerts | bool | true |
| EnablePushNotification / EnableSoundAlert | bool | false |
| ShowChartPanel / ShowProfitPanel / ShowEntryMarkers / ShowSLTPLevels / ShowGridLevels | bool | true |
| EnableDebugLog | bool | false |

## 25. Account & position management
| Parameter | Type | Options | Working logic |
|---|---|---|---|
| AccountMode | ENUM | Hedging, Netting, Auto Detect | Position model |
| PositionManagement | ENUM | EA Only, Symbol Only, All Positions | Scope |
| TradeDirection | ENUM | Both, Buy Only, Sell Only | Allowed directions |
| PositionCloseMode | ENUM | Individual, Basket, All | Close grouping |
| PendingOrderManagement | ENUM | EA Only, Symbol Only, All | Pending scope |
| RestartRecoveryMode | ENUM | Restore, Recalculate, Start Fresh | Behaviour after restart |

EA Only = own magic + symbol. All Positions affects manual trades and other EAs, so it requires explicit selection.
Netting and hedging accounts need different handling.

## 26. Advanced order execution
| Parameter | Type | Options | Default |
|---|---|---|---|
| ExecutionPolicy | ENUM | FOK, IOC, RETURN, Auto | — |
| FillingMode | ENUM | Auto, FOK, IOC, RETURN | — |
| OrderRetryMode | ENUM | None, Fixed Delay, Exponential | — |
| OrderModificationMode | ENUM | Immediate, Throttled | — |
| MaximumPendingOrders | int | — | 10 |
| DeleteExpiredOrders | bool | — | true |
| DeleteOppositePending | bool | — | true |
| RequoteHandling | ENUM | Retry, Skip, Recalculate | — |
| FreezeLevelProtection | bool | — | true |
| StopLevelProtection | bool | — | true |

Only broker-supported filling modes. On requote/rejection follow the retry policy and **revalidate price, volume,
margin and stops**; prevent duplicate orders during retries.

## 27. Advanced trading strategies
Trend Following · Counter Trend · Mean Reversion · Momentum · Scalping · Swing · Breakout Retest · Reversal ·
Continuation · Range · Volatility · Liquidity · Statistical · Arbitrage.
Each needs its own explicit entry, exit and risk rules; **a dropdown label alone does not implement a strategy.**
Arbitrage additionally needs multiple price feeds/venues and realistic execution assumptions.

## 28. Dashboard & Telegram alerts
Dashboard · Balance · Equity · Daily Profit · Daily Loss · Floating Profit · Open Positions · Grid Levels · Entry Arrows ·
SL/TP Lines · Trading Status · Telegram · Push · Sound · Debug Logs. Telegram needs a bot token and chat ID; store
them securely and never print them in logs or shared source.

## 29. Master input group structure
GROUP 01 General · 02 Trading Direction · 03 Entry Strategy Selection · 04 Candle Entry · 05 Breakout Entry ·
06 Pullback Entry · 07 Indicators · 08 SMC · 09 Multi-Timeframe · 10 Entry Execution · 11 Exit Strategy Selection ·
12 Take Profit · 13 Stop Loss · 14 Trailing Stop · 15 Break Even · 16 Partial Close · 17 Basket · 18 Lot Sizing ·
19 Risk Management · 20 Drawdown Protection · 21 Spread & Slippage · 22 Grid · 23 Grid Lot Progression ·
24 Martingale · 25 Hedge · 26 Recovery · 27 Trading Session · 28 Day Filter · 29 News Filter · 30 Advanced Execution ·
31 Account Management · 32 Restart Recovery · 33 Alerts & Notifications · 34 Chart Dashboard · 35 Debug & Logging.

## 30. Final development requirements
1 Native MQL5 · 2 CTrade where appropriate · 3 Modular architecture · 4 Independent entry and exit modules ·
5 Selectable ENUM inputs · 6 English input names · 7 English dropdown options · 8 Clear grouping ·
9 Hedging compatibility · 10 Netting compatibility · 11 XAUUSD price/point conversion · 12 Broker lot validation ·
13 Margin validation · 14 Stop-level validation · 15 Freeze-level validation · 16 Duplicate-trade protection ·
17 Restart recovery · 18 Error handling · 19 Debug logging · 20 Strategy Tester compatibility ·
21 Optimization compatibility · 22 Independent backtesting of every mode.

**Development rules:** every mode has real working code · no contradictory modes at the same time · entry, exit and
lot sizing independently selectable · a disabled mode is genuinely inactive · risk protection applies to every
module · max lot, max exposure and max drawdown enforced · each strategy independently testable · broker errors handled ·
backtests include spread, commission, swap and realistic execution · all units documented (points, ticks, price
units, account currency, seconds, bars, percentages).

**Final objective:** a professional universal modular XAUUSD EA where Entry Strategy, Entry Execution, Exit Strategy,
TP/SL, Trailing, Lot Calculation, Risk Management, Grid, Martingale, Hedge, Recovery, Sessions and MTF are each
selectable in the Inputs tab, and changing one module never changes an unrelated one. Deliver complete MQL5 with
exact rules, parameters, defaults, ranges, compatibility rules and risk implications; never pseudocode only.

---

## 31. Blueprint compliance checklist (Bot Vava audit)

For each blueprint module **present in the EA**, mark PASS / PARTIAL / FAIL / ABSENT. ABSENT modules are reported,
not added, unless the user asks to build or extend (Blueprint mode in SKILL.md).

| # | Check | PASS when |
|---|---|---|
| BP1 | Real code per mode | Every enum option reached in a `switch` with distinct logic; no empty cases or label-only modes |
| BP2 | Disabled = inactive | A disabled module creates no handles, runs no logic and opens no trades |
| BP3 | Independence | Changing one module's input does not change another module's maths (no shared hidden globals) |
| BP4 | No contradictory modes | `OnInit` rejects or warns on conflicts (grid + adding recovery, two hedging engines, hedge on netting) |
| BP5 | Units | Points vs price vs money documented per input; 2/3-digit gold handled via `_Point`/tick size |
| BP6 | Closed-candle rule | Each module and each MTF timeframe states closed vs forming candle |
| BP7 | Lot validation | Volume step/min/max, `OrderCalcMargin`, max lot and max total lots |
| BP8 | Stop/freeze levels | Checked on open and on every modify |
| BP9 | Duplicate protection | One-trade-per-bar/signal, retry without duplicates, pending expiry |
| BP10 | Risk everywhere | Daily loss, drawdown and exposure caps checked before every new position, including grid/hedge/recovery adds |
| BP11 | Account model | Hedging vs netting detected; hedge/grid disabled or adapted on netting |
| BP12 | Restart | State rebuilt from positions/global variables per RestartRecoveryMode |
| BP13 | Errors & logging | Every trade call result checked; retcode + description logged; debug log switch |
| BP14 | Tester & optimization | Works in the tester (no calendar dependence without fallback); `OnTester` or a sensible criterion |
| BP15 | Independent backtests | Each entry module can run alone |
| BP16 | Costs | Backtest plan uses spread, commission, swap and realistic execution |
| BP17 | Specification gaps resolved | SMC definitions, MTF candle state, timer start (fill vs signal), basket P/L composition, daily reset time and limit scope are stated in code comments |
| BP18 | Credentials | Telegram token/chat id never logged or hard-coded |
| BP19 | Input structure | English names, `input group` order 01–35, ENUM dropdowns with English options |

## 32. Reference implementation

`Experts/UniversalGoldEA/` in the user's repository implements this blueprint (35 groups, 407 inputs; full table in
`docs/UniversalGoldEA_Reference.md`). Where that EA's names or defaults differ from this file, **this file is the
specification** and the EA is the reference to compare against. Known differences to reconcile when the user asks:
SMC enum shapes (blueprint: Bullish/Bearish/Both per zone type), MTF default timeframes (M1…H4, Majority),
OrderExpiration (GTC/Specified Time/Specified Bars), BalanceBase (Balance/Equity), BreakEvenAfterProfit (bool),
HedgeLotMode (adds Fixed), RequoteHandling (Retry/Skip/Recalculate), RestartRecoveryMode (Restore/Recalculate/Start Fresh),
PositionCloseMode (Individual/Basket/All), PendingOrderManagement scope (EA Only/Symbol Only/All), defaults given in
price units (e.g. BreakoutBuffer 0.20) and cooldowns in seconds.
