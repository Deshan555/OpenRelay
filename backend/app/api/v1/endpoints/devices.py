import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Device
from app.schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse
from app.auth import create_access_token
from app.logger import logger

router = APIRouter(prefix="/devices", tags=["devices"])

@router.get(
    "/",
    response_model=List[DeviceResponse],
    status_code=status.HTTP_200_OK,
    summary="Get all registered devices (v1)",
    description="Retrieves a list of all devices registered on the server."
)
def get_all_devices(db: Session = Depends(get_db)):
    logger.debug("V1: Fetch all registered devices requested.")
    devices = db.query(Device).all()
    return devices

@router.post(
    "/register",
    response_model=DeviceRegisterResponse,
    status_code=status.HTTP_200_OK,
    summary="Register or update a device (v1)",
    description="Registers a new device or updates an existing one, returning a JWT token."
)
def register_device(request: DeviceRegisterRequest, db: Session = Depends(get_db)):
    # Check if device already exists
    device = db.query(Device).filter(Device.uuid == request.uuid).first()
    
    token = create_access_token(data={"sub": request.uuid})
    
    if device:
        # Update existing device info
        device.name = request.name or device.name
        device.model = request.model or device.model
        device.android_version = request.android_version or device.android_version
        device.carrier = request.carrier or device.carrier
        device.last_seen = datetime.datetime.utcnow()
        device.token = token
        if request.latitude is not None:
             device.latitude = request.latitude
        if request.longitude is not None:
             device.longitude = request.longitude
        logger.info(f"V1: Updated registration info for device UUID: {request.uuid}")
    else:
        # Create new device
        device = Device(
            uuid=request.uuid,
            name=request.name,
            model=request.model,
            android_version=request.android_version,
            carrier=request.carrier,
            latitude=request.latitude,
            longitude=request.longitude,
            token=token
        )
        db.add(device)
        logger.success(f"V1: Registered new device UUID: {request.uuid}")
    
    db.commit()
    db.refresh(device)
    
    return DeviceRegisterResponse(deviceId=device.uuid, token=token)
