//+------------------------------------------------------------------+
//|                                                UGE_Filters.mqh   |
//|  Market-condition filters: session, day, rollover, news,         |
//|  volatility, spread (+spike) and multi-timeframe confirmation.   |
//+------------------------------------------------------------------+

//==================== Time helpers =================================
//--- reference time (server or UTC). Tester has no real UTC, so the offset input is used there.
datetime RefTime()
  {
   if(InpTimeSource == TSRC_SERVER) return TimeCurrent();
   if(g_isTester) return TimeCurrent() - InpServerGMTOffset * 3600;
   return TimeGMT();
  }

int MinuteOfDay(datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.hour * 60 + d.min; }

//--- true if 'now' is inside [start,end) minutes, handling windows that cross midnight
bool InWindow(int startMin, int endMin, int now)
  {
   if(startMin == endMin) return true;
   if(startMin < endMin) return (now >= startMin && now < endMin);
   return (now >= startMin || now < endMin);
  }

//--- minutes since window start (assumes inside)
int MinutesInto(int startMin, int now) { int d = now - startMin; if(d < 0) d += 1440; return d; }

//==================== Session filter ===============================
struct SWindow { int s; int e; };

int BuildWindows(SWindow &w[])
  {
   ArrayResize(w, 0);
   int n = 0;
   int as = InpAsianStartHour * 60,  ae = InpAsianEndHour * 60;
   int ls = InpLondonStartHour * 60, le = InpLondonEndHour * 60;
   int ns = InpNYStartHour * 60,     ne = InpNYEndHour * 60;
   switch(InpTradingSessionMode)
     {
      case SESS_24H:       break;
      case SESS_ASIAN:     ArrayResize(w, 1); w[0].s = as; w[0].e = ae; n = 1; break;
      case SESS_LONDON:    ArrayResize(w, 1); w[0].s = ls; w[0].e = le; n = 1; break;
      case SESS_NEWYORK:   ArrayResize(w, 1); w[0].s = ns; w[0].e = ne; n = 1; break;
      case SESS_LONDON_NY: ArrayResize(w, 1); w[0].s = ls; w[0].e = ne; n = 1; break;
      case SESS_OVERLAP:   ArrayResize(w, 1); w[0].s = ns; w[0].e = le; n = 1; break;
      case SESS_CUSTOM:
         ArrayResize(w, 1);
         w[0].s = InpSessionStartHour * 60 + InpSessionStartMinute;
         w[0].e = InpSessionEndHour * 60 + InpSessionEndMinute; n = 1; break;
      case SESS_MULTIPLE:
      case SESS_BREAKOUT:
        {
         bool br = (InpTradingSessionMode == SESS_BREAKOUT);
         if(InpUseAsian)   { ArrayResize(w, n + 1); w[n].s = as; w[n].e = br ? (as + InpSessionBreakoutMinutes) % 1440 : ae; n++; }
         if(InpUseLondon)  { ArrayResize(w, n + 1); w[n].s = ls; w[n].e = br ? (ls + InpSessionBreakoutMinutes) % 1440 : le; n++; }
         if(InpUseNewYork) { ArrayResize(w, n + 1); w[n].s = ns; w[n].e = br ? (ns + InpSessionBreakoutMinutes) % 1440 : ne; n++; }
         break;
        }
     }
   return n;
  }

//--- true if NEW entries are allowed by the session filter
bool SessionAllows()
  {
   if(!InpEnableSessionFilter || InpTradingSessionMode == SESS_24H) return true;
   SWindow w[];
   int n = BuildWindows(w);
   int now = MinuteOfDay(RefTime());
   for(int i = 0; i < n; i++)
     {
      if(!InWindow(w[i].s, w[i].e, now)) continue;
      int into = MinutesInto(w[i].s, now);
      int len  = MinutesInto(w[i].s, w[i].e); if(len == 0) len = 1440;
      if(into < InpAvoidSessionOpening) continue;
      if(len - into <= InpAvoidSessionClosing) continue;
      return true;
     }
   return false;
  }

//--- true if positions should be closed because we are outside every session window
bool OutsideSessionForClose()
  {
   if(!InpEnableSessionFilter || !InpCloseAtSessionEnd || InpTradingSessionMode == SESS_24H) return false;
   if(InpTradingSessionMode == SESS_BREAKOUT) return false; // breakout windows only gate entries
   SWindow w[];
   int n = BuildWindows(w);
   int now = MinuteOfDay(RefTime());
   for(int i = 0; i < n; i++) if(InWindow(w[i].s, w[i].e, now)) return false;
   return true;
  }

//--- minutes until the active session ends (-1 if not in a session / 24h)
int MinutesToSessionEnd()
  {
   if(InpTradingSessionMode == SESS_24H) return -1;
   SWindow w[];
   int n = BuildWindows(w);
   int now = MinuteOfDay(RefTime());
   for(int i = 0; i < n; i++)
      if(InWindow(w[i].s, w[i].e, now)) { int d = w[i].e - now; if(d < 0) d += 1440; return d; }
   return -1;
  }

//==================== Day / weekend / rollover =====================
bool DayAllows()
  {
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   bool ok = false;
   switch(d.day_of_week)
     {
      case 0: ok = InpEnableSunday;    break;
      case 1: ok = InpEnableMonday;    break;
      case 2: ok = InpEnableTuesday;   break;
      case 3: ok = InpEnableWednesday; break;
      case 4: ok = InpEnableThursday;  break;
      case 5: ok = InpEnableFriday;    break;
      case 6: ok = InpEnableSaturday;  break;
     }
   if(!ok) return false;
   if(d.day_of_week == 5 && InpFridayStopTradingHour >= 0 && d.hour >= InpFridayStopTradingHour) return false;
   if(InpSkipRollover)
     {
      int m = d.hour * 60 + d.min;
      if(m >= 23 * 60 + 50 || m < 15) return false;
     }
   return true;
  }

bool WeekendCloseDue()
  {
   if(!InpCloseBeforeWeekend) return false;
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   if(d.day_of_week == 6 || d.day_of_week == 0) return true;
   return (d.day_of_week == 5 && d.hour * 60 + d.min >= InpFridayCloseHour * 60 + InpFridayCloseMinute);
  }

//==================== Spread filter ================================
double g_spreadHist[];
int    g_spreadIdx = 0, g_spreadCount = 0;

void SpreadSample()
  {
   int n = MathMax(10, InpSpreadAveragePeriod);
   if(ArraySize(g_spreadHist) != n) { ArrayResize(g_spreadHist, n); g_spreadIdx = 0; g_spreadCount = 0; }
   g_spreadHist[g_spreadIdx] = SpreadPoints();
   g_spreadIdx = (g_spreadIdx + 1) % n;
   if(g_spreadCount < n) g_spreadCount++;
  }

double AvgSpread()
  {
   if(g_spreadCount == 0) return SpreadPoints();
   double s = 0; for(int i = 0; i < g_spreadCount; i++) s += g_spreadHist[i];
   return s / g_spreadCount;
  }

bool SpreadAllows()
  {
   if(!InpEnableSpreadFilter) return true;
   int sp = SpreadPoints();
   if(InpMaximumSpread > 0 && sp > InpMaximumSpread) { LogDebug("Spread filter: " + (string)sp); return false; }
   if(InpEnableSpreadSpikeFilter && g_spreadCount >= 10 && sp > AvgSpread() * InpMaximumSpreadMultiplier)
     { LogDebug("Spread spike: " + (string)sp); return false; }
   return true;
  }

//==================== Volatility filter ============================
double VolatilityPoints()
  {
   double v = 0;
   switch(InpVolatilityMode)
     {
      case VOL_ATR:
      case VOL_STDDEV:       v = Buf(g_hVolFilter, 0, 1); break;
      case VOL_CANDLE_RANGE: v = AvgRange(InpVolatilityTF, InpVolatilityPeriod); break;
     }
   if(!Valid(v)) return 0;
   return ToPts(v);
  }

bool VolatilityAllows()
  {
   if(!InpEnableVolatilityFilter) return true;
   double v = VolatilityPoints();
   if(v <= 0) return false;
   if(InpMinimumATR > 0 && v < InpMinimumATR) return false;
   if(InpMaximumATR > 0 && v > InpMaximumATR) return false;
   return true;
  }

//==================== News filter ==================================
datetime g_newsTimes[];
datetime g_newsLoaded = 0;
datetime g_manualNews[];

void ParseManualNews()
  {
   ArrayResize(g_manualNews, 0);
   if(StringLen(InpManualNewsTimes) == 0) return;
   string parts[];
   int n = StringSplit(InpManualNewsTimes, ';', parts);
   for(int i = 0; i < n; i++)
     {
      string p = parts[i]; StringTrimLeft(p); StringTrimRight(p);
      if(StringLen(p) < 10) continue;
      datetime t = StringToTime(p);
      if(t > 0) { int k = ArraySize(g_manualNews); ArrayResize(g_manualNews, k + 1); g_manualNews[k] = t; }
     }
  }

bool ImpactAccepted(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
  {
   switch(InpNewsImpact)
     {
      case NEWS_ALL:    return true;
      case NEWS_LOW:    return (imp >= CALENDAR_IMPORTANCE_LOW);
      case NEWS_MEDIUM: return (imp >= CALENDAR_IMPORTANCE_MODERATE);
      case NEWS_HIGH:   return (imp == CALENDAR_IMPORTANCE_HIGH);
     }
   return false;
  }

//--- refresh calendar events every 15 minutes (live only; the calendar is empty in the tester)
void LoadNews()
  {
   if(g_isTester) return;
   if(TimeCurrent() - g_newsLoaded < 900 && g_newsLoaded > 0) return;
   g_newsLoaded = TimeCurrent();
   ArrayResize(g_newsTimes, 0);
   string cur[];
   int nc = StringSplit(InpNewsCurrencies, ',', cur);
   for(int c = 0; c < nc; c++)
     {
      string cc = cur[c]; StringTrimLeft(cc); StringTrimRight(cc);
      if(StringLen(cc) == 0) continue;
      MqlCalendarValue vals[];
      if(!CalendarValueHistory(vals, TimeCurrent() - 86400, TimeCurrent() + 2 * 86400, NULL, cc)) continue;
      int n = ArraySize(vals);
      for(int i = 0; i < n; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id, ev)) continue;
         if(!ImpactAccepted(ev.importance)) continue;
         int k = ArraySize(g_newsTimes); ArrayResize(g_newsTimes, k + 1); g_newsTimes[k] = vals[i].time;
        }
     }
   LogDebug("News events loaded: " + (string)ArraySize(g_newsTimes));
  }

bool InNewsWindow()
  {
   if(!InpEnableNewsFilter) return false;
   LoadNews();
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(g_newsTimes); i++)
      if(now >= g_newsTimes[i] - InpNewsBeforeMinutes * 60 && now <= g_newsTimes[i] + InpNewsAfterMinutes * 60) return true;
   for(int j = 0; j < ArraySize(g_manualNews); j++)
      if(now >= g_manualNews[j] - InpNewsBeforeMinutes * 60 && now <= g_manualNews[j] + InpNewsAfterMinutes * 60) return true;
   return false;
  }

//==================== Multi-timeframe ==============================
ENUM_TIMEFRAMES MTFFrame(int i)
  {
   switch(i)
     {
      case 0: return InpPrimaryTF;
      case 1: return InpSecondaryTF;
      case 2: return InpThirdTF;
      case 3: return InpFourthTF;
     }
   return InpFifthTF;
  }

int MTFCount() { return MathMax(1, MathMin(5, InpMTFCount)); }

//--- true if MTF confirmation allows trading in 'dir'
bool MTFAllows(int dir)
  {
   if(!InpEnableMTF || dir == 0) return true;
   int n = MTFCount();
   int agree = 0;
   int bias[5];
   for(int i = 0; i < n; i++)
     {
      bias[i] = TFBias(MTFFrame(i), g_hMTF[i], InpMTFMethod);
      if(bias[i] == dir) agree++;
     }
   ENUM_TIMEFRAMES ltf = MTFFrame(n - 1);
   int ltfCandle = (Bull(ltf, 1) ? 1 : (Bear(ltf, 1) ? -1 : 0));
   switch(InpMTFMode)
     {
      case MTF_ALL:       return (agree == n);
      case MTF_ANY:       return (agree >= 1);
      case MTF_MAJORITY:  return (agree >= MathMin(n, MathMax(1, InpMinimumTFConfirmations)));
      case MTF_HTF_BIAS:  return (bias[0] == dir);
      case MTF_LTF_ENTRY: return (ltfCandle == dir);
      case MTF_HTF_LTF:   return (bias[0] == dir && ltfCandle == dir);
     }
   return true;
  }
//+------------------------------------------------------------------+
