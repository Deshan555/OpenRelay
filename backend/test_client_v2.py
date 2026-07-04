import asyncio
import json
import urllib.request
import urllib.parse
import websockets
import random

BACKEND_URL = "http://localhost:8000/api/v2"
WS_URL = "ws://localhost:8000/api/v2/ws/device"

DEVICES_CONFIG = [
    {
        "uuid": "sim-device-001",
        "name": "LA Gateway Alpha",
        "model": "Pixel 8 Pro",
        "android_version": "14",
        "carrier": "T-Mobile",
        "latitude": 34.0522,
        "longitude": -118.2437,
        "battery": 95,
        "signal": 4
    },
    {
        "uuid": "sim-device-002",
        "name": "NY Gateway Beta",
        "model": "Samsung S24 Ultra",
        "android_version": "14",
        "carrier": "Verizon",
        "latitude": 40.7128,
        "longitude": -74.0060,
        "battery": 15,  # Low battery warning
        "signal": 3
    },
    {
        "uuid": "sim-device-003",
        "name": "SF Gateway Gamma",
        "model": "OnePlus 12",
        "android_version": "13",
        "carrier": "AT&T",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "battery": 55,
        "signal": 2
    },
    {
        "uuid": "sim-device-004",
        "name": "Chicago Gateway Delta",
        "model": "Pixel 7a",
        "android_version": "13",
        "carrier": "T-Mobile",
        "latitude": 41.8781,
        "longitude": -87.6298,
        "battery": 82,
        "signal": 4
    },
    {
        "uuid": "sim-device-005",
        "name": "Miami Dispatcher Epsilon",
        "model": "Galaxy S23",
        "android_version": "13",
        "carrier": "Verizon",
        "latitude": 25.7617,
        "longitude": -80.1918,
        "battery": 8,  # Critical battery
        "signal": 1
    },
    {
        "uuid": "sim-device-006",
        "name": "Seattle Gateway Zeta",
        "model": "Nothing Phone (2)",
        "android_version": "14",
        "carrier": "AT&T",
        "latitude": 47.6062,
        "longitude": -122.3321,
        "battery": 99,
        "signal": 3
    },
    {
        "uuid": "sim-device-007",
        "name": "Denver Dispatcher Eta",
        "model": "Xiaomi 14 Pro",
        "android_version": "14",
        "carrier": "Orange",
        "latitude": 39.7392,
        "longitude": -104.9903,
        "battery": 60,
        "signal": 2
    },
    {
        "uuid": "sim-device-008",
        "name": "Boston Gateway Theta",
        "model": "Sony Xperia 1 V",
        "android_version": "13",
        "carrier": "T-Mobile",
        "latitude": 42.3601,
        "longitude": -71.0589,
        "battery": 73,
        "signal": 4
    },
    {
        "uuid": "sim-device-009",
        "name": "Dallas Dispatcher Iota",
        "model": "Motorola Edge 40",
        "android_version": "13",
        "carrier": "Verizon",
        "latitude": 32.7767,
        "longitude": -96.7970,
        "battery": 42,
        "signal": 3
    },
    {
        "uuid": "sim-device-010",
        "name": "Vegas Gateway Kappa",
        "model": "Asus ROG Phone 8",
        "android_version": "14",
        "carrier": "AT&T",
        "latitude": 36.1716,
        "longitude": -115.1398,
        "battery": 90,
        "signal": 4
    },
    {
        "uuid": "sim-device-011",
        "name": "Dialog Router Lambda",
        "model": "Samsung A54",
        "android_version": "13",
        "carrier": "Dialog Axiata",
        "latitude": 6.9271,
        "longitude": 79.8612,
        "battery": 88,
        "signal": 4
    }
]

def register_device(config):
    uuid = config["uuid"]
    print(f"[*] Registering simulated device '{config['name']}' ({uuid}) via API V2...")
    
    data = json.dumps({
        "uuid": uuid,
        "name": config["name"],
        "model": config["model"],
        "android_version": config["android_version"],
        "carrier": config["carrier"],
        "latitude": config["latitude"],
        "longitude": config["longitude"]
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
            print(f"[+] Device {uuid} registered! Token received.")
            return res["token"]
    except Exception as e:
        print(f"[-] Failed to register device {uuid}: {e}")
        return None

async def simulate_device(config, token):
    uuid = config["uuid"]
    name = config["name"]
    battery = config["battery"]
    signal = config["signal"]
    carrier = config["carrier"]
    lat = config["latitude"]
    lon = config["longitude"]

    print(f"[{name}] Connecting to V2 WebSocket...")
    ws_uri = f"{WS_URL}?token={token}"
    
    backoff = 2
    while True:
        try:
            async with websockets.connect(ws_uri) as websocket:
                print(f"[+] [{name}] Connected to OpenRelay V2 WebSocket!")
                
                # Start status reporting task
                async def send_status():
                    nonlocal battery
                    while True:
                        if random.random() < 0.1:
                            battery = max(1, min(100, battery + random.choice([-1, 0, 1])))
                        
                        status_payload = {
                            "type": "STATUS_UPDATE",
                            "battery": battery,
                            "signal": signal,
                            "carrier": carrier,
                            "latitude": lat,
                            "longitude": lon
                        }
                        await websocket.send(json.dumps(status_payload))
                        await asyncio.sleep(15 + random.uniform(-2, 2))
                        
                status_task = asyncio.create_task(send_status())
                
                try:
                    async for message in websocket:
                        payload = json.loads(message)
                        
                        if payload.get("type") == "SEND_SMS":
                            job_id = payload.get("job_id")
                            recipient = payload.get("to")
                            sms_text = payload.get("message")
                            
                            print(f"\n[{name}] [{job_id}] Received SMS request for {recipient}: '{sms_text}'")
                            
                            # Simulate processing latency
                            await asyncio.sleep(random.uniform(0.5, 2.0))
                            
                            # Determine status (SENT vs FAILED)
                            # Simulating higher failure rate for low signal/battery
                            failure_chance = 0.02
                            if signal <= 1:
                                failure_chance = 0.30
                            elif battery < 10:
                                failure_chance = 0.20
                                
                            status = "SENT"
                            if random.random() < failure_chance:
                                status = "FAILED"
                                
                            result_payload = {
                                "type": "RESULT",
                                "job_id": job_id,
                                "status": status
                            }
                            print(f"[{name}] [{job_id}] Completed with status '{status}'")
                            await websocket.send(json.dumps(result_payload))
                except websockets.exceptions.ConnectionClosed:
                    print(f"[-] [{name}] Connection lost. Reconnecting...")
                finally:
                    status_task.cancel()
        except Exception as e:
            print(f"[-] [{name}] Connection failed: {e}. Retrying in {backoff}s...")
            await asyncio.sleep(backoff)
            backoff = min(60, backoff * 2)

async def main_async():
    tasks = []
    for config in DEVICES_CONFIG:
        token = register_device(config)
        if token:
            tasks.append(asyncio.create_task(simulate_device(config, token)))
            
    if tasks:
        print(f"\n[*] Starting parallel simulation of {len(tasks)} devices...")
        await asyncio.gather(*tasks)
    else:
        print("[-] No devices registered. Simulator exiting.")

if __name__ == "__main__":
    try:
        asyncio.run(main_async())
    except KeyboardInterrupt:
        print("\nSimulator stopped by user.")
