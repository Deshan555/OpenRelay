import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.database_mongo import get_mongo_db
from app.schemas import DeviceRegisterRequest, DeviceRegisterResponseV2, DeviceResponseV2
from app.auth import create_access_token, get_current_admin
from app.logger import logger

router = APIRouter(prefix="/devices", tags=["devices"])

@router.get(
    "/",
    response_model=List[DeviceResponseV2],
    status_code=status.HTTP_200_OK,
    summary="Get all registered devices (v2)",
    description="Retrieves a list of all devices registered on the server (v2)."
)
async def get_all_devices(db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    logger.debug("V2: Fetch all registered devices requested.")
    cursor = db.devices.find({})
    devices = await cursor.to_list(length=100)
    return devices

@router.post(
    "/register",
    response_model=DeviceRegisterResponseV2,
    status_code=status.HTTP_200_OK,
    summary="Register or update a device (v2)",
    description="Registers a new device or updates an existing one, returning a JWT token with snake_case response payload keys (v2)."
)
async def register_device(request: DeviceRegisterRequest, db = Depends(get_mongo_db)):
    # Check if device already exists
    device = await db.devices.find_one({"uuid": request.uuid})
    
    token = create_access_token(data={"sub": request.uuid})
    now = datetime.datetime.utcnow()
    
    if device:
        # Update existing device info
        update_data = {
            "token": token,
            "last_seen": now
        }
        if request.name is not None:
             update_data["name"] = request.name
        if request.model is not None:
             update_data["model"] = request.model
        if request.android_version is not None:
             update_data["android_version"] = request.android_version
        if request.carrier is not None:
             update_data["carrier"] = request.carrier
        if request.latitude is not None:
             update_data["latitude"] = request.latitude
        if request.longitude is not None:
             update_data["longitude"] = request.longitude
             
        await db.devices.update_one({"uuid": request.uuid}, {"$set": update_data})
        logger.info(f"V2: Updated registration info for device UUID: {request.uuid}")
    else:
        # Create new device
        device_doc = {
            "uuid": request.uuid,
            "name": request.name,
            "model": request.model,
            "android_version": request.android_version,
            "carrier": request.carrier,
            "latitude": request.latitude,
            "longitude": request.longitude,
            "token": token,
            "status": "offline",
            "last_seen": now,
            "battery": None,
            "signal": None
        }
        await db.devices.insert_one(device_doc)
        logger.success(f"V2: Registered new device UUID: {request.uuid}")
    
    return DeviceRegisterResponseV2(device_id=request.uuid, token=token)

from pydantic import BaseModel

class DeviceConfigRequest(BaseModel):
    regular_interval: float

@router.post(
    "/{device_uuid}/config",
    status_code=status.HTTP_200_OK,
    summary="Update device config (v2)",
    description="Updates configuration parameters (like regular queue dispatch interval) for a device."
)
async def update_device_config(
    device_uuid: str,
    request: DeviceConfigRequest,
    db = Depends(get_mongo_db),
    admin: dict = Depends(get_current_admin)
):
    device = await db.devices.find_one({"uuid": device_uuid})
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {device_uuid} not found"
        )
    await db.devices.update_one(
        {"uuid": device_uuid},
        {"$set": {"regular_interval": request.regular_interval}}
    )
    logger.info(f"Updated configuration for device {device_uuid}: regular_interval={request.regular_interval}s")
    return {"detail": "Configuration updated successfully", "regular_interval": request.regular_interval}
