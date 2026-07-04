from fastapi import APIRouter
from app.api.v2.endpoints import devices, sms, websocket, bulk_sms, admin_auth

api_router = APIRouter()
api_router.include_router(admin_auth.router)
api_router.include_router(devices.router)
api_router.include_router(sms.router)
api_router.include_router(bulk_sms.router)
api_router.include_router(websocket.router)
