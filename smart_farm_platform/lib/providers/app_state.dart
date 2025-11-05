import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/insights_service.dart';
import '../services/weather_service.dart';

class AppState extends ChangeNotifier {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Overview';
  final List<double> _liveData = List.generate(
    60,
    (i) => 20 + Random().nextDouble() * 10,
  );
  Timer? _liveDataTimer;
  String _currentInsight = 'Analyzing farm data patterns...';
  double _insightConfidence = 0.85;
  Timer? _insightTimer;
  String _systemStatus = 'stable';

  bool get isSidebarCollapsed => _isSidebarCollapsed;
  String get currentPage => _currentPage;
  List<double> get liveData => _liveData;
  String get currentInsight => _currentInsight;
  double get insightConfidence => _insightConfidence;
  String get systemStatus => _systemStatus;

  final List<String> _insightPool = [
    'Soil moisture has dropped 8% in Zone A. Consider increasing irrigation by 15%.',
    'Optimal temperature range maintained for 96.3% of the past 24 hours.',
    'Wind patterns suggest potential storm activity. Review crop protection measures.',
    'Water usage efficiency improved by 12% compared to last week.',
    'pH levels trending slightly acidic. Nutrient adjustment may be beneficial.',
    'Humidity levels optimal for current crop growth stage.',
  ];

  /// If [startSimulations] is false this will not start background timers or
  /// network clients — useful for tests.
  ///
  /// To start real network syncing in non-test runs you can either construct
  /// with the default (startSimulations=true) or call
  /// `startDataSyncWithServices` with concrete service instances.
  AppState({bool startSimulations = true}) {
    if (startSimulations) {
      _startLiveDataSimulation();
      _startInsightRotation();
      _simulateSystemStatus();
    } else {
      // Intentionally do NOT initialize network clients or start sync here.
      // Tests should construct AppState(startSimulations: false) to avoid
      // creating timers or HttpClient instances.
    }
  }

  /// Manually attach real service implementations and start periodic data
  /// synchronization. This is useful for integration runs where the caller
  /// wants explicit control over when network activity begins.
  void startDataSyncWithServices(
    ApiService api,
    InsightsService insights,
    WeatherService weather,
  ) {
    _api = api;
    _insights = insights;
    _weather = weather;
    _startDataSync();
  }

  // Real data services (initialized when startSimulations is false)
  late final ApiService _api;
  late final InsightsService _insights;
  late final WeatherService _weather;

  // Summary fields exposed to the UI
  double? greenhouseAvgTemp;
  double? greenhouseAvgHumidity;

  double? irrigationFlowSum;
  int irrigationPumpsOn = 0;
  int irrigationTotalPumps = 0;

  double? soilAvgMoisture;
  double? soilAvgPh;

  int cropThreatsCount = 0;
  String? topCropThreatLabel;
  double? topCropThreatConfidence;

  // Weekly insights cached
  double? weeklySoilMoistureChangePct;
  double? weeklyIrrigationVolume;
  int? weeklyDetectionsCount;

  // Weather
  double? currentTemperature;
  int? currentWeatherCode;
  List<Map<String, dynamic>> threeDayForecast = [];
  double? feelsLikeTemperature;
  double? humidityPercent;
  double? windSpeedKmh;
  String? weatherLocationLabel;
  String? weatherLocationCountry;
  String? weatherLocationRegion;
  String? weatherTimezone;

  Timer? _syncTimer;
  Timer? _weeklyInsightsTimer;
  Timer? _weatherTimer;
  Timer? _systemStatusTimer;

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  void setCurrentPage(String page) {
    _currentPage = page;
    notifyListeners();
  }

  void _startLiveDataSimulation() {
    _liveDataTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _liveData.removeAt(0);
      _liveData.add(20 + Random().nextDouble() * 10);
      notifyListeners();
    });
  }

  void _startInsightRotation() {
    _insightTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      final random = Random();
      _currentInsight = _insightPool[random.nextInt(_insightPool.length)];
      _insightConfidence = 0.75 + random.nextDouble() * 0.2;
      notifyListeners();
    });
  }

  void _simulateSystemStatus() {
    _systemStatusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      final random = Random();
      final statuses = ['stable', 'delayed', 'disconnected'];
      _systemStatus =
          statuses[random.nextInt(100) < 90
              ? 0
              : random.nextInt(statuses.length)];
      notifyListeners();
    });
  }

  void _startDataSync() {
    // Immediately fetch and then schedule periodic sync
    _refreshSummaries();
    _syncTimer = Timer.periodic(Duration(seconds: 20), (_) async {
      await _refreshSummaries();
    });
    // Update weekly insights less frequently
    _weeklyInsightsTimer = Timer.periodic(Duration(minutes: 10), (_) async {
      try {
        weeklySoilMoistureChangePct = await _insights
            .calculateWeeklySoilMoistureChange();
        weeklyIrrigationVolume = await _insights
            .calculateWeeklyIrrigationVolume();
        weeklyDetectionsCount = await _insights.countRecentDetections();
        notifyListeners();
      } catch (_) {}
    });
    // Update weather periodically
    _weatherTimer = Timer.periodic(Duration(minutes: 30), (_) async {
      try {
        final wd = await _weather.fetchWeather();
        final meta = await _weather.loadLocation();
        if (wd != null) {
          currentTemperature = wd.currentTemp;
          currentWeatherCode = wd.weatherCode;
          feelsLikeTemperature = wd.apparentTemp;
          humidityPercent = wd.humidity;
          windSpeedKmh = wd.windSpeed;
          threeDayForecast = wd.daily
              .take(3)
              .map(
                (d) => {
                  'date': d.date.toIso8601String(),
                  'min': d.minTemp,
                  'max': d.maxTemp,
                  'code': d.weatherCode,
                  'precip': d.precipitationProbability,
                  'wind': d.windSpeed,
                },
              )
              .toList();
          if (meta != null) {
            weatherLocationLabel = meta['label'] as String?;
            weatherLocationCountry = meta['country'] as String?;
            weatherLocationRegion = meta['region'] as String?;
            weatherTimezone = meta['timezone'] as String?;
          }
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  /// Public helper: save a new weather location (lat/lon) and refresh weather immediately.
  Future<void> setWeatherLocation(
    double lat,
    double lon, {
    String? label,
    String? country,
    String? region,
    String? timezone,
  }) async {
    try {
      await _weather.saveLocation(
        lat,
        lon,
        label: label,
        country: country,
        admin: region,
        timezone: timezone,
      );
      weatherLocationLabel = label;
      weatherLocationCountry = country;
      weatherLocationRegion = region;
      weatherTimezone = timezone;
      notifyListeners();
      await updateWeatherNow();
    } catch (_) {}
  }

  /// Public helper to fetch weather immediately and update AppState fields.
  Future<void> updateWeatherNow() async {
    try {
      final wd = await _weather.fetchWeather();
      final meta = await _weather.loadLocation();
      if (wd != null) {
        currentTemperature = wd.currentTemp;
        currentWeatherCode = wd.weatherCode;
        feelsLikeTemperature = wd.apparentTemp;
        humidityPercent = wd.humidity;
        windSpeedKmh = wd.windSpeed;
        threeDayForecast = wd.daily
            .take(3)
            .map(
              (d) => {
                'date': d.date.toIso8601String(),
                'min': d.minTemp,
                'max': d.maxTemp,
                'code': d.weatherCode,
                'precip': d.precipitationProbability,
                'wind': d.windSpeed,
              },
            )
            .toList();
        if (meta != null) {
          weatherLocationLabel = meta['label'] as String?;
          weatherLocationCountry = meta['country'] as String?;
          weatherLocationRegion = meta['region'] as String?;
          weatherTimezone = meta['timezone'] as String?;
        }
      } else {
        currentTemperature = null;
        currentWeatherCode = null;
        threeDayForecast = [];
        feelsLikeTemperature = null;
        humidityPercent = null;
        windSpeedKmh = null;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshSummaries() async {
    try {
      // Greenhouse: aggregate greenhouse_g1 and greenhouse_g9
      final ghRaw = await _api.fetchAllGroupRaw('greenhouse');
      if (ghRaw != null) {
        final temps = <double>[];
        final hums = <double>[];
        for (final entry in ghRaw.values) {
          if (entry is Map) {
            final t =
                entry['temperature'] ?? entry['temp'] ?? entry['TEMPERATURE'];
            final h = entry['humidity'] ?? entry['hum'] ?? entry['HUMIDITY'];
            final td = double.tryParse(t?.toString() ?? '');
            final hd = double.tryParse(h?.toString() ?? '');
            if (td != null) temps.add(td);
            if (hd != null) hums.add(hd);
          }
        }
        if (temps.isNotEmpty) {
          greenhouseAvgTemp = temps.reduce((a, b) => a + b) / temps.length;
        }
        if (hums.isNotEmpty) {
          greenhouseAvgHumidity = hums.reduce((a, b) => a + b) / hums.length;
        }
      }

      // Irrigation
      final irrRaw = await _api.fetchAllGroupRaw('irrigation');
      if (irrRaw != null) {
        final node =
            irrRaw['irrigation_telemetry'] ??
            irrRaw.values.firstWhere((_) => true, orElse: () => null);
        final items = <Map<String, dynamic>>[];
        if (node is Map &&
            node['data'] is Map &&
            node['data']['items'] is List) {
          for (final it in node['data']['items']) {
            if (it is Map) {
              items.add(Map<String, dynamic>.from(it));
            }
          }
        }
        double sumFlow = 0.0;
        final pumps = <dynamic>{};
        int onCount = 0;
        for (final it in items) {
          final flow =
              double.tryParse(
                it['flowRate']?.toString() ??
                    it['flow_rate']?.toString() ??
                    '0',
              ) ??
              0.0;
          sumFlow += flow;
          final pumpState = (it['pumpState'] ?? it['pump_status'] ?? '')
              .toString();
          if (pumpState.toUpperCase() == 'ON') {
            onCount += 1;
          }
          final id = it['device_id'] ?? it['id'] ?? it['DEVICE_ID'];
          if (id != null) {
            pumps.add(id);
          }
        }
        irrigationFlowSum = sumFlow;
        irrigationPumpsOn = onCount;
        irrigationTotalPumps = pumps.length;
      }

      // Soil
      final soilRaw = await _api.fetchAllGroupRaw('soil');
      if (soilRaw != null) {
        final moist = <double>[];
        final phs = <double>[];
        for (final entry in soilRaw.values) {
          if (entry is Map &&
              entry['data'] is Map &&
              entry['data']['items'] is List) {
            for (final it in entry['data']['items']) {
              if (it is Map) {
                final m = double.tryParse(
                  it['moisture']?.toString() ??
                      it['moisture_pct']?.toString() ??
                      '',
                );
                final p = double.tryParse(
                  it['ph']?.toString() ?? it['pH']?.toString() ?? '',
                );
                if (m != null) {
                  moist.add(m);
                }
                if (p != null) {
                  phs.add(p);
                }
              }
            }
          }
        }
        if (moist.isNotEmpty) {
          soilAvgMoisture = moist.reduce((a, b) => a + b) / moist.length;
        }
        if (phs.isNotEmpty) {
          soilAvgPh = phs.reduce((a, b) => a + b) / phs.length;
        }
      }

      // Crop vision
      final cvRaw = await _api.fetchAllGroupRaw('crop_vision');
      if (cvRaw != null) {
        int threats = 0;
        String? topLabel;
        double topConf = -1.0;
        for (final entry in cvRaw.values) {
          if (entry is Map &&
              entry['data'] is Map &&
              entry['data']['items'] is List) {
            for (final it in entry['data']['items']) {
              if (it is Map) {
                final disease = (it['disease'] ?? it['label'] ?? '').toString();
                final conf =
                    double.tryParse(
                      it['confidence']?.toString() ??
                          it['score']?.toString() ??
                          '0',
                    ) ??
                    0.0;
                if (disease.toLowerCase() != 'healthy' &&
                    disease.toLowerCase() != 'unknown') {
                  threats += 1;
                }
                if (conf > topConf) {
                  topConf = conf;
                  topLabel = disease;
                }
              }
            }
          }
        }
        cropThreatsCount = threats;
        topCropThreatLabel = topLabel;
        topCropThreatConfidence = topConf >= 0 ? topConf : null;
      }

      notifyListeners();
    } catch (e) {
      // ignore errors for background sync
    }
  }

  @override
  void dispose() {
    _liveDataTimer?.cancel();
    _insightTimer?.cancel();
    _syncTimer?.cancel();
    _weeklyInsightsTimer?.cancel();
    _weatherTimer?.cancel();
    _systemStatusTimer?.cancel();
    super.dispose();
  }
}
