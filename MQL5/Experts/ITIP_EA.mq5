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
   g_infrastructure = new CInfrastructureBrain(ZmqHost, ZmqPort);

   // Draw Panel Layout
   g_dashboard.DrawPanel();

   // Set timer for sub-second calculations and progress bar updates
   EventSetTimer(1);

   Print("ITIP Platform successfully initialized and integrated on ", _Symbol);
   return(INIT_SUCCEEDED);
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
   double lastVolume = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   g_market.Update(lastVolume, bid, ask);

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
               g_infrastructure.SendSignal(_Symbol, "H1", "BUY", g_aiConfidence, g_market.GetCurrentSession(), atr, g_market.timeframes[3].rsiVal);
            }
         }
      }
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
               g_infrastructure.SendSignal(_Symbol, "H1", "SELL", g_aiConfidence, g_market.GetCurrentSession(), atr, g_market.timeframes[3].rsiVal);
            }
         }
      }
   }
   else
   {
      g_lastSignalStr = "NEUTRAL (CONFLUENCE SEARCHING)";
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Redraw timers and elements every second for fluid real-time responsiveness
   double lastVolume = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   g_market.Update(lastVolume, bid, ask);

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
      string prefix = "ITIP_DB_";
      if(sparam == prefix + "BtnBuy")
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(150, atr);
         if(size > 0) g_execution.ExecuteBuy(size, 0, 0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnSell")
      {
         double atr = g_market.GetATR(PERIOD_H1);
         double size = g_risk.CalculatePositionSize(150, atr);
         if(size > 0) g_execution.ExecuteSell(size, 0, 0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnClose")
      {
         g_execution.CloseAllPositions();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnPart")
      {
         g_execution.PartialClosePositions(50.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "BtnBE")
      {
         g_execution.AutoTrailingAndBreakeven();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Dispatch Alerts                                                  |
//+------------------------------------------------------------------+
void TriggerAlerts(string message)
{
   if(PlayAudioAlerts) PlaySound("alert.wav");
   if(SendPushAlerts) SendNotification(message);
   if(SendEmailAlerts) SendMail("ITIP Trading Intel", message);
   Print("ITIP ALERT: ", message);
}
