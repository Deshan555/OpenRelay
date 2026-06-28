import asyncio
import json
import urllib.request
import urllib.parse
import websockets

BACKEND_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000/ws/device"
DEVICE_UUID = "test-device-uuid-123"

def register_device():
    print("[1] Registering device...")
    data = json.dumps({
        "uuid": DEVICE_UUID,
        "name": "Test Android Simulator",
        "model": "Pixel 6",
        "android_version": "12",
        "carrier": "T-Mobile",
        "latitude": 37.7749,
        "longitude": -122.4194
    }).encode("utf-8")
    
    req = urllib.request.Request(
        f"{BACKEND_URL}/devices/register",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode("utf-8"))
            print(f"Device registered successfully! Token details returned.")
            return res["token"]
    except Exception as e:
        print(f"Failed to register device: {e}")
        return None

async def simulate_device(token):
    print("[2] Connecting to WebSocket...")
    ws_uri = f"{WS_URL}?token={token}"
    
    async with websockets.connect(ws_uri) as websocket:
        print("Connected to OpenRelay WebSocket server!")
        
        # Start a background task to report status periodically
        async def send_status():
            while True:
                status_payload = {
                    "type": "STATUS_UPDATE",
                    "battery": 88,
                    "signal": 4,
                    "carrier": "T-Mobile Simulator",
                    "latitude": 37.7749,
                    "longitude": -122.4194
                }
                print(f"Sending device status: {status_payload}")
                await websocket.send(json.dumps(status_payload))
                await asyncio.sleep(15)
                
        status_task = asyncio.create_task(send_status())
        
        try:
            async for message in websocket:
                payload = json.loads(message)
                print(f"\nReceived message from server: {payload}")
                
                if payload.get("type") == "SEND_SMS":
                    job_id = payload.get("jobId")
                    recipient = payload.get("to")
                    sms_text = payload.get("message")
                    
                    print(f"[{job_id}] SENDING SMS to {recipient}: '{sms_text}'")
                    await asyncio.sleep(2)  # Simulate network latency sending SMS
                    
                    # Send RESULT update back to server
                    result_payload = {
                        "type": "RESULT",
                        "jobId": job_id,
                        "status": "SENT"
                    }
                    print(f"[{job_id}] Sending sending result: {result_payload}")
                    await websocket.send(json.dumps(result_payload))
        except websockets.exceptions.ConnectionClosed:
            print("Connection to WebSocket server closed.")
        finally:
            status_task.cancel()

def main():
    token = register_device()
    if token:
        try:
            asyncio.run(simulate_device(token))
        except KeyboardInterrupt:
            print("\nSimulator stopped by user.")

if __name__ == "__main__":
    main()
