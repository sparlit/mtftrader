//+------------------------------------------------------------------+
//|                                                  MarketBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include "Common.mqh"

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

class CMarketBrain
{
private:
   string m_symbol;
   datetime m_lastTickTime;
   double m_cumDelta;

   // Handle arrays for static reuse
   int m_rsiHandles[ITIP_TF_COUNT];
   int m_atrHandles[ITIP_TF_COUNT];

   // Order Blocks and FVG lists
   PriceZone m_obList[];
   PriceZone m_fvgList[];

public:
   TFData timeframes[ITIP_TF_COUNT];

   CMarketBrain()
   {
      m_symbol = _Symbol;
      m_cumDelta = 0.0;
      InitTimeframes();
      InitHandles();
   }

   ~CMarketBrain()
   {
      for(int i = 0; i < ITIP_TF_COUNT; i++)
      {
         if(m_rsiHandles[i] != INVALID_HANDLE) IndicatorRelease(m_rsiHandles[i]);
         if(m_atrHandles[i] != INVALID_HANDLE) IndicatorRelease(m_atrHandles[i]);
      }
   }

   void InitTimeframes()
   {
      ENUM_TIMEFRAMES tfs[ITIP_TF_COUNT] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
      string names[ITIP_TF_COUNT] = {"M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
      int secs[ITIP_TF_COUNT] = {300, 900, 1800, 3600, 14400, 86400, 604800, 2592000};

      for(int i = 0; i < ITIP_TF_COUNT; i++)
      {
         timeframes[i].tf = tfs[i];
         timeframes[i].name = names[i];
         timeframes[i].secondsTotal = secs[i];
         timeframes[i].secondsRemaining = secs[i];
         timeframes[i].progressPercent = 0.0;
         timeframes[i].lastBarTime = 0;
         timeframes[i].rsiVal = 50.0;
         timeframes[i].atrVal = 0.0;
         timeframes[i].bias = ITIP_BIAS_NEUTRAL;
         timeframes[i].timerStr = "00:00";
      }
   }

   void InitHandles()
   {
      for(int i = 0; i < ITIP_TF_COUNT; i++)
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
         double pct = ClampDouble((close - mid) / spread, -1.0, 1.0);
         m_cumDelta += tickVolume * pct;
      }

      // Update remaining timers and bar state
      for(int i = 0; i < ITIP_TF_COUNT; i++)
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
         timeframes[i].progressPercent = ClampDouble(100.0 * (double)(totalSecs - remaining) / (double)totalSecs, 0.0, 100.0);
         timeframes[i].timerStr = FormatCountdown(remaining);

         UpdateTechnicalIndicators(i);
      }

      DetectSMC();
   }

   void UpdateTechnicalIndicators(int index)
   {
      ReadIndicatorValue(m_rsiHandles[index], timeframes[index].rsiVal);
      ReadIndicatorValue(m_atrHandles[index], timeframes[index].atrVal);

      timeframes[index].bias = BiasFromRSI(timeframes[index].rsiVal);
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
            PriceZone fvg = MakePriceZone(rates[i-1].low, rates[i+1].high, true);
            ArrayAppend(m_fvgList, fvg);
         }
         else if(rates[i-1].high < rates[i+1].low && rates[i].close < rates[i].open)
         {
            PriceZone fvg = MakePriceZone(rates[i+1].low, rates[i-1].high, false);
            ArrayAppend(m_fvgList, fvg);
         }
      }

      for(int i = 2; i < copied - 1; i++)
      {
         if(rates[i-1].close < rates[i-1].open && rates[i].close > rates[i].open && rates[i].close > rates[i-1].high)
         {
            PriceZone ob = MakePriceZone(rates[i-1].high, rates[i-1].low, true);
            ArrayAppend(m_obList, ob);
         }
         if(rates[i-1].close > rates[i-1].open && rates[i].close < rates[i].open && rates[i].close < rates[i-1].low)
         {
            PriceZone ob = MakePriceZone(rates[i-1].high, rates[i-1].low, false);
            ArrayAppend(m_obList, ob);
         }
      }
   }

   double GetCumulativeDelta() { return m_cumDelta; }
   int GetFVGCount() { return ArraySize(m_fvgList); }
   int GetOBCount() { return ArraySize(m_obList); }

   double GetATR(ENUM_TIMEFRAMES tf)
   {
      for(int i=0; i<ITIP_TF_COUNT; i++)
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
