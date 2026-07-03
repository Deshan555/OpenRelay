from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

class MongoClientManager:
    client: AsyncIOMotorClient = None

mongo_manager = MongoClientManager()

def get_mongo_client():
    if mongo_manager.client is None:
        # tlsAllowInvalidCertificates=True bypasses macOS local SSL issuer certificate validation errors
        mongo_manager.client = AsyncIOMotorClient(settings.MONGO_URI, tlsAllowInvalidCertificates=True)
    return mongo_manager.client

async def get_mongo_db():
    """
    FastAPI dependency that returns the database instance.
    If the client is not yet initialized via lifespan, it will lazy-initialize here.
    """
    client = get_mongo_client()
    return client[settings.MONGO_DB_NAME]
