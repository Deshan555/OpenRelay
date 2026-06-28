import os

class Settings:
    PROJECT_NAME: str = "OpenRelay SMS Gateway"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./openrelay.db")
    JWT_SECRET: str = os.getenv("JWT_SECRET", "super-secret-key-change-in-production")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 365

settings = Settings()
