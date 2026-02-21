//+------------------------------------------------------------------+
//|                                              MarketRange ADR.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Professional Average Daily Range (ADR) tracker with daily open,  |
//| mid-points, and relative range percentage metrics.               |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MarketRange-ADR"
#property version     "1.07"
#property strict
#property indicator_chart_window

//--- Input Parameters
input int TimeZoneOfData = 0; // Chart time zone(from GMT)
input int TimeZoneOfSession = 0; // Dest time zone(from GMT)
input int ATRPeriod = 15; // Period for ATR
input int LineStyle = STYLE_SOLID;
input int LineThickness1 = 1; // Normal thickness
input color LineColor1 = clrMagenta; // Normal color
input int LineThickness2 = 2; // Thickness for range reached
input color LineColor2 = clrMagenta; // Color for range reached
input color LineColorOpen = clrGray; // Daily Open line color
input color LineColorMid = clrSilver;// ADR Middle line color
input color LineColorPDH_PDL = clrOrange;// Previous Day High/Low color
input int LineStylePDH_PDL = STYLE_SOLID;// Previous Day High/Low style
input color LabelColor = clrWhite;// Percent label color
input int LabelFontSize = 12; // Percent label size
input bool ShowPercentLabel = false; // Show Upsize/Down Size label
input bool ShowMidLine = false; // Show ADR Mid line
input bool ShowSpread = true; // Show current Spread
input color SpreadColor = clrWhite; // Spread color
input int SpreadFontSize = 10; // Spread font size
input int SpreadX = 10; // Spread X distance
input int SpreadY = 30; // Spread Y distance
input bool SendEmailAlert = false; // Send email when ADR reached
input bool DebugLogger = false;

//--- Constants (Internal use)
const int ADROpenHour = 0;
const int ADRCloseHour = 24;
const int ATRTimeFrame = PERIOD_D1;
const bool UseManualADR = false;
const int ManualADRValuePips = 0;

//--- Global Variables
datetime timelastupdate = 0;
int lasttimeframe = 0;
int lastfirstbar = - 1;
int prevTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorShortName("MarketRange ADR(" + IntegerToString(ATRPeriod) + ")");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
const int prev_calculated,
const datetime &time[],
const double &open[],
const double &high[],
const double &low[],
const double &close[],
const long &tick_volume[],
const long &volume[],
const int &spread[])
{
    if(Period() > PERIOD_D1) return(rates_total);

   // Ensure arrays are treated as series (index 0 is latest bar)
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    int idxfirstbaroftoday = 0;
    int idxfirstbarofyesterday = 0;
    int idxlastbarofyesterday = 0;

   // Calculate day indices based on timezone
    ComputeDayIndices(TimeZoneOfData, TimeZoneOfSession, idxfirstbaroftoday, idxfirstbarofyesterday, idxlastbarofyesterday);

   // Update variables
    lasttimeframe = Period();
    timelastupdate = time[0];
    lastfirstbar = idxfirstbaroftoday;

    int tzdiff = TimeZoneOfData + TimeZoneOfSession;
    int tzdiffsec = tzdiff * 3600;

    datetime startofday = time[idxfirstbaroftoday];
    double adr = iATR(NULL, ATRTimeFrame, ATRPeriod, 1);

    if(UseManualADR)
    adr = ManualADRValuePips * Point;

    double today_high = 0, today_low = 0, today_open = 0;
    double adr_high = 0, adr_low = 0;
    bool adr_reached = false;

   // Process today's bars to find open, high, low and ADR reached state
    for(int j = idxfirstbaroftoday; j >= 0; j--)
    {
        datetime bartime = time[j] - tzdiffsec;
      
        if(TimeHour(bartime) >= ADROpenHour && TimeHour(bartime) < ADRCloseHour)
        {
            if(today_open == 0)
            {
                today_open = open[idxfirstbaroftoday];
                adr_high = today_open + adr;
                adr_low = today_open - adr;
                today_high = today_open;
                today_low = today_open;
            }

         // Check 3 prices: Low, High, Close
            double prices[3];
            prices[0] = low[j];
            prices[1] = high[j];
            prices[2] = close[j];

            for(int k = 0; k < 3; k++)
            {
                double price = prices[k];
                double lasthigh = today_high;
                double lastlow = today_low;
                bool lastreached = adr_reached;

                today_high = MathMax(today_high, price);
                today_low = MathMin(today_low, price);
            
                double today_range = today_high - today_low;
                adr_reached = today_range >= adr - Point / 2.0;

            // Update ADR High/Low levels
                if(!lastreached && !adr_reached)
                {
                    adr_high = today_low + adr;
                    adr_low = today_high - adr;
                }
                else if(!lastreached && adr_reached)
                {
                    if(price >= lasthigh)
                    adr_high = today_low + adr;
                    else
                    adr_high = lasthigh;

                    if(price >= lastlow)
                    adr_low = today_low;
                    else
                    adr_low = lasthigh - adr;
                }
            }
        }
    }

   // Ensure adr_high and adr_low are calculated if today_open > 0
    if(today_open > 0)
    {
        if(!adr_reached)
        {
            adr_high = today_low + adr;
            adr_low = today_high - adr;
        }
    }

   // ADR Middle level
   double adr_mid = (adr_high + adr_low) / 2.0;

   // Previous Day High/Low
   double prev_day_high = 0;
   double prev_day_low = 0;
   datetime prev_day_start_time = 0;

   if(idxfirstbarofyesterday > 0 && idxfirstbarofyesterday > idxlastbarofyesterday)
   {
      prev_day_start_time = time[idxfirstbarofyesterday];
      prev_day_high = high[idxfirstbarofyesterday];
      prev_day_low = low[idxfirstbarofyesterday];

      for(int k = idxfirstbarofyesterday; k >= idxlastbarofyesterday; k--)
      {
         prev_day_high = MathMax(prev_day_high, high[k]);
         prev_day_low = MathMin(prev_day_low, low[k]);
      }
   }

   // Visuals
   SetTimeLine("today start", "ADR Start", idxfirstbaroftoday);

    color col = adr_reached ? LineColor2 : LineColor1;
    int thickness = adr_reached ? LineThickness2 : LineThickness1;

   // Alerts
    if(prevTime != (int)time[0] && adr_reached)
    {
        if(SendEmailAlert) SendMail(Symbol() + " | ADR reached", "Currently at " + DoubleToStr(Bid, Digits));
        prevTime = (int)time[0];
    }

    SetLevel("ADR High", adr_high, col, LineStyle, thickness, startofday);
    SetLevel("ADR Low", adr_low, col, LineStyle, thickness, startofday);
   
   if(ShowMidLine)
      SetLevel("ADR Mid", adr_mid, LineColorMid, STYLE_DOT, 1, startofday);
   else
      ObjectDelete("[MR_ADR] ADR Mid Line");

   SetLevel("Daily Open", today_open, LineColorOpen, STYLE_SOLID, 1, startofday);
   
   if(prev_day_high > 0 && prev_day_low > 0)
   {
      SetLevel("Prev Day High", prev_day_high, LineColorPDH_PDL, LineStylePDH_PDL, 1, prev_day_start_time);
      SetLevel("Prev Day Low", prev_day_low, LineColorPDH_PDL, LineStylePDH_PDL, 1, prev_day_start_time);
   }

   // Calculate Move Percents
    double up_size = 0, down_size = 0;
    double range = adr_high - adr_low;
   
    if(range > 0)
    {
        up_size = ((adr_high - close[0]) / range) * 100.0;
        down_size = ((close[0] - adr_low) / range) * 100.0;
    }

    string move_text = "Upsize: " + DoubleToStr(up_size, 1) + " % / Down Size: " + DoubleToStr(down_size, 1) + " % ";
   
   if(ShowPercentLabel)
      SetLabel("ADR Percent", move_text, LabelColor, LabelFontSize, 10, 10);
   else
      ObjectDelete("[MR_ADR] ADR Percent Label");

    string infoStr = "MarketRange ADR(" + IntegerToString(ATRPeriod) + "): " + DoubleToStr(adr / Point, 0) + " pips\n" +
                     "Today Range: " + DoubleToStr((today_high - today_low) / Point, 0) + " pips\n" +
                     "ADR Reached: " + (adr_reached ? "YES" : "NO");
    Comment(infoStr);

    // Display Spread
    if(ShowSpread)
    {
        double currentSpread = (Ask - Bid) / Point;
        // Adjust for 5-digit/3-digit brokers to show pips
        if(Digits == 3 || Digits == 5) currentSpread /= 10.0;
        
        string spreadText = "Spread: " + DoubleToStr(currentSpread, 1);
        SetLabel("Spread", spreadText, SpreadColor, SpreadFontSize, SpreadX, SpreadY);
    }
    else
        ObjectDelete("[MR_ADR] Spread Label");

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Compute index of first/last bar of yesterday and today           |
//+------------------------------------------------------------------+
void ComputeDayIndices(int tzlocal, int tzdest, int &idxToday, int &idxYesterdayStart, int &idxYesterdayEnd)
{
    int tzdiffsec = (tzlocal + tzdest) * 3600;
    int period = Period();
    int barsperday = (24 * 60) / (period == 0 ? 1 : period);
   
    int dayToday = TimeDayOfWeek(Time[0] - tzdiffsec);
    int dayYesterday;

    switch(dayToday)
    {
        case 6: // Sat
        case 0: // Sun
        case 1: // Mon
        dayYesterday = 5; // Previous Friday
        break;
        default:
        dayYesterday = dayToday - 1;
        break;
    }

    idxToday = 0;
    for(int i = 0; i <= barsperday + 1; i++)
    {
        if(TimeDayOfWeek(Time[i] - tzdiffsec) != dayToday)
        {
            idxToday = i - 1;
            break;
        }
    }

    idxYesterdayEnd = 0;
    for(int j = idxToday + 1; j <= 2 * barsperday + 1; j++)
    {
        if(TimeDayOfWeek(Time[j] - tzdiffsec) == dayYesterday)
        {
            idxYesterdayEnd = j;
            break;
        }
    }

    idxYesterdayStart = idxYesterdayEnd;
    for(int k = 1; k <= barsperday; k++)
    {
        if(TimeDayOfWeek(Time[idxYesterdayEnd + k] - tzdiffsec) != dayYesterday)
        {
            idxYesterdayStart = idxYesterdayEnd + k - 1;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Create or update horizontal level line                           |
//+------------------------------------------------------------------+
void SetLevel(string text, double level, color col, int linestyle, int thickness, datetime starttime)
{
    string name = "[MR_ADR] " + text + " Line";
    if(ObjectFind(name) == - 1)
    ObjectCreate(name, OBJ_TREND, 0, starttime, level, Time[0], level);
   
    ObjectSet(name, OBJPROP_BACK, true);
    ObjectSet(name, OBJPROP_STYLE, linestyle);
    ObjectSet(name, OBJPROP_COLOR, col);
    ObjectSet(name, OBJPROP_WIDTH, thickness);
    ObjectMove(name, 0, starttime, level);
    ObjectMove(name, 1, Time[0], level);
}

//+------------------------------------------------------------------+
//| Create or update vertical time line                              |
//+------------------------------------------------------------------+
void SetTimeLine(string objname, string text, int idx)
{
    string name = "[MR_ADR] " + objname;
    if(idx < 0 || idx >= Bars) return;
    datetime t = Time[idx];
    if(ObjectFind(name) == - 1)
    ObjectCreate(name, OBJ_VLINE, 0, t, 0);

    ObjectMove(name, 0, t, 0);
    ObjectSet(name, OBJPROP_BACK, true);
    ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSet(name, OBJPROP_COLOR, clrDarkGray);
}

//+------------------------------------------------------------------+
//| Create or update text label in corner                            |
//+------------------------------------------------------------------+
void SetLabel(string text, string val, color col, int size, int x, int y)
{
    string name = "[MR_ADR] " + text + " Label";
    if(ObjectFind(name) == - 1)
    {
        ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
        ObjectSet(name, OBJPROP_CORNER, 1); // Top Right
        ObjectSet(name, OBJPROP_ANCHOR, 6); // ANCHOR_RIGHT_UP
    }
   
    ObjectSetText(name, val, size, "Arial Bold", col);
    ObjectSet(name, OBJPROP_XDISTANCE, x);
    ObjectSet(name, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                     |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(StringFind(name, "[MR_ADR]") == 0)
        ObjectDelete(name);
    }
}
