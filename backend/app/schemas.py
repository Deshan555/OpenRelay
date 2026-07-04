

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# ==================== V1 Schemas ====================

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

class BulkSmsRow(BaseModel):
    phone_number: str
    message: str
    name: Optional[str] = None

class SMSBatchResponse(BaseModel):
    jobs: List[SMSSendResponse]

# WebSocket updates from Android device
class DeviceStatusUpdate(BaseModel):
    battery: Optional[int] = None
    signal: Optional[int] = None
    status: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


# ==================== V2 Schemas ====================

class DeviceRegisterResponseV2(BaseModel):
    device_id: str
    token: str

class DeviceResponseV2(BaseModel):
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

class SMSSendRequestV2(BaseModel):
    device_id: str  # snake_case instead of device
    to: str
    message: str

class SMSSendResponseV2(BaseModel):
    job_id: str  # snake_case instead of jobId, changed to str for MongoDB ObjectIds
    status: str

class SMSBatchRequestV2(BaseModel):
    device_id: str  # snake_case instead of device
    messages: List[SMSBatchMessage]

class SMSBatchResponseV2(BaseModel):
    jobs: List[SMSSendResponseV2]


