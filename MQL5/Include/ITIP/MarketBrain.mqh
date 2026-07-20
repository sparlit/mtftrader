//+------------------------------------------------------------------+
//|                                                  MarketBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include <Trade\Trade.mqh>

// Struct for Timeframe info
struct TFData
{
   ENUM_TIMEFRAMES tf;
   string name;
   int secondsTotal;
   int secondsRemaining;
   double progressPercent;
   datetime lastBarTime;
   double rsiVal;
   double atrVal;
   string bias; // BULLISH / BEARISH / NEUTRAL
   string timerStr;
};

// Struct for SMC Objects
struct OrderBlock
{
   double top;
   double bottom;
   bool isBullish;
   bool isMitigated;
};

struct FVG
{
   double top;
   double bottom;
   bool isBullish;
   bool isMitigated;
};

class CMarketBrain
{
private:
   string m_symbol;
   datetime m_lastTickTime;
   double m_cumDelta;

   // Handle arrays for static reuse
   int m_rsiHandles[8];
   int m_atrHandles[8];

   // Order Blocks and FVG lists
   OrderBlock m_obList[];
   FVG m_fvgList[];

public:
   TFData timeframes[8];

   CMarketBrain()
   {
      m_symbol = _Symbol;
      m_cumDelta = 0.0;
      InitTimeframes();
      InitHandles();
   }

   ~CMarketBrain()
   {
      for(int i = 0; i < 8; i++)
      {
         if(m_rsiHandles[i] != INVALID_HANDLE) IndicatorRelease(m_rsiHandles[i]);
         if(m_atrHandles[i] != INVALID_HANDLE) IndicatorRelease(m_atrHandles[i]);
      }
   }

   void InitTimeframes()
   {
      ENUM_TIMEFRAMES tfs[8] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
      string names[8] = {"M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
      int secs[8] = {300, 900, 1800, 3600, 14400, 86400, 604800, 2592000};

      for(int i = 0; i < 8; i++)
      {
         timeframes[i].tf = tfs[i];
         timeframes[i].name = names[i];
         timeframes[i].secondsTotal = secs[i];
         timeframes[i].secondsRemaining = secs[i];
         timeframes[i].progressPercent = 0.0;
         timeframes[i].lastBarTime = 0;
         timeframes[i].rsiVal = 50.0;
         timeframes[i].atrVal = 0.0;
         timeframes[i].bias = "NEUTRAL";
         timeframes[i].timerStr = "00:00";
      }
   }

   void InitHandles()
   {
      for(int i = 0; i < 8; i++)
      {
         m_rsiHandles[i] = iRSI(m_symbol, timeframes[i].tf, 14, PRICE_CLOSE);
         m_atrHandles[i] = iATR(m_symbol, timeframes[i].tf, 14);
      }
   }

   void Update(double tickVolume, double bid, double ask)
   {
      m_lastTickTime = TimeCurrent();

      // Real Tick Volume Delta estimation
      double spread = ask - bid;
      if(spread > 0)
      {
         double close = SymbolInfoDouble(m_symbol, SYMBOL_LAST);
         if (close == 0) close = bid;
         double mid = (bid + ask) / 2.0;
         double pct = (close - mid) / (spread);
         if(pct > 1.0) pct = 1.0;
         if(pct < -1.0) pct = -1.0;
         m_cumDelta += tickVolume * pct;
      }

      // Update remaining timers and bar state
      for(int i = 0; i < 8; i++)
      {
         datetime barTime = iSeriesTime(m_symbol, timeframes[i].tf, 0);
         if(barTime != timeframes[i].lastBarTime)
         {
            timeframes[i].lastBarTime = barTime;
         }

         datetime curTime = TimeCurrent();
         int elapsed = (int)(curTime - barTime);
         if(elapsed < 0) elapsed = 0;

         int totalSecs = timeframes[i].secondsTotal;
         if(timeframes[i].tf == PERIOD_W1)
         {
            MqlDateTime dt;
            TimeToStruct(curTime, dt);
            elapsed = dt.day_of_week * 86400 + dt.hour * 3600 + dt.min * 60 + dt.sec;
         }
         else if(timeframes[i].tf == PERIOD_MN1)
         {
            MqlDateTime dt;
            TimeToStruct(curTime, dt);
            elapsed = (dt.day - 1) * 86400 + dt.hour * 3600 + dt.min * 60 + dt.sec;
         }

         int remaining = totalSecs - elapsed;
         if(remaining < 0) remaining = 0;

         timeframes[i].secondsRemaining = remaining;
         timeframes[i].progressPercent = 100.0 * (double)(totalSecs - remaining) / (double)totalSecs;
         if(timeframes[i].progressPercent > 100.0) timeframes[i].progressPercent = 100.0;
         if(timeframes[i].progressPercent < 0.0) timeframes[i].progressPercent = 0.0;

         // Format timer string
         int hrs = remaining / 3600;
         int mins = (remaining % 3600) / 60;
         int secsVal = remaining % 60;

         if(hrs > 0)
            timeframes[i].timerStr = StringFormat("%02dh:%02dm:%02ds", hrs, mins, secsVal);
         else
            timeframes[i].timerStr = StringFormat("%02dm:%02ds", mins, secsVal);

         UpdateTechnicalIndicators(i);
      }

      DetectSMC();
   }

   void UpdateTechnicalIndicators(int index)
   {
      int handleRSI = m_rsiHandles[index];
      if(handleRSI != INVALID_HANDLE)
      {
         double rsiBuf[1];
         if(CopyBuffer(handleRSI, 0, 0, 1, rsiBuf) > 0)
         {
            timeframes[index].rsiVal = rsiBuf[0];
         }
      }

      int handleATR = m_atrHandles[index];
      if(handleATR != INVALID_HANDLE)
      {
         double atrBuf[1];
         if(CopyBuffer(handleATR, 0, 0, 1, atrBuf) > 0)
         {
            timeframes[index].atrVal = atrBuf[0];
         }
      }

      // Determine Bias
      if(timeframes[index].rsiVal > 55)
         timeframes[index].bias = "BULLISH";
      else if(timeframes[index].rsiVal < 45)
         timeframes[index].bias = "BEARISH";
      else
         timeframes[index].bias = "NEUTRAL";
   }

   void DetectSMC()
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, PERIOD_H1, 0, 10, rates);
      if(copied < 10) return;

      ArrayResize(m_fvgList, 0);
      ArrayResize(m_obList, 0);

      for(int i = 1; i < copied - 1; i++)
      {
         if(rates[i-1].low > rates[i+1].high && rates[i].close > rates[i].open)
         {
            FVG fvg;
            fvg.top = rates[i-1].low;
            fvg.bottom = rates[i+1].high;
            fvg.isBullish = true;
            fvg.isMitigated = false;
            int size = ArraySize(m_fvgList);
            ArrayResize(m_fvgList, size + 1);
            m_fvgList[size] = fvg;
         }
         else if(rates[i-1].high < rates[i+1].low && rates[i].close < rates[i].open)
         {
            FVG fvg;
            fvg.top = rates[i+1].low;
            fvg.bottom = rates[i-1].high;
            fvg.isBullish = false;
            fvg.isMitigated = false;
            int size = ArraySize(m_fvgList);
            ArrayResize(m_fvgList, size + 1);
            m_fvgList[size] = fvg;
         }
      }

      for(int i = 2; i < copied - 1; i++)
      {
         if(rates[i-1].close < rates[i-1].open && rates[i].close > rates[i].open && rates[i].close > rates[i-1].high)
         {
            OrderBlock ob;
            ob.top = rates[i-1].high;
            ob.bottom = rates[i-1].low;
            ob.isBullish = true;
            ob.isMitigated = false;
            int size = ArraySize(m_obList);
            ArrayResize(m_obList, size + 1);
            m_obList[size] = ob;
         }
         if(rates[i-1].close > rates[i-1].open && rates[i].close < rates[i].open && rates[i].close < rates[i-1].low)
         {
            OrderBlock ob;
            ob.top = rates[i-1].high;
            ob.bottom = rates[i-1].low;
            ob.isBullish = false;
            ob.isMitigated = false;
            int size = ArraySize(m_obList);
            ArrayResize(m_obList, size + 1);
            m_obList[size] = ob;
         }
      }
   }

   double GetCumulativeDelta() { return m_cumDelta; }
   int GetFVGCount() { return ArraySize(m_fvgList); }
   int GetOBCount() { return ArraySize(m_obList); }

   double GetATR(ENUM_TIMEFRAMES tf)
   {
      for(int i=0; i<8; i++)
         if(timeframes[i].tf == tf) return timeframes[i].atrVal;
      return 0.0;
   }

   string GetCurrentSession()
   {
      datetime cur = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(cur, dt);
      int hour = dt.hour;

      if(hour >= 8 && hour < 16) return "LONDON";
      if(hour >= 13 && hour < 21) return "NEW YORK";
      if(hour >= 0 && hour < 8) return "TOKYO";
      return "SYDNEY";
   }

   datetime iSeriesTime(string symbol, ENUM_TIMEFRAMES tf, int index)
   {
      datetime t[1];
      if(CopyTime(symbol, tf, index, 1, t) > 0)
         return t[0];
      return 0;
   }
};
