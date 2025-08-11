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

-   [ ] **Task-TBU: Implement Full Signal Lifecycle Logic (High Priority)**
    -   **Objective:** Refactor the EA's core logic to correctly handle the switch from "ScenarioOne" to the "Alternative" scenario, preventing the EA from discarding the alternative plan after the first trade is executed.
    -   **Required Logic Flow:**
        1.  **Signal Persistence:** The `PendingSignal` object for an instrument must remain in memory even after the "ScenarioOne" trade is executed.
        2.  **Concurrent Monitoring:** While "ScenarioOne" is active, the EA must monitor for both its entry condition and the "switch condition" (price crossing the alternative scenario's entry).
        3.  **Scenario Invalidation:** If the switch condition is met (e.g., the stop-loss is hit), the EA must invalidate "ScenarioOne", update its internal state to make the "Alternative" scenario active, and begin monitoring for the alternative entry.
        4.  **Lifecycle Completion:** The `PendingSignal` should only be removed after the "Alternative" trade is executed or the trading session ends.
    
- [ ] **Task-TBU:No English. Parsing of Arabic Signals.**  
    [ ] **Task-TBU: Add Support for Arabic PDF Reports**
        -   **Objective:** Modify the Python parsing script (`bot_listener.py`) to handle reports where the text is in Arabic.
        -   **Proposed Logic:**
            1.  **Symbol-Centric Parsing:** Instead of searching for the English keyword "Instrument", the script will iterate through the known symbols in `symbols.txt` to locate signal blocks within the PDF text.
            2.  **Keyword Matching:** Hardcode the Arabic words for "Buy" (`شراء`) and "Sell" (`بيع`) to correctly identify the trade action.
            3.  **Structural Assumption:** Rely on the report's structure, assuming the first instance of a symbol is "ScenarioOne" and the second is the "Alternative".
        -   **Goal:** Enable the bot to successfully parse both English and Arabic reports without requiring full translation.
    
---------------------------------------------------

    [ ] prioritization
    [ ] # of trades and SL | sizing, if applicable. the SL size is enough to absorb EA impact probably, or technicals align with expected outcome and vice versa. 
    [ ] continuation of previous day's trade (can be used in priorization) | trend can be utilized to analyze the continuation pattern, taking into consideration the rrr as well
    [ ] alternate scenario XAUUSD not executed. 202050811. too many trades and all negative. second pdf arrived in Arabic language.
    [ ] Crypto not covered as of now.  
    
    