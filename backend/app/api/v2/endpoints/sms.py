import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.database_mongo import get_mongo_db
from app.auth import get_current_admin
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
async def send_sms(request: SMSSendRequestV2, db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    # Verify device exists and is online
    device = await db.devices.find_one({"uuid": request.device_id})
    if not device:
        logger.error(f"V2 Send SMS failed: Device '{request.device_id}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device_id} not found"
        )
    
    # Create SMS queue entry
    now = datetime.datetime.utcnow()
    queue_doc = {
        "device_uuid": device["uuid"],
        "phone_number": request.to,
        "message": request.message,
        "queue_type": "PRIORITY",
        "status": "QUEUED",
        "retry_count": 0,
        "failed_devices": [],
        "created_at": now,
        "updated_at": now
    }
    result = await db.sms_queue.insert_one(queue_doc)
    job_id = str(result.inserted_id)
    
    # Create legacy SMS Job in database for backwards compatibility
    job_doc = {
        "_id": result.inserted_id,
        "device_uuid": device["uuid"],
        "recipient": request.to,
        "message": request.message,
        "status": "PENDING",
        "created_at": now,
        "sent_at": None
    }
    await db.sms_jobs.insert_one(job_doc)
    logger.info(f"V2: Queued Priority SMS Job {job_id} for device {device['uuid']}")
    
    return SMSSendResponseV2(job_id=job_id, status="QUEUED")

@router.post(
    "/batch",
    response_model=SMSBatchResponseV2,
    status_code=status.HTTP_200_OK,
    summary="Send a batch of SMS messages (v2)",
    description="Accepts multiple recipient and message pairs using snake_case params to dispatch them to a single registered device (v2)."
)
async def send_batch_sms(request: SMSBatchRequestV2, db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    device = await db.devices.find_one({"uuid": request.device_id})
    if not device:
        logger.error(f"V2 Send Batch SMS failed: Device '{request.device_id}' does not exist.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with UUID {request.device_id} not found"
        )
        
    responses = []
    logger.info(f"V2: Queueing priority batch of {len(request.messages)} SMS messages for device {device['uuid']}")
    
    for msg in request.messages:
        now = datetime.datetime.utcnow()
        queue_doc = {
            "device_uuid": device["uuid"],
            "phone_number": msg.to,
            "message": msg.message,
            "queue_type": "PRIORITY",
            "status": "QUEUED",
            "retry_count": 0,
            "failed_devices": [],
            "created_at": now,
            "updated_at": now
        }
        result = await db.sms_queue.insert_one(queue_doc)
        job_id = str(result.inserted_id)
        
        job_doc = {
            "_id": result.inserted_id,
            "device_uuid": device["uuid"],
            "recipient": msg.to,
            "message": msg.message,
            "status": "PENDING",
            "created_at": now,
            "sent_at": None
        }
        await db.sms_jobs.insert_one(job_doc)
        responses.append(SMSSendResponseV2(job_id=job_id, status="QUEUED"))
            
    return SMSBatchResponseV2(jobs=responses)

from typing import Optional
import math

@router.get(
    "/logs",
    status_code=status.HTTP_200_OK,
    summary="Get SMS job logs (v2)",
    description="Retrieves a paginated list of single and batch SMS jobs with optional search filtering."
)
async def get_sms_logs(
    page: int = 1,
    page_size: int = 10,
    search: Optional[str] = None,
    status: Optional[str] = None,
    db = Depends(get_mongo_db),
    admin: dict = Depends(get_current_admin)
):
    query = {}
    if status and status != "ALL":
        query["status"] = status
    if search:
        # Match case-insensitively across recipient, message, device_uuid, or status
        regex_query = {"$regex": search, "$options": "i"}
        search_or = [
            {"recipient": regex_query},
            {"message": regex_query},
            {"device_uuid": regex_query},
            {"status": regex_query}
        ]
        if "status" in query:
            query = {"$and": [{"status": query["status"]}, {"$or": search_or}]}
        else:
            query["$or"] = search_or
        
    total_count = await db.sms_jobs.count_documents(query)
    skip_count = (page - 1) * page_size
    
    cursor = db.sms_jobs.find(query).sort([("created_at", -1)]).skip(skip_count).limit(page_size)
    logs = await cursor.to_list(length=page_size)
    
    for log in logs:
        log["_id"] = str(log["_id"])
        if "created_at" in log and isinstance(log["created_at"], datetime.datetime):
            log["created_at"] = log["created_at"].isoformat()
        if "sent_at" in log and isinstance(log["sent_at"], datetime.datetime):
            log["sent_at"] = log["sent_at"].isoformat()
            
    return {
        "logs": logs,
        "total_count": total_count,
        "page": page,
        "page_size": page_size,
        "total_pages": math.ceil(total_count / page_size) if page_size > 0 else 0
    }
