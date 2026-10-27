//+------------------------------------------------------------------+
//|                                               GoldScalperATR.mq5 |
//|  XAU/USD M1 scalper                                              |
//|  Entry : higher-timeframe EMA trend + M1 EMA side + breakout of  |
//|          the last N bars, confirmed by ATR expansion             |
//|  Exits : ATR-based SL/TP, breakeven and ATR trailing stop        |
//|  Risk  : fixed % of balance per trade, daily loss / trade caps,  |
//|          spread and session filters, one position at a time      |
//+------------------------------------------------------------------+
#property copyright "SS"
#property version   "1.00"
#property description "Transparent ATR breakout scalper for XAU/USD on M1. Test on demo first."

#include <Trade\Trade.mqh>

//--- Risk
input group "Risk"
input double InpRiskPercent      = 1.0;   // Risk per trade (% of balance)
input double InpMaxDailyLossPct  = 3.0;   // Stop trading after this daily loss (% of start balance)
input int    InpMaxTradesPerDay  = 10;    // Max entries per server day
input int    InpMaxSpreadPoints  = 35;    // Max spread allowed (points)

//--- Signal
input group "Signal"
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_M15; // Trend timeframe
input int    InpTrendEMA         = 50;    // Trend EMA period (on trend TF)
input int    InpFastEMA          = 21;    // Fast EMA period (on chart TF)
input int    InpBreakoutBars     = 15;    // Breakout lookback (bars)
input int    InpATRPeriod        = 14;    // ATR period
input int    InpATRAvgBars       = 50;    // Bars used for average ATR
input double InpATRExpansion     = 1.1;   // ATR must exceed average ATR x this

//--- Exits
input group "Exits"
input double InpSL_ATR           = 1.5;   // Stop loss (x ATR)
input double InpTP_ATR           = 2.0;   // Take profit (x ATR)
input double InpBE_ATR           = 1.0;   // Move to breakeven after profit of (x ATR), 0 = off
input int    InpBEOffsetPoints   = 20;    // Breakeven offset (points beyond entry)
input double InpTrail_ATR        = 1.0;   // Trailing distance (x ATR) after breakeven, 0 = off

//--- Session
input group "Session (server time)"
input int    InpStartHour        = 8;     // Session start hour
input int    InpEndHour          = 20;    // Session end hour (exclusive)

//--- General
input group "General"
input ulong  InpMagic            = 260426; // Magic number
input int    InpCooldownBars     = 5;     // Bars to wait after an entry
input int    InpSlippagePoints   = 30;    // Max slippage (points)

CTrade   trade;
int      hATR      = INVALID_HANDLE;
int      hFastEMA  = INVALID_HANDLE;
int      hTrendEMA = INVALID_HANDLE;
datetime lastBarTime   = 0;
datetime lastEntryTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("Warning: GoldScalperATR is tuned for XAU/USD, running on ", _Symbol);
   if(_Period != PERIOD_M1)
      Print("Warning: GoldScalperATR is tuned for M1, running on ", EnumToString(_Period));

   if(InpRiskPercent <= 0 || InpSL_ATR <= 0 || InpTP_ATR <= 0 || InpBreakoutBars < 2 || InpATRAvgBars < 1)
   {
      Print("Invalid inputs");
      return INIT_PARAMETERS_INCORRECT;
   }

   hATR      = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   hFastEMA  = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrendEMA = iMA(_Symbol, InpTrendTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hATR == INVALID_HANDLE || hFastEMA == INVALID_HANDLE || hTrendEMA == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles, error ", GetLastError());
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE)      IndicatorRelease(hATR);
   if(hFastEMA != INVALID_HANDLE)  IndicatorRelease(hFastEMA);
   if(hTrendEMA != INVALID_HANDLE) IndicatorRelease(hTrendEMA);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManagePositions();

   // Entries are evaluated once per closed bar
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return;
   lastBarTime = barTime;

   if(!CanTrade())
      return;

   double atr = 0.0;
   int signal = GetSignal(atr);
   if(signal != 0)
      OpenTrade(signal, atr);
}

//+------------------------------------------------------------------+
//| 1 = buy, -1 = sell, 0 = no trade. Uses closed bars only.         |
//+------------------------------------------------------------------+
int GetSignal(double &atrNow)
{
   double atr[], fast[], trend[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(trend, true);

   if(CopyBuffer(hATR, 0, 1, InpATRAvgBars, atr) < InpATRAvgBars) return 0;
   if(CopyBuffer(hFastEMA, 0, 1, 1, fast) < 1)                     return 0;
   if(CopyBuffer(hTrendEMA, 0, 1, 2, trend) < 2)                   return 0;

   atrNow = atr[0];
   double atrSum = 0.0;
   for(int i = 0; i < InpATRAvgBars; i++)
      atrSum += atr[i];
   double atrAvg = atrSum / InpATRAvgBars;

   // Volatility must be expanding
   if(atrNow < atrAvg * InpATRExpansion)
      return 0;

   // Range of the bars before the signal bar
   int hiIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpBreakoutBars, 2);
   int loIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpBreakoutBars, 2);
   if(hiIdx < 0 || loIdx < 0)
      return 0;
   double rangeHigh = iHigh(_Symbol, PERIOD_CURRENT, hiIdx);
   double rangeLow  = iLow(_Symbol, PERIOD_CURRENT, loIdx);

   double close1     = iClose(_Symbol, PERIOD_CURRENT, 1);
   double trendClose = iClose(_Symbol, InpTrendTF, 1);
   if(close1 == 0 || trendClose == 0)
      return 0;

   bool upTrend   = trendClose > trend[0] && trend[0] > trend[1] && close1 > fast[0];
   bool downTrend = trendClose < trend[0] && trend[0] < trend[1] && close1 < fast[0];

   if(upTrend && close1 > rangeHigh)  return 1;
   if(downTrend && close1 < rangeLow) return -1;
   return 0;
}

//+------------------------------------------------------------------+
bool CanTrade()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool inSession = (InpStartHour <= InpEndHour)
                    ? (dt.hour >= InpStartHour && dt.hour < InpEndHour)
                    : (dt.hour >= InpStartHour || dt.hour < InpEndHour);
   if(!inSession)
      return false;

   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
      return false;

   if(CountPositions() > 0)
      return false;

   if(lastEntryTime > 0 && iBarShift(_Symbol, PERIOD_CURRENT, lastEntryTime) < InpCooldownBars)
      return false;

   int    tradesToday = 0;
   double pnlToday    = 0.0;
   GetTodayStats(tradesToday, pnlToday);
   if(tradesToday >= InpMaxTradesPerDay)
      return false;

   double startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - pnlToday;
   if(InpMaxDailyLossPct > 0 && pnlToday <= -startBalance * InpMaxDailyLossPct / 100.0)
      return false;

   return true;
}

//+------------------------------------------------------------------+
void OpenTrade(const int direction, const double atr)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double slDist  = MathMax(atr * InpSL_ATR, minDist);
   double tpDist  = MathMax(atr * InpTP_ATR, minDist);

   bool   isBuy = direction > 0;
   double price = isBuy ? tick.ask : tick.bid;
   double sl    = NormalizeDouble(isBuy ? price - slDist : price + slDist, _Digits);
   double tp    = NormalizeDouble(isBuy ? price + tpDist : price - tpDist, _Digits);

   double lots = CalcLots(slDist);
   if(lots <= 0)
      return;

   double margin = 0.0;
   ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin) ||
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Print("Not enough free margin for ", lots, " lots");
      return;
   }

   bool ok = isBuy ? trade.Buy(lots, _Symbol, price, sl, tp, "GoldScalperATR")
                   : trade.Sell(lots, _Symbol, price, sl, tp, "GoldScalperATR");
   if(ok && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED))
   {
      lastEntryTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      PrintFormat("%s %.2f lots @ %.2f SL %.2f TP %.2f (ATR %.2f)",
                  isBuy ? "BUY" : "SELL", lots, price, sl, tp, atr);
   }
   else
      PrintFormat("Order failed: retcode %u (%s)", trade.ResultRetcode(), trade.ResultRetcodeDescription());
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

   double lossPerLot = slDist / tickSize * tickValue;
   double lots       = riskMoney / lossPerLot;

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
//| Breakeven + ATR trailing stop for this EA's positions            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(InpBE_ATR <= 0 && InpTrail_ATR <= 0)
      return;

   double atr[];
   if(CopyBuffer(hATR, 0, 1, 1, atr) < 1)
      return;
   double atrNow  = atr[0];
   double trigger = (InpBE_ATR > 0) ? atrNow * InpBE_ATR : 0.0;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   type = PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
      {
         double profit = tick.bid - open;
         if(profit < trigger)
            continue;
         double newSL = sl;
         if(InpBE_ATR > 0)
            newSL = MathMax(newSL, open + InpBEOffsetPoints * _Point);
         if(InpTrail_ATR > 0)
            newSL = MathMax(newSL, tick.bid - atrNow * InpTrail_ATR);
         newSL = NormalizeDouble(newSL, _Digits);
         if(tick.bid - newSL < minDist)
            continue;
         if(sl == 0 || newSL > sl + _Point)
            trade.PositionModify(ticket, newSL, tp);
      }
      else
      {
         double profit = open - tick.ask;
         if(profit < trigger)
            continue;
         double newSL = (sl == 0) ? DBL_MAX : sl;
         if(InpBE_ATR > 0)
            newSL = MathMin(newSL, open - InpBEOffsetPoints * _Point);
         if(InpTrail_ATR > 0)
            newSL = MathMin(newSL, tick.ask + atrNow * InpTrail_ATR);
         if(newSL == DBL_MAX)
            continue;
         newSL = NormalizeDouble(newSL, _Digits);
         if(newSL - tick.ask < minDist)
            continue;
         if(sl == 0 || newSL < sl - _Point)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Entries and realised P/L (incl. swap/commission) since the start |
//| of the current server day, for this EA on this symbol.           |
//+------------------------------------------------------------------+
void GetTodayStats(int &trades, double &pnl)
{
   trades = 0;
   pnl    = 0.0;
   datetime now      = TimeCurrent();
   datetime dayStart = now - (now % 86400);
   if(!HistorySelect(dayStart, now + 60))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol || (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         trades++;
      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT)
           + HistoryDealGetDouble(ticket, DEAL_SWAP)
           + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
}
//+------------------------------------------------------------------+
