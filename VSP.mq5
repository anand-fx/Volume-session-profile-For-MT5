//+------------------------------------------------------------------+
//| SessionVolumeProfile.mq5                                         |
//| Session Volume Profile Indicator — VAH, POC, VAL + Histogram     |
//+------------------------------------------------------------------+
#property copyright "Chethan Kumar S J"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== SESSION (America/New_York — auto DST) ==="
input int    NY_Hour        = 9;    // NY session open hour
input int    NY_Min         = 30;   // NY session open minute

input group "=== VOLUME PROFILE ==="
input int    VP_Bins        = 400;  // Number of price bins
input double ValueAreaPct   = 70.0; // Value Area %

input group "=== DISPLAY ==="
input int    HistoWidthBars = 50;   // Max histogram width in bars
input color  VAH_Color      = clrLime;
input color  POC_Color      = clrYellow;
input color  VAL_Color      = clrRed;
input color  HistoVA_Color  = clrDodgerBlue;
input color  HistoPOC_Color = clrYellow;
input color  HistoOut_Color = clrDimGray;
input int    HistoLineWidth = 3;

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
double   g_VAH = 0, g_POC = 0, g_VAL = 0;
double   g_BinVol[];
double   g_SessLow = 0, g_SessHigh = 0, g_BinSize = 0;
int      g_PocBin = 0, g_VaLoBin = 0, g_VaHiBin = 0;
datetime g_PrevSessStart = 0, g_PrevSessEnd = 0;
datetime g_LastBarTime   = 0;
string   PFX = "SVP_IND_";

//+------------------------------------------------------------------+
//| DST-aware UTC offset for New York                                |
//+------------------------------------------------------------------+
int NyUtcOffsetSec()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   int year = d.year;

   MqlDateTime dst;
   dst.year = year; dst.mon = 3; dst.day = 1; dst.hour = 7; dst.min = 0; dst.sec = 0;
   datetime march1 = StructToTime(dst);
   MqlDateTime m1; TimeToStruct(march1, m1);
   int dow1 = m1.day_of_week;
   int daysToSun1 = (dow1 == 0) ? 0 : 7 - dow1;
   datetime dstStart = march1 + (datetime)((daysToSun1 + 7) * 86400);

   dst.mon = 11; dst.day = 1; dst.hour = 6;
   datetime nov1 = StructToTime(dst);
   MqlDateTime n1; TimeToStruct(nov1, n1);
   int dow2 = n1.day_of_week;
   int daysToSun2 = (dow2 == 0) ? 0 : 7 - dow2;
   datetime dstEnd = nov1 + (datetime)(daysToSun2 * 86400);

   datetime now = TimeCurrent();
   return (now >= dstStart && now < dstEnd) ? -4 * 3600 : -5 * 3600;
}

//+------------------------------------------------------------------+
//| Convert NY time to UTC for today                                 |
//+------------------------------------------------------------------+
datetime NyToUtcToday(int nyHour, int nyMin)
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0; d.min = 0; d.sec = 0;
   datetime todayMidnightUtc = StructToTime(d);
   int offset    = NyUtcOffsetSec();
   int nySeconds = nyHour * 3600 + nyMin * 60;
   return todayMidnightUtc + (datetime)(nySeconds - offset);
}

//+------------------------------------------------------------------+
//| Get previous session range                                       |
//+------------------------------------------------------------------+
void GetPrevSessionRange(datetime &prevStart, datetime &prevEnd)
{
   prevEnd   = NyToUtcToday(NY_Hour, NY_Min);
   prevStart = prevEnd - 86400;
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(g_BinVol, VP_Bins);
   GetPrevSessionRange(g_PrevSessStart, g_PrevSessEnd);
   CalculatePrevSessionVP();
   Redraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAll();
   Comment("");
}

//+------------------------------------------------------------------+
//| ON CALCULATE                                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime != g_LastBarTime)
   {
      g_LastBarTime = barTime;
      GetPrevSessionRange(g_PrevSessStart, g_PrevSessEnd);
      DeleteAll();
      CalculatePrevSessionVP();
      Redraw();
   }
   Dashboard();
   return rates_total;
}

//+------------------------------------------------------------------+
//| Calculate previous session Volume Profile                        |
//+------------------------------------------------------------------+
void CalculatePrevSessionVP()
{
   g_VAH = 0; g_POC = 0; g_VAL = 0;
   g_SessLow = 0; g_SessHigh = 0; g_BinSize = 0;

   int total = iBars(_Symbol, _Period);
   if(total < 10) { Print("VP: not enough bars"); return; }

   double hiArr[], loArr[], clArr[], volArr[];
   int    count = 0;
   double sHi   = -DBL_MAX, sLo = DBL_MAX;

   for(int i = total - 1; i >= 0; i--)
   {
      datetime bt = iTime(_Symbol, _Period, i);
      if(bt <  g_PrevSessStart) continue;
      if(bt >= g_PrevSessEnd)   continue;

      double h = iHigh  (_Symbol, _Period, i);
      double l = iLow   (_Symbol, _Period, i);
      double c = iClose (_Symbol, _Period, i);
      double v = (double)iVolume(_Symbol, _Period, i);

      ArrayResize(hiArr,  count + 1);
      ArrayResize(loArr,  count + 1);
      ArrayResize(clArr,  count + 1);
      ArrayResize(volArr, count + 1);
      hiArr[count] = h; loArr[count] = l;
      clArr[count] = c; volArr[count] = v;
      count++;
      if(h > sHi) sHi = h;
      if(l < sLo) sLo = l;
   }

   if(count < 5 || sHi <= sLo) { Print("PrevVP: insufficient data"); return; }

   double binSz = (sHi - sLo) / VP_Bins;
   if(binSz <= 0) return;

   ArrayResize(g_BinVol, VP_Bins);
   ArrayInitialize(g_BinVol, 0);

   for(int b = 0; b < count; b++)
   {
      double rng    = hiArr[b] - loArr[b];
      double upFrac = (rng > 0) ? (clArr[b] - loArr[b]) / rng : 0.5;
      double dnFrac = 1.0 - upFrac;
      double upVol  = volArr[b] * upFrac;
      double dnVol  = volArr[b] * dnFrac;

      int bLo  = MathMax(0, MathMin((int)MathFloor((loArr[b] - sLo) / binSz), VP_Bins - 1));
      int bHi  = MathMax(0, MathMin((int)MathFloor((hiArr[b] - sLo) / binSz), VP_Bins - 1));
      int span = bHi - bLo + 1;

      for(int bn = bLo; bn <= bHi; bn++)
      {
         double pos     = (double)(bn - bLo) / MathMax(1, span - 1);
         double binUp   = (span > 1) ? upVol * pos         / MathMax(1, span / 2.0) : upVol;
         double binDown = (span > 1) ? dnVol * (1.0 - pos) / MathMax(1, span / 2.0) : dnVol;
         g_BinVol[bn] += (binUp + binDown);
      }
   }

   // Find POC
   int    pocBin = 0;
   double maxV = -1, totV = 0;
   for(int bn = 0; bn < VP_Bins; bn++)
   {
      totV += g_BinVol[bn];
      if(g_BinVol[bn] > maxV) { maxV = g_BinVol[bn]; pocBin = bn; }
   }

   // Expand Value Area
   double target = totV * (ValueAreaPct / 100.0);
   double vaV    = g_BinVol[pocBin];
   int    vaLo   = pocBin, vaHi = pocBin;
   while(vaV < target)
   {
      double vDn = (vaLo > 0)          ? g_BinVol[vaLo - 1] : 0;
      double vUp = (vaHi < VP_Bins - 1) ? g_BinVol[vaHi + 1] : 0;
      if(vDn == 0 && vUp == 0) break;
      if(vUp >= vDn) { vaHi++; vaV += g_BinVol[vaHi]; }
      else           { vaLo--; vaV += g_BinVol[vaLo]; }
   }

   g_SessLow  = sLo;
   g_SessHigh = sHi;
   g_BinSize  = binSz;
   g_PocBin   = pocBin;
   g_VaLoBin  = vaLo;
   g_VaHiBin  = vaHi;
   g_POC = sLo + (pocBin + 0.5) * binSz;
   g_VAH = MathMin(sLo + (vaHi + 1.0) * binSz, sHi);
   g_VAL = MathMax(sLo +  vaLo         * binSz, sLo);
}

//+------------------------------------------------------------------+
//| REDRAW                                                           |
//+------------------------------------------------------------------+
void Redraw()
{
   DrawLevels();
   DrawHistogram();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw VAH / POC / VAL lines                                       |
//+------------------------------------------------------------------+
void DrawLevels()
{
   HLine(PFX + "VAH", g_VAH, VAH_Color, "VAH " + DoubleToString(g_VAH, 5));
   HLine(PFX + "POC", g_POC, POC_Color, "POC " + DoubleToString(g_POC, 5));
   HLine(PFX + "VAL", g_VAL, VAL_Color, "VAL " + DoubleToString(g_VAL, 5));
}

//+------------------------------------------------------------------+
//| Draw Volume Profile Histogram                                    |
//+------------------------------------------------------------------+
void DrawHistogram()
{
   if(g_BinSize <= 0 || g_SessLow <= 0) return;

   int      periodSec      = PeriodSeconds(_Period);
   datetime tLeft          = g_PrevSessStart;
   datetime tRight         = g_PrevSessEnd;

   double maxV = 0;
   for(int bn = 0; bn < VP_Bins; bn++)
      if(g_BinVol[bn] > maxV) maxV = g_BinVol[bn];
   if(maxV <= 0) return;

   long maxWidthSec     = (long)HistoWidthBars * periodSec;
   long sessionWidthSec = (long)(tRight - tLeft);
   long maxAllowedSec   = MathMin(maxWidthSec, sessionWidthSec);

   for(int bn = 0; bn < VP_Bins; bn++)
   {
      if(g_BinVol[bn] <= 0) continue;

      double   midPrice     = g_SessLow + (bn + 0.5) * g_BinSize;
      long     barLenSec    = (long)MathRound((g_BinVol[bn] / maxV) * maxAllowedSec);
      if(barLenSec < periodSec) barLenSec = periodSec;

      datetime tBarRight = tLeft + (datetime)barLenSec;
      if(tBarRight > tRight) tBarRight = tRight;

      color c = (bn == g_PocBin)                     ? HistoPOC_Color :
                (bn >= g_VaLoBin && bn <= g_VaHiBin) ? HistoVA_Color  :
                                                        HistoOut_Color;

      string nm = PFX + "H_" + IntegerToString(bn);
      ObjectDelete(0, nm);
      if(ObjectCreate(0, nm, OBJ_TREND, 0, tLeft, midPrice, tBarRight, midPrice))
      {
         ObjectSetInteger(0, nm, OBJPROP_COLOR,      c);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH,      HistoLineWidth);
         ObjectSetInteger(0, nm, OBJPROP_STYLE,      STYLE_SOLID);
         ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT,  false);
         ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT,   false);
         ObjectSetInteger(0, nm, OBJPROP_BACK,       false);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
      }
   }

   // Dashed vertical line at session start
   string vl1 = PFX + "VLINE_START";
   ObjectDelete(0, vl1);
   if(ObjectCreate(0, vl1, OBJ_VLINE, 0, tLeft, 0))
   {
      ObjectSetInteger(0, vl1, OBJPROP_COLOR,      clrGray);
      ObjectSetInteger(0, vl1, OBJPROP_STYLE,      STYLE_DASH);
      ObjectSetInteger(0, vl1, OBJPROP_WIDTH,      1);
      ObjectSetInteger(0, vl1, OBJPROP_BACK,       true);
      ObjectSetInteger(0, vl1, OBJPROP_SELECTABLE, false);
   }

   // Solid vertical line at session end
   string vl2 = PFX + "VLINE_END";
   ObjectDelete(0, vl2);
   if(ObjectCreate(0, vl2, OBJ_VLINE, 0, tRight, 0))
   {
      ObjectSetInteger(0, vl2, OBJPROP_COLOR,      clrWhite);
      ObjectSetInteger(0, vl2, OBJPROP_STYLE,      STYLE_SOLID);
      ObjectSetInteger(0, vl2, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, vl2, OBJPROP_BACK,       true);
      ObjectSetInteger(0, vl2, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Helper: horizontal line object                                   |
//+------------------------------------------------------------------+
void HLine(string name, double price, color clr, string tip)
{
   ObjectDelete(0, name);
   if(price <= 0) return;
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      2);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP,    tip);
}

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
void Dashboard()
{
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    off   = NyUtcOffsetSec();
   string tzLbl = (off == -4 * 3600) ? "EDT (UTC-4)" : "EST (UTC-5)";

   string d = "";
   d += "╔══════════════════════════════════════╗\n";
   d += "║    Session Volume Profile Indicator  ║\n";
   d += "╠══════════════════════════════════════╣\n";
   d += StringFormat("║  TZ      : %-27s║\n", tzLbl);
   d += StringFormat("║  Prev    : %s → %s ║\n",
        TimeToString(g_PrevSessStart, TIME_DATE | TIME_MINUTES),
        TimeToString(g_PrevSessEnd,   TIME_MINUTES));
   d += "╠══════════════════════════════════════╣\n";
   d += StringFormat("║  VAH     : %-27s║\n", DoubleToString(g_VAH, 5));
   d += StringFormat("║  POC     : %-27s║\n", DoubleToString(g_POC, 5));
   d += StringFormat("║  VAL     : %-27s║\n", DoubleToString(g_VAL, 5));
   d += StringFormat("║  BID     : %-27s║\n", DoubleToString(bid, 5));
   d += "╚══════════════════════════════════════╝";
   Comment(d);
}

//+------------------------------------------------------------------+
//| Delete all indicator objects                                     |
//+------------------------------------------------------------------+
void DeleteAll()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, PFX) == 0) ObjectDelete(0, n);
   }
}
//+------------------------------------------------------------------+