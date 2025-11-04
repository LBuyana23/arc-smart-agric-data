# ARC Smart Agriculture Data Platform  
**Central Data Broker, API Layer, and Dashboard Stack**

---

## Overview  
The **ARC Smart Agriculture Data Platform** serves as the **central communication hub** and **data management layer** for the entire Smart Agriculture ecosystem.  

It connects multiple IoT subsystems — including greenhouse monitoring, soil sensing, water management, and smart farm dashboards — through the **MQTT protocol** and provides structured APIs and UI experiences for storing, analyzing, and sharing agricultural data in real time.

---

### System Architecture  
**Core Components:**
- **ESP32 IoT Nodes** – Collect sensor data (soil, humidity, temperature, etc.) and publish via MQTT.  
- **Mosquitto MQTT Broker** – Handles lightweight, fast message exchange between devices and backend services.  
- **Python Subscribers & Bridges** – Listen to standardized MQTT topics, transform payloads, and forward data to storage or analytics modules.  
- **Central Database / API** – Stores aggregated data and exposes it to dashboards or external systems.  
- **Flutter Dashboard** – Provides operational views (overview, irrigation, soil, crop vision) on top of the Flask data bridge.

---

### MQTT Topic Standardization  
All device topics follow a consistent and hierarchical structure for clarity and scalability:  

```bash
arc/<project-section>/<group-id>/<sensor-type>
```

**Examples:**

```bash
arc/soil-monitoring/group8/soil-sensor
arc/greenhouse-monitoring/group9/greenhouse-sensor
arc/water-management/group10/water-sensor
```

This makes it easy to subscribe selectively to specific groups or sensors using wildcard filters such as: 

```
arc/soil-monitoring/#
arc/+/group9/#
```

---

## Repository Layout
- `smart_farm_platform/` – Flutter dashboard that consumes the Flask bridge.
- `Testing the Flask app/` – Flask service, local mocks, and API tests (`testapp_local.py`, `testapp_clean.py`, `tests/`).
- `mqtt_subscriber.py`, `publisher.py`, `tools/` – MQTT ingest utilities and sample generation helpers.
- `requirements.txt` – Python dependencies for the MQTT bridge and supporting scripts.
- `README_FOR_LECTURER.md`, `attached_assets/` – supplementary documentation.

---

## Setting Up the MQTT + API Layer

### 1. Clone the Repository
```bash
git clone https://github.com/LBuyana23/arc-smart-agric-data.git
cd arc-smart-agric-data
```

### 2. Create a Virtual Environment
```bash
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Run the MQTT Subscriber
```bash
python mqtt_subscriber.py
```
Ensure your Mosquitto broker is running on port 1883 and accessible at the IP specified in the script.

### Testing Connectivity

**Subscribe to all topics**
```bash
mosquitto_sub -t "arc/#"
```

**Publish a test message**
```bash
mosquitto_pub -t "arc/soil-monitoring/group8/soil-sensor" -m "test message"
```

**Sample Output**
```bash
[MQTT] Connected successfully
[MQTT] Subscribed to topic: ['arc/soil-monitoring/group8/soil-sensor', 'arc/greenhouse-monitoring/group9/greenhouse-sensor']
[MQTT] Message received -> Topic: arc/soil-monitoring/group8/soil-sensor, Payload: {"moisture": 45.3, "temperature": 23.1}
```

---

## Flask Data Bridge (`Testing the Flask app/`)

### Local development (`testapp_local.py`)
```bash
cd "Testing the Flask app"
python -m venv venv-local
venv-local\Scripts\activate        # use `source venv-local/bin/activate` on macOS/Linux
pip install -r requirements.txt     # or install flask, flask-cors, requests, python-dotenv individually
set FLASK_ENV=development           # `export` on macOS/Linux
python testapp_local.py             # runs on http://127.0.0.1:5000
```
- Uses local `.env` values for upstream bridges and Oracle fallbacks.
- Hot reload via `debug=True`; ideal for iterating alongside the Flutter app.

### Hosted deployment (`testapp_clean.py`)
```bash
cd "Testing the Flask app"
python -m venv venv-prod
venv-prod\Scripts\activate
pip install -r requirements.txt
set FLASK_ENV=production
python testapp_clean.py             # quick sanity check
pip install gunicorn
gunicorn -b 0.0.0.0:10000 testapp_clean:app
```
- Trimmed logging and no auto-refresh; ready for Render, Railway, or any WSGI host.
- Exposes the same `/api/<group>` endpoints plus proxy/image helpers consumed by the Flutter client.
- Configure environment variables (API keys, upstream base URLs, cache toggles) through your hosting dashboard.

---

## Flutter Dashboard (`smart_farm_platform/`)
```bash
cd smart_farm_platform
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
```
- Requires Flutter 3.24+ and Dart 3.8.
- Pages: Overview, Greenhouse, Soil, Irrigation, Crop Vision (status banners, pagination, CSV export).
- To point at a hosted API, update the `API_BASE_URL` define with your deployment URL.
- Build artifacts:
  - Android: `flutter build apk --dart-define=API_BASE_URL=...`
  - Web: `flutter build web --dart-define=API_BASE_URL=...`

### Useful Checks
- API smoke test: `curl http://127.0.0.1:5000/api/greenhouse/all`
- Flutter analyzer: `flutter analyze`
- Unit tests: `flutter test`
- MQTT ingest (optional): `python mqtt_subscriber.py`

---

## License
This project is for educational and research purposes under the ARC Smart Agriculture initiative.  
© 2025 ARC Group 5. All rights reserved.

---

That’s the full loop: run the MQTT bridge and Flask service (locally or hosted), point the Flutter dashboard at its `/api` base URL, and you have the Smart Farm telemetry UI up and running.
