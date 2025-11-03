Smart Farm Dashboard — Brief README

What this is
------------
A compact Flutter dashboard for monitoring greenhouse and soil sensor data. Includes small Python tools and mocks used during development.

Quick purpose
-------------
Visualise environmental (temperature, CO₂) and soil (moisture, EC, pH, nutrients) readings, handle messy real-world payloads, and export CSVs for analysis.

Quick start (Windows, cmd.exe)
-----------------------------
1. Open a terminal in the Flutter app folder:

   cd "c:\Users\banel\OneDrive\Documents\REPLIT VERSION\SmartFarmDashboard\smart_farm_platform"

2. Install packages and run:

   flutter pub get
   flutter run

(Use an Android/iOS emulator or connected device.)

Where to look (key files)
-------------------------
- `smart_farm_platform/lib/main.dart` — app entry
- `smart_farm_platform/lib/pages/overview_page.dart` — dashboard overview
- `smart_farm_platform/lib/pages/greenhouse_page.dart` — greenhouse tables + Temperature/CO₂ charts
- `smart_farm_platform/lib/pages/soil_page.dart` — soil charts (uses relative-time x-axis to avoid rendering artifacts)
- `smart_farm_platform/lib/widgets/paginated_history.dart` — pagination helper used by tables
- `Testing the Flask app/` — Python mocks and test utilities used during development

Notes for the lecturer
----------------------
- The UI uses `fl_chart` for charts and handles inconsistent field names/timestamps defensively.
- For a quick demo: open the app, show Overview, open a greenhouse group (table + charts), then Soil page.

If you want screenshots, a one-page demo script, or a slide, tell me which and I will add it.