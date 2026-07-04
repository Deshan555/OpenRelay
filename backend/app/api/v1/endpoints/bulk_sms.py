import csv
import io
import datetime
from typing import List

from fastapi import APIRouter, Depends, File, UploadFile, BackgroundTasks, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import BulkSmsLog, Device
from app.schemas import BulkSmsRow
from app.websocket import manager
from app.logger import logger
from app.config import settings
from app.database_mongo import get_mongo_client

router = APIRouter(prefix="/admin", tags=["admin"])

def select_client() -> str:
    """Select the best available mobile client based on signal strength and availability.
    Returns the device UUID of the selected client or raises HTTPException if none available.
    """
    client = get_mongo_client()
    db = client[settings.MONGO_DB_NAME]
    collection = db["mobile_clients"]
    doc = collection.find_one({"available": True}, sort=[("signal_strength", -1)])
    if not doc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="No available mobile clients")
    return doc.get("device_uuid")

async def process_bulk_sms(rows: List[BulkSmsRow], db: Session):
    for row in rows:
        try:
            device_uuid = select_client()
            device = db.query(Device).filter(Device.uuid == device_uuid).first()
            if not device:
                logger.error(f"Selected device {device_uuid} not found in DB")
                continue
            # Create log entry
            log_entry = BulkSmsLog(
                device_uuid=device.uuid,
                phone_number=row.phone_number,
                message=row.message,
                status="PENDING"
            )
            db.add(log_entry)
            db.commit()
            db.refresh(log_entry)
            payload = {
                "type": "SEND_SMS",
                "jobId": str(log_entry.id),
                "to": row.phone_number,
                "message": row.message
            }
            sent = await manager.send_personal_message(payload, device.uuid)
            if sent:
                log_entry.status = "SENT"
                log_entry.sent_at = datetime.datetime.utcnow()
            else:
                log_entry.status = "FAILED"
            db.commit()
        except Exception as e:
            logger.error(f"Error processing bulk SMS row {row}: {e}")

@router.post(
    "/bulk-sms",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Upload CSV for bulk SMS sending",
    description="Accept a CSV file containing phone_number, message, and optional name columns. Messages are sent via the best available connected mobile client."
)
async def upload_bulk_sms(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db)
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
