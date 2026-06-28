import json
from typing import Dict
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, device_uuid: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[device_uuid] = websocket

    def disconnect(self, device_uuid: str):
        if device_uuid in self.active_connections:
            del self.active_connections[device_uuid]

    async def send_personal_message(self, message: dict, device_uuid: str) -> bool:
        websocket = self.active_connections.get(device_uuid)
        if websocket:
            try:
                await websocket.send_text(json.dumps(message))
                return True
            except Exception:
                self.disconnect(device_uuid)
                return False
        return False

manager = ConnectionManager()
