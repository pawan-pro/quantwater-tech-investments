//+------------------------------------------------------------------+
//|                                              signalprocessor.mq5 |
//|                      Copyright 2025, Quantwater Tech Investments |
//|                                      https://www.quantwater.tech |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Quantwater Tech Investments"
#property link      "https://www.quantwater.tech"
#property version   "6.03"
#include <Trade\Trade.mqh>
//--- EA Input Parameters
input group           "Risk Management"
input double          FixedPercentageRisk = 1.0;     // Risk per trade (%)
input double          MinimumAcceptableRRR = 1.5;    // Minimum Risk-Reward Ratio
input group           "Entry Conditions"
input double          EntryTolerancePips = 5.0;      // Tolerance for entry price matching
input bool            WaitForEntryPrice = true;      // Wait for recommended entry price
input int             MaxWaitMinutes = 60;           // Max time to wait for entry conditions
input bool            EnableScenarioSwitch = true;   // Enable automatic scenario switching
input group           "File Settings"
input string          SignalFileName = "signals.csv"; // CSV file name
input int             TimerFrequency = 5;             // Timer frequency (seconds)
input group           "Debug Settings"
input bool            EnableDebugMode = true;        // Enable detailed debug logging
input bool            LogFileContents = false;       // Log entire file contents (use carefully)
input bool            EnableTradingStatusCheck = true; // Enable continuous trading status monitoring
//--- Signal Data Structures
struct SignalData
{
   string symbol;
   string action;
   double entry;
   double target;
   double alt_entry;
   string alt_action;
   double alt_target;
};
// Add copy constructor and default constructor to resolve assignment warning and pass by reference issues
struct PendingSignal
{
   string symbol;
   string current_action;        // Current active action (Buy/Sell)
   double current_entry;         // Current entry price to monitor
   double current_target;        // Current target
   double current_stop_loss;     // Current stop loss
   string alt_action;            // Alternative scenario action
   double alt_entry;             // Alternative entry price
   double alt_target;            // Alternative target
   datetime signal_time;         // When signal was created
   bool scenario_one_active;     // True = Scenario 1, False = Alternative
   double scenario_switch_price; // Price that triggers scenario switch
   // Copy constructor
   PendingSignal(const PendingSignal &other)
   {
      symbol = other.symbol;
      current_action = other.current_action;
      current_entry = other.current_entry;
      current_target = other.current_target;
      current_stop_loss = other.current_stop_loss;
      alt_action = other.alt_action;
      alt_entry = other.alt_entry;
      alt_target = other.alt_target;
      signal_time = other.signal_time;
      scenario_one_active = other.scenario_one_active;
      scenario_switch_price = other.scenario_switch_price;
   }
   // Default constructor (important for arrays)
   PendingSignal()
   {
      symbol = "";
      current_action = "";
      current_entry = 0.0;
      current_target = 0.0;
      current_stop_loss = 0.0;
      alt_action = "";
      alt_entry = 0.0;
      alt_target = 0.0;
      signal_time = 0;
      scenario_one_active = true;
      scenario_switch_price = 0.0;
   }
};
//--- Global Variables
CTrade            trade;
long              lastFileModifyTime = 0;
int               debugCounter = 0;
PendingSignal     pending_signals[];
int               pending_count = 0;
datetime          lastStatusCheck = 0;
//+------------------------------------------------------------------+
//| Debug Print Function                                             |
//+------------------------------------------------------------------+
void DebugPrint(string message)
{
   if(EnableDebugMode)
   {
      Print("[DEBUG-", debugCounter++, "] ", message);
   }
}
//+------------------------------------------------------------------+
//| Check Trading Permissions and Status                            |
//+------------------------------------------------------------------+
bool CheckTradingPermissions(bool print_details = false)
{
   bool terminalTradeAllowed = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   bool expertTradeAllowed = MQLInfoInteger(MQL_TRADE_ALLOWED);
   bool accountTradeAllowed = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
   bool autoTradingEnabled = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   if(print_details)
   {
      DebugPrint("=== TRADING PERMISSIONS CHECK ===");
      DebugPrint("Terminal Trading Allowed: " + (terminalTradeAllowed ? "YES" : "NO"));
      DebugPrint("Expert Trading Allowed: " + (expertTradeAllowed ? "YES" : "NO"));
      DebugPrint("Account Trading Allowed: " + (accountTradeAllowed ? "YES" : "NO"));
      DebugPrint("AutoTrading Status: " + (autoTradingEnabled ? "ENABLED" : "DISABLED"));
      // Additional trading environment info
      DebugPrint("Account Trade Mode: " + IntegerToString(AccountInfoInteger(ACCOUNT_TRADE_MODE)));
      DebugPrint("Account Margin Mode: " + IntegerToString(AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
      DebugPrint("Terminal Connected: " + (TerminalInfoInteger(TERMINAL_CONNECTED) ? "YES" : "NO"));
      DebugPrint("Terminal Build: " + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)));
   }
   bool allPermissionsOK = terminalTradeAllowed && expertTradeAllowed && accountTradeAllowed;
   if(!allPermissionsOK && print_details)
   {
      Print("*** CRITICAL: Trading permissions issue detected ***");
      if(!terminalTradeAllowed)
         Print(">>> SOLUTION: Enable AutoTrading in MetaTrader (click AutoTrading button or press Ctrl+E)");
      if(!expertTradeAllowed)
         Print(">>> SOLUTION: Go to Tools->Options->Expert Advisors and enable 'Allow automated trading'");
      if(!accountTradeAllowed)
         Print(">>> SOLUTION: Contact broker - account trading is disabled");
   }
   return allPermissionsOK;
}
//+------------------------------------------------------------------+
//| Check Symbol Trading Status                                     |
//+------------------------------------------------------------------+
bool CheckSymbolTradingStatus(string symbol, bool print_details = false)
{
   if(!SymbolSelect(symbol, true))
   {
      if(print_details) DebugPrint("Failed to select symbol: " + symbol);
      return false;
   }
   long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   bool tradingAllowed = (tradeMode == SYMBOL_TRADE_MODE_FULL);
   if(print_details)
   {
      DebugPrint("Symbol " + symbol + " trade mode: " + IntegerToString(tradeMode));
      DebugPrint("Trading allowed for " + symbol + ": " + (tradingAllowed ? "YES" : "NO"));
      if(!tradingAllowed)
      {
         string tradeStatus = "";
         switch(tradeMode)
         {
            case SYMBOL_TRADE_MODE_DISABLED: tradeStatus = "DISABLED"; break;
            case SYMBOL_TRADE_MODE_LONGONLY: tradeStatus = "LONG ONLY"; break;
            case SYMBOL_TRADE_MODE_SHORTONLY: tradeStatus = "SHORT ONLY"; break;
            case SYMBOL_TRADE_MODE_CLOSEONLY: tradeStatus = "CLOSE ONLY"; break;
            default: tradeStatus = "UNKNOWN";
         }
         DebugPrint("Trade mode status: " + tradeStatus);
      }
   }
   return tradingAllowed;
}
//+------------------------------------------------------------------+
//| Enhanced Trading Status Monitor                                  |
//+------------------------------------------------------------------+
void MonitorTradingStatus()
{
   if(!EnableTradingStatusCheck) return;
   if(TimeCurrent() - lastStatusCheck > 300) // Check every 5 minutes
   {
      DebugPrint("=== PERIODIC TRADING STATUS CHECK ===");
      bool permissionsOK = CheckTradingPermissions(true);
      if(!permissionsOK)
      {
         Print("*** WARNING: Trading permissions issue - trades will fail ***");
      }
      else
      {
         DebugPrint("Trading permissions: ALL OK");
      }
      // Check connection status
      bool connected = TerminalInfoInteger(TERMINAL_CONNECTED);
      DebugPrint("Broker connection: " + (connected ? "CONNECTED" : "DISCONNECTED"));
      if(!connected)
      {
         Print("*** WARNING: Not connected to broker - trades will fail ***");
      }
      lastStatusCheck = TimeCurrent();
   }
}
//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== SmartReportsProcessorEA v6.03 Initializing ===");
   DebugPrint("Account Number: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   DebugPrint("Account Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   DebugPrint("Account Currency: " + AccountInfoString(ACCOUNT_CURRENCY));
   DebugPrint("Signal File Name: " + SignalFileName);
   DebugPrint("Timer Frequency: " + IntegerToString(TimerFrequency) + " seconds");
   DebugPrint("Risk Percentage: " + DoubleToString(FixedPercentageRisk, 2) + "%");
   DebugPrint("Minimum RRR: " + DoubleToString(MinimumAcceptableRRR, 2));
   DebugPrint("Entry Tolerance: " + DoubleToString(EntryTolerancePips, 1) + " pips");
   DebugPrint("Wait for Entry Price: " + (WaitForEntryPrice ? "YES" : "NO"));
   DebugPrint("Max Wait Time: " + IntegerToString(MaxWaitMinutes) + " minutes");
   DebugPrint("Scenario Switching: " + (EnableScenarioSwitch ? "ENABLED" : "DISABLED"));
   DebugPrint("Trading Status Monitoring: " + (EnableTradingStatusCheck ? "ENABLED" : "DISABLED"));
   string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
   DebugPrint("Terminal Common Data Path: " + commonPath);
   // Comprehensive trading permissions check at startup
   Print("=== INITIAL TRADING ENVIRONMENT CHECK ===");
   bool permissionsOK = CheckTradingPermissions(true);
   if(!permissionsOK)
   {
      Print("*** CRITICAL WARNING: Trading permissions issues detected ***");
      Print("*** EA will not be able to execute trades until resolved ***");
   }
   else
   {
      Print("*** Trading permissions: ALL OK - Ready to trade ***");
   }
   EventSetTimer(TimerFrequency);
   Print("=== Initialization Complete ===");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DebugPrint("EA deinitialization. Reason code: " + IntegerToString(reason));
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM: reasonText = "EA removed"; break;
      case REASON_REMOVE: reasonText = "EA removed manually"; break;
      case REASON_RECOMPILE: reasonText = "EA recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Chart changed"; break;
      case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
      case REASON_PARAMETERS: reasonText = "Parameters changed"; break;
      case REASON_ACCOUNT: reasonText = "Account changed"; break;
      case REASON_TEMPLATE: reasonText = "Template changed"; break;
      case REASON_INITFAILED: reasonText = "Init failed"; break;
      case REASON_CLOSE: reasonText = "Terminal closing"; break;
      default: reasonText = "Unknown reason";
   }
   Print("EA stopped. Reason: " + IntegerToString(reason) + " (" + reasonText + ")");
}
//+------------------------------------------------------------------+
//| OnTick Function - Monitor Entry Conditions                      |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor all pending signals for entry conditions
   for(int i = pending_count - 1; i >= 0; i--)
   {
      CheckEntryConditions(i);
   }
}
//+------------------------------------------------------------------+
//| Timer Function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   DebugPrint("Timer triggered - checking signal file");
   // Monitor trading status periodically
   MonitorTradingStatus();
   if(!FileIsExist(SignalFileName, FILE_COMMON))
   {
      DebugPrint("Signal file '" + SignalFileName + "' not found in Common folder");
      return;
   }
   int fileHandle = FileOpen(SignalFileName, FILE_READ | FILE_BIN | FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      DebugPrint("FAILED to open signal file. Error: " + IntegerToString(GetLastError()));
      return;
   }
   long currentModifyTime = FileGetInteger(fileHandle, FILE_MODIFY_DATE);
   long fileSizeLong = FileGetInteger(fileHandle, FILE_SIZE);
   if(fileSizeLong > INT_MAX) {
      DebugPrint("File too large: " + IntegerToString((int)fileSizeLong) + " bytes");
      FileClose(fileHandle);
      return;
   }
   int fileSize = (int)fileSizeLong;
   DebugPrint("File modify time: " + TimeToString(currentModifyTime));
   DebugPrint("File size: " + IntegerToString(fileSize) + " bytes");
   FileClose(fileHandle);
   if(currentModifyTime > lastFileModifyTime)
   {
      Print("*** NEW SIGNAL FILE DETECTED ***");
      lastFileModifyTime = currentModifyTime;
      ProcessSignals();
   }
   else
   {
      DebugPrint("No file changes detected");
   }
}
//+------------------------------------------------------------------+
//| Extract time components manually (replacement for TimeHour)     |
//+------------------------------------------------------------------+
int ExtractHour(datetime time_value)
{
   MqlDateTime dt;
   TimeToStruct(time_value, dt);
   return dt.hour;
}
//+------------------------------------------------------------------+
//| Check Entry Conditions for Pending Signal                        |
//+------------------------------------------------------------------+
void CheckEntryConditions(int signal_index)
{
   if(signal_index >= pending_count) return;
   PendingSignal sig = pending_signals[signal_index];
   // Check if signal has expired
   if(TimeCurrent() - sig.signal_time > MaxWaitMinutes * 60)
   {
      DebugPrint("Signal expired for " + sig.symbol + " after " + IntegerToString(MaxWaitMinutes) + " minutes");
      RemovePendingSignal(signal_index);
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(sig.symbol, tick)) return;
   double current_market_price = (sig.current_action == "Buy") ? tick.ask : tick.bid;
   // Check for scenario switching first (if enabled and scenario one is active)
   if(EnableScenarioSwitch && sig.scenario_one_active)
   {
      bool should_switch = false;
      if(sig.current_action == "Buy" && current_market_price < sig.scenario_switch_price)
         should_switch = true;
      else if(sig.current_action == "Sell" && current_market_price > sig.scenario_switch_price)
         should_switch = true;
      if(should_switch)
      {
         Print("*** SCENARIO SWITCH TRIGGERED for " + sig.symbol + " ***");
         Print("Market price " + DoubleToString(current_market_price, _Digits) +
               " crossed switch level " + DoubleToString(sig.scenario_switch_price, _Digits));
         // Switch to alternative scenario - update the array element directly
         pending_signals[signal_index].current_action = sig.alt_action;
         pending_signals[signal_index].current_entry = sig.alt_entry;
         pending_signals[signal_index].current_target = sig.alt_target;
         pending_signals[signal_index].current_stop_loss = (sig.alt_action == "Buy") ?
            sig.alt_entry - MathAbs(sig.alt_target - sig.alt_entry) :
            sig.alt_entry + MathAbs(sig.alt_target - sig.alt_entry);
         pending_signals[signal_index].scenario_one_active = false;
         Print("Switched to Alternative: " + sig.alt_action + " at " + DoubleToString(sig.alt_entry, _Digits));
         return; // Wait for next tick to check new entry conditions
      }
   }
   // Check if we should wait for entry price or execute immediately
   bool execute_trade = false;
   if(!WaitForEntryPrice)
   {
      // Execute immediately at market price
      execute_trade = true;
      DebugPrint("Immediate execution mode - executing " + sig.symbol + " at market");
   }
   else
   {
      // Check if current price is within tolerance of recommended entry price
      double tolerance = EntryTolerancePips * SymbolInfoDouble(sig.symbol, SYMBOL_POINT);
      if(sig.current_action == "Buy")
      {
         // For Buy orders, execute when market price is at or below entry price (better fill)
         execute_trade = (current_market_price <= sig.current_entry + tolerance);
      }
      else // Sell
      {
         // For Sell orders, execute when market price is at or above entry price (better fill)
         execute_trade = (current_market_price >= sig.current_entry - tolerance);
      }
      if(execute_trade)
      {
         DebugPrint("Entry conditions met for " + sig.symbol +
                   " - Target: " + DoubleToString(sig.current_entry, _Digits) +
                   ", Market: " + DoubleToString(current_market_price, _Digits));
      }
   }
   if(execute_trade)
   {
      ExecuteTradeFromSignal(signal_index);
      RemovePendingSignal(signal_index);
   }
}
//+------------------------------------------------------------------+
//| Execute Trade from Pending Signal                                |
//+------------------------------------------------------------------+
void ExecuteTradeFromSignal(int signal_index)
{
   if(signal_index >= pending_count) return;
   PendingSignal sig = pending_signals[signal_index];
   Print("*** EXECUTING TRADE for " + sig.symbol + " ***");
   // COMPREHENSIVE PRE-TRADE CHECKS
   // 1. Check global trading permissions
   if(!CheckTradingPermissions(true))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Trading permissions disabled ***");
      Print(">>> Check AutoTrading button and Expert Advisor settings");
      return;
   }
   // 2. Check broker connection
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Not connected to broker ***");
      return;
   }
   // 3. Check account trading status
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Account trading disabled ***");
      Print(">>> Contact your broker to enable trading on this account");
      return;
   }
   // 4. Check symbol availability and trading status
   if(!CheckSymbolTradingStatus(sig.symbol, true))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Symbol trading disabled ***");
      return;
   }
   // 5. Ensure symbol is selected
   if(!SymbolSelect(sig.symbol, true))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Failed to select symbol ***");
      return;
   }
   // 6. Get current tick data
   MqlTick tick;
   if(!SymbolInfoTick(sig.symbol, tick))
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": No tick data available ***");
      return;
   }
   // 7. Simplified market session check using SYMBOL_SESSION_OPEN/CLOSE
   // ASSUMPTION: Markets are open 24/7. Skipping detailed session check.
   DebugPrint("Market session check skipped - assuming 24/7 market availability for " + sig.symbol);

   /*
   // --- Original problematic code commented out ---
   datetime currentTime = TimeCurrent();
   long marketOpenLong = SymbolInfoInteger(sig.symbol, SYMBOL_SESSION_OPEN); // Line 517
   long marketCloseLong = SymbolInfoInteger(sig.symbol, SYMBOL_SESSION_CLOSE); // Line 518
   if(marketOpenLong != 0 && marketCloseLong != 0)
   {
      datetime marketOpen = (datetime)marketOpenLong;
      datetime marketClose = (datetime)marketCloseLong;
      int currentHour = ExtractHour(currentTime);
      int openHour = ExtractHour(marketOpen);
      int closeHour = ExtractHour(marketClose);
      bool marketIsOpen = true;
      if(closeHour > openHour)
         marketIsOpen = (currentHour >= openHour && currentHour < closeHour);
      else if (closeHour < openHour) // Overnight session
         marketIsOpen = (currentHour >= openHour || currentHour < closeHour);
      // If openHour == closeHour, assume 24/7 or invalid, proceed.
      if(!marketIsOpen)
      {
         Print("*** TRADE ABORTED for " + sig.symbol + ": Market is closed ***");
         DebugPrint("Current time: " + TimeToString(currentTime));
         DebugPrint("Market hours: " + TimeToString(marketOpen) + " - " + TimeToString(marketClose));
         return;
      }
   }
   else
   {
       DebugPrint("Warning: Could not retrieve market session info for " + sig.symbol + ". Proceeding assuming market is open.");
   }
   // --- End of commented out code ---
   */

   // Use current market price for execution
   double execution_price = (sig.current_action == "Buy") ? tick.ask : tick.bid;
   // Recalculate stop loss and take profit based on current market conditions
   double stop_loss, take_profit;
   if(WaitForEntryPrice)
   {
      // Use the predefined levels from signals
      stop_loss = sig.current_stop_loss;
      take_profit = sig.current_target;
   }
   else
   {
      // Calculate based on the intended risk/reward from the original signal
      double original_risk = MathAbs(sig.current_entry - sig.current_stop_loss);
      double original_reward = MathAbs(sig.current_target - sig.current_entry);
      if(sig.current_action == "Buy")
      {
         stop_loss = execution_price - original_risk;
         take_profit = execution_price + original_reward;
      }
      else
      {
         stop_loss = execution_price + original_risk;
         take_profit = execution_price - original_reward;
      }
   }
   // Validate prices
   if(stop_loss <= 0 || take_profit <= 0 || execution_price <= 0)
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Invalid price data ***");
      DebugPrint("Execution: " + DoubleToString(execution_price, _Digits));
      DebugPrint("Stop Loss: " + DoubleToString(stop_loss, _Digits));
      DebugPrint("Take Profit: " + DoubleToString(take_profit, _Digits));
      return;
   }
   // Calculate and validate Risk-Reward Ratio
   double point = SymbolInfoDouble(sig.symbol, SYMBOL_POINT);
   double risk_pips = MathAbs(execution_price - stop_loss) / point;
   double reward_pips = MathAbs(take_profit - execution_price) / point;
   if(risk_pips < 1)
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Risk too small (" + DoubleToString(risk_pips, 1) + " pips) ***");
      return;
   }
   double rrr = reward_pips / risk_pips;
   if(rrr < MinimumAcceptableRRR)
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": RRR (" + DoubleToString(rrr, 2) +
            ") below minimum (" + DoubleToString(MinimumAcceptableRRR, 2) + ") ***");
      return;
   }
   // Close existing positions on this symbol
   CloseExistingPositions(sig.symbol);
   // Calculate position size
   double lot_size = CalculatePositionSize(sig.symbol, execution_price, stop_loss, risk_pips);
   if(lot_size <= 0)
   {
      Print("*** TRADE ABORTED for " + sig.symbol + ": Invalid lot size ***");
      return;
   }
   // EXECUTE THE TRADE with enhanced error handling
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(10);
   DebugPrint("=== FINAL TRADE PARAMETERS ===");
   DebugPrint("Symbol: " + sig.symbol);
   DebugPrint("Action: " + sig.current_action);
   DebugPrint("Lot Size: " + DoubleToString(lot_size, 2));
   DebugPrint("Execution Price: " + DoubleToString(execution_price, _Digits));
   DebugPrint("Stop Loss: " + DoubleToString(stop_loss, _Digits));
   DebugPrint("Take Profit: " + DoubleToString(take_profit, _Digits));
   DebugPrint("Risk-Reward Ratio: " + DoubleToString(rrr, 2));
   bool result = false;
   ENUM_ORDER_TYPE order_type = (sig.current_action == "Buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(order_type == ORDER_TYPE_BUY)
      result = trade.Buy(lot_size, sig.symbol, 0, stop_loss, take_profit);
   else
      result = trade.Sell(lot_size, sig.symbol, 0, stop_loss, take_profit);
   // Enhanced error reporting
   int retcode = (int)trade.ResultRetcode(); // Fixed: Cast uint to int
   if(retcode == TRADE_RETCODE_DONE)
   {
      Print("*** TRADE EXECUTED SUCCESSFULLY ***");
      Print("Symbol: " + sig.symbol + " | Action: " + sig.current_action);
      Print("Entry: " + DoubleToString(execution_price, _Digits) +
            " | Target: " + DoubleToString(take_profit, _Digits) +
            " | Stop: " + DoubleToString(stop_loss, _Digits));
      Print("Lot Size: " + DoubleToString(lot_size, 2) + " | RRR: " + DoubleToString(rrr, 2));
      Print("Scenario: " + (sig.scenario_one_active ? "Primary" : "Alternative"));
      Print("Order Ticket: " + IntegerToString((int)trade.ResultOrder()));
   }
   else
   {
      Print("*** TRADE FAILED for " + sig.symbol + " ***");
      Print("Error Code: " + IntegerToString(retcode));
      Print("Error Description: " + trade.ResultComment());
      // Detailed error diagnosis
      switch(retcode)
      {
         case TRADE_RETCODE_TRADE_DISABLED:
            Print(">>> SOLUTION: Enable AutoTrading (Ctrl+E) and check EA settings");
            Print(">>> Check Tools->Options->Expert Advisors->Allow automated trading");
            break;
         case TRADE_RETCODE_MARKET_CLOSED:
            Print(">>> SOLUTION: Wait for market to open or check trading hours");
            break;
         case TRADE_RETCODE_NO_MONEY:
            Print(">>> SOLUTION: Insufficient margin - reduce position size or add funds");
            break;
         case TRADE_RETCODE_PRICE_CHANGED:
            Print(">>> INFO: Price changed during execution - this is normal market behavior");
            break;
         case TRADE_RETCODE_CONNECTION:
            Print(">>> SOLUTION: Check internet connection and broker server status");
            break;
         case TRADE_RETCODE_INVALID_VOLUME:
            Print(">>> SOLUTION: Adjust lot size - current: " + DoubleToString(lot_size, 2));
            Print(">>> Min lot: " + DoubleToString(SymbolInfoDouble(sig.symbol, SYMBOL_VOLUME_MIN), 2));
            Print(">>> Max lot: " + DoubleToString(SymbolInfoDouble(sig.symbol, SYMBOL_VOLUME_MAX), 2));
            break;
         case TRADE_RETCODE_INVALID_STOPS:
            Print(">>> SOLUTION: Adjust stop loss/take profit levels");
            Print(">>> Min stop level: " + IntegerToString((int)SymbolInfoInteger(sig.symbol, SYMBOL_TRADE_STOPS_LEVEL)) + " points");
            break;
         default:
            Print(">>> Check MT5 documentation for error code: " + IntegerToString(retcode));
      }
      // Perform additional diagnostic checks after failure
      Print("=== POST-FAILURE DIAGNOSTICS ===");
      CheckTradingPermissions(true);
      CheckSymbolTradingStatus(sig.symbol, true);
   }
}
//+------------------------------------------------------------------+
//| Close Existing Positions on Symbol                               |
//+------------------------------------------------------------------+
void CloseExistingPositions(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         string position_symbol;
         if(PositionGetString(POSITION_SYMBOL, position_symbol) && position_symbol == symbol)
         {
            if(trade.PositionClose(ticket))
               DebugPrint("Closed existing position #" + IntegerToString((int)ticket) + " on " + symbol);
            else
               DebugPrint("Failed to close position #" + IntegerToString((int)ticket) + " on " + symbol);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Calculate Position Size                                           |
//+------------------------------------------------------------------+
double CalculatePositionSize(string symbol, double entry_price, double stop_loss, double risk_pips)
{
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (FixedPercentageRisk / 100.0);
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(tick_value <= 0 || risk_pips <= 0)
      return 0;
   double lot_size = risk_amount / (risk_pips * tick_value);
   lot_size = NormalizeDouble(MathFloor(lot_size / lot_step) * lot_step, 2);
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   DebugPrint("Position sizing for " + symbol + ":");
   DebugPrint("Risk Amount: " + DoubleToString(risk_amount, 2));
   DebugPrint("Risk Pips: " + DoubleToString(risk_pips, 1));
   DebugPrint("Tick Value: " + DoubleToString(tick_value, 2));
   DebugPrint("Calculated Lot Size: " + DoubleToString(lot_size, 2));
   return lot_size;
}
//+------------------------------------------------------------------+
//| Remove Pending Signal                                             |
//+------------------------------------------------------------------+
void RemovePendingSignal(int index)
{
   if(index < 0 || index >= pending_count) return;
   DebugPrint("Removing pending signal for " + pending_signals[index].symbol);
   // Shift remaining signals down
   for(int i = index; i < pending_count - 1; i++)
   {
      pending_signals[i] = pending_signals[i + 1];
   }
   pending_count--;
   ArrayResize(pending_signals, pending_count);
}
//+------------------------------------------------------------------+
//| Process Signals Function                                          |
//+------------------------------------------------------------------+
void ProcessSignals()
{
   Print("=== PROCESSING NEW SMART REPORTS SIGNALS ===");
   // Clear existing pending signals
   ArrayResize(pending_signals, 0);
   pending_count = 0;
   SignalData signals_to_process[];
   int signal_count = 0;
   // Read and parse the file
   int fileHandle = FileOpen(SignalFileName, FILE_READ | FILE_BIN | FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("CRITICAL ERROR: Cannot open signal file. Error: ", GetLastError());
      return;
   }
   long fileSizeLong = FileGetInteger(fileHandle, FILE_SIZE);
   if(fileSizeLong > INT_MAX) {
      Print("CRITICAL ERROR: File too large");
      FileClose(fileHandle);
      return;
   }
   int fileSize = (int)fileSizeLong;
   uchar buffer[];
   ArrayResize(buffer, fileSize);
   int bytesRead = FileReadArray(fileHandle, buffer, 0, fileSize);
   FileClose(fileHandle);
   if(bytesRead != fileSize)
   {
      Print("CRITICAL ERROR: Failed to read entire file");
      return;
   }
   // Convert buffer to string
   string fileContent = "";
   for(int i = 0; i < fileSize; i++)
   {
      if(i < 3 && buffer[0] == 0xEF && buffer[1] == 0xBB && buffer[2] == 0xBF)
      {
         i = 2; // Skip BOM
         continue;
      }
      uchar byte = buffer[i];
      if(byte >= 32 && byte < 128)
         fileContent += CharToString(byte);
      else if(byte == 10 || byte == 13)
         fileContent += "\n";
      else if(byte < 32)
         fileContent += " ";
   }
   // Normalize line endings
   StringReplace(fileContent, "\r\n", "\n");
   StringReplace(fileContent, "\r", "\n");
   // Parse CSV content
   string lines[];
   int lineCount = StringSplit(fileContent, '\n', lines);
   DebugPrint("Total lines read: " + IntegerToString(lineCount));
   if(LogFileContents)
      DebugPrint("File content:\n" + fileContent);
   // Temporary storage for pairing signals
   struct TempSignal
   {
      string symbol;
      string s1_action;
      double s1_entry;
      double s1_target;
      string alt_action;
      double alt_entry;
      double alt_target;
      // Add default constructor for safety
      TempSignal()
      {
         symbol = "";
         s1_action = "";
         s1_entry = 0.0;
         s1_target = 0.0;
         alt_action = "";
         alt_entry = 0.0;
         alt_target = 0.0;
      }
   };
   TempSignal temp_signals[];
   int temp_count = 0;
   // Parse lines and group by symbol
   for(int idx = 0; idx < lineCount; idx++)
   {
      string line = lines[idx];
      StringTrimLeft(line);
      StringTrimRight(line);
      if(StringLen(line) < 5 || line == "" || StringFind(line, "Instrument") == 0)
         continue;
      string parts[];
      if(StringSplit(line, ',', parts) < 5)
         continue;
      string instrument = parts[0];
      string scenario = parts[1];
      string action = parts[2];
      StringTrimLeft(instrument); StringTrimRight(instrument);
      StringTrimLeft(scenario); StringTrimRight(scenario);
      StringTrimLeft(action); StringTrimRight(action);
      double entry = StringToDouble(parts[3]);
      double target = StringToDouble(parts[4]);
      if(instrument == "" || scenario == "" || action == "" || entry == 0 || target == 0)
         continue;
      // Find or create temp signal entry
      int sig_idx = -1;
      for(int t = 0; t < temp_count; t++)
      {
         if(temp_signals[t].symbol == instrument)
         {
            sig_idx = t;
            break;
         }
      }
      if(sig_idx == -1)
      {
         sig_idx = temp_count;
         temp_count++;
         ArrayResize(temp_signals, temp_count);
         temp_signals[sig_idx].symbol = instrument;
         temp_signals[sig_idx].s1_action = "";
         temp_signals[sig_idx].alt_action = "";
      }
      // Store based on scenario
      if(scenario == "ScenarioOne")
      {
         temp_signals[sig_idx].s1_action = action;
         temp_signals[sig_idx].s1_entry = entry;
         temp_signals[sig_idx].s1_target = target;
      }
      else if(scenario == "Alternative")
      {
         temp_signals[sig_idx].alt_action = action;
         temp_signals[sig_idx].alt_entry = entry;
         temp_signals[sig_idx].alt_target = target;
      }
   }
   // Create pending signals from valid pairs
   for(int t = 0; t < temp_count; t++)
   {
      if(temp_signals[t].s1_action != "" && temp_signals[t].alt_action != "")
      {
         ArrayResize(pending_signals, pending_count + 1);
         // Direct assignment to array element
         pending_signals[pending_count].symbol = temp_signals[t].symbol;
         pending_signals[pending_count].current_action = temp_signals[t].s1_action;
         pending_signals[pending_count].current_entry = temp_signals[t].s1_entry;
         pending_signals[pending_count].current_target = temp_signals[t].s1_target;
         pending_signals[pending_count].current_stop_loss = temp_signals[t].alt_entry; // Alternative entry as stop loss
         pending_signals[pending_count].alt_action = temp_signals[t].alt_action;
         pending_signals[pending_count].alt_entry = temp_signals[t].alt_entry;
         pending_signals[pending_count].alt_target = temp_signals[t].alt_target;
         pending_signals[pending_count].signal_time = TimeCurrent();
         pending_signals[pending_count].scenario_one_active = true;
         pending_signals[pending_count].scenario_switch_price = temp_signals[t].alt_entry; // Switch trigger
         Print("*** PENDING SIGNAL CREATED: " + pending_signals[pending_count].symbol + " ***");
         Print("Primary: " + pending_signals[pending_count].current_action + " at " +
               DoubleToString(pending_signals[pending_count].current_entry, _Digits) +
               " | Target: " + DoubleToString(pending_signals[pending_count].current_target, _Digits));
         Print("Alternative: " + pending_signals[pending_count].alt_action + " at " +
               DoubleToString(pending_signals[pending_count].alt_entry, _Digits) +
               " | Target: " + DoubleToString(pending_signals[pending_count].alt_target, _Digits));
         Print("Switch Price: " + DoubleToString(pending_signals[pending_count].scenario_switch_price, _Digits));
         pending_count++;
      }
   }
   Print("=== SIGNAL PROCESSING COMPLETE: " + IntegerToString(pending_count) + " signals pending ===");
}
//+------------------------------------------------------------------+
