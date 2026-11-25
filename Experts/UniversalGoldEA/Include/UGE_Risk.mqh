//+------------------------------------------------------------------+
//|                                                   UGE_Risk.mqh   |
//|  Persistent state, lot sizing (14 modes), daily / drawdown       |
//|  protection, exposure caps, cooldowns and trade statistics.      |
//|  Risk protection applies to EVERY strategy mode.                 |
//+------------------------------------------------------------------+

struct SState
  {
   datetime dayStart;
   double   dayStartBalance, dayStartEquity;
   double   peakEquity, startBalance, startEquity;
   int      consecLosses, consecWins, winsToday, lossesToday, tradesToday;
   bool     dailyHalt, ddHalt, removeEA;
   datetime lastLossTime, lastWinTime, lastEntryTime;
   double   recoveryDebt;
   datetime recoveryStart;
  };
SState g_st;

//--- save / load the persistent part of the state
void SaveState()
  {
   if(!InpPersistState && !g_isTester) return; // account state not persisted (per-position data always is)
   GVSet("dayStart", (double)g_st.dayStart);
   GVSet("dsBal", g_st.dayStartBalance);   GVSet("dsEq", g_st.dayStartEquity);
   GVSet("peak", g_st.peakEquity);         GVSet("sBal", g_st.startBalance);  GVSet("sEq", g_st.startEquity);
   GVSet("cL", g_st.consecLosses);         GVSet("cW", g_st.consecWins);
   GVSet("wT", g_st.winsToday);            GVSet("lT", g_st.lossesToday);     GVSet("tT", g_st.tradesToday);
   GVSet("dH", g_st.dailyHalt ? 1 : 0);    GVSet("ddH", g_st.ddHalt ? 1 : 0);
   GVSet("lLoss", (double)g_st.lastLossTime); GVSet("lWin", (double)g_st.lastWinTime);
   GVSet("lEntry", (double)g_st.lastEntryTime);
   GVSet("debt", g_st.recoveryDebt);       GVSet("recStart", (double)g_st.recoveryStart);
  }

void LoadState()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(!InpPersistState && !g_isTester)
     {
      //--- clear stale account state so every start is fresh
      string keys[] = {"dayStart","dsBal","dsEq","peak","sBal","sEq","cL","cW","wT","lT","tT","dH","ddH","lLoss","lWin","lEntry","debt","recStart"};
      for(int i = 0; i < ArraySize(keys); i++) GVDel(keys[i]);
     }
   g_st.dayStart        = (datetime)GVGet("dayStart", 0);
   g_st.dayStartBalance = GVGet("dsBal", bal);
   g_st.dayStartEquity  = GVGet("dsEq", eq);
   g_st.peakEquity      = GVGet("peak", eq);
   g_st.startBalance    = GVGet("sBal", bal);
   g_st.startEquity     = GVGet("sEq", eq);
   g_st.consecLosses    = (int)GVGet("cL", 0);
   g_st.consecWins      = (int)GVGet("cW", 0);
   g_st.winsToday       = (int)GVGet("wT", 0);
   g_st.lossesToday     = (int)GVGet("lT", 0);
   g_st.tradesToday     = (int)GVGet("tT", 0);
   g_st.dailyHalt       = (GVGet("dH", 0) > 0);
   g_st.ddHalt          = (GVGet("ddH", 0) > 0);
   g_st.lastLossTime    = (datetime)GVGet("lLoss", 0);
   g_st.lastWinTime     = (datetime)GVGet("lWin", 0);
   g_st.lastEntryTime   = (datetime)GVGet("lEntry", 0);
   g_st.recoveryDebt    = GVGet("debt", 0);
   g_st.recoveryStart   = (datetime)GVGet("recStart", 0);
   g_st.removeEA        = false;
   if(InpResetDrawdownHalt && g_st.ddHalt)
     {
      g_st.ddHalt = false; g_st.peakEquity = eq; g_st.startBalance = bal; g_st.startEquity = eq;
      LogInfo("Drawdown halt reset by user input");
     }
  }

datetime DayOf(datetime t) { MqlDateTime d; TimeToStruct(t, d); d.hour = 0; d.min = 0; d.sec = 0; return StructToTime(d); }

//--- new server day: reset daily counters
void CheckNewDay()
  {
   datetime today = DayOf(TimeCurrent());
   if(today == g_st.dayStart) return;
   g_st.dayStart        = today;
   g_st.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_st.dayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_st.winsToday = 0; g_st.lossesToday = 0; g_st.tradesToday = 0;
   if(g_st.dailyHalt) LogInfo("New day: daily halt cleared");
   g_st.dailyHalt = false;
   SaveState();
  }

//--- realized profit of EA deals today (scope-aware)
double RealizedToday()
  {
   if(!HistorySelect(g_st.dayStart, TimeCurrent() + 60)) return 0;
   double sum = 0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;
      string sym = HistoryDealGetString(d, DEAL_SYMBOL);
      long mg = HistoryDealGetInteger(d, DEAL_MAGIC);
      bool inScope = false;
      if(InpPositionManagement == PSCOPE_ALL) inScope = true;
      else if(sym == _Symbol && (InpPositionManagement == PSCOPE_SYMBOL || IsEAMagic(mg) || (InpIncludeManualTrades && mg == 0))) inScope = true;
      if(!inScope) continue;
      sum += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
     }
   return sum;
  }

double FloatingScope() { SExposure e; GetExposure(e, -1, true); return e.profit; }

//+------------------------------------------------------------------+
//| Lot sizing                                                       |
//+------------------------------------------------------------------+
double FibN(int k) { double a = 1, b = 1; for(int i = 2; i <= k; i++) { double t = a + b; a = b; b = t; } return (k <= 1 ? 1 : b); }

double SeqLot(string seq, int idx)
  {
   string parts[];
   int n = StringSplit(seq, ',', parts);
   if(n <= 0) return InpFixedLot;
   idx = MathMax(0, MathMin(idx, n - 1));
   double v = StringToDouble(parts[idx]);
   return (v > 0 ? v : InpFixedLot);
  }

//--- martingale step lot from base after 'steps' losses
double MartingaleLot(double base, int steps)
  {
   steps = MathMin(steps, MathMax(0, InpMartingaleMaxSteps));
   switch(InpMartingaleMode)
     {
      case MARTI_DOUBLE:     return base * MathPow(2.0, steps);
      case MARTI_MULTIPLIER: return base * MathPow(InpMartingaleMultiplier, steps);
      case MARTI_ADDITIVE:   return base + InpMartingaleAddition * steps;
     }
   return base;
  }

//--- risk-money lot: money / (SL distance value of 1 lot)
double RiskLot(double riskMoney, double slDist)
  {
   if(slDist <= 0) slDist = Pts(InpNoSLFallbackPoints);
   double perLot = MoneyForDistance(1.0, slDist);
   if(perLot <= 0) return 0;
   return riskMoney / perLot;
  }

//--- main entry lot for the configured LotMode
double CalcLot(double slDist, double tpDist)
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE), eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm  = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double base = InpFixedLot, lot = base;
   double atr = CoreATR();
   switch(InpLotMode)
     {
      case LOT_FIXED:            lot = base; break;
      case LOT_RISK_BALANCE:     lot = RiskLot(bal * InpRiskPercent / 100.0, slDist); break;
      case LOT_RISK_EQUITY:      lot = RiskLot(eq * InpRiskPercent / 100.0, slDist); break;
      case LOT_RISK_FREEMARGIN:  lot = RiskLot(fm * InpRiskPercent / 100.0, slDist); break;
      case LOT_DYNAMIC:          lot = base * bal / MathMax(1.0, InpBalanceBase); break;
      case LOT_COMPOUNDING:      lot = base * MathPow(MathMax(0.01, bal / MathMax(1.0, InpBalanceBase)), InpCompoundingFactor); break;
      case LOT_ANTI_COMPOUNDING:
        {
         double r = bal / MathMax(1.0, InpBalanceBase);
         lot = (r >= 1.0) ? base * MathPow(1.0 / r, InpCompoundingFactor) : base * r; // shrink after gains AND losses
         break;
        }
      case LOT_ATR:              lot = RiskLot(eq * InpRiskPercent / 100.0, atr * InpATRMultiplierSL); break;
      case LOT_VOLATILITY:
        {
         double ref = AvgRange(InpATRTF, 100, 1);
         lot = (atr > 0 && ref > 0) ? base * ref / atr : base;
         break;
        }
      case LOT_MARTINGALE:       lot = MartingaleLot(base, g_st.consecLosses); break;
      case LOT_ANTI_MARTINGALE:  lot = MartingaleLot(base, g_st.consecWins); break;
      case LOT_FIBONACCI:        lot = base * FibN(MathMin(g_st.consecLosses, InpMartingaleMaxSteps) + 1); break;
      case LOT_CUSTOM_SEQUENCE:  lot = SeqLot(InpCustomLotSequence, g_st.consecLosses); break;
      case LOT_RECOVERY:
        {
         //--- size so the TP recovers realized debt plus a target; capped by MaximumLot
         double need = MathMax(0.0, g_st.recoveryDebt) + InpRecoveryLotTarget;
         double perLot = MoneyForDistance(1.0, tpDist > 0 ? tpDist : slDist);
         lot = (perLot > 0 && g_st.recoveryDebt > 0) ? need / perLot : base;
         break;
        }
     }
   return NormLot(lot);
  }

//+------------------------------------------------------------------+
//| Protection checks                                                |
//+------------------------------------------------------------------+
string g_blockReason = "";

//--- daily loss in money according to the selected basis (positive = loss)
double DailyLossMoney()
  {
   double r = RealizedToday(), f = FloatingScope();
   double pl = 0;
   if(InpLossBasis == LOSS_REALIZED) pl = r;
   if(InpLossBasis == LOSS_FLOATING) pl = f;
   if(InpLossBasis == LOSS_COMBINED) pl = r + f;
   return -pl;
  }

double CurrentDrawdownPct(double &ddMoney)
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double ref = 0, cur = eq;
   switch(InpDrawdownMode)
     {
      case DD_BALANCE:     ref = g_st.startBalance; cur = bal; break;
      case DD_EQUITY:      ref = g_st.startEquity;  break;
      case DD_PEAK_EQUITY: ref = g_st.peakEquity;   break;
     }
   ddMoney = MathMax(0.0, ref - cur);
   return (ref > 0 ? ddMoney / ref * 100.0 : 0.0);
  }

//--- apply a risk action
void RiskBreach(ENUM_RISK_ACTION act, string why, bool isDD)
  {
   if(isDD) g_st.ddHalt = true; else g_st.dailyHalt = true;
   LogInfo("RISK LIMIT: " + why);
   if(act != RACT_BLOCK_NEW)
     {
      CloseAll("risk: " + why, 0, -1, true);
      DeletePendings("risk: " + why);
     }
   if(act == RACT_CLOSE_REMOVE) g_st.removeEA = true;
   SaveState();
  }

//--- called every tick: track peak, enforce daily loss / drawdown / daily target
void RiskMonitor()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_st.peakEquity) { g_st.peakEquity = eq; if(InpPersistState || g_isTester) GVSet("peak", eq); }
   if(!g_st.dailyHalt)
     {
      double loss = DailyLossMoney();
      double lim = 0;
      if(InpEnableDailyLossLimit)
        {
         if(InpMaxDailyLossPercent > 0) lim = g_st.dayStartBalance * InpMaxDailyLossPercent / 100.0;
         if(InpMaxDailyLossMoney > 0) lim = (lim > 0 ? MathMin(lim, InpMaxDailyLossMoney) : InpMaxDailyLossMoney);
         if(lim > 0 && loss >= lim) RiskBreach(InpRiskAction, StringFormat("daily loss %.2f >= %.2f", loss, lim), false);
        }
      if(!g_st.dailyHalt && InpDailyProfitTarget > 0 && -loss >= InpDailyProfitTarget)
        {
         g_st.dailyHalt = true;
         LogInfo(StringFormat("Daily profit target reached (%.2f) - new trades blocked", -loss));
         if(InpRiskAction != RACT_BLOCK_NEW) { CloseAll("daily target", 0, -1, true); DeletePendings("daily target"); }
         SaveState();
        }
     }
   if(InpEnableMaxDrawdown && !g_st.ddHalt)
     {
      double ddm = 0, ddp = CurrentDrawdownPct(ddm);
      bool hit = (InpMaxDrawdownPercent > 0 && ddp >= InpMaxDrawdownPercent) || (InpMaxDrawdownMoney > 0 && ddm >= InpMaxDrawdownMoney);
      if(hit) RiskBreach(InpDrawdownAction, StringFormat("drawdown %.2f%% (%.2f)", ddp, ddm), true);
     }
  }

//--- every gate that must pass before ANY new position (entry, grid, hedge, recovery)
bool RiskAllowsNew(int dir, double addLots, bool isProtective = false)
  {
   if(g_st.ddHalt)    { g_blockReason = "drawdown halt"; return false; }
   if(g_st.dailyHalt && !isProtective) { g_blockReason = "daily halt"; return false; }
   SExposure e; GetExposure(e, -1, false);
   if(InpMaximumOpenTrades > 0 && e.total >= InpMaximumOpenTrades) { g_blockReason = "max open trades"; return false; }
   if(dir > 0 && InpMaximumBuyPositions > 0 && e.buys >= InpMaximumBuyPositions && !isProtective) { g_blockReason = "max buys"; return false; }
   if(dir < 0 && InpMaximumSellPositions > 0 && e.sells >= InpMaximumSellPositions && !isProtective) { g_blockReason = "max sells"; return false; }
   if(InpMaximumTotalLots > 0 && e.buyLots + e.sellLots + addLots > InpMaximumTotalLots + 1e-9) { g_blockReason = "max total lots"; return false; }
   if(!isProtective)
     {
      double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(InpMinMarginLevel > 0 && AccountInfoDouble(ACCOUNT_MARGIN) > 0 && ml < InpMinMarginLevel) { g_blockReason = "margin level"; return false; }
      if(InpStopTradingAfterLoss > 0 && g_st.consecLosses >= InpStopTradingAfterLoss && g_st.lastLossTime >= g_st.dayStart)
        { g_blockReason = "consecutive losses"; return false; }
      if(InpStopTradingAfterWin > 0 && g_st.winsToday >= InpStopTradingAfterWin) { g_blockReason = "wins today"; return false; }
     }
   return true;
  }

//--- frequency / cooldown gates for NEW signal entries
bool FrequencyAllows()
  {
   datetime now = TimeCurrent();
   if(InpDailyTradeLimit > 0 && g_st.tradesToday >= InpDailyTradeLimit) { g_blockReason = "daily trade limit"; return false; }
   if(InpMaxTradesPerSession > 0 && g_st.tradesToday >= InpMaxTradesPerSession) { g_blockReason = "session trade limit"; return false; }
   if(InpMinEntryInterval > 0 && now - g_st.lastEntryTime < InpMinEntryInterval) { g_blockReason = "entry interval"; return false; }
   if(InpEnableCooldown)
     {
      if(InpCooldownAfterLoss > 0 && g_st.lastLossTime > 0 && now - g_st.lastLossTime < InpCooldownAfterLoss * 60) { g_blockReason = "cooldown after loss"; return false; }
      if(InpCooldownAfterWin > 0 && g_st.lastWinTime > 0 && now - g_st.lastWinTime < InpCooldownAfterWin * 60) { g_blockReason = "cooldown after win"; return false; }
     }
   return true;
  }

//--- record a closed deal (from OnTradeTransaction)
void RecordClosedDeal(ulong deal)
  {
   if(!HistoryDealSelect(deal)) return;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return;
   if(!IsEAMagic(HistoryDealGetInteger(deal, DEAL_MAGIC))) return;
   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) return;
   double p = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
   //--- position fully closed? partial closes count toward debt but not toward streaks
   ulong posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   bool stillOpen = PositionSelectByTicket(posId);
   if(p < 0) g_st.recoveryDebt += -p;
   else      g_st.recoveryDebt = MathMax(0.0, g_st.recoveryDebt - p);
   if(!stillOpen)
     {
      if(p < 0)
        {
         g_st.consecLosses++; g_st.consecWins = 0; g_st.lossesToday++; g_st.lastLossTime = TimeCurrent();
         if(g_st.consecLosses > InpMartingaleMaxSteps && (InpLotMode == LOT_MARTINGALE || InpLotMode == LOT_FIBONACCI || InpLotMode == LOT_CUSTOM_SEQUENCE))
           { g_st.consecLosses = 0; LogInfo("Martingale max steps reached - sequence reset"); }
        }
      else
        {
         g_st.consecWins++; g_st.winsToday++; g_st.lastWinTime = TimeCurrent();
         if(InpMartingaleResetOnWin) g_st.consecLosses = 0;
         if(g_st.consecWins > InpMartingaleMaxSteps && InpLotMode == LOT_ANTI_MARTINGALE) g_st.consecWins = 0;
        }
     }
   SaveState();
  }
//+------------------------------------------------------------------+
