import json
from typing import Dict
from fastapi import WebSocket
from app.logger import logger

class ConnectionManager:
    def __init__(self):
        # Maps device_uuid to WebSocket connection
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, device_uuid: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[device_uuid] = websocket
        logger.success(f"Device connected via WebSocket: {device_uuid}")

    def disconnect(self, device_uuid: str):
        if device_uuid in self.active_connections:
            del self.active_connections[device_uuid]
            logger.warning(f"Device disconnected from WebSocket: {device_uuid}")

    async def send_personal_message(self, message: dict, device_uuid: str) -> bool:
        websocket = self.active_connections.get(device_uuid)
        if websocket:
            try:
                await websocket.send_text(json.dumps(message))
                logger.info(f"Pushed message to device {device_uuid}: {message.get('type')} (Job ID: {message.get('jobId')})")
                return True
            except Exception as e:
                logger.error(f"Failed to send message to device {device_uuid}: {e}")
                self.disconnect(device_uuid)
                return False
        logger.warning(f"Failed to push message: Device {device_uuid} is offline")
        return False

manager = ConnectionManager()

