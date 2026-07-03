import os
import random
import asyncio
from dotenv import load_dotenv

from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest, DeleteContactsRequest
from telethon.tl.types import InputPhoneContact
from telethon.errors import FloodWaitError

# Load .env
load_dotenv()

API_ID = int(os.getenv("TELEGRAM_APP_ID"))
API_HASH = os.getenv("TELEGRAM_APP_HASH")
PHONE = os.getenv("TELEGRAM_APP_PHONE")

client = TelegramClient("session", API_ID, API_HASH)


async def check_number(phone_number: str):
    try:
        # create temp contact
        contact = InputPhoneContact(
            client_id=random.randint(1, 2**63 - 1),
            phone=phone_number,
            first_name="Temp",
            last_name="Check"
        )

        # IMPORT CONTACT (IMPORTANT: await in Telethon 2.x)
        result = await client(ImportContactsRequest([contact]))

        # If user exists
        if result.users:
            user = result.users[0]

            # cleanup temp contact
            await client(DeleteContactsRequest(id=result.users))

            return {
                "phone": phone_number,
                "on_telegram": True,
                "id": user.id,
                "username": user.username,
                "name": user.first_name,
                "bot": user.bot,
                "premium": getattr(user, "premium", False),
            }

        return {
            "phone": phone_number,
            "on_telegram": False
        }

    except FloodWaitError as e:
        return {
            "phone": phone_number,
            "error": f"FloodWait: wait {e.seconds} seconds"
        }

    except Exception as e:
        return {
            "phone": phone_number,
            "error": str(e)
        }


async def main():
    await client.start(phone=PHONE)

    number = input("Enter phone number (+947...): ").strip()

    result = await check_number(number)

    print("\nRESULT")
    print("-" * 40)
    for k, v in result.items():
        print(f"{k}: {v}")

    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())