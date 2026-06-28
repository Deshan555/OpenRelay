import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=True)
    model = Column(String, nullable=True)
    android_version = Column(String, nullable=True)
    battery = Column(Integer, nullable=True)
    carrier = Column(String, nullable=True)
    signal = Column(Integer, nullable=True)
    status = Column(String, default="offline")
    last_seen = Column(DateTime, default=datetime.datetime.utcnow)
    token = Column(String, nullable=True)

    jobs = relationship("SMSJob", back_populates="device")

class SMSJob(Base):
    __tablename__ = "sms_jobs"

    id = Column(Integer, primary_key=True, index=True)
    device_uuid = Column(String, ForeignKey("devices.uuid"), nullable=False)
    recipient = Column(String, nullable=False)
    message = Column(String, nullable=False)
    status = Column(String, default="PENDING")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    sent_at = Column(DateTime, nullable=True)

    device = relationship("Device", back_populates="jobs")
