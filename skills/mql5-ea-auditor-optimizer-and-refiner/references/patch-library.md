# Patch library: MetaEditor-style guardrails

Drop-in functions for common fixes. All names start with `AF_` (audit fix) so they never collide with the
user's code. Copy only what a finding needs, mark each use with `// [AUDIT-FIX #n]`, and keep the user's inputs.
Every block needs `#include <Trade\Trade.mqh>` and a `CTrade` object (`AF_trade` below, or the EA's own).

```mql5
#include <Trade\Trade.mqh>
CTrade AF_trade;   // [AUDIT-FIX] use the EA's existing CTrade if it has one
```

## 1. New-bar gate (stops tick overtrading)

```mql5
//--- true once per new bar of 'tf' (call at the top of the entry block)
bool AF_IsNewBar(const ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
  {
   static datetime last = 0;
   datetime t = iTime(_Symbol, tf, 0);
   if(t == 0 || t == last) return false;
   last = t;
   return true;
  }
```
(One static per function: for several timeframes, keep one `datetime` per timeframe in the caller.)

## 2. Lot normalization and risk lot

```mql5
//--- floor to volume step and clamp to broker min/max; 0 = cannot trade
double AF_NormalizeLot(double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < vmin) return 0.0;
   if(lot > vmax) lot = vmax;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lot, digits);
  }

//--- lot that loses 'riskPct' % of equity if price moves 'slDistance' (price units) against the trade
double AF_RiskLot(const double riskPct, const double slDistance)
  {
   if(slDistance <= 0 || riskPct <= 0) return 0.0;
   double money = AccountInfoDouble(ACCOUNT_EQUITY) * riskPct / 100.0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK), perLot = 0.0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, price, price + slDistance, perLot) || perLot <= 0)
     {
      double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tv <= 0 || ts <= 0) return 0.0;
      perLot = slDistance / ts * tv;
     }
   return AF_NormalizeLot(money / perLot);
  }
```

## 3. Margin fit

```mql5
//--- reduce the lot until it fits 90% of free margin; 0 = does not fit even at the minimum
double AF_FitMargin(const ENUM_ORDER_TYPE type, double lot)
  {
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double free  = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9;
   while(lot >= vmin)
     {
      double m = 0.0;
      if(!OrderCalcMargin(type, _Symbol, lot, price, m)) return lot;   // cannot calculate: let the server decide
      if(m <= free) return lot;
      lot = AF_NormalizeLot(lot - step);
      if(lot <= 0) break;
     }
   return 0.0;
  }
```

## 4. Spread gate

```mql5
//--- false when the current spread is above maxPoints (0 = no limit)
bool AF_SpreadOK(const int maxPoints)
  {
   if(maxPoints <= 0) return true;
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (sp <= maxPoints);
  }
```

## 5. Stops / freeze level safe SL-TP

```mql5
//--- move SL/TP out to the broker's minimum distance; dir +1 buy, -1 sell
void AF_ValidateStops(const int dir, const double entry, double &sl, double &tp)
  {
   int    lvl  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long   sprd = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double minD = (lvl > 0 ? lvl : (int)sprd) * _Point + _Point;
   if(sl > 0) sl = (dir > 0) ? MathMin(sl, entry - minD) : MathMax(sl, entry + minD);
   if(tp > 0) tp = (dir > 0) ? MathMax(tp, entry + minD) : MathMin(tp, entry - minD);
   if(sl > 0) sl = NormalizeDouble(sl, _Digits);
   if(tp > 0) tp = NormalizeDouble(tp, _Digits);
  }

//--- true if a selected position's SL/TP is inside the freeze level (no modification allowed now)
bool AF_Frozen(const long posType, const double sl, const double tp)
  {
   int fz = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(fz <= 0) return false;
   double px = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ((sl > 0 && MathAbs(px - sl) <= fz * _Point) || (tp > 0 && MathAbs(px - tp) <= fz * _Point));
  }
```

## 6. Retry sender

```mql5
//--- market order with retries on transient errors; returns true on success
bool AF_SendMarket(const int dir, const double lot, double sl, double tp, const string cmt, const ulong magic, const int deviation = 30)
  {
   AF_trade.SetExpertMagicNumber(magic);
   AF_trade.SetDeviationInPoints(deviation);
   for(int attempt = 0; attempt < 3; attempt++)
     {
      double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double s = sl, t = tp;
      AF_ValidateStops(dir, price, s, t);
      bool ok = (dir > 0) ? AF_trade.Buy(lot, _Symbol, price, s, t, cmt) : AF_trade.Sell(lot, _Symbol, price, s, t, cmt);
      uint rc = AF_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL)) return true;
      PrintFormat("[AUDIT] order failed: %u %s (attempt %d)", rc, AF_trade.ResultRetcodeDescription(), attempt + 1);
      if(rc != TRADE_RETCODE_REQUOTE && rc != TRADE_RETCODE_PRICE_CHANGED && rc != TRADE_RETCODE_PRICE_OFF &&
         rc != TRADE_RETCODE_TIMEOUT && rc != TRADE_RETCODE_CONNECTION && rc != TRADE_RETCODE_TOO_MANY_REQUESTS) break;
      if(!MQLInfoInteger(MQL_TESTER)) Sleep(300 * (attempt + 1));
     }
   return false;
  }
```

## 7. Safe position loop (magic + symbol, backwards)

```mql5
//--- close every position of this EA on this symbol (backwards loop: safe while closing)
void AF_CloseAll(const ulong magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(!AF_trade.PositionClose(t)) PrintFormat("[AUDIT] close #%I64u failed: %u", t, AF_trade.ResultRetcode());
     }
  }
```

## 8. Daily loss and equity drawdown guard (persisted)

```mql5
//--- call first in OnTick; returns false when new trades must be blocked
bool AF_RiskGuard(const ulong magic, const double maxDailyLossPct, const double maxDDPct, const bool closeOnBreach)
  {
   string k = "AF_" + (string)magic + "_" + _Symbol + "_";
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime d; TimeToStruct(TimeCurrent(), d); d.hour = 0; d.min = 0; d.sec = 0;
   double today = (double)StructToTime(d);
   if(GlobalVariableGet(k + "day") != today)                 // new server day
     { GlobalVariableSet(k + "day", today); GlobalVariableSet(k + "dayEq", eq); GlobalVariableSet(k + "dayHalt", 0); }
   if(eq > GlobalVariableGet(k + "peak")) GlobalVariableSet(k + "peak", eq);
   if(GlobalVariableGet(k + "ddHalt") > 0 || GlobalVariableGet(k + "dayHalt") > 0) return false;
   double dayEq = GlobalVariableGet(k + "dayEq"), peak = GlobalVariableGet(k + "peak");
   bool dayHit = (maxDailyLossPct > 0 && dayEq > 0 && (dayEq - eq) / dayEq * 100.0 >= maxDailyLossPct);
   bool ddHit  = (maxDDPct > 0 && peak > 0 && (peak - eq) / peak * 100.0 >= maxDDPct);
   if(!dayHit && !ddHit) return true;
   GlobalVariableSet(k + (ddHit ? "ddHalt" : "dayHalt"), 1);  // ddHalt stays until the user deletes the global variable
   PrintFormat("[AUDIT] risk limit hit: daily=%s dd=%s", dayHit ? "yes" : "no", ddHit ? "yes" : "no");
   if(closeOnBreach) AF_CloseAll(magic);
   return false;
  }
```
In the tester, delete the `AF_*` global variables in `OnInit` when `MQLInfoInteger(MQL_TESTER)` is true, so every
pass starts fresh.

## 9. Restart re-scan

```mql5
//--- in OnInit: rebuild counters from open positions instead of trusting globals
int AF_CountOwn(const ulong magic, const long type = -1)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(type >= 0 && PositionGetInteger(POSITION_TYPE) != type) continue;
      n++;
     }
   return n;
  }
```

## 10. Filling mode

```mql5
//--- pick a filling mode the symbol supports
ENUM_ORDER_TYPE_FILLING AF_Filling()
  {
   long f = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }
// OnInit: AF_trade.SetTypeFilling(AF_Filling());
```

## 11. `OnTester` custom criterion (optimization criterion 6)

```mql5
//--- profit factor x recovery factor; 0 when too few trades or losing (keeps curve-fit passes out)
double OnTester()
  {
   double trades = TesterStatistics(STAT_TRADES);
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double rf     = TesterStatistics(STAT_RECOVERY_FACTOR);
   double dd     = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   if(trades < 100 || pf <= 1.0 || rf <= 0) return 0.0;
   if(dd > 30.0) return 0.0;                                 // reject passes that need a deep drawdown
   return pf * rf;
  }
```
Add it only if the EA has no `OnTester()`; never replace the user's own.

## 12. Indicator handle lifecycle

```mql5
int AF_hATR = INVALID_HANDLE;
// OnInit:
//   AF_hATR = iATR(_Symbol, PERIOD_CURRENT, 14);
//   if(AF_hATR == INVALID_HANDLE) return INIT_FAILED;
// OnDeinit:
//   if(AF_hATR != INVALID_HANDLE) IndicatorRelease(AF_hATR);
//--- closed-bar value (shift >= 1 avoids repaint); EMPTY_VALUE on failure
double AF_Buf(const int handle, const int buffer, const int shift)
  {
   double v[1];
   if(handle == INVALID_HANDLE || CopyBuffer(handle, buffer, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
  }
```
