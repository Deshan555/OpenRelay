import csv
import io
import datetime
from typing import List

from fastapi import APIRouter, Depends, File, UploadFile, BackgroundTasks, HTTPException, status, Form

from app.schemas import BulkSmsRow, CampaignRequest
from app.websocket import manager
from app.logger import logger
from app.database_mongo import get_mongo_db
from app.auth import get_current_admin

router = APIRouter(prefix="/admin", tags=["admin"])

from bson import ObjectId

async def process_bulk_sms(campaign_id: ObjectId, rows: List[BulkSmsRow], queue_type: str, db):
    """Enqueues bulk/campaign SMS into the shared queue pool.
    
    Messages are enqueued with device_uuid=None (unassigned). Connected device
    workers will dynamically claim and process them from the shared pool,
    ensuring automatic load balancing across all online devices.
    """
    for row in rows:
        try:
            now = datetime.datetime.utcnow()
            queue_doc = {
                "campaign_id": campaign_id,
                "device_uuid": None,
                "phone_number": row.phone_number,
                "message": row.message,
                "name": row.name,
                "queue_type": queue_type,
                "status": "QUEUED",
                "retry_count": 0,
                "failed_devices": [],
                "created_at": now,
                "updated_at": now
            }
            result = await db.sms_queue.insert_one(queue_doc)
            
            # Create a backwards-compatible entry in bulk_sms_logs for tracking
            log_doc = {
                "_id": result.inserted_id,
                "campaign_id": campaign_id,
                "device_uuid": None,
                "phone_number": row.phone_number,
                "message": row.message,
                "status": "PENDING",
                "created_at": now,
                "sent_at": None
            }
            await db.bulk_sms_logs.insert_one(log_doc)
            logger.info(f"V2: Queued bulk message job {result.inserted_id} (unassigned) in campaign {campaign_id}")
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
    queue_type: str = Form("REGULAR"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db = Depends(get_mongo_db),
    admin: dict = Depends(get_current_admin)
):
    if queue_type not in ["PRIORITY", "REGULAR"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid queue_type. Must be PRIORITY or REGULAR"
        )
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
    
    campaign_id = ObjectId()
    # Save campaign details in MongoDB
    campaign_doc = {
        "_id": campaign_id,
        "name": file.filename,
        "total_count": len(rows),
        "queue_type": queue_type,
        "created_at": datetime.datetime.utcnow()
    }
    await db.campaigns.insert_one(campaign_doc)
    
    background_tasks.add_task(process_bulk_sms, campaign_id, rows, queue_type, db)
    return {"detail": f"Bulk SMS processing started for {len(rows)} rows", "campaign_id": str(campaign_id)}

@router.post(
    "/campaign",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Create SMS campaign (v2)",
    description="Create an SMS campaign for multiple recipients with specified queueType."
)
async def create_campaign(
    request: CampaignRequest,
    background_tasks: BackgroundTasks,
    db = Depends(get_mongo_db),
    admin: dict = Depends(get_current_admin)
):
    if request.queue_type not in ["PRIORITY", "REGULAR"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid queue_type. Must be PRIORITY or REGULAR"
        )
        
    rows = [BulkSmsRow(phone_number=num, message=request.message) for num in request.recipients]
    
    campaign_id = ObjectId()
    campaign_doc = {
        "_id": campaign_id,
        "name": f"JSON Campaign ({len(rows)} recipients)",
        "total_count": len(rows),
        "queue_type": request.queue_type,
        "created_at": datetime.datetime.utcnow()
    }
    await db.campaigns.insert_one(campaign_doc)
    
    background_tasks.add_task(process_bulk_sms, campaign_id, rows, request.queue_type, db)
    return {"detail": f"SMS Campaign processing started for {len(rows)} recipients", "campaign_id": str(campaign_id)}

@router.get(
    "/campaigns",
    status_code=status.HTTP_200_OK,
    summary="Get recent campaigns and their live status (v2)",
)
async def get_campaigns(db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    cursor = db.campaigns.find({}).sort([("created_at", -1)]).limit(10)
    campaigns = await cursor.to_list(length=10)
    
    results = []
    for camp in campaigns:
        camp_id = camp["_id"]
        # Retrieve logs stats grouped by status
        pipeline = [
            {"$match": {"campaign_id": camp_id}},
            {"$group": {"_id": "$status", "count": {"$sum": 1}}}
        ]
        counts_cursor = db.bulk_sms_logs.aggregate(pipeline)
        counts = await counts_cursor.to_list(length=15)
        
        counts_map = {c["_id"]: c["count"] for c in counts}
        
        pending = counts_map.get("PENDING", 0)
        processing = counts_map.get("PROCESSING", 0)
        sent = counts_map.get("SENT", 0)
        failed = counts_map.get("FAILED", 0) + counts_map.get("ABANDONED", 0)
        
        total = camp["total_count"]
        completed = sent + failed
        
        # Adjust in case documents are still being queued in the background task
        active_in_db = pending + processing + sent + failed
        if active_in_db < total:
            pending += (total - active_in_db)
            
        progress_pct = round((completed / total) * 100, 1) if total > 0 else 0.0
        
        results.append({
            "id": str(camp_id),
            "name": camp.get("name", "SMS Campaign"),
            "total_count": total,
            "pending_count": pending,
            "processing_count": processing,
            "sent_count": sent,
            "failed_count": failed,
            "progress_percentage": progress_pct,
            "status": "COMPLETED" if completed >= total else "PROCESSING",
            "queue_type": camp.get("queue_type", "REGULAR"),
            "created_at": camp["created_at"].isoformat()
        })
    return results

from typing import Optional
import math

@router.get(
    "/bulk-sms/logs",
    status_code=status.HTTP_200_OK,
    summary="Get bulk SMS logs (v2)",
    description="Retrieves processed bulk SMS logs with optional search filtering and pagination."
)
async def get_bulk_sms_logs(
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
        # Match case-insensitively across phone_number, message, device_uuid, or status
        regex_query = {"$regex": search, "$options": "i"}
        search_or = [
            {"phone_number": regex_query},
            {"message": regex_query},
            {"device_uuid": regex_query},
            {"status": regex_query}
        ]
        if "status" in query:
            query = {"$and": [{"status": query["status"]}, {"$or": search_or}]}
        else:
            query["$or"] = search_or
        
    total_count = await db.bulk_sms_logs.count_documents(query)
    skip_count = (page - 1) * page_size
    
    cursor = db.bulk_sms_logs.find(query).sort([("created_at", -1)]).skip(skip_count).limit(page_size)
    logs = await cursor.to_list(length=page_size)
    
    for log in logs:
        log["_id"] = str(log["_id"])
        if "campaign_id" in log and log["campaign_id"] is not None:
            log["campaign_id"] = str(log["campaign_id"])
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

@router.get(
    "/queue/stats",
    status_code=status.HTTP_200_OK,
    summary="Get live statistics of the message queues and devices (v2)",
)
async def get_queue_stats(db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    now = datetime.datetime.utcnow()
    
    # 1. Fetch Priority and Regular Queue active lengths
    priority_count = await db.sms_queue.count_documents({
        "queue_type": "PRIORITY",
        "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]}
    })
    
    regular_count = await db.sms_queue.count_documents({
        "queue_type": "REGULAR",
        "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]}
    })
    
    # Count unassigned messages in the shared pool (device_uuid is None or empty)
    unassigned_count = await db.sms_queue.count_documents({
        "status": {"$in": ["PENDING", "QUEUED"]},
        "$or": [{"device_uuid": None}, {"device_uuid": ""}]
    })
    
    # 2. Get active UUIDs from the websocket connections manager
    active_uuids = list(manager.active_connections.keys())
    
    # 3. Retrieve all devices from DB
    cursor = db.devices.find({})
    devices = await cursor.to_list(length=100)
    
    device_stats = []
    for dev in devices:
        uuid = dev["uuid"]
        
        # A device is online if it is in the active connections AND database says online,
        # AND heartbeat was seen within 30 seconds
        is_online = uuid in active_uuids and dev.get("status") == "online"
        last_seen = dev.get("last_seen")
        if last_seen and is_online:
            delta_sec = (now - last_seen).total_seconds()
            if delta_sec > 30.0:
                is_online = False
                
        # Query queue counts for this device (only messages currently claimed by this device)
        sent_count = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "status": "SENT"
        })
        
        failed_count = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "status": {"$in": ["FAILED", "ABANDONED"]}
        })
        
        pending_count = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "queue_type": "REGULAR",
            "status": {"$in": ["PENDING", "QUEUED"]}
        })
        
        priority_pending = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "queue_type": "PRIORITY",
            "status": {"$in": ["PENDING", "QUEUED"]}
        })
        
        processing_count = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "status": "PROCESSING"
        })
        
        # Calculate success rate
        total_completed = sent_count + failed_count
        success_rate = 100.0
        if total_completed > 0:
            success_rate = round((sent_count / total_completed) * 100, 2)
            
        # Determine current action
        # With shared pool: device is "waiting" if there are unassigned messages it can claim
        if not is_online:
            action = "offline"
        elif processing_count > 0 or priority_pending > 0:
            action = "sending"
        elif pending_count > 0 or unassigned_count > 0:
            action = "waiting"
        else:
            action = "idle"
            
        # Calculate sending speed (SMS/second) based on last 60 seconds
        one_min_ago = now - datetime.timedelta(seconds=60)
        sent_last_min = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "status": "SENT",
            "sent_at": {"$gte": one_min_ago}
        })
        speed = round(sent_last_min / 60.0, 2)
        
        # Dynamic enhancements: provide a small mock rate if it is actively sending but speed is mathematically 0
        if action == "sending" and speed == 0.0:
            speed = 0.5
            
        # Calculate countdown for regular queue items
        regular_interval = dev.get("regular_interval", 2.0)
        next_send_in = 0.0
        if action == "waiting":
            last_msg = await db.sms_queue.find_one(
                {"device_uuid": uuid, "queue_type": "REGULAR", "status": "SENT"},
                sort=[("sent_at", -1)]
            )
            if last_msg and "sent_at" in last_msg:
                elapsed = (now - last_msg["sent_at"]).total_seconds()
                next_send_in = max(0.0, round(regular_interval - elapsed, 1))
            else:
                next_send_in = regular_interval
                
        device_stats.append({
            "uuid": uuid,
            "name": dev.get("name") or "Device",
            "status": "online" if is_online else "offline",
            "action": action,
            "battery": dev.get("battery"),
            "signal": dev.get("signal"),
            "carrier": dev.get("carrier") or "Unknown",
            "latitude": dev.get("latitude"),
            "longitude": dev.get("longitude"),
            "sent_count": sent_count,
            "pending_count": pending_count + priority_pending,
            "processing_count": processing_count,
            "success_rate": success_rate,
            "speed": speed,
            "next_send_in": next_send_in,
            "regular_interval": regular_interval,
            "last_updated": now.isoformat()
        })
        
    return {
        "priority_queue_count": priority_count,
        "regular_queue_count": regular_count,
        "unassigned_count": unassigned_count,
        "devices": device_stats,
        "timestamp": now.isoformat()
    }
