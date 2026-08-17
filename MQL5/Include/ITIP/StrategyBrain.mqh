//+------------------------------------------------------------------+
//|                                                StrategyBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include "MarketBrain.mqh"

enum ENUM_SIGNAL
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};

class CStrategyBrain
{
private:
   string m_symbol;
   ENUM_SIGNAL m_lastSignal;
   datetime m_lastSignalTime;
   int m_persistenceCount;
   int m_requiredPersistence;

public:
   CStrategyBrain()
   {
      m_symbol = _Symbol;
      m_lastSignal = SIGNAL_NONE;
      m_lastSignalTime = 0;
      m_persistenceCount = 0;
      m_requiredPersistence = 3; // Persistence factor (anti-whiplash)
   }

   ~CStrategyBrain() {}

   ENUM_SIGNAL Evaluate(CMarketBrain &market, double &outConfidence)
   {
      // Confluence factors
      int bullishCount = 0;
      int bearishCount = 0;
      int tfChecked = 0;

      for(int i = 0; i < ITIP_TF_COUNT; i++)
      {
         string bias = BiasFromRSI(market.timeframes[i].rsiVal);
         if(bias == ITIP_BIAS_BULLISH) bullishCount++;
         else if(bias == ITIP_BIAS_BEARISH) bearishCount++;
         tfChecked++;
      }

      // Volatility check
      double atr = market.GetATR(PERIOD_H1);
      double currentSpread = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // If spread exceeds ATR, volatility filter is triggered (no trade)
      if(atr > 0 && currentSpread > atr * 0.5)
      {
         outConfidence = 0.0;
         return SIGNAL_NONE;
      }

      // Bayesian score calculation
      double score = (double)(bullishCount - bearishCount) / (double)tfChecked;
      outConfidence = MathAbs(score) * 100.0;

      ENUM_SIGNAL rawSignal = SIGNAL_NONE;
      if(score >= 0.5) rawSignal = SIGNAL_BUY;
      else if(score <= -0.5) rawSignal = SIGNAL_SELL;

      // Persistence filter (Anti-Whiplash mechanism)
      if(rawSignal != SIGNAL_NONE && rawSignal == m_lastSignal)
      {
         m_persistenceCount++;
      }
      else
      {
         m_persistenceCount = 0;
         m_lastSignal = rawSignal;
      }

      if(m_persistenceCount >= m_requiredPersistence)
      {
         return rawSignal;
      }

      return SIGNAL_NONE;
   }

   bool DetectDivergence(CMarketBrain &market, string &outDetails)
   {
      // Fast check for price vs RSI divergence on M15
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, PERIOD_M15, 0, 5, rates);
      if(copied < 5) return false;

      int handle = iRSI(m_symbol, PERIOD_M15, 14, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;

      double rsiBuf[];
      ArraySetAsSeries(rsiBuf, true);
      int copiedRsi = CopyBuffer(handle, 0, 0, 5, rsiBuf);
      IndicatorRelease(handle);
      if(copiedRsi < 5) return false;

      // Classic Bullish Divergence: Price Lower Low vs RSI Higher Low
      if(rates[0].low < rates[4].low && rsiBuf[0] > rsiBuf[4] && rsiBuf[0] < 35)
      {
         outDetails = "Bullish RSI Divergence (M15)";
         return true;
      }
      // Classic Bearish Divergence: Price Higher High vs RSI Lower High
      if(rates[0].high > rates[4].high && rsiBuf[0] < rsiBuf[4] && rsiBuf[0] > 65)
      {
         outDetails = "Bearish RSI Divergence (M15)";
         return true;
      }

      return false;
   }
};
