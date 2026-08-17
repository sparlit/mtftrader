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
   string m_apiKey;

public:
   CInfrastructureBrain(string host, int port, string apiKey = "")
   {
      m_url = StringFormat("http://%s:%d/api/signal", host, port);
      m_apiKey = apiKey;
   }

   ~CInfrastructureBrain() {}

   bool SendSignal(string symbol, string timeframe, string direction, double confidence, string session, double atr, double rsi)
   {
      // Format payload using exact schema of fastapi SignalRequest
      string payload = StringFormat(
         "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"direction\":\"%s\",\"confidence\":%.1f,\"session\":\"%s\",\"atr\":%.5f,\"rsi\":%.2f}",
         symbol, timeframe, direction, confidence, session, atr, rsi
      );

      char post[];
      char result[];
      string requestHeaders = "Content-Type: application/json\r\n";
      string responseHeaders = "";
      string headers = "Content-Type: application/json\r\n";
      // Attach API key when the backend enforces auth (ITIP_API_KEY set).
      if(StringLen(m_apiKey) > 0)
         headers += StringFormat("X-API-Key: %s\r\n", m_apiKey);

      StringToCharArray(payload, post, 0, StringLen(payload));

      ResetLastError();
      int res = WebRequest("POST", m_url, requestHeaders, 1000, post, result, responseHeaders);
      if(res == -1)
      {
         PrintFormat("InfrastructureBrain: WebRequest to %s failed (error %d). Ensure the URL is whitelisted in MT5 Terminal Settings and the backend is running.",
                     m_url, GetLastError());
         return false;
      }

      if(res < 200 || res >= 300)
      {
         PrintFormat("InfrastructureBrain: Backend rejected signal. HTTP Status: %d. Response: %s",
                     res, CharArrayToString(result));
         return false;
      }

      PrintFormat("InfrastructureBrain: Real-time API Signal synced successfully. HTTP Status: %d", res);
      return true;
   }
};
