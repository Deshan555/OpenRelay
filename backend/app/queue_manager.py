import asyncio
import datetime
from typing import List, Dict, Any, Optional
from bson import ObjectId
from fastapi import HTTPException, status
from pymongo import ReturnDocument

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

async def claim_next_message(db, device_uuid: str, queue_type: str) -> Optional[Dict[str, Any]]:
    """Atomically claim the next unassigned or self-assigned queued message for a device.
    
    Uses find_one_and_update to ensure no two devices can claim the same message.
    Messages with device_uuid=None (unassigned) or already assigned to this device are eligible.
    """
    now = datetime.datetime.utcnow()
    msg = await db.sms_queue.find_one_and_update(
        {
            "queue_type": queue_type,
            "status": {"$in": ["PENDING", "QUEUED"]},
            "$or": [
                {"device_uuid": None},
                {"device_uuid": ""},
                {"device_uuid": device_uuid},
            ]
        },
        {"$set": {
            "device_uuid": device_uuid,
            "status": "PROCESSING",
            "updated_at": now
        }},
        sort=[("created_at", 1)],
        return_document=ReturnDocument.AFTER
    )
    if msg:
        # Sync the device assignment to backwards-compatible log collections
        await db.sms_jobs.update_one({"_id": msg["_id"]}, {"$set": {"device_uuid": device_uuid, "status": "PROCESSING"}})
        await db.bulk_sms_logs.update_one({"_id": msg["_id"]}, {"$set": {"device_uuid": device_uuid, "status": "PROCESSING"}})
        logger.info(f"Device {device_uuid} claimed {queue_type} job {msg['_id']}")
    return msg

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
    """Send a claimed SMS to its assigned device via WebSocket and await RESULT.
    
    Note: The message should already be in PROCESSING state with device_uuid set
    by claim_next_message(). This function handles the WebSocket send and result tracking.
    """
    job_id = str(msg["_id"])
    device_uuid = msg["device_uuid"]

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
                await db.bulk_sms_logs.update_one({"_id": msg["_id"]}, {"$set": {"status": "SENT", "sent_at": now, "device_uuid": device_uuid}})
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
    """Claims and processes messages from the shared queue pool for a specific device.
    
    Uses claim-based processing: the worker atomically claims the next available
    unassigned message from the shared pool, processes it, then claims the next one.
    This provides automatic load balancing across all connected devices.
    """
    logger.info(f"Device queue worker started for device: {device_uuid}")
    db = await get_mongo_db()

    while device_uuid in manager.active_connections:
        try:
            # 1. Claim and process Priority Queue first (oldest first)
            priority_msg = await claim_next_message(db, device_uuid, "PRIORITY")

            if priority_msg:
                await send_queued_message(priority_msg, db)
                # Loop immediately for priority queue (no send interval)
                continue

            # 2. Claim and process Regular Queue if no priority messages available
            regular_msg = await claim_next_message(db, device_uuid, "REGULAR")

            if regular_msg:
                await send_queued_message(regular_msg, db)

                # Fetch configurable regular queue interval
                device_doc = await db.devices.find_one({"uuid": device_uuid})
                interval = device_doc.get("regular_interval", 2.0) if device_doc else 2.0

                # Preemptible sleep loop: wait for 'interval' seconds but check for priority messages
                slept = 0.0
                while slept < interval:
                    # Break sleep early if any priority message exists in the shared pool
                    has_priority = await db.sms_queue.find_one({
                        "queue_type": "PRIORITY",
                        "status": {"$in": ["PENDING", "QUEUED"]},
                        "$or": [
                            {"device_uuid": None},
                            {"device_uuid": ""},
                            {"device_uuid": device_uuid},
                        ]
                    })
                    if has_priority:
                        logger.info(f"Preempting regular queue interval for {device_uuid} due to priority arrival.")
                        break

                    await asyncio.sleep(0.1)
                    slept += 0.1

                    if device_uuid not in manager.active_connections:
                        break
                continue

            # 3. No messages available in shared pool: sleep short interval before polling again
            await asyncio.sleep(0.5)

        except Exception as e:
            logger.error(f"Error in device worker {device_uuid}: {e}")
            await asyncio.sleep(1.0)

    logger.warning(f"Device queue worker stopped for device: {device_uuid}")

async def reassign_device_jobs(device_uuid: str, db):
    """Unassigns all PENDING, QUEUED, or PROCESSING jobs of a disconnected device
    back into the shared pool so any available worker can claim them."""
    now = datetime.datetime.utcnow()
    
    result = await db.sms_queue.update_many(
        {
            "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]},
            "device_uuid": device_uuid
        },
        {"$set": {
            "device_uuid": None,
            "status": "QUEUED",
            "error_detail": f"Unassigned: Device {device_uuid} disconnected.",
            "updated_at": now
        },
        "$addToSet": {
            "failed_devices": device_uuid
        }}
    )
    
    if result.modified_count > 0:
        # Sync backwards-compatible log collections
        await db.sms_jobs.update_many(
            {"device_uuid": device_uuid, "status": {"$in": ["PENDING", "PROCESSING"]}},
            {"$set": {"device_uuid": None, "status": "PENDING"}}
        )
        await db.bulk_sms_logs.update_many(
            {"device_uuid": device_uuid, "status": {"$in": ["PENDING", "PROCESSING"]}},
            {"$set": {"device_uuid": None, "status": "PENDING"}}
        )
        logger.info(f"Unassigned {result.modified_count} jobs from disconnected device {device_uuid} back to shared pool")
    else:
        logger.info(f"No active jobs found for disconnected device {device_uuid}")

async def global_queue_processor():
    """Monitors online devices and spawns/manages device queue workers.
    
    Also handles orphaned jobs: messages assigned to devices that are no longer
    online get unassigned back to the shared pool.
    """
    logger.info("Starting global SMS queue processor...")
    while True:
        try:
            db = await get_mongo_db()
            active_uuids = list(manager.active_connections.keys())

            # Spawn workers for newly online devices
            for uuid in active_uuids:
                if uuid not in active_workers or active_workers[uuid].done():
                    active_workers[uuid] = asyncio.create_task(device_queue_worker(uuid))

            # Cleanup stale workers for devices that disconnected
            stale_workers = [uid for uid in list(active_workers.keys()) if uid not in active_uuids]
            for uid in stale_workers:
                task = active_workers.pop(uid, None)
                if task and not task.done():
                    task.cancel()

            # Failover handling: Unassign orphaned jobs (assigned to offline devices)
            # back to the shared pool so active workers can claim them
            if active_uuids:
                now = datetime.datetime.utcnow()
                result = await db.sms_queue.update_many(
                    {
                        "status": {"$in": ["PENDING", "QUEUED", "PROCESSING"]},
                        "device_uuid": {"$nin": active_uuids + [None, ""]}
                    },
                    {"$set": {
                        "device_uuid": None,
                        "status": "QUEUED",
                        "error_detail": "Unassigned: Original device went offline.",
                        "updated_at": now
                    }}
                )
                if result.modified_count > 0:
                    logger.info(f"Unassigned {result.modified_count} orphaned jobs back to shared pool")

        except Exception as e:
            logger.error(f"Error in global queue processor: {e}")

        await asyncio.sleep(1.0)

def start_queue_worker():
    """Entry point to launch the global queue manager in the background."""
    asyncio.create_task(global_queue_processor())
