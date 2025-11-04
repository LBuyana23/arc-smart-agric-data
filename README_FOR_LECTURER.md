Smart Farm Dashboard — Project README for Lecturer

Overview
--------
This repository contains the Smart Farm Dashboard, a small smart-farm monitoring project built primarily as a Flutter application (UI) and a set of lightweight Python tools (backend testing & mocks). The system collects environmental and soil sensor data, displays current status dashboards, and visualises historical time-series (temperature, CO₂, soil moisture, EC, pH, nutrients).

Purpose
-------
The project demonstrates:
- End-to-end data collection, storage, and visualisation for greenhouse and soil sensors.
- A Flutter-based dashboard with paginated history views and lightweight charts for monitoring.
- Practical handling of real-world data issues: inconsistent field names, missing timestamps, string-number normalization, and CSV export.

High-level architecture
-----------------------
- Frontend: Flutter (Dart) app in `smart_farm_platform/` — the main user-facing dashboard. Uses `fl_chart` for charting and custom widgets for paginated tables.
- Backend / Tools: Python helper scripts and tests in `Testing the Flask app/` — simple mock upstreams, probes, and unit tests for API behaviours (not a full server in this repo).
- Data flow: The frontend fetches group-level and historical readings using an `ApiService` abstraction. Data rows may come with different field key names and timestamp formats; helpers in `UiHelpers` normalise timestamps and preferred column choices.

Repository layout (important files)
----------------------------------
- smart_farm_platform/
  - lib/
    - main.dart — Flutter app entry point.
    - pages/
      - overview_page.dart — Dashboard overview and small charts (linter fixes applied).
      - greenhouse_page.dart — Grouped greenhouse UI: paginated tables + charts (Temperature and CO₂ charts added).
      - soil_page.dart — Soil monitoring page with small charts for moisture, temp, EC, pH, N/P/K (X-axis normalized to avoid plotting issues).
    - widgets/
      - paginated_history.dart — Generic paginated history UI used throughout; requires a builder to render rows/pages.
      - no_data_placeholder.dart — UI shown when no data is available.
    - services/
      - api_service.dart — Abstraction for fetching history/group data from upstream bridge (some linter fixes remain planned).
    - utils/
      - ui_helpers.dart — Timestamp parsing, formatting, and other small helpers.
      - csv_export.dart — CSV export helper used by the UI.
    - theme/
      - app_theme.dart — Colour and style tokens used by the app.
  - pubspec.yaml — Flutter/Dart dependencies.
  - README.md — (existing) may contain Flutter-centric notes.

- Testing the Flask app/
  - testapp.py, mock_upstream.py, mock.json, response.json — test utilities and mock payloads used locally during development.
  - tests/ — small tests that exercise the Python pieces.

Key design/implementation notes (useful for evaluation)
------------------------------------------------------
- Data normalization: Sensors and bridge may return inconsistent field names (e.g., "TEMPERATURE", "temp", "temperature_c"). The app resolves candidate keys by exact case-insensitive match then substring match.
- Timestamp handling: Many rows include epoch timestamps or ISO strings in different fields. The app uses `UiHelpers.parseTimestamp(...)` to parse and normalise timestamps. For charting we convert timestamps to seconds relative to the first timestamp to avoid very large X values that cause rendering artifacts (charts looked like loops when raw epoch ms were used).
- Charts: We use the `fl_chart` package and render compact LineChart cards for quick visual checks. Tooltips are enabled. If no series data exist the UI shows a small "n/a" card.
- Tables: `PaginatedHistory` is used to fetch and render history pages; it requires a `builder` callback which returns a widget for the rows — this pattern keeps the paging logic separate from layout.

How to run (Flutter app) — Windows (cmd.exe)
-------------------------------------------
Prerequisites:
- Flutter SDK installed and on PATH (see https://flutter.dev/docs/get-started/install)
- Android SDK / emulator or iOS tooling (macOS only) if testing on device
- A device/emulator available

Steps (from repo root):
```cmd
cd "c:\Users\banel\OneDrive\Documents\REPLIT VERSION\SmartFarmDashboard\smart_farm_platform"
flutter pub get
flutter run
```
This will launch the app on the connected device or active emulator.

How to run (Python test utilities)
----------------------------------
A set of helper scripts and mocks are in `Testing the Flask app/`. They are not a production backend but are useful for local testing.

Using Windows cmd with an existing venv (if present):
```cmd
cd "c:\Users\banel\OneDrive\Documents\REPLIT VERSION\SmartFarmDashboard\Testing the Flask app"
venv-\Scripts\activate
python -m pip install -r requirements.txt  # if you have a requirements.txt; if not, install minimal deps like Flask
python testapp.py
```
Note: The repo includes a `venv-` directory used during development; creating a fresh virtual environment is recommended for evaluation.

Testing and validation
----------------------
- The Flutter app code has been iteratively linted; `overview_page.dart`, `greenhouse_page.dart`, and `soil_page.dart` have recent fixes applied. A remaining set of linter TODOs are noted in the project TODO list.
- Unit tests for the Python utilities are in `Testing the Flask app/tests`; run them with your chosen test runner (e.g., pytest).

Known issues and TODOs
---------------------
- `lib/providers/app_state.dart`, `lib/services/ai_integration.dart`, and `lib/services/api_service.dart` contain a small number of linter/style issues that should be resolved before final submission.
- Greenhouse chart key resolution is heuristic-based—if the backend uses different field names, add a mapping or expand candidate lists.
- Axis label formatting is currently compact (HH:mm). For multi-day views a date-aware tick formatter would be better.

What to demonstrate to the lecturer
----------------------------------
- Launch the app and show the `Overview` page with small summary metrics and charts.
- Open a greenhouse group: show the paginated table and the Temperature/CO₂ charts below it.
- Open the Soil page: demonstrate the moisture and other small charts and mention the X-axis normalisation fix.
- Show the `Testing the Flask app` folder to explain how mocks were used during development and how the code handles messy, real-world payloads.

Development notes (for the lecturer)
-----------------------------------
- The project was implemented to handle real-life dirty data (inconsistent keys, missing timestamps). Code changes that address these problems are in `lib/utils/ui_helpers.dart`, `lib/pages/soil_page.dart`, and `lib/pages/greenhouse_page.dart`.
- The code favours defensive parsing (try-parse, null checks) and small visual cards rather than large multi-axis charts to keep the UI responsive on low-power devices.

Contact and attribution
-----------------------
If you need me to walk through the code or prepare a short demo recording for the lecture, tell me which sections to focus on (e.g., charting, data-cleaning, or testing utilities) and I will prepare a script and slides.

Acknowledgements
----------------
- Uses Flutter and the `fl_chart` package for visualization.
- Small Python utilities used for mocking & local testing.

---
Generated on 2025-11-04 — README focused for an academic evaluation. If you want a shorter one-page summary or a version tailored to a live demo script, I can create that next.