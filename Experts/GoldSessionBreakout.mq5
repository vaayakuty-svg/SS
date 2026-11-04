//+------------------------------------------------------------------+
//|                                          GoldSessionBreakout.mq5 |
//|  XAU/USD Asian-range / London-open breakout                      |
//|  Range : high/low of the quiet Asian session (server time)       |
//|  Entry : buy-stop above / sell-stop below the range, OCO         |
//|  Exits : SL at the far side of the range (capped), TP = R x SL,  |
//|          breakeven, everything closed at a set hour              |
//|  Risk  : fixed % of balance, one trade per day, range-width,     |
//|          spread and optional H1 trend filters. No grid/martingale|
//+------------------------------------------------------------------+
#property copyright "SS"
#property version   "1.00"
#property description "Asian-range breakout for XAU/USD with OCO stop orders. Any chart timeframe. Test on demo first."

#include <Trade\Trade.mqh>

//--- Risk
input group "Risk"
input double InpRiskPercent     = 1.0;   // Risk per trade (% of balance)
input int    InpMaxSpreadPoints = 40;    // Max spread when placing orders (points)

//--- Range (server time, hours 0-23)
input group "Range & session (server time)"
input int    InpRangeStartHour  = 0;     // Range start hour
input int    InpRangeEndHour    = 7;     // Range end hour (orders placed from here)
input int    InpOrderEndHour    = 16;    // Delete untriggered orders at this hour
input int    InpCloseHour       = 21;    // Close any open trade at this hour
input bool   InpTradeFriday     = true;  // Trade on Fridays

//--- Range filters
input group "Range filters"
input int    InpMinRangePoints  = 300;   // Skip day if range is smaller (points)
input int    InpMaxRangePoints  = 2500;  // Skip day if range is larger (points)
input int    InpBufferPoints    = 50;    // Entry buffer beyond range (points)

//--- Exits
input group "Exits"
input int    InpMaxSLPoints     = 1500;  // Cap stop-loss distance (points), 0 = no cap
input double InpTP_R            = 1.5;   // Take profit (x stop distance)
input double InpBE_R            = 1.0;   // Move to breakeven at this R, 0 = off
input int    InpBEOffsetPoints  = 20;    // Breakeven offset (points beyond entry)

//--- Trend filter
input group "Trend filter"
input bool   InpUseTrendFilter  = true;  // Only trade in direction of H1 EMA
input int    InpTrendEMA        = 200;   // H1 EMA period

//--- General
input group "General"
input ulong  InpMagic           = 260427; // Magic number

CTrade   trade;
int      hTrend   = INVALID_HANDLE;
datetime skipDay  = 0;   // day already evaluated and skipped (avoids log spam)

//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("Warning: GoldSessionBreakout is tuned for XAU/USD, running on ", _Symbol);

   if(InpRiskPercent <= 0 || InpTP_R <= 0 ||
      InpRangeStartHour < 0 || InpRangeEndHour > 23 || InpRangeStartHour >= InpRangeEndHour ||
      InpOrderEndHour <= InpRangeEndHour || InpCloseHour < InpOrderEndHour || InpCloseHour > 24 ||
      InpMinRangePoints < 0 || InpMaxRangePoints <= InpMinRangePoints)
   {
      Print("Invalid inputs: need RangeStart < RangeEnd < OrderEnd <= CloseHour and Min < Max range");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpUseTrendFilter)
   {
      hTrend = iMA(_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(hTrend == INVALID_HANDLE)
      {
         Print("Failed to create EMA handle, error ", GetLastError());
         return INIT_FAILED;
      }
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hTrend != INVALID_HANDLE)
      IndicatorRelease(hTrend);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime now      = TimeCurrent();
   datetime dayStart = now - (now % 86400);
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // End of day: flatten
   if(dt.hour >= InpCloseHour)
   {
      DeletePendings();
      ClosePositions();
      return;
   }

   // Order window over: remove untriggered orders
   if(dt.hour >= InpOrderEndHour)
      DeletePendings();

   // OCO: once one side fills, remove the other
   if(CountPositions() > 0)
      DeletePendings();

   ManageBreakeven();

   if(dt.hour < InpRangeEndHour || dt.hour >= InpOrderEndHour)
      return;
   if(!InpTradeFriday && dt.day_of_week == 5)
      return;
   if(skipDay == dayStart || AlreadyTradedToday(dayStart))
      return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
      return;   // wait for a normal spread

   PlaceBreakoutOrders(dayStart);
}

//+------------------------------------------------------------------+
//| Build the Asian range and place the OCO stop orders              |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders(const datetime dayStart)
{
   datetime from = dayStart + InpRangeStartHour * 3600;
   datetime to   = dayStart + InpRangeEndHour * 3600 - 1;

   double highs[], lows[];
   int nH = CopyHigh(_Symbol, PERIOD_M5, from, to, highs);
   int nL = CopyLow(_Symbol, PERIOD_M5, from, to, lows);
   if(nH <= 0 || nL <= 0)
      return;   // history not ready yet, retry next tick
   if(nH < 6)
   {
      Print("Too few M5 bars in range (", nH, "), skipping today");
      skipDay = dayStart;
      return;
   }

   double rangeHigh = highs[ArrayMaximum(highs)];
   double rangeLow  = lows[ArrayMinimum(lows)];
   double rangePts  = (rangeHigh - rangeLow) / _Point;

   if(rangePts < InpMinRangePoints || rangePts > InpMaxRangePoints)
   {
      PrintFormat("Range %.0f pts outside %d-%d, no trade today", rangePts, InpMinRangePoints, InpMaxRangePoints);
      skipDay = dayStart;
      return;
   }

   double buffer   = InpBufferPoints * _Point;
   double buyPrice = NormalizeDouble(rangeHigh + buffer, _Digits);
   double sellPrice= NormalizeDouble(rangeLow - buffer, _Digits);

   double slDist = buyPrice - sellPrice;   // far side of the range
   if(InpMaxSLPoints > 0)
      slDist = MathMin(slDist, InpMaxSLPoints * _Point);
   double tpDist = slDist * InpTP_R;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   // Trend filter
   bool allowBuy = true, allowSell = true;
   if(InpUseTrendFilter)
   {
      double ema[];
      if(CopyBuffer(hTrend, 0, 1, 1, ema) < 1)
         return;
      double h1Close = iClose(_Symbol, PERIOD_H1, 1);
      if(h1Close == 0)
         return;
      allowBuy  = h1Close > ema[0];
      allowSell = h1Close < ema[0];
   }

   // A side is invalid if price already broke out before the window opened
   bool buyOk  = allowBuy  && buyPrice - tick.ask > minDist;
   bool sellOk = allowSell && tick.bid - sellPrice > minDist;

   double lots = CalcLots(slDist);
   if(lots <= 0 || (!buyOk && !sellOk))
   {
      Print("No valid side today (trend filter, price already outside range, or lot too large)");
      skipDay = dayStart;
      return;
   }

   bool placed = false;
   if(buyOk)
   {
      double sl = NormalizeDouble(buyPrice - slDist, _Digits);
      double tp = NormalizeDouble(buyPrice + tpDist, _Digits);
      if(PlacePending(ORDER_TYPE_BUY_STOP, lots, buyPrice, sl, tp)) placed = true;
   }
   if(sellOk)
   {
      double sl = NormalizeDouble(sellPrice + slDist, _Digits);
      double tp = NormalizeDouble(sellPrice - tpDist, _Digits);
      if(PlacePending(ORDER_TYPE_SELL_STOP, lots, sellPrice, sl, tp)) placed = true;
   }

   if(placed)
      PrintFormat("Range %.2f-%.2f (%.0f pts). Orders: buy %s @ %.2f, sell %s @ %.2f, %.2f lots, SL %.0f pts",
                  rangeLow, rangeHigh, rangePts,
                  buyOk ? "yes" : "no", buyPrice, sellOk ? "yes" : "no", sellPrice,
                  lots, slDist / _Point);
   else
      skipDay = dayStart;   // don't retry every tick after a broker rejection
}

//+------------------------------------------------------------------+
bool PlacePending(const ENUM_ORDER_TYPE type, const double lots,
                  const double price, const double sl, const double tp)
{
   double margin = 0.0;
   ENUM_ORDER_TYPE mType = (type == ORDER_TYPE_BUY_STOP) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(mType, _Symbol, lots, price, margin) ||
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Print("Not enough free margin for ", lots, " lots");
      return false;
   }

   for(int attempt = 0; attempt < 2; attempt++)
   {
      bool ok = (type == ORDER_TYPE_BUY_STOP)
                ? trade.BuyStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "GoldSessionBreakout")
                : trade.SellStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "GoldSessionBreakout");
      uint rc = trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED))
      {
         trade.SetTypeFillingBySymbol(_Symbol);
         return true;
      }
      // Some brokers only accept "return" filling for pending orders
      if(rc == TRADE_RETCODE_INVALID_FILL && attempt == 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
         continue;
      }
      PrintFormat("Pending order failed: retcode %u (%s)", rc, trade.ResultRetcodeDescription());
      break;
   }
   trade.SetTypeFillingBySymbol(_Symbol);
   return false;
}

//+------------------------------------------------------------------+
//| Lot size so that hitting the SL loses InpRiskPercent of balance. |
//| Returns 0 if even the minimum lot would exceed that risk.        |
//+------------------------------------------------------------------+
double CalcLots(const double slDist)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || slDist <= 0)
      return 0;

   double lots = riskMoney / (slDist / tickSize * tickValue);

   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0)
      return 0;

   lots = MathFloor(lots / step) * step;
   if(lots < minLot)
   {
      PrintFormat("Skipped: min lot %.2f would risk more than %.2f%%", minLot, InpRiskPercent);
      return 0;
   }
   lots = MathMin(lots, maxLot);

   int volDigits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, volDigits);
}

//+------------------------------------------------------------------+
//| Move SL to entry + offset once profit reaches InpBE_R x risk     |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(InpBE_R <= 0)
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double offset  = InpBEOffsetPoints * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOurs(PositionGetString(POSITION_SYMBOL), PositionGetInteger(POSITION_MAGIC)))
         continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(sl == 0)
         continue;

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double risk = open - sl;            // <= 0 means already at breakeven
         if(risk <= 0 || tick.bid - open < risk * InpBE_R)
            continue;
         double newSL = NormalizeDouble(open + offset, _Digits);
         if(tick.bid - newSL >= minDist)
            trade.PositionModify(ticket, newSL, tp);
      }
      else
      {
         double risk = sl - open;
         if(risk <= 0 || open - tick.ask < risk * InpBE_R)
            continue;
         double newSL = NormalizeDouble(open - offset, _Digits);
         if(newSL - tick.ask >= minDist)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| True if this EA already placed an order today (survives restart) |
//+------------------------------------------------------------------+
bool AlreadyTradedToday(const datetime dayStart)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket != 0 && IsOurs(OrderGetString(ORDER_SYMBOL), OrderGetInteger(ORDER_MAGIC)))
         return true;
   }
   if(CountPositions() > 0)
      return true;

   if(!HistorySelect(dayStart, TimeCurrent() + 60))
      return false;
   int total = HistoryOrdersTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket != 0 && IsOurs(HistoryOrderGetString(ticket, ORDER_SYMBOL), HistoryOrderGetInteger(ticket, ORDER_MAGIC)))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool IsOurs(const string symbol, const long magic)
{
   return symbol == _Symbol && (ulong)magic == InpMagic;
}

//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && IsOurs(PositionGetString(POSITION_SYMBOL), PositionGetInteger(POSITION_MAGIC)))
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
void DeletePendings()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket != 0 && IsOurs(OrderGetString(ORDER_SYMBOL), OrderGetInteger(ORDER_MAGIC)))
         trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
void ClosePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && IsOurs(PositionGetString(POSITION_SYMBOL), PositionGetInteger(POSITION_MAGIC)))
         trade.PositionClose(ticket);
   }
}
//+------------------------------------------------------------------+
