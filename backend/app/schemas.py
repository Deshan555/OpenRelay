from pydantic import BaseModel
from typing import List, Optional

class DeviceRegisterRequest(BaseModel):
    uuid: str
    name: Optional[str] = None
    model: Optional[str] = None
    android_version: Optional[str] = None
    carrier: Optional[str] = None

class DeviceRegisterResponse(BaseModel):
    deviceId: str
    token: str

class SMSSendRequest(BaseModel):
    device: str
    to: str
    message: str

class SMSSendResponse(BaseModel):
    jobId: int
    status: str

class SMSBatchMessage(BaseModel):
    to: str
    message: str

class SMSBatchRequest(BaseModel):
    device: str
    messages: List[SMSBatchMessage]

class SMSBatchResponse(BaseModel):
    jobs: List[SMSSendResponse]

class DeviceStatusUpdate(BaseModel):
    battery: Optional[int] = None
    signal: Optional[int] = None
    status: Optional[str] = None
