# ARC Soil Sync Dashboard  
**Smart Farm Data Broker, API Layer, and Multi-Channel Dashboard**

---

## 1. Project Overview
The ARC Soil Sync Dashboard is the authoritative interface for our smart agriculture pilot. It ingests real-time telemetry from IoT nodes, brokers the data through MQTT and a Python/Flask bridge, and presents actionable insights through a Flutter dashboard (web, desktop, and Android). This document is aimed at lecturers, reviewers, and collaborators who need to understand the architecture, reproduce the setup, or evaluate the system.

### Key Capabilities
- Unified view of greenhouse, irrigation, soil, and crop vision feeds.
- MQTT-driven ingestion with schema-harmonised topics (`arc/<section>/<group>/<sensor>`).
- Flask API bridge (Render-hosted) with caching, timestamp normalisation, and CSV tooling.
- Flutter UI with Provider state management, Hive caching, AI-assisted narrative summaries, and export-ready analytics.

---

## 2. High-Level Architecture

```
ESP32 Sensors → Mosquitto MQTT Broker → Python Subscribers/Bridges → Flask REST API → Flutter Dashboard
                              ↘ (optional) Google AI Summaries ↗
```

### Core Components
- **IoT Layer** – ESP32 nodes publish sensor payloads for soil, greenhouse, irrigation, and crop imagery metadata.
- **MQTT Broker (Mosquitto)** – Lightweight hub for ingest; runs on campus infrastructure.
- **Python Subscriber + Bridge (`Testing the Flask app/`)** – Normalises payloads, logs to storage, and surfaces `/api/<group>` endpoints.
- **Data Store** – Hosted relational database (Render Postgres), abstracted via the Flask service.
- **Flutter Dashboard (`smart_farm_platform/`)** – Responsive UI for browser, desktop, and mobile builds. Optional Google AI summaries require a compile-time key.

Topic convention enables wildcard subscriptions such as `arc/greenhouse-monitoring/#` or `arc/+/group9/#` for targeted debugging.

---

## 3. Repository Guide
- `smart_farm_platform/` – Flutter client (web/desktop/mobile).
- `Testing the Flask app/` – Flask bridge, mock services, API tests.
- `mqtt_subscriber.py`, `publisher.py`, `tools/` – MQTT data ingest utilities.
- `requirements.txt` – Python dependencies.
- `attached_assets/`, `README_FOR_LECTURER.md` – supplementary documentation and artefacts.

---

## 4. Prerequisites
- **Flutter 3.24+** with Android/iOS/Windows toolchains installed (via `flutter doctor`).
- **Python 3.10+** for MQTT subscribers and Flask bridge.
- **Mosquitto** broker (local or remote). Default port `1883`.
- **Render account** (or similar PaaS) for hosting the Flask API.
- **Optional Google AI key** for narrative summaries.

---

## 5. Quick Start (Local Full Stack)

### 5.1 Clone and bootstrap
```bash
git clone https://github.com/LBuyana23/arc-smart-agric-data.git
cd arc-smart-agric-data
```

### 5.2 MQTT subscriber (optional but recommended for local telemetry)
```bash
python -m venv venv
venv\Scripts\activate           # use `source venv/bin/activate` on macOS/Linux
pip install -r requirements.txt
python mqtt_subscriber.py         # connect to configured broker
```

Test the broker:
```bash
mosquitto_sub -t "arc/#"
mosquitto_pub -t "arc/soil-monitoring/group8/soil-sensor" -m '{"moisture":45.3}'
```

### 5.3 Flask API bridge
```bash
cd "Testing the Flask app"
python -m venv venv-local
venv-local\Scripts\activate
pip install -r requirements.txt
set FLASK_ENV=development           # macOS/Linux: export FLASK_ENV=development
python testapp_local.py             # serves http://127.0.0.1:5000
```
Key endpoints: `/api/greenhouse/all`, `/api/soil/all`, `/api/irrigation/all`, `/api/crop/all`.

### 5.4 Flutter dashboard
```bash
cd ../smart_farm_platform
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
```
Alternative targets:
- `flutter run -d chrome --web-renderer canvaskit --dart-define=API_BASE_URL=...`
- `flutter run -d emulator-5554 --dart-define=API_BASE_URL=...` (Android emulator).

### 5.5 Google AI Narratives (optional)
```powershell
$Env:GOOGLE_AI_API_KEY = 'REGENERATE_ME'
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000/api `
  --dart-define=GOOGLE_AI_API_KEY=$Env:GOOGLE_AI_API_KEY `
  --dart-define=GOOGLE_AI_MODEL=models/gemini-1.5-pro
```
If the key is absent, the UI falls back to deterministic local summaries and labels the button “Generate AI Summary”.

---

## 6. Hosted Deployment (Render)
1. Push the Flask app (`Testing the Flask app/`) to a Render Web Service. Recommended command: `gunicorn -b 0.0.0.0:10000 testapp_clean:app`.
2. Configure environment variables in Render:
   - `UPSTREAM_API_BASE`, `CACHE_ENABLED`, `MQTT_BROKER_HOST`, etc.
3. Note: Render cold starts can introduce **up to a 4-minute delay** on the first request after inactivity. During this period, the dashboard displays cached values. Subsequent requests return in <2 seconds.
4. Update your Flutter builds with `--dart-define=API_BASE_URL=https://smart-farm-api-g25w.onrender.com/api`.

---

## 7. Building for Distribution

### Android APK
```powershell
Set-Location smart_farm_platform
$Env:GOOGLE_AI_API_KEY = 'REGENERATE_ME'
flutter build apk --release `
  --dart-define=API_BASE_URL=https://smart-farm-api-g25w.onrender.com/api `
  --dart-define=GOOGLE_AI_API_KEY=$Env:GOOGLE_AI_API_KEY `
  --dart-define=GOOGLE_AI_MODEL=models/gemini-1.5-pro
```
Artifacts: `smart_farm_platform/build/app/outputs/flutter-apk/app-release.apk`.

### Web
```bash
flutter build web --release --base-href / `
  --dart-define=API_BASE_URL=https://smart-farm-api-g25w.onrender.com/api
```
Deploy the `build/web` folder to static hosting (e.g., Netlify, Firebase Hosting).

### Desktop (Windows)
```bash
flutter build windows --dart-define=API_BASE_URL=https://smart-farm-api-g25w.onrender.com/api
```

---

## 8. Testing and Quality Checks
- **Flutter unit/widget tests**: `flutter test`
- **Static analysis**: `flutter analyze`
- **Flask API tests**: from `Testing the Flask app/tests/` run `python -m pytest`.
- **Integration smoke**: `curl https://smart-farm-api-g25w.onrender.com/api/soil/all`

---

## 9. Troubleshooting & Known Behaviours
- **Render cold start delay (≈4 minutes)** – occurs after periods of inactivity. Solution: trigger the API ahead of live demos by visiting any `/api/...` endpoint. Dashboard indicates the data age and gracefully falls back to cached metrics.
- **MQTT connection refused** – verify broker is reachable and credentials align with `mqtt_subscriber.py` configuration.
- **Missing soil/irrigation samples on first load** – sensors may publish at 1–5 minute intervals; use the Past 14 Days window or trigger manual refresh.
- **AI summary button disabled** – compile without AI key. Rebuild or rerun with `--dart-define=GOOGLE_AI_API_KEY=...`.
- **CORS blocking web build** – when hitting local Flask from Flutter web, launch Chrome with `--disable-web-security` or configure proxy; Render deployment already provides proper headers.
- **App takes long to populate on emulator** – ensure `API_BASE_URL` points to public Render URL; the emulator cannot reach `localhost` on the host PC without port forwarding.

---

## 10. Evaluation Notes for Lecturers
- Demonstration sequence: start the Render-backed API, open the Flutter dashboard (web or Windows desktop), set the data window to “Past 14 Days”, and trigger the AI narrative to sample the Google Gemini integration.
- Highlight: greenhouse aggregates (temperature, humidity, CO₂), soil analytics (moisture, pH, EC), irrigation statistics (flow, pump states), and crop vision summaries.
- Data provenance is traceable: each card exposes counts, last update timestamps, and additional metrics to verify ingestion integrity.

---

## 11. License & Attribution
For coursework and research under the ARC Smart Agriculture initiative.  
© 2025 ARC Group 5. All rights reserved.

---

For further assistance, contact the project supervisor or the development team lead. This README should allow anyone to reproduce the stack end-to-end, understand operational expectations (including Render delays), and diagnose common deployment issues.
