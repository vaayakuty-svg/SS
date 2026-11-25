//+------------------------------------------------------------------+
//|                                                   UGE_Grid.mqh   |
//|  Grid (15 modes), grid spacing (8), grid lot progression (12),   |
//|  hedge (10 modes) and recovery (10 modes).                       |
//|  WARNING: averaging / martingale / recovery can lose the whole   |
//|  account in one strong trend. Every path is capped by levels,    |
//|  lot caps, basket SL, grid max DD and the global drawdown halt.  |
//|  Requires a HEDGING account (disabled automatically on netting). |
//+------------------------------------------------------------------+

bool     g_gridStopped = false;     // set by GMAX_STOP
datetime g_gridCandleBar = 0;       // candle-grid: one add per bar

//==================== Basket scan ==================================
struct SBasket
  {
   int    count, gridLevels;
   double lots, profit, avg;
   double worst, best;           // worst / best open price for the direction
   double firstLot, lastLot, lastPrice;
   ulong  firstTicket, lastTicket;
   double firstProfit, lastProfit;
  };

//--- basket of a direction for given magic offsets (bitmask: 1<<offset)
void ScanBasket(int dir, int magicMask, SBasket &b)
  {
   ZeroMemory(b);
   datetime ft = D'3000.01.01', lt = 0;
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnPosition()) continue;
      int off = (int)(PositionGetInteger(POSITION_MAGIC) - (long)InpMagicNumber);
      if(((1 << off) & magicMask) == 0) continue;
      int pt = (int)PositionGetInteger(POSITION_TYPE);
      if((dir > 0 && pt != POSITION_TYPE_BUY) || (dir < 0 && pt != POSITION_TYPE_SELL)) continue;
      double v = PositionGetDouble(POSITION_VOLUME), op = PositionGetDouble(POSITION_PRICE_OPEN), pr = PosNetProfit();
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(b.count == 0) { b.worst = op; b.best = op; }
      b.count++; b.lots += v; b.profit += pr; sum += v * op;
      if(off == MAGIC_GRID) b.gridLevels++;
      if(dir > 0) { b.worst = MathMin(b.worst, op); b.best = MathMax(b.best, op); }
      else        { b.worst = MathMax(b.worst, op); b.best = MathMin(b.best, op); }
      if(ot < ft || (ot == ft && t < b.firstTicket)) { ft = ot; b.firstLot = v; b.firstTicket = t; b.firstProfit = pr; }
      if(ot > lt || (ot == lt && t > b.lastTicket))  { lt = ot; b.lastLot = v; b.lastPrice = op; b.lastTicket = t; b.lastProfit = pr; }
     }
   b.avg = (b.lots > 0 ? sum / b.lots : 0);
  }

#define MASK_MAIN_GRID ((1 << MAGIC_MAIN) | (1 << MAGIC_GRID))
#define MASK_GRID      (1 << MAGIC_GRID)
#define MASK_HEDGE     (1 << MAGIC_HEDGE)
#define MASK_MAIN_REC  ((1 << MAGIC_MAIN) | (1 << MAGIC_RECOVERY))
#define MASK_ALL       15

//==================== Spacing ======================================
//--- price distance to the next level ('level' = adds already made, 0 = first add)
double GridStep(int level)
  {
   double base = 0, atr = CoreATR();
   switch(InpGridSpacingMode)
     {
      case GSP_FIXED_PRICE:  base = InpGridStepPrice; break;
      case GSP_POINTS:       base = Pts(InpGridStepPoints); break;
      case GSP_ATR:          base = atr * InpATRGridMultiplier; break;
      case GSP_PERCENT:      base = SymBid() * InpGridStepPercent / 100.0; break;
      case GSP_CANDLE_RANGE: base = AvgRange(InpATRTF, 20); break;
      case GSP_FIBONACCI:    base = Pts(InpGridStepPoints) * FibN(level + 1); break;
      case GSP_DYNAMIC:
         base = Pts(InpGridStepPoints) * MathPow(InpGridExpansionFactor, level);
         base = MathMax(Pts(InpDynamicStepMinimum), MathMin(Pts(InpDynamicStepMaximum), base));
         return base;
      case GSP_ADAPTIVE:
        {
         double ref = AvgRange(InpATRTF, 100);
         double regime = (ref > 0 ? atr / ref : 1.0);
         base = Pts(InpGridStepPoints) * regime * MathPow(InpGridExpansionFactor, level);
         base = MathMax(Pts(InpDynamicStepMinimum), MathMin(Pts(InpDynamicStepMaximum), base));
         return base;
        }
     }
   //--- grid-mode overrides
   if(InpGridMode == GRID_DYNAMIC)  base = MathMax(Pts(InpDynamicStepMinimum), MathMin(Pts(InpDynamicStepMaximum), atr * InpATRGridMultiplier * MathPow(InpGridExpansionFactor, level)));
   if(InpGridMode == GRID_ADAPTIVE)
     {
      double ref = AvgRange(InpATRTF, 100);
      base = Pts(InpGridStepPoints) * (ref > 0 ? atr / ref : 1.0) * MathPow(InpGridExpansionFactor, level);
      base = MathMax(Pts(InpDynamicStepMinimum), MathMin(Pts(InpDynamicStepMaximum), base));
     }
   if(InpGridSpacingMultiplier > 0 && InpGridSpacingMultiplier != 1.0) base *= MathPow(InpGridSpacingMultiplier, level);
   if(level == 0 && InpGridStartDistance > 0) base = Pts(InpGridStartDistance);
   return MathMax(base, Pts(10));
  }

//==================== Lot progression ==============================
//--- lot for grid level 'level' (1 = first add)
double GridLot(int level, int dir, const SBasket &b)
  {
   double L0 = InpGridInitialLot, lot = L0;
   switch(InpGridLotMode)
     {
      case GLOT_FIXED:           lot = L0; break;
      case GLOT_ARITHMETIC:      lot = L0 + InpGridLotAddition * level; break;
      case GLOT_GEOMETRIC:       lot = L0 * MathPow(InpGridLotMultiplier, level); break;
      case GLOT_MARTINGALE:      lot = L0 * MathPow(2.0, level); break;
      case GLOT_ANTI_MARTINGALE: lot = L0 / MathPow(MathMax(1.0001, InpGridLotMultiplier), level); break;
      case GLOT_FIBONACCI:       lot = L0 * FibN(level + 1); break;
      case GLOT_CUSTOM:          lot = SeqLot(InpGridCustomLots, level); break;
      case GLOT_RISK_BASED:
        {
         //--- risk % of equity on the distance from here to the basket stop (or one more step)
         double dist = GridStep(level) * 2;
         lot = RiskLot(AccountInfoDouble(ACCOUNT_EQUITY) * InpGridRiskPercent / 100.0, dist);
         break;
        }
      case GLOT_RECOVERY:
        {
         //--- size so the new average sits one TP distance from the current price
         double px = (dir > 0 ? SymAsk() : SymBid()), D = Pts(MathMax(10, InpGridTPPoints));
         double gap = (dir > 0 ? b.avg - px : px - b.avg);
         lot = (gap > D ? b.lots * (gap - D) / D : L0);
         break;
        }
      case GLOT_DECREASING:      lot = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), L0 - InpGridLotAddition * level); break;
      case GLOT_ALTERNATING:     lot = (level % 2 == 1 ? L0 * InpGridLotMultiplier : L0); break;
      case GLOT_HYBRID:          lot = (level < InpGridHybridLevel ? L0 : L0 * MathPow(InpGridLotMultiplier, level - InpGridHybridLevel + 1)); break;
     }
   if(InpEnableLotCap)
     {
      lot = MathMin(lot, InpGridMaxLot);
      SBasket all; ScanBasket(dir, MASK_GRID, all);
      if(all.lots + lot > InpGridMaxTotalLots) lot = InpGridMaxTotalLots - all.lots;
     }
   return NormLot(lot);
  }

//==================== Grid helpers =================================
bool GridDirAllowed(int dir)
  {
   if(InpGridMode == GRID_BUY && dir < 0) return false;
   if(InpGridMode == GRID_SELL && dir > 0) return false;
   if(InpGridDirection == GDIR_BUY && dir < 0) return false;
   if(InpGridDirection == GDIR_SELL && dir > 0) return false;
   return true;
  }

int GridOrderCount()
  {
   SExposure e; GetExposure(e, MAGIC_GRID);
   int pend = 0;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      ulong t = OrderGetTicket(j);
      if(t > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == (long)InpMagicNumber + MAGIC_GRID) pend++;
     }
   return e.total + pend;
  }

bool GridCanAdd(int dir, double lot)
  {
   if(lot <= 0) return false;
   if(InpMaximumGridOrders > 0 && GridOrderCount() >= InpMaximumGridOrders) return false;
   return RiskAllowsNew(dir, lot, true);
  }

//--- pending grid order already near 'price'?
bool PendingNear(double price, double tol, int dir)
  {
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      ulong t = OrderGetTicket(j);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber + MAGIC_GRID) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool isBuy = (ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_BUY_STOP);
      if((dir > 0) != isBuy) continue;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) <= tol) return true;
     }
   return false;
  }

//--- open position near 'price'?
bool PositionNear(double price, double tol, int dir)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnPosition()) continue;
      int pt = (int)PositionGetInteger(POSITION_TYPE);
      if((dir > 0) != (pt == POSITION_TYPE_BUY)) continue;
      if(MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - price) <= tol) return true;
     }
   return false;
  }

int CountGridPendings(int dir)
  {
   int n = 0;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      ulong t = OrderGetTicket(j);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber + MAGIC_GRID) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool isBuy = (ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_BUY_STOP);
      if(dir == 0 || (dir > 0) == isBuy) n++;
     }
   return n;
  }

//--- grid basket exits (TP / SL / DD). Returns true if the basket was closed
bool GridExits(int dir, const SBasket &b)
  {
   if(b.count == 0) return false;
   int dfl = (dir > 0 ? 1 : -1);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpGridStopLossMoney > 0 && b.profit <= -InpGridStopLossMoney)
     { CloseAll("grid basket SL", dfl, MAGIC_GRID); CloseAll("grid basket SL", dfl, MAGIC_MAIN); DeletePendings("grid SL", dfl, MAGIC_GRID); return true; }
   if(InpGridMaxDDPercent > 0 && b.profit <= -bal * InpGridMaxDDPercent / 100.0)
     { CloseAll("grid max DD", dfl, MAGIC_GRID); CloseAll("grid max DD", dfl, MAGIC_MAIN); DeletePendings("grid DD", dfl, MAGIC_GRID); return true; }
   if(b.gridLevels == 0) return false; // single seed: normal exits manage it
   bool tp = false;
   switch(InpGridTPMode)
     {
      case GTP_AVG_PRICE:    tp = (dir > 0 ? SymBid() >= b.avg + Pts(InpGridTPPoints) : SymAsk() <= b.avg - Pts(InpGridTPPoints)); break;
      case GTP_BASKET_MONEY: tp = (b.profit >= InpGridTPMoney); break;
      case GTP_LAST_LEVEL:
         if(b.count >= 2 && b.firstProfit + b.lastProfit >= InpGridTPMoney)
           {
            ClosePosition(b.lastTicket, "grid pair TP"); ClosePosition(b.firstTicket, "grid pair TP");
            return true;
           }
         break;
     }
   if(tp)
     {
      CloseAll("grid TP", dfl, MAGIC_GRID); CloseAll("grid TP", dfl, MAGIC_MAIN);
      if(InpGridMode == GRID_HEDGED) CloseAll("grid TP", -dfl, MAGIC_HEDGE);
      DeletePendings("grid TP", dfl, MAGIC_GRID);
      return true;
     }
   return false;
  }

//--- action at max level (executed once per basket)
void GridOnMax(int dir, const SBasket &b)
  {
   switch(InpGridOnMaxLevel)
     {
      case GMAX_HOLD: break;
      case GMAX_CLOSE_ALL: CloseAll("grid max level", dir, MAGIC_GRID); CloseAll("grid max level", dir, MAGIC_MAIN); break;
      case GMAX_HEDGE:
        {
         SBasket h; ScanBasket(-dir, MASK_HEDGE, h);
         if(h.count == 0 && g_isHedging && RiskAllowsNew(-dir, b.lots, true))
            OpenMarket(-dir, b.lots, 0, 0, MAGIC_HEDGE, "GH");
         break;
        }
      case GMAX_STOP:
         if(!g_gridStopped) LogInfo("Grid max level reached - new grid/seed entries stopped");
         g_gridStopped = true; break;
     }
  }

//==================== Grid modes ===================================
//--- averaging family (classic, buy, sell, buy+sell, counter, recovery, dynamic, adaptive, candle, hedged)
void GridAveraging(int dir)
  {
   SBasket b; ScanBasket(dir, MASK_MAIN_GRID, b);
   if(GridExits(dir, b)) return;
   if(b.count == 0)
     {
      //--- auto start a seed (otherwise the entry signal opens the seed)
      if(!InpGridAutoStart || g_gridStopped || !InpEnableTrading) return;
      if(InpGridMode == GRID_RECOVERY) return; // recovery grid never seeds itself
      if(InpGridMode == GRID_CLASSIC && InpGridDirection == GDIR_SIGNAL) return;
      if(InpGridMode == GRID_COUNTER_TREND)
        {
         double e = Buf(g_hDirEMA, 0, 1), a = CoreATR();
         if(!Valid(e)) return;
         if(dir > 0 && SymBid() > e - 1.5 * a) return; // only fade a stretched move
         if(dir < 0 && SymBid() < e + 1.5 * a) return;
        }
      double l0 = NormLot(InpGridInitialLot);
      if(SessionAllows() && DayAllows() && SpreadAllows() && GridCanAdd(dir, l0))
         OpenMarket(dir, l0, 0, 0, MAGIC_GRID, "GS");
      return;
     }
   //--- hedged grid: hedge legs (opposite direction) count as used levels
   SBasket hg; ZeroMemory(hg);
   if(InpGridMode == GRID_HEDGED) ScanBasket(-dir, MASK_HEDGE, hg);
   int levels = b.gridLevels + hg.count;
   if(levels >= InpMaximumGridLevels) { GridOnMax(dir, b); return; }
   if(InpGridMode == GRID_RECOVERY && b.profit > -InpRecoveryTriggerLoss) return;
   double step = GridStep(levels);
   double px = (dir > 0 ? SymAsk() : SymBid());
   double ref = b.worst;
   if(hg.count > 0) ref = (dir > 0 ? MathMin(ref, hg.lastPrice) : MathMax(ref, hg.lastPrice));
   bool against = (dir > 0 ? px <= ref - step : px >= ref + step);
   if(!against) return;
   if(InpGridMode == GRID_CANDLE)
     {
      datetime bt = iTime(_Symbol, _Period, 0);
      if(bt == g_gridCandleBar) return;
      if(!(dir > 0 ? Bull(_Period, 1) : Bear(_Period, 1))) return;
      g_gridCandleBar = bt;
     }
   if(!SpreadAllows()) return;
   double lot = GridLot(levels + 1, dir, b);
   if(InpGridMode == GRID_HEDGED && levels + 1 >= InpGridHedgeFromLevel)
     {
      if(GridCanAdd(-dir, lot)) OpenMarket(-dir, lot, 0, 0, MAGIC_HEDGE, "GHL" + (string)(levels + 1));
      return;
     }
   if(GridCanAdd(dir, lot)) OpenMarket(dir, lot, 0, 0, MAGIC_GRID, "GL" + (string)(levels + 1));
  }

//--- reverse grid: each step move opens a trade in the direction of that move
void GridReverse()
  {
   SExposure g; GetExposure(g, MAGIC_GRID);
   double ref = GVGet("grev_ref", 0);
   if(g.total == 0 && ref == 0) { GVSet("grev_ref", SymBid()); return; }
   if(g.total > 0 && g.profit >= InpGridTPMoney)   { CloseAll("reverse grid TP", 0, MAGIC_GRID); GVSet("grev_ref", SymBid()); return; }
   if(InpGridStopLossMoney > 0 && g.profit <= -InpGridStopLossMoney) { CloseAll("reverse grid SL", 0, MAGIC_GRID); GVSet("grev_ref", SymBid()); return; }
   if(g.total >= InpMaximumGridLevels) return;
   double step = GridStep(g.total);
   int dir = 0;
   if(SymBid() >= ref + step) dir = 1;
   if(SymBid() <= ref - step) dir = -1;
   if(dir == 0 || !GridDirAllowed(dir) || !SpreadAllows()) return;
   SBasket b; ScanBasket(dir, MASK_GRID, b);
   double lot = GridLot(g.total + 1, dir, b);
   if(GridCanAdd(dir, lot) && OpenMarket(dir, lot, 0, 0, MAGIC_GRID, "GR") > 0) GVSet("grev_ref", SymBid());
  }

//--- trend pyramid: add in favour while the direction EMA agrees; basket stop one step behind the newest add
void GridTrend(int dir)
  {
   SBasket b; ScanBasket(dir, MASK_MAIN_GRID, b);
   if(b.count == 0) return;
   double px = (dir > 0 ? SymBid() : SymAsk());
   double step = GridStep(b.gridLevels);
   if(b.gridLevels > 0)
     {
      double stopLvl = b.lastPrice - dir * step;
      if((dir > 0 && px <= stopLvl) || (dir < 0 && px >= stopLvl) || b.profit >= InpGridTPMoney * MathMax(1, b.count))
        { CloseAll("pyramid exit", dir, MAGIC_GRID); CloseAll("pyramid exit", dir, MAGIC_MAIN); return; }
     }
   if(InpGridStopLossMoney > 0 && b.profit <= -InpGridStopLossMoney) { CloseAll("pyramid SL", dir, MAGIC_GRID); CloseAll("pyramid SL", dir, MAGIC_MAIN); return; }
   if(b.gridLevels >= InpMaximumGridLevels) return;
   if(DirectionTrend() != dir) return;
   bool favour = (dir > 0 ? px >= b.best + step : px <= b.best - step);
   if(!favour || !SpreadAllows()) return;
   double lot = GridLot(b.gridLevels + 1, dir, b);
   if(GridCanAdd(dir, lot)) OpenMarket(dir, lot, 0, 0, MAGIC_GRID, "GP" + (string)(b.gridLevels + 1));
  }

//--- breakout ladder: stop orders above and below; OCO removes the losing side
void GridBreakout(bool start)
  {
   SBasket bb, bs; ScanBasket(1, MASK_GRID, bb); ScanBasket(-1, MASK_GRID, bs);
   if(bb.count > 0) GridExits(1, bb);
   if(bs.count > 0) GridExits(-1, bs);
   int pend = CountGridPendings(0);
   if(InpDeleteOppositePending)
     {
      if(bb.count > 0 && CountGridPendings(-1) > 0) DeletePendings("breakout OCO", -1, MAGIC_GRID);
      if(bs.count > 0 && CountGridPendings(1) > 0)  DeletePendings("breakout OCO", 1, MAGIC_GRID);
     }
   if(bb.count > 0 || bs.count > 0 || pend > 0) return;
   if(!start || g_gridStopped) return;
   double mid = (SymAsk() + SymBid()) / 2.0;
   int maxPend = MathMin(InpMaximumGridLevels, MathMax(1, InpMaximumPendingOrders / 2));
   double off = 0;
   SBasket none; ZeroMemory(none);
   for(int k = 0; k < maxPend; k++)
     {
      off += GridStep(k);
      double lot = GridLot(k, 1, none);
      if(GridDirAllowed(1)  && GridCanAdd(1, lot))  OpenPending(1, true, mid + off, lot, 0, 0, MAGIC_GRID, "GB" + (string)k);
      if(GridDirAllowed(-1) && GridCanAdd(-1, lot)) OpenPending(-1, true, mid - off, lot, 0, 0, MAGIC_GRID, "GB" + (string)k);
     }
  }

//--- zone ladder: buy limits in the lower half, sell limits in the upper half, each with a one-step TP
void GridZone()
  {
   double hi = (InpZoneHigh > 0 ? InpZoneHigh : iHigh(_Symbol, PERIOD_D1, 1));
   double lo = (InpZoneLow  > 0 ? InpZoneLow  : iLow(_Symbol, PERIOD_D1, 1));
   if(hi <= lo) return;
   SExposure g; GetExposure(g, MAGIC_GRID);
   if(InpGridStopLossMoney > 0 && g.profit <= -InpGridStopLossMoney) { CloseAll("zone grid SL", 0, MAGIC_GRID); DeletePendings("zone SL", 0, MAGIC_GRID); return; }
   double px = SymBid();
   //--- price left the zone: remove the ladder (open trades keep their TP; basket SL protects)
   if(px > hi + GridStep(0) || px < lo - GridStep(0)) { if(CountGridPendings(0) > 0) DeletePendings("left zone", 0, MAGIC_GRID); return; }
   if(g_gridStopped || !InpEnableTrading) return;
   double mid = (hi + lo) / 2.0, step = GridStep(0), tol = step / 3.0;
   SBasket none; ZeroMemory(none);
   int lvl = 0;
   for(double p = mid - step; p > lo && lvl < InpMaximumGridLevels; p -= step, lvl++)
     {
      if(!GridDirAllowed(1) || p >= SymAsk()) continue;
      if(PendingNear(p, tol, 1) || PositionNear(p, tol, 1)) continue;
      double lot = GridLot(lvl, 1, none);
      if(GridCanAdd(1, lot)) OpenPending(1, false, p, lot, 0, p + step, MAGIC_GRID, "GZB");
     }
   lvl = 0;
   for(double p = mid + step; p < hi && lvl < InpMaximumGridLevels; p += step, lvl++)
     {
      if(!GridDirAllowed(-1) || p <= SymBid()) continue;
      if(PendingNear(p, tol, -1) || PositionNear(p, tol, -1)) continue;
      double lot = GridLot(lvl, -1, none);
      if(GridCanAdd(-1, lot)) OpenPending(-1, false, p, lot, 0, p - step, MAGIC_GRID, "GZS");
     }
  }

//--- multi-level: once a seed exists, place every remaining level as a limit order at once
void GridMultiLevel(int dir)
  {
   SBasket b; ScanBasket(dir, MASK_MAIN_GRID, b);
   if(b.count == 0) { if(CountGridPendings(dir) > 0) DeletePendings("multi-level basket closed", dir, MAGIC_GRID); return; }
   if(GridExits(dir, b)) return;
   if(CountGridPendings(dir) + b.gridLevels > 0) return; // ladder already placed
   double seed = b.worst, off = 0;
   for(int k = 0; k < InpMaximumGridLevels; k++)
     {
      off += GridStep(k);
      double lot = GridLot(k + 1, dir, b);
      if(!GridCanAdd(dir, lot)) break;
      OpenPending(dir, false, seed - dir * off, lot, 0, 0, MAGIC_GRID, "GM" + (string)(k + 1));
     }
  }

//--- grid dispatcher (called every tick)
void ManageGrid(int lastSignal)
  {
   if(!InpEnableGrid || !g_isHedging) return;
   switch(InpGridMode)
     {
      case GRID_REVERSE:     GridReverse(); return;
      case GRID_BREAKOUT:    GridBreakout(InpGridAutoStart || lastSignal != 0); return;
      case GRID_ZONE:        GridZone(); return;
      case GRID_TREND:       GridTrend(1); GridTrend(-1); return;
      case GRID_MULTI_LEVEL: if(GridDirAllowed(1)) GridMultiLevel(1); if(GridDirAllowed(-1)) GridMultiLevel(-1); return;
      default:
         if(GridDirAllowed(1))  GridAveraging(1);
         if(GridDirAllowed(-1)) GridAveraging(-1);
         return;
     }
  }

//+------------------------------------------------------------------+
//| HEDGE                                                            |
//+------------------------------------------------------------------+
int g_lastSignalDir = 0;   // updated by the entry engine (signal-based hedge)

double HedgeLots(double exposure)
  {
   switch(InpHedgeLotMode)
     {
      case HLOT_SAME:       return exposure;
      case HLOT_MULTIPLIER: return exposure * InpHedgeLotMultiplier;
      case HLOT_PERCENT:    return exposure * InpHedgePercentage / 100.0;
     }
   return exposure;
  }

void ManageHedge()
  {
   if(!InpEnableHedge || InpHedgeMode == HEDGE_DISABLED || !g_isHedging) return;
   int protectMask = (1 << MAGIC_MAIN) | (1 << MAGIC_GRID) | (1 << MAGIC_RECOVERY);
   for(int side = 1; side >= -1; side -= 2)
     {
      SBasket s, h;
      ScanBasket(side, protectMask, s);
      ScanBasket(-side, MASK_HEDGE, h);
      //--- orphan hedge: protected side is gone -> close the hedge so it is not left naked
      if(s.count == 0 && h.count > 0) { CloseAll("orphan hedge", -side, MAGIC_HEDGE); continue; }
      if(s.count == 0) { GVDel("pk_" + (string)side); continue; }
      //--- close the locked pair at net target
      if(h.count > 0 && InpHedgeCloseProfit > 0 && s.profit + h.profit >= InpHedgeCloseProfit)
        { CloseAll("hedge pair target", side, -1); CloseAll("hedge pair target", -side, MAGIC_HEDGE); continue; }
      //--- directional hedge: unlock when the HTF trend returns to the protected side
      if(h.count > 0 && InpHedgeMode == HEDGE_DIRECTIONAL)
        {
         double e = Buf(g_hHedgeEMA, 0, 1);
         if(Valid(e) && ((side > 0 && C(InpHedgeTF, 1) > e) || (side < 0 && C(InpHedgeTF, 1) < e)))
           { CloseAll("directional unlock", -side, MAGIC_HEDGE); continue; }
        }
      if(h.count >= InpMaximumHedgePositions) continue;
      if(h.count > 0 && !InpAllowMultipleHedges) continue;
      double exposure = s.lots - h.lots;
      if(exposure <= 0) continue;
      double loss = -s.profit;
      double need = InpHedgeTriggerLoss * (h.count + 1); // escalate for additional hedges
      double lots = 0;
      switch(InpHedgeMode)
        {
         case HEDGE_FULL:      if(loss >= need) lots = exposure; break;
         case HEDGE_PARTIAL:   if(loss >= need) lots = exposure * InpHedgePercentage / 100.0; break;
         case HEDGE_DYNAMIC:   if(loss >= need) lots = HedgeLots(exposure) * MathMin(1.0, loss / (2.0 * MathMax(0.01, InpHedgeTriggerLoss))); break;
         case HEDGE_RECOVERY:  if(loss >= need) lots = exposure * InpHedgeLotMultiplier; break;
         case HEDGE_EMERGENCY:
           {
            double eq = AccountInfoDouble(ACCOUNT_EQUITY);
            if(g_st.peakEquity > 0 && (g_st.peakEquity - eq) / g_st.peakEquity * 100.0 >= InpHedgeEmergencyDD) lots = HedgeLots(exposure);
            break;
           }
         case HEDGE_GRID:      if(s.gridLevels >= InpMaximumGridLevels && loss >= need) lots = HedgeLots(exposure); break;
         case HEDGE_SIGNAL:    if(loss >= need && g_lastSignalDir == -side) lots = HedgeLots(exposure); break;
         case HEDGE_PROFIT_LOCK:
           {
            double pk = GVGet("pk_" + (string)side, 0);
            if(s.profit > pk) { pk = s.profit; GVSet("pk_" + (string)side, pk); }
            if(pk >= InpHedgeLockProfit && s.profit > 0 && s.profit <= pk * (1.0 - InpHedgeLockRetrace / 100.0))
               lots = HedgeLots(exposure);
            break;
           }
         case HEDGE_DIRECTIONAL:
           {
            double e = Buf(g_hHedgeEMA, 0, 1);
            bool against = Valid(e) && ((side > 0 && C(InpHedgeTF, 1) < e) || (side < 0 && C(InpHedgeTF, 1) > e));
            if(loss >= need && against) lots = HedgeLots(exposure);
            break;
           }
        }
      if(lots <= 0) continue;
      lots = NormLot(lots);
      if(lots > 0 && RiskAllowsNew(-side, lots, true))
        {
         LogInfo(StringFormat("Hedge %s %.2f lots (side loss %.2f)", side > 0 ? "SELL" : "BUY", lots, loss));
         OpenMarket(-side, lots, 0, 0, MAGIC_HEDGE, "H");
        }
     }
  }

//+------------------------------------------------------------------+
//| RECOVERY                                                         |
//+------------------------------------------------------------------+
//--- net P/L of the main+recovery positions if price were 'price'
double NetAtPrice(double price)
  {
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnPosition()) continue;
      int off = (int)(PositionGetInteger(POSITION_MAGIC) - (long)InpMagicNumber);
      if(((1 << off) & MASK_MAIN_REC) == 0) continue;
      int pt = (int)PositionGetInteger(POSITION_TYPE);
      double p = 0;
      if(OrderCalcProfit(pt == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, PositionGetDouble(POSITION_VOLUME),
                         PositionGetDouble(POSITION_PRICE_OPEN), price, p)) sum += p;
     }
   return sum;
  }

double RecLot(double lot) { return NormLot(MathMin(lot, InpMaximumRecoveryLot)); }

bool RecOpen(int dir, double lot, string tag)
  {
   lot = RecLot(lot);
   if(lot <= 0 || !RiskAllowsNew(dir, lot, true)) return false;
   if(g_st.recoveryStart == 0) { g_st.recoveryStart = TimeCurrent(); SaveState(); }
   return (OpenMarket(dir, lot, 0, 0, MAGIC_RECOVERY, tag) > 0);
  }

void RecCloseAll(string why)
  {
   CloseAll(why, 0, MAGIC_RECOVERY);
   CloseAll(why, 0, MAGIC_MAIN);
   g_st.recoveryStart = 0; GVDel("recArmed"); SaveState();
  }

void ManageRecovery()
  {
   if(!InpEnableRecovery || InpRecoveryMode == REC_DISABLED) return;
   SBasket mb, ms, rb, rs;
   ScanBasket(1, 1 << MAGIC_MAIN, mb); ScanBasket(-1, 1 << MAGIC_MAIN, ms);
   ScanBasket(1, 1 << MAGIC_RECOVERY, rb); ScanBasket(-1, 1 << MAGIC_RECOVERY, rs);
   int recCount = rb.count + rs.count;
   double total = mb.profit + ms.profit + rb.profit + rs.profit;
   int mainCount = mb.count + ms.count;
   if(mainCount + recCount == 0) { if(g_st.recoveryStart != 0) { g_st.recoveryStart = 0; SaveState(); } GVDel("recArmed"); return; }
   bool armed = (GVGet("recArmed", 0) > 0);
   if(!armed && total <= -InpRecoveryTriggerLoss) { armed = true; GVSet("recArmed", 1); LogInfo(StringFormat("Recovery armed at %.2f", total)); }
   //--- timeout and target (every mode)
   if((armed || recCount > 0) && InpRecoveryTimeoutMinutes > 0 && g_st.recoveryStart > 0 &&
      TimeCurrent() - g_st.recoveryStart >= InpRecoveryTimeoutMinutes * 60) { RecCloseAll("recovery timeout"); return; }
   if(armed && total >= InpRecoveryTargetMoney && InpRecoveryMode != REC_PARTIAL) { RecCloseAll(StringFormat("recovery target %.2f", total)); return; }
   if(!armed) return;
   if(g_st.recoveryStart == 0) { g_st.recoveryStart = TimeCurrent(); SaveState(); }
   //--- net losing direction of the main exposure
   int d = (mb.lots - ms.lots >= 0 ? 1 : -1);
   if(mainCount == 0) d = (rb.lots >= rs.lots ? 1 : -1);
   SBasket md, rd;
   if(d > 0) { md = mb; rd = rb; } else { md = ms; rd = rs; }
   double px = (d > 0 ? SymAsk() : SymBid());
   double step = Pts(InpRecoveryStepPoints);
   //--- worst open price of the losing side (main + recovery legs)
   double worst = md.worst;
   if(rd.count > 0) worst = (md.count == 0 ? rd.worst : (d > 0 ? MathMin(md.worst, rd.worst) : MathMax(md.worst, rd.worst)));
   bool movedAgainst = (worst > 0 && (d > 0 ? px <= worst - step : px >= worst + step));
   double firstLot = (md.firstLot > 0 ? md.firstLot : InpFixedLot);
   int lvl = recCount;
   if(lvl >= InpMaximumRecoveryLevels && InpRecoveryMode != REC_PARTIAL && InpRecoveryMode != REC_BASKET && InpRecoveryMode != REC_PROFIT_TARGET) return;
   if(!SpreadAllows()) return;
   switch(InpRecoveryMode)
     {
      case REC_LOT_MULT:
         if(movedAgainst) RecOpen(d, (rd.lastLot > 0 ? rd.lastLot : md.lastLot) * InpRecoveryMultiplier, "RM" + (string)(lvl + 1));
         break;
      case REC_GRID:
         if(movedAgainst) RecOpen(d, firstLot, "RG" + (string)(lvl + 1));
         break;
      case REC_OPPOSITE:
         if(total <= -InpRecoveryTriggerLoss * (lvl + 1))
           {
            double net = MathAbs(mb.lots + rb.lots - ms.lots - rs.lots);
            RecOpen(-d, MathMax(net, firstLot) * InpRecoveryMultiplier, "RO" + (string)(lvl + 1));
           }
         break;
      case REC_MULTI_LEVEL:
         if(total <= -InpRecoveryTriggerLoss * (lvl + 2) && movedAgainst)
            RecOpen(d, firstLot * MathPow(InpRecoveryMultiplier, lvl + 1), "RL" + (string)(lvl + 1));
         break;
      case REC_AVERAGE_PRICE:
        {
         if(!movedAgainst) break;
         double V = md.lots + rd.lots;
         double A = (md.lots * md.avg + rd.lots * rd.avg) / MathMax(V, 1e-9);
         double D = Pts(MathMax(10, InpRecoveryTPPoints));
         double gap = (d > 0 ? A - px : px - A);
         if(gap > D) RecOpen(d, V * (gap - D) / D, "RA" + (string)(lvl + 1));
         break;
        }
      case REC_HEDGE_ZONE:
        {
         //--- zone recovery: alternate at the zone edges; size each leg so a TP beyond the edge nets the target
         if(md.count == 0 && recCount == 0) break;
         double P0 = (md.count > 0 ? md.worst : rd.worst);
         double W = step, Tp = Pts(MathMax(10, InpRecoveryTPPoints));
         //--- direction of the newest leg
         SBasket allB, allS; ScanBasket(1, MASK_MAIN_REC, allB); ScanBasket(-1, MASK_MAIN_REC, allS);
         datetime tb = 0, ts = 0;
         if(allB.lastTicket > 0 && PositionSelectByTicket(allB.lastTicket)) tb = (datetime)PositionGetInteger(POSITION_TIME);
         if(allS.lastTicket > 0 && PositionSelectByTicket(allS.lastTicket)) ts = (datetime)PositionGetInteger(POSITION_TIME);
         int lastDir = (tb >= ts ? 1 : -1);
         double edgeLow = (d > 0 ? P0 - W : P0), edgeHigh = (d > 0 ? P0 : P0 + W);
         int newDir = 0; double target = 0;
         if(lastDir > 0 && SymBid() <= edgeLow)  { newDir = -1; target = edgeLow - Tp; }
         if(lastDir < 0 && SymAsk() >= edgeHigh) { newDir = 1;  target = edgeHigh + Tp; }
         if(newDir == 0) break;
         double netAt = NetAtPrice(target);
         double per1 = MoneyForDistance(1.0, Tp); // 1 lot from the edge to the TP
         if(per1 <= 0) break;
         double lot = (InpRecoveryTargetMoney - netAt) / per1;
         if(lot > 0) RecOpen(newDir, lot, "RZ" + (string)(lvl + 1));
         break;
        }
      case REC_PARTIAL:
        {
         //--- use winners to pay down part of the worst loser
         double winP = 0; ulong worstT = 0; double worstP = 0, worstV = 0;
         ulong winners[]; int nw = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong t = PositionGetTicket(i);
            if(t == 0 || !IsOwnPosition()) continue;
            double p = PosNetProfit();
            if(p > 0) { winP += p; ArrayResize(winners, nw + 1); winners[nw++] = t; }
            else if(p < worstP) { worstP = p; worstT = t; worstV = PositionGetDouble(POSITION_VOLUME); }
           }
         if(worstT == 0 || nw == 0 || winP < InpRecoveryTargetMoney + 0.01) break;
         double f = MathMin(1.0, (winP - InpRecoveryTargetMoney) / -worstP);
         double cv = FloorLot(worstV * f);
         if(cv < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) break;
         for(int k = 0; k < nw; k++) ClosePosition(winners[k], "partial recovery winner");
         if(cv >= worstV - 1e-9) ClosePosition(worstT, "partial recovery loser"); else ClosePartial(worstT, cv, "partial recovery loser");
         break;
        }
      case REC_BASKET:        break; // only waits for the break-even + target close above
      case REC_PROFIT_TARGET:
         if(g_st.recoveryDebt > 0 && total >= g_st.recoveryDebt + InpRecoveryTargetMoney) RecCloseAll("debt recovered");
         break;
     }
  }
//+------------------------------------------------------------------+
