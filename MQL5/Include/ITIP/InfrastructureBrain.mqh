//+------------------------------------------------------------------+
//|                                           InfrastructureBrain.mqh |
//|                                  Institutional Trading Platform  |
//|                                      https://github.com/mtftrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ITIP"
#property link      "https://github.com/mtftrader"
#property version   "1.00"

class CInfrastructureBrain
{
private:
   string m_url;

public:
   CInfrastructureBrain(string host, int port)
   {
      m_url = StringFormat("http://%s:%d/api/signal", host, port);
   }

   ~CInfrastructureBrain() {}

   void SendSignal(string symbol, string timeframe, string direction, double confidence, string session, double atr, double rsi)
   {
      // Format payload using exact schema of fastapi SignalRequest
      string payload = StringFormat(
         "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"direction\":\"%s\",\"confidence\":%.1f,\"session\":\"%s\",\"atr\":%.5f,\"rsi\":%.2f}",
         symbol, timeframe, direction, confidence, session, atr, rsi
      );

      char post[];
      char result[];
      string headers = "Content-Type: application/json\r\n";
      string resultHeaders = "";

      StringToCharArray(payload, post, 0, StringLen(payload));

      // Perform asynchronous native web request to pipeline analytics to python
      int res = WebRequest("POST", m_url, headers, 1000, post, result, resultHeaders);
      if(res == -1)
      {
         // Log internally or handle offline status gracefully
         Print("InfrastructureBrain: HTTP Link Offline or URL not whitelisted in MT5 Terminal Settings.");
      }
      else
      {
         Print("InfrastructureBrain: Real-time API Signal synced successfully. HTTP Status: ", res);
      }
   }
};
