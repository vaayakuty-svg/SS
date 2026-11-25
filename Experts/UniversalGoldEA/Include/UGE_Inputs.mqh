//+------------------------------------------------------------------+
//|                                                 UGE_Inputs.mqh   |
//|  Universal Gold EA - all user inputs, grouped 01..35.            |
//|  Distances are in POINTS unless the name says Price/Money/%.     |
//|  XAUUSD 2-digit: 1 point = 0.01 ($1 move = 100 points).          |
//|  XAUUSD 3-digit: 1 point = 0.001 ($1 move = 1000 points).        |
//|  Price inputs ("...Price" / FIXED modes) are in $ of gold price  |
//|  and are converted with _Point, so they work on both.            |
//+------------------------------------------------------------------+

//==================================================================
input group "=== 01 General Settings ==="
input ulong   InpMagicNumber        = 77001;        // Magic number (main trades; +1 grid, +2 hedge, +3 recovery)
input string  InpTradeComment       = "UGE";        // Trade comment (info only, max 31 chars)
input bool    InpEnableTrading      = true;         // Master switch: allow NEW trades
input bool    InpEnableBuy          = true;         // Allow buy entries
input bool    InpEnableSell         = true;         // Allow sell entries

//==================================================================
input group "=== 02 Trading Direction ==="
input ENUM_TRADE_DIRECTION InpTradeDirection = DIR_BOTH;   // Direction mode
input ENUM_TIMEFRAMES      InpDirectionTF    = PERIOD_H1;  // Auto-trend timeframe
input int                  InpDirectionEMA   = 200;        // Auto-trend EMA period

//==================================================================
input group "=== 03 Entry Strategy Selection ==="
input bool    InpUseCandleEntry     = true;          // Module: Candle-based entry
input bool    InpUseBreakoutEntry   = false;         // Module: Breakout entry
input bool    InpUsePullbackEntry   = false;         // Module: Pullback entry
input bool    InpUseIndicatorEntry  = false;         // Module: Indicator entry
input bool    InpUseSMCEntry        = false;         // Module: Smart Money Concepts entry
input bool    InpUseStrategyEntry   = false;         // Module: Advanced strategy preset
input ENUM_ENTRY_COMBINE InpEntryCombine = COMBINE_ALL_AGREE; // How enabled modules combine
input ENUM_STRATEGY      InpStrategyMode = STRAT_TREND_FOLLOWING; // Advanced strategy preset
input ENUM_TIMEFRAMES    InpStrategyTF   = PERIOD_M15;  // Strategy preset timeframe
input string  InpArbSymbol          = "XAGUSD";      // Arbitrage: paired symbol (ratio z-score)
input int     InpStatPeriod         = 50;            // Statistical/Arbitrage: z-score period
input double  InpStatZEntry         = 2.0;           // Statistical/Arbitrage: entry |z| threshold

//==================================================================
input group "=== 04 Candle Entry Settings ==="
input ENUM_CANDLE_PATTERN   InpCandlePatternMode = CP_ENGULFING; // Candle pattern mode
input ENUM_CANDLE_SELECTION InpCandleSelection   = CANDLE_BEFORE; // Candle: BEFORE (closed) / NOW (forming)
input ENUM_TIMEFRAMES       InpCandleTF          = PERIOD_M15;  // Candle timeframe
input int     InpRequiredCandles    = 3;             // Required candles (consecutive mode)
input int     InpMinimumBodySize    = 50;            // Minimum body size (points), 0 = off
input double  InpMaximumWickRatio   = 0.70;          // Max wick/range ratio for colour modes (0-1)
input double  InpPinBarRatio        = 2.0;           // Pin bar: tail >= ratio x body
input double  InpDojiBodyRatio      = 0.10;          // Doji: body <= ratio x range
input double  InpWickRejectRatio    = 0.50;          // Wick rejection: tail >= ratio x range
input bool    InpEntryOnNewCandle   = true;          // Evaluate only on a new candle
input bool    InpOneTradePerCandle  = true;          // Max one entry per candle

//==================================================================
input group "=== 05 Breakout Entry Settings ==="
input ENUM_BREAKOUT_MODE InpBreakoutMode = BO_PREV_CANDLE_HL; // Breakout mode
input ENUM_TIMEFRAMES    InpBreakoutTF   = PERIOD_M15;  // Breakout timeframe
input int     InpBreakoutBuffer     = 30;            // Buffer beyond level (points)
input bool    InpRequireCandleClose = true;          // Require candle CLOSE beyond level
input int     InpMinBreakoutDistance= 0;             // Min distance beyond level (points)
input bool    InpRetestConfirmation = false;         // Wait for retest of broken level
input int     InpMaximumRetestBars  = 6;             // Max bars to wait for retest
input int     InpRangeBars          = 20;            // Range/Donchian bars
input int     InpMaxRangePoints     = 1500;          // Range mode: max range height (points)
input double  InpVolBreakoutK       = 0.5;           // Volatility breakout: k x daily ATR
input int     InpAsianRangeMinutes  = 60;            // Asian breakout: opening range minutes

//==================================================================
input group "=== 06 Pullback Entry Settings ==="
input ENUM_PULLBACK_MODE InpPullbackMode   = PB_EMA;  // Pullback mode
input ENUM_TIMEFRAMES    InpPullbackTF     = PERIOD_M15; // Pullback timeframe
input int     InpPullbackEMAPeriod  = 50;            // Pullback EMA period
input int     InpPullbackDistance   = 100;           // Touch tolerance around level (points)
input bool    InpRequireRejection   = true;          // Signal candle must show rejection wick
input int     InpMaximumWaitBars    = 20;            // Impulse must be within N bars
input ENUM_ENTRY_CONFIRM InpEntryConfirmation = CONF_CLOSE_DIR; // Entry confirmation
input double  InpFiboMin            = 0.50;          // Fibonacci zone min (0.5 = 50%)
input double  InpFiboMax            = 0.618;         // Fibonacci zone max
input int     InpSwingBars          = 3;             // Swing pivot strength (bars each side)

//==================================================================
input group "=== 07 Indicator Settings ==="
input ENUM_TIMEFRAMES InpIndTF      = PERIOD_M15;    // Indicator timeframe (all indicators)
input int     InpIndMinVotes        = 1;             // Min directional indicator votes required
input bool    InpUseEMA             = true;          // EMA: enable
input ENUM_IND_LOGIC InpEMALogic    = ILOGIC_CROSS;  // EMA: logic (Cross/Level=price vs slow/Trend=slope)
input int     InpEMAFast            = 20;            // EMA: fast period
input int     InpEMASlow            = 50;            // EMA: slow period
input bool    InpUseSMA             = false;         // SMA: enable
input ENUM_IND_LOGIC InpSMALogic    = ILOGIC_TREND;  // SMA: logic
input int     InpSMAFast            = 50;            // SMA: fast period
input int     InpSMASlow            = 200;           // SMA: slow period
input bool    InpUseRSI             = false;         // RSI: enable
input ENUM_IND_LOGIC InpRSILogic    = ILOGIC_OBOS;   // RSI: logic (OBOS/Level=50 cross/Trend/Momentum)
input int     InpRSIPeriod          = 14;            // RSI: period
input double  InpRSIOverbought      = 70.0;          // RSI: overbought level
input double  InpRSIOversold        = 30.0;          // RSI: oversold level
input bool    InpUseMACD            = false;         // MACD: enable
input ENUM_IND_LOGIC InpMACDLogic   = ILOGIC_CROSS;  // MACD: logic (Cross=signal/Level=zero/Momentum=hist)
input int     InpMACDFast           = 12;            // MACD: fast EMA
input int     InpMACDSlow           = 26;            // MACD: slow EMA
input int     InpMACDSignal         = 9;             // MACD: signal period
input bool    InpUseStoch           = false;         // Stochastic: enable
input ENUM_IND_LOGIC InpStochLogic  = ILOGIC_OBOS;   // Stochastic: logic
input int     InpStochK             = 14;            // Stochastic: %K
input int     InpStochD             = 3;             // Stochastic: %D
input int     InpStochSlowing       = 3;             // Stochastic: slowing
input double  InpStochOverbought    = 80.0;          // Stochastic: overbought
input double  InpStochOversold      = 20.0;          // Stochastic: oversold
input bool    InpUseBB              = false;         // Bollinger: enable
input ENUM_IND_LOGIC InpBBLogic     = ILOGIC_OBOS;   // Bollinger: logic (OBOS=reversion/Cross=breakout/Trend=mid)
input int     InpBBPeriod           = 20;            // Bollinger: period
input double  InpBBDeviation        = 2.0;           // Bollinger: deviation
input bool    InpUseATRInd          = false;         // ATR: enable (volatility gate)
input int     InpATRIndPeriod       = 14;            // ATR: period
input int     InpATRIndMinPoints    = 100;           // ATR: minimum (points)
input int     InpATRIndMaxPoints    = 3000;          // ATR: maximum (points)
input bool    InpUseADX             = false;         // ADX: enable
input ENUM_IND_LOGIC InpADXLogic    = ILOGIC_TREND;  // ADX: logic (Trend=DI direction / Volatility=gate)
input int     InpADXPeriod          = 14;            // ADX: period
input double  InpADXLevel           = 20.0;          // ADX: minimum trend strength
input bool    InpUseCCI             = false;         // CCI: enable
input ENUM_IND_LOGIC InpCCILogic    = ILOGIC_OBOS;   // CCI: logic
input int     InpCCIPeriod          = 20;            // CCI: period
input double  InpCCILevel           = 100.0;         // CCI: +/- level
input bool    InpUseIchimoku        = false;         // Ichimoku: enable
input ENUM_IND_LOGIC InpIchiLogic   = ILOGIC_TREND;  // Ichimoku: logic (Cross=TK cross / Trend=cloud)
input int     InpIchiTenkan         = 9;             // Ichimoku: Tenkan
input int     InpIchiKijun          = 26;            // Ichimoku: Kijun
input int     InpIchiSenkouB        = 52;            // Ichimoku: Senkou B
input bool    InpUseSAR             = false;         // Parabolic SAR: enable
input ENUM_IND_LOGIC InpSARLogic    = ILOGIC_CROSS;  // SAR: logic (Cross=flip / Trend=side)
input double  InpSARStep            = 0.02;          // SAR: step
input double  InpSARMax             = 0.2;           // SAR: maximum
input bool    InpUseVWAP            = false;         // VWAP (daily, tick volume): enable
input ENUM_IND_LOGIC InpVWAPLogic   = ILOGIC_TREND;  // VWAP: logic (Cross / Trend=side)

//==================================================================
input group "=== 08 SMC Settings ==="
input ENUM_SMC_ENTRY  InpSMCEntryMode       = SMC_COMBO_SWEEP_CHOCH_OB_FVG; // SMC entry mode
input ENUM_TIMEFRAMES InpSMCTF              = PERIOD_M15;  // SMC timeframe
input ENUM_OB_MODE    InpOrderBlockMode     = OB_BODY;     // Order block zone definition
input ENUM_FVG_MODE   InpFVGMode            = FVG_EDGE;    // FVG entry level
input ENUM_STRUCT_MODE InpStructureMode     = STRUCT_CLOSE; // Structure break confirmation
input ENUM_LIQ_MODE   InpLiquidityMode      = LIQ_SWING;   // Liquidity pool definition
input ENUM_PD_MODE    InpPremiumDiscountMode= PD_FILTER;   // Premium / discount filter
input ENUM_MIT_MODE   InpMitigationMode     = MIT_FIRST_TOUCH; // Zone mitigation rule
input bool    InpDisplacementFilter = true;          // OB must be followed by displacement
input double  InpDisplacementATR    = 1.2;           // Displacement: body >= x avg range
input bool    InpInducementFilter   = false;         // Require inducement sweep before entry
input bool    InpSweepConfirmation  = false;         // Require recent liquidity sweep
input bool    InpHTFStructureFilter = true;          // Trade only with HTF structure
input ENUM_TIMEFRAMES InpSMCHTF     = PERIOD_H4;     // HTF structure timeframe
input int     InpSMCSwingLen        = 3;             // Swing pivot strength (bars each side)
input int     InpSMCLookback        = 300;           // Bars analysed
input int     InpSMCMaxSetupBars    = 30;            // Max age of sweep/CHOCH for combo (bars)
input int     InpFVGMinPoints       = 50;            // Min FVG size (points)
input int     InpEqualHLTolerance   = 50;            // Equal highs/lows tolerance (points)

//==================================================================
input group "=== 09 Multi-Timeframe Settings ==="
input bool    InpEnableMTF          = false;         // Enable MTF confirmation
input ENUM_MTF_MODE   InpMTFMode    = MTF_ALL;       // MTF mode
input ENUM_MTF_METHOD InpMTFMethod  = MTFM_PRICE_VS_EMA; // Bias method per TF
input int     InpMTFCount           = 3;             // Number of TFs used (1-5)
input ENUM_TIMEFRAMES InpPrimaryTF  = PERIOD_H1;     // TF 1 (highest / primary)
input ENUM_TIMEFRAMES InpSecondaryTF= PERIOD_M15;    // TF 2
input ENUM_TIMEFRAMES InpThirdTF    = PERIOD_M5;     // TF 3
input ENUM_TIMEFRAMES InpFourthTF   = PERIOD_M1;     // TF 4
input ENUM_TIMEFRAMES InpFifthTF    = PERIOD_M1;     // TF 5
input int     InpMTFEMAPeriod       = 50;            // EMA period for bias
input int     InpMinimumTFConfirmations = 2;         // Majority mode: min confirmations

//==================================================================
input group "=== 10 Entry Execution Settings ==="
input ENUM_EXEC_MODE    InpExecutionMode = EXEC_MARKET;      // Execution mode
input ENUM_ENTRY_TIMING InpEntryTiming   = TIMING_BAR_OPEN;  // Entry timing
input int     InpBarCloseSeconds    = 10;            // Bar close: seconds before close
input int     InpTimerSeconds       = 5;             // Timer timing: interval seconds
input int     InpPendingOffset      = 100;           // Pending order offset (points)
input int     InpOrderExpirationMin = 60;            // Pending expiry (minutes, 0 = GTC)
input int     InpMaximumSlippage    = 30;            // Max slippage / deviation (points)
input int     InpHybridMaxDistance  = 50;            // Hybrid: market if within (points)
input int     InpMaxOrderRetries    = 3;             // Max order retries

//==================================================================
input group "=== 06b Entry Frequency & Opposite Signal ==="
input bool    InpOneTradePerBar     = true;          // One trade per bar (chart TF)
input bool    InpOneTradePerSignal  = true;          // One trade per signal
input int     InpMaxTradesPerBar    = 1;             // Max trades per bar
input int     InpMaxTradesPerSession= 10;            // Max trades per day/session
input int     InpMinEntryInterval   = 0;             // Min seconds between entries
input bool    InpEnableCooldown     = false;         // Enable cooldown
input int     InpCooldownAfterLoss  = 30;            // Cooldown after loss (minutes)
input int     InpCooldownAfterWin   = 0;             // Cooldown after win (minutes)
input bool    InpAllowMultiplePositions = false;     // Allow multiple main positions
input int     InpMaxMainPositions   = 3;             // Max main positions (if multiple)
input ENUM_OPPOSITE_MODE InpOppositeSignalMode = OPP_IGNORE; // Opposite signal handling

//==================================================================
input group "=== 11 Exit Strategy Selection ==="
input ENUM_TIME_EXIT InpTimeExitMode = TEXIT_OFF;    // Time-based exit
input int     InpMaximumHoldingTime = 240;           // Seconds/Minutes value for time exit
input int     InpExitAfterBars      = 20;            // Bars-based exit
input int     InpExitAfterProfitSeconds = 300;       // Profit-time exit: seconds
input bool    InpTimeExitOnlyProfit = false;         // Time exit only if in profit
input bool    InpExitOnOppositeSignal = false;       // Exit on opposite signal
input bool    InpExitOnTrendChange  = false;         // Exit when Direction-TF EMA trend flips
input bool    InpExitOnCandleClose  = false;         // Exit at close of entry candle

//==================================================================
input group "=== 12 Take Profit Settings ==="
input bool    InpEnableTakeProfit   = true;          // Enable take profit
input ENUM_TP_MODE InpTakeProfitMode= TP_RR;         // Take profit mode
input double  InpTakeProfitFixed    = 10.0;          // Fixed TP distance ($ of price)
input int     InpTakeProfitPoints   = 1000;          // TP (points)
input double  InpTakeProfitPrice    = 0.0;           // Absolute TP price
input double  InpTakeProfitMoney    = 20.0;          // Money TP per position
input double  InpATRMultiplierTP    = 3.0;           // ATR x for TP
input double  InpRiskRewardRatio    = 2.0;           // Risk:Reward ratio
input int     InpATRPeriod          = 14;            // Core ATR period (SL/TP/BE/grid)
input ENUM_TIMEFRAMES InpATRTF      = PERIOD_M15;    // Core ATR timeframe

//==================================================================
input group "=== 13 Stop Loss Settings ==="
input bool    InpEnableStopLoss     = true;          // Enable stop loss
input ENUM_SL_MODE InpStopLossMode  = SL_ATR;        // Stop loss mode
input double  InpStopLossFixed      = 5.0;           // Fixed SL distance ($ of price)
input int     InpStopLossPoints     = 500;           // SL (points)
input double  InpStopLossPrice      = 0.0;           // Absolute SL price
input double  InpStopLossMoney      = 10.0;          // Money SL per position
input double  InpATRMultiplierSL    = 1.5;           // ATR x for SL
input ENUM_CANDLE_SL InpCandleSLMode= CSL_WICK;      // Previous candle SL: wick/body
input ENUM_SWING_SL  InpSwingSLMode = SSL_LOOKBACK;  // Swing SL method
input int     InpSwingSLBars        = 10;            // Swing SL lookback bars
input int     InpSLBuffer           = 30;            // Buffer beyond candle/swing (points)
input int     InpMinSLPoints        = 150;           // Min SL distance (points)
input int     InpMaxSLPoints        = 3000;          // Max SL distance (points)
input int     InpNoSLFallbackPoints = 1000;          // Risk sizing distance if no SL (points)

//==================================================================
input group "=== 14 Trailing Stop Settings ==="
input bool    InpEnableTrailing     = true;          // Enable trailing
input ENUM_TRAIL_MODE InpTrailingMode = TRAIL_ATR;   // Trailing mode
input int     InpTrailingStart      = 300;           // Start after profit (points)
input int     InpTrailingDistance   = 250;           // Distance / buffer (points)
input int     InpTrailingStep       = 50;            // Step (points)
input double  InpATRTrailingMultiplier = 1.5;        // ATR x for ATR/Chandelier
input double  InpTrailingPercent    = 50.0;          // Percent: keep % of profit
input ENUM_TIMEFRAMES InpTrailingTimeframe = PERIOD_M15; // Candle/swing/SAR/ATR trail TF
input int     InpChandelierBars     = 22;            // Chandelier lookback

//==================================================================
input group "=== 15 Break Even Settings ==="
input bool    InpEnableBreakEven    = true;          // Enable break even
input ENUM_BE_MODE InpBreakEvenMode = BE_PLUS;       // Break even mode
input int     InpBreakEvenTrigger   = 200;           // Trigger (points)
input int     InpBreakEvenOffset    = 20;            // Lock offset (points)
input double  InpBreakEvenATR       = 1.0;           // ATR trigger multiple
input double  InpBreakEvenPercent   = 50.0;          // % of TP distance trigger
input double  InpBreakEvenAfterProfit = 0.0;         // Also trigger at money profit (0 = off)

//==================================================================
input group "=== 16 Partial Close Settings ==="
input bool    InpEnablePartialClose = false;         // Enable partial close
input ENUM_PARTIAL_MODE InpPartialCloseMode = PC_TP1_TP2; // Partial mode
input double  InpTP1Distance        = 300;           // TP1 (points / % / money by mode)
input double  InpTP1ClosePercent    = 50;            // TP1 close % of initial volume
input double  InpTP2Distance        = 600;           // TP2
input double  InpTP2ClosePercent    = 30;            // TP2 close %
input double  InpTP3Distance        = 900;           // TP3
input double  InpTP3ClosePercent    = 20;            // TP3 close % (remaining is closed at TP3)

//==================================================================
input group "=== 17 Basket Management ==="
input ENUM_BASKET_MODE  InpBasketExitMode = BASKET_OFF; // Basket exit mode
input ENUM_BASKET_SCOPE InpBasketScope    = BSCOPE_ALL; // Basket scope
input double  InpBasketTakeProfit   = 10.0;          // Basket TP (money / % / points)
input double  InpBasketStopLoss     = 0.0;           // Basket SL (money / % / points, 0 = off)
input double  InpEquityTakeProfit   = 0.0;           // Equity TP: day-start equity + X (0 = off)
input double  InpEquityStopLoss     = 0.0;           // Equity SL: day-start equity - X (0 = off)
input bool    InpCloseAllOnTarget   = true;          // Close basket on target
input bool    InpCloseAllOnLoss     = true;          // Close basket on loss
input bool    InpIncludeManualTrades= false;         // Include manual trades (magic 0, this symbol)

//==================================================================
input group "=== 18 Lot Sizing Settings ==="
input ENUM_LOT_MODE InpLotMode      = LOT_RISK_EQUITY; // Lot mode
input double  InpFixedLot           = 0.01;          // Fixed / base lot
input double  InpMinimumLot         = 0.01;          // Minimum lot (EA cap)
input double  InpMaximumLot         = 1.00;          // Maximum lot per order (EA cap)
input double  InpLotStep            = 0.0;           // Lot step override (0 = broker)
input double  InpRiskPercent        = 1.0;           // Risk % per trade
input double  InpBalanceBase        = 1000.0;        // Balance base for dynamic/compounding
input double  InpCompoundingFactor  = 1.0;           // Compounding exponent
input bool    InpEnableDynamicLot   = true;          // Reduce lot to fit free margin
input string  InpCustomLotSequence  = "0.01,0.02,0.03,0.05,0.08"; // Custom lot sequence
input double  InpRecoveryLotTarget  = 5.0;           // Recovery lot: extra profit target (money)

//==================================================================
input group "=== 19 Risk Management ==="
input bool    InpEnableDailyLossLimit = true;        // Enable daily loss limit
input double  InpMaxDailyLossMoney  = 0.0;           // Max daily loss money (0 = off)
input double  InpMaxDailyLossPercent= 3.0;           // Max daily loss % of day-start balance
input ENUM_LOSS_BASIS InpLossBasis  = LOSS_COMBINED; // Daily loss basis
input double  InpDailyProfitTarget  = 0.0;           // Daily profit target money (0 = off)
input int     InpDailyTradeLimit    = 20;            // Max entries per day (0 = off)
input int     InpMaximumOpenTrades  = 10;            // Max open EA positions (all magics)
input int     InpMaximumBuyPositions= 10;            // Max buy positions
input int     InpMaximumSellPositions = 10;          // Max sell positions
input double  InpMaximumTotalLots   = 2.0;           // Max total open lots
input int     InpStopTradingAfterLoss = 0;           // Stop for day after N consecutive losses (0 = off)
input int     InpStopTradingAfterWin  = 0;           // Stop for day after N wins today (0 = off)
input double  InpMinMarginLevel     = 300.0;         // Min margin level % for new trades (0 = off)
input ENUM_RISK_ACTION InpRiskAction= RACT_CLOSE_BLOCK; // Action on daily limit breach

//==================================================================
input group "=== 20 Drawdown Protection ==="
input bool    InpEnableMaxDrawdown  = true;          // Enable max drawdown
input ENUM_DD_MODE InpDrawdownMode  = DD_PEAK_EQUITY; // Drawdown reference
input double  InpMaxDrawdownPercent = 10.0;          // Max drawdown %
input double  InpMaxDrawdownMoney   = 0.0;           // Max drawdown money (0 = off)
input ENUM_RISK_ACTION InpDrawdownAction = RACT_CLOSE_BLOCK; // Action on drawdown breach
input bool    InpResetDrawdownHalt  = false;         // Set true once to clear a drawdown halt

//==================================================================
input group "=== 21 Spread & Slippage ==="
input bool    InpEnableSpreadFilter = true;          // Enable spread filter
input int     InpMaximumSpread      = 40;            // Max spread (points)
input int     InpMaximumSlippagePoints = 30;         // Max slippage after fill (points, log/close)
input bool    InpCloseOnExcessSlippage = false;      // Close fill if slippage exceeds max
input bool    InpEnableSpreadSpikeFilter = true;     // Enable spread spike filter
input int     InpSpreadAveragePeriod= 100;           // Spread average (ticks)
input double  InpMaximumSpreadMultiplier = 2.5;      // Block if spread > avg x this
input bool    InpRetryFailedOrders  = true;          // Retry failed orders
input int     InpRetryCount         = 3;             // Retry count
input int     InpRetryDelayMilliseconds = 300;       // Retry delay (ms)

//==================================================================
input group "=== 22 Grid Settings ==="
input bool    InpEnableGrid         = false;         // Enable grid
input ENUM_GRID_MODE InpGridMode    = GRID_CLASSIC;  // Grid mode
input ENUM_GRID_DIRECTION InpGridDirection = GDIR_SIGNAL; // Grid direction
input bool    InpGridAutoStart      = false;         // Auto start without entry signal
input ENUM_GRID_SPACING InpGridSpacingMode = GSP_POINTS; // Grid spacing mode
input double  InpGridStepPrice      = 2.0;           // Step price distance ($)
input int     InpGridStepPoints     = 300;           // Step (points)
input double  InpATRGridMultiplier  = 1.0;           // ATR x step
input double  InpGridStepPercent    = 0.10;          // Step % of price
input double  InpGridSpacingMultiplier = 1.0;        // Step multiplier per level (1 = flat)
input double  InpGridExpansionFactor= 1.2;           // Dynamic/adaptive expansion per level
input int     InpDynamicStepMinimum = 150;           // Dynamic step min (points)
input int     InpDynamicStepMaximum = 2000;          // Dynamic step max (points)
input int     InpMaximumGridLevels  = 5;             // Max grid levels per basket
input int     InpMaximumGridOrders  = 10;            // Max grid orders (positions + pendings)
input int     InpGridStartDistance  = 0;             // Distance before first level (points, 0 = step)
input int     InpGridHedgeFromLevel = 3;             // Hedged grid: opposite from level
input double  InpZoneHigh           = 0.0;           // Zone grid: upper price (0 = prev day high)
input double  InpZoneLow            = 0.0;           // Zone grid: lower price (0 = prev day low)
input ENUM_GRID_TP InpGridTPMode    = GTP_AVG_PRICE; // Grid take profit mode
input int     InpGridTPPoints       = 300;           // Grid TP beyond average (points)
input double  InpGridTPMoney        = 10.0;          // Grid basket TP (money)
input double  InpGridStopLossMoney  = 100.0;         // Grid basket SL (money, 0 = off)
input double  InpGridMaxDDPercent   = 15.0;          // Grid max DD % of balance (0 = off)
input ENUM_GRID_ONMAX InpGridOnMaxLevel = GMAX_HOLD; // Action at max level

//==================================================================
input group "=== 23 Grid Lot Progression ==="
input ENUM_GRID_LOT InpGridLotMode  = GLOT_FIXED;    // Grid lot progression
input double  InpGridInitialLot     = 0.01;          // Initial grid lot
input double  InpGridLotMultiplier  = 1.5;           // Multiplier
input double  InpGridLotAddition    = 0.01;          // Addition per level
input string  InpGridCustomLots     = "0.01,0.02,0.03,0.05,0.08"; // Custom sequence
input int     InpGridHybridLevel    = 3;             // Hybrid: geometric from level
input double  InpGridRiskPercent    = 0.5;           // Risk-based: % per level
input double  InpGridMaxLot         = 0.50;          // Max lot per grid level
input double  InpGridMaxTotalLots   = 1.00;          // Max total grid lots
input bool    InpEnableLotCap       = true;          // Enforce grid lot caps

//==================================================================
input group "=== 24 Martingale Settings ==="
input ENUM_MARTI_MODE InpMartingaleMode = MARTI_MULTIPLIER; // Martingale progression
input double  InpMartingaleMultiplier = 1.5;         // Multiplier
input double  InpMartingaleAddition   = 0.01;        // Additive step
input int     InpMartingaleMaxSteps   = 4;           // Max steps (then reset)
input bool    InpMartingaleResetOnWin = true;        // Reset sequence on win

//==================================================================
input group "=== 25 Hedge Settings ==="
input bool    InpEnableHedge        = false;         // Enable hedge
input ENUM_HEDGE_MODE InpHedgeMode  = HEDGE_PARTIAL; // Hedge mode
input double  InpHedgeTriggerLoss   = 20.0;          // Trigger loss (money)
input ENUM_HEDGE_LOT InpHedgeLotMode= HLOT_PERCENT;  // Hedge lot mode
input double  InpHedgeLotMultiplier = 1.2;           // Hedge lot multiplier
input double  InpHedgePercentage    = 50.0;          // Hedge percentage
input int     InpMaximumHedgePositions = 2;          // Max hedge positions
input bool    InpAllowMultipleHedges= false;         // Allow multiple hedges
input double  InpHedgeCloseProfit   = 0.0;           // Close hedge pair at net >= money
input double  InpHedgeEmergencyDD   = 8.0;           // Emergency: equity DD %
input double  InpHedgeLockProfit    = 15.0;          // Profit lock: min profit money
input double  InpHedgeLockRetrace   = 40.0;          // Profit lock: retrace % from peak
input ENUM_TIMEFRAMES InpHedgeTF    = PERIOD_H1;     // Directional: trend TF
input int     InpHedgeEMA           = 50;            // Directional: EMA period

//==================================================================
input group "=== 26 Recovery Settings ==="
input bool    InpEnableRecovery     = false;         // Enable recovery
input ENUM_RECOVERY_MODE InpRecoveryMode = REC_BASKET; // Recovery mode
input double  InpRecoveryTriggerLoss= 10.0;          // Trigger floating loss (money)
input double  InpRecoveryMultiplier = 1.5;           // Lot multiplier
input double  InpRecoveryTargetMoney= 2.0;           // Net profit target to close (money)
input int     InpRecoveryStepPoints = 300;           // Step / zone width (points)
input int     InpRecoveryTPPoints   = 300;           // Zone recovery TP distance (points)
input int     InpMaximumRecoveryLevels = 4;          // Max recovery levels
input double  InpMaximumRecoveryLot = 0.50;          // Max recovery lot per order
input int     InpRecoveryTimeoutMinutes = 0;         // Close all after N minutes (0 = off)

//==================================================================
input group "=== 27 Trading Session ==="
input bool    InpEnableSessionFilter= false;         // Enable session filter
input ENUM_SESSION_MODE InpTradingSessionMode = SESS_LONDON_NY; // Session mode
input ENUM_TIME_SOURCE  InpTimeSource = TSRC_SERVER; // Time reference
input int     InpServerGMTOffset    = 2;             // Server GMT offset (tester UTC conversion)
input int     InpAsianStartHour     = 1;             // Asian start hour
input int     InpAsianEndHour       = 9;             // Asian end hour
input int     InpLondonStartHour    = 10;            // London start hour
input int     InpLondonEndHour      = 19;            // London end hour
input int     InpNYStartHour        = 15;            // New York start hour
input int     InpNYEndHour          = 23;            // New York end hour
input bool    InpUseAsian           = false;         // Multiple: Asian
input bool    InpUseLondon          = true;          // Multiple: London
input bool    InpUseNewYork         = true;          // Multiple: New York
input int     InpSessionStartHour   = 9;             // Custom start hour
input int     InpSessionStartMinute = 0;             // Custom start minute
input int     InpSessionEndHour     = 21;            // Custom end hour
input int     InpSessionEndMinute   = 0;             // Custom end minute
input int     InpSessionBreakoutMinutes = 60;        // Session breakout window (minutes)
input bool    InpCloseAtSessionEnd  = false;         // Close positions outside session
input int     InpAvoidSessionOpening= 0;             // Skip first N minutes of session
input int     InpAvoidSessionClosing= 0;             // Skip last N minutes of session
input bool    InpSkipRollover       = true;          // Skip 23:50-00:15 server rollover

//==================================================================
input group "=== 28 Day Filter ==="
input bool    InpEnableMonday       = true;          // Monday
input bool    InpEnableTuesday      = true;          // Tuesday
input bool    InpEnableWednesday    = true;          // Wednesday
input bool    InpEnableThursday     = true;          // Thursday
input bool    InpEnableFriday       = true;          // Friday
input bool    InpEnableSaturday     = false;         // Saturday
input bool    InpEnableSunday       = false;         // Sunday
input int     InpFridayStopTradingHour = 20;         // Friday: no new trades from hour (server, -1 = off)
input bool    InpCloseBeforeWeekend = true;          // Close all before weekend
input int     InpFridayCloseHour    = 22;            // Friday close hour (server)
input int     InpFridayCloseMinute  = 30;            // Friday close minute

//==================================================================
input group "=== 29 News Filter ==="
input bool    InpEnableNewsFilter   = false;         // Enable news filter (MT5 calendar)
input ENUM_NEWS_IMPACT InpNewsImpact= NEWS_HIGH;     // Impact level
input string  InpNewsCurrencies     = "USD";         // Currencies (comma separated)
input int     InpNewsBeforeMinutes  = 30;            // Minutes before event
input int     InpNewsAfterMinutes   = 30;            // Minutes after event
input ENUM_NEWS_ACTION InpNewsAction= NEWS_BLOCK_NEW;// Action during news window
input string  InpManualNewsTimes    = "";            // Manual events (server) "yyyy.mm.dd hh:mi;..." (tester)
input bool    InpEnableVolatilityFilter = false;     // Enable volatility filter
input ENUM_VOL_MODE InpVolatilityMode = VOL_ATR;     // Volatility measure
input ENUM_TIMEFRAMES InpVolatilityTF = PERIOD_M15;  // Volatility timeframe
input int     InpVolatilityPeriod   = 14;            // Volatility period
input int     InpMinimumATR         = 100;           // Min volatility (points)
input int     InpMaximumATR         = 3000;          // Max volatility (points)

//==================================================================
input group "=== 30 Advanced Execution ==="
input ENUM_EXEC_POLICY InpExecutionPolicy = EPOL_SYNC; // Execution policy
input ENUM_FILL_MODE   InpFillingMode     = FILL_AUTO; // Filling mode
input ENUM_RETRY_MODE  InpOrderRetryMode  = RETRY_FIXED; // Retry mode
input ENUM_MODIFY_MODE InpOrderModificationMode = MOD_THROTTLED; // SL/TP modification mode
input int     InpModifyMinSeconds   = 2;             // Throttle: min seconds between modifies
input int     InpModifyMinStep      = 10;            // Throttle: min SL change (points)
input int     InpMaximumPendingOrders = 4;           // Max pending orders
input bool    InpDeleteExpiredOrders= true;          // EA deletes expired pendings itself
input bool    InpDeleteOppositePending = true;       // OCO: delete opposite pendings on fill
input ENUM_REQUOTE InpRequoteHandling = REQ_RETRY;   // Requote handling
input bool    InpFreezeLevelProtection = true;       // Respect freeze level
input bool    InpStopLevelProtection   = true;       // Respect stops level

//==================================================================
input group "=== 31 Account Management ==="
input ENUM_ACCOUNT_MODE InpAccountMode = ACC_AUTO;   // Account mode
input ENUM_POS_SCOPE    InpPositionManagement = PSCOPE_EA_ONLY; // Position scope (risk/basket)
input ENUM_CLOSE_ORDER  InpPositionCloseMode  = CLOSE_LOSERS_FIRST; // Close-all order
input ENUM_PENDING_MGMT InpPendingOrderManagement = PEND_DELETE_OPPOSITE; // Pending orders on signals

//==================================================================
input group "=== 32 Restart Recovery ==="
input ENUM_RESTART_MODE InpRestartRecoveryMode = RESTART_RESUME; // On (re)start
input bool    InpPersistState       = true;          // Persist state in global variables

//==================================================================
input group "=== 33 Alerts & Notifications ==="
input bool    InpEnableAlerts       = false;         // Popup alerts
input bool    InpEnablePushNotification = false;     // Push notifications
input bool    InpEnableSoundAlert   = false;         // Sound alerts
input string  InpSoundFile          = "alert.wav";   // Sound file
input bool    InpEnableTelegram     = false;         // Telegram (add api.telegram.org to WebRequest list)
input string  InpTelegramBotToken   = "";            // Telegram bot token (keep private)
input string  InpTelegramChatID     = "";            // Telegram chat id

//==================================================================
input group "=== 34 Chart Dashboard ==="
input bool    InpShowChartPanel     = true;          // Show dashboard
input bool    InpShowProfitPanel    = true;          // Show profit lines
input bool    InpShowEntryMarkers   = true;          // Entry arrows
input bool    InpShowSLTPLevels     = true;          // Virtual SL/TP and basket lines
input bool    InpShowGridLevels     = true;          // Next grid level lines
input int     InpPanelX             = 10;            // Panel X
input int     InpPanelY             = 25;            // Panel Y
input color   InpPanelColor         = clrWhite;      // Panel text colour

//==================================================================
input group "=== 35 Debug & Logging ==="
input bool    InpEnableDebugLog     = false;         // Detailed debug log
input ENUM_LOG_LEVEL InpLogLevel    = LOG_INFO;      // Log level
//+------------------------------------------------------------------+
