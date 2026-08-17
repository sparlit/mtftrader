//+------------------------------------------------------------------+
//|                                             DashboardBrain.mqh   |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include "MarketBrain.mqh"

class CDashboardBrain
{
private:
   string m_prefix;
   int m_xOffset;
   int m_yOffset;
   int m_width;
   int m_height;

   color m_bgColor;
   color m_textColor;
   color m_bullColor;
   color m_bearColor;
   color m_accentColor;

   // Creates the object with the properties shared by every dashboard element.
   // Returns the object name; newlyCreated tells whether one-time setup is needed.
   string EnsureObject(string name, ENUM_OBJECT type, int x, int y, bool &newlyCreated)
   {
      string objName = m_prefix + name;
      newlyCreated = (ObjectFind(0, objName) < 0);
      if(newlyCreated)
      {
         ObjectCreate(0, objName, type, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      }
      return objName;
   }

   int TableStartX() { return m_xOffset + 15; }
   int TableY()      { return m_yOffset + 110; }
   int RowY(int row) { return TableY() + 25 + (row * 26); }
   int RowRightX()   { return m_xOffset + m_width - 250; }

   // Center X of the table columns: TF, timer, RSI, ATR, progress
   int ColumnCenterX(int column)
   {
      int offsets[5] = {32, 65 + 60, 65 + 120 + 52, 65 + 120 + 105 + 60, 65 + 120 + 105 + 120 + 75};
      return TableStartX() + offsets[column];
   }

   int ProgressBarX() { return TableStartX() + 65 + 120 + 105 + 120 + 15; }

   color BiasColor(string bias)
   {
      if(bias == ITIP_BIAS_BULLISH) return m_bullColor;
      if(bias == ITIP_BIAS_BEARISH) return m_bearColor;
      return m_textColor;
   }

   void CreateLabel(string name, int x, int y, string text, int fontSize, color textColor, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
   {
      bool created;
      string objName = EnsureObject(name, OBJ_LABEL, x, y, created);
      if(created)
      {
         ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI");
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
      }
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   }

   void CreateRect(string name, int x1, int y1, int x2, int y2, color bg, color border)
   {
      bool created;
      string objName = EnsureObject(name, OBJ_RECTANGLE_LABEL, x1, y1, created);
      if(created)
      {
         ObjectSetInteger(0, objName, OBJPROP_XSIZE, x2 - x1);
         ObjectSetInteger(0, objName, OBJPROP_YSIZE, y2 - y1);
         ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      }
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, border);
   }

   void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color textCol)
   {
      bool created;
      string objName = EnsureObject(name, OBJ_BUTTON, x, y, created);
      if(created)
      {
         ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
         ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
         ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, C'64,64,64');
      }
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textCol);
   }

public:
   CDashboardBrain()
   {
      m_prefix = "ITIP_DB_";
      m_xOffset = 20;
      m_yOffset = 50;
      m_width = 850;
      m_height = 420;

      m_bgColor = C'18,18,24';       // Dark Slate
      m_textColor = C'240,240,245';  // Premium off-white
      m_bullColor = C'46,204,113';   // Emerald Green
      m_bearColor = C'231,76,60';    // Alizarin Red
      m_accentColor = C'52,152,219'; // Flat Blue
   }

   ~CDashboardBrain()
   {
      ObjectsDeleteAll(0, m_prefix);
   }

   void DrawPanel()
   {
      CreateRect("MainBG", m_xOffset, m_yOffset, m_xOffset + m_width, m_yOffset + m_height, m_bgColor, C'80,80,95');

      CreateRect("HeaderBar", m_xOffset, m_yOffset, m_xOffset + m_width, m_yOffset + 40, C'26,26,36', C'80,80,95');
      CreateLabel("Title", m_xOffset + 15, m_yOffset + 10, "INSTITUTIONAL TRADING INTELLIGENCE PLATFORM (ITIP) v1.0", 11, m_textColor);

      int widgetY = m_yOffset + 50;
      CreateLabel("StatusHeader", m_xOffset + 15, widgetY, "SYSTEM MONITORING", 10, m_accentColor);

      int tableY = TableY();
      CreateRect("TableHeader", TableStartX(), tableY, RowRightX(), tableY + 25, C'33,33,47', C'60,60,75');

      CreateLabel("H_TF", ColumnCenterX(0), tableY + 4, "TF", 9, m_textColor, ANCHOR_CENTER);
      CreateLabel("H_Timer", ColumnCenterX(1), tableY + 4, "CANDLE TIMER", 9, m_textColor, ANCHOR_CENTER);
      CreateLabel("H_RSI", ColumnCenterX(2), tableY + 4, "RSI (14)", 9, m_textColor, ANCHOR_CENTER);
      CreateLabel("H_ATR", ColumnCenterX(3), tableY + 4, "ATR", 9, m_textColor, ANCHOR_CENTER);
      CreateLabel("H_Progress", ColumnCenterX(4), tableY + 4, "PROGRESS BAR", 9, m_textColor, ANCHOR_CENTER);

      for(int i = 0; i < ITIP_TF_COUNT; i++)
      {
         int rowY = RowY(i);
         CreateRect("Row_" + (string)i, TableStartX(), rowY, RowRightX(), rowY + 26, (i % 2 == 0) ? C'22,22,30' : C'18,18,24', C'40,40,50');
      }

      int actionX = m_xOffset + m_width - 220;
      int actionY = m_yOffset + 110;

      CreateRect("ActionBG", actionX, actionY, actionX + 205, actionY + 235, C'28,28,38', C'60,60,75');
      CreateLabel("ActTitle", actionX + 15, actionY + 10, "INSTITUTIONAL EXECUTION", 9, m_accentColor);

      CreateButton("BtnBuy", actionX + 15, actionY + 40, 80, 32, "BUY LMT", m_bullColor, m_textColor);
      CreateButton("BtnSell", actionX + 110, actionY + 40, 80, 32, "SELL LMT", m_bearColor, m_textColor);

      CreateButton("BtnClose", actionX + 15, actionY + 85, 175, 30, "CLOSE ALL POSITIONS", C'192,57,43', m_textColor);
      CreateButton("BtnPart", actionX + 15, actionY + 125, 175, 30, "PARTIAL CLOSE (50%)", C'230,126,34', m_textColor);
      CreateButton("BtnBE", actionX + 15, actionY + 165, 175, 30, "TRAIL STOP & BREAKEVEN", C'52,73,94', m_textColor);

      CreateRect("Footer", m_xOffset, m_yOffset + m_height - 35, m_xOffset + m_width, m_yOffset + m_height, C'20,20,28', C'80,80,95');
      CreateLabel("FooterText", m_xOffset + 15, m_yOffset + m_height - 25, "System Integrity: SECURE | ZeroMQ Link: STABLE | Execution Mode: ULTRALOW-LATENCY", 9, m_accentColor);

      ChartRedraw(0);
   }

   void UpdateDashboard(CMarketBrain &market, double aiConfidence, string lastSignalStr)
   {
      int widgetY = m_yOffset + 50;
      string statusText = StringFormat("AI Confidence: %.1f%%  |  Bias: %s  |  Cum. Delta: %.2f  |  Session: %s",
                                       aiConfidence, lastSignalStr, market.GetCumulativeDelta(), market.GetCurrentSession());
      CreateLabel("StatusTextVal", m_xOffset + 15, widgetY + 20, statusText, 10, m_textColor);

      for(int i = 0; i < ITIP_TF_COUNT; i++)
      {
         int rowY = RowY(i);
         TFData tf = market.timeframes[i];

         CreateLabel("lblTF_" + (string)i, ColumnCenterX(0), rowY + 5, tf.name, 9, m_textColor, ANCHOR_CENTER);

         CreateLabel("lblTimer_" + (string)i, ColumnCenterX(1), rowY + 5, tf.timerStr, 9,
                     (tf.secondsRemaining < 60) ? m_bearColor : m_textColor, ANCHOR_CENTER);

         CreateLabel("lblRSI_" + (string)i, ColumnCenterX(2), rowY + 5, StringFormat("%.1f", tf.rsiVal), 9,
                     BiasColor(BiasFromRSI(tf.rsiVal)), ANCHOR_CENTER);

         CreateLabel("lblATR_" + (string)i, ColumnCenterX(3), rowY + 5, StringFormat("%.5f", tf.atrVal), 9, m_textColor, ANCHOR_CENTER);

         int barX = ProgressBarX();
         int barW = 120;
         int fillW = (int)ClampDouble(barW * (tf.progressPercent / 100.0), 1, barW);

         CreateRect("progBG_" + (string)i, barX, rowY + 6, barX + barW, rowY + 18, C'40,40,55', C'60,60,75');
         CreateRect("progFill_" + (string)i, barX, rowY + 6, barX + fillW, rowY + 18, m_accentColor, m_accentColor);
      }

      ChartRedraw(0);
   }
};
