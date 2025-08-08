import os
import re
import logging
import csv
import json
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import pdfplumber

# --- Configuration ---
API_KEY_FILE = 'PDF_Trader_Bot/python_processor/api_key.txt'
SYMBOLS_FILE = 'PDF_Trader_Bot/python_processor/symbols.txt'
SYMBOL_MAPPING_FILE = 'PDF_Trader_Bot/python_processor/symbol_mapping.json'
DATA_DIR = 'data'
DOWNLOAD_DIR = os.path.join(DATA_DIR, 'downloaded_pdfs')

# --- The 100% correct path confirmed by the Pathfinder EA ---
OUTPUT_CSV_FILE = '/Users/pawan/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/users/user/AppData/Roaming/MetaQuotes/Terminal/Common/Files/signals.csv'

# --- Setup Logging ---
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# --- Function to securely load the API key ---
def get_telegram_token(file_path: str) -> str:
    """Reads the Telegram bot token from a specified file."""
    logger.info(f"Loading Telegram token from {file_path}")
    try:
        with open(file_path, 'r') as file:
            token = file.read().strip()
            if not token:
                raise ValueError("API key file is empty.")
            return token
    except FileNotFoundError:
        logger.error(f"CRITICAL: Telegram API key file '{file_path}' not found.")
        raise
    except Exception as e:
        logger.error(f"CRITICAL: Failed to read API key: {e}")
        raise

# --- Function to load the symbols ---
def load_symbols_to_find(file_path: str) -> list:
    """Loads a list of symbols from a simple text file."""
    logger.info(f"Loading symbols from {file_path}")
    try:
        with open(file_path, 'r') as f:
            symbols = [line.strip() for line in f if line.strip()]
            logger.info(f"Successfully loaded {len(symbols)} symbols.")
            return symbols
    except FileNotFoundError:
        logger.error(f"CRITICAL: The symbol file '{file_path}' was not found.")
        return []

# --- Function to load PDF->Broker symbol mapping ---
def load_symbol_mapping(file_path: str) -> dict:
    """Loads a JSON mapping from PDF symbols to broker-specific symbols."""
    logger.info(f"Loading symbol mapping from {file_path}")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            mapping = json.load(f)
            if not isinstance(mapping, dict):
                raise ValueError("Mapping file must contain a JSON object (key/value pairs)")
            logger.info(f"Loaded {len(mapping)} mapping entries.")
            return mapping
    except FileNotFoundError:
        logger.warning(f"Symbol mapping file '{file_path}' not found. Proceeding without mapping.")
        return {}
    except Exception as e:
        logger.error(f"Failed to load symbol mapping: {e}. Proceeding without mapping.")
        return {}

# --- PDF Text Extraction ---
def extract_text_from_pdf(pdf_path: str) -> str:
    """Opens a PDF file using pdfplumber and returns all its text content."""
    logger.info(f"Extracting text with pdfplumber from: {pdf_path}")
    text = ""
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        logger.info("Successfully extracted text from PDF.")
        return text
    except Exception as e:
        logger.error(f"Failed to read PDF file {pdf_path}: {e}")
        return ""

# --- Robust Signal Parsing Function ---
def parse_all_signals(text: str, symbols: list) -> list:
    """
    Parses the text by explicitly searching for each symbol from the provided list.
    This version handles optional colons in the 'Alternative' scenario.
    """
    logger.info("Starting targeted signal parsing based on symbol list.")
    all_signals = []

    scenario_one_pattern = re.compile(r"Scenario one:\s*(Sell|Buy).*?around\s+([\d.]+).*?target price of\s+([\d.]+)", re.IGNORECASE | re.DOTALL)
    alternative_pattern = re.compile(r"Alternative:?\s*(Sell|Buy).*?around\s+([\d.]+).*?target price of\s+([\d.]+)", re.IGNORECASE | re.DOTALL)

    for symbol in symbols:
        block_pattern = re.compile(f"{re.escape(symbol)}.*?Comment:.*?$", re.IGNORECASE | re.DOTALL | re.MULTILINE)
        block_match = block_pattern.search(text)
        if not block_match:
            logger.warning(f"Could not find a signal block for symbol: {symbol}")
            continue
        block_text = block_match.group(0)

        s1_match = scenario_one_pattern.search(block_text)
        if s1_match:
            all_signals.append({"Instrument": symbol, "Scenario": "ScenarioOne", "Action": s1_match.group(1).strip(), "Entry": float(s1_match.group(2).strip()), "Target": float(s1_match.group(3).strip())})
        
        alt_match = alternative_pattern.search(block_text)
        if alt_match:
            all_signals.append({"Instrument": symbol, "Scenario": "Alternative", "Action": alt_match.group(1).strip(), "Entry": float(alt_match.group(2).strip()), "Target": float(alt_match.group(3).strip())})

    logger.info(f"Successfully parsed {len(all_signals)} total signals from the provided list.")
    return all_signals

# --- Function to write signals to a CSV file ---
def write_signals_to_csv(signals: list, file_path: str, symbol_mapping: dict):
    """
    Writes signals to CSV, applying PDF->broker symbol mapping when available.
    """
    if not signals:
        logger.warning("No signals to write to CSV.")
        return

    try:
        # Using 'utf-8-sig' to handle the BOM for better compatibility with some CSV readers
        with open(file_path, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, fieldnames=["Instrument", "Scenario", "Action", "Entry", "Target"])
            writer.writeheader()
            for signal in signals:
                modified_signal = signal.copy()
                pdf_symbol = signal['Instrument']
                broker_symbol = symbol_mapping.get(pdf_symbol, pdf_symbol)
                if broker_symbol == pdf_symbol:
                    logger.warning(f"No mapping found for '{pdf_symbol}'. Using as-is.")
                modified_signal["Instrument"] = broker_symbol
                writer.writerow(modified_signal)
        
        logger.info(f"Successfully wrote {len(signals)} signals (with broker symbol mapping) to {file_path}")
        # Setting permissions to ensure the MT5 terminal can read the file
        os.chmod(file_path, 0o777)
        logger.info(f"Set permissions for {file_path} to 0o777")
    except Exception as e:
        logger.error(f"Failed to write CSV file or set permissions: {e}")

# --- Document Handler (The Core Logic) ---
async def document_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Main workflow: load symbols, download PDF, process, and write CSV."""
    symbols_to_find = context.bot_data.get('symbols_to_find')
    symbol_mapping = context.bot_data.get('symbol_mapping', {})
    if not symbols_to_find:
        await update.message.reply_text("Error: Symbol list not loaded. Check logs.")
        return
    try:
        document = update.message.document
        download_path = os.path.join(DOWNLOAD_DIR, document.file_name)
        
        logger.info(f"Received PDF: {document.file_name}")
        pdf_file = await document.get_file()
        await pdf_file.download_to_drive(download_path)
        await update.message.reply_text(f"PDF received. Processing based on {len(symbols_to_find)} symbols...")
        
        extracted_text = extract_text_from_pdf(download_path)
        if not extracted_text:
            await update.message.reply_text("Processing failed: Could not extract text from PDF.")
            return

        parsed_signals = parse_all_signals(extracted_text, symbols_to_find)
        if not parsed_signals:
            await update.message.reply_text("Processing failed: No valid signals were found in the PDF.")
            return
            
        write_signals_to_csv(parsed_signals, OUTPUT_CSV_FILE, symbol_mapping)
        await update.message.reply_text(f"Processing complete! Saved {len(parsed_signals)} signals to {OUTPUT_CSV_FILE}.")
    except Exception as e:
        logger.error(f"Critical error in document_handler: {e}")
        await update.message.reply_text("An unexpected error occurred. Please check the logs for details.")

# --- Start Command Handler ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Sends a welcome message."""
    await update.message.reply_text(
        "Hello! I am your FX Smart Report bot.\n"
        "I am configured to process PDF documents only."
    )

# --- Main Function ---
def main() -> None:
    """Load configs, create folders, and start the bot."""
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    logger.info(f"Ensured data directory exists: {DOWNLOAD_DIR}")
    try:
        TELEGRAM_TOKEN = get_telegram_token(API_KEY_FILE)
        symbols = load_symbols_to_find(SYMBOLS_FILE)
        symbol_mapping = load_symbol_mapping(SYMBOL_MAPPING_FILE)
        if not symbols:
            logger.error(f"Symbol file '{SYMBOLS_FILE}' is empty or missing. Bot cannot proceed.")
            return

        # Build and run the application
        application = Application.builder().token(TELEGRAM_TOKEN).build()
        application.bot_data['symbols_to_find'] = symbols
        application.bot_data['symbol_mapping'] = symbol_mapping

        # Register the handlers
        application.add_handler(CommandHandler("start", start))
        # This handler will ONLY trigger for messages that contain a PDF document
        application.add_handler(MessageHandler(filters.Document.PDF, document_handler))
        
        print("Bot is listening for PDF documents... Press Ctrl+C to stop.")
        application.run_polling()
    except Exception as e:
        logger.error(f"FATAL Error on startup: {e}")
        print(f"FATAL Error on startup: {e}. Please check the log for details.")

if __name__ == '__main__':
    main()