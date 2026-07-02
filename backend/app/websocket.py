import json
from typing import Dict, Any
from fastapi import WebSocket
from app.logger import logger

class ConnectionManager:
    def __init__(self):
        # Maps device_uuid to Dict with "socket" and "version"
        self.active_connections: Dict[str, Dict[str, Any]] = {}

    async def connect(self, device_uuid: str, websocket: WebSocket, version: int = 1):
        await websocket.accept()
        self.active_connections[device_uuid] = {"socket": websocket, "version": version}
        logger.success(f"Device connected via WebSocket (v{version}): {device_uuid}")

    def disconnect(self, device_uuid: str):
        if device_uuid in self.active_connections:
            del self.active_connections[device_uuid]
            logger.warning(f"Device disconnected from WebSocket: {device_uuid}")

    def get_version(self, device_uuid: str) -> int:
        conn = self.active_connections.get(device_uuid)
        if conn:
            return conn.get("version", 1)
        return 1

    async def send_personal_message(self, message: dict, device_uuid: str) -> bool:
        conn = self.active_connections.get(device_uuid)
        if conn:
            websocket = conn["socket"]
            version = conn["version"]
            
            # Format outgoing message depending on the connected device's protocol version
            formatted_message = message.copy()
            if version == 2:
                if "jobId" in formatted_message:
                    formatted_message["job_id"] = formatted_message.pop("jobId")
            else:
                if "job_id" in formatted_message:
                    formatted_message["jobId"] = formatted_message.pop("job_id")

            try:
                await websocket.send_text(json.dumps(formatted_message))
                logger.info(f"Pushed message to device {device_uuid} (v{version}): {formatted_message.get('type')} (Job ID: {formatted_message.get('jobId') or formatted_message.get('job_id')})")
                return True
            except Exception as e:
                logger.error(f"Failed to send message to device {device_uuid}: {e}")
                self.disconnect(device_uuid)
                return False
        logger.warning(f"Failed to push message: Device {device_uuid} is offline")
        return False

manager = ConnectionManager()


