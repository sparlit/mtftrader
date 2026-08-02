//+------------------------------------------------------------------+
//|                                               ExecutionBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "Common.mqh"

class CExecutionBrain
{
private:
   CTrade m_trade;
   string m_symbol;
   ulong m_magic;

   bool SelectOwn(CPositionInfo &pos, int index)
   {
      return SelectOwnedPosition(pos, index, m_symbol, m_magic);
   }

public:
   CExecutionBrain()
   {
      m_symbol = _Symbol;
      m_magic = 8888111;
      m_trade.SetExpertMagicNumber(m_magic);
   }

   ~CExecutionBrain() {}

   bool ExecuteBuy(double lots, double sl, double tp)
   {
      return m_trade.Buy(lots, m_symbol, 0, sl, tp, "ITIP AI Buy Order");
   }

   bool ExecuteSell(double lots, double sl, double tp)
   {
      return m_trade.Sell(lots, m_symbol, 0, sl, tp, "ITIP AI Sell Order");
   }

   void CloseAllPositions()
   {
      CPositionInfo pos;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!SelectOwn(pos, i)) continue;

         m_trade.PositionClose(pos.Ticket());
      }
   }

   void PartialClosePositions(double percent)
   {
      CPositionInfo pos;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!SelectOwn(pos, i)) continue;

         double closeVol = pos.Volume() * (percent / 100.0);
         double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         closeVol = MathRound(closeVol / step) * step;
         if(closeVol >= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         {
            m_trade.PositionClosePartial(pos.Ticket(), closeVol);
         }
      }
   }

   void AutoTrailingAndBreakeven()
   {
      CPositionInfo pos;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!SelectOwn(pos, i)) continue;

         double price = pos.PriceCurrent();
         double open = pos.PriceOpen();
         double sl = pos.StopLoss();
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

         // Breakeven logic: if profit is more than 30 points, move SL to open
         if(pos.PositionType() == POSITION_TYPE_BUY)
         {
            if(price - open > 30 * point && sl < open)
            {
               m_trade.PositionModify(pos.Ticket(), open + 2 * point, pos.TakeProfit());
            }
         }
         else if(pos.PositionType() == POSITION_TYPE_SELL)
         {
            if(open - price > 30 * point && (sl > open || sl == 0))
            {
               m_trade.PositionModify(pos.Ticket(), open - 2 * point, pos.TakeProfit());
            }
         }
      }
   }
};
