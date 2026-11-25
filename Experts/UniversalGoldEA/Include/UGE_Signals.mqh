//+------------------------------------------------------------------+
//|                                                UGE_Signals.mqh   |
//|  Entry modules. Each returns +1 (buy), -1 (sell) or 0 (none).    |
//|  Every module works alone so it can be back-tested on its own.   |
//|  Closed-bar logic uses shift >= 1 (no repaint). Only the candle  |
//|  module's "NOW" selection reads the forming bar, by design.      |
//+------------------------------------------------------------------+

//--- indicator handles for module 07
int g_hEMAf = INVALID_HANDLE, g_hEMAs = INVALID_HANDLE, g_hSMAf = INVALID_HANDLE, g_hSMAs = INVALID_HANDLE;
int g_hRSI = INVALID_HANDLE, g_hMACD = INVALID_HANDLE, g_hStoch = INVALID_HANDLE, g_hBB = INVALID_HANDLE;
int g_hATRi = INVALID_HANDLE, g_hADX = INVALID_HANDLE, g_hCCI = INVALID_HANDLE, g_hIchi = INVALID_HANDLE, g_hSAR = INVALID_HANDLE;
//--- strategy preset handles
int g_hSEMA20 = INVALID_HANDLE, g_hSEMA50 = INVALID_HANDLE, g_hSEMA200 = INVALID_HANDLE, g_hSRSI = INVALID_HANDLE;
int g_hSBB = INVALID_HANDLE, g_hSMACD = INVALID_HANDLE, g_hSADX = INVALID_HANDLE, g_hSATR = INVALID_HANDLE;
int g_hSEMA9 = INVALID_HANDLE, g_hSEMA21 = INVALID_HANDLE;

//--- signal identity (used by "one trade per signal")
string g_lastSignalId = "";

//==================================================================
//| 04 CANDLE ENTRY                                                  |
//==================================================================
//--- size filters for a colour-based candle
bool CandleQuality(ENUM_TIMEFRAMES tf, int s)
  {
   double rg = Range(tf, s);
   if(rg <= 0) return false;
   if(InpMinimumBodySize > 0 && Body(tf, s) < Pts(InpMinimumBodySize)) return false;
   if(InpMaximumWickRatio > 0 && InpMaximumWickRatio < 1.0 && (rg - Body(tf, s)) / rg > InpMaximumWickRatio) return false;
   return true;
  }

int CandleSignal()
  {
   ENUM_TIMEFRAMES tf = InpCandleTF;
   int s = (InpCandleSelection == CANDLE_BEFORE ? 1 : 0);
   switch(InpCandlePatternMode)
     {
      case CP_PREV_BULLISH_BUY:  return (Bull(tf, s) && CandleQuality(tf, s) ? 1 : 0);
      case CP_PREV_BEARISH_SELL: return (Bear(tf, s) && CandleQuality(tf, s) ? -1 : 0);
      case CP_PREV_COLOR_FOLLOW:
         if(!CandleQuality(tf, s)) return 0;
         return (Bull(tf, s) ? 1 : (Bear(tf, s) ? -1 : 0));
      case CP_PREV_COLOR_REVERSE:
         if(!CandleQuality(tf, s)) return 0;
         return (Bear(tf, s) ? 1 : (Bull(tf, s) ? -1 : 0));
      case CP_TWO_BULLISH_BUY:   return (Bull(tf, s) && Bull(tf, s + 1) && CandleQuality(tf, s) ? 1 : 0);
      case CP_TWO_BEARISH_SELL:  return (Bear(tf, s) && Bear(tf, s + 1) && CandleQuality(tf, s) ? -1 : 0);
      case CP_THREE_CANDLE_CONFIRM:
         if(Bull(tf, s) && Bull(tf, s + 1) && Bull(tf, s + 2) && C(tf, s) > H(tf, s + 1)) return 1;
         if(Bear(tf, s) && Bear(tf, s + 1) && Bear(tf, s + 2) && C(tf, s) < L(tf, s + 1)) return -1;
         return 0;
      case CP_CONSECUTIVE:
        {
         int nreq = MathMax(1, InpRequiredCandles), up = 0, dn = 0;
         for(int i = s; i < s + nreq; i++) { if(Bull(tf, i)) up++; else if(Bear(tf, i)) dn++; }
         if(up == nreq && CandleQuality(tf, s)) return 1;
         if(dn == nreq && CandleQuality(tf, s)) return -1;
         return 0;
        }
      case CP_ENGULFING:
         if(Bear(tf, s + 1) && Bull(tf, s) && C(tf, s) >= O(tf, s + 1) && O(tf, s) <= C(tf, s + 1) && Body(tf, s) > Body(tf, s + 1)) return 1;
         if(Bull(tf, s + 1) && Bear(tf, s) && C(tf, s) <= O(tf, s + 1) && O(tf, s) >= C(tf, s + 1) && Body(tf, s) > Body(tf, s + 1)) return -1;
         return 0;
      case CP_PIN_BAR:
        {
         double b = MathMax(Body(tf, s), _Point), rg = Range(tf, s);
         if(rg <= 0) return 0;
         if(LowerWick(tf, s) >= InpPinBarRatio * b && UpperWick(tf, s) <= b && LowerWick(tf, s) >= 0.6 * rg) return 1;
         if(UpperWick(tf, s) >= InpPinBarRatio * b && LowerWick(tf, s) <= b && UpperWick(tf, s) >= 0.6 * rg) return -1;
         return 0;
        }
      case CP_INSIDE_BAR:
         //--- bar s+1 inside mother bar s+2, bar s closes beyond the inside bar
         if(H(tf, s + 1) < H(tf, s + 2) && L(tf, s + 1) > L(tf, s + 2))
           {
            if(C(tf, s) > H(tf, s + 1)) return 1;
            if(C(tf, s) < L(tf, s + 1)) return -1;
           }
         return 0;
      case CP_OUTSIDE_BAR:
         if(H(tf, s) > H(tf, s + 1) && L(tf, s) < L(tf, s + 1))
            return (Bull(tf, s) ? 1 : (Bear(tf, s) ? -1 : 0));
         return 0;
      case CP_DOJI_REVERSAL:
        {
         double rg = Range(tf, s + 1);
         if(rg <= 0 || Body(tf, s + 1) > InpDojiBodyRatio * rg) return 0;
         if(Bear(tf, s + 2) && Bull(tf, s) && C(tf, s) > H(tf, s + 1)) return 1;
         if(Bull(tf, s + 2) && Bear(tf, s) && C(tf, s) < L(tf, s + 1)) return -1;
         return 0;
        }
      case CP_HIGH_BREAKOUT:
        {
         double lvl = H(tf, s + 1);
         double px  = (s == 0 ? SymBid() : C(tf, s));
         return (px > lvl && (s == 0 || C(tf, s + 1) <= lvl) ? 1 : 0);
        }
      case CP_LOW_BREAKOUT:
        {
         double lvl = L(tf, s + 1);
         double px  = (s == 0 ? SymBid() : C(tf, s));
         return (px < lvl && (s == 0 || C(tf, s + 1) >= lvl) ? -1 : 0);
        }
      case CP_BODY_BREAKOUT:
        {
         double top = MathMax(O(tf, s + 1), C(tf, s + 1)), bot = MathMin(O(tf, s + 1), C(tf, s + 1));
         double px  = (s == 0 ? SymBid() : C(tf, s));
         if(px > top && Body(tf, s) > 0) return 1;
         if(px < bot && Body(tf, s) > 0) return -1;
         return 0;
        }
      case CP_WICK_REJECTION:
        {
         double rg = Range(tf, s);
         if(rg <= 0) return 0;
         double mid = (H(tf, s) + L(tf, s)) / 2.0;
         if(LowerWick(tf, s) >= InpWickRejectRatio * rg && C(tf, s) > mid) return 1;
         if(UpperWick(tf, s) >= InpWickRejectRatio * rg && C(tf, s) < mid) return -1;
         return 0;
        }
     }
   return 0;
  }

//==================================================================
//| 05 BREAKOUT ENTRY                                                |
//==================================================================
int    g_boPendDir = 0;      // breakout waiting for retest
double g_boPendLevel = 0;
int    g_boPendBars = 0;
datetime g_boPendBarTime = 0;

//--- session range [startMin,endMin) of the current server day on 'tf' (closed bars)
bool SessionRange(int startMin, int endMin, double &hi, double &lo)
  {
   hi = 0; lo = DBL_MAX;
   MqlDateTime d; TimeToStruct(TimeCurrent(), d); d.hour = 0; d.min = 0; d.sec = 0;
   datetime day = StructToTime(d);
   datetime ts = day + startMin * 60, te = day + endMin * 60;
   if(te <= ts) ts -= 86400; // window crossed midnight: started yesterday
   if(TimeCurrent() < te) return false; // range not finished yet
   for(int i = 1; i < 2000; i++)
     {
      datetime t = T(PERIOD_M5, i);
      if(t == 0 || t < ts) break;
      if(t >= te) continue;
      hi = MathMax(hi, H(PERIOD_M5, i)); lo = MathMin(lo, L(PERIOD_M5, i));
     }
   return (hi > 0 && lo < DBL_MAX);
  }

//--- trading window for session breakouts (entries only inside it)
bool InMinuteWindow(int s, int e) { int now = MinuteOfDay(TimeCurrent()); return InWindow(s, e, now); }

//--- compute breakout levels for the selected mode. Returns false if no level
bool BreakoutLevels(double &upLvl, double &dnLvl)
  {
   ENUM_TIMEFRAMES tf = InpBreakoutTF;
   upLvl = 0; dnLvl = 0;
   int as = InpAsianStartHour * 60, ae = InpAsianEndHour * 60;
   int ls = InpLondonStartHour * 60, le = InpLondonEndHour * 60;
   int ns = InpNYStartHour * 60, ne = InpNYEndHour * 60;
   double hi, lo;
   switch(InpBreakoutMode)
     {
      case BO_PREV_CANDLE_HIGH: upLvl = H(tf, 2); break;
      case BO_PREV_CANDLE_LOW:  dnLvl = L(tf, 2); break;
      case BO_PREV_CANDLE_HL:   upLvl = H(tf, 2); dnLvl = L(tf, 2); break;
      case BO_DAILY_HL:         upLvl = iHigh(_Symbol, PERIOD_D1, 1); dnLvl = iLow(_Symbol, PERIOD_D1, 1); break;
      case BO_WEEKLY_HL:        upLvl = iHigh(_Symbol, PERIOD_W1, 1); dnLvl = iLow(_Symbol, PERIOD_W1, 1); break;
      case BO_ASIAN_SESSION:
         if(!InMinuteWindow(as, ae)) return false;
         if(!SessionRange(as, (as + InpAsianRangeMinutes) % 1440, hi, lo)) return false;
         upLvl = hi; dnLvl = lo; break;
      case BO_LONDON_SESSION:
         if(!InMinuteWindow(ls, le)) return false;
         if(!SessionRange(as, ae, hi, lo)) return false;
         upLvl = hi; dnLvl = lo; break;
      case BO_NEWYORK_SESSION:
         if(!InMinuteWindow(ns, ne)) return false;
         if(!SessionRange(ls, ns, hi, lo)) return false;
         upLvl = hi; dnLvl = lo; break;
      case BO_RANGE:
         hi = HighestHigh(tf, InpRangeBars, 2); lo = LowestLow(tf, InpRangeBars, 2);
         if(hi - lo > Pts(InpMaxRangePoints)) return false; // not a consolidation
         upLvl = hi; dnLvl = lo; break;
      case BO_SUPPORT_RESIST:
        {
         double hp[], lp[]; int hs[], ls2[];
         if(GetPivotHighs(tf, InpSwingBars, 200, hp, hs, 1) > 0) upLvl = hp[0];
         if(GetPivotLows(tf, InpSwingBars, 200, lp, ls2, 1) > 0) dnLvl = lp[0];
         break;
        }
      case BO_DONCHIAN:
         upLvl = HighestHigh(tf, InpRangeBars, 2); dnLvl = LowestLow(tf, InpRangeBars, 2); break;
      case BO_VOLATILITY:
        {
         double atrD = Buf(g_hDailyATR, 0, 1);
         if(!Valid(atrD)) return false;
         double dOpen = iOpen(_Symbol, PERIOD_D1, 0);
         upLvl = dOpen + InpVolBreakoutK * atrD; dnLvl = dOpen - InpVolBreakoutK * atrD; break;
        }
     }
   return (upLvl > 0 || dnLvl > 0);
  }

int BreakoutSignal()
  {
   ENUM_TIMEFRAMES tf = InpBreakoutTF;
   double buf = Pts(InpBreakoutBuffer), minD = Pts(InpMinBreakoutDistance);
   //--- pending retest state machine
   if(InpRetestConfirmation && g_boPendDir != 0)
     {
      if(T(tf, 0) != g_boPendBarTime) { g_boPendBarTime = T(tf, 0); g_boPendBars++; }
      if(g_boPendBars > InpMaximumRetestBars) { g_boPendDir = 0; return 0; }
      double tol = Pts(MathMax(InpBreakoutBuffer, 10));
      if(g_boPendDir > 0 && L(tf, 1) <= g_boPendLevel + tol && C(tf, 1) > g_boPendLevel) { g_boPendDir = 0; return 1; }
      if(g_boPendDir < 0 && H(tf, 1) >= g_boPendLevel - tol && C(tf, 1) < g_boPendLevel) { g_boPendDir = 0; return -1; }
      return 0;
     }
   double up, dn;
   if(!BreakoutLevels(up, dn)) return 0;
   int sig = 0;
   if(InpRequireCandleClose)
     {
      //--- crossing on the last closed bar (no repeat on the same level)
      if(up > 0 && C(tf, 1) > up + buf + minD && C(tf, 2) <= up + buf) sig = 1;
      if(dn > 0 && C(tf, 1) < dn - buf - minD && C(tf, 2) >= dn - buf) sig = -1;
     }
   else
     {
      //--- intrabar: bar 1 had not broken, the forming bar is through the level now
      if(up > 0 && SymBid() > up + buf + minD && H(tf, 1) <= up + buf) sig = 1;
      if(dn > 0 && SymBid() < dn - buf - minD && L(tf, 1) >= dn - buf) sig = -1;
     }
   if(sig == 0) return 0;
   if(InpRetestConfirmation)
     {
      g_boPendDir = sig; g_boPendLevel = (sig > 0 ? up : dn); g_boPendBars = 0; g_boPendBarTime = T(tf, 0);
      LogDebug("Breakout armed, waiting for retest at " + DoubleToString(g_boPendLevel, _Digits));
      return 0;
     }
   return sig;
  }

//==================================================================
//| 06 PULLBACK ENTRY                                                |
//==================================================================
//--- confirmation candle check at shift 1 for direction 'dir'
bool PullbackConfirm(int dir)
  {
   ENUM_TIMEFRAMES tf = InpPullbackTF;
   if(InpRequireRejection)
     {
      double rg = Range(tf, 1);
      if(rg <= 0) return false;
      if(dir > 0 && LowerWick(tf, 1) < 0.3 * rg) return false;
      if(dir < 0 && UpperWick(tf, 1) < 0.3 * rg) return false;
     }
   switch(InpEntryConfirmation)
     {
      case CONF_NONE:      return true;
      case CONF_CLOSE_DIR: return (dir > 0 ? Bull(tf, 1) : Bear(tf, 1));
      case CONF_ENGULFING:
         return (dir > 0 ? (Bull(tf, 1) && C(tf, 1) > O(tf, 2) && Body(tf, 1) > Body(tf, 2))
                         : (Bear(tf, 1) && C(tf, 1) < O(tf, 2) && Body(tf, 1) > Body(tf, 2)));
      case CONF_NEXT_BAR_BREAK:
         return (dir > 0 ? C(tf, 1) > H(tf, 2) : C(tf, 1) < L(tf, 2));
     }
   return true;
  }

//--- setup bar: 1 normally, 2 when the next bar must break it
int PBShift() { return (InpEntryConfirmation == CONF_NEXT_BAR_BREAK ? 2 : 1); }

int PullbackSetup()
  {
   ENUM_TIMEFRAMES tf = InpPullbackTF;
   int s = PBShift();
   double tol = Pts(InpPullbackDistance);
   switch(InpPullbackMode)
     {
      case PB_EMA:
        {
         double e = Buf(g_hPullEMA, 0, s), eOld = Buf(g_hPullEMA, 0, s + 5);
         if(!Valid(e) || !Valid(eOld)) return 0;
         //--- impulse: price was well away from the EMA within MaximumWaitBars
         double farH = HighestHigh(tf, InpMaximumWaitBars, s + 1), farL = LowestLow(tf, InpMaximumWaitBars, s + 1);
         if(e > eOld && C(tf, s) > e && L(tf, s) <= e + tol && farH - e >= 2 * tol) return 1;
         if(e < eOld && C(tf, s) < e && H(tf, s) >= e - tol && e - farL >= 2 * tol) return -1;
         return 0;
        }
      case PB_SUPPORT_RESIST:
        {
         //--- most recent swing high that price has since broken above = new support
         double hp[], lp[]; int hs[], ls[];
         int nh = GetPivotHighs(tf, InpSwingBars, 200, hp, hs, 5);
         for(int i = 0; i < nh; i++)
           {
            if(hs[i] > InpMaximumWaitBars * 3) break;
            if(hs[i] - s < 1) continue;
            double brokeHi = HighestHigh(tf, hs[i] - s, s);
            if(brokeHi > hp[i] + tol && L(tf, s) <= hp[i] + tol && C(tf, s) > hp[i]) return 1;
           }
         int nl = GetPivotLows(tf, InpSwingBars, 200, lp, ls, 5);
         for(int j = 0; j < nl; j++)
           {
            if(ls[j] > InpMaximumWaitBars * 3) break;
            if(ls[j] - s < 1) continue;
            double brokeLo = LowestLow(tf, ls[j] - s, s);
            if(brokeLo < lp[j] - tol && H(tf, s) >= lp[j] - tol && C(tf, s) < lp[j]) return -1;
           }
         return 0;
        }
      case PB_FIBONACCI:
        {
         double hp[], lp[]; int hs[], ls[];
         if(GetPivotHighs(tf, InpSwingBars, 300, hp, hs, 1) < 1 || GetPivotLows(tf, InpSwingBars, 300, lp, ls, 1) < 1) return 0;
         double rg = hp[0] - lp[0];
         if(rg <= 0) return 0;
         if(ls[0] > hs[0]) // impulse up (low older than high): buy in retracement zone
           {
            double zHi = hp[0] - InpFiboMin * rg, zLo = hp[0] - InpFiboMax * rg;
            if(L(tf, s) <= zHi && C(tf, s) >= zLo && C(tf, s) > lp[0]) return 1;
           }
         else
           {
            double zLo = lp[0] + InpFiboMin * rg, zHi = lp[0] + InpFiboMax * rg;
            if(H(tf, s) >= zLo && C(tf, s) <= zHi && C(tf, s) < hp[0]) return -1;
           }
         return 0;
        }
      case PB_TRENDLINE:
        {
         double hp[], lp[]; int hs[], ls[];
         if(GetPivotLows(tf, InpSwingBars, 300, lp, ls, 2) == 2 && lp[0] > lp[1] && ls[1] != ls[0])
           {
            double slope = (lp[0] - lp[1]) / (ls[1] - ls[0]);
            double line  = lp[0] + slope * (ls[0] - s);
            if(L(tf, s) <= line + tol && C(tf, s) > line) return 1;
           }
         if(GetPivotHighs(tf, InpSwingBars, 300, hp, hs, 2) == 2 && hp[0] < hp[1] && hs[1] != hs[0])
           {
            double slope = (hp[1] - hp[0]) / (hs[1] - hs[0]);
            double line  = hp[0] - slope * (hs[0] - s);
            if(H(tf, s) >= line - tol && C(tf, s) < line) return -1;
           }
         return 0;
        }
      case PB_VWAP:
        {
         double v = VWAPAt(tf, s), vPrev = VWAPAt(tf, s + 3);
         if(v <= 0) return 0;
         if(C(tf, s + 3) > vPrev && C(tf, s) > v && L(tf, s) <= v + tol) return 1;
         if(C(tf, s + 3) < vPrev && C(tf, s) < v && H(tf, s) >= v - tol) return -1;
         return 0;
        }
      case PB_BREAKOUT_RETEST:
        {
         //--- a Donchian break happened within MaximumWaitBars; price now retests that level
         for(int k = s + 1; k <= s + InpMaximumWaitBars; k++)
           {
            double up = HighestHigh(tf, InpRangeBars, k + 1), dn = LowestLow(tf, InpRangeBars, k + 1);
            if(C(tf, k) > up && L(tf, s) <= up + tol && C(tf, s) > up) return 1;
            if(C(tf, k) < dn && H(tf, s) >= dn - tol && C(tf, s) < dn) return -1;
           }
         return 0;
        }
      case PB_ORDER_BLOCK:
         if(!g_smc.Update()) return 0;
         if(g_smc.ZoneSignal(ZONE_OB, 1, 0, InpMitigationMode)) return 1;
         if(g_smc.ZoneSignal(ZONE_OB, -1, 0, InpMitigationMode)) return -1;
         return 0;
      case PB_FVG:
         if(!g_smc.Update()) return 0;
         if(g_smc.ZoneSignal(ZONE_FVG, 1, 0, InpMitigationMode)) return 1;
         if(g_smc.ZoneSignal(ZONE_FVG, -1, 0, InpMitigationMode)) return -1;
         return 0;
     }
   return 0;
  }

int PullbackSignal()
  {
   int d = PullbackSetup();
   if(d == 0) return 0;
   return (PullbackConfirm(d) ? d : 0);
  }

//==================================================================
//| 07 INDICATOR ENTRY                                               |
//| Each enabled indicator reports allowBuy / allowSell and whether  |
//| it is directional. Buy needs every enabled indicator to allow it |
//| and at least InpIndMinVotes directional buy votes.               |
//==================================================================
struct SVote { bool buy; bool sell; bool directional; };

void VoteSet(SVote &v, int dir) { v.buy = (dir > 0); v.sell = (dir < 0); v.directional = true; }
void VoteGate(SVote &v, bool ok) { v.buy = ok; v.sell = ok; v.directional = false; }

//--- generic two-line logic (fast/slow lines) for MA-type indicators
void VoteMA(SVote &v, int hf, int hs, ENUM_IND_LOGIC logic)
  {
   double f1 = Buf(hf, 0, 1), f2 = Buf(hf, 0, 2), s1 = Buf(hs, 0, 1), s2 = Buf(hs, 0, 2), s4 = Buf(hs, 0, 4);
   if(!Valid(f1) || !Valid(f2) || !Valid(s1) || !Valid(s2) || !Valid(s4)) { VoteGate(v, false); return; }
   double c1 = C(InpIndTF, 1);
   switch(logic)
     {
      case ILOGIC_CROSS:    VoteSet(v, (f2 <= s2 && f1 > s1) ? 1 : ((f2 >= s2 && f1 < s1) ? -1 : 0)); break;
      case ILOGIC_LEVEL:    VoteSet(v, c1 > s1 ? 1 : (c1 < s1 ? -1 : 0)); break;
      case ILOGIC_TREND:    VoteSet(v, (f1 > s1 && s1 > s4) ? 1 : ((f1 < s1 && s1 < s4) ? -1 : 0)); break;
      case ILOGIC_MOMENTUM: VoteSet(v, (f1 - s1 > f2 - s2 && f1 > s1) ? 1 : ((f1 - s1 < f2 - s2 && f1 < s1) ? -1 : 0)); break;
      default:              VoteSet(v, f1 > s1 ? 1 : -1); break;
     }
  }

//--- oscillator logic (value vs overbought/oversold/mid)
void VoteOsc(SVote &v, double x1, double x2, double ob, double os, double mid, ENUM_IND_LOGIC logic)
  {
   switch(logic)
     {
      case ILOGIC_OBOS:     VoteSet(v, (x2 < os && x1 >= os) ? 1 : ((x2 > ob && x1 <= ob) ? -1 : 0)); break;
      case ILOGIC_CROSS:
      case ILOGIC_LEVEL:    VoteSet(v, (x2 <= mid && x1 > mid) ? 1 : ((x2 >= mid && x1 < mid) ? -1 : 0)); break;
      case ILOGIC_TREND:    VoteSet(v, (x1 > mid && x1 < ob) ? 1 : ((x1 < mid && x1 > os) ? -1 : 0)); break;
      case ILOGIC_MOMENTUM: VoteSet(v, (x1 > x2 && x1 > mid) ? 1 : ((x1 < x2 && x1 < mid) ? -1 : 0)); break;
      case ILOGIC_VOLATILITY: VoteGate(v, MathAbs(x1 - mid) > MathAbs(x2 - mid)); break;
     }
  }

int IndicatorSignal()
  {
   SVote votes[];
   int n = 0;
   ENUM_TIMEFRAMES tf = InpIndTF;
   double c1 = C(tf, 1), c2 = C(tf, 2);
   //--- EMA / SMA
   if(InpUseEMA) { ArrayResize(votes, n + 1); VoteMA(votes[n], g_hEMAf, g_hEMAs, InpEMALogic); n++; }
   if(InpUseSMA) { ArrayResize(votes, n + 1); VoteMA(votes[n], g_hSMAf, g_hSMAs, InpSMALogic); n++; }
   //--- RSI
   if(InpUseRSI)
     {
      ArrayResize(votes, n + 1);
      double r1 = Buf(g_hRSI, 0, 1), r2 = Buf(g_hRSI, 0, 2);
      if(Valid(r1) && Valid(r2)) VoteOsc(votes[n], r1, r2, InpRSIOverbought, InpRSIOversold, 50, InpRSILogic); else VoteGate(votes[n], false);
      n++;
     }
   //--- MACD
   if(InpUseMACD)
     {
      ArrayResize(votes, n + 1);
      double m1 = Buf(g_hMACD, 0, 1), m2 = Buf(g_hMACD, 0, 2), sg1 = Buf(g_hMACD, 1, 1), sg2 = Buf(g_hMACD, 1, 2);
      if(!Valid(m1) || !Valid(m2) || !Valid(sg1) || !Valid(sg2)) VoteGate(votes[n], false);
      else switch(InpMACDLogic)
        {
         case ILOGIC_CROSS:    VoteSet(votes[n], (m2 <= sg2 && m1 > sg1) ? 1 : ((m2 >= sg2 && m1 < sg1) ? -1 : 0)); break;
         case ILOGIC_LEVEL:    VoteSet(votes[n], (m2 <= 0 && m1 > 0) ? 1 : ((m2 >= 0 && m1 < 0) ? -1 : 0)); break;
         case ILOGIC_TREND:    VoteSet(votes[n], (m1 > 0 && m1 > sg1) ? 1 : ((m1 < 0 && m1 < sg1) ? -1 : 0)); break;
         case ILOGIC_MOMENTUM: VoteSet(votes[n], (m1 - sg1 > m2 - sg2) ? 1 : ((m1 - sg1 < m2 - sg2) ? -1 : 0)); break;
         default:              VoteGate(votes[n], MathAbs(m1 - sg1) > MathAbs(m2 - sg2)); break;
        }
      n++;
     }
   //--- Stochastic
   if(InpUseStoch)
     {
      ArrayResize(votes, n + 1);
      double k1 = Buf(g_hStoch, 0, 1), k2 = Buf(g_hStoch, 0, 2), d1 = Buf(g_hStoch, 1, 1), d2 = Buf(g_hStoch, 1, 2);
      if(!Valid(k1) || !Valid(k2) || !Valid(d1) || !Valid(d2)) VoteGate(votes[n], false);
      else if(InpStochLogic == ILOGIC_CROSS)
         VoteSet(votes[n], (k2 <= d2 && k1 > d1 && k1 < 50) ? 1 : ((k2 >= d2 && k1 < d1 && k1 > 50) ? -1 : 0));
      else VoteOsc(votes[n], k1, k2, InpStochOverbought, InpStochOversold, 50, InpStochLogic);
      n++;
     }
   //--- Bollinger Bands
   if(InpUseBB)
     {
      ArrayResize(votes, n + 1);
      double mid = Buf(g_hBB, 0, 1), up1 = Buf(g_hBB, 1, 1), lo1 = Buf(g_hBB, 2, 1), up2 = Buf(g_hBB, 1, 2), lo2 = Buf(g_hBB, 2, 2);
      if(!Valid(mid) || !Valid(up1) || !Valid(lo1) || !Valid(up2) || !Valid(lo2)) VoteGate(votes[n], false);
      else switch(InpBBLogic)
        {
         case ILOGIC_OBOS:  VoteSet(votes[n], (c2 < lo2 && c1 > lo1) ? 1 : ((c2 > up2 && c1 < up1) ? -1 : 0)); break; // re-entry
         case ILOGIC_CROSS: VoteSet(votes[n], (c2 <= up2 && c1 > up1) ? 1 : ((c2 >= lo2 && c1 < lo1) ? -1 : 0)); break; // breakout
         case ILOGIC_VOLATILITY: VoteGate(votes[n], (up1 - lo1) > (up2 - lo2)); break; // bands expanding
         default:           VoteSet(votes[n], c1 > mid ? 1 : (c1 < mid ? -1 : 0)); break;
        }
      n++;
     }
   //--- ATR (volatility gate)
   if(InpUseATRInd)
     {
      ArrayResize(votes, n + 1);
      double a = Buf(g_hATRi, 0, 1);
      VoteGate(votes[n], Valid(a) && ToPts(a) >= InpATRIndMinPoints && ToPts(a) <= InpATRIndMaxPoints);
      n++;
     }
   //--- ADX
   if(InpUseADX)
     {
      ArrayResize(votes, n + 1);
      double adx = Buf(g_hADX, 0, 1), pdi = Buf(g_hADX, 1, 1), mdi = Buf(g_hADX, 2, 1), pdi2 = Buf(g_hADX, 1, 2), mdi2 = Buf(g_hADX, 2, 2);
      if(!Valid(adx) || !Valid(pdi) || !Valid(mdi)) VoteGate(votes[n], false);
      else if(InpADXLogic == ILOGIC_VOLATILITY || InpADXLogic == ILOGIC_LEVEL) VoteGate(votes[n], adx >= InpADXLevel);
      else if(InpADXLogic == ILOGIC_CROSS)
         VoteSet(votes[n], adx >= InpADXLevel ? ((pdi2 <= mdi2 && pdi > mdi) ? 1 : ((pdi2 >= mdi2 && pdi < mdi) ? -1 : 0)) : 0);
      else VoteSet(votes[n], adx >= InpADXLevel ? (pdi > mdi ? 1 : -1) : 0);
      n++;
     }
   //--- CCI
   if(InpUseCCI)
     {
      ArrayResize(votes, n + 1);
      double x1 = Buf(g_hCCI, 0, 1), x2 = Buf(g_hCCI, 0, 2);
      if(Valid(x1) && Valid(x2)) VoteOsc(votes[n], x1, x2, InpCCILevel, -InpCCILevel, 0, InpCCILogic); else VoteGate(votes[n], false);
      n++;
     }
   //--- Ichimoku
   if(InpUseIchimoku)
     {
      ArrayResize(votes, n + 1);
      double tk1 = Buf(g_hIchi, 0, 1), kj1 = Buf(g_hIchi, 1, 1), tk2 = Buf(g_hIchi, 0, 2), kj2 = Buf(g_hIchi, 1, 2);
      double sa = Buf(g_hIchi, 2, 1), sb = Buf(g_hIchi, 3, 1);
      if(!Valid(tk1) || !Valid(kj1) || !Valid(sa) || !Valid(sb)) VoteGate(votes[n], false);
      else if(InpIchiLogic == ILOGIC_CROSS)
         VoteSet(votes[n], (tk2 <= kj2 && tk1 > kj1) ? 1 : ((tk2 >= kj2 && tk1 < kj1) ? -1 : 0));
      else
         VoteSet(votes[n], (c1 > MathMax(sa, sb) && tk1 > kj1) ? 1 : ((c1 < MathMin(sa, sb) && tk1 < kj1) ? -1 : 0));
      n++;
     }
   //--- Parabolic SAR
   if(InpUseSAR)
     {
      ArrayResize(votes, n + 1);
      double s1 = Buf(g_hSAR, 0, 1), s2 = Buf(g_hSAR, 0, 2);
      if(!Valid(s1) || !Valid(s2)) VoteGate(votes[n], false);
      else if(InpSARLogic == ILOGIC_CROSS)
         VoteSet(votes[n], (s2 > C(tf, 2) && s1 < c1) ? 1 : ((s2 < C(tf, 2) && s1 > c1) ? -1 : 0));
      else VoteSet(votes[n], s1 < c1 ? 1 : -1);
      n++;
     }
   //--- VWAP
   if(InpUseVWAP)
     {
      ArrayResize(votes, n + 1);
      double v1 = VWAPAt(tf, 1), v2 = VWAPAt(tf, 2);
      if(InpVWAPLogic == ILOGIC_CROSS) VoteSet(votes[n], (c2 <= v2 && c1 > v1) ? 1 : ((c2 >= v2 && c1 < v1) ? -1 : 0));
      else VoteSet(votes[n], c1 > v1 ? 1 : (c1 < v1 ? -1 : 0));
      n++;
     }
   if(n == 0) return 0;
   bool allBuy = true, allSell = true; int vb = 0, vs = 0;
   for(int i = 0; i < n; i++)
     {
      if(!votes[i].buy)  allBuy = false;
      if(!votes[i].sell) allSell = false;
      if(votes[i].directional && votes[i].buy)  vb++;
      if(votes[i].directional && votes[i].sell) vs++;
     }
   int minV = MathMax(1, InpIndMinVotes);
   if(allBuy && vb >= minV && !allSell) return 1;
   if(allSell && vs >= minV && !allBuy) return -1;
   return 0;
  }

//==================================================================
//| 27 ADVANCED STRATEGY PRESETS                                     |
//==================================================================
//--- z-score of close vs SMA over 'period' (shift 1)
double ZScore(ENUM_TIMEFRAMES tf, int period)
  {
   double s = 0, s2 = 0;
   for(int i = 1; i <= period; i++) { double c = C(tf, i); s += c; s2 += c * c; }
   double m = s / period, var = s2 / period - m * m;
   if(var <= 0) return 0;
   return (C(tf, 1) - m) / MathSqrt(var);
  }

//--- z-score of the price ratio XAU / paired symbol
double RatioZScore(ENUM_TIMEFRAMES tf, int period, string sym2)
  {
   double r[]; ArrayResize(r, period);
   double s = 0, s2 = 0;
   for(int i = 1; i <= period; i++)
     {
      double b = iClose(sym2, tf, i);
      if(b <= 0) return 0;
      r[i - 1] = C(tf, i) / b; s += r[i - 1]; s2 += r[i - 1] * r[i - 1];
     }
   double m = s / period, var = s2 / period - m * m;
   if(var <= 0) return 0;
   return (r[0] - m) / MathSqrt(var);
  }

int StrategySignal()
  {
   ENUM_TIMEFRAMES tf = InpStrategyTF;
   double c1 = C(tf, 1), c2 = C(tf, 2);
   double e20 = Buf(g_hSEMA20, 0, 1), e50 = Buf(g_hSEMA50, 0, 1), e200 = Buf(g_hSEMA200, 0, 1);
   double e20b = Buf(g_hSEMA20, 0, 2), e50b = Buf(g_hSEMA50, 0, 2);
   double rsi = Buf(g_hSRSI, 0, 1), rsi2 = Buf(g_hSRSI, 0, 2);
   double bbU = Buf(g_hSBB, 1, 1), bbL = Buf(g_hSBB, 2, 1), bbM = Buf(g_hSBB, 0, 1);
   double bbU2 = Buf(g_hSBB, 1, 2), bbL2 = Buf(g_hSBB, 2, 2);
   double mh1 = Buf(g_hSMACD, 0, 1) - Buf(g_hSMACD, 1, 1), mh2 = Buf(g_hSMACD, 0, 2) - Buf(g_hSMACD, 1, 2);
   double adx = Buf(g_hSADX, 0, 1), pdi = Buf(g_hSADX, 1, 1), mdi = Buf(g_hSADX, 2, 1);
   double atr = Buf(g_hSATR, 0, 1);
   if(!Valid(e20) || !Valid(e50) || !Valid(e200) || !Valid(rsi) || !Valid(bbU) || !Valid(adx) || !Valid(atr)) return 0;
   switch(InpStrategyMode)
     {
      case STRAT_TREND_FOLLOWING: // EMA stack + ADX strength + fresh EMA20 cross
         if(e20 > e50 && e50 > e200 && adx > 22 && pdi > mdi && c2 <= e20b && c1 > e20) return 1;
         if(e20 < e50 && e50 < e200 && adx > 22 && mdi > pdi && c2 >= e20b && c1 < e20) return -1;
         return 0;
      case STRAT_COUNTER_TREND:   // fade stretched moves: RSI extreme + close back inside BB
         if(rsi2 < 25 && rsi > rsi2 && c1 > bbL && c2 < bbL2) return 1;
         if(rsi2 > 75 && rsi < rsi2 && c1 < bbU && c2 > bbU2) return -1;
         return 0;
      case STRAT_MEAN_REVERSION:  // BB re-entry while ADX low (no strong trend)
         if(adx < 25 && c2 < bbL2 && c1 > bbL) return 1;
         if(adx < 25 && c2 > bbU2 && c1 < bbU) return -1;
         return 0;
      case STRAT_MOMENTUM:        // MACD histogram turn + RSI above/below 55/45 + price vs EMA50
         if(mh2 <= 0 && mh1 > 0 && rsi > 55 && c1 > e50) return 1;
         if(mh2 >= 0 && mh1 < 0 && rsi < 45 && c1 < e50) return -1;
         return 0;
      case STRAT_SCALPING:        // EMA9/21 cross with RSI midline, trend by EMA50
        {
         double f1 = Buf(g_hSEMA9, 0, 1), f2 = Buf(g_hSEMA9, 0, 2), s1 = Buf(g_hSEMA21, 0, 1), s2 = Buf(g_hSEMA21, 0, 2);
         if(!Valid(f1) || !Valid(s1)) return 0;
         if(f2 <= s2 && f1 > s1 && rsi > 50 && c1 > e50) return 1;
         if(f2 >= s2 && f1 < s1 && rsi < 50 && c1 < e50) return -1;
         return 0;
        }
      case STRAT_SWING:           // structure bias + pullback to EMA50 with RSI reset
        {
         int sb = StructureBias(tf, 3);
         if(sb > 0 && L(tf, 1) <= e50 && c1 > e50 && rsi2 < 50 && rsi > rsi2) return 1;
         if(sb < 0 && H(tf, 1) >= e50 && c1 < e50 && rsi2 > 50 && rsi < rsi2) return -1;
         return 0;
        }
      case STRAT_BREAKOUT_RETEST: // break of 20-bar high, retest within 8 bars
         for(int k = 2; k <= 9; k++)
           {
            double up = HighestHigh(tf, 20, k + 1), dn = LowestLow(tf, 20, k + 1);
            if(C(tf, k) > up && L(tf, 1) <= up + 0.2 * atr && c1 > up && Bull(tf, 1)) return 1;
            if(C(tf, k) < dn && H(tf, 1) >= dn - 0.2 * atr && c1 < dn && Bear(tf, 1)) return -1;
           }
         return 0;
      case STRAT_REVERSAL:        // engulfing at a 20-bar extreme with RSI divergence-lite
         if(L(tf, 1) <= LowestLow(tf, 20, 2) && Bull(tf, 1) && c1 > O(tf, 2) && Bear(tf, 2) && rsi > rsi2) return 1;
         if(H(tf, 1) >= HighestHigh(tf, 20, 2) && Bear(tf, 1) && c1 < O(tf, 2) && Bull(tf, 2) && rsi < rsi2) return -1;
         return 0;
      case STRAT_CONTINUATION:    // inside-bar break in direction of EMA50 > EMA200 trend
         if(H(tf, 2) < H(tf, 3) && L(tf, 2) > L(tf, 3))
           {
            if(e50 > e200 && c1 > H(tf, 2)) return 1;
            if(e50 < e200 && c1 < L(tf, 2)) return -1;
           }
         return 0;
      case STRAT_RANGE:           // ADX < 20, buy lower band / sell upper band with rejection
         if(adx < 20 && L(tf, 1) <= bbL && c1 > bbL && Bull(tf, 1) && c1 < bbM) return 1;
         if(adx < 20 && H(tf, 1) >= bbU && c1 < bbU && Bear(tf, 1) && c1 > bbM) return -1;
         return 0;
      case STRAT_VOLATILITY:      // ATR expansion vs 50-bar average range + range break
        {
         double avg = AvgRange(tf, 50, 2);
         if(avg <= 0 || Range(tf, 1) < 1.8 * avg) return 0;
         if(c1 > HighestHigh(tf, 10, 2)) return 1;
         if(c1 < LowestLow(tf, 10, 2)) return -1;
         return 0;
        }
      case STRAT_LIQUIDITY:       // sweep of a swing extreme and close back inside
        {
         double hp[], lp[]; int hs[], ls[];
         if(GetPivotLows(tf, 3, 150, lp, ls, 1) == 1 && L(tf, 1) < lp[0] && c1 > lp[0] && Bull(tf, 1)) return 1;
         if(GetPivotHighs(tf, 3, 150, hp, hs, 1) == 1 && H(tf, 1) > hp[0] && c1 < hp[0] && Bear(tf, 1)) return -1;
         return 0;
        }
      case STRAT_STATISTICAL:     // z-score extreme reversion
        {
         double z = ZScore(tf, MathMax(10, InpStatPeriod));
         if(z <= -InpStatZEntry && Bull(tf, 1)) return 1;
         if(z >=  InpStatZEntry && Bear(tf, 1)) return -1;
         return 0;
        }
      case STRAT_ARBITRAGE:       // gold/silver ratio z-score (single-leg statistical arbitrage)
        {
         double z = RatioZScore(tf, MathMax(10, InpStatPeriod), InpArbSymbol);
         if(z <= -InpStatZEntry) return 1;  // gold cheap vs pair
         if(z >=  InpStatZEntry) return -1; // gold rich vs pair
         return 0;
        }
     }
   return 0;
  }

//==================================================================
//| Combine enabled modules                                          |
//==================================================================
int CombinedSignal(string &why)
  {
   int sig[6]; string names[6] = {"Candle", "Breakout", "Pullback", "Indicator", "SMC", "Strategy"};
   bool on[6];
   on[0] = InpUseCandleEntry; on[1] = InpUseBreakoutEntry; on[2] = InpUsePullbackEntry;
   on[3] = InpUseIndicatorEntry; on[4] = InpUseSMCEntry; on[5] = InpUseStrategyEntry;
   sig[0] = on[0] ? CandleSignal()    : 0;
   sig[1] = on[1] ? BreakoutSignal()  : 0;
   sig[2] = on[2] ? PullbackSignal()  : 0;
   sig[3] = on[3] ? IndicatorSignal() : 0;
   sig[4] = on[4] ? SMCSignal()       : 0;
   sig[5] = on[5] ? StrategySignal()  : 0;
   int enabled = 0, up = 0, dn = 0;
   why = "";
   for(int i = 0; i < 6; i++)
     {
      if(!on[i]) continue;
      enabled++;
      if(sig[i] > 0) { up++; why += names[i] + "+ "; }
      if(sig[i] < 0) { dn++; why += names[i] + "- "; }
     }
   if(enabled == 0) return 0;
   switch(InpEntryCombine)
     {
      case COMBINE_ALL_AGREE: if(up == enabled) return 1; if(dn == enabled) return -1; return 0;
      case COMBINE_ANY:       if(up > 0 && dn == 0) return 1; if(dn > 0 && up == 0) return -1; return 0;
      case COMBINE_MAJORITY:  if(up * 2 > enabled && up > dn) return 1; if(dn * 2 > enabled && dn > up) return -1; return 0;
     }
   return 0;
  }
//+------------------------------------------------------------------+
