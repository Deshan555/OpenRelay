import csv
import io
import datetime
from typing import List

from fastapi import APIRouter, Depends, File, UploadFile, BackgroundTasks, HTTPException, status

from app.schemas import BulkSmsRow
from app.websocket import manager
from app.logger import logger
from app.database_mongo import get_mongo_db

router = APIRouter(prefix="/admin", tags=["admin"])

async def select_client(db) -> str:
    """Select the best available connected mobile client based on signal strength.
    Returns the device UUID of the selected client or raises HTTPException if none available.
    """
    active_uuids = list(manager.active_connections.keys())
    if not active_uuids:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, 
            detail="No available mobile clients connected via WebSocket"
        )
    
    # Query database for active devices, sorted by signal descending
    cursor = db.devices.find({"uuid": {"$in": active_uuids}})
    cursor = cursor.sort([("signal", -1)])
    devices_list = await cursor.to_list(length=100)
    
    if not devices_list:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, 
            detail="No available mobile clients found in database"
        )
        
    return devices_list[0]["uuid"]

async def process_bulk_sms(rows: List[BulkSmsRow], db):
    for row in rows:
        try:
            device_uuid = await select_client(db)
            device = await db.devices.find_one({"uuid": device_uuid})
            if not device:
                logger.error(f"V2 Select device {device_uuid} not found in DB")
                continue
            
            # Create bulk SMS log entry in MongoDB
            log_doc = {
                "device_uuid": device["uuid"],
                "phone_number": row.phone_number,
                "message": row.message,
                "status": "PENDING",
                "created_at": datetime.datetime.utcnow(),
                "sent_at": None
            }
            result = await db.bulk_sms_logs.insert_one(log_doc)
            log_id = str(result.inserted_id)
            
            # Send message using WebSocket
            payload = {
                "type": "SEND_SMS",
                "job_id": log_id,
                "to": row.phone_number,
                "message": row.message
            }
            sent = await manager.send_personal_message(payload, device["uuid"])
            if sent:
                await db.bulk_sms_logs.update_one(
                    {"_id": result.inserted_id},
                    {"$set": {"status": "SENT", "sent_at": datetime.datetime.utcnow()}}
                )
            else:
                await db.bulk_sms_logs.update_one(
                    {"_id": result.inserted_id},
                    {"$set": {"status": "FAILED"}}
                )
        except Exception as e:
            logger.error(f"V2 Error processing bulk SMS row {row}: {e}")

@router.post(
    "/bulk-sms",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Upload CSV for bulk SMS sending (v2)",
    description="Accept a CSV file containing phone_number, message, and optional name columns. Messages are sent via the best available connected mobile client (v2)."
)
async def upload_bulk_sms(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db = Depends(get_mongo_db)
):
    if file.content_type != "text/csv":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid file type. CSV required.")
    
    content = await file.read()
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unable to decode CSV file.")
    
    reader = csv.DictReader(io.StringIO(text))
    rows: List[BulkSmsRow] = []
    for idx, row in enumerate(reader, start=1):
        if "phone_number" not in row or "message" not in row:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Missing required columns in CSV at line {idx}")
        rows.append(BulkSmsRow(phone_number=row["phone_number"], message=row["message"], name=row.get("name")))
    
    background_tasks.add_task(process_bulk_sms, rows, db)
    return {"detail": f"Bulk SMS processing started for {len(rows)} rows"}

@router.get(
    "/bulk-sms/logs",
    status_code=status.HTTP_200_OK,
    summary="Get bulk SMS logs (v2)",
    description="Retrieves processed bulk SMS logs."
)
async def get_bulk_sms_logs(db = Depends(get_mongo_db)):
    cursor = db.bulk_sms_logs.find({}).sort([("created_at", -1)]).limit(100)
    logs = await cursor.to_list(length=100)
    for log in logs:
        log["_id"] = str(log["_id"])
        if "created_at" in log and isinstance(log["created_at"], datetime.datetime):
            log["created_at"] = log["created_at"].isoformat()
        if "sent_at" in log and isinstance(log["sent_at"], datetime.datetime):
            log["sent_at"] = log["sent_at"].isoformat()
    return logs
