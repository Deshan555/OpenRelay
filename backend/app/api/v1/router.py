from fastapi import APIRouter
from app.api.v1.endpoints import devices, sms, websocket, bulk_sms

api_router = APIRouter()
api_router.include_router(devices.router)
api_router.include_router(sms.router)
api_router.include_router(bulk_sms.router)
api_router.include_router(websocket.router)
