//+------------------------------------------------------------------+
//|                                                       Common.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

#ifndef ITIP_COMMON_MQH
#define ITIP_COMMON_MQH

#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>

// Number of timeframes tracked across the platform
#define ITIP_TF_COUNT 8

// RSI thresholds shared by market bias, confluence scoring and dashboard colors
#define ITIP_RSI_BULL 55.0
#define ITIP_RSI_BEAR 45.0

// Bias labels
#define ITIP_BIAS_BULLISH "BULLISH"
#define ITIP_BIAS_BEARISH "BEARISH"
#define ITIP_BIAS_NEUTRAL "NEUTRAL"

// Generic price zone used for Order Blocks and Fair Value Gaps
struct PriceZone
{
   double top;
   double bottom;
   bool   isBullish;
   bool   isMitigated;
};

//+------------------------------------------------------------------+
//| Appends a value to a dynamic array                               |
//+------------------------------------------------------------------+
template<typename T>
void ArrayAppend(T &array[], T &value)
{
   int size = ArraySize(array);
   ArrayResize(array, size + 1);
   array[size] = value;
}

//+------------------------------------------------------------------+
//| Builds a price zone                                              |
//+------------------------------------------------------------------+
PriceZone MakePriceZone(double top, double bottom, bool isBullish)
{
   PriceZone zone;
   zone.top = top;
   zone.bottom = bottom;
   zone.isBullish = isBullish;
   zone.isMitigated = false;
   return zone;
}

//+------------------------------------------------------------------+
//| Clamps a value into [minValue, maxValue]                         |
//+------------------------------------------------------------------+
double ClampDouble(double value, double minValue, double maxValue)
{
   if(value < minValue) return minValue;
   if(value > maxValue) return maxValue;
   return value;
}

//+------------------------------------------------------------------+
//| Reads the latest value of an indicator buffer                    |
//+------------------------------------------------------------------+
bool ReadIndicatorValue(int handle, double &outValue, int bufferIndex = 0)
{
   if(handle == INVALID_HANDLE) return false;

   double buffer[1];
   if(CopyBuffer(handle, bufferIndex, 0, 1, buffer) <= 0) return false;

   outValue = buffer[0];
   return true;
}

//+------------------------------------------------------------------+
//| Maps an RSI reading onto a directional bias label                |
//+------------------------------------------------------------------+
string BiasFromRSI(double rsi)
{
   if(rsi > ITIP_RSI_BULL) return ITIP_BIAS_BULLISH;
   if(rsi < ITIP_RSI_BEAR) return ITIP_BIAS_BEARISH;
   return ITIP_BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Formats a remaining-seconds countdown as hh:mm:ss / mm:ss        |
//+------------------------------------------------------------------+
string FormatCountdown(int remainingSeconds)
{
   if(remainingSeconds < 0) remainingSeconds = 0;

   int hrs = remainingSeconds / 3600;
   int mins = (remainingSeconds % 3600) / 60;
   int secs = remainingSeconds % 60;

   if(hrs > 0) return StringFormat("%02dh:%02dm:%02ds", hrs, mins, secs);
   return StringFormat("%02dm:%02ds", mins, secs);
}

//+------------------------------------------------------------------+
//| Current account drawdown from balance to equity, in percent      |
//+------------------------------------------------------------------+
double AccountDrawdownPercent()
{
   CAccountInfo account;
   double balance = account.Balance();
   double equity = account.Equity();

   if(balance <= 0) return 0.0;
   return (balance - equity) / balance * 100.0;
}

//+------------------------------------------------------------------+
//| Selects position at index and checks it belongs to symbol/magic  |
//+------------------------------------------------------------------+
bool SelectOwnedPosition(CPositionInfo &pos, int index, string symbol, ulong magic)
{
   if(!pos.SelectByIndex(index)) return false;
   return (pos.Symbol() == symbol && pos.Magic() == magic);
}

#endif // ITIP_COMMON_MQH
