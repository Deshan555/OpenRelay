from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Device, SMSJob
from app.schemas import SMSSendRequest, SMSSendResponse, SMSBatchRequest, SMSBatchResponse
from app.websocket import manager

router = APIRouter(prefix="/sms", tags=["sms"])

@router.post("/send", response_model=SMSSendResponse)
async def send_sms(request: SMSSendRequest, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.uuid == request.device).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    job = SMSJob(device_uuid=device.uuid, recipient=request.to, message=request.message, status="PENDING")
    db.add(job)
    db.commit()
    db.refresh(job)
    websocket_payload = {"type": "SEND_SMS", "jobId": str(job.id), "to": job.recipient, "message": job.message}
    sent = await manager.send_personal_message(websocket_payload, device.uuid)
    if not sent:
        job.status = "FAILED"
        db.commit()
        raise HTTPException(status_code=503, detail="Device offline")
    return SMSSendResponse(jobId=job.id, status=job.status)

@router.post("/batch", response_model=SMSBatchResponse)
async def send_batch_sms(request: SMSBatchRequest, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.uuid == request.device).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    responses = []
    for msg in request.messages:
        job = SMSJob(device_uuid=device.uuid, recipient=msg.to, message=msg.message, status="PENDING")
        db.add(job)
        db.commit()
        db.refresh(job)
        websocket_payload = {"type": "SEND_SMS", "jobId": str(job.id), "to": job.recipient, "message": job.message}
        sent = await manager.send_personal_message(websocket_payload, device.uuid)
        if not sent:
            job.status = "FAILED"
            db.commit()
            responses.append(SMSSendResponse(jobId=job.id, status="FAILED"))
        else:
            responses.append(SMSSendResponse(jobId=job.id, status="PENDING"))
    return SMSBatchResponse(jobs=responses)
