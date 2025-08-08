import logging
from telethon import TelegramClient, events

# --- Function to securely load the API id & hash from api_id.txt ---
def load_api_credentials():
    """
    Load API ID and API Hash from a file named 'api_id.txt'.
    The file should contain two lines: first line is API ID, second line is API Hash.
    """
    try:
        with open('api_id.txt', 'r') as file:
            api_id = int(file.readline().strip())
            api_hash = file.readline().strip()
            return api_id, api_hash
    except Exception as e:
        # Add logging here for better debugging
        logging.error("Could not load API credentials. Ensure 'api_id.txt' exists and contains valid credentials.")
        raise ValueError("Could not load API credentials.") from e

# --- Call the function to load the credentials ---
# This is the new, essential part that was missing.
API_ID, API_HASH = load_api_credentials()

# The channel/user you are forwarding FROM
# You can get the ID by forwarding a message from the channel to a bot like @userinfobot
SOURCE_CHANNEL_ID = -1001464460412  # Replace with the Equiti Group channel ID

# The bot you are forwarding TO
DESTINATION_BOT_USERNAME = 'MyAssetSignalBot' # Replace with your bot's username

# --- Logging Setup ---
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Create the client and connect ---
# Now, this line will work because API_ID and API_HASH exist.
client = TelegramClient('forwarder.session', API_ID, API_HASH)

@client.on(events.NewMessage(chats=SOURCE_CHANNEL_ID))
async def handle_new_message(event):
    """
    This function is triggered whenever a new message appears in the source channel.
    It forwards the message to the destination bot.
    """
    logger.info(f"New message received from source channel. Forwarding to {DESTINATION_BOT_USERNAME}...")
    try:
        # Forward the message to your bot
        await client.forward_messages(DESTINATION_BOT_USERNAME, event.message)
        logger.info("Message forwarded successfully.")
    except Exception as e:
        logger.error(f"Failed to forward message: {e}")

async def main():
    """Main function to start the client."""
    logger.info("Starting the forwarder client...")
    await client.start()
    logger.info("Client started. Listening for new messages...")
    await client.run_until_disconnected()

if __name__ == '__main__':
    with client:
        client.loop.run_until_complete(main())