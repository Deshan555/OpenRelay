# OpenRelay SMS Gateway (MVP Backend)

OpenRelay is an open-source, self-hosted SMS Gateway that enables developers to send SMS messages using their own Android devices. This project acts as the FastAPI-based backend management server that coordinates Android devices (via WebSockets) and clients (via REST APIs).

---

## Features

- **Device Registration**: Register devices using their unique UUIDs, tracking hardware metadata, Android version, network carrier, and geolocation.
- **REST APIs**: Trigger single and batch SMS send jobs.
- **WebSocket Gateway**: High-performance bi-directional WebSocket interface to route SMS payloads to connected devices and receive delivery results (`SENT`, `FAILED`) in real-time.
- **Configurable Swagger & OpenAPI docs**: Change document endpoints or disable them completely in production environments.
- **Custom Colored Logger**: Level-based color coding in the terminal console (`SUCCESS`, `INFO`, `WARNING`, `ERROR`) to trace real-time operations.

---

## Installation & Setup

### Prerequisites
- Python 3.8 or higher installed on your system.

### 1. Set Up Virtual Environment
Initialize a clean Python virtual environment to manage dependencies:
```bash
# Navigate to the backend directory
cd backend

# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
# On macOS/Linux:
source .venv/bin/activate
# On Windows:
.venv\Scripts\activate
```

### 2. Install Dependencies
Install all package dependencies using the requirements file:
```bash
pip install -r requirements.txt
```

---

## Running the Server

Start the FastAPI application with Uvicorn:
```bash
python run.py
```
The server will boot up and bind to **`http://localhost:8000`**. You should see colored initialization logs in your terminal output.

---

## Configuration Options

OpenRelay is highly configurable via environment variables. You can customize the settings class:

| Environment Variable | Description | Default Value |
| --- | --- | --- |
| `DATABASE_URL` | SQLAlchemy Connection URL | `sqlite:///./openrelay.db` |
| `JWT_SECRET` | Token signature key | `super-secret-key-change-in-production` |
| `DOCS_URL` | Path for Swagger UI documentation | `/docs` |
| `REDOC_URL` | Path for ReDoc API documentation | `/redoc` |
| `OPENAPI_URL` | Path for raw OpenAPI JSON schema | `/openapi.json` |
| `ENABLE_DOCS` | Enable/Disable documentation interface | `True` |

---

## Testing OpenRelay (Simulating a Device)

To test the end-to-end functionality without installing the real Android app, a mock simulator client is included in the project.

### Step 1: Run the simulator client
In a new terminal window, activate your virtual environment and run the test client:
```bash
cd backend
source .venv/bin/activate
python test_client.py
```
This script registers a device (`test-device-uuid-123`), retrieves an authentication token, establishes a WebSocket connection, and sends periodic status reports.

### Step 2: Trigger an SMS send request via REST
Use `curl` or Postman to request the gateway to send an SMS:
```bash
curl -X POST http://localhost:8000/sms/send \
  -H "Content-Type: application/json" \
  -d '{
    "device": "test-device-uuid-123",
    "to": "+94771234567",
    "message": "Hello from OpenRelay REST API!"
  }'
```

### Step 3: Observe Output
1. The server console will output a log of the incoming API request.
2. The WebSocket manager will push the payload to the simulator.
3. The simulator console will log: `[job_id] SENDING SMS...` and reply over the WebSocket channel with `RESULT: SENT`.
4. The server console will print a green `SUCCESS` message confirming the delivery result.
