import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "OpenRelay SMS Gateway"
    PROJECT_DESCRIPTION: str = (
        "OpenRelay is a self-hosted SMS Gateway that allows developers to "
        "send SMS messages through their own Android devices via REST and WebSocket APIs."
    )
    API_VERSION: str = "1.0.0"
    
    # Swagger & OpenAPI configs (configurable endpoints)
    DOCS_URL: str = os.getenv("DOCS_URL", "/docs")
    REDOC_URL: str = os.getenv("REDOC_URL", "/redoc")
    OPENAPI_URL: str = os.getenv("OPENAPI_URL", "/openapi.json")
    ENABLE_DOCS: bool = os.getenv("ENABLE_DOCS", "True").lower() in ("true", "1", "yes")

    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./openrelay.db")
    MONGO_URI: str = os.getenv("MONGO_URI", "mongodb://localhost:27017")
    MONGO_DB_NAME: str = os.getenv("MONGO_DB_NAME", "openrelay")
    JWT_SECRET: str = os.getenv("JWT_SECRET", "super-secret-key-change-in-production")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 365  # Long lived for devices, or refresh token flow later

settings = Settings()

