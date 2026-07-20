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

   double CalculatePositionSize(double slPoints, double atr)
   {
      CAccountInfo account;
      double balance = account.Balance();
      double equity = account.Equity();

      // Drawdown Circuit Breaker
      double dd = (balance - equity) / balance * 100.0;
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
      double dd = (balance - equity) / balance * 100.0;
      return (dd < m_maxDrawdownLimit);
   }

   double GetMaxRisk() { return m_maxRiskPercent; }
   double GetCircuitBreaker() { return m_maxDrawdownLimit; }
};
