import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.database_mongo import get_mongo_db
from app.schemas import SMSSendRequestV2, SMSSendResponseV2, SMSBatchRequestV2, SMSBatchResponseV2
from app.websocket import manager
from app.logger import logger

router = APIRouter(prefix="/sms", tags=["sms"])

@router.post(
    "/send",
    response_model=SMSSendResponseV2,
    status_code=status.HTTP_200_OK,
    summary="Send a single SMS (v2)",
    description="Dispatches a single SMS request to the specified registered device using snake_case params (v2)."
)
async def send_sms(request: SMSSendRequestV2, db = Depends(get_mongo_db)):
    # Verify device exists
    device = await db.devices.find_one({"uuid": request.device_id})
    if not device:
        logger.error(f"V2 Send SMS failed: Device '{request.device_id}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device_id} not found"
        )
    
    # Create SMS Job in database
    job_doc = {
        "device_uuid": device["uuid"],
        "recipient": request.to,
        "message": request.message,
        "status": "PENDING",
        "created_at": datetime.datetime.utcnow(),
        "sent_at": None
    }
    result = await db.sms_jobs.insert_one(job_doc)
    job_id = str(result.inserted_id)
    job_status = "PENDING"
    logger.info(f"V2: Created SMS Job {job_id} for device {device['uuid']}")
    
    # Try to push via WebSocket (using v2 keys)
    websocket_payload = {
        "type": "SEND_SMS",
        "job_id": job_id,
        "to": request.to,
        "message": request.message
    }
    
    sent = await manager.send_personal_message(websocket_payload, device["uuid"])
    
    if not sent:
        job_status = "FAILED"
        await db.sms_jobs.update_one({"_id": result.inserted_id}, {"$set": {"status": "FAILED"}})
        logger.error(f"V2: Failed to push SMS Job {job_id}: Device {device['uuid']} is offline.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Device is currently offline"
        )
    
    return SMSSendResponseV2(job_id=job_id, status=job_status)

@router.post(
    "/batch",
    response_model=SMSBatchResponseV2,
    status_code=status.HTTP_200_OK,
    summary="Send a batch of SMS messages (v2)",
    description="Accepts multiple recipient and message pairs using snake_case params to dispatch them to a single registered device (v2)."
)
async def send_batch_sms(request: SMSBatchRequestV2, db = Depends(get_mongo_db)):
    device = await db.devices.find_one({"uuid": request.device_id})
    if not device:
        logger.error(f"V2 Send Batch SMS failed: Device '{request.device_id}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device_id} not found"
        )
        
    responses = []
    logger.info(f"V2: Processing batch of {len(request.messages)} SMS messages for device {device['uuid']}")
    
    for msg in request.messages:
        job_doc = {
            "device_uuid": device["uuid"],
            "recipient": msg.to,
            "message": msg.message,
            "status": "PENDING",
            "created_at": datetime.datetime.utcnow(),
            "sent_at": None
        }
        result = await db.sms_jobs.insert_one(job_doc)
        job_id = str(result.inserted_id)
        job_status = "PENDING"
        
        websocket_payload = {
            "type": "SEND_SMS",
            "job_id": job_id,
            "to": msg.to,
            "message": msg.message
        }
        
        sent = await manager.send_personal_message(websocket_payload, device["uuid"])
        if not sent:
            job_status = "FAILED"
            await db.sms_jobs.update_one({"_id": result.inserted_id}, {"$set": {"status": "FAILED"}})
            logger.error(f"V2: Failed to push SMS Job {job_id} from batch: Device {device['uuid']} is offline.")
            responses.append(SMSSendResponseV2(job_id=job_id, status="FAILED"))
        else:
            responses.append(SMSSendResponseV2(job_id=job_id, status="PENDING"))
            
    return SMSBatchResponseV2(jobs=responses)
