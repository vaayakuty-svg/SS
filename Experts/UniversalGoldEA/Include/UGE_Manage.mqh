//+------------------------------------------------------------------+
//|                                                 UGE_Manage.mqh   |
//|  Exit side: SL/TP calculation, break-even, trailing (8 modes),   |
//|  partial closes, time & signal exits, basket / equity exits.     |
//|  Management order each tick: basket -> time -> partial -> BE ->  |
//|  trailing.                                                       |
//+------------------------------------------------------------------+

//==================== Stop loss ====================================
//--- returns SL distance (price) and SL price; 0 = no broker SL
double CalcSL(int dir, double entry, double lot, double &slPrice)
  {
   slPrice = 0;
   if(!InpEnableStopLoss || InpStopLossMode == SL_NONE || InpStopLossMode == SL_EQUITY) return 0;
   ENUM_TIMEFRAMES tf = InpATRTF;
   double buf = Pts(InpSLBuffer), d = 0, lvl = 0;
   switch(InpStopLossMode)
     {
      case SL_FIXED:  d = InpStopLossFixed; break;
      case SL_POINTS: d = Pts(InpStopLossPoints); break;
      case SL_PRICE:
         lvl = InpStopLossPrice;
         if(lvl > 0 && ((dir > 0 && lvl < entry) || (dir < 0 && lvl > entry))) d = MathAbs(entry - lvl);
         break;
      case SL_ATR:    d = CoreATR() * InpATRMultiplierSL; break;
      case SL_PREV_CANDLE:
         if(dir > 0) lvl = (InpCandleSLMode == CSL_WICK ? L(tf, 1) : MathMin(O(tf, 1), C(tf, 1))) - buf;
         else        lvl = (InpCandleSLMode == CSL_WICK ? H(tf, 1) : MathMax(O(tf, 1), C(tf, 1))) + buf;
         d = (dir > 0 ? entry - lvl : lvl - entry);
         break;
      case SL_SWING:
        {
         if(InpSwingSLMode == SSL_LOOKBACK)
            lvl = (dir > 0 ? LowestLow(tf, InpSwingSLBars, 1) - buf : HighestHigh(tf, InpSwingSLBars, 1) + buf);
         else
           {
            double pp[]; int ps[];
            if(dir > 0 && GetPivotLows(tf, InpSwingBars, 300, pp, ps, 1) > 0) lvl = pp[0] - buf;
            if(dir < 0 && GetPivotHighs(tf, InpSwingBars, 300, pp, ps, 1) > 0) lvl = pp[0] + buf;
           }
         d = (lvl > 0 ? (dir > 0 ? entry - lvl : lvl - entry) : 0);
         break;
        }
      case SL_STRUCTURE:
         if(g_smc.Update()) lvl = g_smc.StructSL(dir);
         if(lvl > 0) d = (dir > 0 ? entry - (lvl - buf) : (lvl + buf) - entry);
         break;
      case SL_MONEY:
         d = DistanceForMoney(MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)), InpStopLossMoney);
         break;
     }
   if(d <= 0) d = CoreATR() * InpATRMultiplierSL; // invalid level -> ATR fallback
   if(InpMinSLPoints > 0) d = MathMax(d, Pts(InpMinSLPoints));
   if(InpMaxSLPoints > 0) d = MathMin(d, Pts(InpMaxSLPoints));
   slPrice = NormPrice(dir > 0 ? entry - d : entry + d);
   return d;
  }

//==================== Take profit ==================================
double CalcTP(int dir, double entry, double slDist)
  {
   if(!InpEnableTakeProfit || InpTakeProfitMode == TP_NONE || InpTakeProfitMode == TP_MONEY || InpTakeProfitMode == TP_BASKET) return 0;
   double d = 0;
   switch(InpTakeProfitMode)
     {
      case TP_FIXED:  d = InpTakeProfitFixed; break;
      case TP_POINTS: d = Pts(InpTakeProfitPoints); break;
      case TP_PRICE:
         if(InpTakeProfitPrice > 0 && ((dir > 0 && InpTakeProfitPrice > entry) || (dir < 0 && InpTakeProfitPrice < entry)))
            return NormPrice(InpTakeProfitPrice);
         return 0;
      case TP_ATR:    d = CoreATR() * InpATRMultiplierTP; break;
      case TP_RR:     d = (slDist > 0 ? slDist : Pts(InpNoSLFallbackPoints)) * InpRiskRewardRatio; break;
      case TP_STRUCTURE:
        {
         double lvl = 0;
         if(g_smc.Update()) lvl = g_smc.StructTarget(dir, entry);
         if(lvl <= 0)
           {
            double pp[]; int ps[];
            if(dir > 0 && GetPivotHighs(InpATRTF, InpSwingBars, 300, pp, ps, 3) > 0) for(int i = 0; i < ArraySize(pp); i++) if(pp[i] > entry) { lvl = pp[i]; break; }
            if(dir < 0 && GetPivotLows(InpATRTF, InpSwingBars, 300, pp, ps, 3) > 0)  for(int i = 0; i < ArraySize(pp); i++) if(pp[i] < entry) { lvl = pp[i]; break; }
           }
         if(lvl > 0) return NormPrice(lvl);
         d = (slDist > 0 ? slDist : Pts(InpNoSLFallbackPoints)) * InpRiskRewardRatio; // fallback RR
         break;
        }
     }
   if(d <= 0) return 0;
   return NormPrice(dir > 0 ? entry + d : entry - d);
  }

//==================== Per-position helpers =========================
double PosProfitPts(int pt, double open)
  {
   return (pt == POSITION_TYPE_BUY ? (SymBid() - open) : (open - SymAsk())) / _Point;
  }

//--- initial volume of a position (stored once; survives partial closes and restarts)
double InitialVolume(ulong id, double cur)
  {
   double v = GVGet("iv_" + (string)id, 0);
   if(v <= 0) { v = cur; GVSet("iv_" + (string)id, v); }
   return v;
  }

//==================== Break even ===================================
void ApplyBreakEven(ulong t, int pt, double open, double sl, double tp, double profitMoney)
  {
   if(!InpEnableBreakEven || InpBreakEvenMode == BE_OFF) return;
   int dir = (pt == POSITION_TYPE_BUY ? 1 : -1);
   double offset = (InpBreakEvenMode == BE_FIXED ? 0 : Pts(InpBreakEvenOffset));
   double target = NormPrice(open + dir * offset);
   if(sl > 0 && ((dir > 0 && sl >= target) || (dir < 0 && sl <= target))) return; // already done
   double pp = PosProfitPts(pt, open);
   bool trig = false;
   switch(InpBreakEvenMode)
     {
      case BE_FIXED:
      case BE_PLUS:    trig = (pp >= InpBreakEvenTrigger); break;
      case BE_ATR:     trig = (pp >= ToPts(CoreATR() * InpBreakEvenATR)); break;
      case BE_PERCENT:
        {
         double tpPts = (tp > 0 ? MathAbs(tp - open) / _Point : InpTakeProfitPoints);
         trig = (pp >= tpPts * InpBreakEvenPercent / 100.0);
         break;
        }
      case BE_PARTIAL: trig = (GVGet("pc_" + (string)t, 0) >= 1); break;
     }
   if(InpBreakEvenAfterProfit > 0 && profitMoney >= InpBreakEvenAfterProfit) trig = true;
   if(!trig) return;
   if(ModifyPosition(t, target, -1, true)) LogInfo(StringFormat("Break-even #%I64u -> %s", t, DoubleToString(target, _Digits)));
  }

//==================== Trailing =====================================
void ApplyTrailing(ulong t, int pt, double open, double sl)
  {
   if(!InpEnableTrailing || InpTrailingMode == TRAIL_OFF) return;
   int dir = (pt == POSITION_TYPE_BUY ? 1 : -1);
   double px = (dir > 0 ? SymBid() : SymAsk());
   double pp = PosProfitPts(pt, open);
   if(pp < InpTrailingStart) return;
   ENUM_TIMEFRAMES tf = InpTrailingTimeframe;
   double dist = Pts(InpTrailingDistance), nsl = 0;
   switch(InpTrailingMode)
     {
      case TRAIL_FIXED: nsl = px - dir * dist; break;
      case TRAIL_STEP:
        {
         //--- staircase: lock (n-1) steps once profit passes n steps beyond the start
         double stepP = MathMax(1, InpTrailingStep);
         int k = (int)MathFloor((pp - InpTrailingStart) / stepP);
         nsl = open + dir * Pts(InpTrailingStart - InpTrailingDistance + k * stepP);
         break;
        }
      case TRAIL_ATR:
        {
         double a = Buf(g_hTrailATR, 0, 1);
         if(!Valid(a)) return;
         nsl = px - dir * a * InpATRTrailingMultiplier; break;
        }
      case TRAIL_PERCENT: nsl = open + dir * Pts(pp * InpTrailingPercent / 100.0); break;
      case TRAIL_CANDLE:  nsl = (dir > 0 ? L(tf, 1) - dist : H(tf, 1) + dist); break;
      case TRAIL_SWING:
        {
         double sp[]; int ss[];
         if(dir > 0 && GetPivotLows(tf, InpSwingBars, 200, sp, ss, 1) > 0) nsl = sp[0] - dist;
         if(dir < 0 && GetPivotHighs(tf, InpSwingBars, 200, sp, ss, 1) > 0) nsl = sp[0] + dist;
         break;
        }
      case TRAIL_SAR:
        {
         double s = Buf(g_hTrailSAR, 0, 1);
         if(!Valid(s)) return;
         if((dir > 0 && s < px) || (dir < 0 && s > px)) nsl = s;
         break;
        }
      case TRAIL_CHANDELIER:
        {
         double a = Buf(g_hTrailATR, 0, 1);
         if(!Valid(a)) return;
         nsl = (dir > 0 ? HighestHigh(tf, InpChandelierBars, 1) - a * InpATRTrailingMultiplier
                        : LowestLow(tf, InpChandelierBars, 1) + a * InpATRTrailingMultiplier);
         break;
        }
     }
   if(nsl <= 0) return;
   //--- never move the stop to the wrong side of price; only improve
   if(dir > 0 && nsl >= px) return;
   if(dir < 0 && nsl <= px) return;
   if(sl > 0 && ((dir > 0 && nsl <= sl) || (dir < 0 && nsl >= sl))) return;
   if(InpTrailingMode == TRAIL_FIXED && sl > 0 && MathAbs(nsl - sl) < Pts(InpTrailingStep)) return;
   ModifyPosition(t, nsl, -1, true);
  }

//==================== Partial close ================================
void ApplyPartial(ulong t, int pt, double open, double tp, double vol, double profitMoney)
  {
   if(!InpEnablePartialClose || InpPartialCloseMode == PC_OFF) return;
   int levels = 1;
   if(InpPartialCloseMode == PC_TP1_TP2) levels = 2;
   if(InpPartialCloseMode == PC_TP1_2_3 || InpPartialCloseMode == PC_PERCENT || InpPartialCloseMode == PC_MONEY)
      levels = (InpTP3Distance > 0 ? 3 : (InpTP2Distance > 0 ? 2 : 1));
   int stage = (int)GVGet("pc_" + (string)t, 0);
   if(stage >= levels) return;
   double dists[3]; dists[0] = InpTP1Distance; dists[1] = InpTP2Distance; dists[2] = InpTP3Distance;
   double pcts[3];  pcts[0] = InpTP1ClosePercent; pcts[1] = InpTP2ClosePercent; pcts[2] = InpTP3ClosePercent;
   double need = dists[stage];
   bool hit = false;
   double pp = PosProfitPts(pt, open);
   switch(InpPartialCloseMode)
     {
      case PC_MONEY:   hit = (profitMoney >= need); break;
      case PC_PERCENT:
        {
         double tpPts = (tp > 0 ? MathAbs(tp - open) / _Point : InpTakeProfitPoints);
         hit = (pp >= tpPts * need / 100.0);
         break;
        }
      default:         hit = (pp >= need); break;
     }
   if(!hit) return;
   double init = InitialVolume(t, vol);
   double cv = FloorLot(init * pcts[stage] / 100.0);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   bool lastStage = (stage == levels - 1 && levels == 3);
   if(lastStage || vol - cv < minV) cv = vol;                 // close the remainder
   if(cv < minV) { GVSet("pc_" + (string)t, stage + 1); return; } // too small for the broker: skip stage
   bool ok = (cv >= vol - 1e-9) ? ClosePosition(t, "partial final") : ClosePartial(t, cv, "TP" + (string)(stage + 1));
   if(ok) GVSet("pc_" + (string)t, stage + 1);
  }

//==================== Time / signal exits ==========================
bool TimeExitDue(ulong t, datetime openTime, double profit)
  {
   if(InpTimeExitMode == TEXIT_OFF) return false;
   if(InpTimeExitOnlyProfit && profit <= 0) return false;
   long age = (long)(TimeCurrent() - openTime);
   switch(InpTimeExitMode)
     {
      case TEXIT_SECONDS:     return (age >= InpMaximumHoldingTime);
      case TEXIT_MINUTES:     return (age >= (long)InpMaximumHoldingTime * 60);
      case TEXIT_BARS:        return (iBarShift(_Symbol, _Period, openTime) >= InpExitAfterBars);
      case TEXIT_SESSION_END:
        {
         int m = MinutesToSessionEnd();
         return ((m >= 0 && m <= 1) || (InpEnableSessionFilter && !SessionAllows() && m < 0));
        }
      case TEXIT_PROFIT_TIME: return (age >= InpExitAfterProfitSeconds && profit > 0);
     }
   return false;
  }

//--- main per-position management (main + recovery magic; grid/hedge baskets are basket-managed)
void ManagePositions()
  {
   int trend = (InpExitOnTrendChange ? DirectionTrend() : 0);
   datetime barOpen = iTime(_Symbol, _Period, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnPosition()) continue;
      if(InpRestartRecoveryMode == RESTART_IGNORE && GVGet("ign_" + (string)t, 0) > 0) continue;
      long mg = PositionGetInteger(POSITION_MAGIC) - (long)InpMagicNumber;
      int    pt   = (int)PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double pr   = PosNetProfit();
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      InitialVolume(t, vol);
      //--- virtual money TP / SL (main trades)
      if(mg == MAGIC_MAIN)
        {
         if(InpEnableTakeProfit && InpTakeProfitMode == TP_MONEY && pr >= InpTakeProfitMoney) { ClosePosition(t, "money TP"); continue; }
         if(InpEnableStopLoss && InpStopLossMode == SL_MONEY && pr <= -InpStopLossMoney) { ClosePosition(t, "money SL"); continue; }
        }
      //--- time / signal exits
      if(mg == MAGIC_MAIN && TimeExitDue(t, ot, pr)) { ClosePosition(t, "time exit"); continue; }
      if(mg == MAGIC_MAIN && InpExitOnCandleClose && ot < barOpen) { ClosePosition(t, "candle close exit"); continue; }
      if(mg == MAGIC_MAIN && InpExitOnTrendChange && trend != 0 &&
         ((pt == POSITION_TYPE_BUY && trend < 0) || (pt == POSITION_TYPE_SELL && trend > 0))) { ClosePosition(t, "trend change"); continue; }
      if(mg != MAGIC_MAIN) continue;
      //--- partial -> break-even -> trailing
      ApplyPartial(t, pt, open, tp, vol, pr);
      if(!PositionSelectByTicket(t)) continue;
      sl = PositionGetDouble(POSITION_SL);
      ApplyBreakEven(t, pt, open, sl, tp, PosNetProfit());
      if(!PositionSelectByTicket(t)) continue;
      ApplyTrailing(t, pt, open, PositionGetDouble(POSITION_SL));
     }
  }

//--- clean per-position global variables of closed positions
void CleanupPositionGVs()
  {
   int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      string n = GlobalVariableName(i);
      if(StringFind(n, g_gvPrefix) != 0) continue;
      string key = StringSubstr(n, StringLen(g_gvPrefix));
      if(StringFind(key, "pc_") != 0 && StringFind(key, "iv_") != 0 && StringFind(key, "pk_") != 0 && StringFind(key, "ign_") != 0) continue;
      ulong id = (ulong)StringToInteger(StringSubstr(key, StringFind(key, "_") + 1));
      if(!PositionSelectByTicket(id)) GlobalVariableDel(n);
     }
  }

//==================== Basket & equity ==============================
//--- lot-weighted points of a basket (dirFilter 0 = all)
double BasketPoints(int dirFilter)
  {
   double sp = 0, sl = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !InRiskScope() || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int pt = (int)PositionGetInteger(POSITION_TYPE);
      if(dirFilter > 0 && pt != POSITION_TYPE_BUY) continue;
      if(dirFilter < 0 && pt != POSITION_TYPE_SELL) continue;
      double v = PositionGetDouble(POSITION_VOLUME);
      sp += PosProfitPts(pt, PositionGetDouble(POSITION_PRICE_OPEN)) * v; sl += v;
     }
   return (sl > 0 ? sp / sl : 0);
  }

//--- evaluate one basket group; returns true if it was closed
bool BasketGroup(int dirFilter, double profit, double buyLots, double sellLots, double buyAvg, double sellAvg)
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   bool tpHit = false, slHit = false;
   switch(InpBasketExitMode)
     {
      case BASKET_MONEY:
      case BASKET_COMBINED:
         tpHit = (InpBasketTakeProfit > 0 && profit >= InpBasketTakeProfit);
         slHit = (InpBasketStopLoss > 0 && profit <= -InpBasketStopLoss);
         break;
      case BASKET_PERCENT:
         tpHit = (InpBasketTakeProfit > 0 && profit >= bal * InpBasketTakeProfit / 100.0);
         slHit = (InpBasketStopLoss > 0 && profit <= -bal * InpBasketStopLoss / 100.0);
         break;
      case BASKET_POINTS:
        {
         double p = BasketPoints(dirFilter);
         tpHit = (InpBasketTakeProfit > 0 && p >= InpBasketTakeProfit);
         slHit = (InpBasketStopLoss > 0 && p <= -InpBasketStopLoss);
         break;
        }
      case BASKET_WAVG:
        {
         double net = buyLots - sellLots;
         if(MathAbs(net) < 1e-9) break;
         double be = (buyLots * buyAvg - sellLots * sellAvg) / net; // break-even price of the net position
         if(net > 0) { tpHit = (SymBid() >= be + Pts(InpBasketTakeProfit)); slHit = (InpBasketStopLoss > 0 && SymBid() <= be - Pts(InpBasketStopLoss)); }
         else        { tpHit = (SymAsk() <= be - Pts(InpBasketTakeProfit)); slHit = (InpBasketStopLoss > 0 && SymAsk() >= be + Pts(InpBasketStopLoss)); }
         break;
        }
      default: break;
     }
   if(tpHit && InpCloseAllOnTarget) { CloseAll(StringFormat("basket TP %.2f", profit), dirFilter, -1, true); return true; }
   if(slHit && InpCloseAllOnLoss)   { CloseAll(StringFormat("basket SL %.2f", profit), dirFilter, -1, true); return true; }
   if(tpHit || slHit) LogDebug("Basket level reached (close disabled by input)");
   return false;
  }

void ManageBasket()
  {
   //--- equity take profit / stop loss (relative to day-start equity)
   if(InpBasketExitMode == BASKET_EQUITY || InpBasketExitMode == BASKET_COMBINED)
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(InpEquityTakeProfit > 0 && eq >= g_st.dayStartEquity + InpEquityTakeProfit && InpCloseAllOnTarget)
        { CloseAll("equity TP", 0, -1, true); DeletePendings("equity TP"); return; }
      if(InpEquityStopLoss > 0 && eq <= g_st.dayStartEquity - InpEquityStopLoss && InpCloseAllOnLoss)
        { CloseAll("equity SL", 0, -1, true); DeletePendings("equity SL"); return; }
     }
   if(InpBasketExitMode == BASKET_OFF || InpBasketExitMode == BASKET_EQUITY) return;
   SExposure e; GetExposure(e, -1, true);
   if(e.total == 0) return;
   if(InpBasketScope == BSCOPE_ALL)
      BasketGroup(0, e.profit, e.buyLots, e.sellLots, e.buyAvg, e.sellAvg);
   else
     {
      if(e.buys > 0)  BasketGroup(1, e.buyProfit, e.buyLots, 0, e.buyAvg, 0);
      if(e.sells > 0) BasketGroup(-1, e.sellProfit, 0, e.sellLots, 0, e.sellAvg);
     }
  }
//+------------------------------------------------------------------+
