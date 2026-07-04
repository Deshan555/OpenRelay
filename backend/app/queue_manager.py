import asyncio
import datetime
from typing import List, Dict, Any
from bson import ObjectId
from fastapi import HTTPException, status

from app.database_mongo import get_mongo_db
from app.websocket import manager
from app.logger import logger

# Global dictionaries to track jobs and workers
pending_results: Dict[str, asyncio.Future] = {}
active_workers: Dict[str, asyncio.Task] = {}

async def select_device(db, exclude_devices: List[str] = None, long_batch: bool = False) -> str:
    """Select the most suitable SMS gateway device based on dynamic scoring."""
    if exclude_devices is None:
        exclude_devices = []

    active_uuids = list(manager.active_connections.keys())
    # Filter active connections by exclude list
    candidates = [uid for uid in active_uuids if uid not in exclude_devices]
    if not candidates:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No available mobile clients connected via WebSocket"
        )

    # Query candidate devices from database
    cursor = db.devices.find({"uuid": {"$in": candidates}})
    devices = await cursor.to_list(length=100)

    if not devices:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No healthy candidate mobile clients found in database"
        )

    now = datetime.datetime.utcnow()
    best_uuid = None
    best_score = -1.0

    for dev in devices:
        uuid = dev["uuid"]

        # Check heartbeat freshness (must be within 30 seconds)
        last_seen = dev.get("last_seen")
        if not last_seen:
            continue
        delta_sec = (now - last_seen).total_seconds()
        if delta_sec > 30.0:
            continue  # stale heartbeat connection

        # Signal strength (0 to 4) -> scaled to 0-100
        signal = dev.get("signal", 0)
        signal_val = signal if signal is not None else 0
        signal_score = signal_val * 25.0

        # Battery level (0 to 100)
        battery = dev.get("battery", 100)
        battery_val = battery if battery is not None else 100
        battery_score = battery_val
        if battery_val < 15:
            # Low battery penalty
            battery_score = battery_val * 0.1

        # Workload (count pending/processing queue items assigned to this device)
        queue_count = await db.sms_queue.count_documents({
            "device_uuid": uuid,
            "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]}
        })
        workload_score = max(0.0, 100.0 - (queue_count * 10.0))

        # Heartbeat score
        heartbeat_score = max(0.0, 100.0 - (delta_sec * 3.33))

        # SIM availability
        carrier = dev.get("carrier")
        sim_score = 100.0 if (carrier and carrier.strip()) else 20.0

        # Apply weights based on long_batch parameter
        if long_batch:
            # Campaign mode: Prioritize high battery & connection stability
            score = (
                0.40 * battery_score +
                0.30 * signal_score +
                0.15 * workload_score +
                0.05 * heartbeat_score +
                0.10 * sim_score
            )
        else:
            # Normal mode: Prioritize workload and signal strength
            score = (
                0.20 * battery_score +
                0.35 * signal_score +
                0.30 * workload_score +
                0.05 * heartbeat_score +
                0.10 * sim_score
            )

        if score > best_score:
            best_score = score
            best_uuid = uuid

    if not best_uuid:
        # Fallback to first candidate if scoring was inconclusive
        if candidates:
            return candidates[0]
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No healthy mobile clients are currently available"
        )

    return best_uuid

async def handle_send_failure(msg: Dict[str, Any], db, reason: str):
    """Executes the Retry & Failover Strategy."""
    job_id = msg["_id"]
    current_device = msg["device_uuid"]
    failed_devices = msg.get("failed_devices", [])
    if current_device not in failed_devices:
        failed_devices.append(current_device)

    retry_count = msg.get("retry_count", 0)

    # Step 1: Attempt failover to another available device
    try:
        new_device_uuid = await select_device(db, exclude_devices=failed_devices)
    except Exception:
        new_device_uuid = None

    if new_device_uuid:
        await db.sms_queue.update_one(
            {"_id": job_id},
            {"$set": {
                "device_uuid": new_device_uuid,
                "status": "QUEUED",
                "retry_count": 0,
                "failed_devices": failed_devices,
                "error_detail": f"Failed on {current_device}: {reason}. Transferred to {new_device_uuid}",
                "updated_at": datetime.datetime.utcnow()
            }}
        )
        # Synchronize backwards compatible logs (if exists)
        await db.sms_jobs.update_one({"_id": job_id}, {"$set": {"device_uuid": new_device_uuid, "status": "PENDING"}})
        await db.bulk_sms_logs.update_one({"_id": job_id}, {"$set": {"device_uuid": new_device_uuid, "status": "PENDING"}})
        logger.info(f"Job {job_id} failed on {current_device}, failover to {new_device_uuid}")
        return

    # Step 2: Retry on the current device (up to 3 total attempts)
    if retry_count < 2:
        await db.sms_queue.update_one(
            {"_id": job_id},
            {"$set": {
                "status": "QUEUED",
                "retry_count": retry_count + 1,
                "error_detail": f"Attempt {retry_count + 1} failed: {reason}",
                "updated_at": datetime.datetime.utcnow()
            }}
        )
        logger.info(f"Job {job_id} failed on {current_device}. Retrying on current device (attempt {retry_count + 2}/3)")
        return

    # Step 3: Abandon SMS job
    await db.sms_queue.update_one(
        {"_id": job_id},
        {"$set": {
            "status": "ABANDONED",
            "error_detail": f"Abandoned after 3 attempts on {current_device}. Reason: {reason}",
            "updated_at": datetime.datetime.utcnow()
        }}
    )
    # Update backwards compatible logs
    await db.sms_jobs.update_one({"_id": job_id}, {"$set": {"status": "FAILED"}})
    await db.bulk_sms_logs.update_one({"_id": job_id}, {"$set": {"status": "FAILED"}})
    logger.error(f"Job {job_id} failed on {current_device} and abandoned after max retries. Reason: {reason}")

async def send_queued_message(msg: Dict[str, Any], db) -> bool:
    """Send queued SMS to the selected device via WebSocket and await RESULT."""
    job_id = str(msg["_id"])
    device_uuid = msg["device_uuid"]

    await db.sms_queue.update_one(
        {"_id": msg["_id"]},
        {"$set": {"status": "PROCESSING", "updated_at": datetime.datetime.utcnow()}}
    )
    await db.sms_jobs.update_one({"_id": msg["_id"]}, {"$set": {"status": "PROCESSING"}})
    await db.bulk_sms_logs.update_one({"_id": msg["_id"]}, {"$set": {"status": "PROCESSING"}})

    payload = {
        "type": "SEND_SMS",
        "job_id": job_id,
        "to": msg["phone_number"],
        "message": msg["message"]
    }

    loop = asyncio.get_running_loop()
    fut = loop.create_future()
    pending_results[job_id] = fut

    try:
        sent = await manager.send_personal_message(payload, device_uuid)
        if not sent:
            logger.error(f"WebSocket send failed for job {job_id} on device {device_uuid}")
            await handle_send_failure(msg, db, "WebSocket disconnected or device offline")
            return False

        # Wait for device acknowledgement via websocket
        try:
            status_result = await asyncio.wait_for(fut, timeout=15.0)
            if status_result == "SENT":
                now = datetime.datetime.utcnow()
                await db.sms_queue.update_one(
                    {"_id": msg["_id"]},
                    {"$set": {
                        "status": "SENT",
                        "sent_at": now,
                        "updated_at": now
                    }}
                )
                await db.sms_jobs.update_one({"_id": msg["_id"]}, {"$set": {"status": "SENT", "sent_at": now}})
                await db.bulk_sms_logs.update_one({"_id": msg["_id"]}, {"$set": {"status": "SENT", "sent_at": now}})
                logger.success(f"Job {job_id} sent successfully by device {device_uuid}")
                return True
            else:
                logger.error(f"Job {job_id} failed on device {device_uuid} with status: {status_result}")
                await handle_send_failure(msg, db, f"Device returned status: {status_result}")
                return False
        except asyncio.TimeoutError:
            logger.error(f"Job {job_id} timed out waiting for response from device {device_uuid}")
            await handle_send_failure(msg, db, "Timeout waiting for device acknowledgement")
            return False

    finally:
        pending_results.pop(job_id, None)

async def device_queue_worker(device_uuid: str):
    """Processes Priority and Regular queues for a specific device in a loop."""
    logger.info(f"Device queue worker started for device: {device_uuid}")
    db = await get_mongo_db()

    while device_uuid in manager.active_connections:
        try:
            # 1. Process Priority Queue first (oldest first)
            priority_msg = await db.sms_queue.find_one({
                "device_uuid": device_uuid,
                "queue_type": "PRIORITY",
                "status": {"$in": ["PENDING", "QUEUED"]}
            }, sort=[("created_at", 1)])

            if priority_msg:
                await send_queued_message(priority_msg, db)
                # Loop immediately for priority queue (no send interval)
                continue

            # 2. Process Regular Queue if priority queue is empty
            regular_msg = await db.sms_queue.find_one({
                "device_uuid": device_uuid,
                "queue_type": "REGULAR",
                "status": {"$in": ["PENDING", "QUEUED"]}
            }, sort=[("created_at", 1)])

            if regular_msg:
                await send_queued_message(regular_msg, db)

                # Fetch configurable regular queue interval
                device_doc = await db.devices.find_one({"uuid": device_uuid})
                interval = device_doc.get("regular_interval", 2.0) if device_doc else 2.0

                # Preemptible sleep loop: wait for 'interval' seconds but poll for priority messages
                slept = 0.0
                while slept < interval:
                    # Break sleep early if new priority message is queued
                    has_priority = await db.sms_queue.find_one({
                        "device_uuid": device_uuid,
                        "queue_type": "PRIORITY",
                        "status": {"$in": ["PENDING", "QUEUED"]}
                    })
                    if has_priority:
                        logger.info(f"Preempting regular queue interval for {device_uuid} due to priority arrival.")
                        break

                    await asyncio.sleep(0.1)
                    slept += 0.1

                    if device_uuid not in manager.active_connections:
                        break
                continue

            # 3. Queue is empty: sleep short interval before polling again
            await asyncio.sleep(0.5)

        except Exception as e:
            logger.error(f"Error in device worker {device_uuid}: {e}")
            await asyncio.sleep(1.0)

    logger.warning(f"Device queue worker stopped for device: {device_uuid}")

async def reassign_device_jobs(device_uuid: str, db):
    """Immediately reassigns all PENDING, QUEUED, or PROCESSING jobs of a disconnected device to other active devices."""
    active_uuids = list(manager.active_connections.keys())
    # Filter out the disconnected device itself
    active_candidates = [uid for uid in active_uuids if uid != device_uuid]
    
    if not active_candidates:
        logger.warning(f"No other online devices available to immediately reassign jobs from disconnected device {device_uuid}")
        return

    cursor = db.sms_queue.find({
        "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]},
        "device_uuid": device_uuid
    })
    
    async for msg in cursor:
        job_id = msg["_id"]
        failed_devices = msg.get("failed_devices", [])
        if device_uuid not in failed_devices:
            failed_devices.append(device_uuid)
            
        try:
            new_device = await select_device(db, exclude_devices=failed_devices)
            await db.sms_queue.update_one(
                {"_id": job_id},
                {"$set": {
                    "device_uuid": new_device,
                    "status": "QUEUED",
                    "failed_devices": failed_devices,
                    "error_detail": f"Re-assigned: Device {device_uuid} disconnected.",
                    "updated_at": datetime.datetime.utcnow()
                }}
            )
            # Synchronize backwards compatible logs (if exists)
            await db.sms_jobs.update_one({"_id": job_id}, {"$set": {"device_uuid": new_device, "status": "PENDING"}})
            await db.bulk_sms_logs.update_one({"_id": job_id}, {"$set": {"device_uuid": new_device, "status": "PENDING"}})
            logger.info(f"Immediately re-assigned job {job_id} from disconnected device {device_uuid} to online device {new_device}")
        except Exception as e:
            logger.warning(f"Unable to immediately re-assign job {job_id} of disconnected device {device_uuid}: {e}")

async def global_queue_processor():
    """Monitors online devices and spawns/manages device queue workers."""
    logger.info("Starting global SMS queue processor...")
    while True:
        try:
            db = await get_mongo_db()
            active_uuids = list(manager.active_connections.keys())

            # Spawn workers for newly online devices
            for uuid in active_uuids:
                if uuid not in active_workers or active_workers[uuid].done():
                    active_workers[uuid] = asyncio.create_task(device_queue_worker(uuid))

            # Failover handling: Re-assign queued/processing messages belonging to offline devices
            async for msg in db.sms_queue.find({
                "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]},
                "device_uuid": {"$nin": active_uuids}
            }):
                try:
                    failed_devices = msg.get("failed_devices", [])
                    old_device = msg["device_uuid"]
                    if old_device not in failed_devices:
                        failed_devices.append(old_device)

                    new_device = await select_device(db, exclude_devices=failed_devices)
                    await db.sms_queue.update_one(
                        {"_id": msg["_id"]},
                        {"$set": {
                            "device_uuid": new_device,
                            "status": "QUEUED",
                            "failed_devices": failed_devices,
                            "error_detail": f"Re-assigned: Device {old_device} disconnected.",
                            "updated_at": datetime.datetime.utcnow()
                        }}
                    )
                    # Synchronize backwards compatible logs (if exists)
                    await db.sms_jobs.update_one({"_id": msg["_id"]}, {"$set": {"device_uuid": new_device, "status": "PENDING"}})
                    await db.bulk_sms_logs.update_one({"_id": msg["_id"]}, {"$set": {"device_uuid": new_device, "status": "PENDING"}})
                    logger.info(f"Re-assigned job {msg['_id']} from offline device {old_device} to online device {new_device}")
                except Exception as e:
                    logger.warning(f"Unable to re-assign job {msg['_id']} of offline device {msg['device_uuid']}: {e}")

        except Exception as e:
            logger.error(f"Error in global queue processor: {e}")

        await asyncio.sleep(1.0)

def start_queue_worker():
    """Entry point to launch the global queue manager in the background."""
    asyncio.create_task(global_queue_processor())
