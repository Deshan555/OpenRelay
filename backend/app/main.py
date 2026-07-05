import json
import datetime
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.config import settings
from app.database import Base, engine
from app.logger import logger

from contextlib import asynccontextmanager
from app.database_mongo import mongo_manager, get_mongo_client

# Import versioned routers
from app.api.v1.router import api_router as api_router_v1
from app.api.v2.router import api_router as api_router_v2

# Create tables
logger.info("Initializing database tables...")
Base.metadata.create_all(bind=engine)
logger.success("Database tables initialized successfully.")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize MongoDB client
    logger.info(f"Connecting to MongoDB at {settings.MONGO_URI}...")
    client = get_mongo_client()
    logger.success("Connected to MongoDB successfully.")
    
    # Initialize indexes
    db = client[settings.MONGO_DB_NAME]
    await db.sms_queue.create_index([
        ("device_uuid", 1),
        ("queue_type", 1),
        ("status", 1),
        ("created_at", 1)
    ])
    # Index optimized for claim-based queue processing (dynamic device sharing)
    await db.sms_queue.create_index([
        ("queue_type", 1),
        ("status", 1),
        ("device_uuid", 1),
        ("created_at", 1)
    ])
    logger.success("SMS queue indexes initialized.")

    # Start background queue manager
    from app.queue_manager import start_queue_worker
    start_queue_worker()
    logger.success("Background SMS queue workers started.")

    yield
    # Shutdown: Close MongoDB connection
    if mongo_manager.client:
        mongo_manager.client.close()
        logger.info("Closed MongoDB connection.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.API_VERSION,
    docs_url=settings.DOCS_URL if settings.ENABLE_DOCS else None,
    redoc_url=settings.REDOC_URL if settings.ENABLE_DOCS else None,
    openapi_url=settings.OPENAPI_URL if settings.ENABLE_DOCS else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Versioned router registration
app.include_router(api_router_v1, prefix="/api/v1")
app.include_router(api_router_v2, prefix="/api/v2")

# Backward-compatible legacy aliases (pointing directly to v1 endpoints)
app.include_router(api_router_v1)

@app.get("/")
def read_root():
    logger.debug("Root endpoint accessed.")
    return {
        "message": "OpenRelay SMS Gateway API is running",
        "versions": {
            "v1": "/api/v1",
            "v2": "/api/v2"
        }
    }
