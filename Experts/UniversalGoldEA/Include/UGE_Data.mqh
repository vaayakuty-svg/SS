//+------------------------------------------------------------------+
//|                                                   UGE_Data.mqh   |
//|  Market data: indicator handles (created once), buffer reads,    |
//|  bar helpers, pivots/swings, VWAP and new-bar detection.         |
//+------------------------------------------------------------------+

//--- core handles shared by several modules
int g_hATR       = INVALID_HANDLE;   // core ATR (SL/TP/BE/grid)
int g_hDirEMA    = INVALID_HANDLE;   // direction / trend-change EMA
int g_hTrailATR  = INVALID_HANDLE;   // trailing ATR
int g_hTrailSAR  = INVALID_HANDLE;   // trailing SAR
int g_hVolFilter = INVALID_HANDLE;   // volatility filter ATR / StdDev
int g_hHedgeEMA  = INVALID_HANDLE;   // directional hedge EMA
int g_hDailyATR  = INVALID_HANDLE;   // D1 ATR for volatility breakout
int g_hMTF[5];                       // MTF bias EMAs
int g_hPullEMA   = INVALID_HANDLE;   // pullback EMA

int  g_allHandles[];                 // every handle, released in OnDeinit

//--- register a new handle; returns false if creation failed
bool RegHandle(int h, string what)
  {
   if(h == INVALID_HANDLE)
     {
      LogError("Cannot create indicator: " + what + " err=" + (string)GetLastError());
      return false;
     }
   int n = ArraySize(g_allHandles);
   ArrayResize(g_allHandles, n + 1);
   g_allHandles[n] = h;
   return true;
  }

void ReleaseAllHandles()
  {
   for(int i = 0; i < ArraySize(g_allHandles); i++)
      if(g_allHandles[i] != INVALID_HANDLE) IndicatorRelease(g_allHandles[i]);
   ArrayResize(g_allHandles, 0);
  }

//--- read one buffer value (shift 0 = forming bar). EMPTY_VALUE on failure
double Buf(int handle, int buffer, int shift)
  {
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   double v[1];
   if(CopyBuffer(handle, buffer, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
  }

bool Valid(double v) { return (v != EMPTY_VALUE && MathIsValidNumber(v)); }

//--- bar access (closed bars are shift >= 1)
double O(ENUM_TIMEFRAMES tf, int s) { return iOpen(_Symbol, tf, s); }
double H(ENUM_TIMEFRAMES tf, int s) { return iHigh(_Symbol, tf, s); }
double L(ENUM_TIMEFRAMES tf, int s) { return iLow(_Symbol, tf, s); }
double C(ENUM_TIMEFRAMES tf, int s) { return iClose(_Symbol, tf, s); }
datetime T(ENUM_TIMEFRAMES tf, int s) { return iTime(_Symbol, tf, s); }
double Body(ENUM_TIMEFRAMES tf, int s) { return MathAbs(C(tf, s) - O(tf, s)); }
double Range(ENUM_TIMEFRAMES tf, int s) { return H(tf, s) - L(tf, s); }
bool   Bull(ENUM_TIMEFRAMES tf, int s) { return C(tf, s) > O(tf, s); }
bool   Bear(ENUM_TIMEFRAMES tf, int s) { return C(tf, s) < O(tf, s); }
double UpperWick(ENUM_TIMEFRAMES tf, int s) { return H(tf, s) - MathMax(O(tf, s), C(tf, s)); }
double LowerWick(ENUM_TIMEFRAMES tf, int s) { return MathMin(O(tf, s), C(tf, s)) - L(tf, s); }

//--- highest high / lowest low over 'count' bars starting at 'start'
double HighestHigh(ENUM_TIMEFRAMES tf, int count, int start)
  {
   int i = iHighest(_Symbol, tf, MODE_HIGH, count, start);
   return (i >= 0 ? H(tf, i) : 0.0);
  }
double LowestLow(ENUM_TIMEFRAMES tf, int count, int start)
  {
   int i = iLowest(_Symbol, tf, MODE_LOW, count, start);
   return (i >= 0 ? L(tf, i) : 0.0);
  }

//--- average candle range in price over 'count' closed bars
double AvgRange(ENUM_TIMEFRAMES tf, int count, int start = 1)
  {
   double s = 0; int n = 0;
   for(int i = start; i < start + count; i++) { double r = Range(tf, i); if(r > 0) { s += r; n++; } }
   return (n > 0 ? s / n : 0.0);
  }

//--- core ATR in price (closed bar 1), fallback to average range
double CoreATR()
  {
   double a = Buf(g_hATR, 0, 1);
   if(!Valid(a) || a <= 0) a = AvgRange(InpATRTF, InpATRPeriod);
   return a;
  }

//--- new bar detector per timeframe (caller owns the 'last' variable)
bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last)
  {
   datetime t = T(tf, 0);
   if(t == 0) return false;
   if(t != last) { last = t; return true; }
   return false;
  }

//+------------------------------------------------------------------+
//| Swing pivots (confirmed fractals, no look-ahead)                 |
//| A pivot at shift i needs 'strength' CLOSED bars on its right,    |
//| so the newest usable pivot is at shift strength+1.               |
//+------------------------------------------------------------------+
bool IsPivotHigh(ENUM_TIMEFRAMES tf, int i, int strength)
  {
   double h = H(tf, i);
   for(int k = 1; k <= strength; k++)
      if(H(tf, i - k) >= h || H(tf, i + k) > h) return false;
   return true;
  }
bool IsPivotLow(ENUM_TIMEFRAMES tf, int i, int strength)
  {
   double l = L(tf, i);
   for(int k = 1; k <= strength; k++)
      if(L(tf, i - k) <= l || L(tf, i + k) < l) return false;
   return true;
  }

//--- collect up to 'maxCount' pivots, newest first
int GetPivotHighs(ENUM_TIMEFRAMES tf, int strength, int lookback, double &price[], int &shift[], int maxCount = 10)
  {
   ArrayResize(price, 0); ArrayResize(shift, 0);
   int n = 0;
   int bars = MathMin(lookback, iBars(_Symbol, tf) - strength - 2);
   for(int i = strength + 1; i < bars && n < maxCount; i++)
      if(IsPivotHigh(tf, i, strength))
        { ArrayResize(price, n + 1); ArrayResize(shift, n + 1); price[n] = H(tf, i); shift[n] = i; n++; }
   return n;
  }
int GetPivotLows(ENUM_TIMEFRAMES tf, int strength, int lookback, double &price[], int &shift[], int maxCount = 10)
  {
   ArrayResize(price, 0); ArrayResize(shift, 0);
   int n = 0;
   int bars = MathMin(lookback, iBars(_Symbol, tf) - strength - 2);
   for(int i = strength + 1; i < bars && n < maxCount; i++)
      if(IsPivotLow(tf, i, strength))
        { ArrayResize(price, n + 1); ArrayResize(shift, n + 1); price[n] = L(tf, i); shift[n] = i; n++; }
   return n;
  }

//--- structure bias from the last two swing highs and lows: +1 HH/HL, -1 LH/LL, 0 mixed
int StructureBias(ENUM_TIMEFRAMES tf, int strength)
  {
   double hp[], lp[]; int hs[], ls[];
   if(GetPivotHighs(tf, strength, 300, hp, hs, 2) < 2) return 0;
   if(GetPivotLows(tf, strength, 300, lp, ls, 2) < 2) return 0;
   if(hp[0] > hp[1] && lp[0] > lp[1]) return 1;
   if(hp[0] < hp[1] && lp[0] < lp[1]) return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//| Daily VWAP (tick volume) at a given shift                        |
//+------------------------------------------------------------------+
double VWAPAt(ENUM_TIMEFRAMES tf, int shift)
  {
   datetime bt = T(tf, shift);
   if(bt == 0) return 0.0;
   MqlDateTime d; TimeToStruct(bt, d); d.hour = 0; d.min = 0; d.sec = 0;
   datetime dayStart = StructToTime(d);
   double pv = 0, vv = 0;
   for(int i = shift; i < shift + 1500; i++)
     {
      datetime t = T(tf, i);
      if(t == 0 || t < dayStart) break;
      double tp = (H(tf, i) + L(tf, i) + C(tf, i)) / 3.0;
      double v  = (double)iVolume(_Symbol, tf, i);
      pv += tp * v; vv += v;
     }
   return (vv > 0 ? pv / vv : C(tf, shift));
  }

//+------------------------------------------------------------------+
//| Generic directional bias for a timeframe (MTF / filters)         |
//+------------------------------------------------------------------+
int TFBias(ENUM_TIMEFRAMES tf, int emaHandle, ENUM_MTF_METHOD method)
  {
   switch(method)
     {
      case MTFM_EMA_SLOPE:
        {
         double e1 = Buf(emaHandle, 0, 1), e3 = Buf(emaHandle, 0, 3);
         if(!Valid(e1) || !Valid(e3)) return 0;
         return (e1 > e3 ? 1 : (e1 < e3 ? -1 : 0));
        }
      case MTFM_PRICE_VS_EMA:
        {
         double e = Buf(emaHandle, 0, 1);
         if(!Valid(e)) return 0;
         double c = C(tf, 1);
         return (c > e ? 1 : (c < e ? -1 : 0));
        }
      case MTFM_CANDLE_DIR:
         return (Bull(tf, 1) ? 1 : (Bear(tf, 1) ? -1 : 0));
      case MTFM_STRUCTURE:
         return StructureBias(tf, 2);
     }
   return 0;
  }

//--- Direction-TF trend (+1 / -1 / 0) from the direction EMA
int DirectionTrend()
  {
   double e = Buf(g_hDirEMA, 0, 1);
   if(!Valid(e)) return 0;
   double c = C(InpDirectionTF, 1);
   return (c > e ? 1 : (c < e ? -1 : 0));
  }
//+------------------------------------------------------------------+
