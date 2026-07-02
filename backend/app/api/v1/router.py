from fastapi import APIRouter
from app.api.v1.endpoints import devices, sms, websocket

api_router = APIRouter()
api_router.include_router(devices.router)
api_router.include_router(sms.router)
api_router.include_router(websocket.router)
