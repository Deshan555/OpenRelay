import asyncio
import json
import urllib.request
import websockets

BACKEND_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000/ws/device"
DEVICE_UUID = "test-device-uuid-123"

def register_device():
    data = json.dumps({
        "uuid": DEVICE_UUID,
        "name": "Test Android Simulator",
        "model": "Pixel 6",
        "android_version": "12",
        "carrier": "T-Mobile"
    }).encode("utf-8")
    req = urllib.request.Request(f"{BACKEND_URL}/devices/register", data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode("utf-8"))
            return res["token"]
    except Exception as e:
        return None

async def simulate_device(token):
    ws_uri = f"{WS_URL}?token={token}"
    async with websockets.connect(ws_uri) as websocket:
        async def send_status():
            while True:
                await websocket.send(json.dumps({"type": "STATUS_UPDATE", "battery": 88, "signal": 4, "carrier": "T-Mobile"}))
                await asyncio.sleep(15)
        status_task = asyncio.create_task(send_status())
        try:
            async for message in websocket:
                payload = json.loads(message)
                if payload.get("type") == "SEND_SMS":
                    job_id = payload.get("jobId")
                    await websocket.send(json.dumps({"type": "RESULT", "jobId": job_id, "status": "SENT"}))
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            status_task.cancel()

def main():
    token = register_device()
    if token:
        try:
            asyncio.run(simulate_device(token))
        except KeyboardInterrupt:
            pass

if __name__ == "__main__":
    main()
