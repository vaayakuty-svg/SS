//+------------------------------------------------------------------+
//|                                                   UGE_Core.mqh   |
//|  Core services: logging, symbol maths, broker validation,        |
//|  position scanning, persistence and order execution with retry.  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- magic offsets: one EA owns 4 consecutive magic numbers
#define MAGIC_MAIN     0
#define MAGIC_GRID     1
#define MAGIC_HEDGE    2
#define MAGIC_RECOVERY 3

CTrade        g_trade;
CPositionInfo g_pos;
COrderInfo    g_ord;
CSymbolInfo   g_sym;

bool     g_isHedging    = true;   // account allows several positions per symbol
bool     g_isTester     = false;
string   g_gvPrefix     = "";     // global-variable namespace
datetime g_lastModify[];          // throttling (parallel to g_lastModifyTicket)
ulong    g_lastModifyTicket[];

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogError(string msg) { Print("[UGE][ERROR] ", msg); }
void LogInfo(string msg)  { if(InpLogLevel >= LOG_INFO)  Print("[UGE] ", msg); }
void LogDebug(string msg) { if(InpEnableDebugLog || InpLogLevel >= LOG_DEBUG) Print("[UGE][DBG] ", msg); }

//+------------------------------------------------------------------+
//| Symbol helpers                                                   |
//+------------------------------------------------------------------+
double SymAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double SymBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double Pts(double points) { return points * _Point; }            // points -> price distance
double ToPts(double priceDist) { return priceDist / _Point; }    // price distance -> points
int    SpreadPoints() { return (int)MathRound((SymAsk() - SymBid()) / _Point); }

//--- normalise a price to the tick size
double NormPrice(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0) ts = _Point;
   return NormalizeDouble(MathRound(price / ts) * ts, _Digits);
  }

//--- broker volume step (or user override)
double VolStep()
  {
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(InpLotStep > 0 && InpLotStep >= st) st = InpLotStep;
   return (st > 0 ? st : 0.01);
  }

//--- floor a lot to the step and clamp to broker + EA limits. 0 = cannot trade
double NormLot(double lot)
  {
   double st   = VolStep();
   double bMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double bMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lo   = MathMax(bMin, InpMinimumLot);
   double hi   = MathMin(bMax, InpMaximumLot);
   lot = MathFloor(lot / st + 1e-9) * st;
   if(lot < lo) lot = lo;
   if(lot > hi) lot = hi;
   if(lot < bMin) return 0.0;
   int dig = (int)MathMax(0, MathCeil(-MathLog10(st)));
   return NormalizeDouble(lot, dig);
  }

//--- floor only (used for partial closes), may return 0
double FloorLot(double lot)
  {
   double st = VolStep();
   int dig = (int)MathMax(0, MathCeil(-MathLog10(st)));
   return NormalizeDouble(MathFloor(lot / st + 1e-9) * st, dig);
  }

//--- money value of a price move of 'dist' for 'lots' (uses OrderCalcProfit, fallback tick value)
double MoneyForDistance(double lots, double dist)
  {
   if(lots <= 0 || dist <= 0) return 0.0;
   double p = 0, price = SymAsk();
   if(OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, lots, price, price + dist, p) && p > 0)
      return p;
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0) return 0.0;
   return lots * dist / ts * tv;
  }

//--- price distance that equals 'money' for 'lots'
double DistanceForMoney(double lots, double money)
  {
   double perUnit = MoneyForDistance(lots, 1000 * _Point);
   if(perUnit <= 0) return 0.0;
   return money / perUnit * 1000 * _Point;
  }

int StopsLevelPts()  { return (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); }
int FreezeLevelPts() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL); }

//+------------------------------------------------------------------+
//| Ownership of positions/orders                                    |
//+------------------------------------------------------------------+
bool IsEAMagic(long magic)
  {
   return (magic >= (long)InpMagicNumber && magic <= (long)InpMagicNumber + 3);
  }

//--- position belongs to the EA (always magic + symbol)
bool IsOwnPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol && IsEAMagic(PositionGetInteger(POSITION_MAGIC)));
  }

//--- position included in risk/basket scope
bool InRiskScope()
  {
   string sym = PositionGetString(POSITION_SYMBOL);
   long   mg  = PositionGetInteger(POSITION_MAGIC);
   if(InpPositionManagement == PSCOPE_ALL) return true;
   if(sym != _Symbol) return false;
   if(InpPositionManagement == PSCOPE_SYMBOL) return true;
   if(IsEAMagic(mg)) return true;
   return (InpIncludeManualTrades && mg == 0);
  }

double PosNetProfit() { return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); }

//+------------------------------------------------------------------+
//| Exposure snapshot                                                |
//+------------------------------------------------------------------+
struct SExposure
  {
   int      buys, sells, total;
   int      byMagic[4];
   double   buyLots, sellLots;
   double   buyProfit, sellProfit, profit;
   double   buyAvg, sellAvg;
   double   lowestBuy, highestBuy, lowestSell, highestSell;
   double   lastBuyLot, lastSellLot;
   double   firstBuyLot, firstSellLot;
   datetime firstOpen;
   int      pendings;
  };

//--- scan EA positions (magic offsets filter: -1 = all EA magics)
void GetExposure(SExposure &e, int magicOffset = -1, bool riskScope = false)
  {
   ZeroMemory(e);
   e.lowestBuy = DBL_MAX; e.lowestSell = DBL_MAX;
   e.firstOpen = 0;
   datetime lastB = 0, lastS = 0, firstB = D'3000.01.01', firstS = D'3000.01.01';
   double sumB = 0, sumS = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(riskScope) { if(!InRiskScope()) continue; }
      else if(!IsOwnPosition()) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(magicOffset >= 0 && mg != (long)InpMagicNumber + magicOffset) continue;
      if(IsEAMagic(mg)) e.byMagic[(int)(mg - (long)InpMagicNumber)]++;
      double v  = PositionGetDouble(POSITION_VOLUME);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double pr = PosNetProfit();
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(e.firstOpen == 0 || ot < e.firstOpen) e.firstOpen = ot;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         e.buys++; e.buyLots += v; e.buyProfit += pr; sumB += v * op;
         e.lowestBuy = MathMin(e.lowestBuy, op); e.highestBuy = MathMax(e.highestBuy, op);
         if(ot >= lastB) { lastB = ot; e.lastBuyLot = v; }
         if(ot <= firstB) { firstB = ot; e.firstBuyLot = v; }
        }
      else
        {
         e.sells++; e.sellLots += v; e.sellProfit += pr; sumS += v * op;
         e.lowestSell = MathMin(e.lowestSell, op); e.highestSell = MathMax(e.highestSell, op);
         if(ot >= lastS) { lastS = ot; e.lastSellLot = v; }
         if(ot <= firstS) { firstS = ot; e.firstSellLot = v; }
        }
     }
   e.total  = e.buys + e.sells;
   e.profit = e.buyProfit + e.sellProfit;
   e.buyAvg = (e.buyLots > 0 ? sumB / e.buyLots : 0);
   e.sellAvg= (e.sellLots > 0 ? sumS / e.sellLots : 0);
   if(e.lowestBuy == DBL_MAX) e.lowestBuy = 0;
   if(e.lowestSell == DBL_MAX) e.lowestSell = 0;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      ulong ot2 = OrderGetTicket(j);
      if(ot2 == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && IsEAMagic(OrderGetInteger(ORDER_MAGIC))) e.pendings++;
     }
  }

//+------------------------------------------------------------------+
//| Persistence (global variables survive restarts)                  |
//+------------------------------------------------------------------+
string GVName(string key) { return g_gvPrefix + key; }
double GVGet(string key, double def = 0.0)
  {
   string n = GVName(key);
   if(!GlobalVariableCheck(n)) return def;
   return GlobalVariableGet(n);
  }
void GVSet(string key, double val) { GlobalVariableSet(GVName(key), val); }
void GVDel(string key) { string n = GVName(key); if(GlobalVariableCheck(n)) GlobalVariableDel(n); }

//+------------------------------------------------------------------+
//| Filling mode                                                     |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING ResolveFilling()
  {
   long flags = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   long exe   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
   if(InpFillingMode == FILL_FOK && (flags & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if(InpFillingMode == FILL_IOC && (flags & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   if(InpFillingMode == FILL_RETURN && exe != SYMBOL_TRADE_EXECUTION_MARKET) return ORDER_FILLING_RETURN;
   if(InpFillingMode != FILL_AUTO) LogInfo("Requested filling mode not allowed by broker - using automatic");
   if((flags & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((flags & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//+------------------------------------------------------------------+
//| Stop / freeze level validation                                   |
//+------------------------------------------------------------------+
//--- push SL/TP out to the minimum distance allowed by the broker
void ValidateStops(int dir, double entry, double &sl, double &tp)
  {
   if(!InpStopLevelProtection) return;
   //--- stops level 0 means "floating": use the current spread as the safe minimum
   double minD = (StopsLevelPts() > 0 ? Pts(StopsLevelPts() + 1) : Pts(SpreadPoints() + 1));
   if(dir > 0)
     {
      if(sl > 0 && entry - sl < minD) sl = entry - minD;
      if(tp > 0 && tp - entry < minD) tp = entry + minD;
     }
   else
     {
      if(sl > 0 && sl - entry < minD) sl = entry + minD;
      if(tp > 0 && entry - tp < minD) tp = entry - minD;
     }
   if(sl > 0) sl = NormPrice(sl);
   if(tp > 0) tp = NormPrice(tp);
  }

//--- true if the position's current SL/TP are inside the freeze level (no modification allowed)
bool FrozenNow(int posType, double curSL, double curTP)
  {
   if(!InpFreezeLevelProtection) return false;
   int fz = FreezeLevelPts();
   if(fz <= 0) return false;
   double fd = Pts(fz);
   double px = (posType == POSITION_TYPE_BUY ? SymBid() : SymAsk());
   if(curSL > 0 && MathAbs(px - curSL) <= fd) return true;
   if(curTP > 0 && MathAbs(px - curTP) <= fd) return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Margin validation                                                |
//+------------------------------------------------------------------+
//--- reduce lot until it fits the free margin (keeps 10% reserve). 0 = cannot fit
double FitMargin(int dir, double lot)
  {
   double price = (dir > 0 ? SymAsk() : SymBid());
   ENUM_ORDER_TYPE t = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9;
   double st = VolStep();
   double bMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   for(int k = 0; k < 200 && lot >= bMin; k++)
     {
      double m = 0;
      if(!OrderCalcMargin(t, _Symbol, lot, price, m)) return lot; // cannot calculate: let server decide
      if(m <= free) return lot;
      if(!InpEnableDynamicLot) return 0.0;
      lot = FloorLot(lot - st);
     }
   return 0.0;
  }

//--- broker volume limit for one direction
bool VolumeLimitOK(double addLots)
  {
   double lim = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(lim <= 0) return true;
   SExposure e; GetExposure(e);
   return (e.buyLots + e.sellLots + addLots <= lim);
  }

//+------------------------------------------------------------------+
//| Retry helpers                                                    |
//+------------------------------------------------------------------+
bool IsRetryable(uint rc)
  {
   return (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TOO_MANY_REQUESTS ||
           rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION ||
           rc == TRADE_RETCODE_LOCKED);
  }

bool IsSuccess(uint rc)
  {
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL ||
           rc == TRADE_RETCODE_PLACED || (InpExecutionPolicy == EPOL_ASYNC && rc == TRADE_RETCODE_DONE));
  }

void RetryWait(int attempt)
  {
   if(g_isTester || InpOrderRetryMode == RETRY_NONE) return;
   int ms = InpRetryDelayMilliseconds;
   if(InpOrderRetryMode == RETRY_EXPONENTIAL) ms = (int)(InpRetryDelayMilliseconds * MathPow(2, attempt));
   Sleep(MathMin(ms, 3000)); // bounded wait between attempts
  }

int MaxAttempts()
  {
   if(!InpRetryFailedOrders || InpOrderRetryMode == RETRY_NONE) return 1;
   return 1 + MathMax(0, MathMin(InpRetryCount, InpMaxOrderRetries));
  }

//--- set magic before every request
void UseMagic(int offset) { g_trade.SetExpertMagicNumber(InpMagicNumber + offset); }

//+------------------------------------------------------------------+
//| Market order with validation and retries                         |
//+------------------------------------------------------------------+
ulong OpenMarket(int dir, double lot, double sl, double tp, int magicOffset, string tag)
  {
   if(dir == 0) return 0;
   lot = NormLot(lot);
   lot = FitMargin(dir, lot);
   if(lot <= 0) { LogInfo("Order skipped: lot 0 after margin/volume validation"); return 0; }
   if(!VolumeLimitOK(lot)) { LogInfo("Order skipped: symbol volume limit"); return 0; }
   UseMagic(magicOffset);
   string cmt = StringSubstr(InpTradeComment + "|" + tag, 0, 31);
   int dev = InpMaximumSlippage;
   for(int a = 0; a < MaxAttempts(); a++)
     {
      double price = (dir > 0 ? SymAsk() : SymBid());
      double s = sl, t = tp;
      ValidateStops(dir, price, s, t);
      g_trade.SetDeviationInPoints(dev);
      bool ok = (dir > 0) ? g_trade.Buy(lot, _Symbol, price, s, t, cmt)
                          : g_trade.Sell(lot, _Symbol, price, s, t, cmt);
      uint rc = g_trade.ResultRetcode();
      if(ok && IsSuccess(rc))
        {
         double fill = g_trade.ResultPrice();
         if(fill > 0)
           {
            int slip = (int)MathRound(MathAbs(fill - price) / _Point);
            if(slip > InpMaximumSlippagePoints)
              {
               LogInfo(StringFormat("Slippage %d pts exceeds max %d", slip, InpMaximumSlippagePoints));
               if(InpCloseOnExcessSlippage && g_trade.ResultDeal() > 0)
                 {
                  if(HistoryDealSelect(g_trade.ResultDeal()))
                    {
                     ulong posId = (ulong)HistoryDealGetInteger(g_trade.ResultDeal(), DEAL_POSITION_ID);
                     g_trade.PositionClose(posId, InpMaximumSlippage);
                    }
                  return 0;
                 }
              }
           }
         LogInfo(StringFormat("%s %.2f @ %s SL=%s TP=%s [%s]", dir > 0 ? "BUY" : "SELL", lot,
                              DoubleToString(price, _Digits), DoubleToString(s, _Digits), DoubleToString(t, _Digits), tag));
         ulong res = g_trade.ResultOrder();
         if(g_trade.ResultDeal() > 0 && HistoryDealSelect(g_trade.ResultDeal()))
            res = (ulong)HistoryDealGetInteger(g_trade.ResultDeal(), DEAL_POSITION_ID);
         return res;
        }
      LogError(StringFormat("Open %s failed: %u %s (attempt %d)", dir > 0 ? "BUY" : "SELL", rc,
                            g_trade.ResultRetcodeDescription(), a + 1));
      if(!IsRetryable(rc)) break;
      if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED)
        {
         if(InpRequoteHandling == REQ_ABORT) break;
         if(InpRequoteHandling == REQ_WIDEN) dev = dev * 2;
        }
      RetryWait(a);
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Pending order (stop/limit) with validation                       |
//+------------------------------------------------------------------+
ulong OpenPending(int dir, bool isStop, double price, double lot, double sl, double tp, int magicOffset, string tag)
  {
   lot = NormLot(lot);
   lot = FitMargin(dir, lot);
   if(lot <= 0) return 0;
   UseMagic(magicOffset);
   string cmt = StringSubstr(InpTradeComment + "|" + tag, 0, 31);
   double minD = Pts(MathMax(StopsLevelPts(), SpreadPoints()) + 1);
   double ask = SymAsk(), bid = SymBid();
   //--- keep pending price legal relative to market
   if(dir > 0 &&  isStop && price < ask + minD) price = ask + minD;
   if(dir > 0 && !isStop && price > bid - minD) price = bid - minD;
   if(dir < 0 &&  isStop && price > bid - minD) price = bid - minD;
   if(dir < 0 && !isStop && price < ask + minD) price = ask + minD;
   price = NormPrice(price);
   double s = sl, t = tp;
   ValidateStops(dir, price, s, t);
   datetime exp = 0;
   ENUM_ORDER_TYPE_TIME tt = ORDER_TIME_GTC;
   if(InpOrderExpirationMin > 0)
     {
      exp = TimeCurrent() + InpOrderExpirationMin * 60;
      long modes = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
      if((modes & SYMBOL_EXPIRATION_SPECIFIED) != 0) tt = ORDER_TIME_SPECIFIED;
      else exp = 0; // broker lacks specified expiry: the EA deletes expired orders itself
     }
   bool ok = false;
   for(int a = 0; a < MaxAttempts() && !ok; a++)
     {
      if(dir > 0) ok = isStop ? g_trade.BuyStop(lot, price, _Symbol, s, t, tt, exp, cmt)
                              : g_trade.BuyLimit(lot, price, _Symbol, s, t, tt, exp, cmt);
      else        ok = isStop ? g_trade.SellStop(lot, price, _Symbol, s, t, tt, exp, cmt)
                              : g_trade.SellLimit(lot, price, _Symbol, s, t, tt, exp, cmt);
      uint rc = g_trade.ResultRetcode();
      ok = ok && IsSuccess(rc);
      if(!ok)
        {
         LogError(StringFormat("Pending failed: %u %s", rc, g_trade.ResultRetcodeDescription()));
         if(!IsRetryable(rc)) break;
         RetryWait(a);
        }
     }
   if(!ok) return 0;
   if(InpOrderExpirationMin > 0 && tt == ORDER_TIME_GTC)
      GVSet("exp_" + (string)g_trade.ResultOrder(), (double)(TimeCurrent() + InpOrderExpirationMin * 60));
   LogInfo(StringFormat("Pending %s %s %.2f @ %s [%s]", dir > 0 ? "BUY" : "SELL", isStop ? "STOP" : "LIMIT",
                        lot, DoubleToString(price, _Digits), tag));
   return g_trade.ResultOrder();
  }

//+------------------------------------------------------------------+
//| Modification with throttling, stops and freeze level checks      |
//+------------------------------------------------------------------+
bool ThrottleOK(ulong ticket)
  {
   if(InpOrderModificationMode == MOD_IMMEDIATE) return true;
   int n = ArraySize(g_lastModifyTicket);
   for(int i = 0; i < n; i++)
      if(g_lastModifyTicket[i] == ticket)
         return (TimeCurrent() - g_lastModify[i] >= InpModifyMinSeconds);
   return true;
  }
void ThrottleMark(ulong ticket)
  {
   int n = ArraySize(g_lastModifyTicket);
   for(int i = 0; i < n; i++)
      if(g_lastModifyTicket[i] == ticket) { g_lastModify[i] = TimeCurrent(); return; }
   if(n > 500) { ArrayResize(g_lastModifyTicket, 0); ArrayResize(g_lastModify, 0); n = 0; }
   ArrayResize(g_lastModifyTicket, n + 1); ArrayResize(g_lastModify, n + 1);
   g_lastModifyTicket[n] = ticket; g_lastModify[n] = TimeCurrent();
  }

//--- modify SL/TP of a selected position. Only improves SL when improveOnly.
bool ModifyPosition(ulong ticket, double newSL, double newTP, bool improveOnly = true)
  {
   if(!PositionSelectByTicket(ticket)) return false;
   int    pt  = (int)PositionGetInteger(POSITION_TYPE);
   double cSL = PositionGetDouble(POSITION_SL);
   double cTP = PositionGetDouble(POSITION_TP);
   newSL = (newSL > 0 ? NormPrice(newSL) : cSL);
   newTP = (newTP >= 0 ? (newTP > 0 ? NormPrice(newTP) : 0) : cTP);
   if(improveOnly && cSL > 0 && newSL > 0)
     {
      if(pt == POSITION_TYPE_BUY  && newSL <= cSL) newSL = cSL;
      if(pt == POSITION_TYPE_SELL && newSL >= cSL) newSL = cSL;
     }
   double minStep = (InpOrderModificationMode == MOD_THROTTLED ? Pts(InpModifyMinStep) : _Point * 0.5);
   bool slChange = (MathAbs(newSL - cSL) >= minStep) || (cSL == 0 && newSL > 0);
   bool tpChange = (MathAbs(newTP - cTP) >= _Point * 0.5);
   if(!slChange && !tpChange) return false;
   if(!ThrottleOK(ticket)) return false;
   if(FrozenNow(pt, cSL, cTP)) { LogDebug("Modify skipped: freeze level"); return false; }
   //--- stops level: new SL must be at legal distance from the current price
   double px = (pt == POSITION_TYPE_BUY ? SymBid() : SymAsk());
   double minD = Pts(MathMax(StopsLevelPts(), 1));
   if(InpStopLevelProtection && newSL > 0)
     {
      if(pt == POSITION_TYPE_BUY  && px - newSL < minD) return false;
      if(pt == POSITION_TYPE_SELL && newSL - px < minD) return false;
     }
   if(InpStopLevelProtection && newTP > 0)
     {
      if(pt == POSITION_TYPE_BUY  && newTP - px < minD) newTP = cTP;
      if(pt == POSITION_TYPE_SELL && px - newTP < minD) newTP = cTP;
     }
   UseMagic((int)(PositionGetInteger(POSITION_MAGIC) - (long)InpMagicNumber));
   bool ok = g_trade.PositionModify(ticket, newSL, newTP);
   ThrottleMark(ticket);
   if(!ok || !IsSuccess(g_trade.ResultRetcode()))
     {
      LogDebug(StringFormat("Modify #%I64u failed: %u %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      return false;
     }
   LogDebug(StringFormat("Modified #%I64u SL=%s TP=%s", ticket, DoubleToString(newSL, _Digits), DoubleToString(newTP, _Digits)));
   return true;
  }

//+------------------------------------------------------------------+
//| Closing helpers                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string why)
  {
   if(!PositionSelectByTicket(ticket)) return false;
   if(InpRestartRecoveryMode == RESTART_IGNORE && GVGet("ign_" + (string)ticket, 0) > 0) return false;
   for(int a = 0; a < MaxAttempts(); a++)
     {
      g_trade.SetDeviationInPoints(InpMaximumSlippage * (a + 1));
      if(g_trade.PositionClose(ticket) && IsSuccess(g_trade.ResultRetcode()))
        {
         LogInfo(StringFormat("Closed #%I64u (%s)", ticket, why));
         return true;
        }
      if(!IsRetryable(g_trade.ResultRetcode())) break;
      RetryWait(a);
     }
   LogError(StringFormat("Close #%I64u failed: %u %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   return false;
  }

bool ClosePartial(ulong ticket, double vol, string why)
  {
   vol = FloorLot(vol);
   if(vol < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return false;
   for(int a = 0; a < MaxAttempts(); a++)
     {
      if(g_trade.PositionClosePartial(ticket, vol, InpMaximumSlippage) && IsSuccess(g_trade.ResultRetcode()))
        {
         LogInfo(StringFormat("Partial close #%I64u %.2f (%s)", ticket, vol, why));
         return true;
        }
      if(!IsRetryable(g_trade.ResultRetcode())) break;
      RetryWait(a);
     }
   LogError(StringFormat("Partial close failed: %u", g_trade.ResultRetcode()));
   return false;
  }

//--- close positions. dirFilter: 0 all, 1 buys, -1 sells. magicOffset -1 = all EA magics.
//--- riskScope=true also closes positions in the configured risk scope (symbol/all/manual).
int CloseAll(string why, int dirFilter = 0, int magicOffset = -1, bool riskScope = false, int onlyPL = 0)
  {
   ulong  tk[]; double pr[];
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(riskScope) { if(!InRiskScope()) continue; }
      else if(!IsOwnPosition()) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(magicOffset >= 0 && mg != (long)InpMagicNumber + magicOffset) continue;
      int pt = (int)PositionGetInteger(POSITION_TYPE);
      if(dirFilter > 0 && pt != POSITION_TYPE_BUY) continue;
      if(dirFilter < 0 && pt != POSITION_TYPE_SELL) continue;
      double p = PosNetProfit();
      if(onlyPL > 0 && p <= 0) continue;
      if(onlyPL < 0 && p >= 0) continue;
      ArrayResize(tk, n + 1); ArrayResize(pr, n + 1);
      tk[n] = t; pr[n] = p; n++;
     }
   //--- order: losers first / winners first
   if(InpPositionCloseMode != CLOSE_ANY_ORDER)
      for(int a = 0; a < n - 1; a++)
         for(int b = a + 1; b < n; b++)
           {
            bool swap = (InpPositionCloseMode == CLOSE_LOSERS_FIRST) ? (pr[b] < pr[a]) : (pr[b] > pr[a]);
            if(swap) { double x = pr[a]; pr[a] = pr[b]; pr[b] = x; ulong y = tk[a]; tk[a] = tk[b]; tk[b] = y; }
           }
   int closed = 0;
   for(int k = 0; k < n; k++)
     {
      if(!PositionSelectByTicket(tk[k])) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym != _Symbol)
        {
         //--- other symbol (scope ALL): close via generic request
         if(g_trade.PositionClose(tk[k], InpMaximumSlippage)) closed++;
         continue;
        }
      if(ClosePosition(tk[k], why)) closed++;
     }
   return closed;
  }

//--- delete EA pendings. dirFilter: 0 all, 1 buy-side, -1 sell-side
int DeletePendings(string why, int dirFilter = 0, int magicOffset = -1)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || !IsEAMagic(OrderGetInteger(ORDER_MAGIC))) continue;
      if(magicOffset >= 0 && OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber + magicOffset) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool isBuy = (ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_BUY_STOP || ty == ORDER_TYPE_BUY_STOP_LIMIT);
      if(dirFilter > 0 && !isBuy) continue;
      if(dirFilter < 0 && isBuy) continue;
      if(g_trade.OrderDelete(t)) { n++; GVDel("exp_" + (string)t); }
     }
   if(n > 0) LogInfo(StringFormat("Deleted %d pending orders (%s)", n, why));
   return n;
  }

//--- delete pendings whose EA-side expiry passed
void DeleteExpiredPendings()
  {
   if(!InpDeleteExpiredOrders || InpOrderExpirationMin <= 0) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || !IsEAMagic(OrderGetInteger(ORDER_MAGIC))) continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      double ex = GVGet("exp_" + (string)t, 0);
      datetime limit = (ex > 0 ? (datetime)ex : setup + InpOrderExpirationMin * 60);
      if(TimeCurrent() >= limit && g_trade.OrderDelete(t)) { GVDel("exp_" + (string)t); LogInfo("Expired pending deleted"); }
     }
  }
//+------------------------------------------------------------------+
