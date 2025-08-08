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
-   [x] Implement basic trade execution using the `CTrade` library
        [x] Some trades are not being placed due to invalid prices 
-   [x] Implement logic to avoid duplicate trades and close old trades on new signal arrival

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
    -   [x] **Verify EA Logic:** Check the EA log to confirm:
        -   [x] Correct RRR was calculated.
        -   [x] The RRR passed the `MinimumAcceptableRRR` filter.
        -   [x] The correct Lot Size was calculated.
    -   [x] **Verify Trade Execution:** Check that the trade was opened on the demo account with the **exact Stop Loss and Take Profit levels** calculated by the EA.

-   [ ] **Task: Logic Refinement & Hardening**
    -   [ ] Based on testing, consider improving the entry logic. The current version enters at market price; you could modify it to use pending orders (`TRADE_ACTION_PENDING`) for more precise entries.
    -   [ ] Add more detailed logging to a separate log file for easier debugging over time.
    -   [ ] Review the "close on new signal" logic to ensure it behaves as expected across different market conditions.


---
### **EA Logic Updates (Based on Performance Analysis - Aug 8, 2025)**

*   **Goal:** Refine the EA's trade execution and management logic to improve robustness, prevent premature stop-outs, and align its behavior with the strategic intent of the signals.

-   [x] **Task 1: Correct the Risk-Reward Ratio (RRR) Calculation**
-   [x] **Task 2: Change Signal Expiration to "Session Validity"**
-   [x] **Task 3: Implement Dynamic (ATR-Based) Entry Tolerance**
-   [x] **Task 4: Add a Stop Loss "Breathing Room" Check**
-   [x] **Task 5: Implement Trade Continuation Logic**

-   [ ] **Task 6: Refine Trade Continuation Logic**
    -   **Issue:** The EA opens a new trade if `PositionModify` fails because the SL/TP levels are identical to the existing ones.
    -   **Required Change:** After attempting to modify a position, check if the modification failed *and* if the SL/TP levels are the same. If both are true, treat it as a successful continuation and prevent a new trade from opening.
    -   **Impact:** Prevents duplicate positions when a new signal has the same parameters as an existing trade.

-   [ ] **Task 7: Add a Cap to ATR Entry Tolerance**
    -   **Issue:** The ATR-based tolerance can be excessively large during high volatility, leading to entries far from the intended price.
    -   **Required Change:** Add a new input parameter, e.g., `input double MaxEntryTolerancePips = 25.0;`. When calculating the entry tolerance, use the *minimum* value between the ATR calculation and the fixed `MaxEntryTolerancePips`.
    -   **Impact:** Provides the benefits of dynamic tolerance while preventing runaway entries in extreme market conditions.

-   [ ] **Task 8: Implement Broker-Specific Symbol Mapping**
    -   **Issue:** The Python script extracts generic symbol names (e.g., "US30") from the PDF, but the broker requires specific names (e.g., "US30Roll").
    -   **Required Change:**
        1.  Create a new file, `symbol_mapping.json`, to store the mapping between PDF names and broker symbols.
        2.  Update `bot_listener.py` to read this mapping file.
        3.  When writing to `signals.csv`, the script should now use the mapping to translate the PDF name to the correct, tradable broker symbol.
    -   **Impact:** Ensures the EA receives the correct symbols to trade, preventing "invalid symbol" errors.

---------------------------------------------------

    [ ] prioritization
    [ ] # of trades and SL sizing, if applicable. the SL size is enough to absorb EA impact probably, or technicals align with expected outcome and vice versa. 
    [ ] continuation of previous day's trade (can be used in priorization) | trend can be utilized to analyze the continuation pattern, taking into consideration the rrr as well