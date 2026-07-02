import json
import datetime
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Device, SMSJob
from app.websocket import manager
from app.auth import verify_token
from app.logger import logger

router = APIRouter(tags=["websocket"])

@router.websocket("/ws/device")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
    db: Session = Depends(get_db)
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
    device = db.query(Device).filter(Device.uuid == device_uuid).first()
    if not device:
        logger.warning(f"V2: Unregistered device '{device_uuid}' attempted connection.")
        await websocket.close(code=1008)
        return

    # Accept connection and mark device online with version=2
    await manager.connect(device_uuid, websocket, version=2)
    device.status = "online"
    device.last_seen = datetime.datetime.utcnow()
    db.commit()

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
                        job = db.query(SMSJob).filter(SMSJob.id == int(job_id)).first()
                        if job:
                            job.status = status
                            job.sent_at = datetime.datetime.utcnow()
                            db.commit()
                            
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
                    
                    device.last_seen = datetime.datetime.utcnow()
                    if battery is not None:
                        device.battery = battery
                    if signal is not None:
                        device.signal = signal
                    if carrier is not None:
                        device.carrier = carrier
                    if latitude is not None:
                        device.latitude = latitude
                    if longitude is not None:
                        device.longitude = longitude
                    db.commit()
                    logger.debug(f"V2: Status update from {device_uuid} - Battery: {battery}%, Signal: {signal}")

            except json.JSONDecodeError:
                logger.warning(f"V2: Received invalid JSON message from device {device_uuid}: {data}")

    except WebSocketDisconnect:
        manager.disconnect(device_uuid)
        db.refresh(device)
        device.status = "offline"
        device.last_seen = datetime.datetime.utcnow()
        db.commit()
        logger.warning(f"V2: WebSocket connection closed for device {device_uuid}.")
