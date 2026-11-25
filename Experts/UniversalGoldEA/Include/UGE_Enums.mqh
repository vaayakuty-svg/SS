//+------------------------------------------------------------------+
//|                                                  UGE_Enums.mqh   |
//|  Universal Gold EA - every selectable mode as an ENUM.           |
//|  All option names are English and appear as dropdowns in the     |
//|  MT5 Inputs tab.                                                 |
//+------------------------------------------------------------------+

//==================== 02 Trading direction =========================
enum ENUM_TRADE_DIRECTION
  {
   DIR_BOTH        = 0, // Both directions
   DIR_BUY_ONLY    = 1, // Buy only
   DIR_SELL_ONLY   = 2, // Sell only
   DIR_AUTO_TREND  = 3  // Auto: only with trend EMA (Direction TF)
  };

//==================== 03 Entry strategy selection ==================
enum ENUM_ENTRY_COMBINE
  {
   COMBINE_ALL_AGREE = 0, // All enabled entry modules must agree
   COMBINE_ANY       = 1, // Any enabled module (first non-zero, no conflict)
   COMBINE_MAJORITY  = 2  // Majority vote of enabled modules
  };

//==================== 04 Candle entry ==============================
enum ENUM_CANDLE_PATTERN
  {
   CP_PREV_BULLISH_BUY     = 0,  // Previous candle bullish -> Buy
   CP_PREV_BEARISH_SELL    = 1,  // Previous candle bearish -> Sell
   CP_PREV_COLOR_FOLLOW    = 2,  // Follow previous colour (green Buy / red Sell)
   CP_PREV_COLOR_REVERSE   = 3,  // Reverse previous colour (red Buy / green Sell)
   CP_TWO_BULLISH_BUY      = 4,  // Two bullish candles -> Buy
   CP_TWO_BEARISH_SELL     = 5,  // Two bearish candles -> Sell
   CP_THREE_CANDLE_CONFIRM = 6,  // Three same-colour candles -> follow
   CP_ENGULFING            = 7,  // Engulfing pattern
   CP_PIN_BAR              = 8,  // Pin bar
   CP_INSIDE_BAR           = 9,  // Inside bar breakout
   CP_OUTSIDE_BAR          = 10, // Outside bar
   CP_DOJI_REVERSAL        = 11, // Doji reversal
   CP_HIGH_BREAKOUT        = 12, // Candle high breakout -> Buy
   CP_LOW_BREAKOUT         = 13, // Candle low breakout -> Sell
   CP_BODY_BREAKOUT        = 14, // Candle body breakout (both ways)
   CP_WICK_REJECTION       = 15, // Wick rejection
   CP_CONSECUTIVE          = 16  // N consecutive candles same direction
  };

enum ENUM_CANDLE_SELECTION
  {
   CANDLE_BEFORE = 0, // BEFORE - last closed candle (no repaint)
   CANDLE_NOW    = 1  // NOW - forming candle (intrabar, can repaint)
  };

//==================== 05 Breakout entry ============================
enum ENUM_BREAKOUT_MODE
  {
   BO_PREV_CANDLE_HIGH = 0,  // Previous candle high breakout (Buy)
   BO_PREV_CANDLE_LOW  = 1,  // Previous candle low breakout (Sell)
   BO_PREV_CANDLE_HL   = 2,  // Previous candle high/low (both)
   BO_DAILY_HL         = 3,  // Previous day high/low
   BO_WEEKLY_HL        = 4,  // Previous week high/low
   BO_ASIAN_SESSION    = 5,  // Asian opening-range breakout
   BO_LONDON_SESSION   = 6,  // London breaks Asian range
   BO_NEWYORK_SESSION  = 7,  // New York breaks London-morning range
   BO_RANGE            = 8,  // N-bar consolidation range breakout
   BO_SUPPORT_RESIST   = 9,  // Swing support/resistance breakout
   BO_DONCHIAN         = 10, // Donchian channel breakout
   BO_VOLATILITY       = 11  // Volatility breakout (day open +/- k*ATR)
  };

//==================== 06 Pullback entry ============================
enum ENUM_PULLBACK_MODE
  {
   PB_EMA             = 0, // EMA pullback
   PB_SUPPORT_RESIST  = 1, // Broken S/R pullback
   PB_FIBONACCI       = 2, // Fibonacci retracement zone
   PB_TRENDLINE       = 3, // Swing trendline pullback
   PB_VWAP            = 4, // VWAP pullback
   PB_BREAKOUT_RETEST = 5, // Breakout retest
   PB_ORDER_BLOCK     = 6, // Order block retest (SMC engine)
   PB_FVG             = 7  // Fair value gap retest (SMC engine)
  };

enum ENUM_ENTRY_CONFIRM
  {
   CONF_NONE           = 0, // No confirmation
   CONF_CLOSE_DIR      = 1, // Signal candle closes in trade direction
   CONF_ENGULFING      = 2, // Signal candle engulfs previous candle
   CONF_NEXT_BAR_BREAK = 3  // Next candle breaks setup candle high/low
  };

//==================== 07 Indicator entry ===========================
enum ENUM_IND_LOGIC
  {
   ILOGIC_CROSS       = 0, // Indicator cross
   ILOGIC_LEVEL       = 1, // Above / below level
   ILOGIC_OBOS        = 2, // Overbought / oversold reversal
   ILOGIC_TREND       = 3, // Trend confirmation
   ILOGIC_MOMENTUM    = 4, // Momentum confirmation
   ILOGIC_VOLATILITY  = 5  // Volatility confirmation (gate only)
  };

//==================== 08 Smart Money Concepts ======================
enum ENUM_SMC_ENTRY
  {
   SMC_ORDER_BLOCK      = 0,  // Order Block (OB) retest
   SMC_FVG              = 1,  // Fair Value Gap retest
   SMC_BOS              = 2,  // Break of Structure (continuation)
   SMC_CHOCH            = 3,  // Change of Character (reversal)
   SMC_BSL              = 4,  // Buy-side liquidity sweep -> Sell
   SMC_SSL              = 5,  // Sell-side liquidity sweep -> Buy
   SMC_LIQUIDITY_SWEEP  = 6,  // Any liquidity sweep + rejection
   SMC_INDUCEMENT       = 7,  // Inducement sweep in trend
   SMC_PREMIUM_ZONE     = 8,  // Sell rejections in premium
   SMC_DISCOUNT_ZONE    = 9,  // Buy rejections in discount
   SMC_EQUILIBRIUM      = 10, // Equilibrium reclaim with trend
   SMC_DISPLACEMENT     = 11, // Displacement candle with trend
   SMC_MITIGATION       = 12, // First mitigation of BOS order block
   SMC_BREAKER_BLOCK    = 13, // Breaker block retest
   SMC_MITIGATION_BLOCK = 14, // Mitigation block retest
   SMC_COMBO_SWEEP_CHOCH_OB_FVG = 15 // Sweep + CHOCH + OB/FVG (recommended)
  };

enum ENUM_OB_MODE
  {
   OB_BODY = 0, // Body of OB candle
   OB_WICK = 1, // Full wick range
   OB_MEAN = 2  // Entry at 50% of OB
  };
enum ENUM_FVG_MODE
  {
   FVG_EDGE = 0, // Enter at gap edge
   FVG_MID = 1, // Enter at 50% of gap
   FVG_FULL = 2  // Gap fully tested
  };
enum ENUM_STRUCT_MODE
  {
   STRUCT_CLOSE = 0, // Body close beyond swing
   STRUCT_WICK = 1  // Wick beyond swing
  };
enum ENUM_LIQ_MODE
  {
   LIQ_SWING = 0, // Swing high/low
   LIQ_EQUAL_HL = 1, // Equal highs/lows
   LIQ_PREV_DAY = 2  // Previous day high/low
  };
enum ENUM_PD_MODE
  {
   PD_OFF = 0, // No premium/discount filter
   PD_FILTER = 1, // Buy discount / Sell premium
   PD_OTE = 2  // Optimal trade entry 62-79%
  };
enum ENUM_MIT_MODE
  {
   MIT_FIRST_TOUCH = 0, // First touch only
   MIT_MULTI_TOUCH = 1, // Any touch until broken
   MIT_50PCT = 2  // Must reach 50% of zone
  };

//==================== 09 Multi-timeframe ===========================
enum ENUM_MTF_MODE
  {
   MTF_ALL       = 0, // All timeframes confirm
   MTF_ANY       = 1, // Any timeframe confirms
   MTF_MAJORITY  = 2, // Majority / minimum confirmations
   MTF_HTF_BIAS  = 3, // Primary (highest) TF bias only
   MTF_LTF_ENTRY = 4, // Lowest TF candle must confirm
   MTF_HTF_LTF   = 5  // HTF trend + LTF signal candle
  };

enum ENUM_MTF_METHOD
  {
   MTFM_EMA_SLOPE    = 0, // EMA slope
   MTFM_PRICE_VS_EMA = 1, // Close vs EMA
   MTFM_CANDLE_DIR   = 2, // Last closed candle colour
   MTFM_STRUCTURE    = 3  // Swing structure (HH/HL vs LH/LL)
  };

//==================== 04/News & conditions =========================
enum ENUM_NEWS_IMPACT
  {
   NEWS_LOW = 0, // Low and above
   NEWS_MEDIUM = 1, // Medium and above
   NEWS_HIGH = 2, // High only
   NEWS_ALL = 3  // All events
  };
enum ENUM_NEWS_ACTION
  {
   NEWS_BLOCK_NEW = 0, // Block new entries
   NEWS_CLOSE_ALL = 1, // Close positions
   NEWS_CLOSE_PROFIT = 2, // Close profitable only
   NEWS_DELETE_PENDING = 3  // Delete pending orders
  };
enum ENUM_VOL_MODE
  {
   VOL_ATR = 0, // ATR
   VOL_STDDEV = 1, // Standard deviation
   VOL_CANDLE_RANGE = 2  // Average candle range
  };

//==================== 10 Entry execution ===========================
enum ENUM_EXEC_MODE
  {
   EXEC_MARKET = 0, // Market order
   EXEC_STOP   = 1, // Stop order (Buy Stop above / Sell Stop below)
   EXEC_LIMIT  = 2, // Limit order (Buy Limit below / Sell Limit above)
   EXEC_RETEST = 3, // Retest: limit at signal candle close
   EXEC_HYBRID = 4  // Hybrid: market if close to ideal price else limit
  };

enum ENUM_ENTRY_TIMING
  {
   TIMING_BAR_OPEN   = 0, // Bar open (evaluate closed bar once)
   TIMING_BAR_CLOSE  = 1, // Bar close (last N seconds of the bar)
   TIMING_EVERY_TICK = 2, // Instant / every tick
   TIMING_TIMER      = 3  // Timer (every N seconds)
  };

//==================== 06 Opposite signal ===========================
enum ENUM_OPPOSITE_MODE
  {
   OPP_IGNORE          = 0, // Ignore opposite signal
   OPP_CLOSE           = 1, // Close current position
   OPP_REVERSE         = 2, // Close and open opposite
   OPP_HEDGE           = 3, // Keep and open opposite (hedging only)
   OPP_CLOSE_REENTER   = 4, // Close, re-enter on next confirmed signal
   OPP_CLOSE_IF_PROFIT = 5, // Close only if profitable
   OPP_CLOSE_IF_LOSS   = 6, // Close only if losing
   OPP_WAIT            = 7  // Wait until current trade closes
  };

//==================== 12 Take profit ===============================
enum ENUM_TP_MODE
  {
   TP_NONE      = 0, // Disabled
   TP_FIXED     = 1, // Fixed price distance ($)
   TP_POINTS    = 2, // Points
   TP_PRICE     = 3, // Absolute price level
   TP_MONEY     = 4, // Money per position (virtual)
   TP_ATR       = 5, // ATR multiple
   TP_RR        = 6, // Risk:Reward of SL distance
   TP_STRUCTURE = 7, // Next swing / liquidity level
   TP_BASKET    = 8  // Basket only (no per-trade TP)
  };

//==================== 13 Stop loss =================================
enum ENUM_SL_MODE
  {
   SL_NONE        = 0, // Disabled (use with care)
   SL_FIXED       = 1, // Fixed price distance ($)
   SL_POINTS      = 2, // Points
   SL_PRICE       = 3, // Absolute price level
   SL_ATR         = 4, // ATR multiple
   SL_PREV_CANDLE = 5, // Previous candle high/low
   SL_SWING       = 6, // Swing high/low
   SL_STRUCTURE   = 7, // SMC structure level
   SL_MONEY       = 8, // Money per position
   SL_EQUITY      = 9  // Equity protection only (no per-trade SL)
  };

enum ENUM_CANDLE_SL
  {
   CSL_WICK = 0, // Candle wick
   CSL_BODY = 1  // Candle body
  };
enum ENUM_SWING_SL
  {
   SSL_LOOKBACK = 0, // Lowest low / highest high of N bars
   SSL_FRACTAL = 1  // Last confirmed fractal swing
  };

//==================== 14 Trailing ==================================
enum ENUM_TRAIL_MODE
  {
   TRAIL_OFF        = 0, // Disabled
   TRAIL_FIXED      = 1, // Fixed distance
   TRAIL_STEP       = 2, // Step (staircase lock)
   TRAIL_ATR        = 3, // ATR distance
   TRAIL_PERCENT    = 4, // Keep % of open profit
   TRAIL_CANDLE     = 5, // Previous candle high/low
   TRAIL_SWING      = 6, // Last swing high/low
   TRAIL_SAR        = 7, // Parabolic SAR
   TRAIL_CHANDELIER = 8  // Chandelier exit
  };

//==================== 15 Break even ================================
enum ENUM_BE_MODE
  {
   BE_OFF     = 0, // Disabled
   BE_FIXED   = 1, // Fixed trigger -> SL at entry
   BE_PLUS    = 2, // Trigger -> SL at entry + offset
   BE_ATR     = 3, // ATR trigger
   BE_PERCENT = 4, // % of TP distance trigger
   BE_PARTIAL = 5  // After TP1 partial close
  };

//==================== 16 Partial close =============================
enum ENUM_PARTIAL_MODE
  {
   PC_OFF      = 0, // Disabled
   PC_SINGLE   = 1, // Single partial (TP1)
   PC_TP1_TP2  = 2, // TP1 + TP2
   PC_TP1_2_3  = 3, // TP1 + TP2 + TP3
   PC_PERCENT  = 4, // Levels as % of TP distance
   PC_MONEY    = 5  // Levels as money profit
  };

//==================== 12b Time exit ================================
enum ENUM_TIME_EXIT
  {
   TEXIT_OFF         = 0, // Disabled
   TEXIT_SECONDS     = 1, // Fixed seconds
   TEXIT_MINUTES     = 2, // Minutes
   TEXIT_BARS        = 3, // Bars
   TEXIT_SESSION_END = 4, // At session end
   TEXIT_PROFIT_TIME = 5  // In profit after N seconds
  };

//==================== 17 Basket ====================================
enum ENUM_BASKET_MODE
  {
   BASKET_OFF      = 0, // Disabled
   BASKET_MONEY    = 1, // Money target / stop
   BASKET_PERCENT  = 2, // % of balance target / stop
   BASKET_POINTS   = 3, // Lot-weighted points
   BASKET_WAVG     = 4, // Weighted average (break-even) price exit
   BASKET_EQUITY   = 5, // Equity take profit / stop loss
   BASKET_COMBINED = 6  // Money + equity together
  };

enum ENUM_BASKET_SCOPE
  {
   BSCOPE_ALL = 0, // All EA positions
   BSCOPE_PER_DIR = 1  // Buy and sell baskets separately
  };

//==================== 18 Lot sizing ================================
enum ENUM_LOT_MODE
  {
   LOT_FIXED            = 0,  // Fixed lot
   LOT_RISK_BALANCE     = 1,  // Balance % risk
   LOT_RISK_EQUITY      = 2,  // Equity % risk
   LOT_RISK_FREEMARGIN  = 3,  // Free margin % risk
   LOT_DYNAMIC          = 4,  // Dynamic: FixedLot per BalanceBase
   LOT_COMPOUNDING      = 5,  // Compounding (power curve)
   LOT_ANTI_COMPOUNDING = 6,  // Anti-compounding (lock gains)
   LOT_ATR              = 7,  // ATR risk (ATR stop distance)
   LOT_VOLATILITY       = 8,  // Volatility scaled (inverse ATR)
   LOT_MARTINGALE       = 9,  // Martingale after losses
   LOT_ANTI_MARTINGALE  = 10, // Anti-martingale after wins
   LOT_FIBONACCI        = 11, // Fibonacci after losses
   LOT_CUSTOM_SEQUENCE  = 12, // Custom sequence after losses
   LOT_RECOVERY         = 13  // Recovery: TP recovers realized debt
  };

enum ENUM_MARTI_MODE
  {
   MARTI_DOUBLE = 0, // Double (x2)
   MARTI_MULTIPLIER = 1, // Custom multiplier
   MARTI_ADDITIVE = 2  // Add fixed lot per step
  };

//==================== 19/20 Risk ===================================
enum ENUM_LOSS_BASIS
  {
   LOSS_REALIZED = 0, // Realized only
   LOSS_FLOATING = 1, // Floating only
   LOSS_COMBINED = 2  // Realized + floating
  };
enum ENUM_DD_MODE
  {
   DD_BALANCE = 0, // Balance from start
   DD_EQUITY = 1, // Equity from start
   DD_PEAK_EQUITY = 2  // From peak equity
  };
enum ENUM_RISK_ACTION
  {
   RACT_BLOCK_NEW = 0, // Block new entries
   RACT_CLOSE_BLOCK = 1, // Close all and block
   RACT_CLOSE_REMOVE = 2  // Close all and remove EA
  };

//==================== 22 Grid ======================================
enum ENUM_GRID_MODE
  {
   GRID_CLASSIC        = 0,  // Classic averaging grid
   GRID_BUY            = 1,  // Buy grid only
   GRID_SELL           = 2,  // Sell grid only
   GRID_BUY_SELL       = 3,  // Independent buy & sell grids
   GRID_REVERSE        = 4,  // Reverse: trade in direction of each step
   GRID_TREND          = 5,  // Trend-following pyramid
   GRID_COUNTER_TREND  = 6,  // Counter-trend (fade EMA) averaging
   GRID_HEDGED         = 7,  // Hedged grid (opposite after level N)
   GRID_RECOVERY       = 8,  // Recovery grid (starts at loss trigger)
   GRID_DYNAMIC        = 9,  // Dynamic grid (ATR step per level)
   GRID_ADAPTIVE       = 10, // Adaptive (volatility-regime step)
   GRID_CANDLE         = 11, // Candle-confirmed averaging
   GRID_BREAKOUT       = 12, // Breakout stop-order ladder
   GRID_ZONE           = 13, // Zone (range) limit ladder
   GRID_MULTI_LEVEL    = 14  // Multi-level pending limit ladder
  };

enum ENUM_GRID_DIRECTION
  {
   GDIR_BOTH = 0, // Both
   GDIR_BUY = 1, // Buy only
   GDIR_SELL = 2, // Sell only
   GDIR_SIGNAL = 3  // Follow entry signal
  };

enum ENUM_GRID_SPACING
  {
   GSP_FIXED_PRICE  = 0, // Fixed price distance ($)
   GSP_POINTS       = 1, // Points
   GSP_ATR          = 2, // ATR multiple
   GSP_PERCENT      = 3, // % of price
   GSP_CANDLE_RANGE = 4, // Average candle range
   GSP_FIBONACCI    = 5, // Fibonacci expanding
   GSP_DYNAMIC      = 6, // Dynamic (expansion per level, clamped)
   GSP_ADAPTIVE     = 7  // Adaptive (ATR regime x expansion)
  };

enum ENUM_GRID_LOT
  {
   GLOT_FIXED          = 0,  // Fixed
   GLOT_ARITHMETIC     = 1,  // Arithmetic (+add per level)
   GLOT_GEOMETRIC      = 2,  // Geometric (x multiplier)
   GLOT_MARTINGALE     = 3,  // Martingale (x2)
   GLOT_ANTI_MARTINGALE= 4,  // Anti-martingale (/ multiplier)
   GLOT_FIBONACCI      = 5,  // Fibonacci
   GLOT_CUSTOM         = 6,  // Custom sequence
   GLOT_RISK_BASED     = 7,  // Risk % to grid basket SL
   GLOT_RECOVERY       = 8,  // Pull average price toward market
   GLOT_DECREASING     = 9,  // Decreasing (-add per level)
   GLOT_ALTERNATING    = 10, // Alternating base / base x mult
   GLOT_HYBRID         = 11  // Fixed until level N, then geometric
  };

enum ENUM_GRID_TP
  {
   GTP_AVG_PRICE = 0, // Average price + points
   GTP_BASKET_MONEY = 1, // Basket money
   GTP_LAST_LEVEL = 2  // First + last level pair
  };
enum ENUM_GRID_ONMAX
  {
   GMAX_HOLD = 0, // Hold, no more levels
   GMAX_CLOSE_ALL = 1, // Close grid
   GMAX_HEDGE = 2, // Hedge net exposure
   GMAX_STOP = 3  // Stop new trading
  };

//==================== 25 Hedge =====================================
enum ENUM_HEDGE_MODE
  {
   HEDGE_DISABLED    = 0, // Disabled
   HEDGE_FULL        = 1, // Full hedge (100%)
   HEDGE_PARTIAL     = 2, // Partial hedge (%)
   HEDGE_DYNAMIC     = 3, // Dynamic (scales with loss)
   HEDGE_RECOVERY    = 4, // Recovery hedge (x multiplier)
   HEDGE_EMERGENCY   = 5, // Emergency (equity DD trigger)
   HEDGE_GRID        = 6, // Grid hedge (at grid max level)
   HEDGE_SIGNAL      = 7, // Signal-based (opposite signal in loss)
   HEDGE_PROFIT_LOCK = 8, // Profit lock (after retrace from peak)
   HEDGE_DIRECTIONAL = 9  // Directional (HTF trend against position)
  };

enum ENUM_HEDGE_LOT
  {
   HLOT_SAME = 0, // Same as exposure
   HLOT_MULTIPLIER = 1, // Exposure x multiplier
   HLOT_PERCENT = 2  // Exposure x percentage
  };

//==================== 26 Recovery ==================================
enum ENUM_RECOVERY_MODE
  {
   REC_DISABLED      = 0, // Disabled
   REC_LOT_MULT      = 1, // Lot multiplier adds
   REC_OPPOSITE      = 2, // Opposite direction recovery
   REC_GRID          = 3, // Grid recovery (flat adds)
   REC_HEDGE_ZONE    = 4, // Hedge / zone recovery
   REC_BASKET        = 5, // Basket break-even target
   REC_PARTIAL       = 6, // Partial close loser with winners
   REC_AVERAGE_PRICE = 7, // Average price recovery
   REC_PROFIT_TARGET = 8, // Realized-debt profit target
   REC_MULTI_LEVEL   = 9  // Multi-level escalating
  };

//==================== 27 Session ===================================
enum ENUM_SESSION_MODE
  {
   SESS_24H       = 0, // 24-hour trading
   SESS_ASIAN     = 1, // Asian session
   SESS_LONDON    = 2, // London session
   SESS_NEWYORK   = 3, // New York session
   SESS_LONDON_NY = 4, // London + New York
   SESS_CUSTOM    = 5, // Custom window
   SESS_MULTIPLE  = 6, // Multiple sessions (switches)
   SESS_OVERLAP   = 7, // London / New York overlap
   SESS_BREAKOUT  = 8  // First N minutes after each session open
  };

enum ENUM_TIME_SOURCE
  {
   TSRC_SERVER = 0, // Broker server time
   TSRC_UTC = 1  // UTC (GMT)
  };

//==================== 31 Account ===================================
enum ENUM_ACCOUNT_MODE
  {
   ACC_AUTO = 0, // Auto detect
   ACC_HEDGING = 1, // Hedging
   ACC_NETTING = 2  // Netting
  };
enum ENUM_POS_SCOPE
  {
   PSCOPE_EA_ONLY = 0, // EA magic only
   PSCOPE_SYMBOL = 1, // All on this symbol
   PSCOPE_ALL = 2  // All positions (risk/basket only)
  };
enum ENUM_CLOSE_ORDER
  {
   CLOSE_ANY_ORDER = 0, // Ticket order
   CLOSE_LOSERS_FIRST = 1, // Largest loss first
   CLOSE_WINNERS_FIRST = 2  // Profitable first
  };
enum ENUM_PENDING_MGMT
  {
   PEND_KEEP = 0, // Keep
   PEND_DELETE_OPPOSITE = 1, // Delete on opposite signal
   PEND_REPLACE = 2  // Replace on new signal
  };
enum ENUM_RESTART_MODE
  {
   RESTART_RESUME = 0, // Resume managing
   RESTART_CLOSE_ALL = 1, // Close EA positions
   RESTART_IGNORE = 2  // Ignore existing (unmanaged)
  };

//==================== 30 Advanced execution ========================
enum ENUM_EXEC_POLICY
  {
   EPOL_SYNC = 0, // Synchronous
   EPOL_ASYNC = 1  // Asynchronous
  };
enum ENUM_FILL_MODE
  {
   FILL_AUTO = 0, // Automatic
   FILL_FOK = 1, // FOK
   FILL_IOC = 2, // IOC
   FILL_RETURN = 3  // RETURN
  };
enum ENUM_RETRY_MODE
  {
   RETRY_NONE = 0, // No retry
   RETRY_FIXED = 1, // Fixed delay
   RETRY_EXPONENTIAL = 2  // Exponential back-off
  };
enum ENUM_MODIFY_MODE
  {
   MOD_IMMEDIATE = 0, // Immediate
   MOD_THROTTLED = 1  // Throttled (min seconds + min step)
  };
enum ENUM_REQUOTE
  {
   REQ_RETRY = 0, // Retry with new price
   REQ_WIDEN = 1, // Retry with wider deviation
   REQ_ABORT = 2  // Abort
  };

//==================== 27 Advanced strategies =======================
enum ENUM_STRATEGY
  {
   STRAT_TREND_FOLLOWING = 0,  // Trend following
   STRAT_COUNTER_TREND   = 1,  // Counter trend
   STRAT_MEAN_REVERSION  = 2,  // Mean reversion
   STRAT_MOMENTUM        = 3,  // Momentum
   STRAT_SCALPING        = 4,  // Scalping
   STRAT_SWING           = 5,  // Swing trading
   STRAT_BREAKOUT_RETEST = 6,  // Breakout retest
   STRAT_REVERSAL        = 7,  // Reversal
   STRAT_CONTINUATION    = 8,  // Continuation
   STRAT_RANGE           = 9,  // Range trading
   STRAT_VOLATILITY      = 10, // Volatility expansion
   STRAT_LIQUIDITY       = 11, // Liquidity sweep
   STRAT_STATISTICAL     = 12, // Statistical z-score
   STRAT_ARBITRAGE       = 13  // Statistical pair (ratio) arbitrage
  };

//==================== 35 Logging ===================================
enum ENUM_LOG_LEVEL
  {
   LOG_ERRORS = 0, // Errors only
   LOG_INFO = 1, // Info
   LOG_DEBUG = 2  // Full debug
  };
//+------------------------------------------------------------------+
