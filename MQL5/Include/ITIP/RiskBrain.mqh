//+------------------------------------------------------------------+
//|                                                    RiskBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include <Trade\AccountInfo.mqh>

class CRiskBrain
{
private:
   double m_maxRiskPercent;
   double m_maxDrawdownLimit;
   double m_dailyDrawdown;

public:
   CRiskBrain()
   {
      m_maxRiskPercent = 2.0;       // Max 2% risk per trade
      m_maxDrawdownLimit = 5.0;     // Daily 5% circuit breaker
      m_dailyDrawdown = 0.0;
   }

   ~CRiskBrain() {}

   // Returns 0.0 whenever a size cannot be trusted, so callers must treat 0.0 as "do not trade".
   double CalculatePositionSize(double slPoints, double atr)
   {
      CAccountInfo account;
      double balance = account.Balance();
      double equity = account.Equity();

      if(balance <= 0.0)
      {
         PrintFormat("RiskBrain: Account balance %.2f is not usable for sizing; refusing to trade.", balance);
         return 0.0;
      }

      // Drawdown Circuit Breaker
      double dd = (balance - equity) / balance * 100.0;
      if(dd >= m_maxDrawdownLimit)
      {
         PrintFormat("RiskBrain: Drawdown Circuit Breaker Triggered! Drawdown %.2f%% >= limit %.2f%%.", dd, m_maxDrawdownLimit);
         return 0.0;
      }

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
      {
         PrintFormat("RiskBrain: Invalid point size %.8f for %s; refusing to trade.", point, _Symbol);
         return 0.0;
      }

      if(slPoints <= 0)
      {
         // Fallback using ATR
         slPoints = atr / point;
      }

      if(slPoints <= 0)
      {
         PrintFormat("RiskBrain: No usable stop distance (slPoints=%.2f, atr=%.5f); refusing to trade.", slPoints, atr);
         return 0.0;
      }

      double riskVal = balance * (m_maxRiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickSize <= 0.0 || tickValue <= 0.0)
      {
         PrintFormat("RiskBrain: Broker reported unusable tick data for %s (tick size %.8f, tick value %.5f); refusing to trade.",
                     _Symbol, tickSize, tickValue);
         return 0.0;
      }

      double lotSize = (riskVal / (slPoints * (tickValue * (point / tickSize))));

      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      if(stepLot <= 0.0 || minLot <= 0.0 || maxLot < minLot)
      {
         PrintFormat("RiskBrain: Broker reported unusable volume limits for %s (min %.2f, max %.2f, step %.2f); refusing to trade.",
                     _Symbol, minLot, maxLot, stepLot);
         return 0.0;
      }

      lotSize = MathFloor(lotSize / stepLot) * stepLot;

      if(lotSize < minLot) lotSize = minLot;
      if(lotSize > maxLot) lotSize = maxLot;

      return lotSize;
   }

   bool AllowTrade()
   {
      CAccountInfo account;
      double balance = account.Balance();
      double equity = account.Equity();

      if(balance <= 0.0)
      {
         PrintFormat("RiskBrain: Account balance %.2f is not usable for a drawdown check; blocking trades.", balance);
         return false;
      }

      double dd = (balance - equity) / balance * 100.0;
      return (dd < m_maxDrawdownLimit);
   }

   double GetMaxRisk() { return m_maxRiskPercent; }
   double GetCircuitBreaker() { return m_maxDrawdownLimit; }
};
