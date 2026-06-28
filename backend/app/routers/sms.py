from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Device, SMSJob
from app.schemas import SMSSendRequest, SMSSendResponse, SMSBatchRequest, SMSBatchResponse
from app.websocket import manager
from app.logger import logger

router = APIRouter(prefix="/sms", tags=["sms"])

@router.post(
    "/send",
    response_model=SMSSendResponse,
    status_code=status.HTTP_200_OK,
    summary="Send a single SMS",
    description="Dispatches a single SMS request to the specified registered device. The device must be online and connected via WebSocket to process the send command. Returns the job ID and status."
)
async def send_sms(request: SMSSendRequest, db: Session = Depends(get_db)):
    """
    Triggers sending a single SMS message through a target Android device.

    - **device**: The UUID of the registered target Android device.
    - **to**: Recipient phone number (e.g. +1234567890).
    - **message**: Text body content of the SMS.
    """
    # Verify device exists
    device = db.query(Device).filter(Device.uuid == request.device).first()
    if not device:
        logger.error(f"Send SMS failed: Device '{request.device}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device} not found"
        )
    
    # Create SMS Job in database
    job = SMSJob(
        device_uuid=device.uuid,
        recipient=request.to,
        message=request.message,
        status="PENDING"
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    logger.info(f"Created SMS Job {job.id} for device {device.uuid} (recipient: {request.to})")
    
    # Try to push via WebSocket
    websocket_payload = {
        "type": "SEND_SMS",
        "jobId": str(job.id),
        "to": job.recipient,
        "message": job.message
    }
    
    sent = await manager.send_personal_message(websocket_payload, device.uuid)
    
    if not sent:
        # Device is not connected or send failed
        job.status = "FAILED"
        db.commit()
        logger.error(f"Failed to push SMS Job {job.id}: Device {device.uuid} is offline.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Device is currently offline"
        )
    
    return SMSSendResponse(jobId=job.id, status=job.status)

@router.post(
    "/batch",
    response_model=SMSBatchResponse,
    status_code=status.HTTP_200_OK,
    summary="Send a batch of SMS messages",
    description="Accepts multiple recipient and message pairs to dispatch them to a single registered device. Pushes individual send tasks sequentially to the device's active WebSocket connection."
)
async def send_batch_sms(request: SMSBatchRequest, db: Session = Depends(get_db)):
    """
    Triggers sending multiple SMS messages through a target Android device.

    - **device**: The UUID of the registered target Android device.
    - **messages**: Array of message objects, each containing:
        - **to**: Recipient phone number.
        - **message**: Text body content of the SMS.
    """
    device = db.query(Device).filter(Device.uuid == request.device).first()
    if not device:
        logger.error(f"Send Batch SMS failed: Device '{request.device}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device} not found"
        )
        
    responses = []
    logger.info(f"Processing batch of {len(request.messages)} SMS messages for device {device.uuid}")
    
    for msg in request.messages:
        job = SMSJob(
            device_uuid=device.uuid,
            recipient=msg.to,
            message=msg.message,
            status="PENDING"
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        
        websocket_payload = {
            "type": "SEND_SMS",
            "jobId": str(job.id),
            "to": job.recipient,
            "message": job.message
        }
        
        sent = await manager.send_personal_message(websocket_payload, device.uuid)
        if not sent:
            job.status = "FAILED"
            db.commit()
            logger.error(f"Failed to push SMS Job {job.id} from batch: Device {device.uuid} is offline.")
            responses.append(SMSSendResponse(jobId=job.id, status="FAILED"))
        else:
            responses.append(SMSSendResponse(jobId=job.id, status="PENDING"))
            
    return SMSBatchResponse(jobs=responses)

