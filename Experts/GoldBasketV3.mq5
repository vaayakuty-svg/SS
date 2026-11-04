//+------------------------------------------------------------------+
//|                                                 GoldBasketV3.mq5 |
//|  XAU/USD M1 grid-basket scalper: trend-filtered first entry,      |
//|  fixed-step grid with a lot sequence, whole-basket money close.   |
//|                                                                  |
//|  Modelled on the trading *behaviour* visible in public screen     |
//|  recordings of a "Gold V3 MT5" EA (XAUUSD M1 strategy tester:      |
//|  ~2.21 grid step, lots 0.01,0.01,0.02,0.02,0.03,0.05,0.08,0.11,    |
//|  independent buy & sell baskets closed at a net profit, no SL).   |
//|  The original source is not public; every rule here is written   |
//|  from scratch. Unlike the original, money/drawdown stops are ON.  |
//+------------------------------------------------------------------+
#property copyright "GoldBasketV3"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- Inputs: entry
input group "Entry signal"
input ENUM_TIMEFRAMES InpSignalTF      = PERIOD_M1;  // Signal timeframe
input int             InpFastEMA       = 9;          // Fast EMA
input int             InpSlowEMA       = 21;         // Slow EMA
input int             InpTrendEMA      = 200;        // Trend EMA (0 = off)
input int             InpRSIPeriod     = 14;         // RSI period
input double          InpRSIBuyMin     = 52.0;       // RSI must be above this for buys
input double          InpRSISellMax    = 48.0;       // RSI must be below this for sells
input bool            InpAllowBuy      = true;       // Allow buy baskets
input bool            InpAllowSell     = true;       // Allow sell baskets

//--- Inputs: basket
input group "Basket"
input string InpLotSequence      = "0.01,0.01,0.02,0.02,0.03,0.05,0.08,0.11"; // Lot per grid level (last value repeats)
input double InpLotScale         = 1.0;    // Multiply the whole sequence (e.g. 2.0 for a bigger account)
input double InpGridStepPrice    = 2.21;   // Grid step in price units (2.21 = $2.21 on gold)
input int    InpMaxOrders        = 8;      // Max orders per basket (buy and sell counted separately)
input double InpTPPerLot         = 100.0;  // Basket TP = total lots x this (0.01 lot -> 1.00)
input double InpMinTPMoney       = 1.0;    // Minimum basket TP (account currency)
input double InpStopLossMoney    = 100.0;  // Close a basket at this net loss (0 = off, as original)
input double InpMaxDDPercent     = 5.0;    // Close a basket if loss >= this % of balance (0 = off)
input bool   InpHedgeMode        = true;   // Allow a buy and a sell basket at the same time
input int    InpCooldownBars     = 1;      // Bars to wait after a basket closes

//--- Inputs: filters & safety
input group "Filters & safety"
input int    InpMaxSpreadPoints  = 40;     // Max spread (points)
input int    InpStartHour        = 2;      // Trading start hour (server time)
input int    InpEndHour          = 22;     // Trading end hour (server time)
input double InpDailyLossPercent = 5.0;    // Stop new baskets after this daily loss % (0 = off)
input int    InpMaxBasketsPerDay = 200;    // Max baskets per day
input ulong  InpMagic            = 330033; // Magic number
input string InpComment          = "GoldBasketV3"; // Order comment
input bool   InpShowPanel        = true;   // Show net profit on chart

//--- Globals
CTrade   trade;
int      hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE, hTrend = INVALID_HANDLE, hRSI = INVALID_HANDLE;
double   lotSeq[];
datetime lastBarTime   = 0;
datetime lastCloseBuy  = 0, lastCloseSell = 0;
int      dayOfYear     = -1;
double   dayStartBal   = 0;
int      basketsToday  = 0;
double   closedProfit  = 0;   // realised profit of this EA since attach (for the panel)

struct Basket
{
   int    count;
   double profit;
   double lots;
   double lastPrice;   // open price of the newest order
};

//+------------------------------------------------------------------+
bool ParseLots()
{
   string parts[];
   int n = StringSplit(InpLotSequence, ',', parts);
   if(n <= 0) return false;
   ArrayResize(lotSeq, n);
   for(int i = 0; i < n; i++)
   {
      StringTrimLeft(parts[i]); StringTrimRight(parts[i]);
      lotSeq[i] = StringToDouble(parts[i]) * InpLotScale;
      if(lotSeq[i] <= 0) return false;
   }
   return true;
}

int OnInit()
{
   if(InpFastEMA >= InpSlowEMA) { Print("Fast EMA must be shorter than slow EMA"); return INIT_PARAMETERS_INCORRECT; }
   if(!ParseLots())             { Print("Bad lot sequence"); return INIT_PARAMETERS_INCORRECT; }
   if(InpGridStepPrice <= 0 || InpMaxOrders < 1) { Print("Check grid step / max orders"); return INIT_PARAMETERS_INCORRECT; }

   hFast = iMA(_Symbol, InpSignalTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpSignalTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI  = iRSI(_Symbol, InpSignalTF, InpRSIPeriod, PRICE_CLOSE);
   if(InpTrendEMA > 0) hTrend = iMA(_Symbol, InpSignalTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hRSI == INVALID_HANDLE ||
      (InpTrendEMA > 0 && hTrend == INVALID_HANDLE))
   { Print("Indicator handle error"); return INIT_FAILED; }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   ResetDay();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hFast); IndicatorRelease(hSlow); IndicatorRelease(hRSI);
   if(hTrend != INVALID_HANDLE) IndicatorRelease(hTrend);
   Comment("");
}

//+------------------------------------------------------------------+
void ResetDay()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   if(t.day_of_year != dayOfYear)
   {
      dayOfYear    = t.day_of_year;
      dayStartBal  = AccountInfoDouble(ACCOUNT_BALANCE);
      basketsToday = 0;
   }
}

double GetBuf(int handle, int shift)
{
   double b[1];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return EMPTY_VALUE;
   return b[0];
}

bool IsMine(ulong ticket, int dir)
{
   if(ticket == 0) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) return false;
   int d = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   return d == dir;
}

void GetBasket(int dir, Basket &b)
{
   b.count = 0; b.profit = 0; b.lots = 0; b.lastPrice = 0;
   datetime lastTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!IsMine(ticket, dir)) continue;
      b.count++;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      b.lots   += PositionGetDouble(POSITION_VOLUME);
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= lastTime) { lastTime = ot; b.lastPrice = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
}

void CloseBasket(int dir, const string why)
{
   double realised = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!IsMine(ticket, dir)) continue;
      realised += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(!trade.PositionClose(ticket))
         PrintFormat("Close failed #%I64u: %d", ticket, trade.ResultRetcode());
   }
   closedProfit += realised;
   datetime bar = iTime(_Symbol, InpSignalTF, 0);
   if(dir > 0) lastCloseBuy = bar; else lastCloseSell = bar;
   PrintFormat("%s basket closed (%s): %.2f", dir > 0 ? "BUY" : "SELL", why, realised);
}

double NormLot(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = MathRound(lot / step) * step;
   return MathMax(mn, MathMin(mx, lot));
}

double LotForLevel(int level)
{
   int n = ArraySize(lotSeq);
   return lotSeq[MathMin(level, n - 1)];
}

bool Open(int dir, double lot)
{
   lot = NormLot(lot);
   bool ok = (dir > 0) ? trade.Buy(lot, _Symbol, 0, 0, 0, InpComment)
                       : trade.Sell(lot, _Symbol, 0, 0, 0, InpComment);
   if(!ok) PrintFormat("Open failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
   return ok;
}

bool SpreadOK()  { return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpreadPoints; }

bool SessionOK()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   if(InpStartHour <= InpEndHour) return t.hour >= InpStartHour && t.hour < InpEndHour;
   return t.hour >= InpStartHour || t.hour < InpEndHour; // overnight window
}

bool DailyOK()
{
   if(basketsToday >= InpMaxBasketsPerDay) return false;
   if(InpDailyLossPercent <= 0 || dayStartBal <= 0) return true;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return (dayStartBal - eq) / dayStartBal * 100.0 < InpDailyLossPercent;
}

// +1 buy, -1 sell, 0 none — evaluated on the last closed bar
int Signal()
{
   double f1 = GetBuf(hFast, 1), f2 = GetBuf(hFast, 2);
   double s1 = GetBuf(hSlow, 1);
   double r1 = GetBuf(hRSI, 1);
   if(f1 == EMPTY_VALUE || f2 == EMPTY_VALUE || s1 == EMPTY_VALUE || r1 == EMPTY_VALUE) return 0;

   double c1 = iClose(_Symbol, InpSignalTF, 1);
   double o1 = iOpen(_Symbol, InpSignalTF, 1);
   double tr = (hTrend != INVALID_HANDLE) ? GetBuf(hTrend, 1) : 0;

   bool upTrend = (hTrend == INVALID_HANDLE) || (tr != EMPTY_VALUE && c1 > tr);
   bool dnTrend = (hTrend == INVALID_HANDLE) || (tr != EMPTY_VALUE && c1 < tr);

   // Fast EMA above slow and rising, bullish candle closing above fast EMA
   if(InpAllowBuy && upTrend && f1 > s1 && f1 > f2 && c1 > o1 && c1 > f1 && r1 > InpRSIBuyMin) return 1;
   if(InpAllowSell && dnTrend && f1 < s1 && f1 < f2 && c1 < o1 && c1 < f1 && r1 < InpRSISellMax) return -1;
   return 0;
}

// Manage one basket on every tick: TP / stops / grid add-on
void ManageBasket(int dir)
{
   Basket b; GetBasket(dir, b);
   if(b.count == 0) return;

   double tp  = MathMax(InpMinTPMoney, b.lots * InpTPPerLot);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(b.profit >= tp)                                        { CloseBasket(dir, "take profit");   return; }
   if(InpStopLossMoney > 0 && b.profit <= -InpStopLossMoney) { CloseBasket(dir, "money stop");    return; }
   if(InpMaxDDPercent > 0 && bal > 0 && -b.profit / bal * 100.0 >= InpMaxDDPercent)
                                                             { CloseBasket(dir, "drawdown stop"); return; }

   if(b.count >= InpMaxOrders || !SpreadOK()) return;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool add = (dir > 0 && ask <= b.lastPrice - InpGridStepPrice) ||
              (dir < 0 && bid >= b.lastPrice + InpGridStepPrice);
   if(add) Open(dir, LotForLevel(b.count));
}

void DrawPanel()
{
   if(!InpShowPanel) return;
   Basket bb, sb; GetBasket(1, bb); GetBasket(-1, sb);
   double floating = bb.profit + sb.profit;
   Comment(StringFormat("%s\nBUY basket: %d orders  %.2f lots  %.2f\nSELL basket: %d orders  %.2f lots  %.2f\nClosed since start: %.2f\nNet Profit: %.2f\nBaskets today: %d",
           InpComment, bb.count, bb.lots, bb.profit, sb.count, sb.lots, sb.profit,
           closedProfit, closedProfit + floating, basketsToday));
}

//+------------------------------------------------------------------+
void OnTick()
{
   ResetDay();

   //--- 1) Manage open baskets on every tick
   ManageBasket(1);
   ManageBasket(-1);
   DrawPanel();

   //--- 2) Look for a new first entry once per closed bar
   datetime bar = iTime(_Symbol, InpSignalTF, 0);
   if(bar == lastBarTime) return;
   lastBarTime = bar;

   if(!SpreadOK() || !SessionOK() || !DailyOK()) return;

   int sig = Signal();
   if(sig == 0) return;

   Basket same, other; GetBasket(sig, same); GetBasket(-sig, other);
   if(same.count > 0) return;                       // that side already running
   if(!InpHedgeMode && other.count > 0) return;     // one side at a time
   datetime lastClose = (sig > 0) ? lastCloseBuy : lastCloseSell;
   if(lastClose > 0 && (bar - lastClose) < InpCooldownBars * PeriodSeconds(InpSignalTF)) return;

   if(Open(sig, LotForLevel(0)))
   {
      basketsToday++;
      PrintFormat("New %s basket @ %.2f lot", sig > 0 ? "BUY" : "SELL", LotForLevel(0));
   }
}
//+------------------------------------------------------------------+
