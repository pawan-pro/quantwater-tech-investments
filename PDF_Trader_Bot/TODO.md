# Project To-Do List: PDF-to-MT5 Trading Bot

### **Week 1: Foundations and Signal Reception**
*   **Summary:** All foundational tasks are complete. The project has a working Telegram bot capable of receiving and extracting text from a PDF.
-   [x] **Completed:** Environment Setup & Project Structuring
-   [x] **Completed:** Creating and Testing the Telegram Bot
-   [x] **Completed:** Handling File Downloads
-   [x] **Completed:** PDF Text Extraction
-   [x] **Completed:** Initial Signal Parsing (Proof of Concept)

---

### **Week 2: Full Signal Parsing & EA Communication**
*   **Summary:** All data processing tasks are complete. The Python script is robust, correctly parsing all required data and creating a clean `signals.csv` file ready for the EA.
-   [x] **Completed:** Parsing All Instruments
-   [x] **Completed:** Handling Both Scenarios (including fix for missing colons)
-   [x] **Completed:** Creating the Communication File (`signals.csv`)
-   [x] **Completed:** Identifying the MT5 Data Folder Path
-   [x] **Completed:** Code Review and Refinement (robust logger and error handling added)

---

### **Week 3: MT5 Expert Advisor (EA) Development**
*   **Summary:** All core development tasks for the Expert Advisor are complete. The provided MQL5 code implements the full trading logic we designed.
-   [x] Create a new Expert Advisor in MetaEditor
-   [x] Implement file monitoring and reading (`OnTimer`, `FileGetInteger`)
-   [x] Parse the `signals.csv` file within the EA
        [x] EA reading only prices in the CSV, not symbols. 
-   [x] Implement core trading logic (SL/TP based on Alternative's entry)
-   [x] Implement **Expectancy Filter** to validate trades based on RRR
-   [x] Implement **Fixed Percentage Risk** for position sizing
-   [X] Implement basic trade execution using the `CTrade` library
        [x] Some trades are not being placed due to invalid prices 
-   [ ] Implement logic to avoid duplicate trades and close old trades on new signal arrival

---

### **Week 4: Deployment, Testing, and Refinement (Current Phase)**
*   **Goal:** Set up the complete system on the Virtual Private Server (VPS), conduct thorough end-to-end testing on a **demo account**, and refine the logic based on performance.

-   [x] **Task: Set up the VPS Environment**
    -   [x] Connect to your VPS via RDP.
    -   [x] Install Python 3.x.
    -   [x] Install the MT5 Terminal.
    -   [x] Install the required Python libraries: `pip install python-telegram-bot --upgrade pdfplumber`.

-   [x] **Task: Configure the System Components**
    -   [x] Create the project folder on the VPS (e.g., `C:\TraderBot`).
    -   [x] Place the `bot_listener.py`, `api_key.txt`, and `symbols.txt` files inside.
    -   [x] **Crucially:** In MT5, go to `File > Open Data Folder`, navigate to `MQL5\Files`, copy the path, and update the `OUTPUT_CSV_FILE` variable in `bot_listener.py`.
    -   [x] Start the Python script from the command line: `python C:\TraderBot\bot_listener.py`.
    -   [x] Compile the `SignalProcessorEA.mq5` code in MetaEditor and drag it onto a chart.

-   [x] **Task: Full End-to-End Testing (on a Demo Account)**
    -   [x] Send the PDF report to your Telegram bot.
    -   [x] **Verify Python Script:** Check the script's console output to ensure it downloaded and processed the file without errors.
    -   [x] **Verify CSV Creation:** Check that the `signals.csv` file appears in the `MQL5\Files` directory and its content is correct.
    -   [x] **Verify EA Detection:** Check the EA's "Experts" tab in the MT5 Toolbox to confirm it detected the "New signal file".
    -   [] **Verify EA Logic:** Check the EA log to confirm:
        -   [ ] Correct RRR was calculated.
        -   [ ] The RRR passed the `MinimumAcceptableRRR` filter.
        -   [x] The correct Lot Size was calculated.
    -   [ ] **Verify Trade Execution:** Check that the trade was opened on the demo account with the **exact Stop Loss and Take Profit levels** calculated by the EA.

-   [ ] **Task: Logic Refinement & Hardening**
    -   [ ] Based on testing, consider improving the entry logic. The current version enters at market price; you could modify it to use pending orders (`TRADE_ACTION_PENDING`) for more precise entries.
    -   [ ] Add more detailed logging to a separate log file for easier debugging over time.
    -   [ ] Review the "close on new signal" logic to ensure it behaves as expected across different market conditions.
---------------------------------------------------

    [ ] prioritization
    [ ] # of trades and SL sizing, if applicable. the SL size is enough to absorb EA impact probably, or technicals align with expected outcome and vice versa. 
    [ ] continuation of previous day's trade (can be used in priorization) | trend can be utilized to analyze the continuation pattern, taking into consideration the rrr as well

---
### **EA Logic Updates (Based on Performance Analysis - Aug 8, 2025)**

*   **Goal:** Refine the EA's trade execution and management logic to improve robustness, prevent premature stop-outs, and align its behavior with the strategic intent of the signals.

-   [ ] **Task 1: Correct the Risk-Reward Ratio (RRR) Calculation**
    -   **Issue:** The current RRR calculation is inaccurate because it does not account for the market spread.
    -   **Required Change:** Modify the RRR calculation to be "spread-aware."
        -   For **Sell Trades**, the risk must be calculated from the **Stop Loss** to the current **Ask Price**.
        -   For **Buy Trades**, the risk must be calculated from the **Stop Loss** to the current **Bid Price**.
    -   **Impact:** Ensures the EA only takes trades that meet the RRR criteria based on the *true, executable risk*.

-   [ ] **Task 2: Change Signal Expiration to "Session Validity"**
    -   **Issue:** The 60-minute timer is not aligned with the nature of the signals, which are based on persistent trends and levels.
    -   **Required Change:** Remove the `MaxWaitMinutes` time-based expiration logic. Signals will now only be cleared from the pending list when a new `signals.csv` file is processed.
    -   **Impact:** Maximizes the opportunity to enter every valid trade for that session.

-   [ ] **Task 3: Implement Dynamic (ATR-Based) Entry Tolerance**
    -   **Issue:** The static `EntryTolerancePips` is not adaptive to changing market volatility.
    -   **Required Change:** Replace the static pip tolerance with a dynamic tolerance based on the Average True Range (ATR).
        1.  Add a new input parameter, e.g., `input double EntryToleranceATR_Percent = 0.25;`.
        2.  Before checking the entry condition, calculate the current ATR for the symbol.
        3.  Calculate the dynamic tolerance in price points: `tolerance = ATR_value * EntryToleranceATR_Percent`.
    -   **Impact:** The EA will automatically adapt its entry zone to market conditions, improving entry quality.

-   [ ] **Task 4: Add a Stop Loss "Breathing Room" Check**
    -   **Issue:** The EA can enter trades where the entry price is dangerously close to the stop loss, leading to immediate stop-outs due to the spread.
    -   **Required Change:** Add a final pre-trade safety check in the `ExecuteTradeFromSignal` function.
        1.  Add a new input parameter, e.g., `input double SpreadMultiplierForStop = 2.0;` (minimum stop distance in multiples of the spread).
        2.  Before executing the trade, calculate the required minimum distance: `min_stop_distance = spread * SpreadMultiplierForStop`.
        3.  Check if the distance between the entry price and the stop loss (accounting for spread) is greater than `min_stop_distance`. If not, abort the trade.
    -   **Impact:** Prevents the EA from taking trades that are tactically unviable due to the current spread, dramatically reducing instant stop-outs.

-   [ ] **Task 5: Implement Trade Continuation Logic**
    -   **Issue:** The EA currently closes existing positions before opening new ones, preventing profitable trades from continuing on subsequent signals in the same direction.
    -   **Required Change:**
        1.  In `ExecuteTradeFromSignal`, before closing positions, check if a position already exists for the symbol in the *same direction* as the new signal.
        2.  If a "continuation" is found, do **not** close the existing trade. Instead, use `trade.PositionModify(...)` to update its Stop Loss and Take Profit to the new signal's levels.
        3.  If no existing trade is found, or if it's in the opposite direction, proceed with the original logic of closing and opening a new trade.
    -   **Impact:** Allows the EA to systematically ride a trend by adjusting the parameters of an existing trade, rather than closing it prematurely.