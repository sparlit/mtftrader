//+------------------------------------------------------------------+
//|                                                      ITIP_EA.mq5 |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"
#property description "Institutional Trading Intelligence Platform (ITIP) v1.0"

#include "../Include/ITIP/MarketBrain.mqh"
#include "../Include/ITIP/StrategyBrain.mqh"
#include "../Include/ITIP/RiskBrain.mqh"
#include "../Include/ITIP/ExecutionBrain.mqh"
#include "../Include/ITIP/DashboardBrain.mqh"
#include "../Include/ITIP/InfrastructureBrain.mqh"

// Inputs
input double   RiskPercent = 2.0;       // Max Account Risk Percent
input double   DrawdownLimit = 5.0;     // Daily Max Drawdown Circuit Breaker
input string   ZmqHost = "localhost";   // python API bridge endpoint
input int      ZmqPort = 5555;          // Fast API bridge port
input string   ApiKey = "";              // Backend API key (set if ITIP_API_KEY enabled)
input bool     PlayAudioAlerts = true;  // Enable synthesizer sound alerts
input bool     SendPushAlerts = false;  // Enable mobile app push alerts
input bool     SendEmailAlerts = false; // Enable email notification alerts

// Global Objects
CMarketBrain          *g_market;
CStrategyBrain        *g_strategy;
CRiskBrain            *g_risk;
CExecutionBrain       *g_execution;
CDashboardBrain       *g_dashboard;
CInfrastructureBrain  *g_infrastructure;

double           g_aiConfidence = 0.0;
string           g_lastSignalStr = "NEUTRAL";
string           g_divDetails = "No Divergence Detected";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_market = new CMarketBrain();
   g_strategy = new CStrategyBrain();
   g_risk = new CRiskBrain();
   g_execution = new CExecutionBrain();
   g_dashboard = new CDashboardBrain();
   g_infrastructure = new CInfrastructureBrain(ZmqHost, ZmqPort, ApiKey);

   if(!BrainsAvailable())
   {
      Print("ITIP Platform: Failed to allocate one or more brains; aborting initialization.");
      return(INIT_FAILED);
   }

   if(!g_market.IsReady())
   {
      Print("ITIP Platform: Market indicator handles could not be created; aborting initialization.");
      return(INIT_FAILED);
   }

   // Draw Panel Layout
   g_dashboard.DrawPanel();

   // Set timer for sub-second calculations and progress bar updates
   if(!EventSetTimer(1))
   {
      PrintFormat("ITIP Platform: EventSetTimer failed (error %d); dashboard countdowns would never refresh.", GetLastError());
      return(INIT_FAILED);
   }

   Print("ITIP Platform successfully initialized and integrated on ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| True only when every brain was allocated                         |
//+------------------------------------------------------------------+
bool BrainsAvailable()
{
   return CheckPointer(g_market) != POINTER_INVALID
       && CheckPointer(g_strategy) != POINTER_INVALID
       && CheckPointer(g_risk) != POINTER_INVALID
       && CheckPointer(g_execution) != POINTER_INVALID
       && CheckPointer(g_dashboard) != POINTER_INVALID
       && CheckPointer(g_infrastructure) != POINTER_INVALID;
}

//+------------------------------------------------------------------+
//| Current bid/ask, false when the terminal has no usable quote     |
//+------------------------------------------------------------------+
bool CurrentQuote(double &bid, double &ask)
{
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      PrintFormat("ITIP Platform: Unusable quote for %s (bid %.5f, ask %.5f); skipping this cycle.", _Symbol, bid, ask);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(CheckPointer(g_market) != POINTER_INVALID) delete g_market;
   if(CheckPointer(g_strategy) != POINTER_INVALID) delete g_strategy;
   if(CheckPointer(g_risk) != POINTER_INVALID) delete g_risk;
   if(CheckPointer(g_execution) != POINTER_INVALID) delete g_execution;
   if(CheckPointer(g_dashboard) != POINTER_INVALID) delete g_dashboard;
   if(CheckPointer(g_infrastructure) != POINTER_INVALID) delete g_infrastructure;

   Print("ITIP Platform deinitialized successfully.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!BrainsAvailable()) return;

   double bid, ask;
   if(!CurrentQuote(bid, ask)) return;

   double lastVolume = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);

   g_market.Update(lastVolume, bid, ask);
   double bid, ask;
   RefreshMarket(bid, ask);

   // Active Divergence Scanner
   if(g_strategy.DetectDivergence(*g_market, g_divDetails))
   {
      Print("ITIP Market Scanner: ", g_divDetails);
   }

   ENUM_SIGNAL signal = g_strategy.Evaluate(*g_market, g_aiConfidence);

   if(signal == SIGNAL_BUY)
   {
      g_lastSignalStr = "BULLISH SIGNAL";
      if(g_risk.AllowTrade())
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(200, atr);
         if(size > 0)
         {
            double sl = bid - (atr * 2.0);
            double tp = ask + (atr * 4.0);
            if(g_execution.ExecuteBuy(size, sl, tp))
            {
               TriggerAlerts("ITIP Buy Alert: Target Entry triggered!");
               if(!g_infrastructure.SendSignal(_Symbol, "H1", "BUY", g_aiConfidence, g_market.GetCurrentSession(), atr, g_market.timeframes[3].rsiVal))
                  Print("ITIP Platform: Buy executed but the analytics backend did not record the signal.");
            }
            else
            {
               Print("ITIP Platform: Buy signal was not executed by the broker; see ExecutionBrain retcode above.");
            }
         }
      }
      TryEnter(true, bid, ask);
   }
   else if(signal == SIGNAL_SELL)
   {
      g_lastSignalStr = "BEARISH SIGNAL";
      if(g_risk.AllowTrade())
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(200, atr);
         if(size > 0)
         {
            double sl = ask + (atr * 2.0);
            double tp = bid - (atr * 4.0);
            if(g_execution.ExecuteSell(size, sl, tp))
            {
               TriggerAlerts("ITIP Sell Alert: Target Entry triggered!");
               if(!g_infrastructure.SendSignal(_Symbol, "H1", "SELL", g_aiConfidence, g_market.GetCurrentSession(), atr, g_market.timeframes[3].rsiVal))
                  Print("ITIP Platform: Sell executed but the analytics backend did not record the signal.");
            }
            else
            {
               Print("ITIP Platform: Sell signal was not executed by the broker; see ExecutionBrain retcode above.");
            }
         }
      }
      TryEnter(false, bid, ask);
   }
   else
   {
      g_lastSignalStr = "NEUTRAL (CONFLUENCE SEARCHING)";
   }
}

//+------------------------------------------------------------------+
//| Pushes the latest quote into the market brain                    |
//+------------------------------------------------------------------+
void RefreshMarket(double &bid, double &ask)
{
   if(!BrainsAvailable()) return;

   // Redraw timers and elements every second for fluid real-time responsiveness
   double bid, ask;
   if(!CurrentQuote(bid, ask)) return;

   double lastVolume = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
   double lastVolume = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   g_market.Update(lastVolume, bid, ask);
}

//+------------------------------------------------------------------+
//| Risk-checked ATR based entry in the given direction              |
//+------------------------------------------------------------------+
void TryEnter(bool isBuy, double bid, double ask)
{
   if(!g_risk.AllowTrade()) return;

   double atr = g_market.GetATR(PERIOD_H1);
   double size = g_risk.CalculatePositionSize(200, atr);
   if(size <= 0) return;

   double sl = isBuy ? bid - (atr * 2.0) : ask + (atr * 2.0);
   double tp = isBuy ? ask + (atr * 4.0) : bid - (atr * 4.0);

   bool executed = isBuy ? g_execution.ExecuteBuy(size, sl, tp)
                         : g_execution.ExecuteSell(size, sl, tp);
   if(!executed) return;

   string direction = isBuy ? "BUY" : "SELL";
   TriggerAlerts(StringFormat("ITIP %s Alert: Target Entry triggered!", isBuy ? "Buy" : "Sell"));
   g_infrastructure.SendSignal(_Symbol, "H1", direction, g_aiConfidence, g_market.GetCurrentSession(), atr, g_market.timeframes[3].rsiVal);
}

//+------------------------------------------------------------------+
//| Manual (dashboard button) market order without SL/TP             |
//+------------------------------------------------------------------+
void ManualEntry(bool isBuy)
{
   double atr = g_market.GetATR(PERIOD_H1);
   double size = g_risk.CalculatePositionSize(150, atr);
   if(size <= 0) return;

   if(isBuy) g_execution.ExecuteBuy(size, 0, 0);
   else      g_execution.ExecuteSell(size, 0, 0);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Redraw timers and elements every second for fluid real-time responsiveness
   double bid, ask;
   RefreshMarket(bid, ask);

   string finalStatus = g_lastSignalStr;
   if(g_divDetails != "No Divergence Detected")
   {
      finalStatus = StringFormat("%s | %s", g_lastSignalStr, g_divDetails);
   }

   g_dashboard.UpdateDashboard(*g_market, g_aiConfidence, finalStatus);
}

//+------------------------------------------------------------------+
//| ChartEvent function for interactive buttons                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(!BrainsAvailable()) return;

      string prefix = "ITIP_DB_";
      if(sparam == prefix + "BtnBuy")
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(150, atr);
         if(size > 0)
            g_execution.ExecuteBuy(size, 0, 0);
         else
            Print("ITIP Platform: Manual BUY rejected, RiskBrain returned no tradeable size.");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnSell")
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(150, atr);
         if(size > 0)
            g_execution.ExecuteSell(size, 0, 0);
         else
            Print("ITIP Platform: Manual SELL rejected, RiskBrain returned no tradeable size.");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnClose")
      {
         if(!g_execution.CloseAllPositions())
            Print("ITIP Platform: Manual CLOSE ALL did not close every position; see ExecutionBrain retcodes above.");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnPart")
      {
         if(!g_execution.PartialClosePositions(50.0))
            Print("ITIP Platform: Manual PARTIAL CLOSE did not complete for every position; see ExecutionBrain retcodes above.");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnBE")
      {
         g_execution.AutoTrailingAndBreakeven();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
   }
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   string prefix = "ITIP_DB_";
   if(StringFind(sparam, prefix) != 0) return;

   string button = StringSubstr(sparam, StringLen(prefix));

   if(button == "BtnBuy")       ManualEntry(true);
   else if(button == "BtnSell") ManualEntry(false);
   else if(button == "BtnClose") g_execution.CloseAllPositions();
   else if(button == "BtnPart")  g_execution.PartialClosePositions(50.0);
   else if(button == "BtnBE")    g_execution.AutoTrailingAndBreakeven();
   else return;

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Dispatch Alerts                                                  |
//+------------------------------------------------------------------+
void TriggerAlerts(string message)
{
   if(PlayAudioAlerts && !PlaySound("alert.wav"))
      PrintFormat("ITIP Platform: PlaySound failed (error %d).", GetLastError());

   if(SendPushAlerts && !SendNotification(message))
      PrintFormat("ITIP Platform: Push notification failed (error %d); check MetaQuotes ID in Terminal Settings.", GetLastError());

   if(SendEmailAlerts && !SendMail("ITIP Trading Intel", message))
      PrintFormat("ITIP Platform: Email alert failed (error %d); check SMTP settings in the Terminal.", GetLastError());

   Print("ITIP ALERT: ", message);
}
