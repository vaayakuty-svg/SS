//+------------------------------------------------------------------+
//|                                             UniversalGoldEA.mq5  |
//|  PROFESSIONAL UNIVERSAL MODULAR XAUUSD EXPERT ADVISOR (MT5)      |
//|                                                                  |
//|  Every module is selected independently from the Inputs tab:     |
//|   Entry   : Candle, Breakout, Pullback, Indicator (12), SMC (16), |
//|             Advanced strategy presets (14), combined ALL/ANY/MAJ |
//|   Filters : MTF (6 modes), session (9), day, news, volatility,   |
//|             spread + spike, rollover, weekend                     |
//|   Execute : Market / Stop / Limit / Retest / Hybrid, timing      |
//|             bar-open / bar-close / tick / timer, retries, filling|
//|   Exit    : TP (9), SL (10), trailing (9), break-even (6),       |
//|             partial TP1-TP3, time & signal exits, basket/equity  |
//|   Size    : 14 lot modes, martingale settings, broker validation |
//|   Risk    : daily loss, drawdown, exposure caps, margin, streaks |
//|   Advanced: grid (15) + spacing (8) + lot progression (12),      |
//|             hedge (10), recovery (10)                             |
//|   State   : restart recovery via global variables                |
//|                                                                  |
//|  Architecture: UniversalGoldEA.mq5 (orchestration) + Include/*   |
//|  Magic numbers: Magic (main), +1 grid, +2 hedge, +3 recovery.    |
//|                                                                  |
//|  No profitability is implied. Back-test each mode on real ticks, |
//|  then forward-test on demo before using real money.              |
//+------------------------------------------------------------------+
#property copyright   "SS"
#property version     "1.00"
#property description "Universal modular XAUUSD EA: selectable entry, exit, sizing, risk, grid, hedge and recovery modules."
#property description "Grid / martingale / recovery modes can lose the whole account in one trend. Test on demo first."

#include "Include\UGE_Enums.mqh"
#include "Include\UGE_Inputs.mqh"
#include "Include\UGE_Core.mqh"
#include "Include\UGE_Data.mqh"
#include "Include\UGE_Filters.mqh"
#include "Include\UGE_SMC.mqh"
#include "Include\UGE_Signals.mqh"
#include "Include\UGE_Risk.mqh"
#include "Include\UGE_Manage.mqh"
#include "Include\UGE_Grid.mqh"
#include "Include\UGE_Panel.mqh"

//--- runtime state of the entry engine
datetime g_lastEntryBar     = 0;     // chart TF bar of last evaluation (bar open / bar close timing)
datetime g_lastCandleBar    = 0;     // candle TF bar for EntryOnNewCandle
datetime g_entryCountBar    = 0;     // chart bar used for per-bar entry counting
int      g_entriesThisBar   = 0;
datetime g_candleCountBar   = 0;
int      g_entriesThisCandle= 0;
datetime g_lastPanel        = 0;
int      g_lastSignal       = 0;
bool     g_recoveryRuntime  = true;  // recovery allowed on this account type
bool     g_newsActionDone   = false;

//+------------------------------------------------------------------+
//| Input validation: hard conflicts refuse to start, soft ones warn |
//+------------------------------------------------------------------+
int ValidateInputs()
  {
   string err = "";
   if(InpMagicNumber == 0) err += "MagicNumber must be > 0. ";
   if(!InpEnableBuy && !InpEnableSell) err += "EnableBuy and EnableSell are both false. ";
   if(InpTradeDirection == DIR_BUY_ONLY && !InpEnableBuy) err += "TradeDirection BUY_ONLY but EnableBuy=false. ";
   if(InpTradeDirection == DIR_SELL_ONLY && !InpEnableSell) err += "TradeDirection SELL_ONLY but EnableSell=false. ";
   if(InpRiskPercent <= 0 || InpRiskPercent > 10) err += "RiskPercent must be in (0,10]. ";
   if(InpMaximumLot < InpMinimumLot) err += "MaximumLot < MinimumLot. ";
   if(InpFixedLot <= 0) err += "FixedLot must be > 0. ";
   if(InpRiskRewardRatio <= 0) err += "RiskRewardRatio must be > 0. ";
   if(InpEnablePartialClose && InpTP1ClosePercent + InpTP2ClosePercent + InpTP3ClosePercent > 100.0001 && InpPartialCloseMode != PC_SINGLE)
      err += "Partial close percentages exceed 100. ";
   if(InpEnableGrid && InpMaximumGridLevels < 1) err += "MaximumGridLevels must be >= 1. ";
   //--- mutually exclusive engines (both would add to the same losing position)
   if(InpEnableGrid && InpEnableRecovery &&
      (InpRecoveryMode == REC_GRID || InpRecoveryMode == REC_LOT_MULT || InpRecoveryMode == REC_MULTI_LEVEL ||
       InpRecoveryMode == REC_AVERAGE_PRICE || InpRecoveryMode == REC_HEDGE_ZONE))
      err += "Grid and an adding Recovery mode cannot run together (choose one). ";
   if(InpEnableGrid && InpGridMode == GRID_HEDGED && InpEnableHedge) err += "Hedged grid and Hedge module both open hedges (choose one). ";
   if(InpEnableHedge && InpEnableRecovery && (InpRecoveryMode == REC_HEDGE_ZONE || InpRecoveryMode == REC_OPPOSITE))
      err += "Hedge module and opposite/zone recovery both open opposite trades (choose one). ";
   if(InpLotMode == LOT_RECOVERY && InpEnableRecovery && InpRecoveryMode == REC_PROFIT_TARGET)
      err += "Lot mode RECOVERY and Recovery PROFIT_TARGET both chase the same debt (choose one). ";
   if(InpMTFCount < 1 || InpMTFCount > 5) err += "MTFCount must be 1-5. ";
   if(StringLen(err) > 0) { LogError("Invalid inputs: " + err); return INIT_PARAMETERS_INCORRECT; }
   //--- warnings
   if(StringLen(InpTradeComment) > 25) LogInfo("TradeComment is long; it is truncated to 31 chars with tags.");
   if((!InpEnableStopLoss || InpStopLossMode == SL_NONE || InpStopLossMode == SL_EQUITY) && !InpEnableMaxDrawdown)
      LogInfo("WARNING: no stop loss AND no drawdown protection - unlimited risk.");
   if(InpEnableTakeProfit && InpTakeProfitMode == TP_BASKET && InpBasketExitMode == BASKET_OFF && !InpEnableGrid)
      LogInfo("WARNING: TP mode BASKET but basket management is OFF - trades exit only by SL/trailing.");
   if(InpCandleSelection == CANDLE_NOW && InpUseCandleEntry && InpEntryTiming == TIMING_BAR_OPEN)
      LogInfo("WARNING: Candle NOW with Bar-Open timing reads an empty forming candle; use Tick/Timer/Bar-Close.");
   if(!InpUseCandleEntry && !InpUseBreakoutEntry && !InpUsePullbackEntry && !InpUseIndicatorEntry && !InpUseSMCEntry && !InpUseStrategyEntry && !(InpEnableGrid && InpGridAutoStart))
      LogInfo("No entry module enabled: the EA will only manage existing positions.");
   if(InpEnableGrid || InpLotMode == LOT_MARTINGALE || InpEnableRecovery)
      LogInfo("WARNING: grid/martingale/recovery active. Caps, basket SL and max drawdown are your only protection.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Indicator handles                                                |
//+------------------------------------------------------------------+
bool CreateHandles()
  {
   bool ok = true;
   ok = RegHandle(g_hATR = iATR(_Symbol, InpATRTF, InpATRPeriod), "core ATR") && ok;
   ok = RegHandle(g_hDirEMA = iMA(_Symbol, InpDirectionTF, InpDirectionEMA, 0, MODE_EMA, PRICE_CLOSE), "direction EMA") && ok;
   if(InpEnableTrailing && (InpTrailingMode == TRAIL_ATR || InpTrailingMode == TRAIL_CHANDELIER))
      ok = RegHandle(g_hTrailATR = iATR(_Symbol, InpTrailingTimeframe, InpATRPeriod), "trailing ATR") && ok;
   if(InpEnableTrailing && InpTrailingMode == TRAIL_SAR)
      ok = RegHandle(g_hTrailSAR = iSAR(_Symbol, InpTrailingTimeframe, InpSARStep, InpSARMax), "trailing SAR") && ok;
   if(InpEnableVolatilityFilter && InpVolatilityMode == VOL_ATR)
      ok = RegHandle(g_hVolFilter = iATR(_Symbol, InpVolatilityTF, InpVolatilityPeriod), "volatility ATR") && ok;
   if(InpEnableVolatilityFilter && InpVolatilityMode == VOL_STDDEV)
      ok = RegHandle(g_hVolFilter = iStdDev(_Symbol, InpVolatilityTF, InpVolatilityPeriod, 0, MODE_SMA, PRICE_CLOSE), "volatility StdDev") && ok;
   if(InpEnableHedge && InpHedgeMode == HEDGE_DIRECTIONAL)
      ok = RegHandle(g_hHedgeEMA = iMA(_Symbol, InpHedgeTF, InpHedgeEMA, 0, MODE_EMA, PRICE_CLOSE), "hedge EMA") && ok;
   if(InpUseBreakoutEntry && InpBreakoutMode == BO_VOLATILITY)
      ok = RegHandle(g_hDailyATR = iATR(_Symbol, PERIOD_D1, 14), "daily ATR") && ok;
   if(InpUsePullbackEntry && InpPullbackMode == PB_EMA)
      ok = RegHandle(g_hPullEMA = iMA(_Symbol, InpPullbackTF, InpPullbackEMAPeriod, 0, MODE_EMA, PRICE_CLOSE), "pullback EMA") && ok;
   for(int i = 0; i < 5; i++) g_hMTF[i] = INVALID_HANDLE;
   if(InpEnableMTF)
      for(int i = 0; i < MTFCount(); i++)
         ok = RegHandle(g_hMTF[i] = iMA(_Symbol, MTFFrame(i), InpMTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE), "MTF EMA " + (string)i) && ok;
   //--- indicator module
   if(InpUseIndicatorEntry)
     {
      ENUM_TIMEFRAMES tf = InpIndTF;
      if(InpUseEMA)  { ok = RegHandle(g_hEMAf = iMA(_Symbol, tf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE), "EMA fast") && ok; ok = RegHandle(g_hEMAs = iMA(_Symbol, tf, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE), "EMA slow") && ok; }
      if(InpUseSMA)  { ok = RegHandle(g_hSMAf = iMA(_Symbol, tf, InpSMAFast, 0, MODE_SMA, PRICE_CLOSE), "SMA fast") && ok; ok = RegHandle(g_hSMAs = iMA(_Symbol, tf, InpSMASlow, 0, MODE_SMA, PRICE_CLOSE), "SMA slow") && ok; }
      if(InpUseRSI)  ok = RegHandle(g_hRSI = iRSI(_Symbol, tf, InpRSIPeriod, PRICE_CLOSE), "RSI") && ok;
      if(InpUseMACD) ok = RegHandle(g_hMACD = iMACD(_Symbol, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE), "MACD") && ok;
      if(InpUseStoch)ok = RegHandle(g_hStoch = iStochastic(_Symbol, tf, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH), "Stochastic") && ok;
      if(InpUseBB)   ok = RegHandle(g_hBB = iBands(_Symbol, tf, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE), "Bollinger") && ok;
      if(InpUseATRInd) ok = RegHandle(g_hATRi = iATR(_Symbol, tf, InpATRIndPeriod), "ATR") && ok;
      if(InpUseADX)  ok = RegHandle(g_hADX = iADX(_Symbol, tf, InpADXPeriod), "ADX") && ok;
      if(InpUseCCI)  ok = RegHandle(g_hCCI = iCCI(_Symbol, tf, InpCCIPeriod, PRICE_TYPICAL), "CCI") && ok;
      if(InpUseIchimoku) ok = RegHandle(g_hIchi = iIchimoku(_Symbol, tf, InpIchiTenkan, InpIchiKijun, InpIchiSenkouB), "Ichimoku") && ok;
      if(InpUseSAR)  ok = RegHandle(g_hSAR = iSAR(_Symbol, tf, InpSARStep, InpSARMax), "SAR") && ok;
     }
   //--- strategy presets
   if(InpUseStrategyEntry)
     {
      ENUM_TIMEFRAMES tf = InpStrategyTF;
      ok = RegHandle(g_hSEMA20  = iMA(_Symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE), "S EMA20") && ok;
      ok = RegHandle(g_hSEMA50  = iMA(_Symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE), "S EMA50") && ok;
      ok = RegHandle(g_hSEMA200 = iMA(_Symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE), "S EMA200") && ok;
      ok = RegHandle(g_hSEMA9   = iMA(_Symbol, tf, 9, 0, MODE_EMA, PRICE_CLOSE), "S EMA9") && ok;
      ok = RegHandle(g_hSEMA21  = iMA(_Symbol, tf, 21, 0, MODE_EMA, PRICE_CLOSE), "S EMA21") && ok;
      ok = RegHandle(g_hSRSI    = iRSI(_Symbol, tf, 14, PRICE_CLOSE), "S RSI") && ok;
      ok = RegHandle(g_hSBB     = iBands(_Symbol, tf, 20, 0, 2.0, PRICE_CLOSE), "S BB") && ok;
      ok = RegHandle(g_hSMACD   = iMACD(_Symbol, tf, 12, 26, 9, PRICE_CLOSE), "S MACD") && ok;
      ok = RegHandle(g_hSADX    = iADX(_Symbol, tf, 14), "S ADX") && ok;
      ok = RegHandle(g_hSATR    = iATR(_Symbol, tf, 14), "S ATR") && ok;
      if(InpStrategyMode == STRAT_ARBITRAGE && !SymbolSelect(InpArbSymbol, true))
        { LogError("Arbitrage symbol not available: " + InpArbSymbol); ok = false; }
     }
   return ok;
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
   int v = ValidateInputs();
   if(v != INIT_SUCCEEDED) return v;
   if(!g_sym.Name(_Symbol)) return INIT_FAILED;
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      LogInfo("Note: designed for XAUUSD; running on " + _Symbol + " (point-based inputs still apply).");

   //--- account type
   long mm = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   g_isHedging = (mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(InpAccountMode == ACC_HEDGING && !g_isHedging) LogInfo("AccountMode=Hedging but account is NETTING - using netting rules.");
   if(InpAccountMode == ACC_NETTING && g_isHedging)  LogInfo("AccountMode=Netting on a hedging account - one position per direction enforced.");
   if(InpAccountMode == ACC_NETTING) g_isHedging = false; // user asked for netting behaviour
   if(!g_isHedging)
     {
      if(InpEnableGrid)  LogInfo("Netting account: grid disabled.");
      if(InpEnableHedge) LogInfo("Netting account: hedge disabled.");
      if(InpEnableRecovery) { LogInfo("Netting account: recovery disabled."); g_recoveryRuntime = false; }
     }

   //--- trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaximumSlippage);
   g_trade.SetTypeFilling(ResolveFilling());
   g_trade.SetAsyncMode(InpExecutionPolicy == EPOL_ASYNC);
   g_trade.LogLevel(InpLogLevel >= LOG_DEBUG ? LOG_LEVEL_ALL : LOG_LEVEL_ERRORS);

   //--- persistence namespace (unique per magic + symbol; tester runs are separated)
   g_gvPrefix = StringFormat("UGE_%I64u_%s_%s", InpMagicNumber, _Symbol, g_isTester ? "T_" : "");
   if(g_isTester)
     {
      //--- fresh state for every tester pass
      for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
        { string n = GlobalVariableName(i); if(StringFind(n, g_gvPrefix) == 0) GlobalVariableDel(n); }
     }
   LoadState();
   CheckNewDay();

   //--- handles + engines
   if(!CreateHandles()) { ReleaseAllHandles(); return INIT_FAILED; }
   g_smc.Init(InpSMCTF, InpSMCSwingLen, InpSMCLookback);
   g_smcHTF.Init(InpSMCHTF, InpSMCSwingLen, InpSMCLookback);
   ParseManualNews();

   //--- restart recovery
   if(!g_isTester)
     {
      SExposure e; GetExposure(e);
      if(e.total > 0 || e.pendings > 0)
        {
         switch(InpRestartRecoveryMode)
           {
            case RESTART_RESUME:
               LogInfo(StringFormat("Restart: resuming management of %d positions / %d pendings", e.total, e.pendings));
               break;
            case RESTART_CLOSE_ALL:
               CloseAll("restart close"); DeletePendings("restart close");
               break;
            case RESTART_IGNORE:
               for(int i = PositionsTotal() - 1; i >= 0; i--)
                 {
                  ulong t = PositionGetTicket(i);
                  if(t > 0 && IsOwnPosition()) GVSet("ign_" + (string)t, 1);
                 }
               LogInfo("Restart: existing positions left unmanaged");
               break;
           }
        }
     }
   CleanupPositionGVs();

   int tsec = (InpEntryTiming == TIMING_TIMER ? MathMax(1, InpTimerSeconds) : 1);
   EventSetTimer(tsec);
   g_status = "Running";
   LogInfo(StringFormat("Initialised: %s, %s account, filling=%s, digits=%d, point=%s",
                        _Symbol, g_isHedging ? "hedging" : "netting", EnumToString(ResolveFilling()), _Digits, DoubleToString(_Point, _Digits)));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   SaveState();
   ReleaseAllHandles();
   if(reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS) RemovePanel();
   else ObjectsDeleteAll(0, PANEL_PREFIX + "L");
  }

//+------------------------------------------------------------------+
//| Direction permission (EnableBuy/Sell + TradeDirection)           |
//+------------------------------------------------------------------+
bool DirectionAllowed(int dir)
  {
   if(dir > 0 && !InpEnableBuy) return false;
   if(dir < 0 && !InpEnableSell) return false;
   switch(InpTradeDirection)
     {
      case DIR_BUY_ONLY:   return (dir > 0);
      case DIR_SELL_ONLY:  return (dir < 0);
      case DIR_AUTO_TREND: return (DirectionTrend() == dir);
      default:             return true;
     }
  }

//--- signal identity: one trade per signal across every enabled module's candle
string SignalKey(int dir)
  {
   string k = (string)dir;
   if(InpUseCandleEntry)    k += "_c" + (string)(long)T(InpCandleTF, InpCandleSelection == CANDLE_BEFORE ? 1 : 0);
   if(InpUseBreakoutEntry)  k += "_b" + (string)(long)T(InpBreakoutTF, 1);
   if(InpUsePullbackEntry)  k += "_p" + (string)(long)T(InpPullbackTF, 1);
   if(InpUseIndicatorEntry) k += "_i" + (string)(long)T(InpIndTF, 1);
   if(InpUseSMCEntry)       k += "_s" + (string)(long)T(InpSMCTF, 1);
   if(InpUseStrategyEntry)  k += "_x" + (string)(long)T(InpStrategyTF, 1);
   return k;
  }

//+------------------------------------------------------------------+
//| Opposite-signal and existing-position handling.                  |
//| Returns true if a NEW position may be opened in 'dir'.           |
//+------------------------------------------------------------------+
bool HandleExisting(int dir)
  {
   SBasket same, opp;
   ScanBasket(dir, 1 << MAGIC_MAIN, same);
   ScanBasket(-dir, 1 << MAGIC_MAIN, opp);
   int dfl = (dir > 0 ? -1 : 1); // CloseAll filter for the opposite side
   if(opp.count > 0)
     {
      if(InpExitOnOppositeSignal) { CloseAll("opposite signal exit", dfl, MAGIC_MAIN); opp.count = 0; }
      else
         switch(InpOppositeSignalMode)
           {
            case OPP_IGNORE:          return false;
            case OPP_WAIT:            return false;
            case OPP_CLOSE:           CloseAll("opposite: close", dfl, MAGIC_MAIN); return false;
            case OPP_CLOSE_REENTER:   CloseAll("opposite: close, re-enter next", dfl, MAGIC_MAIN); return false;
            case OPP_REVERSE:         CloseAll("opposite: reverse", dfl, MAGIC_MAIN); break;
            case OPP_HEDGE:           if(!g_isHedging) return false; break;
            case OPP_CLOSE_IF_PROFIT: if(opp.profit <= 0) return false; CloseAll("opposite: close profitable", dfl, MAGIC_MAIN); break;
            case OPP_CLOSE_IF_LOSS:   if(opp.profit >= 0) return false; CloseAll("opposite: close losing", dfl, MAGIC_MAIN); break;
           }
     }
   //--- netting: the opposite must be gone before opening
   if(!g_isHedging) { ScanBasket(-dir, 1 << MAGIC_MAIN, opp); if(opp.count > 0) return false; }
   //--- same direction
   if(same.count > 0)
     {
      if(!InpAllowMultiplePositions) return false;
      if(same.count >= InpMaxMainPositions) return false;
     }
   if(!InpAllowMultiplePositions && opp.count > 0 && InpOppositeSignalMode != OPP_HEDGE) return false;
   return true;
  }

//--- count main pending orders
int MainPendings()
  {
   int n = 0;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      ulong t = OrderGetTicket(j);
      if(t > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == (long)InpMagicNumber + MAGIC_MAIN) n++;
     }
   return n;
  }

//+------------------------------------------------------------------+
//| Place the entry according to the execution mode                  |
//+------------------------------------------------------------------+
bool ExecuteEntry(int dir, string why)
  {
   double ask = SymAsk(), bid = SymBid();
   double mkt = (dir > 0 ? ask : bid);
   double entry = mkt;
   int    kind = 0;            // 0 market, 1 stop, 2 limit
   double ideal = C(_Period, 1);
   switch(InpExecutionMode)
     {
      case EXEC_MARKET: break;
      case EXEC_STOP:   kind = 1; entry = (dir > 0 ? ask + Pts(InpPendingOffset) : bid - Pts(InpPendingOffset)); break;
      case EXEC_LIMIT:  kind = 2; entry = (dir > 0 ? bid - Pts(InpPendingOffset) : ask + Pts(InpPendingOffset)); break;
      case EXEC_RETEST:
         //--- limit at the signal candle close; market if price is already better
         if((dir > 0 && ideal < ask) || (dir < 0 && ideal > bid)) { kind = 2; entry = ideal; }
         break;
      case EXEC_HYBRID:
         if(MathAbs(mkt - ideal) <= Pts(InpHybridMaxDistance)) break;           // close enough: market
         if((dir > 0 && ideal < ask) || (dir < 0 && ideal > bid)) { kind = 2; entry = ideal; }
         else { LogDebug("Hybrid: price ran away from signal, skipped"); return false; }
         break;
     }
   if(kind != 0)
     {
      if(InpPendingOrderManagement == PEND_REPLACE) DeletePendings("replace", 0, MAGIC_MAIN);
      if(InpMaximumPendingOrders > 0 && MainPendings() >= InpMaximumPendingOrders) { LogDebug("Max pending orders"); return false; }
     }
   //--- SL / TP / lot
   double slPrice = 0;
   double lotGuess = InpFixedLot;
   double slDist = CalcSL(dir, entry, lotGuess, slPrice);
   double tpPrice = CalcTP(dir, entry, slDist);
   double tpDist = (tpPrice > 0 ? MathAbs(tpPrice - entry) : 0);
   double lot = CalcLot(slDist, tpDist);
   if(InpStopLossMode == SL_MONEY && InpEnableStopLoss)
     {
      slDist = CalcSL(dir, entry, lot, slPrice); // money SL depends on the final lot
      tpPrice = CalcTP(dir, entry, slDist);
     }
   if(lot <= 0) { g_status = "Lot below broker minimum"; return false; }
   //--- skip if minimum lot would risk far more than intended (risk modes)
   if((InpLotMode == LOT_RISK_BALANCE || InpLotMode == LOT_RISK_EQUITY || InpLotMode == LOT_RISK_FREEMARGIN) && slDist > 0)
     {
      double riskMoney = MoneyForDistance(lot, slDist);
      double allowed = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
      if(riskMoney > allowed * 1.5) { g_status = "Min lot exceeds risk budget"; LogInfo(g_status); return false; }
     }
   if(!RiskAllowsNew(dir, lot)) { g_status = "Blocked: " + g_blockReason; return false; }
   string tag = (kind == 0 ? "M" : (kind == 1 ? "S" : "L"));
   ulong res = 0;
   if(kind == 0) res = OpenMarket(dir, lot, slPrice, tpPrice, MAGIC_MAIN, tag);
   else          res = OpenPending(dir, kind == 1, entry, lot, slPrice, tpPrice, MAGIC_MAIN, tag);
   if(res == 0) return false;
   g_st.tradesToday++; g_st.lastEntryTime = TimeCurrent(); SaveState();
   EntryMarker(dir, mkt);
   Notify(StringFormat("%s %s %.2f lots (%s) SL %s TP %s", kind == 0 ? "Opened" : "Placed", dir > 0 ? "BUY" : "SELL", lot, why,
                       DoubleToString(slPrice, _Digits), DoubleToString(tpPrice, _Digits)));
   return true;
  }

//+------------------------------------------------------------------+
//| Entry engine                                                     |
//+------------------------------------------------------------------+
void TryEntry()
  {
   //--- per-bar counters
   datetime cb = iTime(_Symbol, _Period, 0);
   if(cb != g_entryCountBar) { g_entryCountBar = cb; g_entriesThisBar = 0; }
   datetime kb = iTime(_Symbol, InpCandleTF, 0);
   if(kb != g_candleCountBar) { g_candleCountBar = kb; g_entriesThisCandle = 0; }
   //--- candle module "evaluate only on a new candle"
   if(InpUseCandleEntry && InpEntryOnNewCandle && InpCandleSelection == CANDLE_BEFORE)
     {
      if(kb == g_lastCandleBar) return;
      g_lastCandleBar = kb;
     }
   string why;
   int sig = CombinedSignal(why);
   g_lastSignal = sig;
   g_lastSignalDir = sig;
   if(sig == 0) return;
   LogDebug("Signal " + (string)sig + " from " + why);
   if(!InpEnableTrading)         { g_status = "Trading disabled"; return; }
   if(!DirectionAllowed(sig))    { g_status = "Direction filter"; return; }
   if(!MTFAllows(sig))           { g_status = "MTF filter"; return; }
   if(!SessionAllows())          { g_status = "Outside session"; return; }
   if(!DayAllows())              { g_status = "Day filter"; return; }
   if(InNewsWindow())            { g_status = "News window"; return; }
   if(!SpreadAllows())           { g_status = "Spread filter"; return; }
   if(!VolatilityAllows())       { g_status = "Volatility filter"; return; }
   if(!FrequencyAllows())        { g_status = "Blocked: " + g_blockReason; return; }
   if(InpEnableGrid && g_gridStopped) { g_status = "Grid stopped"; return; }
   if(InpEnableGrid && InpGridMode == GRID_BREAKOUT) return; // the signal arms the breakout ladder
   if(InpOneTradePerBar && g_entriesThisBar >= 1) return;
   if(InpMaxTradesPerBar > 0 && g_entriesThisBar >= InpMaxTradesPerBar) return;
   if(InpUseCandleEntry && InpOneTradePerCandle && g_entriesThisCandle >= 1) return;
   string key = SignalKey(sig);
   if(InpOneTradePerSignal && key == g_lastSignalId) return;
   //--- pending orders on new signals
   if(InpPendingOrderManagement == PEND_DELETE_OPPOSITE) DeletePendings("opposite signal", -sig, MAGIC_MAIN);
   if(!HandleExisting(sig)) { g_lastSignalId = key; return; }
   if(ExecuteEntry(sig, why))
     {
      g_entriesThisBar++; g_entriesThisCandle++;
      g_lastSignalId = key;
      g_status = "Entered " + (sig > 0 ? "BUY" : "SELL");
     }
  }

//--- timing gate for entry evaluation
bool EntryClockDue()
  {
   switch(InpEntryTiming)
     {
      case TIMING_BAR_OPEN:
        {
         datetime t = iTime(_Symbol, _Period, 0);
         if(t == g_lastEntryBar) return false;
         g_lastEntryBar = t; return true;
        }
      case TIMING_BAR_CLOSE:
        {
         datetime t = iTime(_Symbol, _Period, 0);
         if(t == g_lastEntryBar) return false;
         if(TimeCurrent() < t + PeriodSeconds(_Period) - InpBarCloseSeconds) return false;
         g_lastEntryBar = t; return true;
        }
      case TIMING_EVERY_TICK: return true;
      case TIMING_TIMER:      return false; // handled in OnTimer
     }
   return false;
  }

//+------------------------------------------------------------------+
//| News actions on open positions                                   |
//+------------------------------------------------------------------+
void HandleNews()
  {
   if(!InpEnableNewsFilter) return;
   bool inNews = InNewsWindow();
   if(!inNews) { g_newsActionDone = false; return; }
   if(g_newsActionDone) return;
   switch(InpNewsAction)
     {
      case NEWS_BLOCK_NEW:      break;
      case NEWS_CLOSE_ALL:      CloseAll("news"); DeletePendings("news"); break;
      case NEWS_CLOSE_PROFIT:   CloseAll("news (profitable)", 0, -1, false, 1); break;
      case NEWS_DELETE_PENDING: DeletePendings("news"); break;
     }
   g_newsActionDone = true;
   if(InpNewsAction != NEWS_BLOCK_NEW) Notify("News window action executed");
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   SpreadSample();
   CheckNewDay();
   //--- 1) account protection first (applies to every mode)
   RiskMonitor();
   if(g_st.removeEA) { Notify("Risk limit: EA removed"); ExpertRemove(); return; }
   //--- 2) forced exits
   if(WeekendCloseDue())
     {
      SExposure e; GetExposure(e);
      if(e.total > 0 || e.pendings > 0) { CloseAll("weekend close"); DeletePendings("weekend close"); Notify("Weekend close executed"); }
     }
   HandleNews();
   if(OutsideSessionForClose()) { SExposure e2; GetExposure(e2, MAGIC_MAIN); if(e2.total > 0) CloseAll("session end", 0, MAGIC_MAIN); }
   //--- 3) management: basket -> positions (time/partial/BE/trail) -> grid -> hedge -> recovery
   ManageBasket();
   ManagePositions();
   bool canOpen = !WeekendCloseDue();
   if(canOpen) ManageGrid(g_lastSignal);
   if(canOpen) ManageHedge();
   if(canOpen && g_recoveryRuntime) ManageRecovery();
   DeleteExpiredPendings();
   //--- 4) entries
   if(canOpen && EntryClockDue()) TryEntry();
   //--- 5) dashboard (max once per second)
   if(TimeCurrent() != g_lastPanel) { g_lastPanel = TimeCurrent(); UpdatePanel(g_lastSignal); }
  }

//+------------------------------------------------------------------+
//| Timer: timer-based entries, periodic housekeeping                |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(InpEntryTiming == TIMING_TIMER && !WeekendCloseDue()) TryEntry();
   static datetime lastClean = 0;
   if(TimeCurrent() - lastClean > 3600) { lastClean = TimeCurrent(); CleanupPositionGVs(); }
   if(!g_isTester) UpdatePanel(g_lastSignal);
  }

//+------------------------------------------------------------------+
//| Trade transactions: statistics, OCO for main pendings            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   long mg = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(!IsEAMagic(mg)) return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN)
     {
      //--- OCO: a main pending filled -> remove the opposite-side main pendings
      long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      if(InpDeleteOppositePending && mg == (long)InpMagicNumber + MAGIC_MAIN)
         DeletePendings("OCO fill", dtype == DEAL_TYPE_BUY ? -1 : 1, MAGIC_MAIN);
      return;
     }
   RecordClosedDeal(trans.deal);
   double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   if(InpEnableAlerts || InpEnablePushNotification || InpEnableTelegram)
      Notify(StringFormat("Closed deal %.2f lots, P/L %.2f", HistoryDealGetDouble(trans.deal, DEAL_VOLUME), p));
  }

//+------------------------------------------------------------------+
//| Custom optimisation criterion: profit factor x recovery factor,  |
//| zero for fewer than 30 trades (avoids lucky small samples).      |
//+------------------------------------------------------------------+
double OnTester()
  {
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return 0.0;
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   double rf = TesterStatistics(STAT_RECOVERY_FACTOR);
   if(pf <= 0 || rf <= 0) return 0.0;
   return pf * rf;
  }
//+------------------------------------------------------------------+
