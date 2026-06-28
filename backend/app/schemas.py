
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# Device registration
class DeviceRegisterRequest(BaseModel):
    uuid: str
    name: Optional[str] = None
    model: Optional[str] = None
    android_version: Optional[str] = None
    carrier: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class DeviceRegisterResponse(BaseModel):
    deviceId: str
    token: str

class DeviceResponse(BaseModel):
    uuid: str
    name: Optional[str] = None
    model: Optional[str] = None
    android_version: Optional[str] = None
    battery: Optional[int] = None
    carrier: Optional[str] = None
    signal: Optional[int] = None
    status: str
    last_seen: datetime
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    class Config:
        from_attributes = True


# SMS sending
class SMSSendRequest(BaseModel):
    device: str  # device UUID
    to: str
    message: str

class SMSSendResponse(BaseModel):
    jobId: int
    status: str

# Batch SMS sending
class SMSBatchMessage(BaseModel):
    to: str
    message: str

class SMSBatchRequest(BaseModel):
    device: str
    messages: List[SMSBatchMessage]

class SMSBatchResponse(BaseModel):
    jobs: List[SMSSendResponse]

# WebSocket updates from Android device
class DeviceStatusUpdate(BaseModel):
    battery: Optional[int] = None
    signal: Optional[int] = None
    status: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

