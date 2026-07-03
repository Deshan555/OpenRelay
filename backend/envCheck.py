import os
from dotenv import load_dotenv

load_dotenv()

api_id = int(os.getenv('TELEGRAM_APP_ID'))
api_hash = os.getenv('TELEGRAM_APP_HASH')


print(f"ID: {api_id}")
print(f"Hash: {api_hash[:10]}...")  # Don't print full hash
