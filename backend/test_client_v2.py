import asyncio
import json
import urllib.request
import urllib.parse
import websockets

BACKEND_URL = "http://localhost:8000/api/v2"
WS_URL = "ws://localhost:8000/api/v2/ws/device"
DEVICE_UUID = "test-device-uuid-456"

def register_device():
    print("[1] Registering device via API V2...")
    data = json.dumps({
        "uuid": DEVICE_UUID,
        "name": "Test Android Simulator V2",
        "model": "Pixel 7 Pro",
        "android_version": "13",
        "carrier": "AT&T",
        "latitude": 34.0522,
        "longitude": -118.2437
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
            print(f"Device registered successfully! (Device ID: {res['device_id']})")
            return res["token"]
    except Exception as e:
        print(f"Failed to register device via V2: {e}")
        return None

async def simulate_device(token):
    print("[2] Connecting to V2 WebSocket...")
    ws_uri = f"{WS_URL}?token={token}"
    
    async with websockets.connect(ws_uri) as websocket:
        print("Connected to OpenRelay V2 WebSocket server!")
        
        # Start a background task to report status periodically
        async def send_status():
            while True:
                status_payload = {
                    "type": "STATUS_UPDATE",
                    "battery": 92,
                    "signal": 3,
                    "carrier": "AT&T Simulator",
                    "latitude": 34.0522,
                    "longitude": -118.2437
                }
                print(f"Sending device status (V2): {status_payload}")
                await websocket.send(json.dumps(status_payload))
                await asyncio.sleep(15)
                
        status_task = asyncio.create_task(send_status())
        
        try:
            async for message in websocket:
                payload = json.loads(message)
                print(f"\nReceived message from server (V2): {payload}")
                
                if payload.get("type") == "SEND_SMS":
                    # Expecting job_id in V2
                    job_id = payload.get("job_id")
                    recipient = payload.get("to")
                    sms_text = payload.get("message")
                    
                    print(f"[{job_id}] SENDING SMS to {recipient}: '{sms_text}' (V2)")
                    await asyncio.sleep(2)  # Simulate latency
                    
                    # Send RESULT update back to server (using job_id)
                    result_payload = {
                        "type": "RESULT",
                        "job_id": job_id,
                        "status": "SENT"
                    }
                    print(f"[{job_id}] Sending sending result (V2): {result_payload}")
                    await websocket.send(json.dumps(result_payload))
        except websockets.exceptions.ConnectionClosed:
            print("Connection to V2 WebSocket server closed.")
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
