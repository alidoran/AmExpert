//+------------------------------------------------------------------+
//|                                                           MA.mq4 |
//|                                               Copyright 2024, MA |
//|                                             https://dorantech.ir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MA"
#property link      "https://dorantech.ir"
#property version   "1.00"
#property strict
enum CandleType
  {
   NotPinBar,
   AscendingPinBar,
   DescendingPinBar,
  };

enum ArrowCode
  {
   ArrowUp = 233,           // Upward arrow
   ArrowDown = 234,         // Downward arrow
   ArrowLeft = 226,         // Leftward arrow
   ArrowRight = 227,        // Rightward arrow
   ArrowDiagonalUpRight = 228,  // Diagonal up-right arrow
   ArrowDiagonalDownLeft = 229, // Diagonal down-left arrow
   ArrowDiagonalUpLeft = 230,   // Diagonal up-left arrow
   ArrowDiagonalDownRight = 231 // Diagonal down-right arrow
  };

datetime lastCandleTime = 0; // Tracks the time of the last processed candle
MqlRates previousRates[];   // Stores previous candle data
bool isPeriod1Passed = false;
datetime period1PassedTime;
datetime closeTime5Min;

int ima1;
int    ima5;
double MA1_Buffer[];
double MA5_Buffer[];
int lastCandleIndex;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ima1 = iMA(Symbol(),PERIOD_M1,60,1,MODE_EMA,PRICE_CLOSE);
   ima5 = iMA(Symbol(),PERIOD_M5,20,1,MODE_EMA,PRICE_CLOSE);
   ArraySetAsSeries(MA1_Buffer,true);
   ArraySetAsSeries(MA5_Buffer,true);
   EventSetTimer(60);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(ima5);
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlRates rates[];

   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 1, rates);
   if(copied < 1)
     {
      Print("Failed to fetch rates: ", GetLastError());
      return;
     }

   if(CopyBuffer(ima1,0,0,1,MA1_Buffer)!=1)
      return;

   if(CopyBuffer(ima5,0,0,1,MA5_Buffer)!=1)
      return;

   if(rates[0].time != lastCandleTime)
     {
      lastCandleTime = rates[0].time;

      int historyCopied = CopyRates(_Symbol, PERIOD_M1, 1, 50, previousRates);


      if(historyCopied < 5)
        {
         Print("Failed to fetch previous rates: ", GetLastError());
         return;
        }
      lastCandleIndex = ArraySize(previousRates) - 1;
      //getPosition(previousRates);
      movingAveragePosition(previousRates);
     }
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CandleType detectCandleType(MqlRates &rates[], int index)
  {
   CandleType result = NotPinBar;
   double bodySize = MathAbs(rates[index].open - rates[index].close);
   datetime myTime = StringToTime("2024.11.25 08:10");
   datetime currentTime = TimeCurrent();
   double upperShadow = rates[index].high - MathMax(rates[index].open, rates[index].close);
   double lowerShadow = MathMin(rates[index].open, rates[index].close) - rates[index].low;
   double minShadowFactor = 2.0;
   double maxBodyFactor = 0.3;

   if(bodySize < (rates[index].high - rates[index].low) * maxBodyFactor &&
      (upperShadow > bodySize * minShadowFactor || lowerShadow > bodySize * minShadowFactor))
      result = rates[index].close > rates[index].open ? AscendingPinBar : DescendingPinBar;
   return result;
  }
//+------------------------------------------------------------------+
void MarkCandleWithArrow(MqlRates &rates[], int index, ArrowCode arrowCode)
  {
   string objectName = "Arrow_" + IntegerToString(rates[index].time) + "_" + IntegerToString(arrowCode);

   if(ObjectFind(0, objectName) < 0)
     {
      double price = (arrowCode == ArrowUp || arrowCode == ArrowDiagonalUpRight || arrowCode == ArrowDiagonalUpLeft)
                     ? rates[index].high + 10 * _Point
                     : rates[index].low - 10 * _Point;

      int arrowColor = (arrowCode == ArrowUp || arrowCode == ArrowDiagonalUpRight || arrowCode == ArrowDiagonalUpLeft)
                       ? clrGreen
                       : clrRed;

      if(ObjectCreate(0, objectName, OBJ_ARROW, 0, rates[index].time, price))
        {
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, arrowColor);
         ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, arrowCode);
        }
      else
        {
         Print("Error creating arrow: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void getPosition(MqlRates &rates[])
  {
   if((detectCandleType(rates, 3) != NotPinBar) && rates[lastCandleIndex].close > rates[3].high)
     {
      if(getRsi(PERIOD_M30) < 30)
        {
         sendOrderByPipe(30, 60, true);
         //MarkCandleWithArrow(rates, 4, ArrowUp);
        }
     };
   if((detectCandleType(rates, 3) != NotPinBar) && rates[lastCandleIndex].close < rates[3].low)
     {
      if(getRsi(PERIOD_M30) > 70)
        {
         sendOrderByPipe(30, 60, false);
         //MarkCandleWithArrow(rates, 4, ArrowDown);
        }
     };
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getRsi(ENUM_TIMEFRAMES timeFrame)
  {
   int RSiHandle;
   double rsi[2];
   CopyBuffer(RSiHandle,0,1,2,rsi);
   double RSICurrent =(rsi[0]);
   double RSIPrevious =(rsi [1]);

   RSiHandle = iRSI(_Symbol,timeFrame,14,PRICE_CLOSE);
   CopyBuffer(RSiHandle,0,0,2,rsi);
   return rsi[0];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sendOrderByPipe(int slPipe, int tpPipe, bool isBuy)
  {
   double sl = getSlByPipe(isBuy, slPipe);
   double tp = getTpByPipe(isBuy, tpPipe);
   sendOrder(isBuy, sl, tp);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sendOrderByPriorLow(bool isBuy, MqlRates &rates[])
  {
   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = getSlByPriorLow(rates);
   double tp = (MathAbs(entryPrice - sl) * 1.5) + entryPrice;
   sendOrder(isBuy, sl, tp);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sendOrder(bool isBuy, double sl, double tp)
  {
   MqlTradeRequest request;
   MqlTradeResult result;

   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   int orderType= isBuy? ORDER_TYPE_BUY: ORDER_TYPE_SELL;

   if(MathAbs(entryPrice - sl) < stopsLevel || MathAbs(tp - entryPrice) < stopsLevel)
     {
      Print("SL or TP is tSale order fromEnterpriseoo close to the current market price.");
      return;
     }

   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = 0.1;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 12345;
   Print("sl = ",sl," tp = ",tp," entryPrice = ",entryPrice," point= ",point);

   if(!OrderSend(request, result))
     {
      Print("OrderSend failed: ", GetLastError());
      return;
     }

   string message = result.retcode == TRADE_RETCODE_DONE? "Order placed successfully: Ticket = ": "Order failed: Retcode = ";
   Print(message, result.retcode);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getSlByPipe(bool isBuy, int stopLossInPips)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = isBuy ? entryPrice - (stopLossInPips * point) : entryPrice + (stopLossInPips * point);
   return NormalizeDouble(sl, SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getTpByPipe(bool isBuy, int takeProfitInPips)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = isBuy ? entryPrice + (takeProfitInPips * point) : entryPrice - (takeProfitInPips * point);
   return NormalizeDouble(tp, SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getSlByPriorLow(MqlRates &rates[])
  {
   double priorCandleLow = 0;
   for(int i = lastCandleIndex - 5 ; i > lastCandleIndex - 10 ; i--)
     {
      if(priorCandleLow == 0 || rates[i].low < priorCandleLow)
        {
         priorCandleLow = rates[i].low;
        }
     }
   return priorCandleLow;
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isGap(MqlRates &rates[])
  {
   return rates[lastCandleIndex].low > rates[lastCandleIndex - 2].high;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double movingAverage(ENUM_TIMEFRAMES timeFrame, int period)
  {
   return iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void movingAveragePosition(MqlRates &rates[])
  {
   double movingAvrage1 = MA1_Buffer[0];
   double movingAvrage5 = MA5_Buffer[0];
   int availableBars = Bars(_Symbol, PERIOD_M5);
   datetime openTime5Min = iTime(_Symbol, PERIOD_M5, 0);
   datetime closeTime5MinNew = openTime5Min + PeriodSeconds();
   datetime openTime1Min = iTime(_Symbol, PERIOD_M1, 0);
   datetime closeTime1Min = openTime1Min + PeriodSeconds();

   if(closeTime5MinNew != closeTime5Min)
     {
      if(rates[lastCandleIndex].close > movingAvrage5 && isPeriod1Passed)
        {
         if(rates[lastCandleIndex - 20].high < movingAvrage5 && rates[lastCandleIndex - 4].open < movingAvrage1)
           {
            MarkCandleWithArrow(rates, lastCandleIndex, ArrowUp);
            //sendOrderByPipe(30, 60, true);
            sendOrderByPriorLow(true, rates);
           }
        }
      closeTime5Min = closeTime5MinNew;
      isPeriod1Passed = false;
     }

   if(rates[lastCandleIndex].close > movingAvrage1 && !isPeriod1Passed)
     {
      isPeriod1Passed = true;
      period1PassedTime = rates[lastCandleIndex].time;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
