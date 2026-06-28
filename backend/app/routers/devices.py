import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Device
from app.schemas import DeviceRegisterRequest, DeviceRegisterResponse
from app.auth import create_access_token
from app.logger import logger

router = APIRouter(prefix="/devices", tags=["devices"])

@router.post(
    "/register",
    response_model=DeviceRegisterResponse,
    status_code=status.HTTP_200_OK,
    summary="Register or update a device",
    description="Registers a new Android device with the server, or updates its metadata if it is already registered. Returns a JWT access token to authenticate subsequent API and WebSocket requests."
)
def register_device(request: DeviceRegisterRequest, db: Session = Depends(get_db)):
    """
    Registers a new Android device and returns a JWT access token.
    
    - **uuid**: Unique identifier of the device (typically Android ID or custom hardware UUID).
    - **name**: Human-readable name given to the device.
    - **model**: Device hardware model (e.g. Pixel 6).
    - **android_version**: OS version running on the device.
    - **carrier**: Mobile network carrier name.
    """
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
        logger.info(f"Updated registration info for device UUID: {request.uuid} (Name: {request.name})")
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
        logger.success(f"Registered new device UUID: {request.uuid} (Name: {request.name})")
    
    db.commit()
    db.refresh(device)
    
    return DeviceRegisterResponse(deviceId=device.uuid, token=token)

