//+------------------------------------------------------------------+
//|                                                       SaveEA.mq5 |
//|  Tick-momentum scalper for XAUUSD M1 with tight SL and trailing. |
//|  Opens small fixed/risk-based positions in the direction of a    |
//|  short burst of tick momentum, protects them with a tight stop   |
//|  and trails aggressively to lock in profit.                      |
//+------------------------------------------------------------------+
#property copyright "SaveEA"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Money management
input group "Money management"
input double InpLots              = 0.01;   // Fixed lot size (used when risk % = 0)
input double InpRiskPercent       = 0.0;    // Risk % of equity per trade (0 = fixed lots)
input double InpMaxLots           = 1.00;   // Maximum lot size cap

//--- Entry
input group "Entry (tick momentum)"
input int    InpMomentumSeconds   = 10;     // Look-back window in seconds
input int    InpTriggerPoints     = 60;     // Min price move in window to trigger (points)
input int    InpCooldownSeconds   = 15;     // Min seconds between new entries
input bool   InpAllowBuy          = true;   // Allow buy trades
input bool   InpAllowSell         = true;   // Allow sell trades
input int    InpMaxPositions      = 3;      // Max simultaneous positions (this EA)

//--- Exit
input group "Exit"
input int    InpStopLossPoints    = 250;    // Initial stop loss (points)
input int    InpTakeProfitPoints  = 0;      // Take profit (points, 0 = trailing only)
input int    InpBreakEvenPoints   = 40;     // Move SL to break-even after (points, 0 = off)
input int    InpBreakEvenLock     = 5;      // Points locked at break-even
input int    InpTrailStartPoints  = 60;     // Start trailing after profit (points)
input int    InpTrailDistance     = 50;     // Trailing distance (points)
input int    InpTrailStepPoints   = 10;     // Min SL improvement per modify (points)
input int    InpMaxHoldMinutes    = 30;     // Close position after N minutes (0 = off)

//--- Filters & protection
input group "Filters & protection"
input int    InpMaxSpreadPoints   = 40;     // Max spread to open trades (points)
input int    InpStartHour         = 1;      // Trading start hour (server time)
input int    InpEndHour           = 23;     // Trading end hour (server time)
input double InpDailyLossPercent  = 10.0;   // Stop for the day after this % loss (0 = off)
input double InpDailyTargetPercent= 0.0;    // Stop for the day after this % gain (0 = off)
input int    InpSlippagePoints    = 20;     // Max slippage (points)
input ulong  InpMagic             = 20261025; // Magic number
input string InpComment           = "SaveEA";  // Order comment

//--- Globals
CTrade        trade;
CPositionInfo pos;

#define BUF_SIZE 4096
double   g_bid[BUF_SIZE];
long     g_msc[BUF_SIZE];
int      g_head  = 0;
int      g_count = 0;

datetime g_lastEntry     = 0;
datetime g_dayStart      = 0;
double   g_dayStartEquity = 0.0;
bool     g_dayHalted     = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpStopLossPoints <= 0 || InpTriggerPoints <= 0 || InpMomentumSeconds <= 0)
     {
      Print("SaveEA: stop loss, trigger and momentum window must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   ResetDay();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   PushTick(tick.bid, tick.time_msc);
   ManagePositions(tick);

   if(!CheckDay())
      return;
   if(!InTradingHours(tick.time))
      return;

   long spread = (long)MathRound((tick.ask - tick.bid) / _Point);
   if(spread > InpMaxSpreadPoints)
      return;
   if(tick.time - g_lastEntry < InpCooldownSeconds)
      return;
   if(CountPositions() >= InpMaxPositions)
      return;

   int signal = MomentumSignal(tick);
   if(signal > 0 && InpAllowBuy)
      OpenTrade(ORDER_TYPE_BUY, tick);
   else if(signal < 0 && InpAllowSell)
      OpenTrade(ORDER_TYPE_SELL, tick);
  }

//+------------------------------------------------------------------+
//| Ring buffer of recent bid prices                                 |
//+------------------------------------------------------------------+
void PushTick(const double bid, const long msc)
  {
   g_bid[g_head] = bid;
   g_msc[g_head] = msc;
   g_head = (g_head + 1) % BUF_SIZE;
   if(g_count < BUF_SIZE)
      g_count++;
  }

//+------------------------------------------------------------------+
//| +1 = upward burst, -1 = downward burst, 0 = none                 |
//+------------------------------------------------------------------+
int MomentumSignal(const MqlTick &tick)
  {
   if(g_count < 2)
      return(0);

   long   from = tick.time_msc - (long)InpMomentumSeconds * 1000;
   double hi = tick.bid, lo = tick.bid;
   double oldest = tick.bid;
   bool   covered = false;

   for(int i = 1; i <= g_count; i++)
     {
      int idx = (g_head - i + BUF_SIZE) % BUF_SIZE;
      if(g_msc[idx] < from)
        {
         covered = true;
         break;
        }
      oldest = g_bid[idx];
      hi = MathMax(hi, g_bid[idx]);
      lo = MathMin(lo, g_bid[idx]);
     }
   if(!covered)
      return(0);   // not enough history yet

   double move    = (tick.bid - oldest) / _Point;
   double trigger = InpTriggerPoints;

   // Require the move to be directional: price near the extreme of the window
   if(move >= trigger && (hi - tick.bid) / _Point <= trigger * 0.3)
      return(1);
   if(-move >= trigger && (tick.bid - lo) / _Point <= trigger * 0.3)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
void OpenTrade(const ENUM_ORDER_TYPE type, const MqlTick &tick)
  {
   double price = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   int    stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int    slPts = MathMax(InpStopLossPoints, stopsLevel + 1);
   int    tpPts = (InpTakeProfitPoints > 0) ? MathMax(InpTakeProfitPoints, stopsLevel + 1) : 0;

   double sl, tp = 0.0;
   if(type == ORDER_TYPE_BUY)
     {
      sl = price - slPts * _Point;
      if(tpPts > 0)
         tp = price + tpPts * _Point;
     }
   else
     {
      sl = price + slPts * _Point;
      if(tpPts > 0)
         tp = price - tpPts * _Point;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = CalcLots(slPts);
   if(lots <= 0.0)
      return;

   double margin;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin) ||
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      Print("SaveEA: not enough free margin for ", DoubleToString(lots, 2), " lots");
      return;
     }

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lots, _Symbol, price, sl, tp, InpComment)
             : trade.Sell(lots, _Symbol, price, sl, tp, InpComment);
   if(ok && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED))
      g_lastEntry = tick.time;
   else
      Print("SaveEA: order failed, retcode ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
double CalcLots(const int slPts)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lots = InpLots;
   if(InpRiskPercent > 0.0)
     {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0.0 || tickSize <= 0.0)
         return(0.0);
      double riskMoney   = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
      double lossPerLot  = slPts * _Point / tickSize * tickValue;
      if(lossPerLot <= 0.0)
         return(0.0);
      lots = riskMoney / lossPerLot;
     }

   lots = MathMin(lots, InpMaxLots);
   lots = MathFloor(lots / stepLot) * stepLot;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   return(NormalizeDouble(lots, 2));
  }

//+------------------------------------------------------------------+
//| Break-even, trailing stop and time exit                          |
//+------------------------------------------------------------------+
void ManagePositions(const MqlTick &tick)
  {
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != InpMagic)
         continue;

      ulong  ticket = pos.Ticket();
      double open   = pos.PriceOpen();
      double curSL  = pos.StopLoss();
      double curTP  = pos.TakeProfit();
      bool   isBuy  = (pos.PositionType() == POSITION_TYPE_BUY);

      if(InpMaxHoldMinutes > 0 && tick.time - pos.Time() >= InpMaxHoldMinutes * 60)
        {
         trade.PositionClose(ticket);
         continue;
        }

      double price  = isBuy ? tick.bid : tick.ask;
      double profit = isBuy ? (price - open) / _Point : (open - price) / _Point;
      double newSL  = curSL;

      // Break-even
      if(InpBreakEvenPoints > 0 && profit >= InpBreakEvenPoints)
        {
         double be = isBuy ? open + InpBreakEvenLock * _Point : open - InpBreakEvenLock * _Point;
         if(isBuy ? (curSL < be) : (curSL > be || curSL == 0.0))
            newSL = be;
        }

      // Trailing
      if(profit >= InpTrailStartPoints)
        {
         int dist = MathMax(InpTrailDistance, stopsLevel + 1);
         double trail = isBuy ? price - dist * _Point : price + dist * _Point;
         if(isBuy ? (trail > newSL) : (trail < newSL || newSL == 0.0))
            newSL = trail;
        }

      newSL = NormalizeDouble(newSL, _Digits);
      if(newSL == curSL)
         continue;

      // Only modify on a meaningful improvement
      double improve = isBuy ? (newSL - curSL) / _Point : (curSL - newSL) / _Point;
      if(curSL != 0.0 && improve < InpTrailStepPoints)
         continue;

      // Respect broker stop level
      if(isBuy && (price - newSL) / _Point <= stopsLevel)
         continue;
      if(!isBuy && (newSL - price) / _Point <= stopsLevel)
         continue;

      trade.PositionModify(ticket, newSL, curTP);
     }
  }

//+------------------------------------------------------------------+
int CountPositions()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(pos.SelectByIndex(i) && pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
         n++;
   return(n);
  }

//+------------------------------------------------------------------+
bool InTradingHours(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(InpStartHour <= InpEndHour)
      return(dt.hour >= InpStartHour && dt.hour < InpEndHour);
   return(dt.hour >= InpStartHour || dt.hour < InpEndHour);   // overnight window
  }

//+------------------------------------------------------------------+
//| Daily loss / target guard                                        |
//+------------------------------------------------------------------+
void ResetDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   g_dayStart       = StructToTime(dt);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayHalted      = false;
  }

bool CheckDay()
  {
   if(TimeCurrent() - g_dayStart >= 86400)
      ResetDay();
   if(g_dayHalted)
      return(false);
   if(g_dayStartEquity <= 0.0)
      return(true);

   double change = (AccountInfoDouble(ACCOUNT_EQUITY) - g_dayStartEquity) / g_dayStartEquity * 100.0;
   if(InpDailyLossPercent > 0.0 && change <= -InpDailyLossPercent)
     {
      Print("SaveEA: daily loss limit reached (", DoubleToString(change, 2), "%), pausing until tomorrow");
      g_dayHalted = true;
     }
   else if(InpDailyTargetPercent > 0.0 && change >= InpDailyTargetPercent)
     {
      Print("SaveEA: daily target reached (", DoubleToString(change, 2), "%), pausing until tomorrow");
      g_dayHalted = true;
     }
   return(!g_dayHalted);
  }
//+------------------------------------------------------------------+
