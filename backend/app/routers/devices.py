import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Device
from app.schemas import DeviceRegisterRequest, DeviceRegisterResponse
from app.auth import create_access_token
from app.logger import logger

router = APIRouter(prefix="/devices", tags=["devices"])

@router.post("/register", response_model=DeviceRegisterResponse)
def register_device(request: DeviceRegisterRequest, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.uuid == request.uuid).first()
    token = create_access_token(data={"sub": request.uuid})
    if device:
        device.name = request.name or device.name
        device.model = request.model or device.model
        device.android_version = request.android_version or device.android_version
        device.carrier = request.carrier or device.carrier
        device.last_seen = datetime.datetime.utcnow()
        device.token = token
        logger.info(f"Updated registration info for device UUID: {request.uuid} (Name: {request.name})")
    else:
        device = Device(
            uuid=request.uuid,
            name=request.name,
            model=request.model,
            android_version=request.android_version,
            carrier=request.carrier,
            token=token
        )
        db.add(device)
        logger.success(f"Registered new device UUID: {request.uuid} (Name: {request.name})")
    db.commit()
    db.refresh(device)
    return DeviceRegisterResponse(deviceId=device.uuid, token=token)
