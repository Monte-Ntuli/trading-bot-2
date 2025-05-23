//+------------------------------------------------------------------+
//| Enhanced Supply/Demand EA with Smart Risk Management            |
//| Version: 2.0                                                   |
//| Author: Monte                                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

enum ENUM_MARKET_REGIME { REGIME_BULLISH, REGIME_BEARISH, REGIME_RANGING };
enum TradeType { NONE = 0, BUY_TRADE = 1, SELL_TRADE = 2 };

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input double   LotSize = 0.1;                // Base lot size
input int      StopLossPips = 30;            // Base SL (pips)
input int      TakeProfitPips = 400;         // Base TP (pips)
input double   RiskPercentage = 1.0;         // Risk per trade (%)
input int      FakeoutThreshold = 10;        // Min fakeout movement
input string   TradingHours = "13:00-16:00"; // Trading window
input double   DailyProfitTarget = 2.0;      // Daily target (%)
input double   DailyLossLimit = -1.0;        // Daily loss limit (%)
input bool     UseHTFConfirmation = true;    // Use HTF trend filter
input int      ATR_Period = 14;              // ATR period
input bool     UseVolatilitySL = true;       // Use ATR-based SL/TP
input bool     UsePartialClose = true;       // Enable partial closes

//+------------------------------------------------------------------+
//| Zone Structure                                                  |
//+------------------------------------------------------------------+
struct Zone {
   double high;
   double low;
   datetime time;
   int strength;
   int touchCount;
   bool validated;
};

#define MAX_ZONES 15
Zone demandZones[MAX_ZONES];
Zone supplyZones[MAX_ZONES];
int demandZoneCount = 0;
int supplyZoneCount = 0;
int atr_handle = INVALID_HANDLE;
int    ema50_handle;
int    ema200_handle;
int ema200H4_handle = INVALID_HANDLE;
int ema50H4_handle = INVALID_HANDLE;
double GetResistanceLevel() { return iHigh(_Symbol, PERIOD_H1, 1); }
double GetSupportLevel()    { return iLow(_Symbol, PERIOD_H1, 1); }

CTrade trade;
CPositionInfo positionInfo;
datetime lastTradeTime = 0;
ENUM_MARKET_REGIME currentRegime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   atr_handle = iATR(_Symbol, PERIOD_H1, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create ATR handle, error ", GetLastError());
      return(INIT_FAILED);
   }
   
   // create EMA(50) on H1
   ema50_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA50 handle, error ", GetLastError());
      return(INIT_FAILED);
   }
   // create EMA(200) on H1
   ema200_handle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema200_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA200 handle, error ", GetLastError());
      return(INIT_FAILED);
   }
   
   //create EMA(50) on H4
   ema50H4_handle = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50H4_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create EMA50 H4 handle, error ", GetLastError());
      return(INIT_FAILED);
   }
   
   //create EMA(200) on H4
   ema200H4_handle = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema200H4_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create EMA200 H4 handle, error ", GetLastError());
      return(INIT_FAILED);
   }
   
   trade.SetExpertMagicNumber(12345);
   ResetLastTradeIfNoOpenPositions();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) 
{ /* Cleanup if needed */ 
   if(atr_handle != INVALID_HANDLE){
      IndicatorRelease(atr_handle);
      }
   
   if(ema50H4_handle != INVALID_HANDLE) {IndicatorRelease(ema50H4_handle); }
   if(ema200H4_handle != INVALID_HANDLE) {IndicatorRelease(ema200H4_handle);}
      
   if(ema50_handle  != INVALID_HANDLE) IndicatorRelease(ema50_handle);
   if(ema200_handle != INVALID_HANDLE) IndicatorRelease(ema200_handle);
}

//+------------------------------------------------------------------+
//| Main trading function                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   //––– Pre-checks –––
   if(!CheckDailyLimits()) return;
   if(!IsTradingTime()) return;
   if(HasOpenPositionForSymbol()) return;
   if(Bars(_Symbol, PERIOD_H1) < 100) return;
   
   // 1) History guard
   if (Bars(_Symbol, PERIOD_H1) < 3)
   {
      Print(__FUNCTION__, ": waiting for H1 history (", Bars(_Symbol, PERIOD_H1), " bars)");
      return;
   }
   ResetLastError();

   // 2) Cooldown guard
   if (!CanTrade())
   {
      Print(__FUNCTION__, ": cooldown in effect, next trade after ",
            TimeToString(lastTradeTime + 5*60, TIME_MINUTES));
      return;
   }

   // 3) Existing position guard
   if(HasOpenPositionForSymbol())
   {
      Print("🛑 A position is already open on ", _Symbol);
      return;
   }

   // 4) Tradability guard
   if (!IsSymbolTradable())
   {
      Print(__FUNCTION__, ": symbol not tradable");
      return;
   }

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double resistanceLevel = GetResistanceLevel();
   double supportLevel = GetSupportLevel();
   
   currentRegime = DetectMarketRegime();
   double atrValue = GetCurrentATR();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check for price breaking above resistance (fakeout logic)
   if (currentPrice > resistanceLevel + FakeoutThreshold * _Point)
   {
      EnterSellTrade(currentPrice, atrValue);
      SetTradeTime();
   }
   // Check for price breaking below support (fakeout logic)
   else if (currentPrice < supportLevel - FakeoutThreshold * _Point)
   {
      EnterBuyTrade(currentPrice, atrValue);
      SetTradeTime();
   }

   //––– Core Strategies –––
   CheckFakeoutBreakouts(price, atrValue);
   ScanForSupplyDemandZones(atrValue);
   CheckZoneEntry(price, atrValue);
   
   //––– Position Management –––
   ManageExits(atrValue);
   PurgeOldZones(168);
}

//+------------------------------------------------------------------+
//| Global Symbol-Based Last Trade Tracker Trade Duplication Control |
//+------------------------------------------------------------------+

bool IsSymbolTradable()  { return SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED; }

bool CanTrade() { return (TimeCurrent() - lastTradeTime) > 5 * 60; }

void SetTradeTime() { lastTradeTime = TimeCurrent(); }

string GetLastTradeKey()
{
   return "LastTrade_" + _Symbol;
}

TradeType GetLastTrade()
{
   if (!GlobalVariableCheck(GetLastTradeKey()))
      return NONE;
   return (TradeType)(int)GlobalVariableGet(GetLastTradeKey());
}

void SetLastTrade(TradeType type)
{
   GlobalVariableSet(GetLastTradeKey(), type);
}

void ResetLastTradeIfNoOpenPositions()
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetSymbol(i) == _Symbol)
         return;
   }
   GlobalVariableDel(GetLastTradeKey());
}

//-----Get EMA H4------------------------------
double GetEMA50_H4()
{
   double buf[1];
   // buffer 0 is the EMA line itself
   if(CopyBuffer(ema50H4_handle, 0, 0, 1, buf) != 1)
   {
      Print("⚠️ CopyBuffer failed for EMA50 H4, error ", GetLastError());
      return(0.0);
   }
   return buf[0];
}

double GetEMA200_H4()
{
   double buf[1];
   // buffer index 0 is the EMA line
   if(CopyBuffer(ema200H4_handle, 0, 0, 1, buf) != 1)
   {
      Print("⚠️ CopyBuffer failed for EMA200 H4, error ", GetLastError());
      return(0.0);
   }
   return(buf[0]);
}

//–––– DETECT MARKET REGIME ––––––––––––––––––––––––––––––––––––––––––––––––––
ENUM_MARKET_REGIME CheckRegime()
{
   double ema50_buf[1], ema200_buf[1];

   // Copy latest EMA values
   if(CopyBuffer(ema50_handle,  0, 0, 1, ema50_buf)  != 1 ||
      CopyBuffer(ema200_handle, 0, 0, 1, ema200_buf) != 1)
   {
      // on error, default to ranging
      Print("🔍 DetectMarketRegime: CopyBuffer failed, err=", GetLastError());
      return(REGIME_RANGING);
   }

   double ema50 = ema50_buf[0];
   double ema200 = ema200_buf[0];
   double priceH1 = iClose(_Symbol, PERIOD_H1, 0);  // latest H1 close

   // Bullish: EMA50 above EMA200 and price above EMA50
   if(ema50 > ema200 && priceH1 > ema50)
      return(REGIME_BULLISH);

   // Bearish: EMA50 below EMA200 and price below EMA50
   if(ema50 < ema200 && priceH1 < ema50)
      return(REGIME_BEARISH);

   // Otherwise it’s ranging
   return(REGIME_RANGING);
}

//+------------------------------------------------------------------+
//| Fakeout Breakout Logic                                          |
//+------------------------------------------------------------------+
void CheckFakeoutBreakouts(double price, double atr)
{
   double resistance = iHigh(_Symbol, PERIOD_H1, 1);
   double support = iLow(_Symbol, PERIOD_H1, 1);
   double threshold = UseVolatilitySL ? atr * 0.5 : FakeoutThreshold * _Point;

   if(price > resistance + threshold && (!UseHTFConfirmation || currentRegime != REGIME_BULLISH))
      EnterSellTrade(price, atr);
   else if(price < support - threshold && (!UseHTFConfirmation || currentRegime != REGIME_BEARISH))
      EnterBuyTrade(price, atr);
}

//+------------------------------------------------------------------+
//| Zone Entry Logic                                                |
//+------------------------------------------------------------------+
void CheckZoneEntry(double price, double atr)
{
   for(int i=0; i<demandZoneCount; i++) {
      if(price >= demandZones[i].low && price <= demandZones[i].high) {
         demandZones[i].touchCount++;
         if(demandZones[i].touchCount >= 2) demandZones[i].validated = true;
         if(demandZones[i].validated && IsBullishEngulfing() && CheckRegime())
            EnterBuyTrade(price, atr);
      }
   }
   
   for(int i=0; i<supplyZoneCount; i++) {
      if(price <= supplyZones[i].high && price >= supplyZones[i].low) {
         supplyZones[i].touchCount++;
         if(supplyZones[i].touchCount >= 2) supplyZones[i].validated = true;
         if(supplyZones[i].validated && IsBearishEngulfing() && CheckRegime())
            EnterSellTrade(price, atr);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Execution Functions                                       |
//+------------------------------------------------------------------+
void EnterBuyTrade(double price, double atr)
{
   if(GetLastTrade() == BUY_TRADE) return;
   
   double sl = UseVolatilitySL ? price - 1.5*atr : price - StopLossPips*_Point;
   double tp = UseVolatilitySL ? price + 3.0*atr : price + TakeProfitPips*_Point;
   double lot = CalculateDynamicLotSize(atr);
   
   if(trade.Buy(lot, _Symbol, price, sl, tp, "Bullish Zone Entry")) {
      SetLastTrade(BUY_TRADE);
      lastTradeTime = TimeCurrent();
   }
}

void EnterSellTrade(double price, double atr)
{
   if(GetLastTrade() == SELL_TRADE) return;
   
   double sl = UseVolatilitySL ? price + 1.5*atr : price + StopLossPips*_Point;
   double tp = UseVolatilitySL ? price - 3.0*atr : price - TakeProfitPips*_Point;
   double lot = CalculateDynamicLotSize(atr);
   
   if(trade.Sell(lot, _Symbol, price, sl, tp, "Bearish Zone Entry")) {
      SetLastTrade(SELL_TRADE);
      lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Advanced Risk Management                                        |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double atr)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * RiskPercentage / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   double lot = NormalizeDouble(riskAmount / (atr / _Point * tickValue), 2);
   lot = fmax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 
        fmin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)));
   return lot;
}

void ManageExits(double atr)
{
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(positionInfo.SelectByIndex(i)) {
         if(positionInfo.Symbol() != _Symbol) continue;
         
         double profit = positionInfo.Profit();
         double volume = positionInfo.Volume();
         double currentSL = positionInfo.StopLoss();
         
         // Partial close
         if(UsePartialClose && profit > 50 && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)*2) {
            trade.PositionClosePartial(positionInfo.Ticket(), volume/2);
         }
         
         // Trailing stop
         double newSL = positionInfo.PositionType() == POSITION_TYPE_BUY 
                       ? positionInfo.PriceOpen() + 1.5*atr
                       : positionInfo.PriceOpen() - 1.5*atr;
         if((positionInfo.PositionType() == POSITION_TYPE_BUY && newSL > currentSL) ||
            (positionInfo.PositionType() == POSITION_TYPE_SELL && newSL < currentSL)) {
            trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Market Analysis Functions                                       |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME DetectMarketRegime()
{
   double ema50 = GetEMA50_H4();
   double ema200 = GetEMA200_H4();
   return (ema50 > ema200) ? REGIME_BULLISH : (ema50 < ema200) ? REGIME_BEARISH : REGIME_RANGING;
}

void ScanForSupplyDemandZones(double atr)
{
   for(int i=3; i<50; i++) {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      double body = MathAbs(iClose(_Symbol, PERIOD_H1, i) - iOpen(_Symbol, PERIOD_H1, i));
      double range = high - low;
      
      // Demand zones
      if(iClose(_Symbol, PERIOD_H1, i+1) < iOpen(_Symbol, PERIOD_H1, i+1) &&
         iClose(_Symbol, PERIOD_H1, i) > iOpen(_Symbol, PERIOD_H1, i) &&
         body/range > 0.7 && range > atr) 
      {
         AddZone(demandZones, demandZoneCount, high, low, iTime(_Symbol, PERIOD_H1, i), atr);
      }
      
      // Supply zones
      if(iClose(_Symbol, PERIOD_H1, i+1) > iOpen(_Symbol, PERIOD_H1, i+1) &&
         iClose(_Symbol, PERIOD_H1, i) < iOpen(_Symbol, PERIOD_H1, i) &&
         body/range > 0.7 && range > atr) 
      {
         AddZone(supplyZones, supplyZoneCount, high, low, iTime(_Symbol, PERIOD_H1, i), atr);
      }
   }
}

//+------------------------------------------------------------------+
//| Utility Functions                                               |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   double dailyPL = (AccountInfoDouble(ACCOUNT_EQUITY)-AccountInfoDouble(ACCOUNT_BALANCE))
                  /AccountInfoDouble(ACCOUNT_BALANCE)*100;
   return (dailyPL < DailyProfitTarget && dailyPL > DailyLossLimit);
}

bool IsTradingTime()
{
   MqlDateTime now;
   TimeCurrent(now);
   int start = (int)StringSubstr(TradingHours,0,2);
   int end = (int)StringSubstr(TradingHours,6,2);
   return (now.hour >= start && now.hour < end);
}

bool HasOpenPositionForSymbol()
{
  for(int i = 0; i < PositionsTotal(); i++)
  {
    if(PositionGetSymbol(i) == _Symbol)
      return true;
  }
  return false;
}

void AddZone(Zone &zones[], int &count, double high, double low, datetime time, double atr)
{
   if(count >= MAX_ZONES) {
      ArrayCopy(zones, zones, 0, 1);
      count--;
   }
   zones[count].high = high;
   zones[count].low = low;
   zones[count].time = time;
   zones[count].strength = (high-low) > 2*atr ? 2 : 1;
   zones[count].touchCount = 0;
   zones[count].validated = false;
   count++;
}

// Get ATR Value 
double GetCurrentATR()
{
   double atr_buf[1];
   if(CopyBuffer(atr_handle,    // our handle
                 0,             // buffer index for the main line
                 0,             // start at the current bar
                 1,             // copy one value
                 atr_buf) != 1) // expect exactly 1 value
   {
      Print("⚠️ CopyBuffer failed for ATR, error ", GetLastError());
      return(0.0);
   }
   return(atr_buf[0]);  // this is the latest ATR
}

//+------------------------------------------------------------------+
//| Candlestick pattern detection                                    |
//+------------------------------------------------------------------+
bool IsBearishEngulfing()
{
   double o1 = iOpen(_Symbol, PERIOD_H1, 1);
   double c1 = iClose(_Symbol, PERIOD_H1, 1);
   double o2 = iOpen(_Symbol, PERIOD_H1, 2);
   double c2 = iClose(_Symbol, PERIOD_H1, 2);
   return (c1 < o1 && c2 > o2 && c1 < o2 && o1 > c2);
}

bool IsBullishEngulfing()
{
   double o1 = iOpen(_Symbol, PERIOD_H1, 1);
   double c1 = iClose(_Symbol, PERIOD_H1, 1);
   double o2 = iOpen(_Symbol, PERIOD_H1, 2);
   double c2 = iClose(_Symbol, PERIOD_H1, 2);
   return (c1 > o1 && c2 < o2 && c1 > o2 && o1 < c2);
}

void PurgeOldZones(int maxAgeHours)
{
   datetime now = TimeCurrent();
   //––– Purge old demand zones
   int writeDemand = 0;
   for(int i = 0; i < demandZoneCount; i++)
   {
      if(now - demandZones[i].time <= (datetime)maxAgeHours * 3600)
      {
         demandZones[writeDemand++] = demandZones[i];
      }
   }
   demandZoneCount = writeDemand;

   //––– Purge old supply zones
   int writeSupply = 0;
   for(int j = 0; j < supplyZoneCount; j++)
   {
      if(now - supplyZones[j].time <= (datetime)maxAgeHours * 3600)
      {
         supplyZones[writeSupply++] = supplyZones[j];
      }
   }
   supplyZoneCount = writeSupply;
}

void CorrectTradeParameters(double &lot, double &price, double &sl, double &tp)
{
   // Broker requirement checks
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot) lot = minLot;
   
   // Stop level validation
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(price - sl) < minStop)
      sl = (price > sl) ? price - minStop : price + minStop;
}
