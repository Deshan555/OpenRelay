import json
import datetime
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends
from bson import ObjectId

from app.database_mongo import get_mongo_db
from app.websocket import manager
from app.auth import verify_token
from app.logger import logger

router = APIRouter(tags=["websocket"])

@router.websocket("/ws/device")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
    db = Depends(get_mongo_db)
):
    # Authenticate device
    try:
        payload = verify_token(token)
        device_uuid = payload.get("sub")
    except Exception as e:
        logger.error(f"V2 WebSocket authentication failed: {e}")
        await websocket.close(code=1008) # Policy Violation
        return

    # Check if device registered in DB
    device = await db.devices.find_one({"uuid": device_uuid})
    if not device:
        logger.warning(f"V2: Unregistered device '{device_uuid}' attempted connection.")
        await websocket.close(code=1008)
        return

    # Accept connection and mark device online with version=2
    await manager.connect(device_uuid, websocket, version=2)
    await db.devices.update_one(
        {"uuid": device_uuid},
        {"$set": {
            "status": "online",
            "last_seen": datetime.datetime.utcnow()
        }}
    )

    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
                msg_type = message.get("type")

                # Handle result update (expecting job_id instead of jobId)
                if msg_type == "RESULT":
                    job_id = message.get("job_id")
                    status = message.get("status")
                    if job_id and status:
                        # Resolve queue worker future if one is waiting
                        from app.queue_manager import pending_results
                        if job_id in pending_results:
                            try:
                                pending_results[job_id].set_result(status)
                            except Exception as fut_err:
                                logger.error(f"V2: Error setting future result for {job_id}: {fut_err}")

                        try:
                            oid = ObjectId(job_id)
                        except Exception:
                            logger.error(f"V2: Invalid ObjectId '{job_id}' received.")
                            oid = None
                            
                        if oid:
                            job = await db.sms_jobs.find_one({"_id": oid})
                            if job:
                                await db.sms_jobs.update_one(
                                    {"_id": oid},
                                    {"$set": {
                                        "status": status,
                                        "sent_at": datetime.datetime.utcnow()
                                    }}
                                )
                                if status == "SENT":
                                    logger.success(f"V2: SMS Job {job_id} sent successfully by device {device_uuid}.")
                                else:
                                    logger.error(f"V2: SMS Job {job_id} failed on device {device_uuid} with status: {status}.")
                            else:
                                logger.warning(f"V2: Result reported for unknown SMS Job {job_id}.")

                # Handle status/health report from device
                elif msg_type == "STATUS_UPDATE":
                    battery = message.get("battery")
                    signal = message.get("signal")
                    carrier = message.get("carrier")
                    latitude = message.get("latitude")
                    longitude = message.get("longitude")
                    
                    update_fields = {
                        "last_seen": datetime.datetime.utcnow()
                    }
                    if battery is not None:
                        update_fields["battery"] = battery
                    if signal is not None:
                        update_fields["signal"] = signal
                    if carrier is not None:
                        update_fields["carrier"] = carrier
                    if latitude is not None:
                        update_fields["latitude"] = latitude
                    if longitude is not None:
                        update_fields["longitude"] = longitude
                        
                    await db.devices.update_one({"uuid": device_uuid}, {"$set": update_fields})
                    logger.debug(f"V2: Status update from {device_uuid} - Battery: {battery}%, Signal: {signal}")

            except json.JSONDecodeError:
                logger.warning(f"V2: Received invalid JSON message from device {device_uuid}: {data}")

    except WebSocketDisconnect:
        manager.disconnect(device_uuid)
        await db.devices.update_one(
            {"uuid": device_uuid},
            {"$set": {
                "status": "offline",
                "last_seen": datetime.datetime.utcnow()
            }}
        )
        logger.warning(f"V2: WebSocket connection closed for device {device_uuid}.")
        from app.queue_manager import reassign_device_jobs
        await reassign_device_jobs(device_uuid, db)
