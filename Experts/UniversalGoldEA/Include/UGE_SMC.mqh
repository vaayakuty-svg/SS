//+------------------------------------------------------------------+
//|                                                    UGE_SMC.mqh   |
//|  Smart Money Concepts engine. Rebuilt once per new bar of its    |
//|  timeframe from CLOSED bars only (no repaint):                   |
//|  swings, BOS, CHOCH, liquidity sweeps (BSL/SSL), inducement,     |
//|  order blocks, FVGs, breaker blocks, mitigation blocks,          |
//|  premium / discount / equilibrium and displacement.              |
//+------------------------------------------------------------------+

#define ZONE_OB      0
#define ZONE_FVG     1
#define ZONE_BREAKER 2
#define ZONE_MITBLK  3

struct SZone
  {
   double top, bottom;
   int    dir;          // +1 bullish (buy zone), -1 bearish (sell zone)
   int    type;         // ZONE_*
   int    idx;          // creation bar index (array index, oldest = 0)
   bool   broken;
   int    touches;
   int    lastTouch;
   int    lastHalf;     // last bar that reached 50% of the zone
   bool   fromBOS;
   bool   disp;         // followed by displacement
  };

class CSMC
  {
public:
   ENUM_TIMEFRAMES tf;
   int      len, look;
   double   h[], l[], o[], c[];
   int      n;
   int      trend;                         // +1 bullish structure, -1 bearish, 0 unknown
   int      lastBullBOS, lastBearBOS, lastBullCHOCH, lastBearCHOCH;
   int      lastBullSweep, lastBearSweep;  // bull sweep = sell-side liquidity taken
   int      lastBullInduce, lastBearInduce;
   double   shPrice, slPrice, prevSH, prevSL;
   int      shIdx, slIdx;
   bool     shBroken, slBroken;
   double   minorHigh, minorLow;
   double   rangeHi, rangeLo, eq;
   double   avgRange;
   SZone    zones[];
   datetime lastBar;

   void     Init(ENUM_TIMEFRAMES t, int strength, int lookback)
     { tf = t; len = MathMax(1, strength); look = MathMax(60, lookback); lastBar = 0; n = 0; trend = 0; }

   bool     PivotH(int j, int s) { for(int k = 1; k <= s; k++) if(h[j - k] > h[j] || h[j + k] >= h[j]) return false; return true; }
   bool     PivotL(int j, int s) { for(int k = 1; k <= s; k++) if(l[j - k] < l[j] || l[j + k] <= l[j]) return false; return true; }

   void     AddZone(double top, double bottom, int dir, int type, int idx, bool bos, bool disp)
     {
      if(top <= bottom) return;
      int m = ArraySize(zones);
      if(m >= 60) { ArrayRemove(zones, 0, 1); m--; }
      ArrayResize(zones, m + 1);
      zones[m].top = top; zones[m].bottom = bottom; zones[m].dir = dir; zones[m].type = type;
      zones[m].idx = idx; zones[m].broken = false; zones[m].touches = 0; zones[m].lastTouch = -1;
      zones[m].lastHalf = -1; zones[m].fromBOS = bos; zones[m].disp = disp;
     }

   //--- rebuild structure; returns false if data not ready
   bool     Update()
     {
      datetime bt = iTime(_Symbol, tf, 0);
      if(bt == lastBar && n > 0) return true;
      int got = CopyHigh(_Symbol, tf, 1, look, h);
      if(got < 60 || CopyLow(_Symbol, tf, 1, got, l) != got || CopyOpen(_Symbol, tf, 1, got, o) != got ||
         CopyClose(_Symbol, tf, 1, got, c) != got) return false;
      n = got;
      lastBar = bt;
      ArrayResize(zones, 0);
      trend = 0;
      lastBullBOS = lastBearBOS = lastBullCHOCH = lastBearCHOCH = -1;
      lastBullSweep = lastBearSweep = lastBullInduce = lastBearInduce = -1;
      shPrice = slPrice = prevSH = prevSL = 0; shIdx = slIdx = -1; shBroken = slBroken = true;
      minorHigh = minorLow = 0;
      double eqHigh = 0, eqLow = 0;
      //--- average range of the last 50 bars (displacement reference)
      double sr = 0; int cnt = 0;
      for(int i = MathMax(0, n - 50); i < n; i++) { sr += h[i] - l[i]; cnt++; }
      avgRange = (cnt > 0 ? sr / cnt : 0);
      double tol    = InpEqualHLTolerance * _Point;
      double minFVG = InpFVGMinPoints * _Point;

      for(int k = 0; k < n; k++)
        {
         //--- 1) confirm major pivot at j = k - len (needs len bars to the right, all <= k)
         int j = k - len;
         if(j >= len)
           {
            if(PivotH(j, len))
              {
               if(shPrice > 0 && MathAbs(h[j] - shPrice) <= tol) eqHigh = MathMax(h[j], shPrice);
               prevSH = shPrice; shPrice = h[j]; shIdx = j; shBroken = false;
              }
            if(PivotL(j, len))
              {
               if(slPrice > 0 && MathAbs(l[j] - slPrice) <= tol) eqLow = MathMin(l[j], slPrice);
               prevSL = slPrice; slPrice = l[j]; slIdx = j; slBroken = false;
              }
           }
         //--- 2) inducement: minor (1-bar) pivot swept inside the trend
         if(k >= 2)
           {
            if(trend == 1 && minorLow > 0 && l[k] < minorLow && c[k] > minorLow && minorLow > slPrice) { lastBullInduce = k; minorLow = 0; }
            if(trend == -1 && minorHigh > 0 && h[k] > minorHigh && c[k] < minorHigh && minorHigh < shPrice) { lastBearInduce = k; minorHigh = 0; }
            int j1 = k - 1;
            if(h[j1] > h[j1 - 1] && h[j1] >= h[k]) minorHigh = h[j1];
            if(l[j1] < l[j1 - 1] && l[j1] <= l[k]) minorLow = l[j1];
           }
         //--- 3) liquidity sweeps
         double bsl = 0, ssl = 0;
         if(InpLiquidityMode == LIQ_SWING)    { if(!shBroken) bsl = shPrice; if(!slBroken) ssl = slPrice; }
         if(InpLiquidityMode == LIQ_EQUAL_HL) { bsl = eqHigh; ssl = eqLow; }
         if(bsl > 0 && h[k] > bsl && c[k] < bsl) { lastBearSweep = k; if(InpLiquidityMode == LIQ_EQUAL_HL) eqHigh = 0; }
         if(ssl > 0 && l[k] < ssl && c[k] > ssl) { lastBullSweep = k; if(InpLiquidityMode == LIQ_EQUAL_HL) eqLow = 0; }
         //--- 4) structure breaks
         double upRef = (InpStructureMode == STRUCT_CLOSE ? c[k] : h[k]);
         double dnRef = (InpStructureMode == STRUCT_CLOSE ? c[k] : l[k]);
         if(shIdx >= 0 && !shBroken && upRef > shPrice)
           {
            shBroken = true;
            bool choch = (trend == -1);
            if(choch) lastBullCHOCH = k; else lastBullBOS = k;
            //--- order block: last bearish candle between the swing low and the break
            int from = MathMax(0, (slIdx >= 0 ? slIdx : k - 20));
            for(int i = k - 1; i >= from; i--)
               if(c[i] < o[i])
                 {
                  double top = (InpOrderBlockMode == OB_BODY ? o[i] : h[i]);
                  double bot = (InpOrderBlockMode == OB_BODY ? c[i] : l[i]);
                  double mb = 0; for(int q = i + 1; q <= k; q++) mb = MathMax(mb, MathAbs(c[q] - o[q]));
                  AddZone(top, bot, 1, ZONE_OB, k, true, mb >= InpDisplacementATR * avgRange);
                  break;
                 }
            //--- mitigation block: CHOCH after a failed lower low (higher low formed)
            if(choch && slIdx >= 0 && prevSL > 0 && slPrice > prevSL)
               AddZone(MathMax(o[slIdx], c[slIdx]), l[slIdx], 1, ZONE_MITBLK, k, true, true);
            trend = 1;
           }
         if(slIdx >= 0 && !slBroken && dnRef < slPrice)
           {
            slBroken = true;
            bool choch = (trend == 1);
            if(choch) lastBearCHOCH = k; else lastBearBOS = k;
            int from = MathMax(0, (shIdx >= 0 ? shIdx : k - 20));
            for(int i = k - 1; i >= from; i--)
               if(c[i] > o[i])
                 {
                  double top = (InpOrderBlockMode == OB_BODY ? c[i] : h[i]);
                  double bot = (InpOrderBlockMode == OB_BODY ? o[i] : l[i]);
                  double mb = 0; for(int q = i + 1; q <= k; q++) mb = MathMax(mb, MathAbs(c[q] - o[q]));
                  AddZone(top, bot, -1, ZONE_OB, k, true, mb >= InpDisplacementATR * avgRange);
                  break;
                 }
            if(choch && shIdx >= 0 && prevSH > 0 && shPrice < prevSH)
               AddZone(h[shIdx], MathMin(o[shIdx], c[shIdx]), -1, ZONE_MITBLK, k, true, true);
            trend = -1;
           }
         //--- 5) fair value gaps (3-candle imbalance)
         if(k >= 2)
           {
            if(l[k] > h[k - 2] && l[k] - h[k - 2] >= minFVG) AddZone(l[k], h[k - 2], 1, ZONE_FVG, k, false, true);
            if(h[k] < l[k - 2] && l[k - 2] - h[k] >= minFVG) AddZone(l[k - 2], h[k], -1, ZONE_FVG, k, false, true);
           }
         //--- 6) zone touches / invalidation (zones created before bar k)
         int zc = ArraySize(zones);
         for(int z = 0; z < zc; z++)
           {
            if(zones[z].broken || zones[z].idx >= k) continue;
            double mid = (zones[z].top + zones[z].bottom) / 2.0;
            if(zones[z].dir > 0)
              {
               if(l[k] <= zones[z].top) { zones[z].touches++; zones[z].lastTouch = k; }
               if(l[k] <= mid) zones[z].lastHalf = k;
               if(c[k] < zones[z].bottom)
                 {
                  zones[z].broken = true;
                  if(zones[z].type == ZONE_OB) AddZone(zones[z].top, zones[z].bottom, -1, ZONE_BREAKER, k, false, true);
                 }
              }
            else
              {
               if(h[k] >= zones[z].bottom) { zones[z].touches++; zones[z].lastTouch = k; }
               if(h[k] >= mid) zones[z].lastHalf = k;
               if(c[k] > zones[z].top)
                 {
                  zones[z].broken = true;
                  if(zones[z].type == ZONE_OB) AddZone(zones[z].top, zones[z].bottom, 1, ZONE_BREAKER, k, false, true);
                 }
              }
           }
        }
      //--- dealing range and equilibrium
      int last = n - 1;
      rangeHi = shPrice; rangeLo = slPrice;
      if(trend == 1 && slIdx >= 0) { rangeLo = slPrice; rangeHi = h[ArrayMaximum(h, slIdx, last - slIdx + 1)]; }
      if(trend == -1 && shIdx >= 0) { rangeHi = shPrice; rangeLo = l[ArrayMinimum(l, shIdx, last - shIdx + 1)]; }
      eq = (rangeHi > rangeLo && rangeLo > 0 ? (rangeHi + rangeLo) / 2.0 : 0);
      return true;
     }

   //--- zone entry on the last closed bar
   bool     ZoneSignal(int type, int dir, int minIdx, ENUM_MIT_MODE mit)
     {
      int last = n - 1;
      for(int z = ArraySize(zones) - 1; z >= 0; z--)
        {
         if(zones[z].type != type || zones[z].dir != dir || zones[z].broken) continue;
         if(zones[z].idx < minIdx || zones[z].idx >= last) continue;
         if(zones[z].lastTouch != last) continue;
         if(type == ZONE_OB && InpDisplacementFilter && !zones[z].disp) continue;
         if(mit == MIT_FIRST_TOUCH && zones[z].touches != 1) continue;
         if(mit == MIT_50PCT && zones[z].lastHalf != last) continue;
         double mid = (zones[z].top + zones[z].bottom) / 2.0;
         double lvl = (dir > 0 ? zones[z].top : zones[z].bottom);
         if(type == ZONE_OB && InpOrderBlockMode == OB_MEAN) lvl = mid;
         if(type == ZONE_FVG && InpFVGMode == FVG_MID) lvl = mid;
         if(type == ZONE_FVG && InpFVGMode == FVG_FULL) lvl = (dir > 0 ? zones[z].bottom : zones[z].top);
         if(dir > 0 && l[last] <= lvl && c[last] > zones[z].bottom && c[last] > o[last]) return true;
         if(dir < 0 && h[last] >= lvl && c[last] < zones[z].top && c[last] < o[last]) return true;
        }
      return false;
     }

   //--- rejection candle on the last bar
   bool     Rejection(int dir)
     {
      int last = n - 1;
      double rg = h[last] - l[last];
      if(rg <= 0) return false;
      if(dir > 0) return (c[last] > o[last] && (MathMin(o[last], c[last]) - l[last]) >= 0.4 * rg);
      return (c[last] < o[last] && (h[last] - MathMax(o[last], c[last])) >= 0.4 * rg);
     }

   //--- raw signal for the selected SMC entry mode
   int      RawSignal(ENUM_SMC_ENTRY mode)
     {
      if(n < 60) return 0;
      int last = n - 1;
      switch(mode)
        {
         case SMC_ORDER_BLOCK:
            if(ZoneSignal(ZONE_OB, 1, 0, InpMitigationMode)) return 1;
            if(ZoneSignal(ZONE_OB, -1, 0, InpMitigationMode)) return -1;
            return 0;
         case SMC_FVG:
            if(ZoneSignal(ZONE_FVG, 1, 0, InpMitigationMode)) return 1;
            if(ZoneSignal(ZONE_FVG, -1, 0, InpMitigationMode)) return -1;
            return 0;
         case SMC_BOS:
            if(lastBullBOS == last) return 1;
            if(lastBearBOS == last) return -1;
            return 0;
         case SMC_CHOCH:
            if(lastBullCHOCH == last) return 1;
            if(lastBearCHOCH == last) return -1;
            return 0;
         case SMC_BSL:          return (lastBearSweep == last ? -1 : 0);
         case SMC_SSL:          return (lastBullSweep == last ? 1 : 0);
         case SMC_LIQUIDITY_SWEEP:
            if(lastBullSweep == last) return 1;
            if(lastBearSweep == last) return -1;
            return 0;
         case SMC_INDUCEMENT:
            if(lastBullInduce == last) return 1;
            if(lastBearInduce == last) return -1;
            return 0;
         case SMC_PREMIUM_ZONE: return (eq > 0 && c[last] > eq && Rejection(-1) ? -1 : 0);
         case SMC_DISCOUNT_ZONE:return (eq > 0 && c[last] < eq && Rejection(1) ? 1 : 0);
         case SMC_EQUILIBRIUM:
            if(eq <= 0) return 0;
            if(trend == 1 && c[last - 1] < eq && c[last] > eq) return 1;
            if(trend == -1 && c[last - 1] > eq && c[last] < eq) return -1;
            return 0;
         case SMC_DISPLACEMENT:
           {
            double b = MathAbs(c[last] - o[last]);
            if(avgRange <= 0 || b < InpDisplacementATR * avgRange) return 0;
            int d = (c[last] > o[last] ? 1 : -1);
            return (trend == 0 || trend == d ? d : 0);
           }
         case SMC_MITIGATION:
           {
            //--- first touch of an order block that created a BOS/CHOCH, with rejection
            for(int z = ArraySize(zones) - 1; z >= 0; z--)
              {
               if(zones[z].type != ZONE_OB || !zones[z].fromBOS || zones[z].broken) continue;
               if(zones[z].lastTouch != last || zones[z].touches != 1) continue;
               if(zones[z].dir > 0 && Rejection(1)) return 1;
               if(zones[z].dir < 0 && Rejection(-1)) return -1;
              }
            return 0;
           }
         case SMC_BREAKER_BLOCK:
            if(ZoneSignal(ZONE_BREAKER, 1, 0, MIT_MULTI_TOUCH)) return 1;
            if(ZoneSignal(ZONE_BREAKER, -1, 0, MIT_MULTI_TOUCH)) return -1;
            return 0;
         case SMC_MITIGATION_BLOCK:
            if(ZoneSignal(ZONE_MITBLK, 1, 0, MIT_MULTI_TOUCH)) return 1;
            if(ZoneSignal(ZONE_MITBLK, -1, 0, MIT_MULTI_TOUCH)) return -1;
            return 0;
         case SMC_COMBO_SWEEP_CHOCH_OB_FVG:
           {
            int maxAge = MathMax(3, InpSMCMaxSetupBars);
            if(lastBullSweep >= 0 && lastBullCHOCH > lastBullSweep && last - lastBullSweep <= maxAge &&
               (ZoneSignal(ZONE_OB, 1, lastBullSweep, MIT_MULTI_TOUCH) || ZoneSignal(ZONE_FVG, 1, lastBullSweep, MIT_MULTI_TOUCH)))
               return 1;
            if(lastBearSweep >= 0 && lastBearCHOCH > lastBearSweep && last - lastBearSweep <= maxAge &&
               (ZoneSignal(ZONE_OB, -1, lastBearSweep, MIT_MULTI_TOUCH) || ZoneSignal(ZONE_FVG, -1, lastBearSweep, MIT_MULTI_TOUCH)))
               return -1;
            return 0;
           }
        }
      return 0;
     }

   //--- premium/discount filter on the last close
   bool     PDAllows(int dir)
     {
      if(InpPremiumDiscountMode == PD_OFF || eq <= 0) return true;
      double px = c[n - 1], rg = rangeHi - rangeLo;
      if(InpPremiumDiscountMode == PD_FILTER) return (dir > 0 ? px < eq : px > eq);
      //--- OTE: 62% - 79% retracement of the dealing range
      if(dir > 0) return (px <= rangeHi - 0.62 * rg && px >= rangeHi - 0.79 * rg);
      return (px >= rangeLo + 0.62 * rg && px <= rangeLo + 0.79 * rg);
     }

   //--- structure levels for SL / TP
   double   StructSL(int dir) { return (dir > 0 ? slPrice : shPrice); }
   double   StructTarget(int dir, double entry)
     {
      if(dir > 0) { if(shPrice > entry) return shPrice; if(rangeHi > entry) return rangeHi; return 0; }
      if(slPrice > 0 && slPrice < entry) return slPrice;
      if(rangeLo > 0 && rangeLo < entry) return rangeLo;
      return 0;
     }
  };

CSMC g_smc;      // entry timeframe engine
CSMC g_smcHTF;   // higher timeframe structure filter

//--- previous-day liquidity sweep (LIQ_PREV_DAY mode), evaluated on the SMC timeframe's last bar
int PrevDaySweep()
  {
   double pdh = iHigh(_Symbol, PERIOD_D1, 1), pdl = iLow(_Symbol, PERIOD_D1, 1);
   double h1 = H(InpSMCTF, 1), l1 = L(InpSMCTF, 1), c1 = C(InpSMCTF, 1);
   if(pdh > 0 && h1 > pdh && c1 < pdh) return -1;
   if(pdl > 0 && l1 < pdl && c1 > pdl) return 1;
   return 0;
  }

//+------------------------------------------------------------------+
//| SMC module signal with all SMC filters applied                   |
//+------------------------------------------------------------------+
int SMCSignal()
  {
   if(!g_smc.Update()) return 0;
   int sig = 0;
   bool prevDayMode = (InpLiquidityMode == LIQ_PREV_DAY &&
                       (InpSMCEntryMode == SMC_BSL || InpSMCEntryMode == SMC_SSL || InpSMCEntryMode == SMC_LIQUIDITY_SWEEP));
   if(prevDayMode)
     {
      sig = PrevDaySweep();
      if(InpSMCEntryMode == SMC_BSL && sig != -1) sig = 0;
      if(InpSMCEntryMode == SMC_SSL && sig != 1) sig = 0;
     }
   else sig = g_smc.RawSignal(InpSMCEntryMode);
   if(sig == 0) return 0;
   int last = g_smc.n - 1, age = MathMax(3, InpSMCMaxSetupBars);
   if(!g_smc.PDAllows(sig)) { LogDebug("SMC: premium/discount blocked"); return 0; }
   if(InpSweepConfirmation)
     {
      int sw = (sig > 0 ? g_smc.lastBullSweep : g_smc.lastBearSweep);
      if(sw < 0 || last - sw > age) return 0;
     }
   if(InpInducementFilter)
     {
      int ind = (sig > 0 ? g_smc.lastBullInduce : g_smc.lastBearInduce);
      if(ind < 0 || last - ind > age) return 0;
     }
   if(InpHTFStructureFilter)
     {
      if(!g_smcHTF.Update()) return 0;
      if(g_smcHTF.trend != sig) { LogDebug("SMC: HTF structure against signal"); return 0; }
     }
   return sig;
  }
//+------------------------------------------------------------------+
