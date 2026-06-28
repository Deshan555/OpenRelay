import json
import datetime
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.config import settings
from app.database import Base, engine, get_db
from app.models import Device, SMSJob
from app.routers import devices, sms
from app.websocket import manager
from app.auth import verify_token
from app.logger import logger

logger.info("Initializing database tables...")
Base.metadata.create_all(bind=engine)
logger.success("Database tables initialized successfully.")

app = FastAPI(title=settings.PROJECT_NAME)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(devices.router)
app.include_router(sms.router)

@app.get("/")
def read_root():
    logger.debug("Root endpoint accessed.")
    return {"message": "OpenRelay SMS Gateway API is running"}

@app.websocket("/ws/device")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...), db: Session = Depends(get_db)):
    try:
        payload = verify_token(token)
        device_uuid = payload.get("sub")
    except Exception as e:
        logger.error(f"WebSocket authentication failed: {e}")
        await websocket.close(code=1008)
        return
    device = db.query(Device).filter(Device.uuid == device_uuid).first()
    if not device:
        logger.warning(f"Unregistered device with UUID '{device_uuid}' attempted connection.")
        await websocket.close(code=1008)
        return
    await manager.connect(device_uuid, websocket)
    device.status = "online"
    device.last_seen = datetime.datetime.utcnow()
    db.commit()
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
                msg_type = message.get("type")
                if msg_type == "RESULT":
                    job_id = message.get("jobId")
                    status = message.get("status")
                    if job_id and status:
                        job = db.query(SMSJob).filter(SMSJob.id == int(job_id)).first()
                        if job:
                            job.status = status
                            job.sent_at = datetime.datetime.utcnow()
                            db.commit()
                            if status == "SENT":
                                logger.success(f"SMS Job {job_id} sent successfully by device {device_uuid}.")
                            else:
                                logger.error(f"SMS Job {job_id} failed on device {device_uuid} with status: {status}.")
                        else:
                            logger.warning(f"Result reported for unknown SMS Job {job_id}.")
                elif msg_type == "STATUS_UPDATE":
                    battery = message.get("battery")
                    signal = message.get("signal")
                    carrier = message.get("carrier")
                    device.last_seen = datetime.datetime.utcnow()
                    if battery is not None:
                        device.battery = battery
                    if signal is not None:
                        device.signal = signal
                    if carrier is not None:
                        device.carrier = carrier
                    db.commit()
                    logger.debug(f"Status update from {device_uuid} - Battery: {battery}%, Signal: {signal}, Carrier: {carrier}")
            except json.JSONDecodeError:
                logger.warning(f"Received invalid JSON message from device {device_uuid}: {data}")
    except WebSocketDisconnect:
        manager.disconnect(device_uuid)
        db.refresh(device)
        device.status = "offline"
        device.last_seen = datetime.datetime.utcnow()
        db.commit()
        logger.warning(f"WebSocket connection closed for device {device_uuid}.")
