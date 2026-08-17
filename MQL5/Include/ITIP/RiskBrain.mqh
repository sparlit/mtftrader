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

   void SetRiskParameters(double maxRiskPercent, double maxDrawdownLimit)
   {
      if(maxRiskPercent > 0.0) m_maxRiskPercent = maxRiskPercent;
      if(maxDrawdownLimit > 0.0) m_maxDrawdownLimit = maxDrawdownLimit;
   }

   double CurrentDrawdownPercent()
   {
      CAccountInfo account;
      double balance = account.Balance();
      if(balance <= 0.0) return 100.0;

      double equity = account.Equity();
      return (balance - equity) / balance * 100.0;
   }

   double CalculatePositionSize(double slPoints, double atr)
   {
      CAccountInfo account;
      double balance = account.Balance();
      if(balance <= 0.0) return 0.0;

      // Drawdown Circuit Breaker
      double dd = CurrentDrawdownPercent();
      m_dailyDrawdown = dd;
      if(dd >= m_maxDrawdownLimit)
      {
         Print("RiskBrain: Drawdown Circuit Breaker Triggered!");
         return 0.0;
      }

      if(slPoints <= 0)
      {
         // Fallback using ATR
         slPoints = atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      }

      if(slPoints <= 0) return 0.01;

      double riskVal = balance * (m_maxRiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(tickSize == 0 || tickValue == 0) return 0.01;

      double lotSize = (riskVal / (slPoints * (tickValue * (point / tickSize))));

      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      if(stepLot > 0.0) lotSize = MathFloor(lotSize / stepLot) * stepLot;

      if(lotSize < minLot) lotSize = minLot;
      if(lotSize > maxLot) lotSize = maxLot;

      return lotSize;
   }

   bool AllowTrade()
   {
      m_dailyDrawdown = CurrentDrawdownPercent();
      return (m_dailyDrawdown < m_maxDrawdownLimit);
   }

   double GetMaxRisk() { return m_maxRiskPercent; }
   double GetCircuitBreaker() { return m_maxDrawdownLimit; }
   double GetDailyDrawdown() { return m_dailyDrawdown; }
};
