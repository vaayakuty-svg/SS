//+------------------------------------------------------------------+
//|                                                  UGE_Panel.mqh   |
//|  Dashboard, entry markers, virtual level lines, grid levels and  |
//|  notifications (popup, push, sound, Telegram).                   |
//+------------------------------------------------------------------+
#define PANEL_PREFIX "UGE_PNL_"

string g_status = "Starting";

//==================== Notifications ================================
string UrlEncode(string s)
  {
   string out = "";
   uchar b[];
   int n = StringToCharArray(s, b, 0, WHOLE_ARRAY, CP_UTF8) - 1;
   for(int i = 0; i < n; i++)
     {
      uchar c = b[i];
      if((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '-' || c == '_' || c == '.')
         out += CharToString(c);
      else out += StringFormat("%%%02X", c);
     }
   return out;
  }

void SendTelegram(string msg)
  {
   if(!InpEnableTelegram || g_isTester || StringLen(InpTelegramBotToken) == 0 || StringLen(InpTelegramChatID) == 0) return;
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string body = "chat_id=" + UrlEncode(InpTelegramChatID) + "&text=" + UrlEncode(msg);
   char data[], res[];
   string hdrOut;
   int len = StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0) ArrayResize(data, len - 1); // drop the terminating zero
   int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n", 5000, data, res, hdrOut);
   if(code != 200) LogError("Telegram failed (" + (string)code + "). Add https://api.telegram.org to Tools > Options > Expert Advisors > WebRequest.");
  }

void Notify(string msg)
  {
   string full = "UGE " + _Symbol + ": " + msg;
   LogInfo(msg);
   if(g_isTester) return;
   if(InpEnableAlerts) Alert(full);
   if(InpEnablePushNotification) SendNotification(full);
   if(InpEnableSoundAlert) PlaySound(InpSoundFile);
   SendTelegram(full);
  }

//==================== Chart objects ================================
void Label(string id, int row, string text)
  {
   string n = PANEL_PREFIX + id;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetString(0, n, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, InpPanelX + 8);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, InpPanelY + 6 + row * 15);
   ObjectSetInteger(0, n, OBJPROP_COLOR, InpPanelColor);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
  }

void PanelBackground(int rows)
  {
   string n = PANEL_PREFIX + "bg";
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'20,24,32');
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, rows * 15 + 12);
  }

void HLine(string id, double price, color clr, ENUM_LINE_STYLE st)
  {
   string n = PANEL_PREFIX + id;
   if(price <= 0) { ObjectDelete(0, n); return; }
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_STYLE, st);
  }

void EntryMarker(int dir, double price)
  {
   if(!InpShowEntryMarkers) return;
   string n = PANEL_PREFIX + "arr_" + (string)(long)TimeCurrent() + "_" + (string)dir;
   ObjectCreate(0, n, dir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, TimeCurrent(), price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, dir > 0 ? clrDodgerBlue : clrTomato);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
  }

void RemovePanel() { ObjectsDeleteAll(0, PANEL_PREFIX); }

//==================== Dashboard ====================================
void UpdatePanel(int lastSignal)
  {
   if(g_isTester && MQLInfoInteger(MQL_VISUAL_MODE) == 0) return; // skip drawing in fast tests
   if(!InpShowChartPanel) { ObjectsDeleteAll(0, PANEL_PREFIX + "L"); ObjectDelete(0, PANEL_PREFIX + "bg"); }
   SExposure e; GetExposure(e);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE), eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double realized = RealizedToday();
   double ddm = 0, ddp = CurrentDrawdownPct(ddm);
   if(InpShowChartPanel)
     {
      int r = 0;
      Label("L" + (string)r, r, "UNIVERSAL GOLD EA  " + _Symbol + "  #" + (string)InpMagicNumber); r++;
      Label("L" + (string)r, r, StringFormat("Status : %s", g_status)); r++;
      Label("L" + (string)r, r, StringFormat("Account: %s  Spread %d (avg %.0f)", g_isHedging ? "Hedging" : "Netting", SpreadPoints(), AvgSpread())); r++;
      Label("L" + (string)r, r, StringFormat("Balance: %.2f  Equity: %.2f", bal, eq)); r++;
      if(InpShowProfitPanel)
        {
         Label("L" + (string)r, r, StringFormat("Today  : %+.2f  Floating: %+.2f", realized, e.profit)); r++;
         Label("L" + (string)r, r, StringFormat("DD     : %.2f%% (%.2f)  Peak %.2f", ddp, ddm, g_st.peakEquity)); r++;
        }
      Label("L" + (string)r, r, StringFormat("Open   : B%d %.2f / S%d %.2f  Pend %d", e.buys, e.buyLots, e.sells, e.sellLots, e.pendings)); r++;
      Label("L" + (string)r, r, StringFormat("Magics : main %d grid %d hedge %d rec %d", e.byMagic[0], e.byMagic[1], e.byMagic[2], e.byMagic[3])); r++;
      Label("L" + (string)r, r, StringFormat("Trades : today %d  W%d L%d  streak L%d W%d", g_st.tradesToday, g_st.winsToday, g_st.lossesToday, g_st.consecLosses, g_st.consecWins)); r++;
      Label("L" + (string)r, r, StringFormat("Signal : %s", lastSignal > 0 ? "BUY" : (lastSignal < 0 ? "SELL" : "-"))); r++;
      Label("L" + (string)r, r, StringFormat("Halts  : daily %s  DD %s", g_st.dailyHalt ? "YES" : "no", g_st.ddHalt ? "YES" : "no")); r++;
      PanelBackground(r);
     }
   //--- virtual levels (money TP, basket break-even)
   if(InpShowSLTPLevels)
     {
      double net = e.buyLots - e.sellLots;
      double be = (MathAbs(net) > 1e-9 ? (e.buyLots * e.buyAvg - e.sellLots * e.sellAvg) / net : 0);
      HLine("be", be, clrGold, STYLE_DOT);
     }
   //--- next grid levels
   if(InpShowGridLevels && InpEnableGrid)
     {
      double step = GridStep(0);
      HLine("gb", e.buys > 0 ? e.lowestBuy - step : 0, clrDeepSkyBlue, STYLE_DASHDOT);
      HLine("gs", e.sells > 0 ? e.highestSell + step : 0, clrOrangeRed, STYLE_DASHDOT);
     }
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
