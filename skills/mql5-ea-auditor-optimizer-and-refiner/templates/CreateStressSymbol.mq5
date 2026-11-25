//+------------------------------------------------------------------+
//|                                           CreateStressSymbol.mq5 |
//|  Script: clone a symbol into a custom symbol with a WIDER spread |
//|  for Strategy Tester stress passes (the tester has no spread     |
//|  multiplier). Bid prices are kept; ask = bid + spread x mult +   |
//|  extra points. Run once from Navigator > Scripts, then test the  |
//|  EA on the new symbol with "Every tick based on real ticks".     |
//+------------------------------------------------------------------+
#property script_show_inputs
#property version "1.00"

input string   InpOrigin           = "XAUUSD";          // Source symbol
input string   InpStressName       = "XAUUSD_STRESS";   // Custom symbol name
input double   InpSpreadMultiplier = 2.0;               // Spread multiplier
input int      InpExtraPoints      = 0;                 // Extra spread (points)
input datetime InpFrom             = D'2022.01.01';     // Copy ticks from
input datetime InpTo               = D'2025.12.31';     // Copy ticks to

//+------------------------------------------------------------------+
void OnStart()
  {
   if(!SymbolSelect(InpOrigin, true)) { Print("Origin symbol not found: ", InpOrigin); return; }
   bool isCustom = false;
   if(!SymbolExist(InpStressName, isCustom))
     {
      if(!CustomSymbolCreate(InpStressName, "Stress", InpOrigin)) { Print("CustomSymbolCreate failed: ", GetLastError()); return; }
     }
   else if(!isCustom) { Print(InpStressName, " exists and is not a custom symbol"); return; }

   double pt = SymbolInfoDouble(InpOrigin, SYMBOL_POINT);
   long total = 0;
   //--- copy month by month to keep memory bounded
   for(datetime m = InpFrom; m < InpTo; )
     {
      MqlDateTime d; TimeToStruct(m, d);
      d.mon += 1; if(d.mon > 12) { d.mon = 1; d.year++; } d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
      datetime next = StructToTime(d);
      if(next > InpTo) next = InpTo;
      MqlTick ticks[];
      int n = CopyTicksRange(InpOrigin, ticks, COPY_TICKS_ALL, (ulong)m * 1000, (ulong)next * 1000 - 1);
      if(n > 0)
        {
         for(int i = 0; i < n; i++)
           {
            if(ticks[i].bid <= 0 || ticks[i].ask <= 0) continue;
            double spread = ticks[i].ask - ticks[i].bid;
            ticks[i].ask = NormalizeDouble(ticks[i].bid + spread * InpSpreadMultiplier + InpExtraPoints * pt,
                                           (int)SymbolInfoInteger(InpOrigin, SYMBOL_DIGITS));
            ticks[i].flags |= TICK_FLAG_ASK;
           }
         int r = CustomTicksReplace(InpStressName, (long)m * 1000, (long)next * 1000 - 1, ticks);
         if(r < 0) PrintFormat("CustomTicksReplace failed for %s: %d", TimeToString(m), GetLastError());
         else total += r;
        }
      else if(n < 0) PrintFormat("CopyTicksRange failed for %s: %d (download history first)", TimeToString(m), GetLastError());
      m = next;
     }
   //--- M1 bars (spread field widened too)
   MqlRates rates[];
   int nr = CopyRates(InpOrigin, PERIOD_M1, InpFrom, InpTo, rates);
   if(nr > 0)
     {
      for(int i = 0; i < nr; i++) rates[i].spread = (int)MathRound(rates[i].spread * InpSpreadMultiplier) + InpExtraPoints;
      CustomRatesReplace(InpStressName, InpFrom, InpTo, rates);
     }
   SymbolSelect(InpStressName, true);
   PrintFormat("%s ready: %I64d ticks, %d M1 bars, spread x%.2f + %d pts", InpStressName, total, nr, InpSpreadMultiplier, InpExtraPoints);
  }
//+------------------------------------------------------------------+
