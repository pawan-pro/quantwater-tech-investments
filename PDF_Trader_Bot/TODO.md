# Project To-Do List: PDF-to-MT5 Trading Bot

## ✅ Completed Milestones

-   **[x] Foundational Setup:** Project structure, Telegram bot creation, and file handling are all complete.
-   **[x] Python Signal Parsing (English & Arabic):** The Python script can successfully parse reports in both English and Arabic.
-   **[x] EA Core Development:** The EA can monitor for files, parse the CSV, calculate risk, and execute basic trades.
-   **[x] VPS Deployment & Initial Testing:** The full system has been deployed and tested end-to-end on a demo account.

---

## Phase 1: Core Logic Overhaul (Immediate Priority)

*   **Goal:** Refactor the EA's logic to be adaptive, prioritizing the latest signals and correctly managing the full trade lifecycle as defined below.

-   [ ] **Task 1.1: Implement "Prioritize Latest Report" Logic with Continuation**
    -   **Objective:** Ensure the EA always acts on the most recent signal file, intelligently distinguishing between conflicting and continuation signals.
    -   **Location:** This logic must be implemented within the `ProcessSignals()` function when an existing `PendingSignal` is found.
    -   **Required Logic Flow:**
        1.  When a new signal arrives for a symbol that has a `PendingSignal`, first check if there is a live position open.
        2.  **If a live position exists:**
            *   Compare the direction of the live trade with the direction of the new signal.
            *   **If Directions CONFLICT (e.g., live BUY, new SELL):**
                a.  Close the live position using `CloseExistingPositions()`.
                b.  Overwrite the `PendingSignal` with the new data.
                c.  Reset state flags: `scenario_one_executed = false`, `alternative_executed = false`.
                d.  Log the conflict and reset.
            *   **If Directions are the SAME (Continuation):**
                a.  **Do NOT close the trade.**
                b.  Update the `PendingSignal` in memory with the new Stop Loss and Take Profit.
                c.  Use `trade.PositionModify()` to update the live trade's SL and TP to the new values.
                d.  **Do NOT reset the state flags.**
                e.  Log the modification.
        3.  **If no live position exists:**
            *   Simply overwrite the old `PendingSignal` with the new data and reset the state flags, as the old signal was never triggered.

-   [ ] **Task 1.2: Overhaul EA Signal Lifecycle & State Management**
    -   **Objective:** Refactor the EA to correctly handle the two-stage scenario switching and to remember which instruments have completed their lifecycle for the day.
    -   **Required Logic Flow:**
        1.  **State Management:**
            *   The `PendingSignal` struct must contain two boolean flags: `bool scenario_one_executed;` and `bool alternative_executed;`.
        2.  **Daily Memory:**
            *   Implement a global `string traded_symbols_today[]` array.
            *   This array must be automatically cleared at the start of each new trading day.
        3.  **Core Execution Logic (`CheckEntryConditions`):**
            *   **Pre-Check:** Before evaluating any signal, check if its symbol is in the `traded_symbols_today` array. If so, ignore the signal.
            *   **Scenario Switch:** If `scenario_one_active` is `true`, check if the market has hit the `scenario_switch_price`. If it has, close any open position, set `scenario_one_active = false`, and log the switch.
            *   **Trade Entry:** Only execute a trade if the corresponding flag (`scenario_one_executed` or `alternative_executed`) is `false`.
            *   **Post-Execution:**
                *   After a **ScenarioOne** trade, set `scenario_one_executed = true`. The signal remains active.
                *   After an **Alternative** trade, set `alternative_executed = true`. The lifecycle is complete. Add the symbol to `traded_symbols_today` and remove the `PendingSignal`.

---

## Phase 2: Prop Firm Risk Management Layer (High Priority)

*   **Goal:** Implement portfolio-level risk controls to protect the trading account.

-   [ ] **Task: Implement Global Daily Drawdown Limit**
-   [ ] **Task: Implement Maximum Concurrent Trades Limit**

---

## Phase 3: Future Enhancements (Strategy & Scoring)

*   **Goal:** Evolve the EA into an intelligent system that selects the highest-probability trades.

-   [ ] **Task: Develop a Signal Prioritization & Scoring System**