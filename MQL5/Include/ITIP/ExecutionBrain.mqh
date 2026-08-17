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

   void LogTradeFailure(string operation, ulong ticket)
   {
      PrintFormat("ExecutionBrain: %s failed for ticket %I64u. Retcode %u (%s), broker comment: %s",
                  operation, ticket, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription(), m_trade.ResultComment());
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
      if(!m_trade.Buy(lots, m_symbol, 0, sl, tp, "ITIP AI Buy Order"))
      {
         LogTradeFailure("Buy", 0);
         return false;
      }
      return true;
   }

   bool ExecuteSell(double lots, double sl, double tp)
   {
      if(!m_trade.Sell(lots, m_symbol, 0, sl, tp, "ITIP AI Sell Order"))
      {
         LogTradeFailure("Sell", 0);
         return false;
      }
      return true;
   }

   // Returns true only when every matching position was closed.
   bool CloseAllPositions()
   {
      CPositionInfo pos;
      bool allClosed = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!pos.SelectByIndex(i))
         {
            PrintFormat("ExecutionBrain: Could not select position at index %d (error %d).", i, GetLastError());
            allClosed = false;
            continue;
         }

         if(pos.Symbol() == m_symbol && pos.Magic() == m_magic)
         {
            if(!m_trade.PositionClose(pos.Ticket()))
            {
               LogTradeFailure("PositionClose", pos.Ticket());
               allClosed = false;
            }
         }
         if(!SelectOwn(pos, i)) continue;

         m_trade.PositionClose(pos.Ticket());
      }
      return allClosed;
   }

   // Returns true only when every matching position was partially closed.
   bool PartialClosePositions(double percent)
   {
      if(percent <= 0.0 || percent > 100.0)
      {
         PrintFormat("ExecutionBrain: Partial close rejected, percent must be within (0, 100], got %.2f.", percent);
         return false;
      }

      double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double minVol = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      if(step <= 0.0)
      {
         PrintFormat("ExecutionBrain: Invalid volume step %.5f reported for %s; cannot size a partial close.", step, m_symbol);
         return false;
      }

      CPositionInfo pos;
      bool allClosed = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!pos.SelectByIndex(i))
         {
            PrintFormat("ExecutionBrain: Could not select position at index %d (error %d).", i, GetLastError());
            allClosed = false;
            continue;
         }

         if(pos.Symbol() == m_symbol && pos.Magic() == m_magic)
         {
            double closeVol = pos.Volume() * (percent / 100.0);
            closeVol = MathRound(closeVol / step) * step;
            if(closeVol < minVol)
            {
               PrintFormat("ExecutionBrain: Skipping partial close of ticket %I64u, %.2f%% of %.2f lots rounds to %.2f which is below the %.2f minimum.",
                           pos.Ticket(), percent, pos.Volume(), closeVol, minVol);
               continue;
            }

            if(!m_trade.PositionClosePartial(pos.Ticket(), closeVol))
            {
               LogTradeFailure("PositionClosePartial", pos.Ticket());
               allClosed = false;
            }
         if(!SelectOwn(pos, i)) continue;

         double closeVol = pos.Volume() * (percent / 100.0);
         double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         closeVol = MathRound(closeVol / step) * step;
         if(closeVol >= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         {
            m_trade.PositionClosePartial(pos.Ticket(), closeVol);
         }
      }
      return allClosed;
   }

   void AutoTrailingAndBreakeven()
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0.0)
      {
         PrintFormat("ExecutionBrain: Invalid point size %.8f reported for %s; skipping breakeven pass.", point, m_symbol);
         return;
      }

      CPositionInfo pos;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!pos.SelectByIndex(i))
         {
            PrintFormat("ExecutionBrain: Could not select position at index %d (error %d).", i, GetLastError());
            continue;
         }

         if(pos.Symbol() == m_symbol && pos.Magic() == m_magic)
         {
            double price = pos.PriceCurrent();
            double open = pos.PriceOpen();
            double sl = pos.StopLoss();

            // Breakeven logic: if profit is more than 30 points, move SL to open
            if(pos.PositionType() == POSITION_TYPE_BUY)
            {
               if(price - open > 30 * point && sl < open)
               {
                  if(!m_trade.PositionModify(pos.Ticket(), open + 2 * point, pos.TakeProfit()))
                     LogTradeFailure("PositionModify (breakeven buy)", pos.Ticket());
               }
            }
            else if(pos.PositionType() == POSITION_TYPE_SELL)
            {
               if(open - price > 30 * point && (sl > open || sl == 0))
               {
                  if(!m_trade.PositionModify(pos.Ticket(), open - 2 * point, pos.TakeProfit()))
                     LogTradeFailure("PositionModify (breakeven sell)", pos.Ticket());
               }
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
